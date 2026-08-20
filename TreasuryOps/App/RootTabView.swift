import SwiftUI

/// The signed-in app shell. Uses the `Tab`-based `TabView` initializer
/// rather than the soft-deprecated `.tabItem(_:)` — that's what actually
/// opts the bar into the system's floating Liquid Glass material; `.tabItem`
/// keeps rendering the old opaque bar even on OS releases that support the
/// new one.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Transactions", systemImage: "list.bullet.rectangle.fill") {
                TransactionsView()
            }
            Tab("Accounts", systemImage: "building.columns.fill") {
                AccountsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AuthModel())
}
