import Foundation
import UserNotifications

enum NotificationManager {

    static func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func scheduleSendReminder(row: OptionRow, targetLink: URL?, leadMinutes: Int) async {

        await requestPermissionIfNeeded()

        let fireDate = row.sendTime.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        if fireDate <= .now { return }

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Travian absenden"
        content.sound = .default

        let linkText = targetLink?.absoluteString ?? ""
        let sendText = row.sendTime.formatted(date: .omitted, time: .standard)
        content.body = "\(row.start.name) \(row.troop.rawValue). Senden um \(sendText). \(linkText)"

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let id = "send.\(row.id.uuidString)"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(req)
    }
}
