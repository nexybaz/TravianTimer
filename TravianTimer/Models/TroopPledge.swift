import Foundation

/// Eine einzelne Truppenmeldung eines Spielers fuer einen Deff-Call.
/// Supabase-kompatibel: CodingKeys mappen auf snake_case DB-Spalten.
struct TroopPledge: Identifiable, Codable, Hashable {

    enum CodingKeys: String, CodingKey {
        case id
        case callId       = "call_id"
        case userId       = "user_id"
        case playerName   = "player_name"
        case villageName  = "village_name"
        case villageX     = "village_x"
        case villageY     = "village_y"
        case troopKind    = "troop_kind"
        case count
        case pledgedAt    = "pledged_at"
    }

    var id: UUID = UUID()
    var callId: UUID                    // Fremdschluessel auf calls.id
    var userId: UUID?                   // Fremdschluessel auf profiles.id
    var playerName: String              // z.B. "MarcFrei"
    var villageName: String             // z.B. "Bowser Castle"
    var villageX: Int
    var villageY: Int
    var troopKind: String               // TroopKind.rawValue
    var count: Int
    var pledgedAt: Date = .now

    init(
        id: UUID = UUID(),
        callId: UUID,
        userId: UUID? = nil,
        playerName: String,
        villageName: String,
        villageX: Int,
        villageY: Int,
        troopKind: String,
        count: Int,
        pledgedAt: Date = .now
    ) {
        self.id = id
        self.callId = callId
        self.userId = userId
        self.playerName = playerName
        self.villageName = villageName
        self.villageX = villageX
        self.villageY = villageY
        self.troopKind = troopKind
        self.count = count
        self.pledgedAt = pledgedAt
    }
}

// MARK: - Insert-Modell fuer Supabase (ohne id, pledged_at)

struct PledgeInsert: Codable {
    let callId: UUID
    let userId: UUID
    let playerName: String
    let villageName: String
    let villageX: Int
    let villageY: Int
    let troopKind: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case callId       = "call_id"
        case userId       = "user_id"
        case playerName   = "player_name"
        case villageName  = "village_name"
        case villageX     = "village_x"
        case villageY     = "village_y"
        case troopKind    = "troop_kind"
        case count
    }
}
