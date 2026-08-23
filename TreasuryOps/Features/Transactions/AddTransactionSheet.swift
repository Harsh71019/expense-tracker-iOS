import SwiftUI

/// Native counterpart of the web `CreateTxnSheet` / quick-add form.
/// Posts `POST /v1/transactions` with a stable `Idempotency-Key` for
/// the lifetime of this presentation so retrying a failed submit cannot
/// double-post.
struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialAccountId: String?
    let onCreated: () -> Void

    @State private var type: Transaction.Kind = .expense
    @State private var amountText = ""
    @State private var accountId: String?
    @State private var categoryId: String?
    @State private var descriptionText = ""
    @State private var occurredAt = Date()
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var isLoadingOptions = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var idempotencyKey: UUID

    init(initialAccountId: String? = nil, onCreated: @escaping () -> Void) {
        self.initialAccountId = initialAccountId
        self.onCreated = onCreated
        _idempotencyKey = State(initialValue: UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                TransactionKindSection(type: $type)

                AmountSection(amountText: $amountText, type: type)

                AccountSection(
                    accountId: $accountId,
                    accounts: activeAccounts,
                    isLoading: isLoadingOptions && accounts.isEmpty
                )

                DescriptionSection(text: $descriptionText)

                CategorySection(
                    categoryId: $categoryId,
                    categories: matchingCategories
                )

                DateSection(occurredAt: $occurredAt)

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.signalAmber)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Posting…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .onChange(of: type) {
                if let categoryId, matchingCategories.contains(where: { $0.id == categoryId }) == false {
                    self.categoryId = nil
                }
            }
            .task { await loadOptions() }
        }
    }

    private var activeAccounts: [Account] {
        accounts.filter { $0.isArchived == false }
    }

    private var matchingCategories: [Category] {
        categories.filter { $0.kind.rawValue == type.rawValue && $0.isArchived == false }
    }

    private var canSubmit: Bool {
        amountMinor != nil
            && accountId != nil
            && descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var amountMinor: Int? {
        RupeeInput.minorUnits(from: amountText)
    }

    private func loadOptions() async {
        isLoadingOptions = true
        defer { isLoadingOptions = false }
        async let accountsResult: Result<[Account], Error> = Result { try await AccountsClient.list() }
        async let categoriesResult: Result<[Category], Error> = Result { try await CategoriesClient.list() }

        switch await accountsResult {
        case .success(let value):
            accounts = value
            let active = value.filter { $0.isArchived == false }
            if let initialAccountId, active.contains(where: { $0.id == initialAccountId }) {
                accountId = initialAccountId
            } else if active.count == 1 {
                accountId = active.first?.id
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }

        switch await categoriesResult {
        case .success(let value):
            categories = value
        case .failure(let error):
            errorMessage = errorMessage ?? error.localizedDescription
        }
    }

    private func submit() async {
        guard let amountMinor, let accountId else { return }
        let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.isEmpty == false else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await TransactionsClient.create(
                accountId: accountId,
                categoryId: categoryId,
                type: type,
                amountMinor: amountMinor,
                occurredAt: occurredAt,
                description: description,
                idempotencyKey: idempotencyKey
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TransactionKindSection: View {
    @Binding var type: Transaction.Kind

    var body: some View {
        Section {
            Picker("Type", selection: $type) {
                Text("Expense").tag(Transaction.Kind.expense)
                Text("Income").tag(Transaction.Kind.income)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct AmountSection: View {
    @Binding var amountText: String
    let type: Transaction.Kind

    var body: some View {
        Section {
            HStack {
                Text(type == .income ? "+" : "−")
                    .foregroundStyle(type == .income ? .green : .secondary)
                    .font(.title2.weight(.semibold))
                Text("₹")
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.semibold).monospacedDigit())
            }
        } header: {
            Text("Amount")
        } footer: {
            Text("Amount, type, account, and date can't be edited after posting. Fix mistakes by reversing the entry.")
        }
    }
}

private struct AccountSection: View {
    @Binding var accountId: String?
    let accounts: [Account]
    let isLoading: Bool

    var body: some View {
        Section("Account") {
            if isLoading {
                ProgressView()
            } else if accounts.isEmpty {
                Text("No accounts yet. Add one on the web app first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Account", selection: $accountId) {
                    Text("Choose account").tag(String?.none)
                    ForEach(accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
            }
        }
    }
}

private struct DescriptionSection: View {
    @Binding var text: String

    var body: some View {
        Section("Description") {
            TextField("e.g. Dinner at Toit", text: $text, axis: .vertical)
                .lineLimit(1...3)
        }
    }
}

private struct CategorySection: View {
    @Binding var categoryId: String?
    let categories: [Category]

    var body: some View {
        Section("Category") {
            Picker("Category", selection: $categoryId) {
                Text("Uncategorized").tag(String?.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
        }
    }
}

private struct DateSection: View {
    @Binding var occurredAt: Date

    var body: some View {
        Section("Date & Time") {
            DatePicker("Date & Time", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
        }
    }
}

/// Parses a rupee string (`123`, `123.4`, `123.45`) into paise, matching
/// the backend `parseMinor` rule of at most two decimal places and a
/// strictly positive result.
private enum RupeeInput {
    static func minorUnits(from input: String) -> Int? {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard trimmed.isEmpty == false else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let rupeesPart = parts.first, rupeesPart.isEmpty == false else { return nil }
        guard let rupees = Int(rupeesPart), rupees >= 0 else { return nil }
        let paise: Int
        if parts.count == 2 {
            let fraction = String(parts[1])
            guard fraction.count <= 2, fraction.allSatisfy(\.isNumber) else { return nil }
            paise = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        } else {
            paise = 0
        }
        let minor = rupees * 100 + paise
        return minor >= 1 ? minor : nil
    }
}

#Preview {
    AddTransactionSheet(onCreated: {})
}
