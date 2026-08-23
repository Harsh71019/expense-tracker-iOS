import Charts
import SwiftUI

/// Dashboard card displaying investment holdings, current valuation, and return rates.
struct HomeInvestmentsCard: View {
    let investments: DashboardInvestments

    private var totalInvestmentsMinor: Int {
        investments.items.reduce(0) { $0 + $1.currentValueMinor }
    }

    var body: some View {
        DashboardCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Investments & Deposits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(totalInvestmentsMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                }
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(investments.items) { item in
                    InvestmentRow(item: item)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct InvestmentRow: View {
    let item: DashboardInvestmentItem

    var body: some View {
        HStack(spacing: 12) {
            InvestmentKindBadge(kind: item.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.currentValueMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                if let returnPct = item.returnPct {
                    InvestmentReturnBadge(returnPct: returnPct)
                }
            }
        }
    }
}

private struct InvestmentKindBadge: View {
    let kind: String

    var body: some View {
        Image(systemName: systemImageName)
            .font(.footnote)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(badgeGradient, in: .circle)
    }

    private var systemImageName: String {
        switch kind {
        case "fixed_deposit": "lock.shield.fill"
        default: "chart.line.uptrend.xyaxis"
        }
    }

    private var badgeGradient: LinearGradient {
        switch kind {
        case "fixed_deposit":
            return LinearGradient(colors: [.signalAmber, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.verdigris, .verdigrisBright], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct InvestmentReturnBadge: View {
    let returnPct: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: returnPct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(returnText)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(returnPct >= 0 ? .green : .red)
    }

    private var returnText: String {
        let formatted = abs(returnPct).formatted(.number.precision(.fractionLength(0...1)))
        return returnPct >= 0 ? "+\(formatted)%" : "-\(formatted)%"
    }
}

#Preview {
    HomeInvestmentsCard(
        investments: DashboardInvestments(items: [
            DashboardInvestmentItem(
                assetId: "1",
                name: "Nifty 50 Index Fund",
                kind: "investment",
                currentValueMinor: 350_000_00,
                returnPct: 14.8,
                series: []
            ),
            DashboardInvestmentItem(
                assetId: "2",
                name: "HDFC Fixed Deposit",
                kind: "fixed_deposit",
                currentValueMinor: 100_000_00,
                returnPct: 7.1,
                series: []
            )
        ])
    )
    .padding()
}
