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

    /// Bumped on every `refresh()` call so a slower, earlier call can tell
    /// it's been superseded once its request group completes, and skip
    /// publishing a stale snapshot over a newer one.
    private var refreshGeneration = 0

    func loadIfNeeded() async {
        guard summary == nil else { return }
        await refresh()
    }

    /// Fetches every dashboard tile concurrently — they're independent
    /// reads, so there's no reason to serialize them.
    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration

        isLoading = true
        errorMessage = nil
        defer {
            if generation == refreshGeneration { isLoading = false }
        }
        do {
            async let summaryResult = DashboardClient.summary()
            async let statsResult = DashboardClient.stats()
            async let monthlyResult = DashboardClient.monthlySpending()
            async let topSpendingResult = DashboardClient.topSpending(range: .month)
            async let spendMixResult = DashboardClient.spendMix(range: .month)
            async let recentActivityResult = DashboardClient.recentActivity(limit: 8)
            async let categoriesResult = CategoriesClient.list()

            let (summary, stats, monthly, topSpending, spendMix, recentActivity) = try await (
                summaryResult, statsResult, monthlyResult, topSpendingResult, spendMixResult, recentActivityResult
            )
            // Category icons/colors only decorate RecentActivityCard rows
            // (which already handle a missing Category) — a failure here
            // shouldn't blank out the rest of an otherwise-successful load.
            let categories = (try? await categoriesResult) ?? []

            guard generation == refreshGeneration else { return }
            self.summary = summary
            self.stats = stats
            self.monthlySpending = monthly
            self.topSpending = topSpending
            self.spendMix = spendMix
            self.recentActivity = recentActivity
            self.categories = categories
        } catch {
            guard generation == refreshGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }
}
