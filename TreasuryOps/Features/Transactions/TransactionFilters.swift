import Foundation

/// Screen-local filter state for the transactions list. Mirrors the web
/// app's filter set (account, category, date range, tag) minus the amount
/// range and income/expense-type filters, which the web app doesn't have
/// either.
struct TransactionFilters: Equatable {
    var accountId: String?
    var categoryId: String?
    var tag: String = ""
    var dateRange: DateRangePreset = .allTime

    enum DateRangePreset: String, CaseIterable, Identifiable, Hashable {
        case allTime, thisMonth, last30Days, thisYear

        var id: Self { self }

        var label: String {
            switch self {
            case .allTime: "All Time"
            case .thisMonth: "This Month"
            case .last30Days: "Last 30 Days"
            case .thisYear: "This Year"
            }
        }

        /// The concrete `from`/`to` bounds for this preset, evaluated at
        /// call time — `nil` for `.allTime`, which sends no date filter.
        var bounds: (from: Date, to: Date)? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .allTime:
                return nil
            case .thisMonth:
                let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return (start, now)
            case .last30Days:
                let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                return (start, now)
            case .thisYear:
                let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
                return (start, now)
            }
        }
    }

    private var normalizedTag: String? {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var activeCount: Int {
        [accountId != nil, categoryId != nil, normalizedTag != nil, dateRange != .allTime]
            .filter { $0 }
            .count
    }

    var queryTag: String? { normalizedTag }
}
