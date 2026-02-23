import SwiftUI

// MARK: - Benachrichtigungen Detail View

struct NotificationsDetailView: View {

    var body: some View {
        Form {
            Section {
                ForEach(AppNotificationType.allCases) { type in
                    Toggle(isOn: notificationBinding(for: type)) {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } footer: {
                Text("Lege fest, für welche Ereignisse du Push-Benachrichtigungen erhalten möchtest.")
            }
        }
        .navigationTitle("Benachrichtigungen")
    }

    // MARK: - Binding

    private func notificationBinding(for type: AppNotificationType) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                let prefs = NotificationsStore.shared.preferences
                switch type {
                case .newCall:        return prefs?.newCall ?? true
                case .pledgeReceived: return prefs?.pledgeReceived ?? true
                case .guideProgress:  return prefs?.guideProgress ?? true
                }
            },
            set: { newValue in
                Task {
                    await NotificationsStore.shared.updatePreference(type: type, enabled: newValue)
                }
            }
        )
    }
}
