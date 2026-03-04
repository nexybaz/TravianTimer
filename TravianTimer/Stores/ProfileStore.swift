import Foundation
import Observation
import Supabase

// MARK: - Profile Store

@MainActor
@Observable
final class ProfileStore {

    static let shared = ProfileStore()

    var villages: [VillageProfile] = [] {
        didSet { save() }
    }

    @ObservationIgnored private let key = "profileVillagesV1"
    @ObservationIgnored private let migrationKey = "villagesMigratedToSupabase"
    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }

    private init() {
        load()
    }

    // MARK: - Bestehende Methoden (unverändert)

    func seedFromDefaultsIfEmpty() {
        guard villages.isEmpty else { return }
        villages = Defaults.startVillages.map { v in
            VillageProfile(name: v.name, x: v.x, y: v.y, allowedTroops: [], troopCounts: [:])
        }
    }

    func villagesAsStarts(fallback: [StartVillage]) -> [StartVillage] {
        if villages.isEmpty {
            return fallback
        }

        // Tribe-basierte Truppen fuer API-verifizierte Villages ohne manuelle Konfiguration
        let tribeTroops: [TroopKind] = {
            let tribe = AuthService.shared.profile?.tribe ?? ""
            return TroopKind.troops(forSelectedTribeRaw: tribe)
        }()

        return villages.map { vp in
            let troops: [TroopKind]
            if vp.allowedTroops.isEmpty && vp.travianVillageId != nil {
                // API-verifiziertes Village ohne manuellen Truppen-Import:
                // Alle Volks-Truppen als erlaubt setzen (nur in-memory)
                troops = tribeTroops
            } else {
                troops = vp.allowedTroops.compactMap { stored in
                    if let direct = TroopKind.allCases.first(where: { $0.rawValue == stored }) {
                        return direct
                    }
                    return TroopKind.migrateLegacyStoredName(stored)
                }
            }
            return StartVillage(name: vp.name, x: vp.x, y: vp.y, troops: troops)
        }
    }

    func isTroopAllowed(forVillageName name: String, troopRaw: String) -> Bool {
        guard let v = villages.first(where: { $0.name == name }) else {
            // Wenn noch kein Profil gepflegt ist, lieber nichts verstecken.
            // Sobald Profil existiert, gilt Auswahl.
            return villages.isEmpty
        }
        // API-verifiziertes Village ohne manuelle Truppen-Config:
        // Alle Volks-Truppen erlauben
        if v.allowedTroops.isEmpty && v.travianVillageId != nil {
            let tribe = AuthService.shared.profile?.tribe ?? ""
            return TroopKind.troops(forSelectedTribeRaw: tribe)
                .contains(where: { $0.rawValue == troopRaw })
        }
        return v.allowedTroops.contains(troopRaw)
    }

    func upsert(_ village: VillageProfile) {
        if let idx = villages.firstIndex(where: { $0.id == village.id }) {
            villages[idx] = village
        } else {
            villages.append(village)
        }
        // Background Sync zu Supabase
        let villageToSync = village
        Task { await syncToSupabase(villageToSync) }
    }

    func delete(_ village: VillageProfile) {
        villages.removeAll { $0.id == village.id }
        // Background Sync: aus Supabase loeschen
        let villageToDelete = village
        Task { await deleteFromSupabase(villageToDelete) }
    }

    func resetVillages() {
        // Alle Supabase-Villages loeschen
        Task { await deleteAllFromSupabase() }
        villages = []
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    /// Logout: Lokalen Cache leeren ohne Supabase-Daten zu loeschen.
    /// Beim naechsten Login werden die Daten aus Supabase neu geladen.
    func handleLogout() {
        villages = []
        UserDefaults.standard.removeObject(forKey: key)
        // migrationKey NICHT loeschen — Daten sind schon in Supabase
        print("[ProfileStore] Logout — lokaler Cache geleert")
    }

    // MARK: - Lokaler Cache (UserDefaults)

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([VillageProfile].self, from: data) else { return }
        villages = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(villages) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Supabase CRUD

    /// Laedt alle Villages des aktuellen Users aus Supabase.
    /// Wird nach Login und nach Travian-Refresh aufgerufen.
    /// Fuehrt bei Bedarf eine einmalige Migration von lokalen Daten durch.
    func loadFromSupabase() async {
        guard let userId = currentUserId() else {
            print("[ProfileStore] Kein User eingeloggt — skip Supabase Load")
            return
        }

        do {
            let supabaseVillages: [SupabaseVillage] = try await client
                .from("villages")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if supabaseVillages.isEmpty && !villages.isEmpty && !hasMigrated() {
                // Einmalige Migration: Lokale Doerfer zu Supabase hochladen
                print("[ProfileStore] Migration: \(villages.count) lokale Doerfer → Supabase")
                await migrateLocalToSupabase(userId: userId)
                return // migrateLocalToSupabase ruft loadFromSupabase rekursiv auf
            }

            if !supabaseVillages.isEmpty {
                // Supabase-Daten als neue Source-of-Truth setzen,
                // ABER lokale IDs beibehalten (damit VillagePlan.villageId stabil bleibt)
                let oldVillages = villages
                let newVillages = supabaseVillages.map { sv -> VillageProfile in
                    var profile = VillageProfile(from: sv)
                    // Match: existierendes Dorf via supabaseId oder Name+Koordinaten
                    if let existing = oldVillages.first(where: { $0.supabaseId == sv.id }) ??
                                      oldVillages.first(where: { $0.name == sv.name && $0.x == sv.x && $0.y == sv.y }) {
                        profile.id = existing.id  // Lokale ID beibehalten!
                    }
                    return profile
                }
                villages = newVillages
                print("[ProfileStore] \(newVillages.count) Doerfer aus Supabase geladen")
            } else {
                print("[ProfileStore] Keine Doerfer in Supabase (lokaler Cache bleibt)")
            }
        } catch {
            print("[ProfileStore] Supabase Load fehlgeschlagen: \(error.localizedDescription)")
            // Fallback: Lokaler Cache bleibt bestehen
        }
    }

    /// Synchronisiert ein einzelnes Village zu Supabase (UPSERT).
    /// Wird nach lokalen Aenderungen im Background aufgerufen.
    private func syncToSupabase(_ village: VillageProfile) async {
        guard let userId = currentUserId() else { return }

        do {
            if let supabaseId = village.supabaseId {
                // UPDATE: Village hat bereits eine DB-ID
                let payload = village.toUpdate()
                try await client
                    .from("villages")
                    .update(payload)
                    .eq("id", value: supabaseId.uuidString)
                    .execute()
                print("[ProfileStore] Village '\(village.name)' in Supabase aktualisiert")
            } else {
                // INSERT: Neues Village — matche ueber Koordinaten (falls Edge Function es schon angelegt hat)
                let existing: [SupabaseVillage] = try await client
                    .from("villages")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("x", value: village.x)
                    .eq("y", value: village.y)
                    .execute()
                    .value

                if let existingVillage = existing.first, let existingId = existingVillage.id {
                    // UPDATE: Existierendes Village mit neuen App-Daten updaten
                    let payload = village.toUpdate()
                    try await client
                        .from("villages")
                        .update(payload)
                        .eq("id", value: existingId.uuidString)
                        .execute()

                    // Lokales Village mit Supabase-ID aktualisieren
                    if let idx = villages.firstIndex(where: { $0.id == village.id }) {
                        villages[idx].supabaseId = existingId
                        villages[idx].travianVillageId = existingVillage.travianVillageId
                        villages[idx].population = existingVillage.population
                        villages[idx].isCity = existingVillage.isCity ?? false
                    }
                    print("[ProfileStore] Village '\(village.name)' mit bestehendem DB-Eintrag gemerged")
                } else {
                    // INSERT: Komplett neues Village
                    let payload = village.toInsert(userId: userId)
                    let inserted: SupabaseVillage = try await client
                        .from("villages")
                        .insert(payload)
                        .select()
                        .single()
                        .execute()
                        .value

                    // Lokales Village mit neuer Supabase-ID aktualisieren
                    if let idx = villages.firstIndex(where: { $0.id == village.id }),
                       let newId = inserted.id {
                        villages[idx].supabaseId = newId
                    }
                    print("[ProfileStore] Village '\(village.name)' in Supabase erstellt")
                }
            }
        } catch {
            print("[ProfileStore] Supabase Sync fehlgeschlagen fuer '\(village.name)': \(error.localizedDescription)")
        }
    }

    /// Loescht ein Village aus Supabase.
    private func deleteFromSupabase(_ village: VillageProfile) async {
        guard let userId = currentUserId() else { return }

        do {
            if let supabaseId = village.supabaseId {
                // Direkt ueber DB-ID loeschen
                try await client
                    .from("villages")
                    .delete()
                    .eq("id", value: supabaseId.uuidString)
                    .execute()
                print("[ProfileStore] Village '\(village.name)' aus Supabase geloescht")
            } else {
                // Fallback: Ueber Koordinaten + User loeschen
                try await client
                    .from("villages")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("x", value: village.x)
                    .eq("y", value: village.y)
                    .execute()
                print("[ProfileStore] Village '\(village.name)' via Koordinaten aus Supabase geloescht")
            }
        } catch {
            print("[ProfileStore] Supabase Delete fehlgeschlagen fuer '\(village.name)': \(error.localizedDescription)")
        }
    }

    /// Loescht alle Villages des aktuellen Users aus Supabase.
    private func deleteAllFromSupabase() async {
        guard let userId = currentUserId() else { return }

        do {
            try await client
                .from("villages")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            print("[ProfileStore] Alle Villages aus Supabase geloescht")
        } catch {
            print("[ProfileStore] Supabase Delete All fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Einmalige Migration (lokal → Supabase)

    /// Migriert lokale Villages zu Supabase. Wird nur einmalig ausgefuehrt.
    private func migrateLocalToSupabase(userId: String) async {
        let localVillages = villages

        for village in localVillages {
            do {
                // Pruefen ob ein Village mit gleichen Koordinaten schon in Supabase existiert
                // (z.B. durch Edge Function angelegt)
                let existing: [SupabaseVillage] = try await client
                    .from("villages")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("x", value: village.x)
                    .eq("y", value: village.y)
                    .execute()
                    .value

                if let existingVillage = existing.first, let existingId = existingVillage.id {
                    // Merge: Lokale Truppen-Daten in bestehendes DB-Village updaten
                    let payload = village.toUpdate()
                    try await client
                        .from("villages")
                        .update(payload)
                        .eq("id", value: existingId.uuidString)
                        .execute()
                    print("[ProfileStore] Migration Merge: '\(village.name)' (\(village.x)|\(village.y))")
                } else {
                    // Neues Village in Supabase erstellen
                    let payload = village.toInsert(userId: userId)
                    try await client
                        .from("villages")
                        .insert(payload)
                        .execute()
                    print("[ProfileStore] Migration Insert: '\(village.name)' (\(village.x)|\(village.y))")
                }
            } catch {
                print("[ProfileStore] Migration fehlgeschlagen fuer '\(village.name)': \(error.localizedDescription)")
            }
        }

        // Migration-Flag setzen
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("[ProfileStore] Migration abgeschlossen — \(localVillages.count) Doerfer")

        // Jetzt frische Daten aus Supabase laden (mit korrekten DB-IDs)
        await loadFromSupabase()
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        // Synchron: User-ID aus dem lokalen Session-Cache
        // Der Supabase-Client cached die Session lokal nach dem Login
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }

    private func hasMigrated() -> Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }
}
