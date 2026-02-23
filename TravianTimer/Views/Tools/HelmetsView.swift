import SwiftUI

// MARK: - Helme Uebersicht

struct HelmetsView: View {

    @EnvironmentObject private var authService: AuthService
    @StateObject private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welcher Helm ist aufgeklappt (Rangliste sichtbar)
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

            // Helm-Kategorien (nur passende Stufen anzeigen)
            ForEach(HelmetCategory.allCases) { category in
                Section {
                    ForEach(category.tiers(upTo: displayTier)) { tier in
                        HelmetTierRow(
                            tier: tier,
                            worldSpeed: tierService.worldSpeed,
                            isExpanded: expandedTierId == tier.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTierId = expandedTierId == tier.id ? nil : tier.id
                            }
                        }
                    }
                } header: {
                    HelmetCategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Helme")
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

// MARK: - Tier Picker

struct TierPicker: View {
    @Binding var selectedTier: Int?
    let autoTier: Int
    let maxTier: Int
    let tier2Date: Date?
    let tier3Date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Stufe", selection: Binding(
                get: { selectedTier ?? 0 },
                set: { selectedTier = $0 == 0 ? nil : $0 }
            )) {
                Text("Auto (\(autoTier))").tag(0)
                Text("Stufe 1").tag(1)
                Text("Stufe 2").tag(2)
                Text("Stufe 3").tag(3)
            }
            .pickerStyle(.segmented)

            if tier2Date != nil || tier3Date != nil {
                HStack(spacing: 12) {
                    if let t2 = tier2Date {
                        TierDateBadge(tier: 2, date: t2, isActive: Date() >= t2)
                    }
                    if let t3 = tier3Date {
                        TierDateBadge(tier: 3, date: t3, isActive: Date() >= t3)
                    }
                }
            } else {
                Text("Keine Tier-Daten für diese Spielwelt hinterlegt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Tier Datum Badge

private struct TierDateBadge: View {
    let tier: Int
    let date: Date
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? tierColor : .gray.opacity(0.4))
                .frame(width: 6, height: 6)
            Text("Stufe \(tier): \(formatted)")
                .font(.caption)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    private var tierColor: Color {
        switch tier {
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    private var formatted: String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Kategorie Header

private struct HelmetCategoryHeader: View {
    let category: HelmetCategory

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

private struct HelmetTierRow: View {
    let tier: HelmetTier
    let worldSpeed: Int
    let isExpanded: Bool
    let onTap: () -> Void

    /// Multiplikator: Kultur-Helme werden mit Spielwelt-Speed multipliziert.
    private var speedMultiplier: Int {
        tier.category == .culture ? worldSpeed : 1
    }

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
                    Text(tier.displayEffect(speed: speedMultiplier))
                        .font(.callout)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Rangliste (aufklappbar)
            if isExpanded {
                RankingList(tier: tier, speedMultiplier: speedMultiplier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct RankingList: View {
    let tier: HelmetTier
    let speedMultiplier: Int

    var body: some View {
        let entries = tier.rankings(speed: speedMultiplier)

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                RankingRow(rank: index + 1, value: ranking.value, unit: tier.displayUnit(speed: speedMultiplier), isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct RankingRow: View {
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

struct RankingEntry {
    let value: String
}

enum HelmetCategory: String, CaseIterable, Identifiable {
    case health
    case culture
    case cavalry
    case infantry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health:    return "Helm der Gesundheit"
        case .culture:   return "Helm der Kultur"
        case .cavalry:   return "Helm der Kavallerie"
        case .infantry:  return "Helm der Infanterie"
        }
    }

    var icon: String {
        switch self {
        case .health:    return "heart.fill"
        case .culture:   return "star.fill"
        case .cavalry:   return "hare.fill"
        case .infantry:  return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .health:    return .red
        case .culture:   return .purple
        case .cavalry:   return .blue
        case .infantry:  return .orange
        }
    }

    /// Gibt alle Stufen bis einschliesslich `maxLevel` zurueck.
    func tiers(upTo maxLevel: Int) -> [HelmetTier] {
        allTiers.filter { $0.level <= maxLevel }
    }

    private var allTiers: [HelmetTier] {
        switch self {
        case .health:
            return [
                HelmetTier(level: 1, name: "Helm der Regeneration",
                           effect: "+10 Gesundheitspunkte / Tag",
                           baseValue: 10, variantSteps: [2, 1, 0, -1, -2],
                           unit: "HP/Tag", prefix: "+",
                           category: self),
                HelmetTier(level: 2, name: "Helm der Gesundheit",
                           effect: "+15 Gesundheitspunkte / Tag",
                           baseValue: 15, variantSteps: [2, 1, 0, -1, -2],
                           unit: "HP/Tag", prefix: "+",
                           category: self),
                HelmetTier(level: 3, name: "Helm der Heilung",
                           effect: "+20 Gesundheitspunkte / Tag",
                           baseValue: 20, variantSteps: [2, 1, 0, -1, -2],
                           unit: "HP/Tag", prefix: "+",
                           category: self),
            ]
        case .culture:
            return [
                HelmetTier(level: 1, name: "Helm des Gladiators",
                           effect: "+50 \u{00D7} Geschwindigkeit KP / Tag",
                           baseValue: 50, variantSteps: [20, 10, 0, -10, -20],
                           unit: "\u{00D7}Geschw. KP/Tag", prefix: "+",
                           category: self),
                HelmetTier(level: 2, name: "Helm des Tribunen",
                           effect: "+200 \u{00D7} Geschwindigkeit KP / Tag",
                           baseValue: 200, variantSteps: [50, 25, 0, -25, -50],
                           unit: "\u{00D7}Geschw. KP/Tag", prefix: "+",
                           category: self),
                HelmetTier(level: 3, name: "Helm des Konsuls",
                           effect: "+800 \u{00D7} Geschwindigkeit KP / Tag",
                           baseValue: 800, variantSteps: [200, 100, 0, -100, -200],
                           unit: "\u{00D7}Geschw. KP/Tag", prefix: "+",
                           category: self),
            ]
        case .cavalry:
            return [
                HelmetTier(level: 1, name: "Helm der Reiterei",
                           effect: "-10% Trainingszeit im Stall",
                           baseValue: -10, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Stall", prefix: "",
                           category: self),
                HelmetTier(level: 2, name: "Helm der Kavallerie",
                           effect: "-15% Trainingszeit im Stall",
                           baseValue: -15, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Stall", prefix: "",
                           category: self),
                HelmetTier(level: 3, name: "Helm der schweren Reiterei",
                           effect: "-20% Trainingszeit im Stall",
                           baseValue: -20, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Stall", prefix: "",
                           category: self),
            ]
        case .infantry:
            return [
                HelmetTier(level: 1, name: "Helm des Söldners",
                           effect: "-10% Trainingszeit in der Kaserne",
                           baseValue: -10, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Kaserne", prefix: "",
                           category: self),
                HelmetTier(level: 2, name: "Helm des Kämpfers",
                           effect: "-15% Trainingszeit in der Kaserne",
                           baseValue: -15, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Kaserne", prefix: "",
                           category: self),
                HelmetTier(level: 3, name: "Helm des Anführers",
                           effect: "-20% Trainingszeit in der Kaserne",
                           baseValue: -20, variantSteps: [-2, -1, 0, 1, 2],
                           unit: "% Trainingszeit Kaserne", prefix: "",
                           category: self),
            ]
        }
    }
}

struct HelmetTier: Identifiable {
    let level: Int
    let name: String
    let effect: String
    let baseValue: Int
    let variantSteps: [Int]    // Absteigend sortiert: best → worst
    let unit: String
    let prefix: String         // "+" fuer positive Werte, "" fuer negative
    let category: HelmetCategory

    var id: String { "\(category.rawValue)-\(level)" }

    var tierColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    /// Effekt-Text mit Speed-Multiplikator (fuer Kultur-Helme).
    func displayEffect(speed: Int) -> String {
        guard category == .culture else { return effect }
        let multiplied = baseValue * speed
        if speed > 1 {
            return "+\(multiplied) KP / Tag (x\(speed))"
        }
        return "+\(multiplied) KP / Tag"
    }

    /// Einheit-Text mit optionalem Speed-Multiplikator.
    func displayUnit(speed: Int) -> String {
        guard category == .culture else { return unit }
        if speed > 1 {
            return "KP/Tag (x\(speed))"
        }
        return "KP/Tag"
    }

    /// Rangliste: Basiswert + Variante, absteigend von gut zu schlecht.
    /// Bei negativen Werten (Kavallerie/Infanterie): kleiner = besser.
    /// Kultur-Helme: Werte werden mit Speed multipliziert.
    func rankings(speed: Int = 1) -> [RankingEntry] {
        let multiplier = category == .culture ? speed : 1
        let values = variantSteps.map { (baseValue + $0) * multiplier }
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
