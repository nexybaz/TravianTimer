import Foundation

// MARK: - Notification Preferences (Supabase-kompatibel)

struct NotificationPreferences: Codable {

    var id: UUID
    var userId: UUID
    var newCall: Bool
    var pledgeReceived: Bool
    var guideProgress: Bool
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case newCall            = "new_call"
        case pledgeReceived     = "pledge_received"
        case guideProgress      = "guide_progress"
        case updatedAt          = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id              = try container.decode(UUID.self, forKey: .id)
        userId          = try container.decode(UUID.self, forKey: .userId)
        newCall         = (try? container.decode(Bool.self, forKey: .newCall)) ?? true
        pledgeReceived  = (try? container.decode(Bool.self, forKey: .pledgeReceived)) ?? true
        guideProgress   = (try? container.decode(Bool.self, forKey: .guideProgress)) ?? true
        updatedAt       = (try? container.decode(Date.self, forKey: .updatedAt)) ?? .now
    }
}
