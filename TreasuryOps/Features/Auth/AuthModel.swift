import Foundation
import Observation

@MainActor
@Observable
final class AuthModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private(set) var currentUser: AuthUser?

    var isSignedIn: Bool { currentUser != nil }

    var isEmailValid: Bool {
        (try? Self.emailPattern.wholeMatch(in: email)) != nil
    }

    private static let emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

    /// Called once at app launch to check whether the persisted session
    /// cookie (if any) is still valid, so a returning user skips the login
    /// screen without re-entering credentials.
    func restoreSession() async {
        currentUser = try? await AuthClient.currentSession()
    }

    func signIn() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            currentUser = try await AuthClient.signIn(email: email, password: password)
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        currentUser = nil
        try? await AuthClient.signOut()
    }
}
