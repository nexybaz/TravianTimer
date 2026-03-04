import UIKit
import Supabase

// MARK: - Avatar Service

/// Zentraler Service fuer Avatar-Verwaltung.
/// Speichert Avatare in Supabase Storage (Cloud) und lokal (Cache).
/// Pfad-Schema: avatars/{userId}/avatar.jpg
enum AvatarService {

    private static var client: SupabaseClient { SupabaseManager.client }
    private static let bucket = "avatars"

    // MARK: - Upload

    /// Laedt ein Bild in Supabase Storage hoch und cached es lokal.
    static func upload(_ image: UIImage, userId: UUID) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        // Lokal cachen
        saveLocally(data, userId: userId)

        // Remote hochladen (upsert — ueberschreibt existierende Datei)
        let path = remotePath(for: userId)
        do {
            try await client.storage.from(bucket).upload(
                path,
                data: data,
                options: .init(contentType: "image/jpeg", upsert: true)
            )
        } catch {
            print("[AvatarService] Upload fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Download

    /// Laedt Avatar von Supabase Storage und cached ihn lokal.
    /// Gibt nil zurueck wenn kein Avatar vorhanden.
    static func download(userId: UUID) async -> UIImage? {
        let path = remotePath(for: userId)
        do {
            let data = try await client.storage.from(bucket).download(path: path)
            saveLocally(data, userId: userId)
            return UIImage(data: data)
        } catch {
            // Kein Avatar vorhanden oder Netzwerkfehler — kein Log-Spam
            return nil
        }
    }

    // MARK: - Load (Cache-First)

    /// Versucht zuerst lokal zu laden, dann remote.
    static func loadCachedOrRemote(userId: UUID) async -> UIImage? {
        // 1. Lokal pruefen
        if let local = loadLocal(userId: userId) {
            return local
        }

        // 2. Remote laden + cachen
        return await download(userId: userId)
    }

    // MARK: - Delete

    /// Loescht Avatar aus Supabase Storage und lokal.
    static func delete(userId: UUID) async {
        // Lokal loeschen
        let localURL = avatarFileURL(for: userId)
        try? FileManager.default.removeItem(at: localURL)

        // Remote loeschen
        let path = remotePath(for: userId)
        do {
            try await client.storage.from(bucket).remove(paths: [path])
        } catch {
            print("[AvatarService] Delete fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Lokale Helfer

    /// Laedt Avatar aus lokalem Cache.
    static func loadLocal(userId: UUID) -> UIImage? {
        let url = avatarFileURL(for: userId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func saveLocally(_ data: Data, userId: UUID) {
        let url = avatarFileURL(for: userId)
        try? data.write(to: url)
    }

    private static func remotePath(for userId: UUID) -> String {
        "\(userId.uuidString)/avatar.jpg"
    }
}
