import Foundation

// MARK: - Call Model

struct CallItem: Identifiable, Hashable, Codable {

    enum Status: String, Codable {
        case open
        case done
    }

    // Explizite CodingKeys: deletedPledgeIds + isShared werden NICHT persistiert (transient)
    enum CodingKeys: String, CodingKey {
        case id, title, targetX, targetY, arrival, link, status, createdAt
        case cropLimit, pledges, discordMessageId, updatedAt, guildId
    }

    var id: UUID = UUID()
    var title: String
    var targetX: Int
    var targetY: Int
    var arrival: Date
    var link: URL?
    var status: Status = .open
    var createdAt: Date = .now

    /// Getreide-Obergrenze die der Caller definiert (optional)
    var cropLimit: Int?

    /// Lokale Truppenmeldungen (später: von anderen Spielern empfangen)
    var pledges: [TroopPledge] = []

    /// Discord Message ID für Deduplizierung (optional, nur bei Remote-Push)
    var discordMessageId: String?

    /// Zeitstempel der letzten Änderung (für Cloud-Sync Konfliktauflösung)
    var updatedAt: Date = .now

    /// Discord Guild ID für Team-Zuordnung (optional)
    var guildId: String?

    /// Pledge-IDs die lokal gelöscht wurden (transient, nur für nächsten Push)
    var deletedPledgeIds: [UUID] = []

    /// Team-Call: gehört einem anderen User, wird nicht lokal persistiert (transient)
    var isShared: Bool = false

    // Custom Decoder: bestehende Calls ohne pledges/cropLimit/updatedAt fehlerfrei laden
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title       = try c.decode(String.self, forKey: .title)
        targetX     = try c.decode(Int.self, forKey: .targetX)
        targetY     = try c.decode(Int.self, forKey: .targetY)
        arrival     = try c.decode(Date.self, forKey: .arrival)
        link        = try c.decodeIfPresent(URL.self, forKey: .link)
        status      = try c.decodeIfPresent(Status.self, forKey: .status) ?? .open
        createdAt   = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        cropLimit   = try c.decodeIfPresent(Int.self, forKey: .cropLimit)
        pledges     = try c.decodeIfPresent([TroopPledge].self, forKey: .pledges) ?? []
        discordMessageId = try c.decodeIfPresent(String.self, forKey: .discordMessageId)
        updatedAt   = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        guildId     = try c.decodeIfPresent(String.self, forKey: .guildId)
        // deletedPledgeIds + isShared sind transient — nicht decodiert
    }

    init(
        id: UUID = UUID(),
        title: String,
        targetX: Int,
        targetY: Int,
        arrival: Date,
        link: URL? = nil,
        status: Status = .open,
        createdAt: Date = .now,
        cropLimit: Int? = nil,
        pledges: [TroopPledge] = [],
        discordMessageId: String? = nil,
        updatedAt: Date = .now,
        guildId: String? = nil,
        isShared: Bool = false
    ) {
        self.id = id
        self.title = title
        self.targetX = targetX
        self.targetY = targetY
        self.arrival = arrival
        self.link = link
        self.status = status
        self.createdAt = createdAt
        self.cropLimit = cropLimit
        self.pledges = pledges
        self.discordMessageId = discordMessageId
        self.updatedAt = updatedAt
        self.guildId = guildId
        self.isShared = isShared
    }

    // Hashable: deletedPledgeIds + isShared ignorieren (transient)
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
        lhs.pledges == rhs.pledges &&
        lhs.discordMessageId == rhs.discordMessageId &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.guildId == rhs.guildId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CallsPayload: Codable {
    var version: Int = 3
    var savedAt: Date = .now
    var calls: [CallItem]
}
