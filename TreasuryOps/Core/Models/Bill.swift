import Foundation

/// Mirrors a `BillPage` item from `GET /v1/bills` — one credit-card
/// billing cycle. Only what `AccountCard`'s "current bill" row needs is
/// decoded; the statement-reconciliation fields aren't used yet.
struct Bill: Identifiable, Decodable, Equatable {
    enum PaymentStatus: String, Decodable {
        case unpaid, partial, paid
    }

    let id: String
    let accountId: String
    let dueDate: Date?
    let remainingMinor: Int
    let paymentStatus: PaymentStatus
}
