import Foundation
import Observation
import Supabase

// MARK: - Tool Favorites Store

@MainActor
@Observable
final class FavoritesStore {

    static let shared = FavoritesStore()

    var favoriteIds: Set<String> = []

    @ObservationIgnored private let baseKey = "toolFavorites"
    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }

    private init() {}

    // MARK: - Public API

    func isFavorite(_ id: String) -> Bool {
        favoriteIds.contains(id)
    }

    func toggle(_ id: String) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
            saveLocal()
            Task { await removeFromSupabase(id) }
        } else {
            favoriteIds.insert(id)
            saveLocal()
            Task { await addToSupabase(id) }
        }
    }

    // MARK: - Lifecycle (aufgerufen von AuthService)

    /// Nach Login: Favoriten aus Supabase laden (Source of Truth).
    func loadFromSupabase() async {
        guard let userId = currentUserId() else {
            print("[FavoritesStore] Kein User eingeloggt — skip")
            return
        }

        do {
            let rows: [FavoriteRow] = try await client
                .from("tool_favorites")
                .select("tool_id")
                .eq("user_id", value: userId)
                .execute()
                .value

            let remoteIds = Set(rows.map(\.toolId))

            // Einmalige Migration: Alte lokale Favoriten (ohne User-Key) hochladen
            let oldLocal = Set(UserDefaults.standard.stringArray(forKey: baseKey) ?? [])
            if !oldLocal.isEmpty && remoteIds.isEmpty {
                print("[FavoritesStore] Migration: \(oldLocal.count) lokale Favoriten → Supabase")
                favoriteIds = oldLocal
                saveLocal()
                for toolId in oldLocal {
                    await addToSupabase(toolId)
                }
                // Alte globale Key aufräumen
                UserDefaults.standard.removeObject(forKey: baseKey)
                return
            }

            // Supabase ist Source of Truth
            favoriteIds = remoteIds
            saveLocal()
            print("[FavoritesStore] \(remoteIds.count) Favoriten aus Supabase geladen")
        } catch {
            // Fallback: Lokalen Cache laden
            loadLocal()
            print("[FavoritesStore] Supabase Load fehlgeschlagen, nutze lokalen Cache: \(error.localizedDescription)")
        }
    }

    /// Bei Logout: Lokalen Cache leeren (Supabase-Daten bleiben).
    func handleLogout() {
        favoriteIds = []
        // Lokalen Cache fuer diesen User loeschen
        if let key = userKey() {
            UserDefaults.standard.removeObject(forKey: key)
        }
        print("[FavoritesStore] Logout — lokaler Cache geleert")
    }

    // MARK: - Lokaler Cache (pro User)

    private func userKey() -> String? {
        guard let userId = currentUserId() else { return nil }
        return "\(baseKey)_\(userId)"
    }

    private func loadLocal() {
        guard let key = userKey() else { return }
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        favoriteIds = Set(stored)
    }

    private func saveLocal() {
        guard let key = userKey() else { return }
        UserDefaults.standard.set(Array(favoriteIds), forKey: key)
    }

    // MARK: - Supabase Sync

    private func addToSupabase(_ toolId: String) async {
        guard let userId = currentUserId() else { return }

        do {
            try await client
                .from("tool_favorites")
                .insert(["user_id": userId, "tool_id": toolId])
                .execute()
        } catch {
            print("[FavoritesStore] Supabase INSERT fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func removeFromSupabase(_ toolId: String) async {
        guard let userId = currentUserId() else { return }

        do {
            try await client
                .from("tool_favorites")
                .delete()
                .eq("user_id", value: userId)
                .eq("tool_id", value: toolId)
                .execute()
        } catch {
            print("[FavoritesStore] Supabase DELETE fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}

// MARK: - Supabase Row

private struct FavoriteRow: Decodable {
    let toolId: String

    enum CodingKeys: String, CodingKey {
        case toolId = "tool_id"
    }
}
