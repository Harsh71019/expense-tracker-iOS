import SwiftUI

/// The rounded, elevated card shell every Home dashboard tile sits in.
/// Each caller composes its own heading/value/chart inside — this only
/// owns the shared padding and background.
struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The small circular chevron every tappable dashboard tile/row shows —
/// an explicit "this leads somewhere" signal (mirrors the Health app's
/// Summary cards), so it should only ever appear on a view that's actually
/// wrapped in a working `NavigationLink`, never decoratively.
struct DetailChevronBadge: View {
    var diameter: CGFloat = 24

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: diameter * 0.42, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: diameter, height: diameter)
            .background(Color(.tertiarySystemFill), in: .circle)
    }
}
