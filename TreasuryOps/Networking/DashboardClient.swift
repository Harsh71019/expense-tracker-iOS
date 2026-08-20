import Foundation

/// Talks to `/v1/dashboard/*` directly via `URLSession.shared` — same
/// hand-rolled pattern as `AccountsClient`/`TransactionsClient`.
enum DashboardClient {
    /// Ranges accepted by the range-scoped endpoints (`top-spending`,
    /// `spend-mix`, `cashflow`).
    enum Range: String {
        case week = "1W"
        case month = "1M"
        case sixMonths = "6M"
        case year = "12M"
    }

    static func summary() async throws -> DashboardSummary {
        try await get("v1/dashboard/summary")
    }

    static func stats(period: String? = nil) async throws -> DashboardStats {
        try await get("v1/dashboard/stats", queryItems: period.map { [URLQueryItem(name: "period", value: $0)] } ?? [])
    }

    static func recentActivity(limit: Int = 10) async throws -> [RecentActivityItem] {
        try await get("v1/dashboard/recent-activity", queryItems: [URLQueryItem(name: "limit", value: String(limit))])
    }

    static func monthlySpending() async throws -> MonthlySpending {
        try await get("v1/dashboard/monthly-spending")
    }

    static func topSpending(range: Range, limit: Int = 5) async throws -> [TopSpendingItem] {
        try await get("v1/dashboard/top-spending", queryItems: [
            URLQueryItem(name: "range", value: range.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ])
    }

    static func spendMix(range: Range) async throws -> SpendMix {
        try await get("v1/dashboard/spend-mix", queryItems: [URLQueryItem(name: "range", value: range.rawValue)])
    }

    private static func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(
            url: AppEnvironment.apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
