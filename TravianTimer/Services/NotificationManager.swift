import Foundation
import UserNotifications

enum NotificationManager {

    static let openCallNotificationName = Notification.Name("TT_OpenCallFromNotification")
    static let userInfoCallIdKey = "tt_call_id"
    static let userInfoRowKeyKey = "tt_row_key"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func scheduleSendReminder(
        callId: UUID,
        rowKey: String,
        row: OptionRow,
        targetLink: URL?,
        leadMinutes: Int
    ) async -> Bool {
        let allowed = await ensureAuthorization()
        guard allowed else { return false }

        let fireDate = row.sendTime.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard fireDate > .now else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Travian absenden"
        content.sound = .default

        let sendText = row.sendTime.formatted(date: .omitted, time: .standard)
        content.body = "Absenden von \(row.start.name) \(row.troop.uiName). Senden um \(sendText)."

        // Deep link payload
        content.userInfo = [
            userInfoCallIdKey: callId.uuidString,
            userInfoRowKeyKey: rowKey
        ]

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let safeVillage = row.start.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "|", with: "_")

        let id = "send.\(callId.uuidString).\(safeVillage).\(row.troop.rawValue)"

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(req)
            return true
        } catch {
            return false
        }
    }

    static func notificationId(callId: UUID, row: OptionRow) -> String {
        let safeVillage = row.start.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "|", with: "_")
        return "send.\(callId.uuidString).\(safeVillage).\(row.troop.rawValue)"
    }

    static func cancelReminder(callId: UUID, row: OptionRow) {
        let id = notificationId(callId: callId, row: row)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Interception Reminders

    static func scheduleInterceptionReminder(
        villageName: String,
        troop: TroopKind,
        sendTime: Date,
        leadMinutes: Int
    ) async -> Bool {
        let allowed = await ensureAuthorization()
        guard allowed else { return false }

        let fireDate = sendTime.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard fireDate > .now else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Abfang senden"
        content.sound = .default

        let sendText = sendTime.formatted(date: .omitted, time: .standard)
        content.body = "\(villageName) → \(troop.uiName) absenden um \(sendText)"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let id = interceptionNotificationId(villageName: villageName, troop: troop)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(req)
            return true
        } catch {
            return false
        }
    }

    static func cancelInterceptionReminder(villageName: String, troop: TroopKind) {
        let id = interceptionNotificationId(villageName: villageName, troop: troop)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func interceptionNotificationId(villageName: String, troop: TroopKind) -> String {
        let safe = villageName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "|", with: "_")
        return "intercept.\(safe).\(troop.rawValue)"
    }
}
