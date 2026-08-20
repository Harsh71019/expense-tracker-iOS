import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Thin wrapper around the generated OpenAPI `Client`, pointed at
/// `AppEnvironment.apiBaseURL`. Auth is cookie-based (Better Auth session
/// cookie, not a bearer token — see `AuthClient`): this client's transport
/// uses `URLSession.shared` by default, the same cookie jar `AuthClient`
/// signs into, so the session cookie set at sign-in rides along
/// automatically on every request here.
enum APIClient {
    static let shared: Client = Client(
        serverURL: AppEnvironment.apiBaseURL,
        transport: URLSessionTransport(),
        middlewares: [OriginMiddleware()]
    )
}

/// Attaches the `Origin` header Better Auth's trusted-origins check expects
/// (see `AppEnvironment.apiOrigin`). Harmless on plain resource endpoints;
/// required on `/auth/*` routes.
struct OriginMiddleware: ClientMiddleware {
    nonisolated func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.init("Origin")!] = await AppEnvironment.apiOrigin
        return try await next(request, body, baseURL)
    }
}
