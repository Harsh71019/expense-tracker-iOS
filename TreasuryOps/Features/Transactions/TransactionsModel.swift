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

    var searchText = "" {
        didSet { scheduleSearch() }
    }

    private var nextCursor: String?
    private var searchTask: Task<Void, Never>?

    func loadFirstPageIfNeeded() async {
        guard transactions.isEmpty else { return }
        await refresh()
    }

    func applyFilters(_ newFilters: TransactionFilters) async {
        filters = newFilters
        await refresh()
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
        do {
            let page = try await fetchPage(cursor: nil)
            transactions = page.items
            nextCursor = page.pageInfo.nextCursor
            hasMore = page.pageInfo.hasMore
        } catch {
            errorMessage = "Could not load transactions."
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
