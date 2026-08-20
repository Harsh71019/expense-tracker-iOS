import SwiftUI

struct LoginView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                LoginHeader()

                // Headline and form share this one leading-aligned container
                // — same padding, same width cap — so the headline's left
                // edge always lines up with the input cards below it,
                // instead of drifting apart on wider screens.
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sign in to your ledger")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)

                    LoginForm()
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LoginBackground())
    }
}

private struct LoginHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            AppMark(diameter: 64)
            Text("TreasuryOps")
                .font(.system(.title2, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.verdigris, .verdigrisBright],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.top, 40)
    }
}

/// Gradient wash, faint ruled-paper texture, and two soft color blooms —
/// Liquid Glass blurs and refracts whatever sits behind it, and a flat
/// color gives it nothing to show. This gives the glass cards real light
/// and texture to catch, the way it does in Apple's own material.
private struct LoginBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.verdigris.opacity(0.32), .ledgerPaper, .ledgerPaper],
                startPoint: .top,
                endPoint: .bottom
            )

            LedgerRulePattern()
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)

            Circle()
                .fill(Color.verdigrisBright.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -110, y: -220)

            Circle()
                .fill(Color.verdigris.opacity(0.30))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 130, y: 80)
        }
        .ignoresSafeArea()
    }
}

/// Ruled-paper hairlines, evenly spaced top to bottom — the texture is the
/// pattern Liquid Glass needs to visibly blur, and it's on-theme with the
/// ledger mark rather than a decorative dot grid.
private struct LedgerRulePattern: Shape {
    var spacing: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}

private struct LoginForm: View {
    @Environment(AuthModel.self) private var authModel
    @FocusState private var focusedField: Field?
    @State private var isEmailConfirmed = false
    @Namespace private var glassNamespace

    private enum Field {
        case email, password
    }

    var body: some View {
        @Bindable var authModel = authModel

        VStack(alignment: .leading, spacing: 16) {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    TextField("Email", text: $authModel.email, prompt: Text("Email"))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .onSubmit(confirmEmail)
                        .submitLabel(.next)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .glassEffectID("email", in: glassNamespace)

                    if isEmailConfirmed {
                        SecureField("Password", text: $authModel.password, prompt: Text("Password"))
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .onSubmit(submit)
                            .submitLabel(.go)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            .glassEffectID("password", in: glassNamespace)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }

            if let errorMessage = authModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.signalAmber)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity)
            }

            Button(action: isEmailConfirmed ? submit : confirmEmail) {
                if authModel.isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isEmailConfirmed ? "Sign In" : "Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!canProceed)
        }
        .animation(.default, value: authModel.errorMessage)
        .animation(.default, value: isEmailConfirmed)
        .onAppear { focusedField = .email }
    }

    private var canProceed: Bool {
        guard !authModel.isSubmitting else { return false }
        guard isEmailConfirmed else { return authModel.isEmailValid }
        return authModel.isEmailValid && !authModel.password.isEmpty
    }

    private func confirmEmail() {
        guard authModel.isEmailValid else { return }
        isEmailConfirmed = true
        focusedField = .password
    }

    private func submit() {
        guard canProceed else { return }
        focusedField = nil
        Task { await authModel.signIn() }
    }
}

#Preview {
    LoginView()
        .environment(AuthModel())
}
