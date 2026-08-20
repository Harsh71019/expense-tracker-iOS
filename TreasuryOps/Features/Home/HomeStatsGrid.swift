import Charts
import SwiftUI

/// The 2-column grid of stat tiles (Spent/Income/Savings Rate/Net Worth),
/// each with a trend sparkline — modeled on the Health app's Step Count/
/// Step Distance summary tiles.
struct HomeStatsGrid: View {
    let stats: DashboardStats

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            StatTile(
                title: "Spent",
                valueText: stats.spent.valueMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                deltaPct: stats.spent.deltaPct,
                trend: stats.spent.trend.map(Double.init),
                tint: .signalAmber
            )
            StatTile(
                title: "Income",
                valueText: stats.income.valueMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                deltaPct: stats.income.deltaPct,
                trend: stats.income.trend.map(Double.init),
                tint: .green
            )
            StatTile(
                title: "Savings Rate",
                valueText: stats.savingsRate.valuePct.formatted(.number.precision(.fractionLength(0))) + "%",
                deltaPct: stats.savingsRate.deltaPct,
                trend: stats.savingsRate.trend,
                tint: .verdigrisBright
            )
            StatTile(
                title: "Net Worth",
                valueText: stats.netWorth.valueMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                deltaPct: stats.netWorth.deltaPct,
                trend: stats.netWorth.trend.map(Double.init),
                tint: .verdigris
            )
        }
    }
}

private struct StatTile: View {
    let title: String
    let valueText: String
    let deltaPct: Double?
    let trend: [Double]
    let tint: Color

    var body: some View {
        DashboardCard {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(valueText)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let deltaPct {
                DeltaBadge(deltaPct: deltaPct)
            }

            if trend.count > 1 {
                Chart(Array(trend.enumerated()), id: \.offset) { index, value in
                    BarMark(x: .value("Point", index), y: .value("Value", value))
                        .foregroundStyle(tint.gradient)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 36)
            }
        }
    }
}

private struct DeltaBadge: View {
    let deltaPct: Double

    var body: some View {
        Label(deltaText, systemImage: deltaPct >= 0 ? "arrow.up.right" : "arrow.down.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(deltaPct >= 0 ? .green : .red)
    }

    private var deltaText: String {
        let magnitude = abs(deltaPct).formatted(.number.precision(.fractionLength(0...1)))
        return deltaPct >= 0 ? "+\(magnitude)%" : "-\(magnitude)%"
    }
}

#Preview {
    HomeStatsGrid(
        stats: DashboardStats(
            period: "2026-08",
            spent: .init(valueMinor: 42_500_00, deltaPct: 8.4, trend: [3200, 4100, 2800, 5300, 4700, 3900, 6100]),
            income: .init(valueMinor: 95_000_00, deltaPct: 2.1, trend: [95000, 95000, 95000, 95000]),
            savingsRate: .init(valuePct: 24.6, deltaPct: -3.2, trend: [30, 28, 26, 24.6]),
            netWorth: .init(valueMinor: 480_231_00, deltaPct: 5.6, trend: [420000, 435000, 452000, 480231])
        )
    )
    .padding()
}
