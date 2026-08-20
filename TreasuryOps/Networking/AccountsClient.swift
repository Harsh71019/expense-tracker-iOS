import Foundation

/// Talks to `/v1/accounts` directly via `URLSession.shared` — same
/// hand-rolled pattern as `AuthClient`/`TransactionsClient`.
enum AccountsClient {
    struct CreditCardConfigInput: Encodable {
        let statementDay: Int
        let dueDay: Int
    }

    private static var accountsURL: URL {
        AppEnvironment.apiBaseURL.appendingPathComponent("v1/accounts")
    }

    static func list() async throws -> [Account] {
        var request = URLRequest(url: accountsURL)
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        // `Account.creditCardConfig.nextStatementAt` is a Date — without
        // this, the default `.deferredToDate` strategy expects a numeric
        // timestamp and throws on the backend's ISO8601 string the moment
        // any account has a credit card config.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Account].self, from: data)
    }

    /// `POST /v1/accounts`. Requires an `Idempotency-Key` header, same as
    /// the batch/patch mutations in `TransactionsClient`.
    static func create(
        name: String,
        type: Account.Kind,
        openingBalanceMinor: Int,
        creditCardConfig: CreditCardConfigInput?
    ) async throws -> Account {
        struct RequestBody: Encodable {
            let name: String
            let type: Account.Kind
            let openingBalanceMinor: Int
            let creditCardConfig: CreditCardConfigInput?
        }
        var request = URLRequest(url: accountsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            name: name,
            type: type,
            openingBalanceMinor: openingBalanceMinor,
            creditCardConfig: creditCardConfig
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Account.self, from: data)
    }

    /// `PATCH /v1/accounts/{id}/archive` — 204 No Content, nothing to
    /// decode. One-way: there's no unarchive endpoint.
    static func archive(accountId: String) async throws {
        var request = URLRequest(url: accountsURL.appendingPathComponent(accountId).appendingPathComponent("archive"))
        request.httpMethod = "PATCH"
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)
    }
}
