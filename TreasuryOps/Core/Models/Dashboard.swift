import Foundation

/// Mirrors the backend's `/v1/dashboard/*` response shapes (see
/// `openapi.json`). Hand-decoded like `Transaction`/`Account` rather than
/// through the generated OpenAPI client, for the same reason: these are
/// small, stable, backend-owned shapes and a hand-written type is simpler
/// than reconciling the generator's output.

struct DashboardSummary: Decodable, Equatable {
    let totalBalanceMinor: Int
    let activeAccountCount: Int
    let assetsMinor: Int
    let liabilitiesMinor: Int
}

struct DashboardStats: Decodable, Equatable {
    struct MoneyStat: Decodable, Equatable {
        let valueMinor: Int
        let deltaPct: Double?
        let trend: [Int]
    }

    struct PercentStat: Decodable, Equatable {
        let valuePct: Double?
        let deltaPct: Double?
        let trend: [Double?]
    }

    let period: String
    let spent: MoneyStat
    let income: MoneyStat
    let savingsRate: PercentStat
    let netWorth: MoneyStat
}

struct RecentActivityItem: Identifiable, Decodable, Hashable {
    let id: String
    let accountId: String
    let accountName: String
    let categoryId: String?
    let type: Transaction.Kind
    let amountMinor: Int
    let description: String
    let occurredAt: Date?
    let tags: [String]
}

struct MonthlySpending: Decodable, Equatable, Hashable {
    struct DailyBucket: Decodable, Equatable, Hashable, Identifiable {
        let date: Date?
        let amountMinor: Int

        var id: Date { date ?? .distantPast }
    }

    struct WeeklyBucket: Decodable, Equatable, Hashable {
        let startAt: Date?
        let endAt: Date?
        let amountMinor: Int
    }

    let period: String
    let asOf: Date?
    let totalMinor: Int
    let daily: [DailyBucket]
    let weekly: [WeeklyBucket]
}

struct TopSpendingItem: Identifiable, Decodable, Equatable {
    let categoryId: String?
    let name: String
    let icon: String?
    let color: String?
    let amountMinor: Int
    let txnCount: Int

    /// The API only guarantees `categoryId` for real (non-"uncategorized")
    /// categories, so fall back to `name` — stable within one snapshot
    /// list, which is all `Identifiable` needs here.
    var id: String { categoryId ?? name }
}

struct CashflowResponse: Decodable, Equatable {
    struct Bucket: Decodable, Equatable, Hashable, Identifiable {
        let label: String
        let incomeMinor: Int
        let expenseMinor: Int

        var id: String { label }
    }

    let range: String
    let buckets: [Bucket]
}

struct SpendMix: Decodable, Equatable {
    struct Bucket: Decodable, Equatable {
        let amountMinor: Int
        let pct: Double
    }

    let range: String
    let totalMinor: Int
    let essential: Bucket
    let lifestyle: Bucket
    let uncategorized: Bucket
}

struct DashboardInvestments: Decodable, Equatable {
    let items: [DashboardInvestmentItem]
}

struct DashboardInvestmentItem: Identifiable, Decodable, Equatable {
    struct ValuationPoint: Decodable, Equatable, Hashable {
        let valuedAt: Date?
        let valueMinor: Int
    }

    let assetId: String
    let name: String
    let kind: String
    let currentValueMinor: Int
    let returnPct: Double?
    let series: [ValuationPoint]

    var id: String { assetId }
}

struct RecurringForecast: Decodable, Equatable {
    let range: String
    let inMinor: Int
    let outMinor: Int
    let netMinor: Int
    let upcoming: [RecurringForecastUpcomingItem]
}

struct RecurringForecastUpcomingItem: Identifiable, Decodable, Equatable {
    let ruleId: String
    let name: String
    let icon: String?
    let type: Transaction.Kind
    let amountMinor: Int
    let nextRunAt: Date?

    var id: String { ruleId }
}

