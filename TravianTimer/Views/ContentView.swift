import SwiftUI

struct ContentView: View {

    enum AppTab: Hashable {
        case calls
        case parser
        case manuell
        case troops
        case settings
    }

    @EnvironmentObject private var callsStore: CallsStore
    @State private var selection: AppTab = .calls

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selection) {

            CallsTabView()
                .tabItem {
                    Label("Calls", systemImage: "list.bullet")
                }
                .tag(AppTab.calls)

            ParserTabView(selection: $selection)
                .tabItem {
                    Label("Parser", systemImage: "paperplane")
                }
                .tag(AppTab.parser)

            ManualTabView(selection: $selection)
                .tabItem {
                    Label("Manuell", systemImage: "square.and.pencil")
                }
                .tag(AppTab.manuell)

            TroopsOverviewView()
                .tabItem {
                    Label("Truppen", systemImage: "shield.fill")
                }
                .tag(AppTab.troops)

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCallNotificationName)) { _ in
            selection = .calls
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            VillageImportView(
                onImport: { imported in
                    for v in imported {
                        ProfileStore.shared.upsert(v)
                    }
                }
            )
        }
    }
}
