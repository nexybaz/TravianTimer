import Foundation

// MARK: - Operation Model (Supabase-kompatibel)

struct Operation: Identifiable, Hashable, Codable {

    enum Status: String, Codable, CaseIterable {
        case planning
        case active
        case completed
        case cancelled

        var label: String {
            switch self {
            case .planning:  return "Geplant"
            case .active:    return "Aktiv"
            case .completed: return "Abgeschlossen"
            case .cancelled: return "Abgebrochen"
            }
        }
    }

    enum Visibility: String, Codable {
        case full
        case personal
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy    = "created_by"
        case kingdomId    = "kingdom_id"
        case joinCode     = "join_code"
        case title
        case description
        case worldSpeed   = "world_speed"
        case status
        case visibility
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    var id: UUID = UUID()
    var createdBy: UUID?
    var kingdomId: Int?
    var joinCode: String?
    var title: String
    var description: String?
    var worldSpeed: Double = 1.0
    var status: Status = .planning
    var visibility: Visibility = .full
    var createdAt: Date = .now
    var updatedAt: Date = .now

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdBy   = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        kingdomId   = try c.decodeIfPresent(Int.self, forKey: .kingdomId)
        joinCode    = try c.decodeIfPresent(String.self, forKey: .joinCode)
        title       = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        worldSpeed  = try c.decodeIfPresent(Double.self, forKey: .worldSpeed) ?? 1.0
        status      = try c.decodeIfPresent(Status.self, forKey: .status) ?? .planning
        visibility  = try c.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .full
        createdAt   = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt   = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    init(
        id: UUID = UUID(), createdBy: UUID? = nil, kingdomId: Int? = nil,
        joinCode: String? = nil, title: String, description: String? = nil,
        worldSpeed: Double = 1.0, status: Status = .planning,
        visibility: Visibility = .full, createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.createdBy = createdBy
        self.kingdomId = kingdomId
        self.joinCode = joinCode
        self.title = title
        self.description = description
        self.worldSpeed = worldSpeed
        self.status = status
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: Operation, rhs: Operation) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var isDone: Bool {
        status == .completed || status == .cancelled
    }
}

// MARK: - Insert Model

struct OperationInsert: Codable {
    let createdBy: UUID
    let kingdomId: Int?
    let title: String
    let description: String?
    let worldSpeed: Double
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case createdBy   = "created_by"
        case kingdomId   = "kingdom_id"
        case title, description
        case worldSpeed  = "world_speed"
        case visibility
    }
}
