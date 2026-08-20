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
    @State private var errorMessage: String?

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
                    Text("Uncategorized").tag(String?.none)
                    ForEach(matchingCategories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                .disabled(isUpdatingCategory)
            } header: {
                Text("Category")
            } footer: {
                if isUpdatingCategory {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Updating…")
                    }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.signalAmber)
                }
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
        } catch {
            errorMessage = error.localizedDescription
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
