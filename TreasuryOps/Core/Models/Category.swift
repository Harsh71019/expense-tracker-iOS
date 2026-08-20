import Foundation

struct Category: Identifiable, Decodable, Equatable, Hashable {
    enum Kind: String, Decodable, Hashable {
        case expense, income
    }

    let id: String
    let name: String
    let kind: Kind
    let icon: String?
    /// Hex string (e.g. "#4f46e5") — see `Color.init(hex:)`.
    let color: String?
    let isArchived: Bool
}
