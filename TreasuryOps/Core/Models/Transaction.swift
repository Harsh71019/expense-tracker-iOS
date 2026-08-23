import Foundation

/// Mirrors the backend's `Transaction` shape (single currency: INR, amounts
/// as integer minor units/paise). Decoded by hand rather than through the
/// generated OpenAPI client — `TransactionPage.items` and the standalone
/// `Transaction` schema currently serialize as two structurally-identical
/// but separately-named schemas, so one hand-written type here is simpler
/// and more reliable than reconciling two generated ones.
struct Transaction: Identifiable, Decodable, Hashable {
    enum Kind: String, Codable, Hashable {
        case expense, income
    }

    enum Status: String, Decodable, Hashable {
        case posted, reversed, reversal
    }

    let id: String
    let accountId: String
    var categoryId: String?
    let type: Kind
    let amountMinor: Int
    let occurredAt: Date?
    let description: String
    let tags: [String]
    let status: Status
    let transferGroupId: String?
    let counterpartyHandle: String?

    /// Rupees, derived from `amountMinor` (paise). Always INR — the backend
    /// is single-currency.
    var amount: Decimal {
        Decimal(amountMinor) / 100
    }
}
