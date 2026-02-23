import SwiftUI

// MARK: - Ruestungen Uebersicht

struct ArmorView: View {

    @EnvironmentObject private var authService: AuthService
    @StateObject private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welche Ruestung ist aufgeklappt (Rangliste sichtbar)
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

            // Ruestungs-Kategorien (nur passende Stufen anzeigen)
            ForEach(ArmorCategory.allCases) { category in
                Section {
                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        ArmorTierRow(
                            tier: tier,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    ArmorCategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Rüstungen")
        .navigationBarTitleDisplayMode(.inline)
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

private struct ArmorCategoryHeader: View {
    let category: ArmorCategory

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

private struct ArmorTierRow: View {
    let tier: ArmorTier
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

                // Haupteffekt
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(tier.tierColor)
                    Text(tier.effect)
                        .font(.callout)
                }

                // Zweiter Effekt (falls vorhanden)
                if let secondary = tier.secondaryEffect {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(tier.tierColor.opacity(0.7))
                        Text(secondary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Rangliste (aufklappbar)
            if isExpanded {
                ArmorRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct ArmorRankingList: View {
    let tier: ArmorTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                ArmorRankingRow(rank: index + 1, value: ranking.value, unit: tier.unit, isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct ArmorRankingRow: View {
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

enum ArmorCategory: String, CaseIterable, Identifiable {
    case regeneration
    case scaleMail
    case breastplate
    case segmentedArmor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regeneration:   return "Rüstung der Regeneration"
        case .scaleMail:      return "Schuppenpanzer"
        case .breastplate:    return "Brustpanzer"
        case .segmentedArmor: return "Gliederpanzer"
        }
    }

    var icon: String {
        switch self {
        case .regeneration:   return "heart.fill"
        case .scaleMail:      return "shield.lefthalf.filled"
        case .breastplate:    return "bolt.shield.fill"
        case .segmentedArmor: return "shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .regeneration:   return .red
        case .scaleMail:      return .teal
        case .breastplate:    return .indigo
        case .segmentedArmor: return .brown
        }
    }

    /// Gibt alle Stufen bis einschliesslich `maxLevel` zurueck.
    func tiers(upTo maxLevel: Int) -> [ArmorTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    // swiftlint:disable function_body_length
    private var allTiers: [ArmorTier] {
        switch self {

        // ── Ruestung der Regeneration ──────────────────────────
        case .regeneration:
            return [
                ArmorTier(level: 1, name: "Leichte Rüstung der Regeneration",
                          effect: "+20 Gesundheitspunkte / Tag",
                          secondaryEffect: nil,
                          baseValue: 20, variantSteps: [4, 2, 0, -2, -4],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
                ArmorTier(level: 2, name: "Rüstung der Regeneration",
                          effect: "+30 Gesundheitspunkte / Tag",
                          secondaryEffect: nil,
                          baseValue: 30, variantSteps: [4, 2, 0, -2, -4],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
                ArmorTier(level: 3, name: "Rüstung der Heilung",
                          effect: "+40 Gesundheitspunkte / Tag",
                          secondaryEffect: nil,
                          baseValue: 40, variantSteps: [4, 2, 0, -2, -4],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
            ]

        // ── Schuppenpanzer ─────────────────────────────────────
        case .scaleMail:
            return [
                ArmorTier(level: 1, name: "Leichter Schuppenpanzer",
                          effect: "Schaden um 4 HP reduziert",
                          secondaryEffect: "+10 HP/Tag",
                          baseValue: 10, variantSteps: [2, 1, 0, -1, -2],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
                ArmorTier(level: 2, name: "Schuppenpanzer",
                          effect: "Schaden um 6 HP reduziert",
                          secondaryEffect: "+15 HP/Tag",
                          baseValue: 15, variantSteps: [2, 1, 0, -1, -2],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
                ArmorTier(level: 3, name: "Schwerer Schuppenpanzer",
                          effect: "Schaden um 8 HP reduziert",
                          secondaryEffect: "+20 HP/Tag",
                          baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                          unit: "HP/Tag", prefix: "+",
                          category: self),
            ]

        // ── Brustpanzer ────────────────────────────────────────
        case .breastplate:
            return [
                ArmorTier(level: 1, name: "Leichter Brustpanzer",
                          effect: "+500 Kampfkraft für Helden",
                          secondaryEffect: nil,
                          baseValue: 500, variantSteps: [100, 50, 0, -50, -100],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
                ArmorTier(level: 2, name: "Brustpanzer",
                          effect: "+1000 Kampfkraft für Helden",
                          secondaryEffect: nil,
                          baseValue: 1000, variantSteps: [200, 100, 0, -100, -200],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
                ArmorTier(level: 3, name: "Schwerer Brustpanzer",
                          effect: "+1500 Kampfkraft für Helden",
                          secondaryEffect: nil,
                          baseValue: 1500, variantSteps: [500, 300, 200, 100, 0],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
            ]

        // ── Gliederpanzer ──────────────────────────────────────
        case .segmentedArmor:
            return [
                ArmorTier(level: 1, name: "Leichter Gliederpanzer",
                          effect: "Schaden um 3 HP reduziert",
                          secondaryEffect: "+250 Kampfkraft",
                          baseValue: 250, variantSteps: [50, 25, 0, -25, -50],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
                ArmorTier(level: 2, name: "Gliederpanzer",
                          effect: "Schaden um 4 HP reduziert",
                          secondaryEffect: "+500 Kampfkraft",
                          baseValue: 500, variantSteps: [100, 50, 0, -50, -100],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
                ArmorTier(level: 3, name: "Schwerer Gliederpanzer",
                          effect: "Schaden um 5 HP reduziert",
                          secondaryEffect: "+750 Kampfkraft",
                          baseValue: 750, variantSteps: [250, 150, 100, 50, 0],
                          unit: "Kampfkraft", prefix: "+",
                          category: self),
            ]
        }
    }
    // swiftlint:enable function_body_length
}

struct ArmorTier: Identifiable {
    let level: Int
    let name: String
    let effect: String
    let secondaryEffect: String?   // Zweiter Effekt (Schuppenpanzer, Gliederpanzer)
    let baseValue: Int
    let variantSteps: [Int]        // Absteigend sortiert: best → worst
    let unit: String
    let prefix: String             // "+" fuer positive Werte, "" fuer negative
    let category: ArmorCategory

    var id: String { "\(category.rawValue)-\(level)" }

    var tierColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    /// Rangliste: Basiswert + Variante, absteigend von gut zu schlecht.
    var rankings: [RankingEntry] {
        let values = variantSteps.map { baseValue + $0 }
        return values.map { val in
            let str: String
            if val > 0 {
                str = "\(prefix)\(val)"
            } else {
                str = "\(val)"
            }
            return RankingEntry(value: str)
        }
    }
}
