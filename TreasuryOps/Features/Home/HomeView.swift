import Foundation
import SwiftUI

struct HomeView: View {
    @Environment(AuthModel.self) private var authModel
    @State private var model = HomeModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeaderView(name: authModel.currentUser?.name)
                    HomeContent(model: model)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await model.refresh() }
            .task { await model.loadIfNeeded() }
        }
    }
}

/// Everything below the greeting header — split out so its `.task`-driven
/// data dependencies (`model`'s individual properties) don't also
/// re-evaluate the header on every refresh.
private struct HomeContent: View {
    let model: HomeModel

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
            if model.topSpending.isEmpty == false {
                HomeTopSpendingCard(items: model.topSpending)
            }
            if let spendMix = model.spendMix {
                HomeSpendMixCard(mix: spendMix)
            }
            HomeRecentActivityCard(items: model.recentActivity, categoriesById: model.categoriesById)
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
