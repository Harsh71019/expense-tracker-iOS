import Foundation

extension Int {
    /// Converts minor units (paise) to a `Decimal` rupee amount for
    /// currency formatting — the same convention as `Transaction.amount`,
    /// lifted here since dashboard payloads carry several bare `*Minor`
    /// integers with no wrapping model of their own.
    var minorUnitsAsDecimal: Decimal {
        Decimal(self) / 100
    }
}
