import SwiftUI

/// Placeholder tab. Stands in until real account balances/transactions are
/// wired up against the OpenAPI client.
struct AccountsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Accounts Yet",
                systemImage: "building.columns",
                description: Text("Account balances will show up here.")
            )
            .navigationTitle("Accounts")
        }
    }
}

#Preview {
    AccountsView()
}
