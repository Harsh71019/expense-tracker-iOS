import Foundation

struct Account: Identifiable, Decodable, Equatable, Hashable {
    enum Kind: String, Codable, Hashable, CaseIterable {
        case bank
        case creditCard = "credit_card"
        case cash, wallet, investment

        var displayName: String {
            switch self {
            case .bank: "Bank"
            case .creditCard: "Credit Card"
            case .cash: "Cash"
            case .wallet: "Wallet"
            case .investment: "Investment"
            }
        }

        var symbolName: String {
            switch self {
            case .bank: "building.columns.fill"
            case .creditCard: "creditcard.fill"
            case .cash: "banknote.fill"
            case .wallet: "wallet.pass.fill"
            case .investment: "chart.line.uptrend.xyaxis"
            }
        }
    }

    struct CreditCardConfig: Decodable, Equatable, Hashable {
        let statementDay: Int
        let dueDay: Int
        let nextStatementAt: Date?
    }

    let id: String
    let name: String
    let type: Kind
    var isArchived: Bool
    let balanceMinor: Int
    let creditCardConfig: CreditCardConfig?

    /// Rupees, derived from `balanceMinor` (paise) — same convention as
    /// `Transaction.amount`. Always INR — the backend is single-currency.
    var balance: Decimal {
        Decimal(balanceMinor) / 100
    }
}
