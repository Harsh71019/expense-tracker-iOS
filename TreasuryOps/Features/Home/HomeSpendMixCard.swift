import SwiftUI

/// Essential vs. lifestyle vs. uncategorized spend as a segmented bar with
/// a legend — a stacked-proportion meter, not a per-point chart, so it's
/// built by hand rather than with Swift Charts.
struct HomeSpendMixCard: View {
    let mix: SpendMix

    var body: some View {
        DashboardCard {
            Text("Essential vs. Lifestyle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SpendMixBar(
                essentialPct: mix.essential.pct,
                lifestylePct: mix.lifestyle.pct,
                uncategorizedPct: mix.uncategorized.pct
            )
            .padding(.top, 4)

            VStack(spacing: 8) {
                SpendMixLegendRow(label: "Essential", color: .verdigris, bucket: mix.essential)
                SpendMixLegendRow(label: "Lifestyle", color: .verdigrisBright, bucket: mix.lifestyle)
                SpendMixLegendRow(label: "Uncategorized", color: Color.secondary.opacity(0.35), bucket: mix.uncategorized)
            }
            .padding(.top, 6)
        }
    }
}

private struct SpendMixBar: View {
    let essentialPct: Double
    let lifestylePct: Double
    let uncategorizedPct: Double

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                segment(essentialPct, .verdigris, width: proxy.size.width)
                segment(lifestylePct, .verdigrisBright, width: proxy.size.width)
                segment(uncategorizedPct, Color.secondary.opacity(0.35), width: proxy.size.width)
            }
        }
        .frame(height: 14)
        .clipShape(.capsule)
    }

    private func segment(_ pct: Double, _ color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width * pct / 100))
    }
}

private struct SpendMixLegendRow: View {
    let label: String
    let color: Color
    let bucket: SpendMix.Bucket

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.footnote)
            Spacer()
            Text(bucket.amountMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(bucket.pct.formatted(.number.precision(.fractionLength(0))) + "%")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

#Preview {
    HomeSpendMixCard(
        mix: SpendMix(
            range: "1M",
            totalMinor: 42_500_00,
            essential: .init(amountMinor: 24_000_00, pct: 56.5),
            lifestyle: .init(amountMinor: 15_000_00, pct: 35.3),
            uncategorized: .init(amountMinor: 3_500_00, pct: 8.2)
        )
    )
    .padding()
}
