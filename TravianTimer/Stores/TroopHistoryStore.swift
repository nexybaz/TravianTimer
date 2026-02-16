import Foundation
import Combine

// MARK: - Troop History Store

final class TroopHistoryStore: ObservableObject {

    static let shared = TroopHistoryStore()

    @Published var snapshots: [TroopSnapshot] = [] {
        didSet { save() }
    }

    private let key = "troopHistoryV1"

    private init() {
        load()
    }

    // MARK: - Record

    /// Speichert einen Snapshot pro Dorf mit dem aktuellen Zeitstempel.
    func recordSnapshot(villages: [VillageProfile]) {
        let now = Date()
        let newSnapshots = villages.compactMap { v -> TroopSnapshot? in
            // Nur Dörfer mit Truppen erfassen
            let total = v.troopCounts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return TroopSnapshot(
                date: now,
                villageName: v.name,
                villageX: v.x,
                villageY: v.y,
                troopCounts: v.troopCounts
            )
        }
        guard !newSnapshots.isEmpty else { return }
        snapshots.append(contentsOf: newSnapshots)
    }

    // MARK: - Aggregation

    struct DateTotal: Identifiable {
        let id = UUID()
        let date: Date
        let totalTroops: Int
        let totalCrop: Int
        let offTroops: Int
        let deffTroops: Int
    }

    /// Gruppiert Snapshots nach Zeitstempel und summiert Truppen + Getreide + Off/Deff.
    func totalsByDate() -> [DateTotal] {
        // Snapshots sind pro Dorf gespeichert — gleicher Zeitstempel = gleicher Import.
        // Gruppiere nach Sekunden-genauem Datum.
        var grouped: [TimeInterval: (troops: Int, crop: Int, off: Int, deff: Int, date: Date)] = [:]

        for snap in snapshots {
            let key = snap.date.timeIntervalSince1970.rounded()
            let existing = grouped[key] ?? (troops: 0, crop: 0, off: 0, deff: 0, date: snap.date)

            var troops = 0
            var crop = 0
            var off = 0
            var deff = 0
            for (rawValue, count) in snap.troopCounts where count > 0 {
                troops += count
                if let kind = TroopKind(rawValue: rawValue) {
                    crop += count * kind.cropPerHour
                    if kind.isOffensive { off += count }
                    if kind.isDefensive { deff += count }
                }
            }

            grouped[key] = (
                troops: existing.troops + troops,
                crop: existing.crop + crop,
                off: existing.off + off,
                deff: existing.deff + deff,
                date: existing.date
            )
        }

        return grouped.values
            .map { DateTotal(date: $0.date, totalTroops: $0.troops, totalCrop: $0.crop, offTroops: $0.off, deffTroops: $0.deff) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([TroopSnapshot].self, from: data) else { return }
        snapshots = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func clearHistory() {
        snapshots = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
