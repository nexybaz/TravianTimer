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

    /// Registriert den Device-Token bei Supabase.
    func registerDeviceToken(_ token: String? = nil) async -> Bool {
        let tokenToSend = token ?? storedToken ?? ""
        guard !tokenToSend.isEmpty else {
            print("[PushService] Kein Device-Token vorhanden")
            return false
        }

        let supabaseURL = UserDefaults.standard.string(forKey: "supabaseProjectURL") ?? ""
        let supabaseKey = UserDefaults.standard.string(forKey: "supabaseAnonKey") ?? ""

        guard !supabaseURL.isEmpty, !supabaseKey.isEmpty else {
            print("[PushService] Supabase nicht konfiguriert")
            return false
        }

        guard let url = URL(string: "\(supabaseURL)/functions/v1/register-device") else {
            print("[PushService] Ungültige URL")
            return false
        }

        let playerName = UserDefaults.standard.string(forKey: "accountName") ?? "Unknown"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "token": tokenToSend,
            "player_name": playerName,
            "platform": "ios"
        ]

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
