import Foundation

// MARK: - Equipment Slot

enum EquipmentSlot: String, CaseIterable, Codable, Identifiable {
    case helm
    case armor
    case boots
    case horse
    case leftHand
    case rightHand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .helm:      return "Helm"
        case .armor:     return "Rüstung"
        case .boots:     return "Schuhe"
        case .horse:     return "Pferd"
        case .leftHand:  return "Linke Hand"
        case .rightHand: return "Rechte Hand"
        }
    }

    var icon: String {
        switch self {
        case .helm:      return "crown.fill"
        case .armor:     return "shield.checkerboard"
        case .boots:     return "shoeprints.fill"
        case .horse:     return "hare.fill"
        case .leftHand:  return "hand.raised.fill"
        case .rightHand: return "hand.raised.fingers.spread.fill"
        }
    }
}

// MARK: - Equipment Piece

struct EquipmentPiece: Codable, Equatable, Hashable {
    let category: String    // z.B. "health", "culture", "breastplate", "legionnaire"
    let tier: Int           // 1, 2, oder 3
    let variantIndex: Int   // Index in variantSteps (0 = bester)
}

// MARK: - Hero Config

struct HeroConfig: Codable, Equatable {
    var level: Int = 1
    var skillFight: Int = 0     // × 80 Kampfkraft
    var skillOff: Int = 0       // × 0.2% Off-Bonus
    var skillDef: Int = 0       // × 0.2% Def-Bonus
    var skillRes: Int = 0       // × 20 Ressourcen/h
    var hp: Int = 100
    var xp: Int = 0
    var equipment: [String: EquipmentPiece] = [:]  // key = EquipmentSlot.rawValue

    // MARK: Computed

    var totalSkillPoints: Int { skillFight + skillOff + skillDef + skillRes }
    var availableSkillPoints: Int { max(0, (level - 1) * 4) }
    var remainingSkillPoints: Int { availableSkillPoints - totalSkillPoints }

    func piece(for slot: EquipmentSlot) -> EquipmentPiece? {
        equipment[slot.rawValue]
    }

    mutating func setPiece(_ piece: EquipmentPiece?, for slot: EquipmentSlot) {
        equipment[slot.rawValue] = piece
    }

    // MARK: CodingKeys (snake_case fuer Supabase)

    enum CodingKeys: String, CodingKey {
        case level
        case skillFight = "skill_fight"
        case skillOff   = "skill_off"
        case skillDef   = "skill_def"
        case skillRes   = "skill_res"
        case hp
        case xp
        case equipment
    }
}

// MARK: - Supabase Row (mit id + user_id)

struct HeroConfigRow: Codable {
    let id: UUID?
    let userId: String
    let level: Int
    let skillFight: Int
    let skillOff: Int
    let skillDef: Int
    let skillRes: Int
    let hp: Int
    let xp: Int
    let equipment: [String: EquipmentPiece]

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case level
        case skillFight = "skill_fight"
        case skillOff   = "skill_off"
        case skillDef   = "skill_def"
        case skillRes   = "skill_res"
        case hp
        case xp
        case equipment
    }

    init(userId: String, config: HeroConfig) {
        self.id = nil
        self.userId = userId
        self.level = config.level
        self.skillFight = config.skillFight
        self.skillOff = config.skillOff
        self.skillDef = config.skillDef
        self.skillRes = config.skillRes
        self.hp = config.hp
        self.xp = config.xp
        self.equipment = config.equipment
    }

    func toConfig() -> HeroConfig {
        var c = HeroConfig()
        c.level = level
        c.skillFight = skillFight
        c.skillOff = skillOff
        c.skillDef = skillDef
        c.skillRes = skillRes
        c.hp = hp
        c.xp = xp
        c.equipment = equipment
        return c
    }
}
