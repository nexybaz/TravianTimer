import SwiftUI
import AuthenticationServices

// MARK: - Auth View (Login / Register / Password Reset)

struct AuthView: View {

    @ObservedObject private var auth = AuthService.shared

    enum Mode {
        case signIn
        case signUp
        case resetRequest      // E-Mail eingeben für Reset
        case resetConfirm      // Code + neues Passwort eingeben
    }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var resetCode: String = ""
    @State private var newPassword: String = ""
    @State private var newPasswordConfirm: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                Spacer()

                // Logo / Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)

                    Text("TravianTimer")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 32)

                // Form
                VStack(spacing: 16) {

                    // --- Sign In / Sign Up ---
                    if mode == .signIn || mode == .signUp {
                        TextField("E-Mail", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        SecureField("Passwort", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if mode == .signUp {
                            SecureField("Passwort bestätigen", text: $passwordConfirm)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // --- Reset: E-Mail eingeben ---
                    if mode == .resetRequest {
                        TextField("E-Mail", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // --- Reset: Code + neues Passwort ---
                    if mode == .resetConfirm {
                        TextField("6-stelliger Code", text: $resetCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        SecureField("Neues Passwort", text: $newPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        SecureField("Neues Passwort bestätigen", text: $newPasswordConfirm)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Success
                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }

                    // Action Button
                    Button {
                        Task { await performAction() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.small)
                            }
                            Text(actionButtonLabel)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isFormValid || isLoading)

                    // Passwort vergessen (nur im Login-Modus)
                    if mode == .signIn {
                        Button {
                            withAnimation {
                                mode = .resetRequest
                                errorMessage = nil
                                successMessage = nil
                            }
                        } label: {
                            Text("Passwort vergessen?")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        // --- Apple Sign In ---
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color(.systemGray4))
                            Text("oder")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color(.systemGray4))
                        }
                        .padding(.vertical, 4)

                        SignInWithAppleButton(.signIn) { request in
                            let appleRequest = auth.prepareAppleSignInRequest()
                            request.requestedScopes = appleRequest.requestedScopes
                            request.nonce = appleRequest.nonce
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result: result) }
                        }
                        .signInWithAppleButtonStyle(
                            colorScheme == .dark ? .white : .black
                        )
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // --- Discord Sign In ---
                        Button {
                            Task { await handleDiscordSignIn() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 18))
                                Text("Mit Discord anmelden")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 88/255, green: 101/255, blue: 242/255)) // Discord Blurple #5865F2
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .frame(height: 50)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Bottom links
                HStack(spacing: 16) {
                    if mode == .signIn {
                        Button {
                            switchTo(.signUp)
                        } label: {
                            Text("Noch keinen Account? ") +
                            Text("Registrieren").fontWeight(.semibold)
                        }
                    } else if mode == .signUp {
                        Button {
                            switchTo(.signIn)
                        } label: {
                            Text("Schon einen Account? ") +
                            Text("Anmelden").fontWeight(.semibold)
                        }
                    } else {
                        // Reset modes
                        Button {
                            switchTo(.signIn)
                        } label: {
                            Text("Zurück zur ") +
                            Text("Anmeldung").fontWeight(.semibold)
                        }
                    }
                }
                .font(.footnote)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Computed

    private var headerSubtitle: String {
        switch mode {
        case .signIn, .signUp:
            return "Melde dich an, um deine Calls\nauf allen Geräten zu synchronisieren."
        case .resetRequest:
            return "Gib deine E-Mail ein, um einen\nReset-Code zu erhalten."
        case .resetConfirm:
            return "Gib den Code aus der E-Mail und\ndein neues Passwort ein."
        }
    }

    private var actionButtonLabel: String {
        switch mode {
        case .signIn: return "Anmelden"
        case .signUp: return "Registrieren"
        case .resetRequest: return "Reset-Code senden"
        case .resetConfirm: return "Passwort zurücksetzen"
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmailValid = trimmedEmail.contains("@") && trimmedEmail.contains(".")

        switch mode {
        case .signIn:
            return isEmailValid && password.count >= 6
        case .signUp:
            return isEmailValid && password.count >= 6 && password == passwordConfirm
        case .resetRequest:
            return isEmailValid
        case .resetConfirm:
            return !resetCode.isEmpty && newPassword.count >= 6 && newPassword == newPasswordConfirm
        }
    }

    // MARK: - Navigation

    private func switchTo(_ newMode: Mode) {
        withAnimation {
            mode = newMode
            errorMessage = nil
            successMessage = nil
            password = ""
            passwordConfirm = ""
            resetCode = ""
            newPassword = ""
            newPasswordConfirm = ""
        }
    }

    // MARK: - OAuth Sign In (Discord, Google)

    private func handleDiscordSignIn() async {
        await handleOAuthSignIn { await auth.startDiscordSignIn() }
    }

    private func handleOAuthSignIn(action: () async -> Result<Void, AuthError>) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let result = await action()

        await MainActor.run {
            isLoading = false
            switch result {
            case .success:
                break // isAuthenticated triggers navigation
            case .failure(let error):
                // User-Abbruch → kein Fehler anzeigen
                if error.errorDescription?.contains("Abgebrochen") == true {
                    return
                }
                errorMessage = error.errorDescription
            }
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                await MainActor.run {
                    errorMessage = "Ungültige Apple-Anmeldedaten"
                }
                return
            }

            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            let signInResult = await auth.handleAppleSignIn(credential: appleCredential)

            await MainActor.run {
                isLoading = false
                switch signInResult {
                case .success:
                    break // isAuthenticated triggers navigation
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }

        case .failure(let error):
            // User-Abbruch → kein Fehler anzeigen
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            await MainActor.run {
                errorMessage = "Apple-Anmeldung fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Actions

    private func performAction() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            successMessage = nil
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch mode {
        case .signUp:
            let result = await auth.signUp(email: trimmedEmail, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let msg):
                    successMessage = msg
                    if !auth.isAuthenticated {
                        mode = .signIn
                        password = ""
                        passwordConfirm = ""
                    }
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }

        case .signIn:
            let result = await auth.signIn(email: trimmedEmail, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }

        case .resetRequest:
            let result = await auth.sendPasswordReset(email: trimmedEmail)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Reset-Code gesendet! Prüfe deine E-Mail."
                    mode = .resetConfirm
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }

        case .resetConfirm:
            let result = await auth.verifyRecoveryAndSetPassword(
                email: trimmedEmail,
                code: resetCode.trimmingCharacters(in: .whitespacesAndNewlines),
                newPassword: newPassword
            )
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Passwort erfolgreich geändert! Du kannst dich jetzt anmelden."
                    mode = .signIn
                    password = ""
                    resetCode = ""
                    newPassword = ""
                    newPasswordConfirm = ""
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }
}
