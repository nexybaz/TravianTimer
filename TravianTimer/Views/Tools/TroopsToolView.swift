import SwiftUI

// MARK: - Truppen Tool

struct TroopsToolView: View {

    @Environment(AuthService.self) var authService
    @State private var favorites = FavoritesStore.shared

    var body: some View {
        List {
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
        TroopUnit(name: "Legionär",            attack: 40,  defInfantry: 35,  defCavalry: 50,  speed: 6,  carry: 50,   upkeep: 1, type: .infantry, costWood: 75,    costClay: 50,    costIron: 100),
        TroopUnit(name: "Prätorianer",          attack: 30,  defInfantry: 65,  defCavalry: 35,  speed: 5,  carry: 20,   upkeep: 1, type: .infantry, costWood: 80,    costClay: 100,   costIron: 160),
        TroopUnit(name: "Imperianer",           attack: 70,  defInfantry: 40,  defCavalry: 25,  speed: 7,  carry: 50,   upkeep: 1, type: .infantry, costWood: 100,   costClay: 110,   costIron: 140),
        TroopUnit(name: "Equites Legati",       attack: 0,   defInfantry: 20,  defCavalry: 10,  speed: 16, carry: 0,    upkeep: 2, type: .cavalry,  costWood: 100,   costClay: 140,   costIron: 10),
        TroopUnit(name: "Equites Imperatoris",  attack: 120, defInfantry: 65,  defCavalry: 50,  speed: 14, carry: 100,  upkeep: 3, type: .cavalry,  costWood: 350,   costClay: 260,   costIron: 180),
        TroopUnit(name: "Equites Caesaris",     attack: 180, defInfantry: 80,  defCavalry: 105, speed: 10, carry: 70,   upkeep: 4, type: .cavalry,  costWood: 280,   costClay: 340,   costIron: 600),
        TroopUnit(name: "Rammbock",             attack: 60,  defInfantry: 30,  defCavalry: 75,  speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 700,   costClay: 180,   costIron: 400),
        TroopUnit(name: "Feuerkatapult",        attack: 75,  defInfantry: 60,  defCavalry: 10,  speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 690,   costClay: 1000,  costIron: 400),
        TroopUnit(name: "Senator",              attack: 50,  defInfantry: 40,  defCavalry: 30,  speed: 4,  carry: 0,    upkeep: 5, type: .infantry, costWood: 30750, costClay: 27200, costIron: 45000),
        TroopUnit(name: "Siedler",              attack: 0,   defInfantry: 80,  defCavalry: 80,  speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 3500,  costClay: 3000,  costIron: 4500),
    ]
}

// MARK: - Germanen Truppen

struct TroopsTeutonsView: View {
    var body: some View {
        TroopStatsView(tribeName: "Germanen", units: Self.units)
    }

    static let units: [TroopUnit] = [
        TroopUnit(name: "Keulenschwinger",  attack: 40,  defInfantry: 20,  defCavalry: 5,  speed: 7,  carry: 60,   upkeep: 1, type: .infantry, costWood: 85,    costClay: 65,    costIron: 30),
        TroopUnit(name: "Speerkämpfer",     attack: 10,  defInfantry: 35,  defCavalry: 60, speed: 7,  carry: 40,   upkeep: 1, type: .infantry, costWood: 125,   costClay: 50,    costIron: 65),
        TroopUnit(name: "Axtkämpfer",       attack: 60,  defInfantry: 30,  defCavalry: 30, speed: 6,  carry: 50,   upkeep: 1, type: .infantry, costWood: 80,    costClay: 65,    costIron: 130),
        TroopUnit(name: "Kundschafter",     attack: 0,   defInfantry: 10,  defCavalry: 5,  speed: 9,  carry: 0,    upkeep: 1, type: .infantry, costWood: 140,   costClay: 80,    costIron: 30),
        TroopUnit(name: "Paladin",          attack: 55,  defInfantry: 100, defCavalry: 40, speed: 10, carry: 110,  upkeep: 2, type: .cavalry,  costWood: 330,   costClay: 170,   costIron: 200),
        TroopUnit(name: "Teutonen-Reiter",  attack: 150, defInfantry: 50,  defCavalry: 75, speed: 9,  carry: 80,   upkeep: 3, type: .cavalry,  costWood: 280,   costClay: 320,   costIron: 260),
        TroopUnit(name: "Ramme",            attack: 65,  defInfantry: 30,  defCavalry: 80, speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 800,   costClay: 150,   costIron: 250),
        TroopUnit(name: "Katapult",         attack: 50,  defInfantry: 60,  defCavalry: 10, speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 660,   costClay: 900,   costIron: 370),
        TroopUnit(name: "Stammesführer",    attack: 40,  defInfantry: 60,  defCavalry: 40, speed: 4,  carry: 0,    upkeep: 4, type: .infantry, costWood: 35500, costClay: 26600, costIron: 25000),
        TroopUnit(name: "Siedler",          attack: 10,  defInfantry: 80,  defCavalry: 80, speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 4000,  costClay: 3500,  costIron: 3200),
    ]
}

// MARK: - Gallier Truppen

struct TroopsGaulsView: View {
    var body: some View {
        TroopStatsView(tribeName: "Gallier", units: Self.units)
    }

    static let units: [TroopUnit] = [
        TroopUnit(name: "Phalanx",           attack: 15,  defInfantry: 40,  defCavalry: 50,  speed: 7,  carry: 35,   upkeep: 1, type: .infantry, costWood: 85,    costClay: 100,   costIron: 50),
        TroopUnit(name: "Schwertkämpfer",    attack: 65,  defInfantry: 35,  defCavalry: 20,  speed: 6,  carry: 45,   upkeep: 1, type: .infantry, costWood: 95,    costClay: 60,    costIron: 140),
        TroopUnit(name: "Späher",            attack: 0,   defInfantry: 20,  defCavalry: 10,  speed: 17, carry: 0,    upkeep: 2, type: .cavalry,  costWood: 140,   costClay: 110,   costIron: 20),
        TroopUnit(name: "Theutates-Blitz",   attack: 90,  defInfantry: 25,  defCavalry: 40,  speed: 19, carry: 75,   upkeep: 2, type: .cavalry,  costWood: 200,   costClay: 280,   costIron: 130),
        TroopUnit(name: "Druidenreiter",     attack: 45,  defInfantry: 115, defCavalry: 55,  speed: 16, carry: 35,   upkeep: 2, type: .cavalry,  costWood: 300,   costClay: 270,   costIron: 190),
        TroopUnit(name: "Haeduaner",         attack: 140, defInfantry: 60,  defCavalry: 165, speed: 13, carry: 65,   upkeep: 3, type: .cavalry,  costWood: 300,   costClay: 380,   costIron: 440),
        TroopUnit(name: "Ramme",             attack: 50,  defInfantry: 30,  defCavalry: 105, speed: 4,  carry: 0,    upkeep: 3, type: .siege,    costWood: 750,   costClay: 370,   costIron: 220),
        TroopUnit(name: "Kriegskatapult",    attack: 70,  defInfantry: 45,  defCavalry: 10,  speed: 3,  carry: 0,    upkeep: 6, type: .siege,    costWood: 590,   costClay: 1200,  costIron: 400),
        TroopUnit(name: "Häuptling",         attack: 40,  defInfantry: 50,  defCavalry: 50,  speed: 5,  carry: 0,    upkeep: 4, type: .infantry, costWood: 30750, costClay: 45400, costIron: 31000),
        TroopUnit(name: "Siedler",           attack: 0,   defInfantry: 80,  defCavalry: 80,  speed: 5,  carry: 3000, upkeep: 1, type: .infantry, costWood: 3000,  costClay: 4000,  costIron: 3000),
    ]
}
