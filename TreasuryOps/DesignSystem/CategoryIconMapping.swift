import Foundation

/// Maps `Category.icon` (a Lucide icon key from the web app's closed
/// `ICON_CHOICES` set — see `apps/web/src/features/categories/model/
/// icon-registry.ts` in the backend repo) to the closest SF Symbol. Icons
/// are shared data (a category picked in the web app must still render
/// something sensible here), not something this app gets to redefine.
enum CategoryIconMapping {
    private static let symbolNamesByIconKey: [String: String] = [
        "utensils": "fork.knife",
        "shopping-cart": "cart.fill",
        "utensils-crossed": "fork.knife.circle.fill",
        "car": "car.fill",
        "shopping-bag": "bag.fill",
        "zap": "bolt.fill",
        "home": "house.fill",
        "plane": "airplane",
        "film": "film.fill",
        "briefcase": "briefcase.fill",
        "percent": "percent",
        "laptop": "laptopcomputer",
        "coffee": "cup.and.saucer.fill",
        "dumbbell": "dumbbell.fill",
        "gift": "gift.fill",
        "graduation-cap": "graduationcap.fill",
        "heart-pulse": "heart.text.square.fill",
        "paw-print": "pawprint.fill",
        "piggy-bank": "banknote.fill",
        "receipt-text": "receipt",
        "smartphone": "iphone",
        "train": "tram.fill",
        "wrench": "wrench.fill",
        "baby": "figure.child"
    ]

    /// Falls back to a generic tag glyph for `nil` or any icon key added on
    /// the web side after this mapping was written.
    static func symbolName(for iconKey: String?) -> String {
        guard let iconKey, let symbolName = symbolNamesByIconKey[iconKey] else { return "tag.fill" }
        return symbolName
    }
}
