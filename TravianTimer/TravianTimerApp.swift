import SwiftUI
import UserNotifications

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Remote Push registrieren
        UIApplication.shared.registerForRemoteNotifications()

        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(token)")

        PushService.shared.storeToken(token)

        Task {
            await PushService.shared.registerDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registrierung fehlgeschlagen: \(error.localizedDescription)")
    }

    // MARK: - Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Fall 1: Remote Push mit Call-Payload
        if let callData = userInfo["call"] as? [String: Any] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: callData) {
                UserDefaults.standard.set(jsonData, forKey: "tt_pending_remote_call")
            }
            NotificationCenter.default.post(name: NotificationManager.openCallNotificationName, object: nil)
        }
        // Fall 2: Lokale Notification (bestehende Logik)
        else if let callId = userInfo[NotificationManager.userInfoCallIdKey] as? String,
                let rowKey = userInfo[NotificationManager.userInfoRowKeyKey] as? String {
            UserDefaults.standard.set(callId, forKey: NotificationManager.userInfoCallIdKey)
            UserDefaults.standard.set(rowKey, forKey: NotificationManager.userInfoRowKeyKey)
            NotificationCenter.default.post(name: NotificationManager.openCallNotificationName, object: nil)
        }

        completionHandler()
    }

    // Notification anzeigen auch wenn App im Vordergrund ist
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Background Remote Notification

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Call-Payload im Hintergrund speichern
        if let callData = userInfo["call"] as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: callData) {
            UserDefaults.standard.set(jsonData, forKey: "tt_pending_remote_call")
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}

// MARK: - App Entry Point

@main
struct TravianTimerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var callsStore = CallsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(callsStore)
        }
    }
}
