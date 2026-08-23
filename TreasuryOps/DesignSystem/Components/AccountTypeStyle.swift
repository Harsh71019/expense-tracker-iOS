import SwiftUI

/// Chart/badge tint per account type. Kept here rather than on
/// `Account.Kind` itself — `Core/Models` stays SwiftUI-free, the same
/// reason `Category.color` is a hex string parsed via `Color+Hex` at the
/// view layer instead of stored as a `Color` on the model.
extension Account.Kind {
    var tint: Color {
        switch self {
        case .bank: .verdigris
        case .creditCard: .signalAmber
        case .cash: .green
        case .wallet: .verdigrisBright
        case .investment: .blue
        }
    }
}
