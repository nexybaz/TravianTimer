import Foundation
import Observation
import Supabase

// MARK: - Avatar Config Store

@MainActor
@Observable
final class AvatarConfigStore {

    static let shared = AvatarConfigStore()

    var config: AvatarConfig = AvatarConfig()
    var undoStack: [AvatarConfig] = []
    var isLoaded: Bool = false

    @ObservationIgnored private let baseKey = "avatarConfig"
    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private init() {}

    // MARK: - Undo

    /// Aktuellen Zustand auf den Undo-Stack schieben (vor Aenderungen aufrufen).
    func pushUndo() {
        undoStack.append(config)
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    /// Letzte Aenderung rueckgaengig machen.
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        config = previous
        save()
    }

    var canUndo: Bool { !undoStack.isEmpty }

    // MARK: - Presets

    /// Preset anwenden (mit Undo-Punkt).
    func applyPreset(_ preset: AvatarPresetType) {
        pushUndo()
        config = preset.config
        save()
    }

    /// Zufaellige Konfiguration generieren.
    func randomize() {
        pushUndo()
        config = AvatarConfig(
            faceShape: Int.random(in: 0..<4),
            hairStyle: Int.random(in: 0..<6),
            eyeStyle: Int.random(in: 0..<5),
            noseStyle: Int.random(in: 0..<4),
            mouthStyle: Int.random(in: 0..<5),
            accessory: Int.random(in: -1..<4),
            hairColor: AvatarColorPalette.hairColors.randomElement()?.hex ?? "8B4513",
            eyeColor: AvatarColorPalette.eyeColors.randomElement()?.hex ?? "4169E1",
            skinColor: AvatarColorPalette.skinColors.randomElement()?.hex ?? "FDBCB4",
            backgroundColor: AvatarColorPalette.backgroundColors.randomElement()?.hex ?? "4A90D9"
        )
        save()
    }

    // MARK: - Public API

    /// Speichert lokal + Supabase (debounced).
    func save() {
        saveLocal()
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await syncToSupabase()
        }
    }

    // MARK: - Lifecycle (aufgerufen von AuthService)

    /// Nach Login: Avatar-Config aus Supabase laden (Source of Truth).
    func loadFromSupabase() async {
        guard let userId = currentUserId() else {
            print("[AvatarConfigStore] Kein User eingeloggt — skip")
            return
        }

        do {
            let rows: [AvatarConfigRow] = try await client
                .from("avatar_configs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if let row = rows.first {
                config = row.config
                saveLocal()
                print("[AvatarConfigStore] Config aus Supabase geladen")
            } else {
                loadLocal()
                print("[AvatarConfigStore] Kein Supabase-Eintrag, nutze Default/Cache")
            }
            isLoaded = true
        } catch {
            loadLocal()
            isLoaded = true
            print("[AvatarConfigStore] Supabase Load fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Bei Logout: Lokalen Cache leeren (Supabase-Daten bleiben).
    func handleLogout() {
        config = AvatarConfig()
        undoStack = []
        isLoaded = false
        if let key = userKey() {
            UserDefaults.standard.removeObject(forKey: key)
        }
        print("[AvatarConfigStore] Logout — lokaler Cache geleert")
    }

    // MARK: - Lokaler Cache (pro User)

    private func userKey() -> String? {
        guard let userId = currentUserId() else { return nil }
        return "\(baseKey)_\(userId)"
    }

    private func loadLocal() {
        guard let key = userKey(),
              let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(AvatarConfig.self, from: data) else { return }
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

        let row = AvatarConfigRow(userId: userId, config: config)

        do {
            try await client
                .from("avatar_configs")
                .upsert(row, onConflict: "user_id")
                .execute()
            print("[AvatarConfigStore] Supabase UPSERT erfolgreich")
        } catch {
            print("[AvatarConfigStore] Supabase UPSERT fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}
