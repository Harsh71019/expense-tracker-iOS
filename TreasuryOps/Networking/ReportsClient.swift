import Foundation

/// `GET /v1/reports/monthly/{month}` — one request covers every account's
/// net movement for that month at once, which is why `AccountsModel` fans
/// this out per-month (6 requests) rather than per-account.
enum ReportsClient {
    static func monthlyRollup(month: String) async throws -> MonthlyRollup {
        var request = URLRequest(url: AppEnvironment.apiBaseURL.appendingPathComponent("v1/reports/monthly/\(month)"))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MonthlyRollup.self, from: data)
    }
}
