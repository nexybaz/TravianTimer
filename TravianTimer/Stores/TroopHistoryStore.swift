import Foundation
import Combine
import Supabase

// MARK: - Supabase Snapshot Model (DB-Mapping)

private struct SupabaseSnapshot: Codable {
    let id: UUID?
    let userId: String?
    let date: Date
    let villageName: String
    let villageX: Int
    let villageY: Int
    let troopCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case date
        case villageName = "village_name"
        case villageX    = "village_x"
        case villageY    = "village_y"
        case troopCounts = "troop_counts"
    }
}

// MARK: - Troop History Store

@MainActor
final class TroopHistoryStore: ObservableObject {

    static let shared = TroopHistoryStore()

    @Published var snapshots: [TroopSnapshot] = [] {
        didSet { saveLocal() }
    }

    private let key = "troopHistoryV1"
    private var client: SupabaseClient { SupabaseManager.client }

    private init() {
        loadLocal()
    }

    // MARK: - Record

    /// Speichert einen Snapshot pro Dorf mit dem aktuellen Zeitstempel.
    /// Schreibt lokal + async nach Supabase.
    func recordSnapshot(villages: [VillageProfile]) {
        let now = Date()
        let newSnapshots = villages.compactMap { v -> TroopSnapshot? in
            // Nur Doerfer mit Truppen erfassen
            let total = v.troopCounts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return TroopSnapshot(
                date: now,
                villageName: v.name,
                villageX: v.x,
                villageY: v.y,
                troopCounts: v.troopCounts
            )
        }
        guard !newSnapshots.isEmpty else { return }
        snapshots.append(contentsOf: newSnapshots)

        // Background Sync zu Supabase
        let snapshotsToSync = newSnapshots
        Task { await syncToSupabase(snapshotsToSync) }
    }

    // MARK: - Aggregation

    struct DateTotal: Identifiable {
        let id = UUID()
        let date: Date
        let totalTroops: Int
        let totalCrop: Int
        let offTroops: Int
        let deffTroops: Int
    }

    /// Gruppiert Snapshots nach Zeitstempel und summiert Truppen + Getreide + Off/Deff.
    func totalsByDate() -> [DateTotal] {
        // Snapshots sind pro Dorf gespeichert — gleicher Zeitstempel = gleicher Import.
        // Gruppiere nach Sekunden-genauem Datum.
        var grouped: [TimeInterval: (troops: Int, crop: Int, off: Int, deff: Int, date: Date)] = [:]

        for snap in snapshots {
            let key = snap.date.timeIntervalSince1970.rounded()
            let existing = grouped[key] ?? (troops: 0, crop: 0, off: 0, deff: 0, date: snap.date)

            var troops = 0
            var crop = 0
            var off = 0
            var deff = 0
            for (rawValue, count) in snap.troopCounts where count > 0 {
                troops += count
                if let kind = TroopKind(rawValue: rawValue) {
                    crop += count * kind.cropPerHour
                    if kind.isOffensive { off += count }
                    if kind.isDefensive { deff += count }
                }
            }

            grouped[key] = (
                troops: existing.troops + troops,
                crop: existing.crop + crop,
                off: existing.off + off,
                deff: existing.deff + deff,
                date: existing.date
            )
        }

        return grouped.values
            .map { DateTotal(date: $0.date, totalTroops: $0.troops, totalCrop: $0.crop, offTroops: $0.off, deffTroops: $0.deff) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Logout / Clear

    /// Logout: Lokalen Cache leeren ohne Supabase-Daten zu loeschen.
    /// Beim naechsten Login werden die Snapshots aus Supabase neu geladen.
    func handleLogout() {
        snapshots = []
        UserDefaults.standard.removeObject(forKey: key)
        print("[TroopHistory] Logout — lokaler Cache geleert")
    }

    func clearHistory() {
        snapshots = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Lokaler Cache (UserDefaults)

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([TroopSnapshot].self, from: data) else { return }
        snapshots = decoded
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Supabase Sync

    /// Laedt alle Snapshots des aktuellen Users aus Supabase.
    /// Wird nach Login aufgerufen um den Verlauf wiederherzustellen.
    func loadFromSupabase() async {
        guard let userId = currentUserId() else {
            print("[TroopHistory] Kein User eingeloggt — skip Supabase Load")
            return
        }

        do {
            let dbSnapshots: [SupabaseSnapshot] = try await client
                .from("troop_snapshots")
                .select()
                .eq("user_id", value: userId)
                .order("date", ascending: true)
                .execute()
                .value

            if !dbSnapshots.isEmpty {
                let loaded = dbSnapshots.map { db in
                    TroopSnapshot(
                        date: db.date,
                        villageName: db.villageName,
                        villageX: db.villageX,
                        villageY: db.villageY,
                        troopCounts: db.troopCounts
                    )
                }
                snapshots = loaded
                print("[TroopHistory] \(loaded.count) Snapshots aus Supabase geladen")
            } else {
                print("[TroopHistory] Keine Snapshots in Supabase")
            }
        } catch {
            print("[TroopHistory] Supabase Load fehlgeschlagen: \(error.localizedDescription)")
            // Fallback: Lokaler Cache bleibt bestehen
        }
    }

    /// Synchronisiert neue Snapshots nach Supabase.
    private func syncToSupabase(_ newSnapshots: [TroopSnapshot]) async {
        guard let userId = currentUserId() else { return }

        for snap in newSnapshots {
            do {
                let payload = SupabaseSnapshot(
                    id: nil,
                    userId: userId,
                    date: snap.date,
                    villageName: snap.villageName,
                    villageX: snap.villageX,
                    villageY: snap.villageY,
                    troopCounts: snap.troopCounts
                )
                try await client
                    .from("troop_snapshots")
                    .insert(payload)
                    .execute()
            } catch {
                print("[TroopHistory] Supabase Sync fehlgeschlagen fuer '\(snap.villageName)': \(error.localizedDescription)")
            }
        }
        print("[TroopHistory] \(newSnapshots.count) Snapshots nach Supabase synchronisiert")
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}
