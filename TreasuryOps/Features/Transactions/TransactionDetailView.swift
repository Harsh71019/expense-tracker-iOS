import Foundation
import SwiftUI

/// Pushed (not a drawer/sheet) when a transaction row is tapped — the
/// native equivalent of the web app's `TxnDetailDrawer`. Amount, type,
/// account, and date are immutable on the backend (corrections happen via
/// reverse & repost, not edit-in-place); category is the one thing this
/// screen lets you change, applied immediately on selection.
struct TransactionDetailView: View {
    let model: TransactionsModel

    @State private var transaction: Transaction
    @State private var categories: [Category] = []
    @State private var accountName: String?
    @State private var isUpdatingCategory = false
    @State private var showsUpdateConfirmation = false
    @State private var errorMessage: String?
    @State private var confirmationTask: Task<Void, Never>?

    init(transaction: Transaction, model: TransactionsModel) {
        _transaction = State(initialValue: transaction)
        self.model = model
    }

    var body: some View {
        List {
            Section {
                TransactionSummary(transaction: transaction)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                Picker("Category", selection: categoryBinding) {
                    Label("Uncategorized", systemImage: "questionmark.circle")
                        .tag(String?.none)
                    ForEach(matchingCategories) { category in
                        Label {
                            Text(category.name)
                        } icon: {
                            CategoryBadge(iconKey: category.icon, colorHex: category.color, diameter: 22)
                        }
                        .tag(Optional(category.id))
                    }
                }
                .disabled(isUpdatingCategory)
            } header: {
                Text("Category")
            } footer: {
                CategoryUpdateFooter(
                    isUpdating: isUpdatingCategory,
                    showsConfirmation: showsUpdateConfirmation,
                    errorMessage: errorMessage
                )
            }

            Section("Details") {
                LabeledContent("Account", value: accountName ?? "—")
                LabeledContent("Status", value: transaction.status.rawValue.capitalized)
                if !transaction.tags.isEmpty {
                    LabeledContent("Tags", value: transaction.tags.joined(separator: ", "))
                }
                if let counterpartyHandle = transaction.counterpartyHandle {
                    LabeledContent("Counterparty", value: counterpartyHandle)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(TransactionKindWash(kind: transaction.type))
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadOptions() }
    }

    /// Only categories of the same kind (expense/income) as the
    /// transaction are offered — matches the web app's create/edit forms,
    /// which filter categories by type for the same reason.
    private var matchingCategories: [Category] {
        categories.filter { $0.kind.rawValue == transaction.type.rawValue }
    }

    private var categoryBinding: Binding<String?> {
        Binding(
            get: { transaction.categoryId },
            set: { newCategoryId in
                Task { await updateCategory(to: newCategoryId) }
            }
        )
    }

    private func updateCategory(to categoryId: String?) async {
        guard categoryId != transaction.categoryId else { return }
        confirmationTask?.cancel()
        showsUpdateConfirmation = false
        isUpdatingCategory = true
        errorMessage = nil
        defer { isUpdatingCategory = false }
        do {
            let updated = try await TransactionsClient.updateCategory(
                transactionId: transaction.id,
                categoryId: categoryId
            )
            transaction = updated
            model.replace(updated)
            showConfirmationBriefly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A lightweight in-place "toast" rather than a floating overlay — it
    /// lives in the section footer right under the picker, so the
    /// confirmation appears exactly where the change was made.
    private func showConfirmationBriefly() {
        showsUpdateConfirmation = true
        confirmationTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            showsUpdateConfirmation = false
        }
    }

    private func loadOptions() async {
        async let categoriesResult: Result<[Category], Error> = Result { try await CategoriesClient.list() }
        async let accountsResult: Result<[Account], Error> = Result { try await AccountsClient.list() }

        switch await categoriesResult {
        case .success(let value):
            categories = value
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        switch await accountsResult {
        case .success(let value):
            accountName = value.first { $0.id == transaction.accountId }?.name
        case .failure(let error):
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }
}

private struct CategoryUpdateFooter: View {
    let isUpdating: Bool
    let showsConfirmation: Bool
    let errorMessage: String?

    var body: some View {
        Group {
            if isUpdating {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Updating…")
                }
            } else if showsConfirmation {
                Label("Category updated", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.signalAmber)
            }
        }
        .animation(.default, value: showsConfirmation)
        .animation(.default, value: isUpdating)
    }
}

/// A quiet income/expense tint behind the whole screen — green for money
/// in, red for money out. Deliberately faint (6% opacity): a hint, not a
/// colored panel.
private struct TransactionKindWash: View {
    let kind: Transaction.Kind

    var body: some View {
        (kind == .income ? Color.green : Color.red)
            .opacity(0.06)
            .ignoresSafeArea()
    }
}

private struct TransactionSummary: View {
    let transaction: Transaction

    var body: some View {
        VStack(spacing: 8) {
            Text(transaction.description)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(signedAmount, format: .currency(code: "INR").sign(strategy: .always()))
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(transaction.type == .income ? .green : .primary)

            if let occurredAt = transaction.occurredAt {
                Text(occurredAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var signedAmount: Decimal {
        transaction.type == .income ? transaction.amount : -transaction.amount
    }
}
