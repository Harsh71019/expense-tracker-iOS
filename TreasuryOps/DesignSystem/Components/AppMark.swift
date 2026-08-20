import SwiftUI

/// TreasuryOps' signature mark: three ledger lines of descending length —
/// an entry and its total — struck in a verdigris gradient inside a
/// Liquid Glass seal. Stands in for a bitmap logo; scales losslessly,
/// adapts to light/dark and Dynamic Type, and needs no image asset.
struct AppMark: View {
    var diameter: CGFloat = 84

    var body: some View {
        LedgerStrokes()
            .stroke(
                LinearGradient(
                    colors: [.verdigris, .verdigrisBright],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: diameter * 0.042, lineCap: .round)
            )
            .padding(diameter * 0.32)
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular.tint(.verdigris), in: .circle)
    }
}

/// Three horizontal strokes at 100%, 72%, and 45% width — a stylized
/// ledger entry, read top to bottom as a line item then its total.
/// Internal (not `private`) so other design-system views can reuse the
/// same motif at a different scale — see `LoginHero`'s background flourish.
struct LedgerStrokes: Shape {
    func path(in rect: CGRect) -> Path {
        let lineWidths: [CGFloat] = [1.0, 0.72, 0.45]
        let spacing = rect.height / CGFloat(lineWidths.count - 1)

        var path = Path()
        for (index, widthFraction) in lineWidths.enumerated() {
            let y = CGFloat(index) * spacing
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width * widthFraction, y: y))
        }
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        AppMark()
        AppMark(diameter: 56)
    }
    .padding(48)
}
