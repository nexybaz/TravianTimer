import Foundation
import Observation
import Supabase

// MARK: - Village Plan Store
//
// Dual-Persistenz:
//   1. UserDefaults (primaer)  — sofort, zuverlässig, kein Auth noetig
//   2. Datei (Backup)          — atomare Schreibvorgaenge
//   3. Supabase (Cloud-Sync)   — debounced 500ms, braucht Auth
//
// Beim Start wird aus BEIDEN lokalen Quellen geladen (wer mehr Plaene hat, gewinnt).
// Jeder Save schreibt in BEIDE + async Supabase.

@MainActor
@Observable
final class VillagePlanStore {

    static let shared = VillagePlanStore()

    var plans: [VillagePlan] = []
    var isLoaded: Bool = false

    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    // Keys / Pfade
    @ObservationIgnored private static let defaultsKey = "village_plans_v2"
    @ObservationIgnored private static let fileName = "village_plans.json"

    private init() {
        loadLocal()
        print("[VillagePlanStore] Init — \(plans.count) Plaene geladen")
    }

    // MARK: - Public API

    func plans(for villageId: UUID) -> [VillagePlan] {
        plans.filter { $0.villageId == villageId }
    }

    func upsert(_ plan: VillagePlan) {
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        } else {
            plans.append(plan)
        }
        save()
    }

    func delete(_ plan: VillagePlan) {
        plans.removeAll { $0.id == plan.id }
        save()
    }

    func deletePlans(for villageId: UUID) {
        plans.removeAll { $0.villageId == villageId }
        save()
    }

    /// Entfernt Plaene deren villageId keinem bekannten Dorf entspricht.
    func cleanupOrphanedPlans(knownVillageIds: Set<UUID>) {
        guard !knownVillageIds.isEmpty else { return }
        let before = plans.count
        plans.removeAll { !knownVillageIds.contains($0.villageId) }
        let removed = before - plans.count
        if removed > 0 {
            save()
            print("[VillagePlanStore] Cleanup: \(removed) verwaiste Plaene entfernt (\(plans.count) verbleiben)")
        }
    }

    // MARK: - Speichern

    func save() {
        saveLocal()
        // Supabase debounced
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await syncToSupabase()
        }
    }

    // MARK: - Lifecycle (aufgerufen von AuthService)

    func loadFromSupabase() async {
        guard let userId = currentUserId() else { return }

        // Falls plans leer ist (z.B. nach handleLogout), lokale Daten laden
        if plans.isEmpty {
            loadLocal()
            if !plans.isEmpty {
                print("[VillagePlanStore] Lokale Plaene wiederhergestellt: \(plans.count)")
            }
        }

        let localCount = plans.count

        do {
            let rows: [VillagePlansRow] = try await client
                .from("village_plans_sync")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let cloudPlans = rows.first?.plans ?? []

            if cloudPlans.isEmpty && !plans.isEmpty {
                // Cloud leer, lokal vorhanden → hochladen
                await syncToSupabase()
                print("[VillagePlanStore] Cloud leer: \(plans.count) lokale Plaene hochgeladen")
            } else if !cloudPlans.isEmpty && plans.count > cloudPlans.count {
                // Lokal hat MEHR Plaene als Cloud → lokale behalten + Cloud aktualisieren
                // (z.B. letzter Plan wurde vor App-Kill nicht gesynct)
                await syncToSupabase()
                print("[VillagePlanStore] Lokal (\(plans.count)) > Cloud (\(cloudPlans.count)): lokale Plaene behalten + Cloud aktualisiert")
            } else if !cloudPlans.isEmpty {
                // Cloud hat gleich viele oder mehr Plaene → Cloud ist Source of Truth
                plans = cloudPlans
                saveLocal()
                print("[VillagePlanStore] Cloud: \(plans.count) Plaene geladen")
            }
            isLoaded = true
        } catch {
            isLoaded = true
            print("[VillagePlanStore] Cloud-Fehler: \(error.localizedDescription)")
        }
    }

    func handleLogout() {
        let count = plans.count
        plans = []
        isLoaded = false
        // WICHTIG: NICHT saveLocal() aufrufen!
        // Grund: Auth-Listener kann ein transientes "kein Session"-Event feuern
        // BEVOR die gespeicherte Session wiederhergestellt wird.
        // Wenn wir hier saveLocal() aufrufen, wird [] in UserDefaults + Datei geschrieben
        // und alle Plaene sind permanent geloescht.
        // Memory ist geleert → UI zeigt keine Plaene.
        // Persistente Daten bleiben als Sicherheitsnetz erhalten
        // und werden beim naechsten Login von loadFromSupabase() ueberschrieben.
        print("[VillagePlanStore] Logout — \(count) Plaene geleert (nur Memory)")
    }

    // MARK: - Lokale Persistenz (UserDefaults + Datei)

    private func loadLocal() {
        // 1. UserDefaults (primaer)
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey) {
            do {
                let loaded = try JSONDecoder().decode([VillagePlan].self, from: data)
                if !loaded.isEmpty {
                    plans = loaded
                    print("[VillagePlanStore] UserDefaults: \(loaded.count) Plaene")
                    return
                }
            } catch {
                print("[VillagePlanStore] UserDefaults DECODE FEHLER: \(error)")
            }
        }

        // 2. Datei (Backup)
        let url = Self.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode([VillagePlan].self, from: data)
                if !loaded.isEmpty {
                    plans = loaded
                    print("[VillagePlanStore] Datei: \(loaded.count) Plaene")
                    // Auch in UserDefaults speichern fuer naechsten Start
                    if let encoded = try? JSONEncoder().encode(plans) {
                        UserDefaults.standard.set(encoded, forKey: Self.defaultsKey)
                    }
                    return
                }
            } catch {
                print("[VillagePlanStore] Datei DECODE FEHLER: \(error)")
            }
        }

        // 3. Alt-Migration (villagePlansV1)
        if let data = UserDefaults.standard.data(forKey: "villagePlansV1") {
            do {
                plans = try JSONDecoder().decode([VillagePlan].self, from: data)
                print("[VillagePlanStore] Migration villagePlansV1: \(plans.count) Plaene")
                saveLocal()
                UserDefaults.standard.removeObject(forKey: "villagePlansV1")
            } catch {
                print("[VillagePlanStore] villagePlansV1 FEHLER: \(error)")
            }
        }
    }

    private func saveLocal() {
        do {
            let data = try JSONEncoder().encode(plans)

            // 1. UserDefaults (primaer, sofort)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            // Sofort auf Disk flushen — verhindert Datenverlust bei App-Kill
            UserDefaults.standard.synchronize()

            // 2. Datei (Backup, atomar)
            try data.write(to: Self.fileURL, options: .atomic)

            print("[VillagePlanStore] Gespeichert: \(plans.count) Plaene (\(data.count) bytes)")
        } catch {
            print("[VillagePlanStore] SPEICHERN FEHLGESCHLAGEN: \(error)")
        }
    }

    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    // MARK: - Supabase Sync

    private func syncToSupabase() async {
        guard let userId = currentUserId() else { return }
        let row = VillagePlansRow(userId: userId, plans: plans)
        do {
            try await client
                .from("village_plans_sync")
                .upsert(row, onConflict: "user_id")
                .execute()
        } catch {
            print("[VillagePlanStore] Supabase Sync Fehler: \(error.localizedDescription)")
        }
    }

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}
