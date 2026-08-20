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
