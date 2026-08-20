import Foundation

/// `GET /v1/categories` — a flat array, no pagination. Same hand-rolled
/// pattern as `AuthClient`/`TransactionsClient`.
enum CategoriesClient {
    static func list() async throws -> [Category] {
        var request = URLRequest(url: AppEnvironment.apiBaseURL.appendingPathComponent("v1/categories"))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAPIResponse(response, data: data)
        return try JSONDecoder().decode([Category].self, from: data)
    }
}
