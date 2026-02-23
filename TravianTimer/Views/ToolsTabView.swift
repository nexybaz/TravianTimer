import SwiftUI

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
                .sharedBackgroundVisibility(.hidden)
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
    case heroHelmets
    case heroArmor
    case heroBoots
    case heroHorses
    case heroLeftHand
    case heroRightHand
    // Troops
    case troopsGauls
    case troopsRomans
    case troopsTeutons
    // Infrastructure
    case infraBuildingCosts
    // Guides
    case guideSchnellsiedeln

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroHelmets:      return "Helme"
        case .heroArmor:        return "Rüstungen"
        case .heroBoots:        return "Schuhe"
        case .heroHorses:       return "Pferde"
        case .heroLeftHand:     return "Linke Hand"
        case .heroRightHand:    return "Rechte Hand"
        case .troopsGauls:      return "Gallier"
        case .troopsRomans:     return "Römer"
        case .troopsTeutons:    return "Germanen"
        case .infraBuildingCosts: return "Baukosten"
        case .guideSchnellsiedeln: return "Schnellsiedeln"
        }
    }

    var icon: String {
        switch self {
        case .heroHelmets:      return "crown.fill"
        case .heroArmor:        return "shield.checkerboard"
        case .heroBoots:        return "shoeprints.fill"
        case .heroHorses:       return "hare.fill"
        case .heroLeftHand:     return "hand.raised.fill"
        case .heroRightHand:    return "hand.raised.fingers.spread.fill"
        case .troopsGauls:      return "leaf.fill"
        case .troopsRomans:     return "laurel.leading"
        case .troopsTeutons:    return "hammer.fill"
        case .infraBuildingCosts: return "hammer.fill"
        case .guideSchnellsiedeln: return "hare.fill"
        }
    }

    var color: Color {
        switch self {
        case .heroHelmets, .heroArmor, .heroBoots,
             .heroHorses, .heroLeftHand, .heroRightHand:
            return .orange
        case .troopsGauls, .troopsRomans, .troopsTeutons:
            return .red
        case .infraBuildingCosts:
            return .blue
        case .guideSchnellsiedeln:
            return .green
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .heroHelmets:      HelmetsView()
        case .heroArmor:        ArmorView()
        case .heroBoots:        BootsView()
        case .heroHorses:       HorsesView()
        case .heroLeftHand:     LeftHandView()
        case .heroRightHand:    RightHandFavoriteWrapper()
        case .troopsGauls:      TroopsGaulsView()
        case .troopsRomans:     TroopsRomansView()
        case .troopsTeutons:    TroopsTeutonsView()
        case .infraBuildingCosts: BuildingCostsView()
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
