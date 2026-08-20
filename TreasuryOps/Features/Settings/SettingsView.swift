import SwiftUI

struct SettingsView: View {
    @Environment(AuthModel.self) private var authModel

    var body: some View {
        NavigationStack {
            List {
                if let user = authModel.currentUser {
                    Section {
                        AccountRow(name: user.name, email: user.email)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await authModel.signOut() }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct AccountRow: View {
    let name: String
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.headline)
            Text(email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthModel())
}
