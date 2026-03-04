import Foundation
import Observation
import Supabase

// MARK: - Hero Store

@MainActor
@Observable
final class HeroStore {

    static let shared = HeroStore()

    var config: HeroConfig = HeroConfig()
    var isLoaded: Bool = false

    @ObservationIgnored private let baseKey = "heroConfig"
    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private init() {}

    // MARK: - Public API

    /// Speichert lokal + Supabase (debounced).
    func save() {
        saveLocal()
        // Debounce: vorherigen Save-Task abbrechen
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await syncToSupabase()
        }
    }

    // MARK: - Lifecycle (aufgerufen von AuthService)

    /// Nach Login: Hero-Config aus Supabase laden (Source of Truth).
    func loadFromSupabase() async {
        guard let userId = currentUserId() else {
            print("[HeroStore] Kein User eingeloggt — skip")
            return
        }

        do {
            let rows: [HeroConfigRow] = try await client
                .from("hero_configs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if let row = rows.first {
                config = row.toConfig()
                saveLocal()
                print("[HeroStore] Config aus Supabase geladen (Level \(config.level))")
            } else {
                // Kein Eintrag: prüfe lokalen Cache
                loadLocal()
                print("[HeroStore] Kein Supabase-Eintrag, nutze Default/Cache")
            }
            isLoaded = true
        } catch {
            loadLocal()
            isLoaded = true
            print("[HeroStore] Supabase Load fehlgeschlagen, nutze lokalen Cache: \(error.localizedDescription)")
        }
    }

    /// Bei Logout: Lokalen Cache leeren (Supabase-Daten bleiben).
    func handleLogout() {
        config = HeroConfig()
        isLoaded = false
        if let key = userKey() {
            UserDefaults.standard.removeObject(forKey: key)
        }
        print("[HeroStore] Logout — lokaler Cache geleert")
    }

    // MARK: - Lokaler Cache (pro User)

    private func userKey() -> String? {
        guard let userId = currentUserId() else { return nil }
        return "\(baseKey)_\(userId)"
    }

    private func loadLocal() {
        guard let key = userKey(),
              let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(HeroConfig.self, from: data) else { return }
        config = cached
    }

    private func saveLocal() {
        guard let key = userKey(),
              let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Supabase Sync

    private func syncToSupabase() async {
        guard let userId = currentUserId() else { return }

        let row = HeroConfigRow(userId: userId, config: config)

        do {
            try await client
                .from("hero_configs")
                .upsert(row, onConflict: "user_id")
                .execute()
            print("[HeroStore] Supabase UPSERT erfolgreich")
        } catch {
            print("[HeroStore] Supabase UPSERT fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}
