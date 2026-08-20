import SwiftUI

/// A small circular icon badge for a category: the category's own color at
/// full saturation for the glyph, ~15% opacity for the fill — restrained
/// enough to sit inline in a list row, prominent enough to read at a
/// glance. Falls back to the app's verdigris accent when a category has no
/// color (or there's no category at all).
struct CategoryBadge: View {
    let iconKey: String?
    let colorHex: String?
    var diameter: CGFloat = 28

    var body: some View {
        let tint = colorHex.flatMap(Color.init(hex:)) ?? .verdigris
        Image(systemName: CategoryIconMapping.symbolName(for: iconKey))
            .font(.system(size: diameter * 0.46))
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .background(tint.opacity(0.15), in: .circle)
    }
}

#Preview {
    HStack(spacing: 12) {
        CategoryBadge(iconKey: "shopping-cart", colorHex: "#4f46e5")
        CategoryBadge(iconKey: "coffee", colorHex: "#b45309")
        CategoryBadge(iconKey: nil, colorHex: nil)
    }
    .padding()
}
