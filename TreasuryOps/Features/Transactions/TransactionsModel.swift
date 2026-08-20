import Foundation
import Observation

@MainActor
@Observable
final class TransactionsModel {
    private(set) var transactions: [Transaction] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasMore = true
    private(set) var filters = TransactionFilters()

    /// Cached for row badges and the bulk-assign sheet — fetched once,
    /// not re-fetched per row.
    private(set) var categories: [Category] = []

    var categoriesById: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    var searchText = "" {
        didSet { scheduleSearch() }
    }

    private var nextCursor: String?
    private var searchTask: Task<Void, Never>?

    /// Bumped by every mutation to `transactions` — `refresh()`/
    /// `loadNextPage()` capture it before their network call and only
    /// apply the response if nothing else (most importantly `replace(_:)`)
    /// has mutated state in the meantime. Without this, a fetch started
    /// *before* a category edit can complete *after* it and silently
    /// overwrite the edit with the pre-edit server state it fetched.
    private var stateVersion = 0

    func loadFirstPageIfNeeded() async {
        guard transactions.isEmpty else { return }
        await refresh()
    }

    func loadCategoriesIfNeeded() async {
        guard categories.isEmpty else { return }
        categories = (try? await CategoriesClient.list()) ?? []
    }

    func applyFilters(_ newFilters: TransactionFilters) async {
        filters = newFilters
        await refresh()
    }

    /// Reflects an edit made on the detail screen (e.g. a category change)
    /// back into the list without a full reload. If a category filter is
    /// active and the edit moved the transaction out of it, the row is
    /// removed instead of updated in place — otherwise it'd keep showing
    /// in a filtered list it no longer belongs in.
    func replace(_ updated: Transaction) {
        stateVersion += 1
        guard let index = transactions.firstIndex(where: { $0.id == updated.id }) else { return }
        if let categoryId = filters.categoryId, updated.categoryId != categoryId {
            transactions.remove(at: index)
        } else {
            transactions[index] = updated
        }
    }

    /// Same idea as `replace(_:)`, applied to every transaction a batch
    /// category assignment touched — one `stateVersion` bump for the whole
    /// batch rather than per-item, so an in-flight refresh only has to
    /// discard its response once, not N times.
    func applyBatchCategoryUpdate(transactionIds: Set<String>, categoryId: String) {
        stateVersion += 1
        if let activeCategoryId = filters.categoryId, activeCategoryId != categoryId {
            transactions.removeAll { transactionIds.contains($0.id) }
        } else {
            for index in transactions.indices where transactionIds.contains(transactions[index].id) {
                transactions[index].categoryId = categoryId
            }
        }
    }

    /// Reloads from the start. Deliberately does **not** cancel
    /// `searchTask` here: `scheduleSearch()`'s task calls this method
    /// directly as its own continuation, so cancelling `searchTask` from
    /// inside `refresh()` would self-cancel the very task that's running —
    /// `URLSession`'s async APIs are cancellation-aware, so the network
    /// call would throw `CancellationError` immediately and every debounced
    /// search would silently fail. `scheduleSearch()` already cancels any
    /// previous *pending* debounce before starting a new one, which is all
    /// that's needed to prevent them from stacking.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let versionAtStart = stateVersion
        do {
            let page = try await fetchPage(cursor: nil)
            guard versionAtStart == stateVersion else { return }
            transactions = page.items
            stateVersion += 1
            nextCursor = page.pageInfo.nextCursor
            hasMore = page.pageInfo.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called from each row's `.task` — triggers the next page once the
    /// scroll position nears the end, replacing the web app's manual
    /// "Load more" button with native scroll-triggered pagination.
    func loadMoreIfNeeded(currentItem: Transaction) async {
        guard hasMore, !isLoadingMore, nextCursor != nil else { return }
        let thresholdIndex = transactions.index(transactions.endIndex, offsetBy: -5, limitedBy: transactions.startIndex) ?? transactions.startIndex
        guard let currentIndex = transactions.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard let cursor = nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetchPage(cursor: cursor)
            transactions.append(contentsOf: page.items)
            nextCursor = page.pageInfo.nextCursor
            hasMore = page.pageInfo.hasMore
        } catch {
            // Transient failure mid-scroll: keep what's already loaded and
            // let the next scroll attempt retry, rather than surfacing an
            // error over content the person can already see.
        }
    }

    private func fetchPage(cursor: String?) async throws -> TransactionsClient.Page {
        let bounds = filters.dateRange.bounds
        return try await TransactionsClient.list(
            accountId: filters.accountId,
            categoryId: filters.categoryId,
            query: normalizedSearchText,
            tag: filters.queryTag,
            from: bounds?.from,
            to: bounds?.to,
            cursor: cursor
        )
    }

    private var normalizedSearchText: String? {
        searchText.isEmpty ? nil : searchText
    }

    /// A debounced timer only — the task it schedules calls `refresh()`
    /// directly (never re-enters `scheduleSearch`), so cancelling
    /// `searchTask` here only ever cancels a *previous, still-pending*
    /// debounce, never a network call already in flight.
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }
}
