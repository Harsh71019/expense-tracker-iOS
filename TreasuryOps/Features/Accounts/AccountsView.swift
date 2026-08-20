import SwiftUI

struct AccountsView: View {
    @State private var model = AccountsModel()
    @State private var isShowingAddAccount = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.accounts.isEmpty {
                    ProgressView()
                } else if let errorMessage = model.errorMessage, model.accounts.isEmpty {
                    ContentUnavailableView(
                        "Couldn't Load Accounts",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if model.accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts Yet",
                        systemImage: "building.columns",
                        description: Text("Add an account to start tracking balances.")
                    )
                } else {
                    AccountsList(model: model, onArchive: { account in
                        Task { await model.archive(account) }
                    })
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Account")
                }
            }
            .sheet(isPresented: $isShowingAddAccount) {
                AddAccountSheet { name, type, openingBalanceMinor, creditCardConfig in
                    await model.createAccount(
                        name: name,
                        type: type,
                        openingBalanceMinor: openingBalanceMinor,
                        creditCardConfig: creditCardConfig
                    )
                }
            }
            .navigationDestination(for: Account.self) { account in
                TransactionsScreen(
                    initialFilters: TransactionFilters(accountId: account.id),
                    title: account.name
                )
            }
            .task { await model.loadIfNeeded() }
        }
    }
}

private struct AccountsList: View {
    let model: AccountsModel
    let onArchive: (Account) -> Void

    var body: some View {
        List {
            Section {
                AccountsSummaryRow(totalBalanceMinor: model.totalBalanceMinor)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Accounts") {
                ForEach(model.activeAccounts) { account in
                    NavigationLink(value: account) {
                        AccountRow(account: account)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onArchive(account)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }

            if model.archivedAccounts.isEmpty == false {
                Section("Archived") {
                    ForEach(model.archivedAccounts) { account in
                        NavigationLink(value: account) {
                            AccountRow(account: account)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.refresh() }
    }
}

private struct AccountsSummaryRow: View {
    let totalBalanceMinor: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(totalBalanceMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(totalBalanceMinor < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.verdigris, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(account.balance, format: .currency(code: "INR"))
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(account.balanceMinor < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        }
        .padding(.vertical, 2)
        .opacity(account.isArchived ? 0.5 : 1)
    }

    private var subtitle: String {
        guard let creditCardConfig = account.creditCardConfig else { return account.type.displayName }
        return "Statement day \(creditCardConfig.statementDay) · Due day \(creditCardConfig.dueDay)"
    }
}

#Preview {
    AccountsView()
}
