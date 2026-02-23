import SwiftUI

// MARK: - Schuhe Uebersicht

struct BootsView: View {

    @EnvironmentObject private var authService: AuthService
    @StateObject private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welcher Schuh ist aufgeklappt (Rangliste sichtbar)
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

            // Schuh-Kategorien (nur passende Stufen anzeigen)
            ForEach(BootsCategory.allCases) { category in
                Section {
                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        BootsTierRow(
                            tier: tier,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    BootsCategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Schuhe")
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

private struct BootsCategoryHeader: View {
    let category: BootsCategory

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

private struct BootsTierRow: View {
    let tier: BootsTier
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
                BootsRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct BootsRankingList: View {
    let tier: BootsTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                BootsRankingRow(rank: index + 1, value: ranking.value, unit: tier.unit, isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct BootsRankingRow: View {
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

enum BootsCategory: String, CaseIterable, Identifiable {
    case mindfulness
    case endurance
    case spurs
    case coward

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mindfulness: return "Schuhe der Achtsamkeit"
        case .endurance:   return "Schuhe der Ausdauer"
        case .spurs:       return "Pferdesporen"
        case .coward:      return "Stiefel des Angsthasen"
        }
    }

    var icon: String {
        switch self {
        case .mindfulness: return "book.fill"
        case .endurance:   return "figure.run"
        case .spurs:       return "hare.fill"
        case .coward:      return "figure.walk.motion"
        }
    }

    var color: Color {
        switch self {
        case .mindfulness: return .purple
        case .endurance:   return .green
        case .spurs:       return .blue
        case .coward:      return .orange
        }
    }

    /// Gibt alle Stufen bis einschliesslich `maxLevel` zurueck.
    func tiers(upTo maxLevel: Int) -> [BootsTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    // swiftlint:disable function_body_length
    private var allTiers: [BootsTier] {
        switch self {

        // ── Schuhe der Achtsamkeit ─────────────────────────────
        case .mindfulness:
            return [
                BootsTier(level: 1, name: "Schuhe der Erkenntnis",
                          effect: "+15% mehr Erfahrung für den Helden",
                          baseValue: 15, variantSteps: [2, 1, 0, -1, -2],
                          unit: "% Erfahrung", prefix: "+",
                          category: self),
                BootsTier(level: 2, name: "Schuhe der Erleuchtung",
                          effect: "+20% mehr Erfahrung für den Helden",
                          baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                          unit: "% Erfahrung", prefix: "+",
                          category: self),
                BootsTier(level: 3, name: "Schuhe der Weisheit",
                          effect: "+25% mehr Erfahrung für den Helden",
                          baseValue: 25, variantSteps: [5, 3, 2, 1, 0],
                          unit: "% Erfahrung", prefix: "+",
                          category: self),
            ]

        // ── Schuhe der Ausdauer ────────────────────────────────
        case .endurance:
            return [
                BootsTier(level: 1, name: "Schuhe des Söldners",
                          effect: "+25% Geschwindigkeit (> 20 Felder)",
                          baseValue: 25, variantSteps: [10, 5, 0, -5, -10],
                          unit: "% Geschwindigkeit", prefix: "+",
                          category: self),
                BootsTier(level: 2, name: "Schuhe des Soldaten",
                          effect: "+50% Geschwindigkeit (> 20 Felder)",
                          baseValue: 50, variantSteps: [10, 5, 0, -5, -10],
                          unit: "% Geschwindigkeit", prefix: "+",
                          category: self),
                BootsTier(level: 3, name: "Schuhe des Anführers",
                          effect: "+75% Geschwindigkeit (> 20 Felder)",
                          baseValue: 75, variantSteps: [25, 15, 10, 5, 0],
                          unit: "% Geschwindigkeit", prefix: "+",
                          category: self),
            ]

        // ── Pferdesporen ───────────────────────────────────────
        case .spurs:
            return [
                BootsTier(level: 1, name: "Kleine Pferdesporen",
                          effect: "+2 Felder/h für berittene Helden",
                          baseValue: 2, variantSteps: [1, 0],
                          unit: "Felder/h", prefix: "+",
                          category: self),
                BootsTier(level: 2, name: "Pferdesporen",
                          effect: "+4 Felder/h für berittene Helden",
                          baseValue: 4, variantSteps: [1, 0],
                          unit: "Felder/h", prefix: "+",
                          category: self),
                BootsTier(level: 3, name: "Große Pferdesporen",
                          effect: "+6 Felder/h für berittene Helden",
                          baseValue: 6, variantSteps: [1, 0],
                          unit: "Felder/h", prefix: "+",
                          category: self),
            ]

        // ── Stiefel des Angsthasen ─────────────────────────────
        case .coward:
            return [
                BootsTier(level: 1, name: "Stiefel des Angsthasen",
                          effect: "200 Truppen weichen Angriff aus (180s)",
                          baseValue: 200, variantSteps: [50, 25, 0, -25, -50],
                          unit: "Truppen", prefix: "+",
                          category: self),
                BootsTier(level: 2, name: "Stiefel des Angsthasen",
                          effect: "1000 Truppen weichen Angriff aus (180s)",
                          baseValue: 1000, variantSteps: [200, 100, 0, -100, -200],
                          unit: "Truppen", prefix: "+",
                          category: self),
                BootsTier(level: 3, name: "Stiefel des Angsthasen",
                          effect: "2000 Truppen weichen Angriff aus (180s)",
                          baseValue: 2000, variantSteps: [500, 250, 0, -250, -500],
                          unit: "Truppen", prefix: "+",
                          category: self),
            ]
        }
    }
    // swiftlint:enable function_body_length
}

struct BootsTier: Identifiable {
    let level: Int
    let name: String
    let effect: String
    let baseValue: Int
    let variantSteps: [Int]    // Absteigend sortiert: best → worst
    let unit: String
    let prefix: String         // "+" fuer positive Werte, "" fuer negative
    let category: BootsCategory

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
