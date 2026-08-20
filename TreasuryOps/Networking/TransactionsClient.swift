import Foundation

/// Talks to `/v1/transactions` directly via `URLSession.shared` — same
/// approach as `AuthClient`, for the same reason: predictable decoding
/// against the verified JSON shape, sidestepping the generated OpenAPI
/// client's currently-divergent `Transaction` / `TransactionPage.items`
/// types (see `Transaction.swift`).
enum TransactionsClient {
    struct Page: Decodable {
        let items: [Transaction]
        let pageInfo: PageInfo
    }

    struct PageInfo: Decodable {
        let nextCursor: String?
        let hasMore: Bool
        let limit: Int
    }

    private static var transactionsURL: URL {
        AppEnvironment.apiBaseURL.appendingPathComponent("v1/transactions")
    }

    static func list(
        accountId: String? = nil,
        categoryId: String? = nil,
        query: String? = nil,
        tag: String? = nil,
        from: Date? = nil,
        to: Date? = nil,
        cursor: String? = nil,
        limit: Int = 50
    ) async throws -> Page {
        var components = URLComponents(url: transactionsURL, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let accountId { queryItems.append(URLQueryItem(name: "accountId", value: accountId)) }
        if let categoryId { queryItems.append(URLQueryItem(name: "categoryId", value: categoryId)) }
        if let query, !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        if let from { queryItems.append(URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: from))) }
        if let to { queryItems.append(URLQueryItem(name: "to", value: ISO8601DateFormatter().string(from: to))) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Page.self, from: data)
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        throw URLError(.badServerResponse)
    }
}
