import Foundation

/// Talks directly to Better Auth's REST routes (`/auth/sign-in/email`,
/// `/auth/sign-out`, `/auth/get-session`). These aren't in `openapi.json` —
/// Better Auth mounts its own router (`toNodeHandler`) outside the NestJS
/// controllers the spec is generated from, so there's no generated client
/// for them.
///
/// Uses `URLSession.shared` explicitly: `APIClient.shared`'s
/// `URLSessionTransport()` also defaults to `.shared`, so the
/// `better-auth.session_token` cookie set here rides along automatically on
/// every request made through `APIClient` afterward — no manual token
/// storage or header wiring needed.
enum AuthClient {
    private static var authBaseURL: URL {
        AppEnvironment.apiBaseURL.appendingPathComponent("auth")
    }

    static func signIn(email: String, password: String) async throws -> AuthUser {
        struct RequestBody: Encodable {
            let email: String
            let password: String
        }
        struct Response: Decodable {
            let user: AuthUser
        }
        let response: Response = try await post(
            "sign-in/email",
            body: RequestBody(email: email, password: password)
        )
        return response.user
    }

    static func signOut() async throws {
        try await post("sign-out")
    }

    /// Verifies the stored session cookie is still valid, returning the
    /// signed-in user if so. Better Auth responds with a literal JSON
    /// `null` body (not a 401) when there's no active session.
    static func currentSession() async throws -> AuthUser? {
        struct Response: Decodable {
            let user: AuthUser
        }
        var request = URLRequest(url: authBaseURL.appendingPathComponent("get-session"))
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "null", !data.isEmpty else { return nil }
        return try JSONDecoder().decode(Response.self, from: data).user
    }

    // MARK: - Plumbing

    private static func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: authBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func post(_ path: String) async throws {
        var request = URLRequest(url: authBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(AppEnvironment.apiOrigin, forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        let message = try? JSONDecoder().decode(BetterAuthErrorBody.self, from: data).message
        throw AuthError.server(status: http.statusCode, message: message)
    }
}

private struct BetterAuthErrorBody: Decodable {
    let message: String?
}

enum AuthError: LocalizedError {
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .server(let status, let message):
            return message ?? (status == 401
                ? "Incorrect email or password."
                : "Sign in failed. Please try again.")
        }
    }
}
