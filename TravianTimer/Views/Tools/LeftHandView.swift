import SwiftUI

// MARK: - Linke Hand Uebersicht

struct LeftHandView: View {

    @Environment(AuthService.self) var authService
    @State private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welcher Gegenstand ist aufgeklappt (Rangliste sichtbar)
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

            // Kategorien (nur passende Stufen anzeigen)
            ForEach(LeftHandCategory.allCases) { category in
                Section {
                    // Kategorie-Beschreibung (falls vorhanden)
                    if let note = category.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        LeftHandTierRow(
                            tier: tier,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    LeftHandCategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Linke Hand")
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

private struct LeftHandCategoryHeader: View {
    let category: LeftHandCategory

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

private struct LeftHandTierRow: View {
    let tier: LeftHandTier
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
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Rangliste (aufklappbar)
            if isExpanded {
                LeftHandRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct LeftHandRankingList: View {
    let tier: LeftHandTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                LeftHandRankingRow(rank: index + 1, value: ranking.value, unit: tier.unit, isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct LeftHandRankingRow: View {
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

enum LeftHandCategory: String, CaseIterable, Identifiable {
    case maps
    case tribeStandard
    case allianceStandard
    case telescope
    case bags
    case shields
    case horns

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maps:             return "Karten"
        case .tribeStandard:    return "Standarte des Volkes"
        case .allianceStandard: return "Standarte des Bundes"
        case .telescope:        return "Fernrohr"
        case .bags:             return "Taschen"
        case .shields:          return "Schilde"
        case .horns:            return "Hörner"
        }
    }

    var icon: String {
        switch self {
        case .maps:             return "map.fill"
        case .tribeStandard:    return "flag.fill"
        case .allianceStandard: return "flag.2.crossed.fill"
        case .telescope:        return "binoculars.fill"
        case .bags:             return "bag.fill"
        case .shields:          return "shield.fill"
        case .horns:            return "megaphone.fill"
        }
    }

    var color: Color {
        switch self {
        case .maps:             return .green
        case .tribeStandard:    return .blue
        case .allianceStandard: return .purple
        case .telescope:        return .cyan
        case .bags:             return .brown
        case .shields:          return .indigo
        case .horns:            return .orange
        }
    }

    /// Optionale Beschreibung unter dem Header.
    var note: String? {
        switch self {
        case .bags:
            return "Plünderungsbonus erhöht die Tragekapazität der Armee. Hat keinen Einfluss auf Verstecke."
        default:
            return nil
        }
    }

    /// Gibt alle Stufen bis einschliesslich `maxLevel` zurueck.
    func tiers(upTo maxLevel: Int) -> [LeftHandTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    // swiftlint:disable function_body_length
    private var allTiers: [LeftHandTier] {
        switch self {

        // ── Karten ─────────────────────────────────────────────
        case .maps:
            return [
                LeftHandTier(level: 1, name: "Kleine Karte",
                             effect: "30% schnellere Rückkehr (Held + Truppen)",
                             baseValue: 30, variantSteps: [10, 5, 0, -5, -10],
                             unit: "% Rückkehr", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Karte",
                             effect: "50% schnellere Rückkehr (Held + Truppen)",
                             baseValue: 50, variantSteps: [10, 5, 0, -5, -10],
                             unit: "% Rückkehr", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Große Karte",
                             effect: "80% schnellere Rückkehr (Held + Truppen)",
                             baseValue: 80, variantSteps: [20, 15, 10, 5, 0],
                             unit: "% Rückkehr", prefix: "+",
                             category: self),
            ]

        // ── Standarte des Volkes ───────────────────────────────
        case .tribeStandard:
            return [
                LeftHandTier(level: 1, name: "Kleine Standarte des Volkes",
                             effect: "30% schnellere Truppen zwischen eigenen Dörfern",
                             baseValue: 30, variantSteps: [5, 0, -5],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Standarte des Volkes",
                             effect: "40% schnellere Truppen zwischen eigenen Dörfern",
                             baseValue: 40, variantSteps: [5, 0, -5],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Große Standarte des Volkes",
                             effect: "50% schnellere Truppen zwischen eigenen Dörfern",
                             baseValue: 50, variantSteps: [5, 0, -5],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
            ]

        // ── Standarte des Bundes ───────────────────────────────
        case .allianceStandard:
            return [
                LeftHandTier(level: 1, name: "Kleine Standarte des Bundes",
                             effect: "15% schnellere Truppen zwischen Allianzmitgliedern",
                             baseValue: 15, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Standarte des Bundes",
                             effect: "20% schnellere Truppen zwischen Allianzmitgliedern",
                             baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Große Standarte des Bundes",
                             effect: "25% schnellere Truppen zwischen Allianzmitgliedern",
                             baseValue: 25, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Geschwindigkeit", prefix: "+",
                             category: self),
            ]

        // ── Fernrohr ──────────────────────────────────────────
        case .telescope:
            return [
                LeftHandTier(level: 1, name: "Kleines Fernrohr",
                             effect: "Truppentypen bei < 5 Truppen + VP-Stufe",
                             baseValue: 5, variantSteps: [2, 1, 0, -1, -2],
                             unit: "Truppen", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Fernrohr",
                             effect: "Truppentypen bei < 10 Truppen + VP-Stufe",
                             baseValue: 10, variantSteps: [2, 1, 0, -1, -2],
                             unit: "Truppen", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Großes Fernrohr",
                             effect: "Truppentypen bei < 15 Truppen + VP-Stufe",
                             baseValue: 15, variantSteps: [5, 3, 2, 1, 0],
                             unit: "Truppen", prefix: "+",
                             category: self),
            ]

        // ── Taschen ────────────────────────────────────────────
        case .bags:
            return [
                LeftHandTier(level: 1, name: "Kleiner Sack des Diebes",
                             effect: "10% Plünderungsbonus",
                             baseValue: 10, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Plünderung", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Sack des Diebes",
                             effect: "15% Plünderungsbonus",
                             baseValue: 15, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Plünderung", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Großer Sack des Diebes",
                             effect: "20% Plünderungsbonus",
                             baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Plünderung", prefix: "+",
                             category: self),
            ]

        // ── Schilde ────────────────────────────────────────────
        case .shields:
            return [
                LeftHandTier(level: 1, name: "Kleiner Kriegsschild",
                             effect: "+500 Kampfkraft für Helden",
                             baseValue: 500, variantSteps: [100, 50, 0, -50, -100],
                             unit: "Kampfkraft", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Kriegsschild",
                             effect: "+1000 Kampfkraft für Helden",
                             baseValue: 1000, variantSteps: [200, 100, 0, -100, -200],
                             unit: "Kampfkraft", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Großer Kriegsschild",
                             effect: "+1500 Kampfkraft für Helden",
                             baseValue: 1500, variantSteps: [500, 300, 200, 100, 0],
                             unit: "Kampfkraft", prefix: "+",
                             category: self),
            ]

        // ── Hoerner ────────────────────────────────────────────
        case .horns:
            return [
                LeftHandTier(level: 1, name: "Kleines Horn der Natarianer",
                             effect: "+20% Angriff gegen Nataren",
                             baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Angriff vs Nataren", prefix: "+",
                             category: self),
                LeftHandTier(level: 2, name: "Horn der Natarianer",
                             effect: "+25% Angriff gegen Nataren",
                             baseValue: 25, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Angriff vs Nataren", prefix: "+",
                             category: self),
                LeftHandTier(level: 3, name: "Riesiges Horn der Natarianer",
                             effect: "+30% Angriff gegen Nataren",
                             baseValue: 30, variantSteps: [2, 1, 0, -1, -2],
                             unit: "% Angriff vs Nataren", prefix: "+",
                             category: self),
            ]
        }
    }
    // swiftlint:enable function_body_length
}

struct LeftHandTier: Identifiable {
    let level: Int
    let name: String
    let effect: String
    let baseValue: Int
    let variantSteps: [Int]    // Absteigend sortiert: best → worst
    let unit: String
    let prefix: String         // "+" fuer positive Werte, "" fuer negative
    let category: LeftHandCategory

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
