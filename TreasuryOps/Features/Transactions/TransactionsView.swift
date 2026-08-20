import Foundation
import SwiftUI

struct TransactionsView: View {
    @State private var model = TransactionsModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.transactions.isEmpty {
                    ProgressView()
                } else if model.transactions.isEmpty {
                    if model.searchText.isEmpty {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Transactions will show up here.")
                        )
                    } else {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                } else {
                    TransactionList(model: model)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $model.searchText, prompt: "Search transactions")
            .task { await model.loadFirstPageIfNeeded() }
        }
    }
}

private struct TransactionList: View {
    let model: TransactionsModel

    var body: some View {
        List {
            ForEach(model.transactions) { transaction in
                TransactionRow(transaction: transaction)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
