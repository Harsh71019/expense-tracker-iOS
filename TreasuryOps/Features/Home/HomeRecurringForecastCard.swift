import SwiftUI

/// Dashboard card displaying upcoming recurring expense & income forecasts.
struct HomeRecurringForecastCard: View {
    let forecast: RecurringForecast

    var body: some View {
        DashboardCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recurring Obligations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(forecast.outMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text("upcoming")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 0) {
                ForecastStat(
                    label: "Expected In",
                    value: forecast.inMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                    tint: .green
                )
                Spacer()
                ForecastStat(
                    label: "Expected Out",
                    value: forecast.outMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                    tint: .signalAmber
                )
                Spacer()
                ForecastStat(
                    label: "Net Flow",
                    value: forecast.netMinor.minorUnitsAsDecimal.formatted(.currency(code: "INR").notation(.compactName)),
                    tint: forecast.netMinor >= 0 ? .green : .red
                )
            }
            .padding(.top, 2)

            if !forecast.upcoming.isEmpty {
                VStack(spacing: 10) {
                    ForEach(forecast.upcoming.prefix(4)) { item in
                        RecurringUpcomingRow(item: item)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct ForecastStat: View {
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

private struct RecurringUpcomingRow: View {
    let item: RecurringForecastUpcomingItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type == .income ? "arrow.down.left" : "arrow.up.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(item.type == .income ? .green : .signalAmber)
                .frame(width: 24, height: 24)
                .background(item.type == .income ? Color.green.opacity(0.12) : Color.signalAmber.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)

                if let nextRunAt = item.nextRunAt {
                    Text(nextRunAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.amountMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.type == .income ? .green : .primary)
        }
    }
}

#Preview {
    HomeRecurringForecastCard(
        forecast: RecurringForecast(
            range: "1M",
            inMinor: 95_000_00,
            outMinor: 32_400_00,
            netMinor: 62_600_00,
            upcoming: [
                RecurringForecastUpcomingItem(
                    ruleId: "1",
                    name: "House Rent",
                    icon: "house",
                    type: .expense,
                    amountMinor: 25_000_00,
                    nextRunAt: .now.addingTimeInterval(86400 * 3)
                ),
                RecurringForecastUpcomingItem(
                    ruleId: "2",
                    name: "Internet Fiber",
                    icon: "wifi",
                    type: .expense,
                    amountMinor: 1_400_00,
                    nextRunAt: .now.addingTimeInterval(86400 * 7)
                ),
                RecurringForecastUpcomingItem(
                    ruleId: "3",
                    name: "Salary",
                    icon: "banknote",
                    type: .income,
                    amountMinor: 95_000_00,
                    nextRunAt: .now.addingTimeInterval(86400 * 10)
                )
            ]
        )
    )
    .padding()
}
