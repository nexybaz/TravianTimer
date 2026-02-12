import Foundation

enum TroopKind: String, Codable, CaseIterable, Hashable {
    case phalanx = "Phalanxe"
    case swordsman = "Schwertkämpfer"
    case haeduan = "Haeduaner"
    case ram = "Ramme"
    case catapult = "Katapult"

    var speed: Double {
        switch self {
        case .phalanx: return 7
        case .swordsman: return 6
        case .haeduan: return 13
        case .ram: return 4
        case .catapult: return 3
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
