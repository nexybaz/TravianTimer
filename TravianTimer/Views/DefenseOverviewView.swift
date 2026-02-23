import SwiftUI

// MARK: - Navigation Route

struct DefenseOverviewRoute: Hashable {
    let callId: UUID
}

// MARK: - Deff-Übersicht

struct DefenseOverviewView: View {

    let call: CallItem

    @EnvironmentObject private var store: CallsStore

    @State private var expandedCard: ExpandedCard?

    private enum ExpandedCard {
        case troops
        case players
        case types
    }

    /// Aktuellen Call aus dem Store lesen (reaktiv bei Status-Aenderungen)
    private var liveCall: CallItem {
        store.calls.first(where: { $0.id == call.id }) ?? call
    }

    /// Pledges fuer diesen Call aus dem Store (Supabase-backed)
    /// Discord-Pledges (troop_kind = "unknown") werden hier rausgefiltert,
    /// da sie ueber den "Discord Spieler"-Mechanismus in aggregated angezeigt werden.
    private var pledges: [TroopPledge] {
        (store.pledgesByCall[call.id] ?? []).filter { $0.troopKind != "unknown" }
    }

    /// Aggregierte Truppentypen inkl. virtuellem "Discord Spieler" Eintrag.
    /// Wenn der DB-Wert (cropPledgedTotal) hoeher ist als die Pledge-Summe,
    /// stammt die Differenz aus manuellen Discord-Meldungen (ohne App-Pledge).
    private var aggregated: [AggregatedTroop] {
        var result = DefenseAggregator.aggregate(pledges)

        let pledgeCrop = DefenseAggregator.totalCrop(result)
        let discordExtra = liveCall.cropPledgedTotal - pledgeCrop
        if discordExtra > 0 {
            result.append(AggregatedTroop(
                id: "discord.player",
                troopKind: .discordPlayer,
                totalCount: discordExtra,   // count = Crop-Wert (cropPerHour = 1)
                playerCount: 1,
                totalCrop: discordExtra
            ))
        }

        return result
    }

    private var grandTotal: Int {
        DefenseAggregator.grandTotal(aggregated)
    }

    private var playerCount: Int {
        let appPlayers = DefenseAggregator.uniquePlayerCount(pledges)
        let hasDiscord = aggregated.contains { $0.troopKind == .discordPlayer }
        return hasDiscord ? appPlayers + 1 : appPlayers
    }

    private var totalCrop: Int {
        DefenseAggregator.totalCrop(aggregated)
    }

    private var cropLimit: Int? {
        liveCall.cropLimit
    }

    private var cropRatio: Double {
        guard let limit = cropLimit, limit > 0 else { return 0 }
        return min(1.0, Double(totalCrop) / Double(limit))
    }

    private var isOverLimit: Bool {
        guard let limit = cropLimit else { return false }
        return totalCrop > limit
    }

    /// Truppen nach Volk aggregiert
    private var tribeSummaries: [TribeSummary] {
        // Nur echte Truppen (ohne Discord-Spieler)
        let realTroops = aggregated.filter { $0.troopKind != .discordPlayer }
        let grouped = Dictionary(grouping: realTroops, by: { $0.troopKind.tribe })

        let order = ["romans", "gauls", "teutons"]
        var result = grouped.compactMap { (tribe, troops) -> TribeSummary? in
            let totalUnits = troops.reduce(0) { $0 + $1.totalCount }
            let totalCrop = troops.reduce(0) { $0 + $1.totalCrop }
            let typeCount = troops.count
            let color: Color = switch tribe {
            case "romans": .blue
            case "teutons": .orange
            default: .green
            }
            let uiName: String = switch tribe {
            case "romans": "Römer"
            case "teutons": "Germanen"
            case "gauls": "Gallier"
            default: tribe.capitalized
            }
            let icon: String = switch tribe {
            case "romans": "building.columns.fill"
            case "teutons": "flame.fill"
            case "gauls": "leaf.fill"
            default: "questionmark.circle.fill"
            }
            return TribeSummary(
                tribe: tribe,
                uiName: uiName,
                icon: icon,
                color: color,
                totalUnits: totalUnits,
                totalCrop: totalCrop,
                typeCount: typeCount
            )
        }
        .sorted { (order.firstIndex(of: $0.tribe) ?? 99) < (order.firstIndex(of: $1.tribe) ?? 99) }

        // Discord Spieler als virtuellen Eintrag
        if let discordTroop = aggregated.first(where: { $0.troopKind == .discordPlayer }) {
            result.append(TribeSummary(
                tribe: "discord",
                uiName: "Discord",
                icon: "bubble.left.fill",
                color: .purple,
                totalUnits: 0,
                totalCrop: discordTroop.totalCrop,
                typeCount: 0
            ))
        }

        return result
    }

    /// Spieler-Zusammenfassung: jeder Spieler mit Gesamtcrop und Truppentypen
    private var playerSummaries: [PlayerSummary] {
        let grouped = Dictionary(grouping: pledges, by: \.playerName)
        var result = grouped.map { (name, playerPledges) -> PlayerSummary in
            let crop = playerPledges.compactMap { pledge -> Int? in
                guard let kind = TroopKind(rawValue: pledge.troopKind) else { return nil }
                return pledge.count * kind.cropPerHour
            }.reduce(0, +)
            let troopTypes = Set(playerPledges.compactMap { TroopKind(rawValue: $0.troopKind) })
            let totalUnits = playerPledges.reduce(0) { $0 + $1.count }
            return PlayerSummary(
                name: name,
                totalCrop: crop,
                totalUnits: totalUnits,
                troopTypes: Array(troopTypes).sorted { $0.uiName < $1.uiName }
            )
        }
        .sorted { $0.totalCrop > $1.totalCrop }

        // Discord Spieler als virtuellen Eintrag
        let hasDiscord = aggregated.contains { $0.troopKind == .discordPlayer }
        if hasDiscord, let discordTroop = aggregated.first(where: { $0.troopKind == .discordPlayer }) {
            result.append(PlayerSummary(
                name: "Discord Spieler",
                totalCrop: discordTroop.totalCrop,
                totalUnits: 0,
                troopTypes: [.discordPlayer]
            ))
        }

        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if pledges.isEmpty && liveCall.cropPledgedTotal <= 0 {
                    VStack(spacing: 14) {
                        Spacer().frame(height: 40)

                        Image(systemName: "shield.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))

                        Text("Keine Truppen zugesagt")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Sichere Truppen im Call zu, um die Deff-Übersicht zu sehen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    cropCard

                    statsRow

                    // Aufklappbare Liste unter der Stats-Row
                    switch expandedCard {
                    case .troops:
                        tribesList
                    case .players:
                        playersList
                    case .types:
                        troopsList
                    case .none:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("Deff-Übersicht")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Getreide Card (Hauptelement)

    private var cropCard: some View {
        VStack(spacing: 14) {
            // Getreide-Zahl gross
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(isOverLimit ? .red : .orange)

                Text("\(totalCrop)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOverLimit ? .red : .primary)

                if let limit = cropLimit {
                    Text("/ \(limit)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Getreide/h")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Fortschrittsbalken (nur wenn Obergrenze gesetzt)
            if cropLimit != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(isOverLimit ? Color.red : Color.orange)
                            .frame(width: geo.size.width * cropRatio, height: 12)
                    }
                }
                .frame(height: 12)

                if isOverLimit {
                    Text("Obergrenze um \(totalCrop - (cropLimit ?? 0)) überschritten!")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }

        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Stats Row (tappbare Cards)

    private var statsRow: some View {
        HStack(spacing: 16) {
            statBadge(value: "\(grandTotal)", label: "Truppen", icon: "person.3.fill", card: .troops)
            statBadge(value: "\(playerCount)", label: "Spieler", icon: "person.fill", card: .players)
            statBadge(value: "\(aggregated.count)", label: "Typen", icon: "shield.fill", card: .types)
        }
    }

    private func statBadge(value: String, label: String, icon: String, card: ExpandedCard) -> some View {
        let isActive = expandedCard == card
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isActive ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .orange : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive
                      ? Color.orange.opacity(0.12)
                      : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.orange.opacity(0.4) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                expandedCard = expandedCard == card ? nil : card
            }
        }
    }

    // MARK: - Tribes List (Truppen nach Volk)

    private var tribesList: some View {
        VStack(spacing: 0) {
            ForEach(tribeSummaries, id: \.tribe) { tribe in
                tribeRow(tribe)
                    .padding(.horizontal)
                if tribe.tribe != tribeSummaries.last?.tribe {
                    Divider().padding(.leading, 68)
                }
            }
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func tribeRow(_ tribe: TribeSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tribe.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: tribe.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(tribe.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tribe.uiName)
                    .font(.body)
                    .fontWeight(.semibold)

                if tribe.tribe == "discord" {
                    Text("Manuell via Discord gemeldet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(tribe.typeCount) Typen  \u{2022}  \(tribe.totalUnits) Einheiten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(tribe.totalCrop)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)

                Text("Getreide/h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Troops List (Content unter Stats-Card)

    private var troopsList: some View {
        VStack(spacing: 0) {
            ForEach(aggregated) { troop in
                troopRow(troop)
                    .padding(.horizontal)
                if troop.id != aggregated.last?.id {
                    Divider().padding(.leading, 68)
                }
            }
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Troop Row

    private func troopRow(_ troop: AggregatedTroop) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(troop.troopKind.tribeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: troop.troopKind.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(troop.troopKind.tribeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(troop.troopKind.uiName)
                    .font(.body)
                    .fontWeight(.semibold)

                if troop.troopKind == .discordPlayer {
                    Text("Manuell via Discord gemeldet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(troop.playerCount) Spieler  \u{2022}  \(troop.totalCount) Einheiten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Getreide pro Typ prominent rechts
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(troop.totalCrop)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)

                Text("Getreide/h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Players List (Content unter Stats-Card)

    private var playersList: some View {
        VStack(spacing: 0) {
            ForEach(playerSummaries, id: \.name) { player in
                playerRow(player)
                    .padding(.horizontal)
                if player.name != playerSummaries.last?.name {
                    Divider().padding(.leading, 68)
                }
            }
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Player Row

    private func playerRow(_ player: PlayerSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(player.troopTypes.first == .discordPlayer
                          ? Color.purple.opacity(0.15)
                          : Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: player.troopTypes.first == .discordPlayer
                      ? "bubble.left.fill"
                      : "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(player.troopTypes.first == .discordPlayer
                                    ? .purple : .blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.body)
                    .fontWeight(.semibold)

                if player.troopTypes.first == .discordPlayer {
                    Text("Manuell via Discord gemeldet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(player.troopTypes.map(\.uiName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(player.totalCrop)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)

                if player.totalUnits > 0 {
                    Text("\(player.totalUnits) Einh.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Getreide/h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

}

// MARK: - Helper Models

private struct TribeSummary {
    let tribe: String       // "romans", "gauls", "teutons", "discord"
    let uiName: String      // "Römer", "Gallier", "Germanen", "Discord"
    let icon: String
    let color: Color
    let totalUnits: Int
    let totalCrop: Int
    let typeCount: Int
}

private struct PlayerSummary {
    let name: String
    let totalCrop: Int
    let totalUnits: Int
    let troopTypes: [TroopKind]
}
