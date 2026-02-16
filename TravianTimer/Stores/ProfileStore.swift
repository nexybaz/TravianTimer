import Foundation
import Combine

// MARK: - Profile Store

final class ProfileStore: ObservableObject {

    static let shared = ProfileStore()

    @Published var villages: [VillageProfile] = [] {
        didSet { save() }
    }

    private let key = "profileVillagesV1"

    private init() {
        load()
    }

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

        // StartVillage verlangt zusätzlich die Truppenliste.
        // Option A: Wenn keine Truppen gewählt sind, bleibt die Liste leer.
        return villages.map { vp in
            let troops: [TroopKind] = vp.allowedTroops.compactMap { stored in
                if let direct = TroopKind.allCases.first(where: { $0.rawValue == stored }) {
                    return direct
                }
                return TroopKind.migrateLegacyStoredName(stored)
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
        return v.allowedTroops.contains(troopRaw)
    }

    func upsert(_ village: VillageProfile) {
        if let idx = villages.firstIndex(where: { $0.id == village.id }) {
            villages[idx] = village
        } else {
            villages.append(village)
        }
    }

    func delete(_ village: VillageProfile) {
        villages.removeAll { $0.id == village.id }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([VillageProfile].self, from: data) else { return }
        villages = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(villages) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func resetVillages() {
        villages = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
