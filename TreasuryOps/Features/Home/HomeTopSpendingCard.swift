import SwiftUI

/// Ranked list of the month's top spending categories, each with a bar
/// proportional to the top category's amount.
struct HomeTopSpendingCard: View {
    let items: [TopSpendingItem]

    private var maxAmountMinor: Int {
        items.map(\.amountMinor).max() ?? 1
    }

    var body: some View {
        DashboardCard {
            Text("Top Categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                ForEach(items) { item in
                    TopSpendingRow(
                        item: item,
                        fraction: maxAmountMinor > 0 ? Double(item.amountMinor) / Double(maxAmountMinor) : 0
                    )
                }
            }
            .padding(.top, 2)
        }
    }
}

private struct TopSpendingRow: View {
    let item: TopSpendingItem
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(iconKey: item.icon, colorHex: item.color, diameter: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(item.amountMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: fraction)
                    .tint(item.color.flatMap(Color.init(hex:)) ?? .verdigris)
            }
        }
    }
}

#Preview {
    HomeTopSpendingCard(items: [
        TopSpendingItem(categoryId: "1", name: "Groceries", icon: "shopping-cart", color: "#4f46e5", amountMinor: 12_400_00, txnCount: 14),
        TopSpendingItem(categoryId: "2", name: "Dining Out", icon: "utensils", color: "#b45309", amountMinor: 8_200_00, txnCount: 9),
        TopSpendingItem(categoryId: nil, name: "Uncategorized", icon: nil, color: nil, amountMinor: 3_100_00, txnCount: 4)
    ])
    .padding()
}
