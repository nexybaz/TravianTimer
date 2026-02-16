import Foundation

// MARK: - Player Profile (Local)

struct VillageProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var x: Int
    var y: Int

    // Option A: default leer. Nur ausgewählte Truppen werden berücksichtigt.
    var allowedTroops: [String] = []

    // Exact troop counts per troop key (TroopKind.rawValue). Filled by the troop overview import.
    // Presence filtering in the app still uses `allowedTroops`.
    var troopCounts: [String: Int] = [:]
}
