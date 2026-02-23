import Foundation
import Supabase

// MARK: - Item Tier Service

/// Ermittelt die aktuelle Gegenstandsstufe (Tier 1/2/3) basierend auf
/// den Tier-Daten der Spielwelt aus der gameworlds-Tabelle.
@MainActor
final class ItemTierService: ObservableObject {

    static let shared = ItemTierService()

    @Published var currentTier: Int = 1
    @Published var maxTier: Int = 1
    @Published var tier2Date: Date?
    @Published var tier3Date: Date?
    @Published var worldSpeed: Int = 1
    @Published var isLoaded: Bool = false

    private var client: SupabaseClient { SupabaseManager.client }

    private init() {}

    // MARK: - Tier-Daten laden

    /// Laedt die Tier-Daten fuer eine Spielwelt und berechnet die aktuelle Stufe.
    func loadTierDates(worldId: String) async {
        struct GameworldTierRow: Decodable {
            let start_date: String?
            let tier2_date: String?
            let tier3_date: String?
            let speed: Int?
        }

        do {
            let row: GameworldTierRow = try await client
                .from("gameworlds")
                .select("start_date, tier2_date, tier3_date, speed")
                .eq("world_id", value: worldId)
                .single()
                .execute()
                .value

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Europe/Berlin")

            tier2Date = row.tier2_date.flatMap { formatter.date(from: $0) }
            tier3Date = row.tier3_date.flatMap { formatter.date(from: $0) }
            worldSpeed = row.speed ?? 1

            recalculateTier()
            isLoaded = true

        } catch {
            print("[ItemTierService] Fehler beim Laden der Tier-Daten: \(error.localizedDescription)")
            // Fallback: Stufe 1, keine Daten verfuegbar
            currentTier = 1
            maxTier = 1
            isLoaded = true
        }
    }

    // MARK: - Berechnung

    /// Berechnet die aktuelle Stufe basierend auf dem heutigen Datum.
    func recalculateTier() {
        let today = Date()

        if let t3 = tier3Date, today >= t3 {
            currentTier = 3
            maxTier = 3
        } else if let t2 = tier2Date, today >= t2 {
            currentTier = 2
            maxTier = tier3Date != nil ? 3 : 2
        } else {
            currentTier = 1
            if tier3Date != nil {
                maxTier = 3
            } else if tier2Date != nil {
                maxTier = 2
            } else {
                maxTier = 1
            }
        }
    }
}
