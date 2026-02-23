import SwiftUI

// MARK: - Notification Bell Button (oben links in jedem Tab)

struct NotificationBellButton: View {

    @StateObject private var store = NotificationsStore.shared

    var body: some View {
        Button {
            store.showSheet = true
        } label: {
            Image(systemName: store.unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.unreadCount > 0 ? .orange : .primary)
        }
    }
}

// MARK: - Notifications Sheet (Modal)

struct NotificationsSheetView: View {

    @StateObject private var store = NotificationsStore.shared
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView("Lade Mitteilungen...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationList
                }
            }
            .navigationTitle("Mitteilungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                if !store.notifications.isEmpty && store.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Alle gelesen") {
                            Task { await store.markAllAsRead() }
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { callId in
                CallDeepLinkView(callId: callId)
            }
            .task {
                await store.loadNotifications()
            }
            .onAppear {
                // App-Badge zuruecksetzen
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Keine Mitteilungen")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Hier erscheinen Benachrichtigungen zu Calls und Truppen-Zusagen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Notification List

    private var notificationList: some View {
        List {
            let unread = store.notifications.filter { !$0.isRead }
            let read = store.notifications.filter { $0.isRead }

            if !unread.isEmpty {
                Section("Neu") {
                    ForEach(unread) { notification in
                        NotificationRow(notification: notification, isUnread: true)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(notification)
                            }
                    }
                }
            }

            if !read.isEmpty {
                Section("Frueher") {
                    ForEach(read) { notification in
                        NotificationRow(notification: notification, isUnread: false)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(notification)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Tap Handling

    private func handleTap(_ notification: NotificationItem) {
        // Als gelesen markieren
        Task { await store.markAsRead(notification) }

        // Navigation zum referenzierten Call
        if notification.referenceType == "call", let callId = notification.referenceId {
            path.append(callId)
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {

    let notification: NotificationItem
    let isUnread: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Unread-Indikator
            Circle()
                .fill(isUnread ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            // Typ-Icon
            let type = notification.notificationType
            Image(systemName: type?.icon ?? "bell.fill")
                .font(.title3)
                .foregroundStyle(type?.color ?? .secondary)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            // Inhalt
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(isUnread ? .semibold : .regular)

                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let actorName = notification.actorName {
                    Text("von \(actorName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            // Zeitstempel
            Text(relativeTime(notification.createdAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    /// Relative Zeitanzeige ("jetzt", "vor 5min", "vor 2h", "vor 3T")
    private func relativeTime(_ date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        let seconds = Int(diff)

        if seconds < 60 { return "jetzt" }
        if seconds < 3600 { return "vor \(seconds / 60)min" }
        if seconds < 86400 { return "vor \(seconds / 3600)h" }
        if seconds < 604800 { return "vor \(seconds / 86400)T" }

        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Call Deep Link View

/// Hilfview die einen Call per ID aus dem CallsStore laedt.
/// Falls der Call nicht im Store ist, wird ein Fallback angezeigt.
struct CallDeepLinkView: View {
    let callId: UUID
    @EnvironmentObject private var store: CallsStore

    var body: some View {
        if let call = store.calls.first(where: { $0.id == callId }) {
            CallDetailView(call: call, initialExpandedRowKey: nil)
                .environmentObject(store)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Call nicht gefunden")
                    .font(.headline)

                Text("Dieser Call wurde möglicherweise gelöscht oder ist nicht mehr verfügbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }
}
