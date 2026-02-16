import Foundation

/// Aggregierter Truppentyp über alle Spieler hinweg.
struct AggregatedTroop: Identifiable, Hashable {
    let id: String               // TroopKind.rawValue
    let troopKind: TroopKind
    let totalCount: Int
    let playerCount: Int         // Wie viele verschiedene Spieler diesen Typ melden
    let totalCrop: Int           // Gesamtgetreideverbrauch/h für diesen Typ
}

/// Stateless Aggregationslogik für Truppenmeldungen.
enum DefenseAggregator {

    /// Gruppiert Pledges nach Truppentyp, sortiert nach Anzahl absteigend.
    static func aggregate(_ pledges: [TroopPledge]) -> [AggregatedTroop] {
        let grouped = Dictionary(grouping: pledges, by: \.troopKind)

        return grouped.compactMap { (rawKey, items) -> AggregatedTroop? in
            guard let kind = TroopKind(rawValue: rawKey) else { return nil }
            let total = items.reduce(0) { $0 + $1.count }
            let uniquePlayers = Set(items.map(\.playerName)).count
            let crop = total * kind.cropPerHour
            return AggregatedTroop(
                id: rawKey,
                troopKind: kind,
                totalCount: total,
                playerCount: uniquePlayers,
                totalCrop: crop
            )
        }
        .sorted { $0.totalCount > $1.totalCount }
    }

    /// Gesamtzahl aller Truppen.
    static func grandTotal(_ aggregated: [AggregatedTroop]) -> Int {
        aggregated.reduce(0) { $0 + $1.totalCount }
    }

    /// Anzahl verschiedener Spieler über alle Pledges.
    static func uniquePlayerCount(_ pledges: [TroopPledge]) -> Int {
        Set(pledges.map(\.playerName)).count
    }

    /// Gesamtgetreideverbrauch/h aller aggregierten Truppen.
    static func totalCrop(_ aggregated: [AggregatedTroop]) -> Int {
        aggregated.reduce(0) { $0 + $1.totalCrop }
    }
}
