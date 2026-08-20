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

    var searchText = "" {
        didSet { scheduleSearch() }
    }

    private var nextCursor: String?
    private var searchTask: Task<Void, Never>?

    func loadFirstPageIfNeeded() async {
        guard transactions.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        searchTask?.cancel()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await TransactionsClient.list(query: normalizedSearchText)
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
            let page = try await TransactionsClient.list(query: normalizedSearchText, cursor: cursor)
            transactions.append(contentsOf: page.items)
            nextCursor = page.pageInfo.nextCursor
            hasMore = page.pageInfo.hasMore
        } catch {
            // Transient failure mid-scroll: keep what's already loaded and
            // let the next scroll attempt retry, rather than surfacing an
            // error over content the person can already see.
        }
    }

    private var normalizedSearchText: String? {
        searchText.isEmpty ? nil : searchText
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }
}
