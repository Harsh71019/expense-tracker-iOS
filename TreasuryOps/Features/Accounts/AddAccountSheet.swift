import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Returns `nil` on success (the sheet dismisses itself) or an error
    /// message to display inline.
    let onCreate: (String, Account.Kind, Int, AccountsClient.CreditCardConfigInput?) async -> String?

    @State private var name = ""
    @State private var type: Account.Kind = .bank
    @State private var openingBalanceText = ""
    @State private var statementDay = 1
    @State private var dueDay = 15
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(Account.Kind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    HStack {
                        Text("Opening Balance")
                        Spacer()
                        TextField("0.00", text: $openingBalanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if type == .creditCard {
                    Section {
                        Stepper("Statement Day: \(statementDay)", value: $statementDay, in: 1...31)
                        Stepper("Due Day: \(dueDay)", value: $dueDay, in: 1...31)
                    } header: {
                        Text("Billing Cycle")
                    } footer: {
                        Text("The day of the month your statement closes and your payment is due.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.signalAmber)
                    }
                }
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Add") { Task { await submit() } }
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        return openingBalanceText.isEmpty || Decimal(string: openingBalanceText) != nil
    }

    private var openingBalanceMinor: Int {
        guard !openingBalanceText.isEmpty, let decimal = Decimal(string: openingBalanceText) else { return 0 }
        return Int(truncating: NSDecimalNumber(decimal: decimal * 100))
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let creditCardConfig: AccountsClient.CreditCardConfigInput? = type == .creditCard
            ? AccountsClient.CreditCardConfigInput(statementDay: statementDay, dueDay: dueDay)
            : nil

        let failureMessage = await onCreate(
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            type,
            openingBalanceMinor,
            creditCardConfig
        )
        if let failureMessage {
            errorMessage = failureMessage
        } else {
            dismiss()
        }
    }
}

#Preview {
    AddAccountSheet(onCreate: { _, _, _, _ in nil })
}
