import Charts
import SwiftUI

/// Full-screen version of `HomeMonthlySpendingCard` — same already-fetched
/// `MonthlySpending` payload, just given room to breathe, plus the weekly
/// buckets the card itself has no space to show.
struct HomeMonthlySpendingDetailView: View {
    let monthly: MonthlySpending

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(monthly.totalMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                if monthly.daily.isEmpty == false {
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
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                            AxisGridLine()
                        }
                    }
                    .frame(height: 220)
                }

                if monthly.weekly.isEmpty == false {
                    DashboardCard {
                        Text("By Week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            ForEach(Array(monthly.weekly.enumerated()), id: \.offset) { index, week in
                                WeekRow(index: index, week: week)
                                if index != monthly.weekly.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Spending This Month")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeekRow: View {
    let index: Int
    let week: MonthlySpending.WeeklyBucket

    var body: some View {
        HStack {
            Text("Week \(index + 1)")
                .font(.subheadline)
            if let startAt = week.startAt, let endAt = week.endAt {
                Text(startAt, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(endAt, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(week.amountMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.subheadline)
                .monospacedDigit()
        }
    }
}

#Preview {
    NavigationStack {
        HomeMonthlySpendingDetailView(
            monthly: MonthlySpending(
                period: "2026-08",
                asOf: .now,
                totalMinor: 42_500_00,
                daily: (1...20).map { day in
                    .init(date: Calendar.current.date(byAdding: .day, value: day - 1, to: .now), amountMinor: Int.random(in: 0...5000) * 100)
                },
                weekly: (0..<3).map { week in
                    .init(
                        startAt: Calendar.current.date(byAdding: .day, value: week * 7, to: .now),
                        endAt: Calendar.current.date(byAdding: .day, value: week * 7 + 6, to: .now),
                        amountMinor: Int.random(in: 5000...20000) * 100
                    )
                }
            )
        )
    }
}
