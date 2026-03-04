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
    @AppStorage("hasCompletedTroopImport") private var hasCompletedTroopImport = false
    @State private var showVerifySheet = false
    @State private var showPlayerNameSheet = false
    @State private var showTroopImport = false
    @State private var showProfileSetup = false

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
                    SearchResultsView(searchText: $searchText)
                        .navigationTitle("Suche")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .searchable(text: $searchText, prompt: "Gebäude, Truppen, Tools suchen…")
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
            hasCompletedTroopImport = true
            // Kleiner Delay, damit SwiftUI das Sheet komplett schliesst bevor das nächste kommt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                checkOnboardingState()
            }
        }) {
            TroopUpdateView(isOnboarding: true)
        }
        .sheet(isPresented: $showProfileSetup, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            ProfileSetupView()
                .environment(authService)
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
        } else if !hasCompletedTroopImport && !hasCompletedOnboarding {
            // Truppen-Import (kann übersprungen werden via "Abbrechen")
            showVerifySheet = false
            showPlayerNameSheet = false
            if !showTroopImport {
                showTroopImport = true
            }
        } else if !hasCompletedOnboarding {
            // Profil-Setup (Prestige, Lehnstreue, Plus)
            showVerifySheet = false
            showPlayerNameSheet = false
            showTroopImport = false
            if !showProfileSetup {
                showProfileSetup = true
            }
        }
    }
}

// MARK: - Search Results

private struct SearchResultsView: View {
    @Binding var searchText: String
    @AppStorage("recentSearches") private var recentSearchesJSON: String = "[]"

    private var query: String {
        searchText.lowercased().trimmingCharacters(in: .whitespaces)
    }

    private var hasResults: Bool {
        !matchingTools.isEmpty || !matchingBuildings.isEmpty || !matchingTroops.isEmpty
    }

    // MARK: Letzte Suchen

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentSearchesJSON.utf8))) ?? []
    }

    private func addRecentSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == trimmed.lowercased() }
        searches.insert(trimmed, at: 0)
        if searches.count > 8 { searches = Array(searches.prefix(8)) }
        if let data = try? JSONEncoder().encode(searches) {
            recentSearchesJSON = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    private func clearRecentSearches() {
        recentSearchesJSON = "[]"
    }

    private func removeRecentSearch(_ term: String) {
        var searches = recentSearches
        searches.removeAll { $0 == term }
        if let data = try? JSONEncoder().encode(searches) {
            recentSearchesJSON = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    // MARK: Tool-Treffer

    private var matchingTools: [FavoriteToolItem] {
        guard !query.isEmpty else { return [] }
        return FavoriteToolItem.allCases.filter { item in
            item.title.lowercased().contains(query) ||
            item.searchKeywords.contains { $0.contains(query) }
        }
    }

    // MARK: Gebäude-Treffer

    private var matchingBuildings: [Building] {
        guard !query.isEmpty else { return [] }
        return Building.allBuildings.filter { b in
            b.name.lowercased().contains(query) ||
            b.shortDescription.lowercased().contains(query) ||
            b.category.title.lowercased().contains(query) ||
            (b.tribe?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: Truppen-Treffer

    private struct TroopMatch: Identifiable {
        let id = UUID()
        let tribe: TroopsTribe
        let unit: TroopUnit
    }

    private var matchingTroops: [TroopMatch] {
        guard !query.isEmpty else { return [] }
        let allTroops: [(TroopsTribe, [TroopUnit])] = [
            (.romans, TroopsRomansView.units),
            (.teutons, TroopsTeutonsView.units),
            (.gauls, TroopsGaulsView.units),
        ]
        var results: [TroopMatch] = []
        for (tribe, units) in allTroops {
            for unit in units {
                if unit.name.lowercased().contains(query) ||
                   unit.type.rawValue.lowercased().contains(query) ||
                   tribe.title.lowercased().contains(query) {
                    results.append(TroopMatch(tribe: tribe, unit: unit))
                }
            }
        }
        return results
    }

    // MARK: Schnellzugriff

    private struct QuickCategory: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let itemCount: String
    }

    private let quickCategories: [QuickCategory] = [
        QuickCategory(icon: "building.2.fill", title: "Gebäude", subtitle: "Kosten & Bauzeiten", color: .blue, itemCount: "\(Building.allBuildings.count)"),
        QuickCategory(icon: "shield.lefthalf.filled", title: "Truppen", subtitle: "3 Völker", color: .red, itemCount: "30"),
        QuickCategory(icon: "crown.fill", title: "Held", subtitle: "Ausrüstung & Items", color: .orange, itemCount: "6"),
        QuickCategory(icon: "wrench.and.screwdriver.fill", title: "Rechner", subtitle: "Truppen & Ausbau", color: .teal, itemCount: "5"),
    ]

    // MARK: Beliebte Suchen

    private let suggestedSearches = [
        "Akademie", "Schmiede", "Imperianer", "Kaserne",
        "Getreidefeld", "Druidenreiter", "Brauerei", "Paladin",
    ]

    // MARK: Tipps

    private let tips = [
        "Suche nach Truppentypen wie \"Infanterie\" oder \"Kavallerie\" um alle Einheiten eines Typs zu finden.",
        "Tippe ein Volk wie \"Römer\" ein, um alle Truppen und Stammgebäude auf einmal zu sehen.",
        "Du kannst nach Gebäude-Kategorien suchen: \"Militär\", \"Ressourcen\" oder \"Infrastruktur\".",
        "Der Forschungsrechner zeigt dir, ab wann sich Schmiede-Stufen lohnen.",
        "Im Ausbau-Rechner findest du die optimale Reihenfolge für Rohstofffelder.",
        "Der Dorfplaner hilft dir beim Layout — Rohstofffelder inklusive Produktion.",
    ]

    private var tipOfTheDay: String {
        let dayIndex = Calendar.current.component(.day, from: Date()) % tips.count
        return tips[dayIndex]
    }

    // MARK: Body

    var body: some View {
        if query.isEmpty {
            discoveryHub
        } else if !hasResults {
            ContentUnavailableView(
                "Keine Ergebnisse",
                systemImage: "magnifyingglass",
                description: Text("Keine Treffer für \"\(searchText)\"")
            )
        } else {
            searchResults
        }
    }

    // MARK: - Discovery Hub (leerer Zustand)

    private var discoveryHub: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Letzte Suchen
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }

                // Schnellzugriff
                quickAccessGrid

                // Beliebte Suchen
                suggestedSearchesSection

                // Tipp
                tipCard

                Spacer(minLength: 40)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Letzte Suchen

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Letzte Suchen", systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    withAnimation { clearRecentSearches() }
                } label: {
                    Text("Löschen")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentSearches, id: \.self) { term in
                        Button {
                            searchText = term
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(term)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Button {
                                    withAnimation { removeRecentSearch(term) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Schnellzugriff Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Schnellzugriff", systemImage: "square.grid.2x2.fill")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                // Gebäude
                NavigationLink {
                    BuildingsView()
                } label: {
                    quickAccessCard(
                        icon: "building.2.fill",
                        title: "Gebäude",
                        subtitle: "\(Building.allBuildings.count) Gebäude",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                // Truppen
                NavigationLink {
                    TroopsToolView()
                } label: {
                    quickAccessCard(
                        icon: "shield.lefthalf.filled",
                        title: "Truppen",
                        subtitle: "3 Völker · 30 Einheiten",
                        color: .red
                    )
                }
                .buttonStyle(.plain)

                // Held & Ausrüstung
                NavigationLink {
                    HeroToolView()
                } label: {
                    quickAccessCard(
                        icon: "crown.fill",
                        title: "Held",
                        subtitle: "Ausrüstung & Items",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                // Rechner & Tools
                NavigationLink {
                    InfrastructureToolView()
                } label: {
                    quickAccessCard(
                        icon: "wrench.and.screwdriver.fill",
                        title: "Infrastruktur",
                        subtitle: "Planer & Rechner",
                        color: .teal
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    private func quickAccessCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Beliebte Suchen

    private var suggestedSearchesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Beliebte Suchen", systemImage: "sparkle.magnifyingglass")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(suggestedSearches.enumerated()), id: \.offset) { idx, term in
                    Button {
                        searchText = term
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(term)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)

                    if idx < suggestedSearches.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // MARK: Tipp des Tages

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tipp")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(tipOfTheDay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Such-Ergebnisse

    private var searchResults: some View {
        List {
            // Tools
            if !matchingTools.isEmpty {
                Section("Tools") {
                    ForEach(matchingTools) { item in
                        NavigationLink {
                            item.destination
                                .onAppear { addRecentSearch(searchText) }
                        } label: {
                            Label {
                                Text(item.title)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: item.icon)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(item.color.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }

            // Gebäude
            if !matchingBuildings.isEmpty {
                Section("Gebäude") {
                    ForEach(matchingBuildings) { building in
                        NavigationLink {
                            BuildingDetailView(building: building)
                                .onAppear { addRecentSearch(searchText) }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(building.name)
                                        .font(.subheadline)
                                    Text(building.shortDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: building.icon)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(building.category.color.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }

            // Truppen
            if !matchingTroops.isEmpty {
                Section("Truppen") {
                    ForEach(matchingTroops) { match in
                        NavigationLink {
                            TroopStatsView(
                                tribeName: match.tribe.title,
                                units: troopUnits(for: match.tribe)
                            )
                            .onAppear { addRecentSearch(searchText) }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.unit.name)
                                        .font(.subheadline)
                                    HStack(spacing: 4) {
                                        Text(match.tribe.title)
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                        Text(match.unit.type.rawValue)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: match.tribe.icon)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(match.unit.type.badgeColor.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func troopUnits(for tribe: TroopsTribe) -> [TroopUnit] {
        switch tribe {
        case .romans:  return TroopsRomansView.units
        case .teutons: return TroopsTeutonsView.units
        case .gauls:   return TroopsGaulsView.units
        }
    }
}

// MARK: - Such-Keywords für Tools

private extension FavoriteToolItem {
    var searchKeywords: [String] {
        switch self {
        case .heroConfigurator:   return ["held", "konfigurator", "skill", "ausrüstung", "level", "kampfkraft"]
        case .heroHelmets:        return ["held", "helm", "ausrüstung", "equipment"]
        case .heroArmor:          return ["held", "rüstung", "ausrüstung", "panzer"]
        case .heroBoots:          return ["held", "schuhe", "ausrüstung", "stiefel"]
        case .heroHorses:         return ["held", "pferd", "ausrüstung", "reittier"]
        case .heroLeftHand:       return ["held", "schild", "ausrüstung", "linke"]
        case .heroRightHand:      return ["held", "waffe", "ausrüstung", "rechte", "schwert"]
        case .troopsCalculator:   return ["truppen", "ausbildung", "training", "rechner", "kaserne", "stall"]
        case .troopsInterception: return ["abfang", "interception", "rechner", "rückkehr", "abfangen", "timing"]
        case .troopsResearchCalc: return ["forschung", "schmiede", "rechner", "verbesserung", "upgrade"]
        case .troopsRobberCalc:   return ["räuber", "robber", "lager", "bär", "schlange", "wolf", "clan"]
        case .troopsGauls:        return ["gallier", "truppen", "phalanx", "druidenreiter"]
        case .troopsRomans:       return ["römer", "truppen", "legionär", "prätorianer", "imperianer"]
        case .troopsTeutons:      return ["germanen", "truppen", "keulenschwinger", "paladin"]
        case .infraBuildingCosts: return ["gebäude", "kosten", "bauzeit", "infrastruktur"]
        case .infraResourceParser: return ["ressourcen", "import", "produktion", "parser"]
        case .infraVillagePlanner: return ["dorf", "planer", "layout", "gebäude"]
        case .infraUpgradeCalc:   return ["ausbau", "reihenfolge", "upgrade", "rohstoff", "felder", "optimierung"]
        case .guideQuests:         return ["quest", "aufgabe", "belohnung", "wren", "markus", "häuptling"]
        case .guideSchnellsiedeln: return ["guide", "siedeln", "schnell", "anleitung", "siedler"]
        }
    }
}
