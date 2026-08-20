import Foundation

struct AuthUser: Identifiable, Decodable, Equatable {
    let id: String
    let email: String
    let name: String
    let emailVerified: Bool
}
