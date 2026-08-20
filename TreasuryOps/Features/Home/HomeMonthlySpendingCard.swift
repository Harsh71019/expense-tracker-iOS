import Charts
import SwiftUI

/// Full-width "this month so far" card: a big total plus a daily spend
/// bar chart, in the spirit of the Health app's per-metric detail screen.
struct HomeMonthlySpendingCard: View {
    let monthly: MonthlySpending

    var body: some View {
        NavigationLink(value: monthly) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        DashboardCard {
            HStack {
                Text("Spending This Month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(monthly.totalMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()

            if monthly.daily.isEmpty {
                Text("No spending recorded yet this month.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                Chart(monthly.daily) { day in
                    if let date = day.date {
                        BarMark(
                            x: .value("Day", date, unit: .day),
                            y: .value("Spent", Double(day.amountMinor) / 100)
                        )
                        .foregroundStyle(Color.verdigris.gradient)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.day())
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
                }
                .frame(height: 160)
                .padding(.top, 8)
            }
        }
    }
}

#Preview {
    HomeMonthlySpendingCard(
        monthly: MonthlySpending(
            period: "2026-08",
            asOf: .now,
            totalMinor: 42_500_00,
            daily: (1...20).map { day in
                .init(date: Calendar.current.date(byAdding: .day, value: day - 1, to: .now), amountMinor: Int.random(in: 0...5000) * 100)
            },
            weekly: []
        )
    )
    .padding()
}
