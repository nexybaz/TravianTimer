import Foundation

// MARK: - Player Profile (Local + Supabase)

struct VillageProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var x: Int
    var y: Int

    // Option A: default leer. Nur ausgewählte Truppen werden berücksichtigt.
    var allowedTroops: [String] = []

    // Exact troop counts per troop key (TroopKind.rawValue). Filled by the troop overview import.
    // Presence filtering in the app still uses `allowedTroops`.
    var troopCounts: [String: Int] = [:]

    // Supabase-spezifische Felder (optional, da bei rein lokalen Villages noch nicht vorhanden)
    var supabaseId: UUID?           // Die DB-UUID (villages.id), getrennt von der lokalen SwiftUI `id`
    var travianVillageId: Int?      // Fuer Merge/Upsert mit Travian-API-Daten
    var population: Int?            // Aus Travian-API
    var isCity: Bool = false        // Aus Travian-API

    // Ressourcen-Produktion pro Stunde (via Clipboard-Parser)
    var productionWood: Int?
    var productionClay: Int?
    var productionIron: Int?
    var productionCrop: Int?        // kann negativ sein

    // Custom Decoder: Damit alte UserDefaults-Daten (ohne die neuen Felder) weiterhin geladen werden koennen.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        allowedTroops = try container.decodeIfPresent([String].self, forKey: .allowedTroops) ?? []
        troopCounts = try container.decodeIfPresent([String: Int].self, forKey: .troopCounts) ?? [:]
        supabaseId = try container.decodeIfPresent(UUID.self, forKey: .supabaseId)
        travianVillageId = try container.decodeIfPresent(Int.self, forKey: .travianVillageId)
        population = try container.decodeIfPresent(Int.self, forKey: .population)
        isCity = try container.decodeIfPresent(Bool.self, forKey: .isCity) ?? false
        productionWood = try container.decodeIfPresent(Int.self, forKey: .productionWood)
        productionClay = try container.decodeIfPresent(Int.self, forKey: .productionClay)
        productionIron = try container.decodeIfPresent(Int.self, forKey: .productionIron)
        productionCrop = try container.decodeIfPresent(Int.self, forKey: .productionCrop)
    }

    // Memberwise init (fuer Code-Nutzung)
    init(id: UUID = UUID(), name: String, x: Int, y: Int,
         allowedTroops: [String] = [], troopCounts: [String: Int] = [:],
         supabaseId: UUID? = nil, travianVillageId: Int? = nil,
         population: Int? = nil, isCity: Bool = false,
         productionWood: Int? = nil, productionClay: Int? = nil,
         productionIron: Int? = nil, productionCrop: Int? = nil) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.allowedTroops = allowedTroops
        self.troopCounts = troopCounts
        self.supabaseId = supabaseId
        self.travianVillageId = travianVillageId
        self.population = population
        self.isCity = isCity
        self.productionWood = productionWood
        self.productionClay = productionClay
        self.productionIron = productionIron
        self.productionCrop = productionCrop
    }
}

// MARK: - Supabase Village (DB-Antwort / SELECT)

/// Codable Struct fuer das Lesen aus der Supabase `villages`-Tabelle.
struct SupabaseVillage: Codable {
    let id: UUID?
    let userId: String?
    let name: String
    let x: Int
    let y: Int
    let allowedTroops: [String]?
    let troopCounts: [String: Int]?
    let travianVillageId: Int?
    let population: Int?
    let isCity: Bool?
    let updatedAt: String?
    let productionWood: Int?
    let productionClay: Int?
    let productionIron: Int?
    let productionCrop: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case name
        case x
        case y
        case allowedTroops   = "allowed_troops"
        case troopCounts     = "troop_counts"
        case travianVillageId = "travian_village_id"
        case population
        case isCity          = "is_city"
        case updatedAt       = "updated_at"
        case productionWood  = "production_wood"
        case productionClay  = "production_clay"
        case productionIron  = "production_iron"
        case productionCrop  = "production_crop"
    }
}

// MARK: - Supabase Village Insert (ohne id/updated_at — DB generiert diese)

/// Codable Struct fuer INSERT in die Supabase `villages`-Tabelle.
/// Laesst `id` und `updated_at` weg, damit die DB die Defaults nutzt.
struct SupabaseVillageInsert: Codable {
    let userId: String
    let name: String
    let x: Int
    let y: Int
    let allowedTroops: [String]
    let troopCounts: [String: Int]
    let travianVillageId: Int?
    let population: Int?
    let isCity: Bool
    let productionWood: Int?
    let productionClay: Int?
    let productionIron: Int?
    let productionCrop: Int?

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case name
        case x
        case y
        case allowedTroops   = "allowed_troops"
        case troopCounts     = "troop_counts"
        case travianVillageId = "travian_village_id"
        case population
        case isCity          = "is_city"
        case productionWood  = "production_wood"
        case productionClay  = "production_clay"
        case productionIron  = "production_iron"
        case productionCrop  = "production_crop"
    }
}

// MARK: - Supabase Village Update (nur App-gesteuerte Felder)

/// Codable Struct fuer UPDATE der App-gesteuerten Felder.
/// Ueberschreibt nicht die von Edge Functions geschriebenen Felder (population, is_city, travian_village_id).
struct SupabaseVillageUpdate: Codable {
    let name: String
    let x: Int
    let y: Int
    let allowedTroops: [String]
    let troopCounts: [String: Int]
    let productionWood: Int?
    let productionClay: Int?
    let productionIron: Int?
    let productionCrop: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case x
        case y
        case allowedTroops   = "allowed_troops"
        case troopCounts     = "troop_counts"
        case productionWood  = "production_wood"
        case productionClay  = "production_clay"
        case productionIron  = "production_iron"
        case productionCrop  = "production_crop"
    }
}

// MARK: - Konvertierungen

extension VillageProfile {

    /// Erstellt ein VillageProfile aus einem SupabaseVillage (DB → App)
    init(from sv: SupabaseVillage) {
        self.init(
            name: sv.name,
            x: sv.x,
            y: sv.y,
            allowedTroops: sv.allowedTroops ?? [],
            troopCounts: sv.troopCounts ?? [:],
            supabaseId: sv.id,
            travianVillageId: sv.travianVillageId,
            population: sv.population,
            isCity: sv.isCity ?? false,
            productionWood: sv.productionWood,
            productionClay: sv.productionClay,
            productionIron: sv.productionIron,
            productionCrop: sv.productionCrop
        )
    }

    /// Konvertiert zu SupabaseVillageInsert fuer neue Villages (App → DB INSERT)
    func toInsert(userId: String) -> SupabaseVillageInsert {
        SupabaseVillageInsert(
            userId: userId,
            name: name,
            x: x,
            y: y,
            allowedTroops: allowedTroops,
            troopCounts: troopCounts,
            travianVillageId: travianVillageId,
            population: population,
            isCity: isCity,
            productionWood: productionWood,
            productionClay: productionClay,
            productionIron: productionIron,
            productionCrop: productionCrop
        )
    }

    /// Konvertiert zu SupabaseVillageUpdate fuer bestehende Villages (App → DB UPDATE)
    func toUpdate() -> SupabaseVillageUpdate {
        SupabaseVillageUpdate(
            name: name,
            x: x,
            y: y,
            allowedTroops: allowedTroops,
            troopCounts: troopCounts,
            productionWood: productionWood,
            productionClay: productionClay,
            productionIron: productionIron,
            productionCrop: productionCrop
        )
    }
}
