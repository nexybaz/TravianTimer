import Foundation
import Supabase

// MARK: - Device Token Service

/// Registriert APNs Device Tokens in Supabase (device_tokens Tabelle).
/// Wird beim App-Start aufgerufen, wenn der User eingeloggt ist.
/// Bei Logout wird der Token entfernt.
actor DeviceTokenService {

    static let shared = DeviceTokenService()

    private var client: SupabaseClient { SupabaseManager.client }

    /// Der zuletzt registrierte Token (fuer spaeteres Cleanup bei Logout).
    private var currentToken: String?

    // MARK: - Register

    /// Speichert den APNs Device Token in Supabase.
    /// Wird nach didRegisterForRemoteNotifications aufgerufen.
    func registerToken(_ token: String) async {
        guard let userId = await AuthService.shared.currentUserId else {
            // Noch nicht eingeloggt — Token merken, spaeter registrieren
            currentToken = token
            print("[DeviceToken] Token gemerkt (noch nicht eingeloggt)")
            return
        }

        currentToken = token

        do {
            // UPSERT: Wenn Token schon existiert, user_id aktualisieren
            try await client
                .from("device_tokens")
                .upsert(
                    DeviceTokenInsert(userId: userId, token: token),
                    onConflict: "token"
                )
                .execute()

            print("[DeviceToken] Token registriert fuer User \(userId.uuidString.prefix(8))")
        } catch {
            print("[DeviceToken] Registrierung fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Registriert den gemerkten Token (nach Login aufrufen).
    func registerPendingToken() async {
        guard let token = currentToken else { return }
        await registerToken(token)
    }

    // MARK: - Unregister

    /// Entfernt den Device Token aus Supabase (bei Logout).
    func unregisterToken() async {
        guard let token = currentToken else { return }

        do {
            try await client
                .from("device_tokens")
                .delete()
                .eq("token", value: token)
                .execute()

            print("[DeviceToken] Token entfernt")
        } catch {
            print("[DeviceToken] Entfernung fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}

// MARK: - Insert Model

private struct DeviceTokenInsert: Codable {
    let userId: UUID
    let token: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
    }
}
