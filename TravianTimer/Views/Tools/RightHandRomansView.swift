import SwiftUI

// MARK: - Rechte Hand Roemer

struct RightHandRomansView: View {

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
            ForEach(RomanWeaponCategory.allCases) { category in
                Section {
                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        RomanWeaponTierRow(
                            tier: tier,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    RomanWeaponCategoryHeader(category: category)
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

private struct RomanWeaponCategoryHeader: View {
    let category: RomanWeaponCategory

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

private struct RomanWeaponTierRow: View {
    let tier: RomanWeaponTier
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                RomanWeaponRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct RomanWeaponRankingList: View {
    let tier: RomanWeaponTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                RomanWeaponRankingRow(rank: index + 1, value: ranking.value, unit: "Kampfkraft", isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct RomanWeaponRankingRow: View {
    let rank: Int
    let value: String
    let unit: String
    let isTop: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 24, height: 24)
                .background(rankColor.opacity(0.12))
                .clipShape(Circle())

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

enum RomanWeaponCategory: String, CaseIterable, Identifiable {
    case legionnaire
    case praetorian
    case imperian
    case imperatoris
    case caesaris

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legionnaire: return "Schwert des Legionärs"
        case .praetorian:  return "Schwert des Prätorianers"
        case .imperian:    return "Schwert des Imperianers"
        case .imperatoris: return "Schwert des Imperatoris"
        case .caesaris:    return "Lanze des Caesaris"
        }
    }

    var icon: String {
        switch self {
        case .legionnaire: return "bolt.horizontal.fill"
        case .praetorian:  return "shield.lefthalf.filled"
        case .imperian:    return "bolt.fill"
        case .imperatoris: return "arrow.up.right"
        case .caesaris:    return "arrow.up.to.line"
        }
    }

    var color: Color {
        switch self {
        case .legionnaire: return .red
        case .praetorian:  return .blue
        case .imperian:    return .green
        case .imperatoris: return .orange
        case .caesaris:    return .purple
        }
    }

    var troopName: String {
        switch self {
        case .legionnaire: return "Legionär"
        case .praetorian:  return "Prätorianer"
        case .imperian:    return "Imperianer"
        case .imperatoris: return "Imperatoris"
        case .caesaris:    return "Equites Caesaris"
        }
    }

    func tiers(upTo maxLevel: Int) -> [RomanWeaponTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    private var allTiers: [RomanWeaponTier] {
        let bonuses = troopBonusValues
        return [
            RomanWeaponTier(level: 1, name: tierNames[0],
                            heroStrength: 500,
                            troopAtk: bonuses[0].atk, troopDef: bonuses[0].def,
                            troopName: troopName,
                            variantSteps: [100, 50, 0, -50, -100],
                            category: self),
            RomanWeaponTier(level: 2, name: tierNames[1],
                            heroStrength: 1000,
                            troopAtk: bonuses[1].atk, troopDef: bonuses[1].def,
                            troopName: troopName,
                            variantSteps: [200, 100, 0, -100, -200],
                            category: self),
            RomanWeaponTier(level: 3, name: tierNames[2],
                            heroStrength: 1500,
                            troopAtk: bonuses[2].atk, troopDef: bonuses[2].def,
                            troopName: troopName,
                            variantSteps: [500, 300, 200, 100, 0],
                            category: self),
        ]
    }

    private var tierNames: [String] {
        switch self {
        case .legionnaire:
            return ["Kurzschwert des Legionärs", "Schwert des Legionärs", "Langschwert des Legionärs"]
        case .praetorian:
            return ["Kurzschwert des Prätorianers", "Schwert des Prätorianers", "Langschwert des Prätorianers"]
        case .imperian:
            return ["Kurzschwert des Imperianers", "Schwert des Imperianers", "Langschwert des Imperianers"]
        case .imperatoris:
            return ["Kurzschwert des Imperatoris", "Schwert des Imperatoris", "Langschwert des Imperatoris"]
        case .caesaris:
            return ["Leichte Lanze des Caesaris", "Lanze des Caesaris", "Schwere Lanze des Caesaris"]
        }
    }

    private var troopBonusValues: [(atk: Int, def: Int)] {
        switch self {
        case .legionnaire: return [(3, 3), (4, 4), (5, 5)]
        case .praetorian:  return [(3, 3), (4, 4), (5, 5)]
        case .imperian:    return [(3, 3), (4, 4), (5, 5)]
        case .imperatoris: return [(9, 9), (12, 12), (15, 15)]
        case .caesaris:    return [(12, 12), (16, 16), (20, 20)]
        }
    }
}

struct RomanWeaponTier: Identifiable {
    let level: Int
    let name: String
    let heroStrength: Int
    let troopAtk: Int
    let troopDef: Int
    let troopName: String
    let variantSteps: [Int]
    let category: RomanWeaponCategory

    var id: String { "\(category.rawValue)-\(level)" }

    var tierColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    var effectPrimary: String {
        "+\(heroStrength) Kampfkraft für Helden"
    }

    var effectSecondary: String {
        "+\(troopAtk) Angriff / +\(troopDef) Verteidigung pro \(troopName)"
    }

    var rankings: [RankingEntry] {
        variantSteps.map { step in
            RankingEntry(value: "+\(heroStrength + step)")
        }
    }
}
