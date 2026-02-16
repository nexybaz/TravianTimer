import Foundation

// MARK: - Call Model

struct CallItem: Identifiable, Hashable, Codable {

    enum Status: String, Codable {
        case open
        case done
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

    // Custom Decoder: bestehende Calls ohne pledges/cropLimit fehlerfrei laden
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
        discordMessageId: String? = nil
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
    }
}

struct CallsPayload: Codable {
    var version: Int = 2
    var savedAt: Date = .now
    var calls: [CallItem]
}
