import SwiftUI

/// Switches between the login screen and the signed-in app based on
/// `AuthModel.isSignedIn`, and checks for a still-valid session cookie once
/// at launch so a returning user isn't asked to sign in again.
struct RootView: View {
    @Environment(AuthModel.self) private var authModel
    @State private var hasCheckedSession = false

    var body: some View {
        Group {
            if !hasCheckedSession {
                ProgressView()
            } else if authModel.isSignedIn {
                RootTabView()
            } else {
                LoginView()
            }
        }
        .task {
            guard !hasCheckedSession else { return }
            await authModel.restoreSession()
            hasCheckedSession = true
        }
    }
}
