import Foundation
import Combine
import Supabase
import AuthenticationServices
import CryptoKit

// MARK: - User Profile (aus Supabase profiles-Tabelle)

struct UserProfile: Codable, Sendable, Equatable {
    let id: UUID
    var playerName: String
    var tribe: String
    var worldId: String?
    var worldSpeed: String?
    var role: UserRole
    var isVerified: Bool
    var kingdomId: Int?
    var kingdomTag: String?
    var functions: [PlayerFunction]
    var fealtyLevel: Int
    var prestigePoints: Int

    /// Prestige-Level berechnet aus Gesamtpunktzahl (offizielle Schwellen)
    var prestigeLevel: Int {
        Self.prestigeLevel(from: prestigePoints)
    }

    /// Offizielle Prestige-Schwellen: (benötigte Punkte, Level)
    static let prestigeThresholds: [(points: Int, level: Int)] = [
        (20_000, 13), (10_000, 12), (5_000, 11), (2_000, 10),
        (1_000, 9), (750, 8), (500, 7), (400, 6),
        (300, 5), (200, 4), (100, 3), (50, 2), (25, 1)
    ]

    /// Berechnet das Prestige-Level aus der Punktzahl
    static func prestigeLevel(from points: Int) -> Int {
        for threshold in prestigeThresholds {
            if points >= threshold.points { return threshold.level }
        }
        return 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case playerName     = "player_name"
        case tribe
        case worldId        = "world_id"
        case worldSpeed     = "world_speed"
        case role
        case isVerified     = "is_verified"
        case kingdomId      = "kingdom_id"
        case kingdomTag     = "kingdom_tag"
        case functions
        case fealtyLevel    = "fealty_level"
        case prestigePoints = "prestige_points"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id              = try container.decode(UUID.self, forKey: .id)
        playerName      = try container.decode(String.self, forKey: .playerName)
        tribe           = try container.decode(String.self, forKey: .tribe)
        worldId         = try container.decodeIfPresent(String.self, forKey: .worldId)
        worldSpeed      = try container.decodeIfPresent(String.self, forKey: .worldSpeed)
        role            = try container.decode(UserRole.self, forKey: .role)
        isVerified      = try container.decode(Bool.self, forKey: .isVerified)
        kingdomId       = try container.decodeIfPresent(Int.self, forKey: .kingdomId)
        kingdomTag      = try container.decodeIfPresent(String.self, forKey: .kingdomTag)
        functions       = (try? container.decode([PlayerFunction].self, forKey: .functions)) ?? []
        fealtyLevel     = (try? container.decode(Int.self, forKey: .fealtyLevel)) ?? 0
        prestigePoints  = (try? container.decode(Int.self, forKey: .prestigePoints)) ?? 0
    }
}

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    // MARK: Published State

    @Published var isAuthenticated: Bool = false
    @Published var hasCheckedSession: Bool = false
    @Published var currentUserId: UUID? = nil
    @Published var currentRole: UserRole = .governor
    @Published var profile: UserProfile? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: Private

    private var authStateTask: Task<Void, Never>?
    private var currentNonce: String?

    private var client: SupabaseClient { SupabaseManager.client }

    // MARK: Init

    private init() {
        listenToAuthStateChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener

    /// Lauscht auf Auth-Events (Login, Logout, Session-Restore, Token-Refresh).
    /// Wird beim App-Start automatisch aufgerufen via `.initialSession`.
    private func listenToAuthStateChanges() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                guard [.initialSession, .signedIn, .signedOut, .tokenRefreshed]
                    .contains(event) else { continue }

                let hasSession = session != nil
                self.isAuthenticated = hasSession
                self.currentUserId = session?.user.id

                // Sofort Splash ausblenden — Daten werden im Hintergrund geladen
                if !self.hasCheckedSession {
                    self.hasCheckedSession = true
                }

                if hasSession {
                    await self.loadProfile()
                    // Truppen-History aus Supabase laden
                    await TroopHistoryStore.shared.loadFromSupabase()
                    // Tool-Favoriten aus Supabase laden
                    await FavoritesStore.shared.loadFromSupabase()
                    // Benachrichtigungen laden + Realtime starten
                    await NotificationsStore.shared.loadNotifications()
                    await NotificationsStore.shared.loadPreferences()
                    await NotificationsStore.shared.subscribeToRealtime()
                    // Device Token registrieren (falls noch nicht geschehen)
                    await DeviceTokenService.shared.registerPendingToken()
                    // Bestehende Guide-Session laden (falls vorhanden)
                    await GuideSessionStore.shared.loadExistingSession()
                } else {
                    // Device Token entfernen
                    await DeviceTokenService.shared.unregisterToken()
                    self.profile = nil
                    self.currentRole = .governor
                    // Lokale Caches leeren (bleiben in Supabase erhalten)
                    ProfileStore.shared.handleLogout()
                    TroopHistoryStore.shared.handleLogout()
                    FavoritesStore.shared.handleLogout()
                    GuideSessionStore.shared.handleLogout()
                    // Benachrichtigungen aufraeumen
                    await NotificationsStore.shared.handleLogout()
                    // CallsStore aufräumen bei Logout
                    NotificationCenter.default.post(name: AuthService.didSignOutNotification, object: nil)
                }
            }
        }
    }

    /// Notification die bei Logout gepostet wird — CallsStore lauscht darauf
    static let didSignOutNotification = Notification.Name("AuthService.didSignOut")

    // MARK: - Sign Up

    func signUp(email: String, password: String, playerName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["player_name": .string(playerName)],
                redirectTo: URL(string: "traviantimer://auth/callback")
            )

            if response.session == nil {
                // E-Mail-Bestaetigung erforderlich
                errorMessage = nil
            }
            // Wenn Session vorhanden: authStateChanges kuemmert sich um den Rest
        } catch {
            errorMessage = mapError(error)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            // Sofort authentifiziert setzen damit die Login-Maske verschwindet
            self.isAuthenticated = true
            self.currentUserId = session.user.id
            isLoading = false
            // Profil + Villages sofort laden (nicht auf authStateChanges warten)
            await loadProfile()
            await TroopHistoryStore.shared.loadFromSupabase()
            await NotificationsStore.shared.loadNotifications()
            await NotificationsStore.shared.loadPreferences()
            await NotificationsStore.shared.subscribeToRealtime()
            await DeviceTokenService.shared.registerPendingToken()
            await GuideSessionStore.shared.loadExistingSession()
        } catch {
            errorMessage = mapError(error)
            isLoading = false
        }
    }

    // MARK: - Apple Sign In

    /// Erstellt den Apple Sign-In Request mit Nonce.
    /// Aufruf: `let request = authService.prepareAppleSignInRequest()`
    func prepareAppleSignInRequest() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Verarbeitet das Apple Sign-In Credential.
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .failure(let error):
            isLoading = false
            // ASAuthorizationError.canceled = User hat abgebrochen → kein Fehler anzeigen
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                errorMessage = "Apple Identity Token fehlt"
                isLoading = false
                return
            }

            guard let nonce = currentNonce else {
                errorMessage = "Kein Nonce vorhanden. Bitte erneut versuchen."
                isLoading = false
                return
            }

            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken,
                        nonce: nonce
                    )
                )

                // Sofort authentifiziert setzen damit die Login-Maske verschwindet
                self.isAuthenticated = true
                self.currentUserId = session.user.id

                // Apple liefert den Namen nur beim ersten Sign-In
                if let fullName = credential.fullName {
                    let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                    let displayName = parts.joined(separator: " ")
                    if !displayName.isEmpty {
                        try? await client.auth.update(
                            user: .init(data: ["player_name": .string(displayName)])
                        )
                        // Auch in profiles-Tabelle updaten (Trigger hat bereits 'Spieler' gesetzt)
                        try? await client
                            .from("profiles")
                            .update(["player_name": displayName])
                            .eq("id", value: session.user.id.uuidString)
                            .execute()
                    }
                }

                currentNonce = nil
                isLoading = false
                // Profil + Villages sofort laden (nicht auf authStateChanges warten)
                await loadProfile()
                await TroopHistoryStore.shared.loadFromSupabase()
                await NotificationsStore.shared.loadNotifications()
                await NotificationsStore.shared.loadPreferences()
                await NotificationsStore.shared.subscribeToRealtime()
                await DeviceTokenService.shared.registerPendingToken()
                await GuideSessionStore.shared.loadExistingSession()
            } catch {
                errorMessage = mapError(error)
                isLoading = false
            }
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.resetPasswordForEmail(email)
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await client.auth.signOut()
            // authStateChanges kuemmert sich um State-Reset
        }
    }

    // MARK: - Delete Account

    /// Löscht den Account komplett (Profil, Daten, Auth-User).
    /// Ruft die Edge Function `delete-account` auf, die:
    /// 1. Alle User-Daten in der DB bereinigt (via delete_user_data SQL-Funktion)
    /// 2. Den Auth-User via Admin API löscht
    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Edge Function Response
        struct DeleteResponse: Codable {
            let success: Bool?
            let error: String?
        }

        let response: DeleteResponse = try await client.functions.invoke(
            "delete-account"
        ) { data, _ in
            if let decoded = try? JSONDecoder().decode(DeleteResponse.self, from: data) {
                if let errorMsg = decoded.error {
                    throw AccountDeletionError.serverError(errorMsg)
                }
                return decoded
            }
            throw AccountDeletionError.invalidResponse
        }

        guard response.success == true else {
            throw AccountDeletionError.unknown
        }

        // Avatar lokal löschen (vor State-Reset, da currentUserId danach nil ist)
        if let userId = currentUserId {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let avatarURL = docs.appendingPathComponent("\(userId.uuidString)_avatar.jpg")
            try? FileManager.default.removeItem(at: avatarURL)
        }

        // Device Token entfernen
        await DeviceTokenService.shared.unregisterToken()

        // Lokalen State aufräumen
        self.isAuthenticated = false
        self.currentUserId = nil
        self.profile = nil
        self.currentRole = .governor
        ProfileStore.shared.handleLogout()
        TroopHistoryStore.shared.handleLogout()
        FavoritesStore.shared.handleLogout()
        GuideSessionStore.shared.handleLogout()
        await NotificationsStore.shared.handleLogout()
        NotificationCenter.default.post(name: AuthService.didSignOutNotification, object: nil)

        // Lokale Session entfernen
        try? await client.auth.signOut()
    }

    enum AccountDeletionError: LocalizedError {
        case invalidResponse
        case serverError(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Unerwartete Antwort vom Server."
            case .serverError(let msg):
                return msg
            case .unknown:
                return "Account konnte nicht gelöscht werden. Bitte versuche es erneut."
            }
        }
    }

    // MARK: - Load Profile

    /// Laedt das Profil aus der profiles-Tabelle.
    /// Retry nach 1s falls der DB-Trigger (handle_new_user) noch nicht gefeuert hat.
    func loadProfile() async {
        guard let userId = currentUserId else { return }

        do {
            let profile: UserProfile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.profile = profile
            self.currentRole = profile.role
            // Villages aus Supabase laden
            await ProfileStore.shared.loadFromSupabase()
        } catch {
            // Trigger hat evtl. noch nicht gefeuert → 1s warten und nochmal versuchen
            print("[Auth] Profil laden fehlgeschlagen, retry in 1s: \(error.localizedDescription)")
            try? await Task.sleep(for: .seconds(1))

            do {
                let profile: UserProfile = try await client
                    .from("profiles")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                self.profile = profile
                self.currentRole = profile.role
                // Villages aus Supabase laden
                await ProfileStore.shared.loadFromSupabase()
            } catch {
                print("[Auth] Profil laden endgueltig fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Refresh Profile (public)

    /// Laedt das Profil neu aus der DB.
    /// Aufruf z.B. nach Travian-Verifizierung oder taegl. Refresh.
    func refreshProfile() async {
        await loadProfile()
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") || message.contains("invalid_credentials") {
            return "E-Mail oder Passwort falsch."
        }
        if message.contains("email not confirmed") {
            return "Bitte zuerst die E-Mail bestätigen."
        }
        if message.contains("user already registered") {
            return "Registrierung fehlgeschlagen. Falls du bereits einen Account hast, versuche dich anzumelden."
        }
        if message.contains("rate limit") || message.contains("too many requests") || message.contains("429") {
            return "Zu viele Versuche. Bitte warte einen Moment."
        }
        if message.contains("password") && message.contains("short") {
            return "Passwort muss mindestens 6 Zeichen lang sein."
        }
        if message.contains("network") || message.contains("offline") || message.contains("internet") {
            return "Keine Internetverbindung."
        }

        // Generischer Fallback ohne technische Details
        print("[Auth] Unmapped error: \(error.localizedDescription)")
        return "Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut."
    }

    // MARK: - Apple Sign In Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Nonce-Generierung fehlgeschlagen")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
