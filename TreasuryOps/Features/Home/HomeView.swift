import Foundation
import SwiftUI

struct HomeView: View {
    @Environment(AuthModel.self) private var authModel
    @State private var model = HomeModel()

    /// Feeds `TransactionDetailView` when a recent-activity row is tapped
    /// — a dedicated model, separate from the Transactions tab's own, so
    /// a category edit made from here doesn't need to reach across tabs.
    @State private var transactionsModel = TransactionsModel()
    @State private var selectedTransaction: Transaction?
    @State private var loadingRecentActivityId: String?
    @State private var recentActivityErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeaderView(name: authModel.currentUser?.name)
                    HomeContent(
                        model: model,
                        loadingRecentActivityId: loadingRecentActivityId,
                        onSelectRecentActivity: selectTransaction
                    )
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await model.refresh() }
            .task { await model.loadIfNeeded() }
            .navigationDestination(for: HomeCashflowMetric.self) { metric in
                HomeCashflowDetailView(metric: metric)
            }
            .navigationDestination(for: MonthlySpending.self) { monthly in
                HomeMonthlySpendingDetailView(monthly: monthly)
            }
            .navigationDestination(for: HomeCategoryDrillDown.self) { drillDown in
                TransactionsScreen(
                    initialFilters: TransactionFilters(categoryId: drillDown.categoryId, dateRange: .thisMonth),
                    title: drillDown.categoryName
                )
            }
            .navigationDestination(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction, model: transactionsModel)
            }
            .alert(
                "Couldn't Load Transaction",
                isPresented: Binding(
                    get: { recentActivityErrorMessage != nil },
                    set: { isPresented in if !isPresented { recentActivityErrorMessage = nil } }
                ),
                presenting: recentActivityErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private func selectTransaction(_ item: RecentActivityItem) {
        guard loadingRecentActivityId == nil else { return }
        loadingRecentActivityId = item.id
        Task {
            defer { loadingRecentActivityId = nil }
            do {
                selectedTransaction = try await TransactionsClient.get(id: item.id)
            } catch {
                recentActivityErrorMessage = error.localizedDescription
            }
        }
    }
}

/// Everything below the greeting header — split out so its `.task`-driven
/// data dependencies (`model`'s individual properties) don't also
/// re-evaluate the header on every refresh.
private struct HomeContent: View {
    let model: HomeModel
    let loadingRecentActivityId: String?
    let onSelectRecentActivity: (RecentActivityItem) -> Void

    var body: some View {
        if let errorMessage = model.errorMessage, model.summary == nil {
            ContentUnavailableView(
                "Couldn't Load Dashboard",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if model.isLoading && model.summary == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else {
            if let summary = model.summary {
                HomeBalanceSummaryCard(summary: summary)
            }
            if let stats = model.stats {
                HomeStatsGrid(stats: stats)
            }
            if let monthly = model.monthlySpending {
                HomeMonthlySpendingCard(monthly: monthly)
            }
            if let recurring = model.recurringForecast {
                HomeRecurringForecastCard(forecast: recurring)
            }
            if let investments = model.investments, !investments.items.isEmpty {
                HomeInvestmentsCard(investments: investments)
            }
            if model.topSpending.isEmpty == false {
                HomeTopSpendingCard(items: model.topSpending)
            }
            if let spendMix = model.spendMix {
                HomeSpendMixCard(mix: spendMix)
            }
            HomeRecentActivityCard(
                items: model.recentActivity,
                categoriesById: model.categoriesById,
                loadingItemId: loadingRecentActivityId,
                onSelect: onSelectRecentActivity
            )
        }
    }
}

private struct HomeHeaderView: View {
    let name: String?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(displayName)
                    .font(.largeTitle.bold())
            }
            Spacer()
            HomeAvatarBadge(name: name)
        }
        .padding(.top, 8)
    }

    private var displayName: String {
        guard let name, !name.isEmpty else { return "Welcome back" }
        return name
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}

private struct HomeAvatarBadge: View {
    let name: String?

    var body: some View {
        Text(initials)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(LinearGradient(colors: [.verdigris, .verdigrisBright], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
    }

    private var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

#Preview {
    HomeView()
        .environment(AuthModel())
}
