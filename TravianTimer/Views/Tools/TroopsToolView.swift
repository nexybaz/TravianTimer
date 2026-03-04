import SwiftUI

// MARK: - Truppen Tool

struct TroopsToolView: View {

    @Environment(AuthService.self) var authService
    @State private var favorites = FavoritesStore.shared

    var body: some View {
        List {
            Section("Rechner") {
                NavigationLink {
                    TroopCalculatorView()
                        .environment(authService)
                } label: {
                    Label("Truppenrechner", systemImage: "function")
                }
                .contextMenu {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsCalculator.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsCalculator.rawValue) ? "Aus Favoriten entfernen" : "An Tools anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsCalculator.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsCalculator.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsCalculator.rawValue) ? "Lösen" : "Anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsCalculator.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                    .tint(.orange)
                }

                NavigationLink {
                    ResearchCalculatorView()
                } label: {
                    Label("Forschungsrechner", systemImage: "flask.fill")
                }
                .contextMenu {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsResearchCalc.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsResearchCalc.rawValue) ? "Aus Favoriten entfernen" : "An Tools anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsResearchCalc.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsResearchCalc.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsResearchCalc.rawValue) ? "Lösen" : "Anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsResearchCalc.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                    .tint(.orange)
                }

                NavigationLink {
                    InterceptionCalculatorView()
                } label: {
                    Label("Abfang-Rechner", systemImage: "scope")
                }
                .contextMenu {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsInterception.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsInterception.rawValue) ? "Aus Favoriten entfernen" : "An Tools anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsInterception.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsInterception.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsInterception.rawValue) ? "Lösen" : "Anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsInterception.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                    .tint(.orange)
                }

                NavigationLink {
                    RobberCampCalculatorView()
                } label: {
                    Label("Räuberlager-Rechner", systemImage: "pawprint.fill")
                }
                .contextMenu {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsRobberCalc.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsRobberCalc.rawValue) ? "Aus Favoriten entfernen" : "An Tools anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsRobberCalc.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        withAnimation { favorites.toggle(FavoriteToolItem.troopsRobberCalc.rawValue) }
                    } label: {
                        Label(
                            favorites.isFavorite(FavoriteToolItem.troopsRobberCalc.rawValue) ? "Lösen" : "Anheften",
                            systemImage: favorites.isFavorite(FavoriteToolItem.troopsRobberCalc.rawValue) ? "pin.slash" : "pin.fill"
                        )
                    }
                    .tint(.orange)
                }
            }

            Section("Planung") {
                NavigationLink {
                    OperationsTabView()
                } label: {
                    Label("Einsatzplaner", systemImage: "scope")
                }
            }

            Section("Truppenübersicht") {
                ForEach(TroopsTribe.allCases) { tribe in
                    NavigationLink(value: tribe) {
                        Label(tribe.title, systemImage: tribe.icon)
                    }
                    .contextMenu {
                        Button {
                            withAnimation { favorites.toggle(tribe.favoriteId) }
                        } label: {
                            Label(
                                favorites.isFavorite(tribe.favoriteId) ? "Aus Favoriten entfernen" : "An Tools anheften",
                                systemImage: favorites.isFavorite(tribe.favoriteId) ? "pin.slash" : "pin.fill"
                            )
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            withAnimation { favorites.toggle(tribe.favoriteId) }
                        } label: {
                            Label(
                                favorites.isFavorite(tribe.favoriteId) ? "Lösen" : "Anheften",
                                systemImage: favorites.isFavorite(tribe.favoriteId) ? "pin.slash" : "pin.fill"
                            )
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Truppen")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TroopsTribe.self) { tribe in
            tribe.destination
        }
    }
}

// MARK: - Voelker fuer Truppenuebersicht

enum TroopsTribe: String, CaseIterable, Identifiable, Hashable {
    case gauls
    case romans
    case teutons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gauls:   return "Gallier"
        case .romans:  return "Römer"
        case .teutons: return "Germanen"
        }
    }

    var icon: String {
        switch self {
        case .gauls:   return "leaf.fill"
        case .romans:  return "laurel.leading"
        case .teutons: return "hammer.fill"
        }
    }

    var favoriteId: String {
        switch self {
        case .gauls:   return FavoriteToolItem.troopsGauls.rawValue
        case .romans:  return FavoriteToolItem.troopsRomans.rawValue
        case .teutons: return FavoriteToolItem.troopsTeutons.rawValue
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .gauls:   TroopsGaulsView()
        case .romans:  TroopsRomansView()
        case .teutons: TroopsTeutonsView()
        }
    }
}

// MARK: - Truppen Daten-Modell

struct TroopUnit: Identifiable {
    let id = UUID()
    let name: String
    let attack: Int
    let defInfantry: Int
    let defCavalry: Int
    let speed: Int
    let carry: Int
    let upkeep: Int
    let type: TroopType
    // Ausbildungskosten (Quelle: support.kingdoms.com)
    let costWood: Int
    let costClay: Int
    let costIron: Int
    let baseTrainingTimeSec: Int    // Basis-Ausbildungszeit in Sekunden (Kaserne/Stall/Werkstatt Stufe 1)
}

enum TroopType: String {
    case infantry = "Infanterie"
    case cavalry  = "Kavallerie"
    case siege    = "Belagerung"

    /// Farbe fuer Typ-Badge
    var badgeColor: Color {
        switch self {
        case .infantry: return .orange
        case .cavalry:  return .blue
        case .siege:    return .purple
        }
    }

    /// Treue-Kostenreduktion fuer Ausbildung (0.5% pro Level, linear)
    /// Werkstatt ab Fealty 8, Stall ab 9, Kaserne ab 10 — jeweils bis max 9%
    func trainingCostReduction(fealty: Int, prestige: Int) -> Double {
        let minLevel: Int
        let basePercent: Double
        let prestigeMinLevel: Int

        switch self {
        case .siege:
            minLevel = 8
            basePercent = 3.0
            prestigeMinLevel = 4
        case .cavalry:
            minLevel = 9
            basePercent = 3.5
            prestigeMinLevel = 9
        case .infantry:
            minLevel = 10
            basePercent = 4.0
            prestigeMinLevel = 5
        }

        guard fealty >= minLevel else { return 0.0 }

        let fealtyBonus = min(basePercent + 0.5 * Double(fealty - minLevel), 9.0)
        let prestigeBonus: Double = prestige >= prestigeMinLevel ? 1.0 : 0.0

        return min(fealtyBonus + prestigeBonus, 10.0) / 100.0
    }
}

// MARK: - Truppen-Tabelle (wiederverwendbar)

struct TroopStatsView: View {
    let tribeName: String
    let units: [TroopUnit]

    @Environment(AuthService.self) var authService

    /// Fealty-Level aus globalem Profil (fallback 0)
    private var fealtyLevel: Int {
        authService.profile?.fealtyLevel ?? 0
    }

    /// Prestige-Level aus globalem Profil (fallback 0)
    private var prestigeLevel: Int {
        authService.profile?.prestigeLevel ?? 0
    }

    /// Aktive Boni nach Truppentyp (nur nicht-null anzeigen)
    private var activeBonuses: [(label: String, percent: Double)] {
        let types: [(TroopType, String)] = [
            (.infantry, "Kaserne"),
            (.cavalry, "Stall"),
            (.siege, "Werkstatt"),
        ]
        return types.compactMap { type, label in
            let r = type.trainingCostReduction(fealty: fealtyLevel, prestige: prestigeLevel)
            guard r > 0 else { return nil }
            return (label, r * 100)
        }
    }

    @State private var showBonuses = false

    var body: some View {
        List {
            // Hinweis
            Section {
                Text("Belagerungswaffen zählen in Kampfberechnungen als Infanterie.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !activeBonuses.isEmpty {
                    DisclosureGroup("Treue-Boni", isExpanded: $showBonuses) {
                        ForEach(activeBonuses, id: \.label) { bonus in
                            Label(
                                String(format: "%@: Kosten −%.1f%%", bonus.label, bonus.percent),
                                systemImage: "star.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Einheiten
            ForEach(units) { unit in
                Section {
                    TroopUnitRow(
                        unit: unit,
                        costReduction: unit.type.trainingCostReduction(
                            fealty: fealtyLevel,
                            prestige: prestigeLevel
                        )
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tribeName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Einheiten-Zeile

private struct TroopUnitRow: View {
    let unit: TroopUnit
    var costReduction: Double = 0.0

    /// Reduzierte Kosten (floor wie im Spiel)
    private func adjustedCost(_ base: Int) -> Int {
        guard costReduction > 0 else { return base }
        return max(0, Int(floor(Double(base) * (1.0 - costReduction))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + Typ
            HStack {
                Text(unit.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(unit.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(unit.type.badgeColor)
                    .clipShape(Capsule())
            }

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                TroopStatCell(icon: "⚔️", label: "Angriff", value: "\(unit.attack)")
                TroopStatCell(icon: "🛡", label: "Def Inf.", value: "\(unit.defInfantry)")
                TroopStatCell(icon: "🐴", label: "Def Kav.", value: "\(unit.defCavalry)")
                TroopStatCell(icon: "💨", label: "Tempo", value: "\(unit.speed)")
                TroopStatCell(icon: "🎒", label: "Kapazität", value: "\(unit.carry)")
                TroopStatCell(icon: "🌾", label: "Unterhalt", value: "\(unit.upkeep)")
            }

            // Ausbildungskosten
            HStack(spacing: 6) {
                Text("Kosten")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)

                TroopCostBadge(icon: "🪵", value: adjustedCost(unit.costWood))
                TroopCostBadge(icon: "🧱", value: adjustedCost(unit.costClay))
                TroopCostBadge(icon: "⚙️", value: adjustedCost(unit.costIron))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TroopStatCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(icon)
                .font(.caption)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TroopCostBadge: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            Text(icon)
                .font(.caption2)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Roemer Truppen

struct TroopsRomansView: View {
    var body: some View {
        TroopStatsView(tribeName: "Römer", units: Self.units)
    }

    static let units: [TroopUnit] = [
        TroopUnit(name: "Legionär",            attack: 40,  defInfantry: 35,  defCavalry: 50,  speed: 6,  carry: 50,   upkeep: 1, type: .infantry, costWood: 75,    costClay: 50,    costIron: 100,   baseTrainingTimeSec: 1200),
        TroopUnit(name: "Prätorianer",          attack: 30,  defInfantry: 65,  defCavalry: 35,  speed: 5,  carry: 20,   upkeep: 1, type: .infantry, costWood: 80,    costClay: 100,   costIron: 160,   baseTrainingTimeSec: 1440),
        TroopUnit(name: "Imperianer",           attack: 70,  defInfantry: 40,  defCavalry: 25,  speed: 7,  carry: 50,   upkeep: 1, type: .infantry, costWood: 100,   costClay: 110,   costIron: 140,   baseTrainingTimeSec: 1560),
        TroopUnit(name: "Equites Legati",       attack: 0,   defInfantry: 20,  defCavalry: 10,  speed: 16, carry: 0,    upkeep: 2, type: .cavalry,  costWood: 100,   costClay: 140,   costIron: 10,    baseTrainingTimeSec: 1200),
        TroopUnit(name: "Equites Imperatoris",  attack: 120, defInfantry: 65,  defCavalry: 50,  speed: 14, carry: 100,  upkeep: 3, type: .cavalry,  costWood: 350,   costClay: 260,   costIron: 180,   baseTrainingTimeSec: 2160),
        TroopUnit(name: "Equites Caesaris",     attack: 180, defInfantry: 80,  defCavalry: 105, speed: 10, carry: 70,   upkeep: 4, type: .cavalry,  costWood: 280,   costClay: 340,   costIron: 600,   baseTrainingTimeSec: 2880),
        TroopUnit(name: "Rammbock",             attack: 60,  defInfantry: 30,  defCavalry: 75,  speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 700,   costClay: 180,   costIron: 400,   baseTrainingTimeSec: 3600),
        TroopUnit(name: "Feuerkatapult",        attack: 75,  defInfantry: 60,  defCavalry: 10,  speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 690,   costClay: 1000,  costIron: 400,   baseTrainingTimeSec: 7200),
        TroopUnit(name: "Senator",              attack: 50,  defInfantry: 40,  defCavalry: 30,  speed: 4,  carry: 0,    upkeep: 5, type: .infantry, costWood: 30750, costClay: 27200, costIron: 45000,  baseTrainingTimeSec: 73700),
        TroopUnit(name: "Siedler",              attack: 0,   defInfantry: 80,  defCavalry: 80,  speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 3500,  costClay: 3000,  costIron: 4500,  baseTrainingTimeSec: 22700),
    ]
}

// MARK: - Germanen Truppen

struct TroopsTeutonsView: View {
    var body: some View {
        TroopStatsView(tribeName: "Germanen", units: Self.units)
    }

    static let units: [TroopUnit] = [
        TroopUnit(name: "Keulenschwinger",  attack: 40,  defInfantry: 20,  defCavalry: 5,  speed: 7,  carry: 60,   upkeep: 1, type: .infantry, costWood: 85,    costClay: 65,    costIron: 30,    baseTrainingTimeSec: 720),
        TroopUnit(name: "Speerkämpfer",     attack: 10,  defInfantry: 35,  defCavalry: 60, speed: 7,  carry: 40,   upkeep: 1, type: .infantry, costWood: 125,   costClay: 50,    costIron: 65,    baseTrainingTimeSec: 1080),
        TroopUnit(name: "Axtkämpfer",       attack: 60,  defInfantry: 30,  defCavalry: 30, speed: 6,  carry: 50,   upkeep: 1, type: .infantry, costWood: 80,    costClay: 65,    costIron: 130,   baseTrainingTimeSec: 1320),
        TroopUnit(name: "Kundschafter",     attack: 0,   defInfantry: 10,  defCavalry: 5,  speed: 9,  carry: 0,    upkeep: 1, type: .infantry, costWood: 140,   costClay: 80,    costIron: 30,    baseTrainingTimeSec: 900),
        TroopUnit(name: "Paladin",          attack: 55,  defInfantry: 100, defCavalry: 40, speed: 10, carry: 110,  upkeep: 2, type: .cavalry,  costWood: 330,   costClay: 170,   costIron: 200,   baseTrainingTimeSec: 2160),
        TroopUnit(name: "Teutonen-Reiter",  attack: 150, defInfantry: 50,  defCavalry: 75, speed: 9,  carry: 80,   upkeep: 3, type: .cavalry,  costWood: 280,   costClay: 320,   costIron: 260,   baseTrainingTimeSec: 2880),
        TroopUnit(name: "Ramme",            attack: 65,  defInfantry: 30,  defCavalry: 80, speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 800,   costClay: 150,   costIron: 250,   baseTrainingTimeSec: 3600),
        TroopUnit(name: "Katapult",         attack: 50,  defInfantry: 60,  defCavalry: 10, speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 660,   costClay: 900,   costIron: 370,   baseTrainingTimeSec: 7200),
        TroopUnit(name: "Stammesführer",    attack: 40,  defInfantry: 60,  defCavalry: 40, speed: 4,  carry: 0,    upkeep: 4, type: .infantry, costWood: 35500, costClay: 26600, costIron: 25000,  baseTrainingTimeSec: 73700),
        TroopUnit(name: "Siedler",          attack: 10,  defInfantry: 80,  defCavalry: 80, speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 4000,  costClay: 3500,  costIron: 3200,  baseTrainingTimeSec: 22700),
    ]
}

// MARK: - Gallier Truppen

struct TroopsGaulsView: View {
    var body: some View {
        TroopStatsView(tribeName: "Gallier", units: Self.units)
    }

    static let units: [TroopUnit] = [
        TroopUnit(name: "Phalanx",           attack: 15,  defInfantry: 40,  defCavalry: 50,  speed: 7,  carry: 35,   upkeep: 1, type: .infantry, costWood: 85,    costClay: 100,   costIron: 50,    baseTrainingTimeSec: 1080),
        TroopUnit(name: "Schwertkämpfer",    attack: 65,  defInfantry: 35,  defCavalry: 20,  speed: 6,  carry: 45,   upkeep: 1, type: .infantry, costWood: 95,    costClay: 60,    costIron: 140,   baseTrainingTimeSec: 1320),
        TroopUnit(name: "Späher",            attack: 0,   defInfantry: 20,  defCavalry: 10,  speed: 17, carry: 0,    upkeep: 2, type: .cavalry,  costWood: 140,   costClay: 110,   costIron: 20,    baseTrainingTimeSec: 1200),
        TroopUnit(name: "Theutates-Blitz",   attack: 90,  defInfantry: 25,  defCavalry: 40,  speed: 19, carry: 75,   upkeep: 2, type: .cavalry,  costWood: 200,   costClay: 280,   costIron: 130,   baseTrainingTimeSec: 2160),
        TroopUnit(name: "Druidenreiter",     attack: 45,  defInfantry: 115, defCavalry: 55,  speed: 16, carry: 35,   upkeep: 2, type: .cavalry,  costWood: 300,   costClay: 270,   costIron: 190,   baseTrainingTimeSec: 2160),
        TroopUnit(name: "Haeduaner",         attack: 140, defInfantry: 60,  defCavalry: 165, speed: 13, carry: 65,   upkeep: 3, type: .cavalry,  costWood: 300,   costClay: 380,   costIron: 440,   baseTrainingTimeSec: 2880),
        TroopUnit(name: "Ramme",             attack: 50,  defInfantry: 30,  defCavalry: 105, speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 750,   costClay: 370,   costIron: 220,   baseTrainingTimeSec: 3600),
        TroopUnit(name: "Kriegskatapult",    attack: 70,  defInfantry: 45,  defCavalry: 10,  speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 590,   costClay: 1200,  costIron: 400,   baseTrainingTimeSec: 7200),
        TroopUnit(name: "Häuptling",         attack: 40,  defInfantry: 50,  defCavalry: 50,  speed: 5,  carry: 0,    upkeep: 4, type: .infantry, costWood: 30750, costClay: 45400, costIron: 31000,  baseTrainingTimeSec: 73700),
        TroopUnit(name: "Siedler",           attack: 0,   defInfantry: 80,  defCavalry: 80,  speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 3000,  costClay: 4000,  costIron: 3000,  baseTrainingTimeSec: 22700),
    ]
}

// MARK: - Truppenrechner

struct TroopCalculatorView: View {

    @Environment(AuthService.self) var authService

    // Auswahl
    @State private var selectedTribe: TroopsTribe = .romans
    @State private var selectedUnitIndex: Int = 0

    // Eingabe
    @State private var hours: Int = 8
    @State private var minutes: Int = 0
    @State private var buildingLevel: Int = 10
    @State private var gameSpeed: Int = 1

    /// Kaserne/Stall/Werkstatt-Multiplikator pro Stufe (Prozent der Basiszeit)
    private static let trainingPercent: [Int] = [
        100, 90, 81, 73, 66, 59, 53, 48, 43, 39, 35, 31, 28, 25, 23, 21, 19, 17, 15, 14
    ]

    // MARK: - Abgeleitete Werte

    private var units: [TroopUnit] {
        switch selectedTribe {
        case .gauls:   return TroopsGaulsView.units
        case .romans:  return TroopsRomansView.units
        case .teutons: return TroopsTeutonsView.units
        }
    }

    private var selectedUnit: TroopUnit {
        let idx = min(selectedUnitIndex, units.count - 1)
        return units[max(0, idx)]
    }

    private var buildingName: String {
        switch selectedUnit.type {
        case .infantry: return "Kaserne"
        case .cavalry:  return "Stall"
        case .siege:    return "Werkstatt"
        }
    }

    private var totalSeconds: Int {
        hours * 3600 + minutes * 60
    }

    /// Bauzeit-Reduktion durch Treue (Level 11+) — identisch mit InfrastructureToolView
    private var fealtyTimeReduction: Double {
        guard fealtyLevel >= 11 else { return 0.0 }
        var reduction: Double
        switch fealtyLevel {
        case 11: reduction = 1.0
        case 12: reduction = 1.5
        default: reduction = Double(min(fealtyLevel, 20) - 11)
        }
        if prestigeLevel >= 11 { reduction += 1.0 }
        return reduction / 100.0
    }

    private var effectiveTimeSec: Double {
        let pct = Self.trainingPercent[min(buildingLevel - 1, 19)]
        var seconds = Double(selectedUnit.baseTrainingTimeSec) / Double(max(1, gameSpeed))
        seconds *= Double(pct) / 100.0
        if fealtyTimeReduction > 0 {
            seconds *= (1.0 - fealtyTimeReduction)
        }
        return seconds
    }

    private var producibleCount: Int {
        guard effectiveTimeSec > 0 && totalSeconds > 0 else { return 0 }
        return Int(floor(Double(totalSeconds) / effectiveTimeSec))
    }

    private var fealtyLevel: Int { authService.profile?.fealtyLevel ?? 0 }
    private var prestigeLevel: Int { authService.profile?.prestigeLevel ?? 0 }

    private var costReduction: Double {
        selectedUnit.type.trainingCostReduction(fealty: fealtyLevel, prestige: prestigeLevel)
    }

    private func adjusted(_ base: Int) -> Int {
        guard costReduction > 0 else { return base }
        return max(0, Int(floor(Double(base) * (1.0 - costReduction))))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Volk ──
                tribePicker

                // ── Einheit ──
                unitPicker

                // ── Zeit ──
                timeInput

                // ── Gebäudestufe ──
                buildingLevelSlider

                // ── Geschwindigkeit ──
                speedPicker

                Divider()
                    .padding(.horizontal)

                // ── Ergebnis ──
                resultSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Truppenrechner")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedTribe) { _, _ in
            selectedUnitIndex = 0
        }
    }

    // MARK: - Tribe Picker

    @ViewBuilder
    private var tribePicker: some View {
        Picker("Volk", selection: $selectedTribe) {
            ForEach(TroopsTribe.allCases) { tribe in
                Text(tribe.title).tag(tribe)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Unit Picker (horizontale Chips)

    @ViewBuilder
    private var unitPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(units.enumerated()), id: \.offset) { idx, unit in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            selectedUnitIndex = idx
                        }
                    } label: {
                        Text(unit.name)
                            .font(.caption)
                            .fontWeight(selectedUnitIndex == idx ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedUnitIndex == idx ? unit.type.badgeColor : Color(.systemGray5))
                            .foregroundStyle(selectedUnitIndex == idx ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Zeit-Eingabe

    @ViewBuilder
    private var timeInput: some View {
        VStack(spacing: 8) {
            Text("Produktionszeit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Stepper(value: $hours, in: 0...999) {
                        HStack(spacing: 4) {
                            Text("\(hours)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .frame(minWidth: 30, alignment: .trailing)
                            Text("Std")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Stepper(value: $minutes, in: 0...59) {
                        HStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .frame(minWidth: 20, alignment: .trailing)
                            Text("Min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Schnellauswahl
            HStack(spacing: 8) {
                ForEach([1, 4, 8, 12, 24], id: \.self) { h in
                    Button("\(h)h") {
                        hours = h
                        minutes = 0
                    }
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(hours == h && minutes == 0 ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(hours == h && minutes == 0 ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Gebaeudestufe Slider

    @ViewBuilder
    private var buildingLevelSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text(buildingName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Stufe \(buildingLevel)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(buildingLevel) },
                    set: { buildingLevel = Int($0) }
                ),
                in: 1...20,
                step: 1
            )
            .tint(selectedUnit.type.badgeColor)

            // Bauzeit pro Einheit
            HStack {
                Text("Bauzeit pro Einheit:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(Int(effectiveTimeSec)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Geschwindigkeit

    @ViewBuilder
    private var speedPicker: some View {
        HStack {
            Text("Geschwindigkeit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach([1, 2, 3, 5], id: \.self) { speed in
                    Button {
                        gameSpeed = speed
                    } label: {
                        Text("\(speed)\u{00D7}")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(gameSpeed == speed ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(gameSpeed == speed ? Color.accentColor : Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private var resultSection: some View {
        VStack(spacing: 14) {

            // Grosse Anzahl
            VStack(spacing: 4) {
                Text("\(producibleCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedUnit.type.badgeColor)
                    .contentTransition(.numericText())

                Text(selectedUnit.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .animation(.snappy(duration: 0.15), value: producibleCount)

            Divider()

            // Ressourcen-Kosten
            VStack(spacing: 8) {
                Text("Gesamtkosten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    calcCostCell(icon: "🪵", value: adjusted(selectedUnit.costWood) * producibleCount)
                    calcCostCell(icon: "🧱", value: adjusted(selectedUnit.costClay) * producibleCount)
                    calcCostCell(icon: "⚙️", value: adjusted(selectedUnit.costIron) * producibleCount)
                }
            }

            // Unterhalt
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Unterhalt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedUnit.upkeep * producibleCount) 🌾/h")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            // Treue-Hinweise
            if costReduction > 0 || fealtyTimeReduction > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    if costReduction > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.orange)
                            Text(String(format: "Treue-Bonus: Kosten −%.1f%%", costReduction * 100))
                                .foregroundStyle(.orange)
                        }
                    }
                    if fealtyTimeReduction > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text(String(format: "Treue-Bonus: Bauzeit −%.1f%%", fealtyTimeReduction * 100))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func calcCostCell(icon: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text(icon)
                .font(.caption)
            Text(formatNumber(value))
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        }
        if n >= 10_000 {
            return String(format: "%.0fk", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
