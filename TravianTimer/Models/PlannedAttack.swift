import Foundation
import SwiftUI

// MARK: - Attack Type (Getter-Tools kompatibel)

enum AttackType: String, Codable, CaseIterable, Identifiable, Hashable {
    case attack       = "attack"
    case fake         = "fake"
    case preNoble     = "pre_noble"
    case noble        = "noble"
    case nobleFake    = "noble_fake"
    case raid         = "raid"
    case raidFake     = "raid_fake"
    case siege        = "siege"
    case scout        = "scout"
    case support      = "support"
    case supportFake  = "support_fake"
    case wwSupport    = "ww_support"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .attack:      return "Angriff"
        case .fake:        return "Fake"
        case .preNoble:    return "Voradeln"
        case .noble:       return "Adeln"
        case .nobleFake:   return "Adels-Fake"
        case .raid:        return "Raubzug"
        case .raidFake:    return "Raubzug-Fake"
        case .siege:       return "Belagerung"
        case .scout:       return "Spähen"
        case .support:     return "Unterstützung"
        case .supportFake: return "Unterst.-Fake"
        case .wwSupport:   return "ZD-Unterst."
        }
    }

    var shortLabel: String {
        switch self {
        case .attack:      return "Angriff"
        case .fake:        return "Fake"
        case .preNoble:    return "Voradel"
        case .noble:       return "Adel"
        case .nobleFake:   return "A-Fake"
        case .raid:        return "Raid"
        case .raidFake:    return "R-Fake"
        case .siege:       return "Siege"
        case .scout:       return "Scout"
        case .support:     return "Deff"
        case .supportFake: return "D-Fake"
        case .wwSupport:   return "ZD"
        }
    }

    var color: Color {
        switch self {
        case .attack:      return .red
        case .fake:        return .blue
        case .preNoble:    return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .noble:       return .red
        case .nobleFake:   return .teal
        case .raid:        return .brown
        case .raidFake:    return .brown
        case .siege:       return .red
        case .scout:       return Color(red: 0.0, green: 0.39, blue: 0.0)
        case .support:     return .green
        case .supportFake: return .green
        case .wwSupport:   return .green
        }
    }

    var icon: String {
        switch self {
        case .attack:      return "flame.fill"
        case .fake:        return "theatermasks"
        case .preNoble:    return "crown"
        case .noble:       return "crown.fill"
        case .nobleFake:   return "theatermasks.fill"
        case .raid:        return "shippingbox.fill"
        case .raidFake:    return "shippingbox"
        case .siege:       return "building.2.fill"
        case .scout:       return "eye.fill"
        case .support:     return "shield.fill"
        case .supportFake: return "shield"
        case .wwSupport:   return "shield.checkered"
        }
    }

    /// Getter-Tools type ID (fuer Import/Export)
    var getterId: Int {
        switch self {
        case .attack:      return 1
        case .fake:        return 10
        case .preNoble:    return 2
        case .noble:       return 3
        case .nobleFake:   return 11
        case .raid:        return 4
        case .raidFake:    return 12
        case .siege:       return 5
        case .scout:       return 20
        case .support:     return 30
        case .supportFake: return 31
        case .wwSupport:   return 32
        }
    }

    static func fromGetterId(_ id: Int) -> AttackType? {
        allCases.first { $0.getterId == id }
    }

    /// Haeufigste Typen zuerst (fuer Picker)
    static var commonTypes: [AttackType] {
        [.attack, .fake, .noble, .preNoble, .nobleFake, .raid, .raidFake, .siege, .scout, .support, .supportFake, .wwSupport]
    }
}

// MARK: - Planned Attack Model (Supabase-kompatibel)

struct PlannedAttack: Identifiable, Hashable, Codable {

    enum CodingKeys: String, CodingKey {
        case id
        case operationId   = "operation_id"
        case assignedTo    = "assigned_to"
        case attackType    = "attack_type"
        case playerName    = "player_name"
        case villageName   = "village_name"
        case villageX      = "village_x"
        case villageY      = "village_y"
        case targetX       = "target_x"
        case targetY       = "target_y"
        case targetPlayer  = "target_player"
        case targetVillage = "target_village"
        case arrival
        case travelSeconds = "travel_seconds"
        case departureAt   = "departure_at"
        case troopSpeed    = "troop_speed"
        case confirmed
        case sent
        case confirmedAt   = "confirmed_at"
        case sentAt        = "sent_at"
        case notes
        case sortOrder     = "sort_order"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    var id: UUID = UUID()
    var operationId: UUID
    var assignedTo: UUID?
    var attackType: AttackType = .attack
    var playerName: String
    var villageName: String
    var villageX: Int
    var villageY: Int
    var targetX: Int
    var targetY: Int
    var targetPlayer: String?
    var targetVillage: String?
    var arrival: Date
    var travelSeconds: Double
    var departureAt: Date
    var troopSpeed: Double = 3.0
    var confirmed: Bool = false
    var sent: Bool = false
    var confirmedAt: Date?
    var sentAt: Date?
    var notes: String?
    var sortOrder: Int = 0
    var createdAt: Date = .now
    var updatedAt: Date = .now

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        operationId   = try c.decode(UUID.self, forKey: .operationId)
        assignedTo    = try c.decodeIfPresent(UUID.self, forKey: .assignedTo)
        attackType    = try c.decodeIfPresent(AttackType.self, forKey: .attackType) ?? .attack
        playerName    = try c.decode(String.self, forKey: .playerName)
        villageName   = try c.decode(String.self, forKey: .villageName)
        villageX      = try c.decode(Int.self, forKey: .villageX)
        villageY      = try c.decode(Int.self, forKey: .villageY)
        targetX       = try c.decode(Int.self, forKey: .targetX)
        targetY       = try c.decode(Int.self, forKey: .targetY)
        targetPlayer  = try c.decodeIfPresent(String.self, forKey: .targetPlayer)
        targetVillage = try c.decodeIfPresent(String.self, forKey: .targetVillage)
        arrival       = try c.decode(Date.self, forKey: .arrival)
        travelSeconds = try c.decode(Double.self, forKey: .travelSeconds)
        departureAt   = try c.decode(Date.self, forKey: .departureAt)
        troopSpeed    = try c.decodeIfPresent(Double.self, forKey: .troopSpeed) ?? 3.0
        confirmed     = try c.decodeIfPresent(Bool.self, forKey: .confirmed) ?? false
        sent          = try c.decodeIfPresent(Bool.self, forKey: .sent) ?? false
        confirmedAt   = try c.decodeIfPresent(Date.self, forKey: .confirmedAt)
        sentAt        = try c.decodeIfPresent(Date.self, forKey: .sentAt)
        notes         = try c.decodeIfPresent(String.self, forKey: .notes)
        sortOrder     = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt     = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt     = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: UUID = UUID(), operationId: UUID, assignedTo: UUID? = nil,
        attackType: AttackType = .attack,
        playerName: String, villageName: String, villageX: Int, villageY: Int,
        targetX: Int, targetY: Int, targetPlayer: String? = nil, targetVillage: String? = nil,
        arrival: Date, travelSeconds: Double, departureAt: Date, troopSpeed: Double = 3.0,
        confirmed: Bool = false, sent: Bool = false, notes: String? = nil, sortOrder: Int = 0
    ) {
        self.id = id
        self.operationId = operationId
        self.assignedTo = assignedTo
        self.attackType = attackType
        self.playerName = playerName
        self.villageName = villageName
        self.villageX = villageX
        self.villageY = villageY
        self.targetX = targetX
        self.targetY = targetY
        self.targetPlayer = targetPlayer
        self.targetVillage = targetVillage
        self.arrival = arrival
        self.travelSeconds = travelSeconds
        self.departureAt = departureAt
        self.troopSpeed = troopSpeed
        self.confirmed = confirmed
        self.sent = sent
        self.notes = notes
        self.sortOrder = sortOrder
    }

    static func == (lhs: PlannedAttack, rhs: PlannedAttack) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Ist die Absendezeit bereits verstrichen?
    var isDeparturePast: Bool { departureAt < .now }
}

// MARK: - Insert Model

struct PlannedAttackInsert: Codable {
    let operationId: UUID
    let assignedTo: UUID?
    let attackType: AttackType
    let playerName: String
    let villageName: String
    let villageX: Int
    let villageY: Int
    let targetX: Int
    let targetY: Int
    let targetPlayer: String?
    let targetVillage: String?
    let arrival: Date
    let travelSeconds: Double
    let departureAt: Date
    let troopSpeed: Double
    let notes: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case operationId   = "operation_id"
        case assignedTo    = "assigned_to"
        case attackType    = "attack_type"
        case playerName    = "player_name"
        case villageName   = "village_name"
        case villageX      = "village_x"
        case villageY      = "village_y"
        case targetX       = "target_x"
        case targetY       = "target_y"
        case targetPlayer  = "target_player"
        case targetVillage = "target_village"
        case arrival
        case travelSeconds = "travel_seconds"
        case departureAt   = "departure_at"
        case troopSpeed    = "troop_speed"
        case notes
        case sortOrder     = "sort_order"
    }
}

// MARK: - Leichtgewichtige Structs fuer Realtime DELETE

struct PlannedAttackIdOnly: Codable {
    let id: UUID
}

struct OperationIdOnly: Codable {
    let id: UUID
}
