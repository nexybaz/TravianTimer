import Foundation

enum Defaults {
    static let startVillages: [StartVillage] = [

        .init(
            name: "1.0 Bowser Castle",
            x: -6,
            y: 3,
            troops: [.gaulsPhalanx, .gaulsSwordsman, .gaulsHaeduan, .gaulsRam, .gaulsTrebuchet]
        ),

        .init(
            name: "1.1 Peach Circuit",
            x: -5,
            y: 1,
            troops: [.gaulsPhalanx, .gaulsRam]
        ),

        .init(
            name: "1.2 Shy Guy Beach",
            x: -5,
            y: 5,
            troops: [.gaulsPhalanx, .gaulsRam]
        ),

        .init(
            name: "2.0 Bowser Castle 2",
            x: 22,
            y: -4,
            troops: [.gaulsPhalanx, .gaulsRam]
        ),

        .init(
            name: "2.2 Boo Lake",
            x: 19,
            y: -5,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "2.1 Mario Circuit",
            x: 19,
            y: -2,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "1.3 Riverside Park",
            x: -1,
            y: 2,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "2.3 Cheese Land",
            x: 24,
            y: -2,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "3.0 Bowser Castle 3",
            x: -1,
            y: 12,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "3.1 Luigi Circuit",
            x: 0,
            y: 10,
            troops: [.gaulsPhalanx]
        ),

        .init(
            name: "3.2 Sky Garden",
            x: -4,
            y: 7,
            troops: [.gaulsPhalanx]
        )
    ]

    static var speedMultiplier: Int {
        let raw = UserDefaults.standard.integer(forKey: "speedMultiplier")
        let value = (raw == 0) ? 1 : raw
        return max(1, min(3, value))
    }
}
