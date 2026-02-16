import Foundation

/// Eine einzelne Truppenmeldung eines Spielers für einen Deff-Call.
struct TroopPledge: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var playerName: String          // z.B. "MarcFrei"
    var villageName: String         // z.B. "Bowser Castle"
    var villageX: Int
    var villageY: Int
    var troopKind: String           // TroopKind.rawValue
    var count: Int
    var pledgedAt: Date = .now

    /// User-ID des Pledgers (für Team-Pledges, optional bei eigenen Pledges)
    var userId: String?
}
