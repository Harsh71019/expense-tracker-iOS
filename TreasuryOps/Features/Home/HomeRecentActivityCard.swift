import SwiftUI

/// The most recent posted transactions, read-only here — full editing
/// still lives on the Transactions tab.
struct HomeRecentActivityCard: View {
    let items: [RecentActivityItem]
    let categoriesById: [String: Category]

    /// A row's own id has no full `Transaction` to navigate with — only
    /// this summary shape — so tapping fetches one on demand rather than
    /// pushing a value directly. `loadingItemId` marks which row's fetch is
    /// in flight so that (and only that) row can show a spinner.
    let loadingItemId: String?
    let onSelect: (RecentActivityItem) -> Void

    var body: some View {
        DashboardCard {
            Text("Recent Activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("No recent transactions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            RecentActivityRow(
                                item: item,
                                category: item.categoryId.flatMap { categoriesById[$0] },
                                isLoading: item.id == loadingItemId
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(loadingItemId != nil)
                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct RecentActivityRow: View {
    let item: RecentActivityItem
    let category: Category?
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            CategoryBadge(iconKey: category?.icon, colorHex: category?.color, diameter: 28)
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(item.accountName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount, format: .currency(code: "INR").sign(strategy: .always()))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(item.type == .income ? .green : .primary)
                if let occurredAt = item.occurredAt {
                    Text(occurredAt, format: .dateTime.day().month())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                ProgressView()
                    .padding(.leading, 4)
            }
        }
    }

    private var signedAmount: Decimal {
        let amount = item.amountMinor.minorUnitsAsDecimal
        return item.type == .income ? amount : -amount
    }
}

#Preview {
    HomeRecentActivityCard(
        items: [
            RecentActivityItem(id: "1", accountId: "a1", accountName: "HDFC Checking", categoryId: nil, type: .expense, amountMinor: 45000, description: "Groceries", occurredAt: .now, tags: []),
            RecentActivityItem(id: "2", accountId: "a1", accountName: "HDFC Checking", categoryId: nil, type: .income, amountMinor: 9_500_000, description: "Salary", occurredAt: .now, tags: [])
        ],
        categoriesById: [:],
        loadingItemId: nil,
        onSelect: { _ in }
    )
    .padding()
}
