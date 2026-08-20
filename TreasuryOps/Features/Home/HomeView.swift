import SwiftUI

/// Placeholder landing screen for a signed-in user. Stands in for the real
/// dashboard until account/transaction features are built.
struct HomeView: View {
    @Environment(AuthModel.self) private var authModel

    var body: some View {
        NavigationStack {
            HomeWelcome(
                name: authModel.currentUser?.name,
                email: authModel.currentUser?.email
            )
            .navigationTitle("Home")
        }
    }
}

private struct HomeWelcome: View {
    let name: String?
    let email: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("You're signed in")
                .font(.title2)
                .fontWeight(.semibold)
            if let name, !name.isEmpty {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let email {
                Text(email)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    HomeView()
        .environment(AuthModel())
}
