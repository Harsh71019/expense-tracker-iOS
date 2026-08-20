import Foundation

struct Category: Identifiable, Decodable, Equatable, Hashable {
    enum Kind: String, Decodable {
        case expense, income
    }

    let id: String
    let name: String
    let kind: Kind
    let icon: String?
    let isArchived: Bool
}
