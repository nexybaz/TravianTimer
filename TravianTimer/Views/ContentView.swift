import SwiftUI

struct ContentView: View {

    enum AppTab: Hashable {
        case calls
        case troops
        case tools
        case settings
        case search
    }

    @Environment(CallsStore.self) var callsStore
    @Environment(AuthService.self) var authService
    @State private var notificationsStore = NotificationsStore.shared
    @State private var lockService = BiometricLockService.shared
    @State private var selection: AppTab = .calls

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSkippedVerification") private var hasSkippedVerification = false
    @State private var showVerifySheet = false
    @State private var showPlayerNameSheet = false
    @State private var showTroopImport = false

    // Search
    @State private var searchText = ""

    var body: some View {
        Group {
            if !authService.hasCheckedSession {
                // Splash — Session wird geprüft
                splashView
            } else if authService.isAuthenticated {
                if lockService.isLocked && lockService.isEnabled {
                    BiometricLockView()
                } else {
                    mainTabView
                }
            } else {
                AuthView()
                    .environment(authService)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.hasCheckedSession)
        .animation(.easeInOut(duration: 0.2), value: lockService.isLocked)
    }

    // MARK: - Splash View

    private var splashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("TravianTimer")
                .font(.title.bold())

            ProgressView()
                .controlSize(.regular)
                .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView(selection: $selection) {

            Tab("Calls", systemImage: "list.bullet", value: AppTab.calls) {
                CallsTabView()
            }

            Tab("Truppen", systemImage: "shield.fill", value: AppTab.troops) {
                TroopsOverviewView()
            }

            Tab("Tools", systemImage: "wrench.and.screwdriver", value: AppTab.tools) {
                ToolsTabView()
            }

            Tab("Einstellungen", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }

            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchResultsView(searchText: searchText)
                        .navigationTitle("Suche")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .searchable(text: $searchText, prompt: "Suchen")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCallNotificationName)) { _ in
            selection = .calls
        }
        .onAppear {
            checkOnboardingState()
        }
        .onChange(of: authService.profile) { _, _ in
            checkOnboardingState()
        }
        .sheet(isPresented: $showVerifySheet, onDismiss: {
            // Wenn nach Dismiss immer noch nicht verifiziert → User hat übersprungen
            if authService.profile?.isVerified != true {
                hasSkippedVerification = true
            }
            checkOnboardingState()
        }) {
            TravianVerifyView()
                .environment(authService)
        }
        .sheet(isPresented: $showPlayerNameSheet, onDismiss: {
            checkOnboardingState()
        }) {
            PlayerNameView()
                .environment(authService)
        }
        .sheet(isPresented: $showTroopImport, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            TroopUpdateView()
        }
        .sheet(isPresented: $notificationsStore.showSheet) {
            NotificationsSheetView()
                .environment(callsStore)
                .environment(authService)
        }
    }

    // MARK: - Onboarding State Machine

    private func checkOnboardingState() {
        guard authService.isAuthenticated else { return }
        guard let profile = authService.profile else { return }

        if !profile.isVerified && !hasSkippedVerification {
            // Verifizierung nur anzeigen wenn noch nicht übersprungen
            if !showVerifySheet {
                showVerifySheet = true
            }
        } else if profile.playerName == "Spieler" {
            // Apple Sign-In User ohne Spielername → Name abfragen
            showVerifySheet = false
            if !showPlayerNameSheet {
                showPlayerNameSheet = true
            }
        } else if !hasCompletedOnboarding {
            showVerifySheet = false
            showPlayerNameSheet = false
            if !showTroopImport {
                showTroopImport = true
            }
        }
    }
}

// MARK: - Search Results (Platzhalter)

private struct SearchResultsView: View {
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "Suchen",
                systemImage: "magnifyingglass",
                description: Text("Gib einen Suchbegriff ein")
            )
        } else {
            ContentUnavailableView(
                "Keine Ergebnisse",
                systemImage: "magnifyingglass",
                description: Text("Keine Treffer für \"\(searchText)\"")
            )
        }
    }
}
