import Foundation
import SwiftUI

struct TransactionsView: View {
    @State private var model = TransactionsModel()
    @State private var isShowingFilters = false
    @State private var selectedIDs: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var isShowingBatchAssign = false
    @State private var isAssigningCategory = false
    @State private var batchErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.transactions.isEmpty {
                    ProgressView()
                } else if model.transactions.isEmpty {
                    if model.searchText.isEmpty && model.filters.activeCount == 0 {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Transactions will show up here.")
                        )
                    } else if model.searchText.isEmpty {
                        ContentUnavailableView(
                            "No Matching Transactions",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try widening your filters.")
                        )
                    } else {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                } else {
                    TransactionList(model: model, selectedIDs: $selectedIDs)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $model.searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: model.filters.activeCount > 0
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode.isEditing {
                        Text(selectedIDs.isEmpty ? "Select Transactions" : "\(selectedIDs.count) Selected")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isAssigningCategory {
                            ProgressView()
                        } else {
                            Button("Assign Category") {
                                isShowingBatchAssign = true
                            }
                            .disabled(selectedIDs.isEmpty || selectedKind == nil)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $isShowingFilters) {
                TransactionFilterSheet(filters: model.filters) { newFilters in
                    Task { await model.applyFilters(newFilters) }
                }
            }
            .sheet(isPresented: $isShowingBatchAssign) {
                if let selectedKind {
                    BatchCategoryAssignSheet(
                        categories: model.categories,
                        kind: selectedKind,
                        selectedCount: selectedIDs.count
                    ) { category in
                        Task { await assignCategory(category) }
                    }
                }
            }
            .alert(
                "Couldn't Assign Category",
                isPresented: Binding(
                    get: { batchErrorMessage != nil },
                    set: { isPresented in if !isPresented { batchErrorMessage = nil } }
                ),
                presenting: batchErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .navigationDestination(for: Transaction.self) { transaction in
                TransactionDetailView(transaction: transaction, model: model)
            }
            .task {
                await model.loadFirstPageIfNeeded()
                await model.loadCategoriesIfNeeded()
            }
            // A reload (search/filter/pull-to-refresh) can drop, reorder,
            // or replace rows entirely — any selection made before it no
            // longer reliably refers to what's now on screen.
            .onChange(of: model.reloadCount) {
                selectedIDs = []
            }
        }
    }

    /// The common expense/income kind across the current selection, or
    /// `nil` if nothing's selected or the selection mixes both — bulk
    /// category assignment is only offered when every selected transaction
    /// shares one kind, since a category itself is always one or the other.
    private var selectedKind: Transaction.Kind? {
        let kinds = Set(model.transactions.filter { selectedIDs.contains($0.id) }.map(\.type))
        return kinds.count == 1 ? kinds.first : nil
    }

    private func assignCategory(_ category: Category) async {
        // The onChange(of: model.reloadCount) handler clears selectedIDs
        // on any reload, but a reload can still land in the narrow window
        // between opening the assign sheet and tapping a category. Re-check
        // here rather than trust the selection is still what's on screen —
        // if anything selected has disappeared, reject the whole batch
        // instead of silently sending a set the person never actually saw.
        let ids = selectedIDs
        let currentIDs = Set(model.transactions.map(\.id))
        guard !ids.isEmpty, ids.isSubset(of: currentIDs) else {
            batchErrorMessage = "Your selection changed. Please reselect and try again."
            selectedIDs = []
            editMode = .inactive
            return
        }

        isAssigningCategory = true
        defer { isAssigningCategory = false }
        do {
            _ = try await TransactionsClient.batchAssignCategory(
                transactionIds: Array(ids),
                categoryId: category.id
            )
            model.applyBatchCategoryUpdate(transactionIds: ids, categoryId: category.id)
            selectedIDs = []
            editMode = .inactive
        } catch {
            batchErrorMessage = error.localizedDescription
        }
    }
}

private struct BatchCategoryAssignSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let kind: Transaction.Kind
    let selectedCount: Int
    let onAssign: (Category) -> Void

    var body: some View {
        NavigationStack {
            List(matchingCategories) { category in
                Button {
                    onAssign(category)
                    dismiss()
                } label: {
                    Label {
                        Text(category.name)
                            .foregroundStyle(.primary)
                    } icon: {
                        CategoryBadge(iconKey: category.icon, colorHex: category.color, diameter: 22)
                    }
                }
            }
            .navigationTitle("Assign to \(selectedCount) Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var matchingCategories: [Category] {
        categories.filter { $0.kind.rawValue == kind.rawValue }
    }
}

private struct TransactionList: View {
    let model: TransactionsModel
    @Binding var selectedIDs: Set<String>

    var body: some View {
        // Computed once per body evaluation, not once per row — `ForEach`
        // re-runs this closure for every visible transaction, and rebuilding
        // the whole categories dictionary that often would be wasted work.
        let categoriesById = model.categoriesById

        List(selection: $selectedIDs) {
            ForEach(model.transactions) { transaction in
                TransactionRow(
                    transaction: transaction,
                    category: transaction.categoryId.flatMap { categoriesById[$0] }
                )
                .task { await model.loadMoreIfNeeded(currentItem: transaction) }
            }

            if model.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    let category: Category?

    var body: some View {
        NavigationLink(value: transaction) {
            switch transaction.status {
            case .reversed:
                content
                    .strikethrough()
                    .opacity(0.5)
            case .posted, .reversal:
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(alignment: .firstTextBaseline) {
            CategoryBadge(iconKey: category?.icon, colorHex: category?.color)
                .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.body)
                    .lineLimit(1)
                if let occurredAt = transaction.occurredAt {
                    Text(occurredAt, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(signedAmount, format: .currency(code: "INR").sign(strategy: .always()))
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(transaction.type == .income ? .green : .primary)
        }
        .padding(.vertical, 4)
    }

    private var signedAmount: Decimal {
        transaction.type == .income ? transaction.amount : -transaction.amount
    }
}

#Preview {
    TransactionsView()
}
