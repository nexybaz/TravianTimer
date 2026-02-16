import Foundation
import Combine
import Security
import AuthenticationServices
import CryptoKit

// MARK: - Auth Service (Supabase Email + Password)

final class AuthService: ObservableObject {

    static let shared = AuthService()

    // Hardcoded Supabase config (Anon Key ist öffentlich)
    static let supabaseURL = "https://rgpzawyreavhvbkutqwl.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJncHphd3lyZWF2aHZia3V0cXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMzQ5ODUsImV4cCI6MjA4NjgxMDk4NX0.W_uWAaOFZlqPGu8cPT2ygsA9SwN5CQm_3cuH5nCUeSY"

    // MARK: - Published State

    @Published var isAuthenticated: Bool = false
    @Published var userEmail: String? = nil
    @Published var userId: String? = nil
    @Published var isLoading: Bool = false

    // MARK: - Private

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?
    private var currentNonce: String?
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    // Keychain keys
    private let kAccessToken = "tt.auth.accessToken"
    private let kRefreshToken = "tt.auth.refreshToken"
    private let kUserId = "tt.auth.userId"
    private let kUserEmail = "tt.auth.userEmail"
    private let kTokenExpiry = "tt.auth.tokenExpiry"

    private init() {
        restoreSession()
    }

    // MARK: - Sign Up

    /// Registriert einen neuen Account. Supabase sendet Bestätigungs-Mail.
    func signUp(email: String, password: String) async -> Result<String, AuthError> {
        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/signup") else {
            return .failure(.networkError("Ungültige URL"))
        }

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if http.statusCode == 200 || http.statusCode == 201 {
                // Prüfe ob Session zurückkommt (wenn E-Mail-Bestätigung deaktiviert)
                if let accessToken = json?["access_token"] as? String,
                   let refreshToken = json?["refresh_token"] as? String,
                   let user = json?["user"] as? [String: Any],
                   let uid = user["id"] as? String {
                    let email = user["email"] as? String ?? email
                    let expiresIn = json?["expires_in"] as? Int ?? 3600
                    await saveSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        userId: uid,
                        email: email,
                        expiresIn: expiresIn
                    )
                    return .success("Erfolgreich registriert und angemeldet!")
                }

                // Sonst: E-Mail-Bestätigung nötig
                return .success("Bestätigungs-Mail gesendet! Bitte E-Mail bestätigen und dann anmelden.")
            }

            // Fehler
            if let errorMsg = json?["msg"] as? String {
                return .failure(.signUpFailed(errorMsg))
            }
            if let errorMsg = json?["error_description"] as? String {
                return .failure(.signUpFailed(errorMsg))
            }
            if let errorMsg = json?["message"] as? String {
                return .failure(.signUpFailed(errorMsg))
            }
            return .failure(.signUpFailed("Registrierung fehlgeschlagen (HTTP \(http.statusCode))"))

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Sign In

    /// Meldet einen bestehenden User an (E-Mail + Passwort).
    func signIn(email: String, password: String) async -> Result<Void, AuthError> {
        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=password") else {
            return .failure(.networkError("Ungültige URL"))
        }

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if http.statusCode == 200,
               let accessToken = json?["access_token"] as? String,
               let refreshToken = json?["refresh_token"] as? String,
               let user = json?["user"] as? [String: Any],
               let uid = user["id"] as? String {

                let email = user["email"] as? String ?? email
                let expiresIn = json?["expires_in"] as? Int ?? 3600

                await saveSession(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    userId: uid,
                    email: email,
                    expiresIn: expiresIn
                )

                // Legacy-Keys aufräumen
                UserDefaults.standard.removeObject(forKey: "supabaseProjectURL")
                UserDefaults.standard.removeObject(forKey: "supabaseAnonKey")

                // Device-Token neu registrieren mit user_id
                Task {
                    await PushService.shared.registerDeviceToken()
                }

                return .success(())
            }

            // Fehler
            if let errorDesc = json?["error_description"] as? String {
                return .failure(.signInFailed(errorDesc))
            }
            if let errorMsg = json?["msg"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            if let errorMsg = json?["message"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            return .failure(.signInFailed("Anmeldung fehlgeschlagen (HTTP \(http.statusCode))"))

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Password Reset

    /// Sendet eine Passwort-Reset-Mail (Recovery OTP) an die E-Mail-Adresse.
    func sendPasswordReset(email: String) async -> Result<Void, AuthError> {
        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/recover") else {
            return .failure(.networkError("Ungültige URL"))
        }

        let body: [String: Any] = [
            "email": email
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            if http.statusCode == 200 {
                return .success(())
            }
            return .failure(.resetFailed("Reset-Mail konnte nicht gesendet werden (HTTP \(http.statusCode))"))
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    /// Verifiziert den Recovery-Code und setzt das Passwort zurück.
    func verifyRecoveryAndSetPassword(email: String, code: String, newPassword: String) async -> Result<Void, AuthError> {
        // Schritt 1: OTP verifizieren → gibt eine Session zurück
        guard let verifyUrl = URL(string: "\(Self.supabaseURL)/auth/v1/verify") else {
            return .failure(.networkError("Ungültige URL"))
        }

        let verifyBody: [String: Any] = [
            "email": email,
            "token": code,
            "type": "recovery"
        ]

        var verifyRequest = URLRequest(url: verifyUrl)
        verifyRequest.httpMethod = "POST"
        verifyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        verifyRequest.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        verifyRequest.httpBody = try? JSONSerialization.data(withJSONObject: verifyBody)

        do {
            let (verifyData, verifyResponse) = try await URLSession.shared.data(for: verifyRequest)
            guard let http = verifyResponse as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let json = try? JSONSerialization.jsonObject(with: verifyData) as? [String: Any]

            guard http.statusCode == 200,
                  let accessToken = json?["access_token"] as? String else {
                if let errorMsg = json?["error_description"] as? String ?? json?["msg"] as? String ?? json?["message"] as? String {
                    return .failure(.resetFailed(errorMsg))
                }
                return .failure(.resetFailed("Ungültiger Code"))
            }

            // Schritt 2: Neues Passwort setzen mit dem temporären access_token
            guard let updateUrl = URL(string: "\(Self.supabaseURL)/auth/v1/user") else {
                return .failure(.networkError("Ungültige URL"))
            }

            let updateBody: [String: Any] = [
                "password": newPassword
            ]

            var updateRequest = URLRequest(url: updateUrl)
            updateRequest.httpMethod = "PUT"
            updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            updateRequest.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
            updateRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            updateRequest.httpBody = try? JSONSerialization.data(withJSONObject: updateBody)

            let (_, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            guard let updateHttp = updateResponse as? HTTPURLResponse, updateHttp.statusCode == 200 else {
                return .failure(.resetFailed("Passwort konnte nicht gesetzt werden"))
            }

            return .success(())
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Apple Sign In

    /// Erzeugt einen Apple ID Authorization Request mit frischem Nonce.
    func prepareAppleSignInRequest() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Verarbeitet die Apple-Anmeldedaten und sendet den Token an Supabase.
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async -> Result<Void, AuthError> {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            return .failure(.signInFailed("Apple Identity Token fehlt"))
        }

        guard let nonce = currentNonce else {
            return .failure(.signInFailed("Kein Nonce vorhanden. Bitte erneut versuchen."))
        }

        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=id_token") else {
            return .failure(.networkError("Ungültige URL"))
        }

        var body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken,
            "nonce": nonce
        ]

        // Apple liefert den Namen nur beim ersten Sign In
        if let fullName = credential.fullName {
            let givenName = fullName.givenName ?? ""
            let familyName = fullName.familyName ?? ""
            let displayName = [givenName, familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !displayName.isEmpty {
                body["data"] = ["full_name": displayName]
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if http.statusCode == 200,
               let accessToken = json?["access_token"] as? String,
               let refreshToken = json?["refresh_token"] as? String,
               let user = json?["user"] as? [String: Any],
               let uid = user["id"] as? String {

                let email = user["email"] as? String ?? credential.email ?? "Apple User"
                let expiresIn = json?["expires_in"] as? Int ?? 3600

                await saveSession(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    userId: uid,
                    email: email,
                    expiresIn: expiresIn
                )

                currentNonce = nil

                // Device-Token neu registrieren mit user_id
                Task {
                    await PushService.shared.registerDeviceToken()
                }

                return .success(())
            }

            // Fehler
            if let errorDesc = json?["error_description"] as? String {
                return .failure(.signInFailed(errorDesc))
            }
            if let errorMsg = json?["msg"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            if let errorMsg = json?["message"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            return .failure(.signInFailed("Apple-Anmeldung fehlgeschlagen (HTTP \(http.statusCode))"))

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - Apple Sign In Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - OAuth Sign In (Discord, Google, etc.)

    /// Startet den Discord OAuth-Flow via ASWebAuthenticationSession.
    @MainActor
    func startDiscordSignIn() async -> Result<Void, AuthError> {
        await startOAuthSignIn(provider: "discord", scopes: "identify email")
    }

    /// Startet den Google OAuth-Flow via ASWebAuthenticationSession.
    @MainActor
    func startGoogleSignIn() async -> Result<Void, AuthError> {
        await startOAuthSignIn(provider: "google", scopes: "email profile")
    }

    /// Generische OAuth-Methode für beliebige Supabase-Provider (PKCE).
    @MainActor
    private func startOAuthSignIn(provider: String, scopes: String? = nil) async -> Result<Void, AuthError> {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: "traviantimer://auth/callback"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        if let scopes {
            queryItems.append(URLQueryItem(name: "scopes", value: scopes))
        }

        var components = URLComponents(string: "\(Self.supabaseURL)/auth/v1/authorize")!
        components.queryItems = queryItems

        guard let authURL = components.url else {
            return .failure(.networkError("Ungültige OAuth-URL"))
        }

        // ASWebAuthenticationSession mit async/await
        let callbackResult: Result<URL, Error> = await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "traviantimer"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else if let callbackURL {
                    continuation.resume(returning: .success(callbackURL))
                } else {
                    continuation.resume(returning: .failure(AuthError.signInFailed("Kein Callback erhalten")))
                }
            }

            session.presentationContextProvider = WebAuthContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session // Strong reference halten
            session.start()
        }

        webAuthSession = nil

        switch callbackResult {
        case .failure(let error):
            // User-Abbruch → kein Fehler
            if let asError = error as? ASWebAuthenticationSessionError,
               asError.code == .canceledLogin {
                return .failure(.signInFailed("Abgebrochen"))
            }
            return .failure(.signInFailed(error.localizedDescription))

        case .success(let callbackURL):
            // Code aus der Callback-URL extrahieren
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                return .failure(.signInFailed("Kein Autorisierungscode erhalten"))
            }

            return await exchangeCodeForSession(code: code)
        }
    }

    /// Tauscht den OAuth Auth-Code gegen eine Supabase Session.
    private func exchangeCodeForSession(code: String) async -> Result<Void, AuthError> {
        guard let verifier = codeVerifier else {
            return .failure(.signInFailed("Kein Code-Verifier vorhanden"))
        }

        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=pkce") else {
            return .failure(.networkError("Ungültige URL"))
        }

        let body: [String: Any] = [
            "auth_code": code,
            "code_verifier": verifier
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if http.statusCode == 200,
               let accessToken = json?["access_token"] as? String,
               let refreshToken = json?["refresh_token"] as? String,
               let user = json?["user"] as? [String: Any],
               let uid = user["id"] as? String {

                let email = user["email"] as? String ?? "Discord User"
                let expiresIn = json?["expires_in"] as? Int ?? 3600

                await saveSession(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    userId: uid,
                    email: email,
                    expiresIn: expiresIn
                )

                codeVerifier = nil

                // Device-Token neu registrieren mit user_id
                Task {
                    await PushService.shared.registerDeviceToken()
                }

                return .success(())
            }

            // Fehler
            if let errorDesc = json?["error_description"] as? String {
                return .failure(.signInFailed(errorDesc))
            }
            if let errorMsg = json?["msg"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            if let errorMsg = json?["message"] as? String {
                return .failure(.signInFailed(errorMsg))
            }
            return .failure(.signInFailed("Discord-Anmeldung fehlgeschlagen (HTTP \(http.statusCode))"))

        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return Data(randomBytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token Management

    /// Gibt einen gültigen access_token zurück, refresht bei Bedarf.
    func validAccessToken() async -> String? {
        guard let token = accessToken else { return nil }

        // Noch gültig? (60s Puffer)
        if let expiry = tokenExpiresAt, expiry.timeIntervalSinceNow > 60 {
            return token
        }

        // Token refreshen
        let success = await refreshSession()
        return success ? accessToken : nil
    }

    /// Refresht die Session mit dem refresh_token.
    @discardableResult
    func refreshSession() async -> Bool {
        guard let refreshToken else {
            print("[Auth] Kein Refresh-Token vorhanden")
            await MainActor.run { isAuthenticated = false }
            return false
        }

        guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            return false
        }

        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = json["access_token"] as? String,
                  let newRefreshToken = json["refresh_token"] as? String,
                  let user = json["user"] as? [String: Any],
                  let uid = user["id"] as? String else {

                print("[Auth] Token-Refresh fehlgeschlagen")
                await MainActor.run {
                    isAuthenticated = false
                    userId = nil
                    userEmail = nil
                }
                clearKeychain()
                return false
            }

            let email = user["email"] as? String
            let expiresIn = json["expires_in"] as? Int ?? 3600

            await saveSession(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
                userId: uid,
                email: email ?? self.userEmail ?? "",
                expiresIn: expiresIn
            )

            print("[Auth] Token erfolgreich erneuert")
            return true

        } catch {
            print("[Auth] Refresh Netzwerkfehler: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Logout

    func logout() {
        // Server-seitig abmelden (best effort)
        if let token = accessToken {
            Task {
                guard let url = URL(string: "\(Self.supabaseURL)/auth/v1/logout") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }

        // Lokal aufräumen
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = nil
        clearKeychain()

        isAuthenticated = false
        userId = nil
        userEmail = nil

        print("[Auth] Abgemeldet")
    }

    // MARK: - Session Restore

    private func restoreSession() {
        guard let storedRefresh = readFromKeychain(kRefreshToken),
              let storedUserId = readFromKeychain(kUserId) else {
            print("[Auth] Keine gespeicherte Session")
            return
        }

        refreshToken = storedRefresh
        accessToken = readFromKeychain(kAccessToken)
        userId = storedUserId
        userEmail = readFromKeychain(kUserEmail)

        if let expiryStr = readFromKeychain(kTokenExpiry),
           let expiryInterval = TimeInterval(expiryStr) {
            tokenExpiresAt = Date(timeIntervalSince1970: expiryInterval)
        }

        // Vorläufig als authentifiziert markieren, Token wird bei Bedarf refreshed
        isAuthenticated = true

        print("[Auth] Session wiederhergestellt für \(userEmail ?? "?")")

        // Im Hintergrund Token refreshen
        Task {
            await refreshSession()
        }
    }

    // MARK: - Session Save

    @MainActor
    private func saveSession(accessToken: String, refreshToken: String, userId: String, email: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.userId = userId
        self.userEmail = email
        self.isAuthenticated = true

        // In Keychain speichern
        saveToKeychain(kAccessToken, value: accessToken)
        saveToKeychain(kRefreshToken, value: refreshToken)
        saveToKeychain(kUserId, value: userId)
        saveToKeychain(kUserEmail, value: email)
        saveToKeychain(kTokenExpiry, value: String(self.tokenExpiresAt!.timeIntervalSince1970))

        print("[Auth] Session gespeichert für \(email)")
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(_ key: String, value: String) {
        let data = value.data(using: .utf8)!

        // Erst löschen (falls vorhanden)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Neu speichern
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readFromKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func clearKeychain() {
        deleteFromKeychain(kAccessToken)
        deleteFromKeychain(kRefreshToken)
        deleteFromKeychain(kUserId)
        deleteFromKeychain(kUserEmail)
        deleteFromKeychain(kTokenExpiry)
    }
}

// MARK: - Web Auth Context Provider

/// Stellt das Presentation-Window für ASWebAuthenticationSession bereit.
final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Erstes aktives Window der App
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case networkError(String)
    case invalidResponse
    case signUpFailed(String)
    case signInFailed(String)
    case resetFailed(String)
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Netzwerkfehler: \(msg)"
        case .invalidResponse: return "Ungültige Server-Antwort"
        case .signUpFailed(let msg): return "Registrierung: \(msg)"
        case .signInFailed(let msg): return "Anmeldung: \(msg)"
        case .resetFailed(let msg): return "Passwort-Reset: \(msg)"
        case .sessionExpired: return "Session abgelaufen. Bitte erneut anmelden."
        }
    }
}
