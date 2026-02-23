import SwiftUI

// MARK: - Pferde Uebersicht

struct HorsesView: View {

    @Environment(AuthService.self) var authService
    @State private var tierService = ItemTierService.shared

    /// Vom User gewaehlte Stufe (nil = automatisch)
    @State private var selectedTier: Int? = nil

    /// Welches Pferd ist aufgeklappt (Rangliste sichtbar)
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

            // Pferde (nur passende Stufen anzeigen)
            Section {
                ForEach(HorseTier.allTiers(upTo: displayTier)) { tier in
                    HorseTierRow(
                        tier: tier,
                        isExpanded: expandedTierId == tier.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedTierId = expandedTierId == tier.id ? nil : tier.id
                        }
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: "hare.fill")
                        .foregroundStyle(.brown)
                    Text("Reittiere")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .textCase(nil)
            }

            // Hinweise
            Section("Hinweise") {
                HorseNote(icon: "figure.equestrian.sports",
                          text: "Geschwindigkeitsbonus gilt nur mit Pferd beim Helden")
                HorseNote(icon: "person.fill",
                          text: "Bonus gilt nur für den Helden, nicht für Truppen")
                HorseNote(icon: "shield.fill",
                          text: "Held zählt als Kavallerie mit Pferd, als Infanterie ohne")
                HorseNote(icon: "leaf.fill",
                          text: "Gallier: +5 Felder/h Bonus für berittene Helden")
                HorseNote(icon: "paintpalette.fill",
                          text: "Pferdefarbe (weiß/schwarz/braun) hat keinen Einfluss")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pferde")
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

// MARK: - Hinweis-Zeile

private struct HorseNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Stufen-Zeile (antippbar → Rangliste)

private struct HorseTierRow: View {
    let tier: HorseTier
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

                    if tier.hasVariants {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
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
            .onTapGesture {
                if tier.hasVariants { onTap() }
            }

            // Rangliste (aufklappbar, nur wenn Varianten vorhanden)
            if isExpanded && tier.hasVariants {
                HorseRankingList(tier: tier)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Rangliste

private struct HorseRankingList: View {
    let tier: HorseTier

    var body: some View {
        let entries = tier.rankings

        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            ForEach(Array(entries.enumerated()), id: \.offset) { index, ranking in
                HorseRankingRow(rank: index + 1, value: ranking.value, unit: tier.unit, isTop: index == 0)

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct HorseRankingRow: View {
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

struct HorseTier: Identifiable {
    let level: Int
    let name: String
    let effect: String
    let baseValue: Int
    let variantSteps: [Int]    // Absteigend sortiert: best → worst
    let unit: String

    var id: String { "horse-\(level)" }

    /// Stufe 1 hat keine Varianten.
    var hasVariants: Bool { variantSteps.count > 1 }

    var tierColor: Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    /// Rangliste: Basiswert + Variante, absteigend.
    var rankings: [RankingEntry] {
        variantSteps.map { step in
            RankingEntry(value: "\(baseValue + step)")
        }
    }

    // ── Alle Pferde ────────────────────────────────────────

    private static let allTiersList: [HorseTier] = [
        HorseTier(level: 1, name: "Leichtes Reitpferd",
                  effect: "14 Felder/h Heldengeschwindigkeit",
                  baseValue: 14, variantSteps: [0],
                  unit: "Felder/h"),
        HorseTier(level: 2, name: "Edles Vollblut",
                  effect: "17 Felder/h Heldengeschwindigkeit (x1)",
                  baseValue: 17, variantSteps: [2, 1, 0, -1, -2],
                  unit: "Felder/h"),
        HorseTier(level: 3, name: "Streitross",
                  effect: "20 Felder/h Heldengeschwindigkeit (x1)",
                  baseValue: 20, variantSteps: [5, 3, 2, 1, 0],
                  unit: "Felder/h"),
    ]

    static func allTiers(upTo maxLevel: Int) -> [HorseTier] {
        allTiersList.filter { $0.level <= maxLevel }
    }
}
