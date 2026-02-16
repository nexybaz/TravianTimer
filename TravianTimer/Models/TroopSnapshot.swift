import Foundation

// MARK: - Troop Snapshot (Verlauf)

struct TroopSnapshot: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var villageName: String
    var villageX: Int
    var villageY: Int
    var troopCounts: [String: Int]   // TroopKind.rawValue → count
}
