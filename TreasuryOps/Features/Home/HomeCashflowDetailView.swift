import Charts
import SwiftUI

/// Which stat tile a `HomeCashflowDetailView` was opened from — determines
/// which of `CashflowResponse`'s two series (income/expense are both
/// present in every bucket) is the "primary" one totaled and charted.
enum HomeCashflowMetric: Hashable {
    case spent
    case income

    var title: String {
        switch self {
        case .spent: "Spent"
        case .income: "Income"
        }
    }

    var tint: Color {
        switch self {
        case .spent: .signalAmber
        case .income: .green
        }
    }
}

/// Pushed from a Spent/Income stat tile — a range-scoped detail chart in
/// the spirit of the Health app's per-metric screen, backed by
/// `/v1/dashboard/cashflow`.
struct HomeCashflowDetailView: View {
    let metric: HomeCashflowMetric

    @State private var range: DashboardClient.Range = .month
    @State private var cashflow: CashflowResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Range", selection: $range) {
                    Text("1W").tag(DashboardClient.Range.week)
                    Text("1M").tag(DashboardClient.Range.month)
                    Text("6M").tag(DashboardClient.Range.sixMonths)
                    Text("12M").tag(DashboardClient.Range.year)
                }
                .pickerStyle(.segmented)

                if let errorMessage, cashflow == nil {
                    ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if isLoading && cashflow == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let cashflow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(totalMinor(in: cashflow).minorUnitsAsDecimal, format: .currency(code: "INR"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(metric.tint)
                    }

                    Chart(cashflow.buckets) { bucket in
                        BarMark(
                            x: .value("Bucket", bucket.label),
                            y: .value(metric.title, Double(amountMinor(for: bucket)) / 100)
                        )
                        .foregroundStyle(metric.tint.gradient)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 220)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: range) { await load() }
    }

    private func amountMinor(for bucket: CashflowResponse.Bucket) -> Int {
        switch metric {
        case .spent: bucket.expenseMinor
        case .income: bucket.incomeMinor
        }
    }

    private func totalMinor(in cashflow: CashflowResponse) -> Int {
        cashflow.buckets.reduce(0) { $0 + amountMinor(for: $1) }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            cashflow = try await DashboardClient.cashflow(range: range)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        HomeCashflowDetailView(metric: .spent)
    }
}
