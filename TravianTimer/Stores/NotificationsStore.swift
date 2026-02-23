import Foundation
import Combine
import Observation
import Supabase
import Realtime

// MARK: - Notifications Store (Supabase CRUD + Realtime)

@MainActor
@Observable
final class NotificationsStore {

    static let shared = NotificationsStore()

    // MARK: Published State

    var notifications: [NotificationItem] = []
    var preferences: NotificationPreferences?
    var isLoading: Bool = false
    var unreadCount: Int = 0
    var showSheet: Bool = false

    // MARK: Private

    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }
    @ObservationIgnored private var notificationsChannel: RealtimeChannelV2?
    @ObservationIgnored private var realtimeTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    private init() {
        // Bei Logout alles aufraeumen
        NotificationCenter.default.publisher(for: AuthService.didSignOutNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleLogout() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Notifications

    /// Laedt die letzten 100 Benachrichtigungen des aktuellen Users.
    func loadNotifications() async {
        guard AuthService.shared.currentUserId != nil else {
            notifications = []
            unreadCount = 0
            return
        }

        isLoading = true

        do {
            let result: [NotificationItem] = try await client
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value

            notifications = result
            updateUnreadCount()
        } catch {
            print("[NotificationsStore] loadNotifications Fehler: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Load Preferences

    /// Laedt die Benachrichtigungs-Einstellungen. Erstellt Default-Zeile falls nicht vorhanden.
    func loadPreferences() async {
        guard let userId = AuthService.shared.currentUserId else { return }

        do {
            let result: [NotificationPreferences] = try await client
                .from("notification_preferences")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let prefs = result.first {
                preferences = prefs
            } else {
                // Noch keine Preferences — Default-Zeile erstellen
                try await client
                    .from("notification_preferences")
                    .insert(["user_id": userId.uuidString])
                    .execute()

                // Nochmal laden
                let retry: [NotificationPreferences] = try await client
                    .from("notification_preferences")
                    .select()
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value

                preferences = retry.first
            }
        } catch {
            print("[NotificationsStore] loadPreferences Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Preference

    /// Aktualisiert eine einzelne Benachrichtigungs-Einstellung.
    func updatePreference(type: AppNotificationType, enabled: Bool) async {
        guard let userId = AuthService.shared.currentUserId else { return }

        let column: String
        switch type {
        case .newCall:        column = "new_call"
        case .pledgeReceived: column = "pledge_received"
        case .guideProgress:  column = "guide_progress"
        }

        // Optimistisches lokales Update
        switch type {
        case .newCall:        preferences?.newCall = enabled
        case .pledgeReceived: preferences?.pledgeReceived = enabled
        case .guideProgress:  preferences?.guideProgress = enabled
        }

        do {
            try await client
                .from("notification_preferences")
                .update([column: enabled])
                .eq("user_id", value: userId.uuidString)
                .execute()
        } catch {
            print("[NotificationsStore] updatePreference Fehler: \(error.localizedDescription)")
            // Rollback
            switch type {
            case .newCall:        preferences?.newCall = !enabled
            case .pledgeReceived: preferences?.pledgeReceived = !enabled
            case .guideProgress:  preferences?.guideProgress = !enabled
            }
        }
    }

    // MARK: - Mark as Read

    /// Markiert eine einzelne Benachrichtigung als gelesen.
    func markAsRead(_ notification: NotificationItem) async {
        guard !notification.isRead else { return }

        // Optimistisch lokal updaten
        if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[idx].isRead = true
            updateUnreadCount()
        }

        do {
            try await client
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id.uuidString)
                .execute()
        } catch {
            print("[NotificationsStore] markAsRead Fehler: \(error.localizedDescription)")
        }
    }

    /// Markiert alle ungelesenen Benachrichtigungen als gelesen.
    func markAllAsRead() async {
        guard let userId = AuthService.shared.currentUserId else { return }

        // Optimistisch lokal updaten
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        updateUnreadCount()

        do {
            try await client
                .from("notifications")
                .update(["is_read": true])
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
        } catch {
            print("[NotificationsStore] markAllAsRead Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Unread Count

    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    // MARK: - Realtime

    /// Abonniert Realtime-Changes fuer neue Benachrichtigungen.
    func subscribeToRealtime() async {
        guard let userId = AuthService.shared.currentUserId else { return }

        // Erst alte Subscriptions aufraeumen
        await unsubscribeFromRealtime()

        let channel = client.realtimeV2.channel("notifications-\(userId.uuidString.prefix(8))")
        self.notificationsChannel = channel

        // INSERT Listener registrieren VOR subscribe
        let insertTask = Task { [weak self] in
            for await insertion in channel.postgresChange(InsertAction.self, schema: "public", table: "notifications") {
                guard let self else { return }
                if let newNotification = try? insertion.decodeRecord(as: NotificationItem.self, decoder: JSONDecoder.notificationsDecoder) {
                    // Nur eigene Notifications (RLS sollte das bereits filtern)
                    guard newNotification.userId == userId else { continue }

                    // Duplikat-Check
                    if !self.notifications.contains(where: { $0.id == newNotification.id }) {
                        self.notifications.insert(newNotification, at: 0)
                        self.updateUnreadCount()
                        print("[Realtime] Notification INSERT: \(newNotification.title)")
                    }
                }
            }
        }

        realtimeTasks = [insertTask]

        // Subscriben
        do {
            try await channel.subscribeWithError()
            print("[Realtime] Notifications Channel subscribed")
        } catch {
            print("[NotificationsStore] Realtime subscribe Fehler: \(error.localizedDescription)")
        }
    }

    /// Beendet Realtime-Subscriptions.
    func unsubscribeFromRealtime() async {
        for task in realtimeTasks {
            task.cancel()
        }
        realtimeTasks = []

        await notificationsChannel?.unsubscribe()
        notificationsChannel = nil
    }

    // MARK: - Logout

    func handleLogout() async {
        await unsubscribeFromRealtime()
        notifications = []
        preferences = nil
        unreadCount = 0
    }
}

// MARK: - JSONDecoder fuer Notifications

private extension JSONDecoder {
    /// Supabase-kompatibler Decoder mit ISO8601 Datum-Strategie.
    static var notificationsDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // ISO8601 mit Fractional Seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }

            // Fallback ohne Fractional Seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ungueltiges Datum: \(string)")
        }
        return decoder
    }
}
