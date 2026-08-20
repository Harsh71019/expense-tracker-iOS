import Foundation

/// `GET /v1/accounts` — a flat array, no pagination. Same hand-rolled
/// pattern as `AuthClient`/`TransactionsClient`.
enum AccountsClient {
    static func list() async throws -> [Account] {
        var request = URLRequest(url: AppEnvironment.apiBaseURL.appendingPathComponent("v1/accounts"))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)
        return try JSONDecoder().decode([Account].self, from: data)
    }
}
