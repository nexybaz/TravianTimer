import Foundation

// MARK: - Call Model (Supabase-kompatibel)

struct CallItem: Identifiable, Hashable, Codable {

    enum Status: String, Codable {
        case open
        case inactive
        case archived

        /// Legacy-Alias: .done → .inactive (Backward-Compat)
        static let done = Status.inactive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy    = "created_by"
        case kingdomId    = "kingdom_id"
        case title
        case targetX      = "target_x"
        case targetY      = "target_y"
        case arrival
        case link
        case cropLimit         = "crop_limit"
        case cropPledgedTotal  = "crop_pledged_total"
        case status
        case discordChannelId  = "discord_channel_id"
        case discordMessageId  = "discord_message_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    var id: UUID = UUID()
    var createdBy: UUID?
    var kingdomId: Int?
    var title: String
    var targetX: Int
    var targetY: Int
    var arrival: Date
    var link: String?              // TEXT in DB (nicht URL)
    var cropLimit: Int?
    var cropPledgedTotal: Int = 0   // DB-Aggregat (wird von Edge Function + manuellem Discord-Update gesetzt)
    var status: Status = .open
    var discordChannelId: String?
    var discordMessageId: String?
    var createdAt: Date = .now
    var updatedAt: Date = .now

    // Custom Decoder: Supabase snake_case + optionale Felder
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdBy        = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        kingdomId        = try c.decodeIfPresent(Int.self, forKey: .kingdomId)
        title            = try c.decode(String.self, forKey: .title)
        targetX          = try c.decode(Int.self, forKey: .targetX)
        targetY          = try c.decode(Int.self, forKey: .targetY)
        arrival          = try c.decode(Date.self, forKey: .arrival)
        link             = try c.decodeIfPresent(String.self, forKey: .link)
        cropLimit        = try c.decodeIfPresent(Int.self, forKey: .cropLimit)
        cropPledgedTotal = try c.decodeIfPresent(Int.self, forKey: .cropPledgedTotal) ?? 0
        status           = try c.decodeIfPresent(Status.self, forKey: .status) ?? .open
        discordChannelId = try c.decodeIfPresent(String.self, forKey: .discordChannelId)
        discordMessageId = try c.decodeIfPresent(String.self, forKey: .discordMessageId)
        createdAt        = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt        = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: UUID = UUID(),
        createdBy: UUID? = nil,
        kingdomId: Int? = nil,
        title: String,
        targetX: Int,
        targetY: Int,
        arrival: Date,
        link: String? = nil,
        cropLimit: Int? = nil,
        cropPledgedTotal: Int = 0,
        status: Status = .open,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.createdBy = createdBy
        self.kingdomId = kingdomId
        self.title = title
        self.targetX = targetX
        self.targetY = targetY
        self.arrival = arrival
        self.link = link
        self.cropLimit = cropLimit
        self.cropPledgedTotal = cropPledgedTotal
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: CallItem, rhs: CallItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.targetX == rhs.targetX &&
        lhs.targetY == rhs.targetY &&
        lhs.arrival == rhs.arrival &&
        lhs.link == rhs.link &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt &&
        lhs.cropLimit == rhs.cropLimit &&
        lhs.cropPledgedTotal == rhs.cropPledgedTotal &&
        lhs.updatedAt == rhs.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Convenience: URL aus dem link-String
    var linkURL: URL? {
        guard let link else { return nil }
        return URL(string: link)
    }

    /// Ist dieser Call "erledigt"? (inactive oder archived)
    var isDone: Bool {
        status == .inactive || status == .archived
    }
}

// MARK: - Insert-Modell fuer Supabase (ohne id, created_at etc.)

struct CallInsert: Codable {
    let createdBy: UUID
    let kingdomId: Int?
    let title: String
    let targetX: Int
    let targetY: Int
    let arrival: Date
    let link: String?
    let cropLimit: Int?
    let status: String

    enum CodingKeys: String, CodingKey {
        case createdBy    = "created_by"
        case kingdomId    = "kingdom_id"
        case title
        case targetX      = "target_x"
        case targetY      = "target_y"
        case arrival
        case link
        case cropLimit    = "crop_limit"
        case status
    }
}

// MARK: - Legacy (fuer alte UserDefaults-Daten, nicht mehr aktiv genutzt)

struct CallsPayload: Codable {
    var version: Int = 3
    var savedAt: Date = .now
    var calls: [LegacyCallItem]
}

/// Altes CallItem-Format fuer UserDefaults-Migration
struct LegacyCallItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var targetX: Int
    var targetY: Int
    var arrival: Date
    var link: URL?
    var status: String = "open"
    var createdAt: Date = .now
    var cropLimit: Int?
    var pledges: [TroopPledge] = []
    var updatedAt: Date = .now

    enum CodingKeys: String, CodingKey {
        case id, title, targetX, targetY, arrival, link, status, createdAt
        case cropLimit, pledges, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title       = try c.decode(String.self, forKey: .title)
        targetX     = try c.decode(Int.self, forKey: .targetX)
        targetY     = try c.decode(Int.self, forKey: .targetY)
        arrival     = try c.decode(Date.self, forKey: .arrival)
        link        = try c.decodeIfPresent(URL.self, forKey: .link)
        status      = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        createdAt   = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        cropLimit   = try c.decodeIfPresent(Int.self, forKey: .cropLimit)
        pledges     = try c.decodeIfPresent([TroopPledge].self, forKey: .pledges) ?? []
        updatedAt   = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
