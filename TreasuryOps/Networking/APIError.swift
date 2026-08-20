import Foundation

/// Surfaces the backend's RFC 7807 Problem Details body (see `ProblemDetails`
/// in openapi.json) instead of a bare status code — every hand-rolled
/// client's `validate` should throw this so failures are actually
/// diagnosable instead of collapsing into a generic "could not do X".
struct APIError: LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { message }
}

func validateAPIResponse(_ response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
    if let problem = try? JSONDecoder().decode(ProblemDetailsBody.self, from: data), !problem.message.isEmpty {
        throw APIError(status: http.statusCode, message: problem.message)
    }
    throw APIError(status: http.statusCode, message: "Request failed (\(http.statusCode)).")
}

private struct ProblemDetailsBody: Decodable {
    let message: String
}
