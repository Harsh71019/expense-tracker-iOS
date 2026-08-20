import Foundation
import Observation

@MainActor
@Observable
final class HomeModel {
    private(set) var summary: DashboardSummary?
    private(set) var stats: DashboardStats?
    private(set) var monthlySpending: MonthlySpending?
    private(set) var topSpending: [TopSpendingItem] = []
    private(set) var spendMix: SpendMix?
    private(set) var recentActivity: [RecentActivityItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Cached for `RecentActivityCard` row badges — `RecentActivityItem`
    /// carries only a `categoryId`, not the category's icon/color.
    private(set) var categories: [Category] = []

    var categoriesById: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    func loadIfNeeded() async {
        guard summary == nil else { return }
        await refresh()
    }

    /// Fetches every dashboard tile concurrently — they're independent
    /// reads, so there's no reason to serialize them.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let summaryResult = DashboardClient.summary()
            async let statsResult = DashboardClient.stats()
            async let monthlyResult = DashboardClient.monthlySpending()
            async let topSpendingResult = DashboardClient.topSpending(range: .month)
            async let spendMixResult = DashboardClient.spendMix(range: .month)
            async let recentActivityResult = DashboardClient.recentActivity(limit: 8)
            async let categoriesResult = CategoriesClient.list()

            let (summary, stats, monthly, topSpending, spendMix, recentActivity, categories) = try await (
                summaryResult, statsResult, monthlyResult, topSpendingResult, spendMixResult, recentActivityResult, categoriesResult
            )
            self.summary = summary
            self.stats = stats
            self.monthlySpending = monthly
            self.topSpending = topSpending
            self.spendMix = spendMix
            self.recentActivity = recentActivity
            self.categories = categories
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
