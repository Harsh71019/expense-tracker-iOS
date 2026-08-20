import SwiftUI

struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TransactionFilters
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var isLoadingOptions = false

    private let onApply: (TransactionFilters) -> Void

    init(filters: TransactionFilters, onApply: @escaping (TransactionFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Picker("Date Range", selection: $draft.dateRange) {
                        ForEach(TransactionFilters.DateRangePreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Account") {
                    Picker("Account", selection: $draft.accountId) {
                        Text("All Accounts").tag(String?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    if isLoadingOptions && accounts.isEmpty {
                        ProgressView()
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $draft.categoryId) {
                        Text("All Categories").tag(String?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    if isLoadingOptions && categories.isEmpty {
                        ProgressView()
                    }
                }

                Section("Tag") {
                    TextField("Tag", text: $draft.tag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset Filters", role: .destructive) {
                        draft = TransactionFilters()
                    }
                    .disabled(draft == TransactionFilters())
                }
            }
            .task { await loadOptions() }
        }
    }

    private func loadOptions() async {
        guard accounts.isEmpty, categories.isEmpty else { return }
        isLoadingOptions = true
        defer { isLoadingOptions = false }
        async let accountsResult = try? AccountsClient.list()
        async let categoriesResult = try? CategoriesClient.list()
        accounts = await accountsResult ?? []
        categories = await categoriesResult ?? []
    }
}

#Preview {
    TransactionFilterSheet(filters: TransactionFilters()) { _ in }
}
