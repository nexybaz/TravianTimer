import Foundation

// MARK: - Oasen-Bonus

struct OasisBonus: Codable, Hashable {
    var woodPercent: Int = 0   // 0, 25 oder 50
    var clayPercent: Int = 0
    var ironPercent: Int = 0
    var cropPercent: Int = 0

    var isEmpty: Bool {
        woodPercent == 0 && clayPercent == 0 && ironPercent == 0 && cropPercent == 0
    }

    func percent(for type: ResourceFieldType) -> Int {
        switch type {
        case .wood: return woodPercent
        case .clay: return clayPercent
        case .iron: return ironPercent
        case .crop: return cropPercent
        }
    }
}

// MARK: - Rechner-Konfiguration (Eingabe)

struct UpgradeCalculatorConfig: Codable, Hashable {

    var villageType: VillageResourceType = .type4446
    var resourceFieldLevels: [ResourceFieldSlot]

    // Veredelungsgebäude-Stufen (0 = nicht gebaut)
    var sawmillLevel: Int = 0         // Sägewerk (id: 5)
    var brickyardLevel: Int = 0       // Lehmbrennerei (id: 6)
    var ironFoundryLevel: Int = 0     // Eisenschmelze (id: 7)
    var grainMillLevel: Int = 0       // Getreidemühle (id: 8)
    var bakeryLevel: Int = 0          // Bäckerei (id: 9)

    // Oasen-Bonus (Summe aller Oasen pro Ressource)
    var oasisBonus: OasisBonus = OasisBonus()

    // Optionen
    var goldBoost: Bool = false       // +25% Gold-Club Produktionsbonus
    var maxSteps: Int = 50            // Anzahl Schritte berechnen
    var skipWCIBoosters: Bool = false  // Holz/Lehm/Eisen-Booster ignorieren

    // Erstellt Konfiguration aus VillagePlan
    static func from(plan: VillagePlan) -> UpgradeCalculatorConfig {
        UpgradeCalculatorConfig(
            villageType: plan.villageType,
            resourceFieldLevels: plan.resourceFields
        )
    }

    // Standard-Konfiguration für einen Dorf-Typ
    static func defaultConfig(for type: VillageResourceType = .type4446) -> UpgradeCalculatorConfig {
        UpgradeCalculatorConfig(
            villageType: type,
            resourceFieldLevels: type.generateFields()
        )
    }
}

// MARK: - Upgrade-Typ

enum UpgradeType: Codable, Hashable {
    case resourceField(fieldIndex: Int, resourceType: ResourceFieldType)
    case booster(buildingId: Int)

    var isResourceField: Bool {
        if case .resourceField = self { return true }
        return false
    }
}

// MARK: - Upgrade-Schritt (Ergebnis)

struct UpgradeStep: Identifiable, Hashable {

    let id: Int                        // Schrittnummer (1-basiert)
    let upgradeType: UpgradeType
    let buildingName: String
    let buildingIcon: String           // SF Symbol
    let fromLevel: Int
    let toLevel: Int

    // Kosten
    let woodCost: Int
    let clayCost: Int
    let ironCost: Int
    let cropCost: Int
    let baseTimeSec: Int
    let pop: Int

    var totalCost: Int { woodCost + clayCost + ironCost + cropCost }

    // Produktionsänderung
    let productionDelta: Double        // Gesamtzuwachs/h über alle Typen
    let efficiency: Double             // productionDelta / totalCost

    // Kumulativ nach diesem Schritt
    let cumulativeWoodProd: Double
    let cumulativeClayProd: Double
    let cumulativeIronProd: Double
    let cumulativeCropProd: Double

    var cumulativeTotalProd: Double {
        cumulativeWoodProd + cumulativeClayProd + cumulativeIronProd + cumulativeCropProd
    }

    // Kumulative Gesamtkosten
    let cumulativeTotalCost: Int

    // Codable/Hashable Konformität
    static func == (lhs: UpgradeStep, rhs: UpgradeStep) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
