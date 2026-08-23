import Foundation
import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Returns `nil` on success (the sheet dismisses itself) or an error
    /// message to display inline. `idempotencyKey` is generated once per
    /// sheet presentation (not per attempt) so a retry after a lost
    /// response replays the same logical request instead of risking a
    /// duplicate account.
    let onCreate: (String, Account.Kind, Int, AccountsClient.CreditCardConfigInput?, String) async -> String?

    @State private var name = ""
    @State private var type: Account.Kind = .bank
    @State private var openingBalanceText = ""
    @State private var statementDay = 1
    @State private var dueDay = 15
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var idempotencyKey = UUID().uuidString

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
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
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
        return openingBalanceMinorIfValid != nil
    }

    /// `nil` for empty input (treated as a zero opening balance) or text
    /// that doesn't parse; also `nil` when the value has sub-paise
    /// precision (e.g. "0.001"), which `Int(truncating:)` would otherwise
    /// silently round away instead of rejecting.
    private var openingBalanceMinorIfValid: Int? {
        guard !openingBalanceText.isEmpty else { return 0 }
        guard let decimal = Decimal(string: openingBalanceText) else { return nil }

        let scaled = decimal * 100
        var rounded = Decimal()
        var mutableScaled = scaled
        NSDecimalRound(&rounded, &mutableScaled, 0, .plain)
        guard rounded == scaled else { return nil }

        return Int(truncating: NSDecimalNumber(decimal: rounded))
    }

    private func submit() async {
        guard !isSubmitting, let openingBalanceMinor = openingBalanceMinorIfValid else { return }
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
            creditCardConfig,
            idempotencyKey
        )
        if let failureMessage {
            errorMessage = failureMessage
        } else {
            dismiss()
        }
    }
}

#Preview {
    AddAccountSheet(onCreate: { _, _, _, _, _ in nil })
}
