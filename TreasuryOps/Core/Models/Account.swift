import Foundation

struct Account: Identifiable, Decodable, Equatable, Hashable {
    enum Kind: String, Decodable {
        case bank
        case creditCard = "credit_card"
        case cash, wallet, investment
    }

    let id: String
    let name: String
    let type: Kind
    let isArchived: Bool
}
