import SwiftUI

// MARK: - Rechte Hand Gallier

struct RightHandGaulsView: View {

    @EnvironmentObject private var authService: AuthService
    @StateObject private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welche Waffe ist aufgeklappt (Rangliste sichtbar)
    @State private var expandedTierId: String? = nil

    var body: some View {
        List {
            // Tier-Picker
            Section {
                TierPicker(
                    selectedTier: $selectedTier,
                    autoTier: tierService.currentTier,
                    maxTier: tierService.maxTier,
                    tier2Date: tierService.tier2Date,
                    tier3Date: tierService.tier3Date
                )
            }

            // Waffen-Kategorien (nur passende Stufen anzeigen)
            ForEach(GaulWeaponCategory.allCases) { category in
                Section {
                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        GaulWeaponTierRow(
                            tier: tier,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    GaulWeaponCategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            if let worldId = authService.profile?.worldId, !worldId.isEmpty {
                await tierService.loadTierDates(worldId: worldId)
            }
        }
    }

    /// Die angezeigte Stufe: User-Auswahl oder automatisch.
    private var displayTier: Int {
        selectedTier ?? tierService.currentTier
    }
}

// MARK: - Kategorie Header

private struct GaulWeaponCategoryHeader: View {
    let category: GaulWeaponCategory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundStyle(category.color)
            Text(category.title)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .textCase(nil)
    }
}

// MARK: - Stufen-Zeile (antippbar → Rangliste)

private struct GaulWeaponTierRow: View {
    let tier: GaulWeaponTier
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hauptbereich (antippbar)
            VStack(alignment: .leading, spacing: 8) {
                // Stufe + Name
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Stufe \(tier.level)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(tier.tierColor)
                        .clipShape(Capsule())

                    Text(tier.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                // Haupteffekt (Kampfkraft)
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(tier.tierColor)
                    Text(tier.effectPrimary)
                        .font(.callout)
                }

                // Zweiter Effekt (Truppen-Bonus)
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                        .foregroundStyle(tier.tierColor.opacity(0.7))
                    Text(tier.effectSecondary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Rangliste (aufklappbar)
            if isExpanded {
                GaulWeaponRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct GaulWeaponRankingList: View {
    let tier: GaulWeaponTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                GaulWeaponRankingRow(rank: index + 1, value: ranking.value, unit: "Kampfkraft", isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct GaulWeaponRankingRow: View {
    let rank: Int
    let value: String
    let unit: String
    let isTop: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Rang-Badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 24, height: 24)
                .background(rankColor.opacity(0.12))
                .clipShape(Circle())

            // Wert
            Text(value)
                .font(.subheadline)
                .fontWeight(isTop ? .bold : .regular)
                .foregroundStyle(isTop ? .primary : .secondary)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isTop {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 5)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Daten-Modell

enum GaulWeaponCategory: String, CaseIterable, Identifiable {
    case phalanxSpear
    case swordsmanSword
    case theutatesBow
    case druidriderStaff
    case haeduan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phalanxSpear:     return "Speer der Phalanx"
        case .swordsmanSword:   return "Schwert des Schwertkämpfers"
        case .theutatesBow:     return "Bogen des Theutates"
        case .druidriderStaff:  return "Stab des Druidenreiters"
        case .haeduan:          return "Lanze des Haeduaners"
        }
    }

    var icon: String {
        switch self {
        case .phalanxSpear:     return "arrow.up.to.line"
        case .swordsmanSword:   return "bolt.horizontal.fill"
        case .theutatesBow:     return "scope"
        case .druidriderStaff:  return "wand.and.stars"
        case .haeduan:          return "arrow.up.right"
        }
    }

    var color: Color {
        switch self {
        case .phalanxSpear:     return .green
        case .swordsmanSword:   return .blue
        case .theutatesBow:     return .orange
        case .druidriderStaff:  return .purple
        case .haeduan:          return .red
        }
    }

    /// Truppenname fuer den Sekundaereffekt.
    var troopName: String {
        switch self {
        case .phalanxSpear:     return "Phalanx"
        case .swordsmanSword:   return "Schwertkämpfer"
        case .theutatesBow:     return "Theutates-Blitz"
        case .druidriderStaff:  return "Druidenreiter"
        case .haeduan:          return "Haeduaner"
        }
    }

    /// Gibt alle Stufen bis einschliesslich `maxLevel` zurueck.
    func tiers(upTo maxLevel: Int) -> [GaulWeaponTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    private var allTiers: [GaulWeaponTier] {
        let bonusPerLevel: [(atk: Int, def: Int)] = troopBonusValues
        return [
            GaulWeaponTier(level: 1, name: tierNames[0],
                           heroStrength: 500,
                           troopAtk: bonusPerLevel[0].atk, troopDef: bonusPerLevel[0].def,
                           troopName: troopName,
                           variantSteps: [100, 50, 0, -50, -100],
                           category: self),
            GaulWeaponTier(level: 2, name: tierNames[1],
                           heroStrength: 1000,
                           troopAtk: bonusPerLevel[1].atk, troopDef: bonusPerLevel[1].def,
                           troopName: troopName,
                           variantSteps: [200, 100, 0, -100, -200],
                           category: self),
            GaulWeaponTier(level: 3, name: tierNames[2],
                           heroStrength: 1500,
                           troopAtk: bonusPerLevel[2].atk, troopDef: bonusPerLevel[2].def,
                           troopName: troopName,
                           variantSteps: [500, 300, 200, 100, 0],
                           category: self),
        ]
    }

    private var tierNames: [String] {
        switch self {
        case .phalanxSpear:
            return ["Speer der Phalanx", "Spieß der Phalanx", "Lanze der Phalanx"]
        case .swordsmanSword:
            return ["Kurzschwert des Schwertkämpfers", "Schwert des Schwertkämpfers", "Langschwert des Schwertkämpfers"]
        case .theutatesBow:
            return ["Kurzbogen des Theutates", "Bogen des Theutates", "Langbogen des Theutates"]
        case .druidriderStaff:
            return ["Wanderstab des Druidenreiters", "Stab des Druidenreiters", "Kampfstab des Druidenreiters"]
        case .haeduan:
            return ["Leichte Lanze des Haeduaners", "Lanze des Haeduaners", "Schwere Lanze des Haeduaners"]
        }
    }

    /// Truppen-Bonuswerte (Angriff/Verteidigung) pro Stufe.
    private var troopBonusValues: [(atk: Int, def: Int)] {
        switch self {
        case .phalanxSpear:     return [(3, 3), (4, 4), (5, 5)]
        case .swordsmanSword:   return [(3, 3), (4, 4), (5, 5)]
        case .theutatesBow:     return [(6, 6), (8, 8), (10, 10)]
        case .druidriderStaff:  return [(6, 6), (8, 8), (10, 10)]
        case .haeduan:          return [(9, 9), (12, 12), (15, 15)]
        }
    }
}

struct GaulWeaponTier: Identifiable {
    let level: Int
    let name: String
    let heroStrength: Int          // Kampfkraft fuer Helden
    let troopAtk: Int              // Angriff pro Truppe
    let troopDef: Int              // Verteidigung pro Truppe
    let troopName: String          // Name der Truppeneinheit
    let variantSteps: [Int]        // Absteigend sortiert: best → worst (Kampfkraft)
    let category: GaulWeaponCategory

    var id: String { "\(category.rawValue)-\(level)" }

    var tierColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    /// Primaereffekt: Kampfkraft fuer Helden.
    var effectPrimary: String {
        "+\(heroStrength) Kampfkraft für Helden"
    }

    /// Sekundaereffekt: Truppen-Bonus.
    var effectSecondary: String {
        "+\(troopAtk) Angriff / +\(troopDef) Verteidigung pro \(troopName)"
    }

    /// Rangliste: Kampfkraft-Varianten.
    var rankings: [RankingEntry] {
        variantSteps.map { step in
            let val = heroStrength + step
            return RankingEntry(value: "+\(val)")
        }
    }
}
