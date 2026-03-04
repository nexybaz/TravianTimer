import Foundation
import SwiftUI

// MARK: - Resource Cost

struct ResourceCost: Codable, Hashable {
    let wood: Int
    let clay: Int
    let iron: Int
    let crop: Int
    var total: Int { wood + clay + iron + crop }
}

// MARK: - Village Plan

struct VillagePlan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var villageId: UUID
    var name: String
    var slots: [PlanSlot]
    var villageType: VillageResourceType = .type4446
    var resourceFields: [ResourceFieldSlot]
    var createdAt: Date = Date()
    var populationBuildPlan: PopBuildPlan?

    /// Erstellt einen leeren Plan mit 23 Gebäude-Slots + 18 Rohstofffeldern:
    /// - Slots 1-5: Innerer Ring (Slot 2 = Rally Point Position)
    /// - Slots 6-21: Äusserer Ring (4 Gruppen × 4, getrennt durch Wege)
    /// - Slots 22-23: Freischaltbare Bauslot-Karten
    static func empty(villageId: UUID, name: String = "Neuer Plan") -> VillagePlan {
        let type = VillageResourceType.type4446
        return VillagePlan(
            villageId: villageId,
            name: name,
            slots: (1...23).map { PlanSlot(slotNumber: $0) },
            villageType: type,
            resourceFields: type.generateFields()
        )
    }

    /// Berechnet die Gesamtproduktion pro Stunde für jeden Rohstofftyp
    var totalProduction: (wood: Int, clay: Int, iron: Int, crop: Int) {
        var wood = 0, clay = 0, iron = 0, crop = 0
        for field in resourceFields {
            let prod = ResourceFieldType.production(at: field.level)
            switch field.resourceType {
            case .wood: wood += prod
            case .clay: clay += prod
            case .iron: iron += prod
            case .crop: crop += prod
            }
        }
        return (wood, clay, iron, crop)
    }

    /// Gesamtproduktion aller Rohstofffelder kombiniert
    var totalProductionSum: Int {
        let p = totalProduction
        return p.wood + p.clay + p.iron + p.crop
    }

    /// Prüft ob mindestens ein Rohstofffeld eine Stufe gesetzt hat
    var hasAnyResourceLevel: Bool {
        resourceFields.contains { $0.level > 0 }
    }

    /// Generiert Rohstofffelder neu wenn der Dorf-Typ geändert wird (behält Level bei wo möglich)
    mutating func changeVillageType(to newType: VillageResourceType) {
        let oldFields = resourceFields
        villageType = newType
        let newFields = newType.generateFields()

        // Versuche Levels zu übertragen: für jeden Typ die Level der gleichen Felder übernehmen
        var oldLevelsByType: [ResourceFieldType: [Int]] = [:]
        for field in oldFields where field.level > 0 {
            oldLevelsByType[field.resourceType, default: []].append(field.level)
        }

        resourceFields = newFields.map { field in
            var f = field
            if var levels = oldLevelsByType[field.resourceType], !levels.isEmpty {
                f.level = levels.removeFirst()
                oldLevelsByType[field.resourceType] = levels
            }
            return f
        }
    }
}

// MARK: - Plan Slot (Gebäude)

struct PlanSlot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var slotNumber: Int
    var buildingId: Int?
    var level: Int = 0

    /// Slot 2 = Rally Point Position (nur Versammlungsplatz oder leer)
    var isRallyPointSlot: Bool { slotNumber == 2 }
    /// Slots 22-23 = Freischaltbare Bonus-Slots (Bauslot-Karten)
    var isUnlockableSlot: Bool { slotNumber > 21 }
    /// Slots 1-5 = Innerer Ring
    var isInnerRing: Bool { slotNumber >= 1 && slotNumber <= 5 }
    /// Slots 6-21 = Äusserer Ring
    var isOuterRing: Bool { slotNumber >= 6 && slotNumber <= 21 }

    var isEmpty: Bool { buildingId == nil }
}

// MARK: - Resource Field Slot (Rohstofffeld)

struct ResourceFieldSlot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fieldNumber: Int           // 1-18
    var resourceType: ResourceFieldType
    var level: Int = 0             // 0 = nicht gesetzt, 1-20
}

// MARK: - Resource Field Type

enum ResourceFieldType: String, Codable, CaseIterable, Identifiable {
    case wood   // Holzfäller
    case clay   // Lehmgrube
    case iron   // Eisenmine
    case crop   // Getreidefeld

    var id: String { rawValue }

    var name: String {
        switch self {
        case .wood: return "Holzfäller"
        case .clay: return "Lehmgrube"
        case .iron: return "Eisenmine"
        case .crop: return "Getreidefeld"
        }
    }

    var shortName: String {
        switch self {
        case .wood: return "Holz"
        case .clay: return "Lehm"
        case .iron: return "Eisen"
        case .crop: return "Getreide"
        }
    }

    var icon: String {
        switch self {
        case .wood: return "tree.fill"
        case .clay: return "mountain.2.fill"
        case .iron: return "hammer.fill"
        case .crop: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .wood: return .green
        case .clay: return .orange
        case .iron: return .gray
        case .crop: return .yellow
        }
    }

    var emoji: String {
        switch self {
        case .wood: return "🪵"
        case .clay: return "🧱"
        case .iron: return "⚙️"
        case .crop: return "🌾"
        }
    }

    /// Produktion pro Stunde je Stufe (1-20). Index 0 = Stufe 1, Index 19 = Stufe 20.
    /// Identisch für alle 4 Rohstofftypen.
    static let productionPerLevel: [Int] = [
        5, 9, 15, 22, 33, 50, 70, 100, 145, 200,
        280, 375, 495, 635, 800, 1000, 1300, 1600, 2000, 2500
    ]

    /// Gibt die Produktion/h für eine bestimmte Stufe zurück (0 = keine Produktion)
    static func production(at level: Int) -> Int {
        guard level >= 1 && level <= productionPerLevel.count else { return 0 }
        return productionPerLevel[level - 1]
    }

    /// Bevölkerung (Gesamtbevölkerung) je Stufe (1-20) — unterschiedlich pro Rohstofftyp.
    /// Quelle: https://support.kingdoms.com
    var populationPerLevel: [Int] {
        switch self {
        case .wood:
            return [2, 3, 3, 4, 5, 6, 8, 10, 12, 16, 18, 20, 22, 24, 26, 29, 32, 35, 38, 41]
        case .clay:
            return [2, 2, 3, 4, 5, 6, 8, 12, 14, 16, 18, 20, 22, 24, 26, 29, 32, 35, 38, 40]
        case .iron:
            return [3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51]
        case .crop:
            return [0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20]
        }
    }

    /// Gibt die Bevölkerung für eine bestimmte Stufe zurück (0 = keine Bevölkerung)
    func population(at level: Int) -> Int {
        let levels = populationPerLevel
        guard level >= 1 && level <= levels.count else { return 0 }
        return levels[level - 1]
    }

    /// Kulturpunkte je Stufe (1-20). Holz/Lehm/Getreide identisch, Eisen höher.
    var culturePointsPerLevel: [Int] {
        switch self {
        case .wood, .clay, .crop:
            return [1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 2, 2, 2, 2, 3, 4, 5, 5, 6]
        case .iron:
            return [1, 1, 2, 2, 2, 3, 4, 4, 5, 6, 7, 9, 11, 13, 15, 18, 22, 27, 32, 38]
        }
    }

    /// Gibt die Kulturpunkte für eine bestimmte Stufe zurück
    func culturePoints(at level: Int) -> Int {
        let levels = culturePointsPerLevel
        guard level >= 1 && level <= levels.count else { return 0 }
        return levels[level - 1]
    }

    /// Basis-Bauzeit in Sekunden je Stufe (1-20) — unterschiedlich pro Rohstofftyp.
    var baseTimePerLevel: [Int] {
        switch self {
        case .wood:
            return [10, 55, 180, 720, 1440, 2880, 4320, 8700, 12900, 19500,
                    25800, 32400, 38700, 47400, 53700, 64500, 86100, 107700, 129300, 172200]
        case .clay:
            return [10, 50, 165, 660, 1320, 2640, 3960, 7800, 11700, 17700,
                    23700, 29700, 35400, 43500, 49200, 59100, 78900, 98700, 118500, 157800]
        case .iron:
            return [15, 65, 225, 900, 1800, 3600, 5400, 10800, 16200, 24300,
                    32400, 40500, 48300, 59100, 67200, 80700, 107700, 134400, 161400, 215400]
        case .crop:
            return [10, 45, 150, 600, 1200, 2400, 3600, 7200, 10800, 16200,
                    21600, 27000, 32400, 39600, 44700, 53700, 71700, 89700, 107700, 143400]
        }
    }

    /// Gibt die Basis-Bauzeit in Sekunden für eine bestimmte Stufe zurück
    func baseTime(at level: Int) -> Int {
        let levels = baseTimePerLevel
        guard level >= 1 && level <= levels.count else { return 0 }
        return levels[level - 1]
    }

    /// Baukosten (Holz, Lehm, Eisen, Getreide) je Stufe (1-20) — unterschiedlich pro Rohstofftyp.
    /// Quelle: https://support.kingdoms.com
    var resourceCostsPerLevel: [ResourceCost] {
        switch self {
        case .wood:
            return [
                ResourceCost(wood: 40, clay: 100, iron: 50, crop: 60),
                ResourceCost(wood: 65, clay: 165, iron: 85, crop: 100),
                ResourceCost(wood: 110, clay: 280, iron: 140, crop: 165),
                ResourceCost(wood: 185, clay: 465, iron: 235, crop: 280),
                ResourceCost(wood: 310, clay: 780, iron: 390, crop: 465),
                ResourceCost(wood: 520, clay: 1300, iron: 650, crop: 780),
                ResourceCost(wood: 870, clay: 2170, iron: 1085, crop: 1300),
                ResourceCost(wood: 1450, clay: 3625, iron: 1810, crop: 2175),
                ResourceCost(wood: 2420, clay: 6050, iron: 3025, crop: 3630),
                ResourceCost(wood: 4040, clay: 10105, iron: 5050, crop: 6060),
                ResourceCost(wood: 6750, clay: 16870, iron: 8435, crop: 10125),
                ResourceCost(wood: 11270, clay: 28175, iron: 14090, crop: 16905),
                ResourceCost(wood: 18820, clay: 47055, iron: 23525, crop: 28230),
                ResourceCost(wood: 31430, clay: 78580, iron: 39290, crop: 47150),
                ResourceCost(wood: 52490, clay: 131230, iron: 65615, crop: 78740),
                ResourceCost(wood: 87660, clay: 219155, iron: 109575, crop: 131490),
                ResourceCost(wood: 146395, clay: 365985, iron: 182995, crop: 219590),
                ResourceCost(wood: 244480, clay: 611195, iron: 305600, crop: 366715),
                ResourceCost(wood: 408280, clay: 1020695, iron: 510350, crop: 612420),
                ResourceCost(wood: 681825, clay: 1704565, iron: 852280, crop: 1022740),
            ]
        case .clay:
            return [
                ResourceCost(wood: 80, clay: 40, iron: 80, crop: 50),
                ResourceCost(wood: 135, clay: 65, iron: 135, crop: 85),
                ResourceCost(wood: 225, clay: 110, iron: 225, crop: 140),
                ResourceCost(wood: 375, clay: 185, iron: 375, crop: 235),
                ResourceCost(wood: 620, clay: 310, iron: 620, crop: 390),
                ResourceCost(wood: 1040, clay: 520, iron: 1040, crop: 650),
                ResourceCost(wood: 1735, clay: 870, iron: 1735, crop: 1085),
                ResourceCost(wood: 2900, clay: 1450, iron: 2900, crop: 1810),
                ResourceCost(wood: 4840, clay: 2420, iron: 4840, crop: 3025),
                ResourceCost(wood: 8080, clay: 4040, iron: 8080, crop: 5050),
                ResourceCost(wood: 13500, clay: 6750, iron: 13500, crop: 8435),
                ResourceCost(wood: 22540, clay: 11270, iron: 22540, crop: 14090),
                ResourceCost(wood: 37645, clay: 18820, iron: 37645, crop: 23525),
                ResourceCost(wood: 62865, clay: 31430, iron: 62865, crop: 39290),
                ResourceCost(wood: 104985, clay: 52490, iron: 104985, crop: 65615),
                ResourceCost(wood: 175320, clay: 87660, iron: 175320, crop: 109575),
                ResourceCost(wood: 292790, clay: 146395, iron: 292790, crop: 182995),
                ResourceCost(wood: 488955, clay: 244480, iron: 488955, crop: 305600),
                ResourceCost(wood: 816555, clay: 408280, iron: 816555, crop: 510350),
                ResourceCost(wood: 1363650, clay: 681825, iron: 1363650, crop: 852280),
            ]
        case .iron:
            return [
                ResourceCost(wood: 100, clay: 80, iron: 30, crop: 60),
                ResourceCost(wood: 165, clay: 135, iron: 50, crop: 100),
                ResourceCost(wood: 280, clay: 225, iron: 85, crop: 165),
                ResourceCost(wood: 465, clay: 375, iron: 140, crop: 280),
                ResourceCost(wood: 780, clay: 620, iron: 235, crop: 465),
                ResourceCost(wood: 1300, clay: 1040, iron: 390, crop: 780),
                ResourceCost(wood: 2170, clay: 1735, iron: 650, crop: 1300),
                ResourceCost(wood: 3625, clay: 2900, iron: 1085, crop: 2175),
                ResourceCost(wood: 6050, clay: 4840, iron: 1815, crop: 3630),
                ResourceCost(wood: 10105, clay: 8080, iron: 3030, crop: 6060),
                ResourceCost(wood: 16870, clay: 13500, iron: 5060, crop: 10125),
                ResourceCost(wood: 28175, clay: 22540, iron: 8455, crop: 16905),
                ResourceCost(wood: 47055, clay: 37645, iron: 14115, crop: 28230),
                ResourceCost(wood: 78580, clay: 62865, iron: 23575, crop: 47150),
                ResourceCost(wood: 131230, clay: 104985, iron: 39370, crop: 78740),
                ResourceCost(wood: 219155, clay: 175320, iron: 65745, crop: 131490),
                ResourceCost(wood: 365985, clay: 292790, iron: 109795, crop: 219590),
                ResourceCost(wood: 611195, clay: 488955, iron: 183360, crop: 366715),
                ResourceCost(wood: 1020695, clay: 816555, iron: 306210, crop: 612420),
                ResourceCost(wood: 1704565, clay: 1363650, iron: 511370, crop: 1022740),
            ]
        case .crop:
            return [
                ResourceCost(wood: 75, clay: 90, iron: 85, crop: 0),
                ResourceCost(wood: 125, clay: 150, iron: 140, crop: 0),
                ResourceCost(wood: 210, clay: 250, iron: 235, crop: 0),
                ResourceCost(wood: 350, clay: 420, iron: 395, crop: 0),
                ResourceCost(wood: 585, clay: 700, iron: 660, crop: 0),
                ResourceCost(wood: 975, clay: 1170, iron: 1105, crop: 0),
                ResourceCost(wood: 1625, clay: 1950, iron: 1845, crop: 0),
                ResourceCost(wood: 2715, clay: 3260, iron: 3080, crop: 0),
                ResourceCost(wood: 4535, clay: 5445, iron: 5140, crop: 0),
                ResourceCost(wood: 7575, clay: 9095, iron: 8590, crop: 0),
                ResourceCost(wood: 12655, clay: 15185, iron: 14340, crop: 0),
                ResourceCost(wood: 21130, clay: 25360, iron: 23950, crop: 0),
                ResourceCost(wood: 35290, clay: 42350, iron: 39995, crop: 0),
                ResourceCost(wood: 58935, clay: 70720, iron: 66795, crop: 0),
                ResourceCost(wood: 98420, clay: 118105, iron: 111545, crop: 0),
                ResourceCost(wood: 164365, clay: 197240, iron: 186280, crop: 0),
                ResourceCost(wood: 274490, clay: 329385, iron: 311085, crop: 0),
                ResourceCost(wood: 458395, clay: 550075, iron: 519515, crop: 0),
                ResourceCost(wood: 765520, clay: 918625, iron: 867590, crop: 0),
                ResourceCost(wood: 1278420, clay: 1534105, iron: 1448880, crop: 0),
            ]
        }
    }

    /// Gibt die Baukosten für eine bestimmte Stufe zurück
    func resourceCost(at level: Int) -> ResourceCost {
        guard level >= 1 && level <= resourceCostsPerLevel.count else {
            return ResourceCost(wood: 0, clay: 0, iron: 0, crop: 0)
        }
        return resourceCostsPerLevel[level - 1]
    }
}

// MARK: - Supabase Row (fuer village_plans_sync Tabelle)

struct VillagePlansRow: Codable {
    let id: UUID?
    let userId: String
    let plans: [VillagePlan]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case plans
    }

    init(userId: String, plans: [VillagePlan]) {
        self.id = nil
        self.userId = userId
        self.plans = plans
    }
}

// MARK: - Village Resource Type (Dorf-Typ)

enum VillageResourceType: String, Codable, CaseIterable, Identifiable {
    case type4446   // 4 Holz, 4 Lehm, 4 Eisen, 6 Getreide (Standard)
    case type3456   // 3 Holz, 4 Lehm, 5 Eisen, 6 Getreide
    case type4356   // 4 Holz, 3 Lehm, 5 Eisen, 6 Getreide
    case type4536   // 4 Holz, 5 Lehm, 3 Eisen, 6 Getreide
    case type5436   // 5 Holz, 4 Lehm, 3 Eisen, 6 Getreide
    case type5346   // 5 Holz, 3 Lehm, 4 Eisen, 6 Getreide
    case type3546   // 3 Holz, 5 Lehm, 4 Eisen, 6 Getreide
    case type3339   // 3 Holz, 3 Lehm, 3 Eisen, 9 Getreide (9er Cropper)
    case type11115  // 1 Holz, 1 Lehm, 1 Eisen, 15 Getreide (15er Cropper)

    var id: String { rawValue }

    /// Anzeigename (z.B. "4-4-4-6")
    var label: String {
        let c = distribution
        return "\(c.wood)-\(c.clay)-\(c.iron)-\(c.crop)"
    }

    /// Beschreibung
    var subtitle: String {
        switch self {
        case .type4446: return "Standard"
        case .type3339: return "9er Cropper"
        case .type11115: return "15er Cropper"
        default: return ""
        }
    }

    /// Verteilung: (Holz, Lehm, Eisen, Getreide)
    var distribution: (wood: Int, clay: Int, iron: Int, crop: Int) {
        switch self {
        case .type4446: return (4, 4, 4, 6)
        case .type3456: return (3, 4, 5, 6)
        case .type4356: return (4, 3, 5, 6)
        case .type4536: return (4, 5, 3, 6)
        case .type5436: return (5, 4, 3, 6)
        case .type5346: return (5, 3, 4, 6)
        case .type3546: return (3, 5, 4, 6)
        case .type3339: return (3, 3, 3, 9)
        case .type11115: return (1, 1, 1, 15)
        }
    }

    /// Generiert 18 Rohstofffelder basierend auf dem Dorf-Typ
    func generateFields() -> [ResourceFieldSlot] {
        let d = distribution
        var types: [ResourceFieldType] = []
        types += Array(repeating: .wood, count: d.wood)
        types += Array(repeating: .clay, count: d.clay)
        types += Array(repeating: .iron, count: d.iron)
        types += Array(repeating: .crop, count: d.crop)

        return types.enumerated().map { i, type in
            ResourceFieldSlot(fieldNumber: i + 1, resourceType: type)
        }
    }
}
