import SwiftUI

/// The headline "Net Worth" tile — total balance plus its assets/
/// liabilities/account-count breakdown, in the same spirit as the Health
/// app's Activity Rings card: one big number, a few supporting stats.
struct HomeBalanceSummaryCard: View {
    let summary: DashboardSummary

    var body: some View {
        DashboardCard {
            Text("Net Worth")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(summary.totalBalanceMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(summary.totalBalanceMinor >= 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.red))

            HStack(spacing: 0) {
                BalanceStat(
                    label: "Assets",
                    value: summary.assetsMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                    tint: .green
                )
                Spacer()
                BalanceStat(
                    label: "Liabilities",
                    value: summary.liabilitiesMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                    tint: .signalAmber
                )
                Spacer()
                BalanceStat(
                    label: "Accounts",
                    value: summary.activeAccountCount.formatted(),
                    tint: .verdigris
                )
            }
            .padding(.top, 4)
        }
    }
}

private struct BalanceStat: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeBalanceSummaryCard(
        summary: DashboardSummary(totalBalanceMinor: 48_231_00, activeAccountCount: 3, assetsMinor: 62_000_00, liabilitiesMinor: 13_769_00)
    )
    .padding()
}
