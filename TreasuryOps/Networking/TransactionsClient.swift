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
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Page.self, from: data)
    }

    /// `POST /v1/transactions` — creates a new transaction entry.
    static func create(
        accountId: String,
        categoryId: String?,
        type: Transaction.Kind,
        amountMinor: Int,
        occurredAt: Date,
        description: String,
        idempotencyKey: UUID
    ) async throws -> Transaction {
        struct RequestBody: Encodable {
            let accountId: String
            let categoryId: String?
            let type: Transaction.Kind
            let amountMinor: Int
            let occurredAt: Date
            let description: String
            let tags: [String]

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(accountId, forKey: .accountId)
                try container.encodeIfPresent(categoryId, forKey: .categoryId)
                try container.encode(type, forKey: .type)
                try container.encode(amountMinor, forKey: .amountMinor)
                try container.encode(occurredAt, forKey: .occurredAt)
                try container.encode(description, forKey: .description)
                try container.encode(tags, forKey: .tags)
            }

            private enum CodingKeys: String, CodingKey {
                case accountId, categoryId, type, amountMinor, occurredAt, description, tags
            }
        }

        var request = URLRequest(url: transactionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(
            RequestBody(
                accountId: accountId,
                categoryId: categoryId,
                type: type,
                amountMinor: amountMinor,
                occurredAt: occurredAt,
                description: description,
                tags: []
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Transaction.self, from: data)
    }

    static func get(id: String) async throws -> Transaction {
        var request = URLRequest(url: transactionsURL.appendingPathComponent(id))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Transaction.self, from: data)
    }

    /// `PATCH /v1/transactions/{id}`. Only `categoryId` is settable here —
    /// `nil` explicitly clears the category (encoded as JSON `null`, not
    /// omitted, so this can't be confused with "leave it unchanged").
    ///
    /// Requires an `Idempotency-Key` header — the controller parses it with
    /// `IdempotencyKeySchema.parse(key)`, and that schema is `z.string().uuid()`
    /// with no `.optional()`, so a missing header 400s even though the
    /// `@Headers` decorator itself marks the parameter optional.
    static func updateCategory(transactionId: String, categoryId: String?) async throws -> Transaction {
        struct RequestBody: Encodable {
            let categoryId: String?
        }
        var request = URLRequest(url: transactionsURL.appendingPathComponent(transactionId))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(RequestBody(categoryId: categoryId))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Transaction.self, from: data)
    }

    struct BatchCategorizeResult: Decodable {
        let transactionIds: [String]
        let categoryId: String
        let updatedCount: Int
    }

    /// `PATCH /v1/transactions` (no id — the batch form). Unlike
    /// `updateCategory`, `categoryId` here is required: the backend has no
    /// batch "uncategorize."
    static func batchAssignCategory(transactionIds: [String], categoryId: String) async throws -> BatchCategorizeResult {
        struct RequestBody: Encodable {
            let transactionIds: [String]
            let categoryId: String
        }
        var request = URLRequest(url: transactionsURL)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(RequestBody(transactionIds: transactionIds, categoryId: categoryId))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)
        return try JSONDecoder().decode(BatchCategorizeResult.self, from: data)
    }
}
