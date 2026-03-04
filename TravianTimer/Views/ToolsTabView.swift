import SwiftUI
import Supabase
// MARK: - Tools Tab

struct ToolsTabView: View {

    @State private var favorites = FavoritesStore.shared
    @State private var selectedFavorite: FavoriteToolItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Angeheftet

                    if !sortedFavorites.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Angeheftet", systemImage: "pin.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(sortedFavorites) { item in
                                    FavoriteCard(item: item)
                                        .contentShape(.contextMenuPreview,
                                                       RoundedRectangle(cornerRadius: 14))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    favorites.toggle(item.rawValue)
                                                }
                                            } label: {
                                                Label("Lösen", systemImage: "pin.slash")
                                            }
                                        }
                                        .onTapGesture {
                                            selectedFavorite = item
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    } else {
                        // MARK: Empty-State Tipp
                        HStack(spacing: 12) {
                            Image(systemName: "pin.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 36, height: 36)
                                .background(.orange.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tipp")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Wische in einer Kategorie nach links, um Tools hier anzuheften.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }

                    // MARK: Alle Tools

                    List {
                        Section {
                            ForEach(Tool.allCases) { tool in
                                NavigationLink(value: tool) {
                                    Label(tool.title, systemImage: tool.icon)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDisabled(true)
                    .frame(minHeight: CGFloat(Tool.allCases.count) * 52 + 80)
                }
            }
            .navigationTitle("Tools")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton()
                }
            }
            .navigationDestination(for: Tool.self) { tool in
                tool.destination
            }
            .sheet(item: $selectedFavorite) { item in
                NavigationStack {
                    item.destination
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Fertig") {
                                    selectedFavorite = nil
                                }
                            }
                        }
                }
            }
        }
    }

    /// Favoriten in stabiler Reihenfolge (nach Enum-Index)
    private var sortedFavorites: [FavoriteToolItem] {
        FavoriteToolItem.allCases
            .filter { favorites.favoriteIds.contains($0.rawValue) }
    }
}

// MARK: - Favorite Card

private struct FavoriteCard: View {
    let item: FavoriteToolItem

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(item.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Favorite Tool Item

enum FavoriteToolItem: String, CaseIterable, Identifiable, Hashable {
    // Hero
    case heroConfigurator
    case heroHelmets
    case heroArmor
    case heroBoots
    case heroHorses
    case heroLeftHand
    case heroRightHand
    // Troops
    case troopsCalculator
    case troopsInterception
    case troopsResearchCalc
    case troopsRobberCalc
    case troopsGauls
    case troopsRomans
    case troopsTeutons
    // Infrastructure
    case infraBuildingCosts
    case infraResourceParser
    case infraVillagePlanner
    case infraUpgradeCalc
    // Guides
    case guideQuests
    case guideSchnellsiedeln

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroConfigurator: return "Konfigurator"
        case .heroHelmets:      return "Helme"
        case .heroArmor:        return "Rüstungen"
        case .heroBoots:        return "Schuhe"
        case .heroHorses:       return "Pferde"
        case .heroLeftHand:     return "Linke Hand"
        case .heroRightHand:    return "Rechte Hand"
        case .troopsCalculator: return "Truppenrechner"
        case .troopsInterception: return "Abfang-Rechner"
        case .troopsResearchCalc: return "Forschungsrechner"
        case .troopsRobberCalc: return "Räuberlager"
        case .troopsGauls:      return "Gallier"
        case .troopsRomans:     return "Römer"
        case .troopsTeutons:    return "Germanen"
        case .infraBuildingCosts: return "Gebäude"
        case .infraResourceParser: return "Ressourcen-Parser"
        case .infraVillagePlanner: return "Dorfplaner"
        case .infraUpgradeCalc: return "Ausbau-Rechner"
        case .guideQuests:         return "Quests"
        case .guideSchnellsiedeln: return "Schnellsiedeln"
        }
    }

    var icon: String {
        switch self {
        case .heroConfigurator: return "slider.horizontal.3"
        case .heroHelmets:      return "crown.fill"
        case .heroArmor:        return "shield.checkerboard"
        case .heroBoots:        return "shoeprints.fill"
        case .heroHorses:       return "hare.fill"
        case .heroLeftHand:     return "hand.raised.fill"
        case .heroRightHand:    return "hand.raised.fingers.spread.fill"
        case .troopsCalculator: return "function"
        case .troopsInterception: return "scope"
        case .troopsResearchCalc: return "flask.fill"
        case .troopsRobberCalc: return "pawprint.fill"
        case .troopsGauls:      return "leaf.fill"
        case .troopsRomans:     return "laurel.leading"
        case .troopsTeutons:    return "hammer.fill"
        case .infraBuildingCosts: return "building.2.fill"
        case .infraResourceParser: return "leaf.fill"
        case .infraVillagePlanner: return "square.grid.3x3.topleft.filled"
        case .infraUpgradeCalc: return "chart.line.uptrend.xyaxis"
        case .guideQuests:         return "text.book.closed.fill"
        case .guideSchnellsiedeln: return "hare.fill"
        }
    }

    var color: Color {
        switch self {
        case .heroConfigurator, .heroHelmets, .heroArmor, .heroBoots,
             .heroHorses, .heroLeftHand, .heroRightHand:
            return .orange
        case .troopsCalculator, .troopsInterception, .troopsRobberCalc, .troopsGauls, .troopsRomans, .troopsTeutons:
            return .red
        case .troopsResearchCalc:
            return .indigo
        case .infraBuildingCosts, .infraResourceParser:
            return .blue
        case .infraVillagePlanner:
            return .purple
        case .infraUpgradeCalc:
            return .teal
        case .guideQuests:
            return .indigo
        case .guideSchnellsiedeln:
            return .green
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .heroConfigurator: HeroConfiguratorView()
        case .heroHelmets:      HelmetsView()
        case .heroArmor:        ArmorView()
        case .heroBoots:        BootsView()
        case .heroHorses:       HorsesView()
        case .heroLeftHand:     LeftHandView()
        case .heroRightHand:    RightHandFavoriteWrapper()
        case .troopsCalculator: TroopCalculatorView()
        case .troopsInterception: InterceptionCalculatorView()
        case .troopsResearchCalc: ResearchCalculatorView()
        case .troopsRobberCalc: RobberCampCalculatorView()
        case .troopsGauls:      TroopsGaulsView()
        case .troopsRomans:     TroopsRomansView()
        case .troopsTeutons:    TroopsTeutonsView()
        case .infraBuildingCosts: BuildingsView()
        case .infraResourceParser: ResourceParserView()
        case .infraVillagePlanner: VillagePlannerListView()
        case .infraUpgradeCalc: UpgradeCalculatorView()
        case .guideQuests:         QuestsGuideView()
        case .guideSchnellsiedeln: SchnellsiedelGuideView()
        }
    }
}

// MARK: - Tool Definition

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case hero
    case troops
    case infrastructure
    case guides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero:           return "Held"
        case .troops:         return "Truppen"
        case .infrastructure: return "Infrastruktur"
        case .guides:         return "Guides"
        }
    }

    var icon: String {
        switch self {
        case .hero:           return "person.fill"
        case .troops:         return "shield.lefthalf.filled"
        case .infrastructure: return "building.2.fill"
        case .guides:         return "book.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .hero:           HeroToolView()
        case .troops:         TroopsToolView()
        case .infrastructure: InfrastructureToolView()
        case .guides:         GuidesToolView()
        }
    }
}

// MARK: - Platzhalter View

struct ToolPlaceholderView: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: tool.icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(tool.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Kommt bald...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Rechte Hand Favorit Wrapper

/// Liest den Tribe auf dem MainActor und leitet an RightHandView weiter.
private struct RightHandFavoriteWrapper: View {
    @Environment(AuthService.self) var authService

    var body: some View {
        RightHandView(tribe: Tribe.from(profileTribe: authService.profile?.tribe))
    }
}
