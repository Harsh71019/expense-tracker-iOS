import Foundation

/// Mirrors `GET /v1/reports/monthly/{month}` — only the `byAccount` slice
/// is decoded; `byCategory`/`totalExpenseMinor`/etc. aren't used yet.
struct MonthlyRollup: Decodable {
    struct AccountNet: Decodable {
        let accountId: String
        let netMinor: Int
    }

    let month: String
    let byAccount: [AccountNet]
}
