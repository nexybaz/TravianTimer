import Foundation
import SwiftUI

enum TroopKind: String, Codable, CaseIterable, Hashable {

    // rawValue is a stable internal key (unique across all tribes).
    // Use `uiName` for display.

    // MARK: Romans
    case romansLegionnaire = "romans.legionnaire"
    case romansPraetorian = "romans.praetorian"
    case romansImperian = "romans.imperian"
    case romansEquitesLegati = "romans.equites_legati"
    case romansEquitesImperatoris = "romans.equites_imperatoris"
    case romansEquitesCaesaris = "romans.equites_caesaris"
    case romansBatteringRam = "romans.battering_ram"
    case romansFireCatapult = "romans.fire_catapult"
    case romansSenator = "romans.senator"
    case romansSettler = "romans.settler"

    // MARK: Teutons
    case teutonsClubswinger = "teutons.clubswinger"
    case teutonsSpearfighter = "teutons.spearfighter"
    case teutonsAxefighter = "teutons.axefighter"
    case teutonsScout = "teutons.scout"
    case teutonsPaladin = "teutons.paladin"
    case teutonsTeutonicKnight = "teutons.teutonic_knight"
    case teutonsRam = "teutons.ram"
    case teutonsCatapult = "teutons.catapult"
    case teutonsChief = "teutons.chief"
    case teutonsSettler = "teutons.settler"

    // MARK: Gauls
    case gaulsPhalanx = "gauls.phalanx"
    case gaulsSwordsman = "gauls.swordsman"
    case gaulsPathfinder = "gauls.pathfinder"
    case gaulsTheutatesThunder = "gauls.theutates_thunder"
    case gaulsDruidrider = "gauls.druidrider"
    case gaulsHaeduan = "gauls.haeduan"
    case gaulsRam = "gauls.ram"
    case gaulsTrebuchet = "gauls.trebuchet"
    case gaulsChieftain = "gauls.chieftain"
    case gaulsSettler = "gauls.settler"

    // Display name (in-game)
    var uiName: String {
        switch self {
        // Römer
        case .romansLegionnaire: return "Legionär"
        case .romansPraetorian: return "Prätorianer"
        case .romansImperian: return "Imperianer"
        case .romansEquitesLegati: return "Equites Legati"
        case .romansEquitesImperatoris: return "Equites Imperatoris"
        case .romansEquitesCaesaris: return "Equites Caesaris"
        case .romansBatteringRam: return "Ramme"
        case .romansFireCatapult: return "Feuerkatapult"
        case .romansSenator: return "Senator"
        case .romansSettler: return "Siedler"

        // Germanen
        case .teutonsClubswinger: return "Keulenschwinger"
        case .teutonsSpearfighter: return "Speerkämpfer"
        case .teutonsAxefighter: return "Axtkämpfer"
        case .teutonsScout: return "Späher"
        case .teutonsPaladin: return "Paladin"
        case .teutonsTeutonicKnight: return "Teutonen-Reiter"
        case .teutonsRam: return "Ramme"
        case .teutonsCatapult: return "Katapult"
        case .teutonsChief: return "Stammesführer"
        case .teutonsSettler: return "Siedler"

        // Gallier
        case .gaulsPhalanx: return "Phalanxe"
        case .gaulsSwordsman: return "Schwertkämpfer"
        case .gaulsPathfinder: return "Späher"
        case .gaulsTheutatesThunder: return "Theutates Blitz"
        case .gaulsDruidrider: return "Druidenreiter"
        case .gaulsHaeduan: return "Haeduaner"
        case .gaulsRam: return "Ramme"
        case .gaulsTrebuchet: return "Katapult"
        case .gaulsChieftain: return "Stammesführer"
        case .gaulsSettler: return "Siedler"
        }
    }

    // MARK: - Off / Deff Klassifikation

    /// Offensiv-Truppen (primär Angriffswerte). Belagerung, Anführer und Siedler zählen weder als Off noch Deff.
    var isOffensive: Bool {
        switch self {
        // Römer
        case .romansImperian, .romansEquitesImperatoris, .romansEquitesCaesaris:
            return true
        // Germanen
        case .teutonsClubswinger, .teutonsAxefighter, .teutonsTeutonicKnight:
            return true
        // Gallier
        case .gaulsSwordsman, .gaulsTheutatesThunder, .gaulsHaeduan:
            return true
        default:
            return false
        }
    }

    /// Defensiv-Truppen (primär Verteidigungswerte).
    var isDefensive: Bool {
        switch self {
        // Römer
        case .romansLegionnaire, .romansPraetorian, .romansEquitesLegati:
            return true
        // Germanen
        case .teutonsSpearfighter, .teutonsPaladin:
            return true
        // Gallier
        case .gaulsPhalanx, .gaulsDruidrider:
            return true
        default:
            return false
        }
    }

    // MARK: - Volk & Kategorie (für Deff-Übersicht)

    /// Volk-Prefix: "romans", "teutons" oder "gauls"
    var tribe: String {
        if rawValue.hasPrefix("romans.") { return "romans" }
        if rawValue.hasPrefix("teutons.") { return "teutons" }
        return "gauls"
    }

    /// Farbe pro Volk für UI-Darstellung
    var tribeColor: Color {
        switch tribe {
        case "romans":  return .blue
        case "teutons": return .orange
        default:        return .green
        }
    }

    /// SF Symbol basierend auf Truppenkategorie
    var categoryIcon: String {
        switch self {
        // Kavallerie
        case .romansEquitesLegati, .romansEquitesImperatoris, .romansEquitesCaesaris,
             .gaulsTheutatesThunder, .gaulsDruidrider, .gaulsHaeduan,
             .teutonsPaladin, .teutonsTeutonicKnight:
            return "figure.equestrian.sports"
        // Belagerung
        case .romansBatteringRam, .romansFireCatapult,
             .gaulsRam, .gaulsTrebuchet,
             .teutonsRam, .teutonsCatapult:
            return "bolt.shield.fill"
        // Späher
        case .gaulsPathfinder, .teutonsScout:
            return "eye"
        // Anführer
        case .romansSenator, .gaulsChieftain, .teutonsChief:
            return "crown"
        // Siedler
        case .romansSettler, .gaulsSettler, .teutonsSettler:
            return "house"
        // Infanterie (default)
        default:
            return "shield.fill"
        }
    }

    /// Getreideverbrauch pro Truppe pro Stunde
    var cropPerHour: Int {
        switch self {
        // Römer
        case .romansLegionnaire:          return 1
        case .romansPraetorian:           return 1
        case .romansImperian:             return 1
        case .romansEquitesLegati:        return 2
        case .romansEquitesImperatoris:   return 3
        case .romansEquitesCaesaris:      return 4
        case .romansBatteringRam:         return 3
        case .romansFireCatapult:         return 6
        case .romansSenator:             return 5
        case .romansSettler:             return 1

        // Germanen
        case .teutonsClubswinger:        return 1
        case .teutonsSpearfighter:       return 1
        case .teutonsAxefighter:         return 1
        case .teutonsScout:              return 1
        case .teutonsPaladin:            return 2
        case .teutonsTeutonicKnight:      return 3
        case .teutonsRam:                return 3
        case .teutonsCatapult:           return 6
        case .teutonsChief:              return 4
        case .teutonsSettler:            return 1

        // Gallier
        case .gaulsPhalanx:              return 1
        case .gaulsSwordsman:            return 1
        case .gaulsPathfinder:           return 1
        case .gaulsTheutatesThunder:     return 2
        case .gaulsDruidrider:           return 2
        case .gaulsHaeduan:              return 3
        case .gaulsRam:                  return 3
        case .gaulsTrebuchet:            return 6
        case .gaulsChieftain:            return 4
        case .gaulsSettler:              return 1
        }
    }

    /// Base speed for 1x worlds (multiplier is applied in Calculator)
    var speed: Double {
        switch self {
        // Romans
        case .romansLegionnaire: return 6
        case .romansPraetorian: return 5
        case .romansImperian: return 7
        case .romansEquitesLegati: return 16
        case .romansEquitesImperatoris: return 14
        case .romansEquitesCaesaris: return 10
        case .romansBatteringRam: return 4
        case .romansFireCatapult: return 3
        case .romansSenator: return 4
        case .romansSettler: return 5

        // Teutons
        case .teutonsClubswinger: return 7
        case .teutonsSpearfighter: return 7
        case .teutonsAxefighter: return 6
        case .teutonsScout: return 9
        case .teutonsPaladin: return 10
        case .teutonsTeutonicKnight: return 9
        case .teutonsRam: return 4
        case .teutonsCatapult: return 3
        case .teutonsChief: return 4
        case .teutonsSettler: return 5

        // Gauls
        case .gaulsPhalanx: return 7
        case .gaulsSwordsman: return 6
        case .gaulsPathfinder: return 17
        case .gaulsTheutatesThunder: return 19
        case .gaulsDruidrider: return 16
        case .gaulsHaeduan: return 13
        case .gaulsRam: return 4
        case .gaulsTrebuchet: return 3
        case .gaulsChieftain: return 5
        case .gaulsSettler: return 5
        }
    }

    /// Returns the troops for the selected tribe (stored as German UI string in AppStorage)
    static func troops(forSelectedTribeRaw tribeRaw: String) -> [TroopKind] {
        let t = tribeRaw.lowercased()
        if t.contains("römer") || t.contains("roemer") || t.contains("roman") {
            return allCases.filter { $0.rawValue.hasPrefix("romans.") }
        }
        if t.contains("german") || t.contains("teuton") || t.contains("germanen") {
            return allCases.filter { $0.rawValue.hasPrefix("teutons.") }
        }
        return allCases.filter { $0.rawValue.hasPrefix("gauls.") }
    }

    /// Migration helper: old stored troop display names (German legacy) to new stable keys.
    static func migrateLegacyStoredName(_ legacy: String) -> TroopKind? {
        let l = legacy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch l {
        case "phalanxe", "phalanx": return .gaulsPhalanx
        case "schwertkämpfer", "schwertkaempfer", "schwerkämpfer", "schwerkaempfer", "swordsman": return .gaulsSwordsman
        case "haeduaner", "haeduan": return .gaulsHaeduan
        case "ramme", "ram": return .gaulsRam
        case "katapult", "trebuchet": return .gaulsTrebuchet
        default:
            return nil
        }
    }
}

struct StartVillage: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var x: Int
    var y: Int
    var troops: [TroopKind]

    init(name: String, x: Int, y: Int, troops: [TroopKind]) {
        self.id = UUID()
        self.name = name
        self.x = x
        self.y = y
        self.troops = troops
    }

    var coordText: String {
        "\(x)/\(y)"
    }
}
