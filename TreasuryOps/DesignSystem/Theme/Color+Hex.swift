import SwiftUI

extension Color {
    /// Parses a `#rrggbb` hex string (the shape `Category.color` comes in
    /// from the backend). Returns `nil` for anything else rather than a
    /// wrong color — callers should fall back to a themed default.
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
