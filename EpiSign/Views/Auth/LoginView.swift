import SwiftUI

enum LoginMode {
    case magicLink
    case password
}

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var magicLinkSent = false
    @State private var loginMode: LoginMode = .password
    @State private var isSignUp = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("EpiSign")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Signature de présence")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if magicLinkSent {
                magicLinkSentView
            } else {
                VStack(spacing: 16) {
                    // Email field
                    TextField("Adresse email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($emailFocused)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)

                    // Password field (password mode only)
                    if loginMode == .password {
                        SecureField("Mot de passe", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .font(.body)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundStyle(.white)
                    }

                    // Primary action button
                    Button {
                        Task { await primaryAction() }
                    } label: {
                        Text(primaryButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule().fill(canSubmit ? Color.white : Color.white.opacity(0.3))
                            )
                            .foregroundStyle(canSubmit ? .black : .white.opacity(0.5))
                    }
                    .disabled(!canSubmit)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Toggle sign up / sign in
                    if loginMode == .password {
                        Button {
                            isSignUp.toggle()
                            auth.errorMessage = nil
                        } label: {
                            Text(isSignUp ? "Déjà un compte ? Se connecter" : "Pas de compte ? S'inscrire")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    // Switch between magic link and password
                    Button {
                        loginMode = loginMode == .password ? .magicLink : .password
                        auth.errorMessage = nil
                    } label: {
                        Text(loginMode == .password ? "Utiliser un lien magique" : "Utiliser un mot de passe")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Text("EPITA — Projet iOS M1")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 20)
        }
        .background(Color.black)
        .onAppear { emailFocused = true }
    }

    // MARK: - Subviews

    private var magicLinkSentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            Text("Lien envoyé !")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Vérifiez votre boîte mail\n\(email)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                magicLinkSent = false
            } label: {
                Text("Retour")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Logic

    private var primaryButtonTitle: String {
        switch loginMode {
        case .magicLink: return "Recevoir le lien de connexion"
        case .password: return isSignUp ? "S'inscrire" : "Se connecter"
        }
    }

    private var canSubmit: Bool {
        let validEmail = email.contains("@") && email.contains(".")
        if loginMode == .password {
            return validEmail && password.count >= 6
        }
        return validEmail
    }

    private func primaryAction() async {
        switch loginMode {
        case .magicLink:
            await auth.signInWithMagicLink(email: email)
            if auth.errorMessage == nil {
                magicLinkSent = true
            }
        case .password:
            if isSignUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
