import SwiftUI
import AuthenticationServices

// MARK: - Auth View

struct AuthView: View {

    @Environment(AuthService.self) var authService

    enum Mode {
        case signIn
        case signUp
        case resetPassword
    }

    enum Field: Hashable {
        case playerName, email, password, passwordConfirm
    }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var playerName: String = ""
    @State private var successMessage: String? = nil

    // Validation state (shown after field loses focus)
    @State private var showEmailError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var showConfirmError: Bool = false
    @State private var showNameError: Bool = false

    // Haptic triggers
    @State private var hapticSuccess: Bool = false
    @State private var hapticError: Bool = false

    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    Spacer().frame(height: 20)

                    // MARK: Header
                    headerSection

                    // MARK: Form
                    formSection

                    // MARK: Messages
                    messagesSection

                    // MARK: Primary Button
                    primaryButton

                    // MARK: Passwort vergessen (nur bei Sign-In)
                    if mode == .signIn {
                        forgotPasswordLink
                    }

                    // MARK: Divider + Apple Sign-In (nur bei Sign-In / Sign-Up)
                    if mode != .resetPassword {
                        dividerSection
                        appleSignInSection
                    }

                    Spacer().frame(height: 12)

                    // MARK: Mode Toggle
                    modeToggle

                    // MARK: Datenschutz-Links
                    if mode != .resetPassword {
                        legalLinksSection
                    }

                    // MARK: Version
                    versionLabel
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .disabled(authService.isLoading)
            .sensoryFeedback(.success, trigger: hapticSuccess)
            .sensoryFeedback(.error, trigger: hapticError)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("TravianTimer")
                .font(.largeTitle.bold())

            Text(modeTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modeTitle: String {
        switch mode {
        case .signIn:        return "Anmelden"
        case .signUp:        return "Neuen Account erstellen"
        case .resetPassword: return "Passwort zurücksetzen"
        }
    }

    // MARK: - Form Fields

    private var formSection: some View {
        VStack(spacing: 4) {
            // Spielername (nur bei Registrierung)
            if mode == .signUp {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Spielername", text: $playerName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .playerName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                        .onChange(of: focusedField) { _, newField in
                            if newField != .playerName && playerName.isEmpty {
                                showNameError = true
                            } else if newField == .playerName {
                                showNameError = false
                            }
                        }

                    if showNameError && playerName.isEmpty {
                        validationHint("Spielername erforderlich")
                    }
                }
            }

            // E-Mail
            VStack(alignment: .leading, spacing: 2) {
                TextField("E-Mail", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .email)
                    .submitLabel(mode == .resetPassword ? .go : .next)
                    .onSubmit {
                        if mode == .resetPassword {
                            Task { await performPrimaryAction() }
                        } else {
                            focusedField = .password
                        }
                    }
                    .onChange(of: focusedField) { _, newField in
                        if newField != .email && !email.isEmpty && !isEmailValid {
                            showEmailError = true
                        } else if newField == .email {
                            showEmailError = false
                        }
                    }

                if showEmailError && !email.isEmpty && !isEmailValid {
                    validationHint("Ungültige E-Mail-Adresse")
                }
            }

            // Passwort (nicht bei Reset)
            if mode != .resetPassword {
                VStack(alignment: .leading, spacing: 2) {
                    SecureField("Passwort", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .submitLabel(mode == .signUp ? .next : .go)
                        .onSubmit {
                            if mode == .signUp {
                                focusedField = .passwordConfirm
                            } else {
                                Task { await performPrimaryAction() }
                            }
                        }
                        .onChange(of: focusedField) { _, newField in
                            if newField != .password && !password.isEmpty && password.count < 6 {
                                showPasswordError = true
                            } else if newField == .password {
                                showPasswordError = false
                            }
                        }

                    if showPasswordError && !password.isEmpty && password.count < 6 {
                        validationHint("Mindestens 6 Zeichen")
                    }

                    // Passwort-Stärke (nur bei Registrierung)
                    if mode == .signUp && !password.isEmpty {
                        passwordStrengthIndicator
                    }
                }
            }

            // Passwort bestätigen (nur bei Registrierung)
            if mode == .signUp {
                VStack(alignment: .leading, spacing: 2) {
                    SecureField("Passwort bestätigen", text: $passwordConfirm)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .passwordConfirm)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await performPrimaryAction() }
                        }
                        .onChange(of: focusedField) { _, newField in
                            if newField != .passwordConfirm && !passwordConfirm.isEmpty && password != passwordConfirm {
                                showConfirmError = true
                            } else if newField == .passwordConfirm {
                                showConfirmError = false
                            }
                        }

                    if showConfirmError && !passwordConfirm.isEmpty && password != passwordConfirm {
                        validationHint("Passwörter stimmen nicht überein")
                    }
                }
            }
        }
    }

    // MARK: - Validation Hint

    private func validationHint(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.leading, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: text)
    }

    // MARK: - Password Strength Indicator

    private var passwordStrengthIndicator: some View {
        let strength = passwordStrength
        return HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < strength.level ? strength.color : Color(.systemGray4))
                    .frame(height: 3)
            }
            Text(strength.label)
                .font(.caption2)
                .foregroundStyle(strength.color)
        }
        .padding(.top, 2)
        .animation(.easeInOut(duration: 0.2), value: password)
    }

    private var passwordStrength: (level: Int, label: String, color: Color) {
        let len = password.count
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil
        let variety = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count

        if len < 6 { return (1, "Zu kurz", .red) }
        if len < 8 && variety < 2 { return (1, "Schwach", .red) }
        if len < 10 && variety < 3 { return (2, "Mittel", .orange) }
        if len >= 10 && variety >= 3 { return (3, "Stark", .yellow) }
        if len >= 12 && variety >= 3 { return (4, "Sehr stark", .green) }
        return (2, "Mittel", .orange)
    }

    // MARK: - Email Validation

    private var isEmailValid: Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Messages

    private var messagesSection: some View {
        VStack(spacing: 4) {
            if let error = authService.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let success = successMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(success)
                        .font(.caption)
                }
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: successMessage)
    }

    // MARK: - Primary Action Button

    private var primaryButton: some View {
        Button {
            focusedField = nil
            Task { await performPrimaryAction() }
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(!isFormValid)
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .signIn:        return "Anmelden"
        case .signUp:        return "Registrieren"
        case .resetPassword: return "Link senden"
        }
    }

    private var isFormValid: Bool {
        switch mode {
        case .signIn:
            return isEmailValid && password.count >= 6
        case .signUp:
            return isEmailValid && password.count >= 6 && password == passwordConfirm && !playerName.trimmingCharacters(in: .whitespaces).isEmpty
        case .resetPassword:
            return isEmailValid
        }
    }

    private func performPrimaryAction() async {
        successMessage = nil
        authService.errorMessage = nil

        switch mode {
        case .signIn:
            await authService.signIn(email: email, password: password)
            if authService.isAuthenticated {
                hapticSuccess.toggle()
            } else if authService.errorMessage != nil {
                hapticError.toggle()
            }

        case .signUp:
            await authService.signUp(email: email, password: password, playerName: playerName)
            if authService.errorMessage == nil && !authService.isAuthenticated {
                successMessage = "Bestätigungs-Mail gesendet! Bitte E-Mail prüfen."
                hapticSuccess.toggle()
            } else if authService.errorMessage != nil {
                hapticError.toggle()
            }

        case .resetPassword:
            let success = await authService.sendPasswordReset(email: email)
            if success {
                successMessage = "Reset-Link gesendet! Bitte E-Mail prüfen."
                hapticSuccess.toggle()
            } else {
                hapticError.toggle()
            }
        }
    }

    // MARK: - Forgot Password Link

    private var forgotPasswordLink: some View {
        Button("Passwort vergessen?") {
            withAnimation {
                mode = .resetPassword
                authService.errorMessage = nil
                successMessage = nil
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Divider

    private var dividerSection: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Text("oder")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
    }

    // MARK: - Apple Sign-In

    private var appleSignInSection: some View {
        SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
            let appleRequest = authService.prepareAppleSignInRequest()
            request.requestedScopes = appleRequest.requestedScopes
            request.nonce = appleRequest.nonce
        } onCompletion: { result in
            Task {
                await authService.handleAppleSignIn(result: result)
                if authService.isAuthenticated {
                    hapticSuccess.toggle()
                } else if authService.errorMessage != nil {
                    hapticError.toggle()
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 44)
        .cornerRadius(8)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 4) {
            Text(modeToggleQuestion)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(modeToggleAction) {
                withAnimation {
                    switch mode {
                    case .signIn:        mode = .signUp
                    case .signUp:        mode = .signIn
                    case .resetPassword: mode = .signIn
                    }
                    authService.errorMessage = nil
                    successMessage = nil
                    resetValidation()
                }
            }
            .font(.footnote.bold())
            .foregroundStyle(.orange)
        }
    }

    private var modeToggleQuestion: String {
        switch mode {
        case .signIn:        return "Noch keinen Account?"
        case .signUp:        return "Schon einen Account?"
        case .resetPassword: return "Passwort fällt dir wieder ein?"
        }
    }

    private var modeToggleAction: String {
        switch mode {
        case .signIn:        return "Registrieren"
        case .signUp:        return "Anmelden"
        case .resetPassword: return "Zurück zur Anmeldung"
        }
    }

    private func resetValidation() {
        showEmailError = false
        showPasswordError = false
        showConfirmError = false
        showNameError = false
    }

    // MARK: - Legal Links

    private var legalLinksSection: some View {
        HStack(spacing: 16) {
            Link("Datenschutz", destination: URL(string: "https://traviantimer.app/datenschutz")!)
            Link("Nutzungsbedingungen", destination: URL(string: "https://traviantimer.app/nutzungsbedingungen")!)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: - Version

    private var versionLabel: some View {
        Text(appVersion)
            .font(.caption2)
            .foregroundStyle(.quaternary)
            .padding(.bottom, 8)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}
