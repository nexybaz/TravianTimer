import Foundation

// MARK: - Push Service (Supabase)

final class PushService {

    static let shared = PushService()
    private init() {}

    private let deviceTokenKey = "apnsDeviceToken"
    private let registeredKey = "pushDeviceRegistered"

    // MARK: - Token

    var storedToken: String? {
        UserDefaults.standard.string(forKey: deviceTokenKey)
    }

    var isRegistered: Bool {
        UserDefaults.standard.bool(forKey: registeredKey)
    }

    func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: deviceTokenKey)
    }

    // MARK: - Register

    /// Registriert den Device-Token bei Supabase. Inkludiert user_id wenn eingeloggt.
    func registerDeviceToken(_ token: String? = nil) async -> Bool {
        let tokenToSend = token ?? storedToken ?? ""
        guard !tokenToSend.isEmpty else {
            print("[PushService] Kein Device-Token vorhanden")
            return false
        }

        guard let url = URL(string: "\(AuthService.supabaseURL)/functions/v1/register-device") else {
            print("[PushService] Ungültige URL")
            return false
        }

        let playerName = UserDefaults.standard.string(forKey: "accountName") ?? "Unknown"

        var body: [String: Any] = [
            "token": tokenToSend,
            "player_name": playerName,
            "platform": "ios"
        ]

        // user_id mitsenden wenn eingeloggt
        if let userId = AuthService.shared.userId {
            body["user_id"] = userId
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth-Header: JWT wenn eingeloggt, sonst Anon Key
        if let accessToken = await AuthService.shared.validAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(AuthService.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("[PushService] Registrierung erfolgreich")
                UserDefaults.standard.set(true, forKey: registeredKey)
                return true
            } else {
                print("[PushService] Registrierung fehlgeschlagen")
                UserDefaults.standard.set(false, forKey: registeredKey)
                return false
            }
        } catch {
            print("[PushService] Netzwerkfehler: \(error.localizedDescription)")
            UserDefaults.standard.set(false, forKey: registeredKey)
            return false
        }
    }
}
