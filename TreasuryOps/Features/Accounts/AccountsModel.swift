import Foundation
import Observation

@MainActor
@Observable
final class AccountsModel {
    private(set) var accounts: [Account] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Last 6 months' net movement per account, oldest first — from
    /// `MonthlyRollup.byAccount`, fanned out one request per month (not
    /// per account: each month's rollup already covers every account).
    private(set) var netTrendByAccountId: [String: [Int]] = [:]

    /// Most recent bill per credit-card account, keyed by accountId —
    /// only fetched for accounts of type `.creditCard`.
    private(set) var currentBillByAccountId: [String: Bill] = [:]

    /// Bumped on every `refresh()` so a slower, earlier call can't
    /// overwrite a newer one's results if it completes out of order.
    private var refreshGeneration = 0

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
        refreshGeneration += 1
        let generation = refreshGeneration

        isLoading = true
        errorMessage = nil
        defer {
            if generation == refreshGeneration { isLoading = false }
        }
        do {
            async let accountsResult = AccountsClient.list()
            async let trendResult = Self.loadNetTrend()
            let (accounts, trend) = try await (accountsResult, trendResult)

            let creditCardAccountIds = accounts.filter { $0.type == .creditCard }.map(\.id)
            let bills = await Self.loadCurrentBills(accountIds: creditCardAccountIds)

            guard generation == refreshGeneration else { return }
            self.accounts = accounts
            self.netTrendByAccountId = trend
            self.currentBillByAccountId = bills
        } catch {
            guard generation == refreshGeneration else { return }
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

    private static func loadNetTrend() async throws -> [String: [Int]] {
        let months = last6Months()
        let rollups = try await withThrowingTaskGroup(of: (Int, MonthlyRollup).self) { group -> [MonthlyRollup] in
            for (index, month) in months.enumerated() {
                group.addTask { (index, try await ReportsClient.monthlyRollup(month: month)) }
            }
            var byIndex: [Int: MonthlyRollup] = [:]
            for try await (index, rollup) in group {
                byIndex[index] = rollup
            }
            return months.indices.compactMap { byIndex[$0] }
        }

        var trend: [String: [Int]] = [:]
        for rollup in rollups {
            for accountNet in rollup.byAccount {
                trend[accountNet.accountId, default: []].append(accountNet.netMinor)
            }
        }
        return trend
    }

    /// Best-effort: a bill fetch failing for one account (or all of them)
    /// shouldn't block the rest of the account list from showing.
    private static func loadCurrentBills(accountIds: [String]) async -> [String: Bill] {
        guard !accountIds.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, Bill?).self) { group in
            for accountId in accountIds {
                group.addTask {
                    let bills = (try? await BillsClient.list(accountId: accountId)) ?? []
                    let mostRecent = bills.max { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
                    return (accountId, mostRecent)
                }
            }
            var result: [String: Bill] = [:]
            for await (accountId, bill) in group {
                if let bill { result[accountId] = bill }
            }
            return result
        }
    }

    private static func last6Months(endingAt date: Date = .now) -> [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return (0..<6).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: date).map(formatter.string(from:))
        }
    }
}
