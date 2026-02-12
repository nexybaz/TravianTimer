import Foundation

struct OptionRow: Identifiable, Hashable {
    let id = UUID()
    let start: StartVillage
    let troop: TroopKind
    let distance: Double
    let sendTime: Date
    let isLate: Bool
}

struct Calculator {

    static func distance(fromX: Int, fromY: Int, toX: Int, toY: Int) -> Double {
        let dx = Double(toX - fromX)
        let dy = Double(toY - fromY)
        return (dx * dx + dy * dy).squareRoot()
    }

    static func calculateOptions(
        starts: [StartVillage],
        targetX: Int,
        targetY: Int,
        arrival: Date,
        now: Date = .now
    ) -> [OptionRow] {

        var result: [OptionRow] = []

        for village in starts {

            let dist = distance(
                fromX: village.x,
                fromY: village.y,
                toX: targetX,
                toY: targetY
            )

            for troop in village.troops {

                let speed = troop.speed
                let hours = dist / speed
                let travelSeconds = hours * 3600.0
                let sendTime = arrival.addingTimeInterval(-travelSeconds)

                let late = sendTime < now

                result.append(
                    OptionRow(
                        start: village,
                        troop: troop,
                        distance: dist,
                        sendTime: sendTime,
                        isLate: late
                    )
                )
            }
        }

        return result.sorted {
            if $0.isLate != $1.isLate {
                return $0.isLate == false
            }
            return $0.sendTime < $1.sendTime
        }
    }
}
