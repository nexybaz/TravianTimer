import SwiftUI
import UIKit
import UserNotifications
import Supabase

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Notification-Berechtigung anfragen (lokal + remote)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[Notifications] Berechtigung Fehler: \(error.localizedDescription)")
            }
            if granted {
                // APNs Device Token anfordern
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("[Notifications] Berechtigung abgelehnt")
            }
        }

        return true
    }

    // MARK: - APNs Device Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[APNs] Device Token erhalten: \(tokenString.prefix(16))...")

        // Token an Supabase device_tokens senden
        Task {
            await DeviceTokenService.shared.registerToken(tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration fehlgeschlagen: \(error.localizedDescription)")
    }

    // MARK: - Notification Tap (lokal + remote)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Deep Link: Call-ID aus Notification
        if let callId = userInfo[NotificationManager.userInfoCallIdKey] as? String {
            let rowKey = userInfo[NotificationManager.userInfoRowKeyKey] as? String ?? ""
            UserDefaults.standard.set(callId, forKey: NotificationManager.userInfoCallIdKey)
            UserDefaults.standard.set(rowKey, forKey: NotificationManager.userInfoRowKeyKey)
            NotificationCenter.default.post(name: NotificationManager.openCallNotificationName, object: nil)
        }

        // Deep Link: Remote Push mit call_id
        if let callIdString = userInfo["call_id"] as? String {
            UserDefaults.standard.set(callIdString, forKey: NotificationManager.userInfoCallIdKey)
            UserDefaults.standard.set("", forKey: NotificationManager.userInfoRowKeyKey)
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
}

// MARK: - App Entry Point

@main
struct TravianTimerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var callsStore = CallsStore()
    @State private var operationStore = OperationPlanStore()
    @State private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(callsStore)
                .environment(operationStore)
                .environment(authService)
                .onOpenURL { url in
                    // Handle Supabase Auth Callback (E-Mail Bestaetigung, Magic Link, OAuth)
                    Task {
                        do {
                            let session = try await SupabaseManager.client.auth.session(from: url)
                            print("[Auth] Session aus URL erhalten: \(session.user.email ?? "?")")
                        } catch {
                            print("[Auth] onOpenURL Fehler: \(error)")
                        }
                    }
                }
        }
    }
}
