import SwiftUI
import Supabase
// MARK: - Held Tool

struct HeroToolView: View {

    @Environment(AuthService.self) var authService
    @State private var favorites = FavoritesStore.shared

    var body: some View {
        List {
            Section("Konfigurator") {
                NavigationLink {
                    HeroConfiguratorView()
                        .environment(authService)
                } label: {
                    Label("Held konfigurieren", systemImage: "slider.horizontal.3")
                }
                .contextMenu {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.heroConfigurator.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.heroConfigurator.rawValue) ? "Aus Favoriten entfernen" : "An Tools anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.heroConfigurator.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.heroConfigurator.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.heroConfigurator.rawValue) ? "Lösen" : "Anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.heroConfigurator.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                    .tint(.orange)
                }
            }

            Section("Gegenstände") {
                ForEach(HeroItem.allCases) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                    .contextMenu {
                        Button {
                            withAnimation { favorites.toggle(item.favoriteId) }
                        } label: {
                            Label(
                                favorites.isFavorite(item.favoriteId) ? "Aus Favoriten entfernen" : "An Tools anheften",
                                systemImage: favorites.isFavorite(item.favoriteId) ? "pin.slash" : "pin.fill"
                            )
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            withAnimation { favorites.toggle(item.favoriteId) }
                        } label: {
                            Label(
                                favorites.isFavorite(item.favoriteId) ? "Lösen" : "Anheften",
                                systemImage: favorites.isFavorite(item.favoriteId) ? "pin.slash" : "pin.fill"
                            )
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Held")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HeroItem.self) { item in
            item.destination(tribe: currentTribe)
        }
    }

    private var currentTribe: Tribe {
        Tribe.from(profileTribe: authService.profile?.tribe)
    }
}

// MARK: - Voelker

enum Tribe: String, CaseIterable, Identifiable {
    case romans  = "Roemer"
    case gauls   = "Gallier"
    case teutons = "Germanen"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .romans:  return "Römer"
        case .gauls:   return "Gallier"
        case .teutons: return "Germanen"
        }
    }

    /// Erstellt Tribe aus dem DB-String (profiles.tribe).
    static func from(profileTribe: String?) -> Tribe {
        guard let raw = profileTribe else { return .gauls }
        return Tribe(rawValue: raw) ?? .gauls
    }
}

// MARK: - Held Gegenstände

enum HeroItem: String, CaseIterable, Identifiable, Hashable {
    case helmets
    case armor
    case boots
    case horses
    case leftHand
    case rightHand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .helmets:   return "Helme"
        case .armor:     return "Rüstungen"
        case .boots:     return "Schuhe"
        case .horses:    return "Pferde"
        case .leftHand:  return "Linke Hand"
        case .rightHand: return "Rechte Hand"
        }
    }

    var icon: String {
        switch self {
        case .helmets:   return "crown.fill"
        case .armor:     return "shield.checkerboard"
        case .boots:     return "shoeprints.fill"
        case .horses:    return "hare.fill"
        case .leftHand:  return "hand.raised.fill"
        case .rightHand: return "hand.raised.fingers.spread.fill"
        }
    }

    var favoriteId: String {
        switch self {
        case .helmets:   return FavoriteToolItem.heroHelmets.rawValue
        case .armor:     return FavoriteToolItem.heroArmor.rawValue
        case .boots:     return FavoriteToolItem.heroBoots.rawValue
        case .horses:    return FavoriteToolItem.heroHorses.rawValue
        case .leftHand:  return FavoriteToolItem.heroLeftHand.rawValue
        case .rightHand: return FavoriteToolItem.heroRightHand.rawValue
        }
    }

    @ViewBuilder
    func destination(tribe: Tribe) -> some View {
        switch self {
        case .helmets:
            HelmetsView()
        case .armor:
            ArmorView()
        case .boots:
            BootsView()
        case .horses:
            HorsesView()
        case .leftHand:
            LeftHandView()
        case .rightHand:
            RightHandView(tribe: tribe)
        default:
            HeroItemPlaceholderView(item: self)
        }
    }
}

// MARK: - Rechte Hand (volk-spezifisch)

struct RightHandView: View {
    let tribe: Tribe

    @State private var selectedTribe: Tribe?

    /// Angezeigtes Volk: User-Auswahl oder Account-Volk.
    private var activeTribe: Tribe {
        selectedTribe ?? tribe
    }

    var body: some View {
        Group {
            switch activeTribe {
            case .romans:
                RightHandRomansView()
            case .gauls:
                RightHandGaulsView()
            case .teutons:
                RightHandTeutonsView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            tribePicker
        }
        .navigationTitle("Rechte Hand – \(activeTribe.displayName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tribePicker: some View {
        VStack(spacing: 0) {
            Divider()
            Picker("Volk", selection: $selectedTribe) {
                Text(tribe.displayName)
                    .tag(nil as Tribe?)
                ForEach(Tribe.allCases.filter { $0 != tribe }) { t in
                    Text(t.displayName)
                        .tag(t as Tribe?)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}

// MARK: - Volk-spezifische Rechte-Hand-Views

// RightHandRomansView → eigene Datei: RightHandRomansView.swift

// RightHandGaulsView → eigene Datei: RightHandGaulsView.swift

// RightHandTeutonsView → eigene Datei: RightHandTeutonsView.swift

// MARK: - Platzhalter fuer andere Gegenstände

struct HeroItemPlaceholderView: View {
    let item: HeroItem

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(item.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Kommt bald...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
