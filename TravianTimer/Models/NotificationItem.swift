import Foundation
import SwiftUI

// MARK: - App Notification Type

enum AppNotificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case newCall        = "new_call"
    case pledgeReceived = "pledge_received"
    case guideProgress  = "guide_progress"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newCall:           return "Neuer Deff-Call"
        case .pledgeReceived:    return "Truppen zugesagt"
        case .guideProgress:     return "Guide-Fortschritt"
        }
    }

    var icon: String {
        switch self {
        case .newCall:           return "megaphone.fill"
        case .pledgeReceived:    return "shield.fill"
        case .guideProgress:     return "list.clipboard.fill"
        }
    }

    var color: Color {
        switch self {
        case .newCall:           return .orange
        case .pledgeReceived:    return .blue
        case .guideProgress:     return .green
        }
    }
}

// MARK: - Notification Item (Supabase-kompatibel)

struct NotificationItem: Identifiable, Codable, Hashable {

    var id: UUID
    var userId: UUID
    var kingdomId: Int?
    var type: String
    var title: String
    var body: String
    var referenceId: UUID?
    var referenceType: String?
    var actorId: UUID?
    var actorName: String?
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case kingdomId     = "kingdom_id"
        case type
        case title
        case body
        case referenceId   = "reference_id"
        case referenceType = "reference_type"
        case actorId       = "actor_id"
        case actorName     = "actor_name"
        case isRead        = "is_read"
        case createdAt     = "created_at"
    }

    /// Convenience: Parsed notification type
    var notificationType: AppNotificationType? {
        AppNotificationType(rawValue: type)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id             = try container.decode(UUID.self, forKey: .id)
        userId         = try container.decode(UUID.self, forKey: .userId)
        kingdomId      = try container.decodeIfPresent(Int.self, forKey: .kingdomId)
        type           = try container.decode(String.self, forKey: .type)
        title          = try container.decode(String.self, forKey: .title)
        body           = try container.decode(String.self, forKey: .body)
        referenceId    = try container.decodeIfPresent(UUID.self, forKey: .referenceId)
        referenceType  = try container.decodeIfPresent(String.self, forKey: .referenceType)
        actorId        = try container.decodeIfPresent(UUID.self, forKey: .actorId)
        actorName      = try container.decodeIfPresent(String.self, forKey: .actorName)
        isRead         = (try? container.decode(Bool.self, forKey: .isRead)) ?? false
        createdAt      = (try? container.decode(Date.self, forKey: .createdAt)) ?? .now
    }
}
