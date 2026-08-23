import Foundation

/// `GET /v1/bills` — scoped to one account per call. Used only to surface
/// a credit-card account's current bill; the statement-reconciliation
/// endpoints under `/v1/bills/{id}/...` aren't wired up yet.
enum BillsClient {
    private struct Page: Decodable {
        let items: [Bill]
    }

    static func list(accountId: String, limit: Int = 3) async throws -> [Bill] {
        var components = URLComponents(
            url: AppEnvironment.apiBaseURL.appendingPathComponent("v1/bills"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "accountId", value: accountId),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Page.self, from: data).items
    }
}
