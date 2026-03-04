import Foundation

// MARK: - Hero Bonus Summary

struct TroopEquipmentBonus: Equatable {
    let troopName: String
    let attackPerTroop: Int
    let defensePerTroop: Int
    let weaponKampfkraft: Int
}

struct HeroBonusSummary: Equatable {
    // Kampf
    let kampfkraft: Int                     // Skill × 80 + Ausrüstung
    let offBonusPercent: Double             // Skill × 0.2
    let defBonusPercent: Double             // Skill × 0.2

    // Wirtschaft
    let resourceBonusPerHour: Int           // Skill × 20
    let kulturpunktePerDay: Int             // Helm der Kultur × worldSpeed

    // Geschwindigkeit
    let heroSpeed: Int                      // Pferd base + variant (+ Gallier +5)
    let speedBonusPercent: Int              // Ausdauer-Schuhe (> 20 Felder)
    let spursBonusPerHour: Int              // Pferdesporen (nur beritten)
    let isCavalry: Bool                     // true wenn Pferd ausgerüstet

    // Regeneration / XP
    let hpRegenPerDay: Int                  // Helm + Rüstung
    let xpBonusPercent: Int                 // Achtsamkeits-Schuhe

    // Training
    let barracksReductionPercent: Int       // Infanterie-Helm
    let stableReductionPercent: Int         // Kavallerie-Helm

    // Spezial
    let plunderBonusPercent: Int            // Taschen (Linke Hand)
    let returnSpeedPercent: Int             // Karten (Linke Hand)
    let ownTransferPercent: Int             // Standarte des Volkes
    let allianceTransferPercent: Int        // Standarte des Bundes
    let natarBonusPercent: Int              // Horn
    let evadeTroops: Int                    // Angsthasen-Stiefel
    let telescopeThreshold: Int             // Fernrohr
    let shieldKampfkraft: Int               // Kriegsschild (Linke Hand)

    // Truppen-Bonus (Rechte Hand)
    let troopBonus: TroopEquipmentBonus?
}

// MARK: - Calculator

enum HeroBonusCalculator {

    static func calculate(config: HeroConfig, tribe: Tribe, worldSpeed: Int) -> HeroBonusSummary {
        // Skill-basierte Werte
        let skillKampfkraft = config.skillFight * 80
        let offBonus = Double(config.skillOff) * 0.2
        let defBonus = Double(config.skillDef) * 0.2
        let resBonus = config.skillRes * 20

        // Equipment-Boni sammeln
        var equipKampfkraft = 0
        var kulturpunkte = 0
        var heroSpeed = 0
        var speedBonusPercent = 0
        var spursBonusPerHour = 0
        var hpRegen = 0
        var xpBonusPercent = 0
        var barracksReduction = 0
        var stableReduction = 0
        var plunderBonus = 0
        var returnSpeed = 0
        var ownTransfer = 0
        var allianceTransfer = 0
        var natarBonus = 0
        var evadeTroops = 0
        var telescopeThreshold = 0
        var shieldKampfkraft = 0
        var troopBonus: TroopEquipmentBonus?
        var hasHorse = false

        // Helm
        if let piece = config.piece(for: .helm),
           let cat = HelmetCategory(rawValue: piece.category) {
            let val = resolveValue(tiers: cat.tiers(upTo: 3), level: piece.tier, variantIndex: piece.variantIndex)
            switch cat {
            case .health:    hpRegen += val
            case .culture:   kulturpunkte = val * worldSpeed
            case .cavalry:   stableReduction = val  // negativ, z.B. -15
            case .infantry:  barracksReduction = val
            }
        }

        // Rüstung
        if let piece = config.piece(for: .armor),
           let cat = ArmorCategory(rawValue: piece.category) {
            let val = resolveValue(tiers: cat.tiers(upTo: 3), level: piece.tier, variantIndex: piece.variantIndex)
            switch cat {
            case .regeneration: hpRegen += val
            case .scaleMail:    hpRegen += val  // baseValue ist HP/Tag-Regen
            case .breastplate:  equipKampfkraft += val
            case .segmentedArmor: equipKampfkraft += val
            }
        }

        // Schuhe
        if let piece = config.piece(for: .boots),
           let cat = BootsCategory(rawValue: piece.category) {
            let val = resolveValue(tiers: cat.tiers(upTo: 3), level: piece.tier, variantIndex: piece.variantIndex)
            switch cat {
            case .mindfulness: xpBonusPercent = val
            case .endurance:   speedBonusPercent = val
            case .spurs:       spursBonusPerHour = val
            case .coward:      evadeTroops = val
            }
        }

        // Pferd
        if let piece = config.piece(for: .horse) {
            hasHorse = true
            let allHorseTiers = HorseTier.allTiers(upTo: 3)
            if let tier = allHorseTiers.first(where: { $0.level == piece.tier }) {
                let idx = min(piece.variantIndex, tier.variantSteps.count - 1)
                heroSpeed = tier.baseValue + tier.variantSteps[max(0, idx)]
                // Gallier +5 Bonus
                if tribe == .gauls {
                    heroSpeed += 5
                }
            }
        }

        // Linke Hand
        if let piece = config.piece(for: .leftHand),
           let cat = LeftHandCategory(rawValue: piece.category) {
            let val = resolveLeftHandValue(category: cat, level: piece.tier, variantIndex: piece.variantIndex)
            switch cat {
            case .maps:              returnSpeed = val
            case .tribeStandard:     ownTransfer = val
            case .allianceStandard:  allianceTransfer = val
            case .telescope:         telescopeThreshold = val
            case .bags:              plunderBonus = val
            case .shields:           shieldKampfkraft = val
            case .horns:             natarBonus = val
            }
        }

        // Rechte Hand (tribe-spezifisch)
        if let piece = config.piece(for: .rightHand) {
            troopBonus = resolveWeaponBonus(category: piece.category, tribe: tribe,
                                             level: piece.tier, variantIndex: piece.variantIndex)
        }

        let totalKampfkraft = skillKampfkraft + equipKampfkraft + shieldKampfkraft + (troopBonus?.weaponKampfkraft ?? 0)

        return HeroBonusSummary(
            kampfkraft: totalKampfkraft,
            offBonusPercent: offBonus,
            defBonusPercent: defBonus,
            resourceBonusPerHour: resBonus,
            kulturpunktePerDay: kulturpunkte,
            heroSpeed: heroSpeed,
            speedBonusPercent: speedBonusPercent,
            spursBonusPerHour: hasHorse ? spursBonusPerHour : 0,
            isCavalry: hasHorse,
            hpRegenPerDay: hpRegen,
            xpBonusPercent: xpBonusPercent,
            barracksReductionPercent: barracksReduction,
            stableReductionPercent: stableReduction,
            plunderBonusPercent: plunderBonus,
            returnSpeedPercent: returnSpeed,
            ownTransferPercent: ownTransfer,
            allianceTransferPercent: allianceTransfer,
            natarBonusPercent: natarBonus,
            evadeTroops: evadeTroops,
            telescopeThreshold: telescopeThreshold,
            shieldKampfkraft: shieldKampfkraft,
            troopBonus: troopBonus
        )
    }

    // MARK: - Helpers

    /// Generischer Resolver fuer Helm/Ruestung/Schuhe Tiers.
    private static func resolveValue<T: TierResolvable>(tiers: [T], level: Int, variantIndex: Int) -> Int {
        guard let tier = tiers.first(where: { $0.tierLevel == level }) else { return 0 }
        let idx = min(max(0, variantIndex), tier.tierVariantSteps.count - 1)
        return tier.tierBaseValue + tier.tierVariantSteps[idx]
    }

    /// Linke Hand: nutzt LeftHandCategory.tiers(upTo:)
    private static func resolveLeftHandValue(category: LeftHandCategory, level: Int, variantIndex: Int) -> Int {
        let tiers = category.tiers(upTo: 3)
        guard let tier = tiers.first(where: { $0.level == level }) else { return 0 }
        let idx = min(max(0, variantIndex), tier.variantSteps.count - 1)
        return tier.baseValue + tier.variantSteps[idx]
    }

    /// Rechte Hand: tribe-spezifische Waffen-Kategorien
    private static func resolveWeaponBonus(category: String, tribe: Tribe, level: Int, variantIndex: Int) -> TroopEquipmentBonus? {
        switch tribe {
        case .romans:
            guard let cat = RomanWeaponCategory(rawValue: category) else { return nil }
            let tiers = cat.tiers(upTo: 3)
            guard let tier = tiers.first(where: { $0.level == level }) else { return nil }
            let idx = min(max(0, variantIndex), tier.variantSteps.count - 1)
            let kk = tier.heroStrength + tier.variantSteps[idx]
            return TroopEquipmentBonus(troopName: tier.troopName, attackPerTroop: tier.troopAtk,
                                        defensePerTroop: tier.troopDef, weaponKampfkraft: kk)
        case .gauls:
            guard let cat = GaulWeaponCategory(rawValue: category) else { return nil }
            let tiers = cat.tiers(upTo: 3)
            guard let tier = tiers.first(where: { $0.level == level }) else { return nil }
            let idx = min(max(0, variantIndex), tier.variantSteps.count - 1)
            let kk = tier.heroStrength + tier.variantSteps[idx]
            return TroopEquipmentBonus(troopName: tier.troopName, attackPerTroop: tier.troopAtk,
                                        defensePerTroop: tier.troopDef, weaponKampfkraft: kk)
        case .teutons:
            guard let cat = TeutonWeaponCategory(rawValue: category) else { return nil }
            let tiers = cat.tiers(upTo: 3)
            guard let tier = tiers.first(where: { $0.level == level }) else { return nil }
            let idx = min(max(0, variantIndex), tier.variantSteps.count - 1)
            let kk = tier.heroStrength + tier.variantSteps[idx]
            return TroopEquipmentBonus(troopName: tier.troopName, attackPerTroop: tier.troopAtk,
                                        defensePerTroop: tier.troopDef, weaponKampfkraft: kk)
        }
    }
}

// MARK: - Tier Resolvable Protocol

/// Generisches Protokoll fuer alle Tier-Structs die baseValue + variantSteps haben.
protocol TierResolvable {
    var tierLevel: Int { get }
    var tierBaseValue: Int { get }
    var tierVariantSteps: [Int] { get }
}

extension HelmetTier: TierResolvable {
    var tierLevel: Int { level }
    var tierBaseValue: Int { baseValue }
    var tierVariantSteps: [Int] { variantSteps }
}

extension ArmorTier: TierResolvable {
    var tierLevel: Int { level }
    var tierBaseValue: Int { baseValue }
    var tierVariantSteps: [Int] { variantSteps }
}

extension BootsTier: TierResolvable {
    var tierLevel: Int { level }
    var tierBaseValue: Int { baseValue }
    var tierVariantSteps: [Int] { variantSteps }
}
