import Charts
import SwiftUI

struct AccountsView: View {
    @State private var model = AccountsModel()
    @State private var isShowingAddAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AccountsContent(model: model, onArchive: { account in
                        Task { await model.archive(account) }
                    })
                }
                .padding(16)
            }
            .swipeActionsContainer()
            .background(Color(.systemGroupedBackground))
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
            .refreshable { await model.refresh() }
            .task { await model.loadIfNeeded() }
        }
    }
}

/// Split out from `AccountsView` so its `.task`-driven loading states
/// don't also re-evaluate the toolbar/sheet/navigation wiring above.
private struct AccountsContent: View {
    let model: AccountsModel
    let onArchive: (Account) -> Void

    var body: some View {
        if model.isLoading && model.accounts.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let errorMessage = model.errorMessage, model.accounts.isEmpty {
            ContentUnavailableView(
                "Couldn't Load Accounts",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if model.accounts.isEmpty {
            ContentUnavailableView(
                "No Accounts Yet",
                systemImage: "building.columns",
                description: Text("Add an account to start tracking balances.")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            AccountsSummaryCard(accounts: model.activeAccounts, totalBalanceMinor: model.totalBalanceMinor)

            AccountCardsSection(
                title: "Accounts",
                accounts: model.activeAccounts,
                netTrendByAccountId: model.netTrendByAccountId,
                currentBillByAccountId: model.currentBillByAccountId,
                onArchive: onArchive
            )

            if model.archivedAccounts.isEmpty == false {
                AccountCardsSection(
                    title: "Archived",
                    accounts: model.archivedAccounts,
                    netTrendByAccountId: model.netTrendByAccountId,
                    currentBillByAccountId: model.currentBillByAccountId,
                    onArchive: nil
                )
            }
        }
    }
}

private struct AccountsSummaryCard: View {
    let accounts: [Account]
    let totalBalanceMinor: Int

    private var balanceByType: [(type: Account.Kind, balanceMinor: Int)] {
        Dictionary(grouping: accounts, by: \.type)
            .map { (type: $0.key, balanceMinor: $0.value.reduce(0) { $0 + $1.balanceMinor }) }
            .sorted { $0.balanceMinor > $1.balanceMinor }
    }

    var body: some View {
        DashboardCard {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalBalanceMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(totalBalanceMinor < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))

            if balanceByType.count > 1 {
                Chart(balanceByType, id: \.type) { item in
                    BarMark(
                        x: .value("Type", item.type.displayName),
                        y: .value("Balance", Double(item.balanceMinor) / 100)
                    )
                    .foregroundStyle(item.type.tint.gradient)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 140)
                .padding(.top, 4)
            }
        }
    }
}

private struct AccountCardsSection: View {
    let title: String
    let accounts: [Account]
    let netTrendByAccountId: [String: [Int]]
    let currentBillByAccountId: [String: Bill]
    let onArchive: ((Account) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(accounts) { account in
                    NavigationLink(value: account) {
                        AccountCard(
                            account: account,
                            netTrend: netTrendByAccountId[account.id] ?? [],
                            currentBill: currentBillByAccountId[account.id]
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        if let onArchive {
                            Button(role: .destructive) {
                                onArchive(account)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct AccountCard: View {
    let account: Account
    let netTrend: [Int]
    let currentBill: Bill?

    var body: some View {
        DashboardCard {
            HStack(spacing: 12) {
                Image(systemName: account.type.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(account.type.tint, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(account.balance, format: .currency(code: "INR"))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(account.balanceMinor < 0 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))

                DetailChevronBadge(diameter: 20)
            }

            if netTrend.count > 1 {
                Chart(Array(netTrend.enumerated()), id: \.offset) { index, value in
                    BarMark(x: .value("Month", index), y: .value("Net", Double(value) / 100))
                        .foregroundStyle(value >= 0 ? Color.green.gradient : Color.red.gradient)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 36)
                .padding(.top, 2)
            }

            if let currentBill {
                Divider()
                CurrentBillRow(bill: currentBill)
            }
        }
        .opacity(account.isArchived ? 0.55 : 1)
    }
}

private struct CurrentBillRow: View {
    let bill: Bill

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Bill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let dueDate = bill.dueDate {
                    Text("Due \(dueDate.formatted(.dateTime.day().month()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(bill.remainingMinor.minorUnitsAsDecimal, format: .currency(code: "INR"))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                PaymentStatusBadge(status: bill.paymentStatus)
            }
        }
    }
}

private struct PaymentStatusBadge: View {
    let status: Bill.PaymentStatus

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
    }

    private var text: String {
        switch status {
        case .unpaid: "Unpaid"
        case .partial: "Partially Paid"
        case .paid: "Paid"
        }
    }

    private var tint: Color {
        switch status {
        case .unpaid: .signalAmber
        case .partial: .verdigrisBright
        case .paid: .green
        }
    }
}

#Preview {
    AccountsView()
}
