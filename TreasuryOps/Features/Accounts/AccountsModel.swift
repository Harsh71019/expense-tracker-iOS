import Foundation
import Observation

@MainActor
@Observable
final class AccountsModel {
    private(set) var accounts: [Account] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var archivedAccounts: [Account] {
        accounts.filter(\.isArchived)
    }

    var totalBalanceMinor: Int {
        activeAccounts.reduce(0) { $0 + $1.balanceMinor }
    }

    func loadIfNeeded() async {
        guard accounts.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            accounts = try await AccountsClient.list()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns `nil` on success, the server's error message on failure —
    /// lets the caller (a creation sheet) show the actual reason rather
    /// than a generic fallback.
    func createAccount(
        name: String,
        type: Account.Kind,
        openingBalanceMinor: Int,
        creditCardConfig: AccountsClient.CreditCardConfigInput?
    ) async -> String? {
        do {
            let account = try await AccountsClient.create(
                name: name,
                type: type,
                openingBalanceMinor: openingBalanceMinor,
                creditCardConfig: creditCardConfig
            )
            accounts.append(account)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Optimistic — flips `isArchived` locally so the row leaves the
    /// active list immediately, and rolls back if the request fails.
    func archive(_ account: Account) async {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].isArchived = true
        do {
            try await AccountsClient.archive(accountId: account.id)
        } catch {
            accounts[index].isArchived = false
            errorMessage = error.localizedDescription
        }
    }
}
