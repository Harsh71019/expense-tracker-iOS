import Foundation

/// `GET /v1/categories` — a flat array, no pagination. Same hand-rolled
/// pattern as `AuthClient`/`TransactionsClient`.
enum CategoriesClient {
    static func list() async throws -> [Category] {
        var request = URLRequest(url: AppEnvironment.apiBaseURL.appendingPathComponent("v1/categories"))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Category].self, from: data)
    }
}
