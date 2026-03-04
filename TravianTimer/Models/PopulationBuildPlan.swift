import Foundation

// MARK: - Build Source (Gebäude-Slot oder Rohstofffeld)

enum PopBuildSource: Codable, Hashable {
    case resourceField(fieldIndex: Int, resourceType: ResourceFieldType)
    case existingBuilding(slotIndex: Int, buildingId: Int)
    case newBuilding(slotIndex: Int, buildingId: Int)
}

// MARK: - Build Step (ein einzelner Bau-Schritt)

struct PopBuildStep: Identifiable, Codable, Hashable {
    let id: UUID
    let stepNumber: Int
    let source: PopBuildSource
    let name: String
    let icon: String
    let fromLevel: Int
    let toLevel: Int
    let cost: ResourceCost
    let popBefore: Int
    let popAfter: Int
    var isCompleted: Bool = false

    var popDelta: Int { popAfter - popBefore }
}

// MARK: - Build Plan (gespeichert pro VillagePlan)

struct PopBuildPlan: Codable, Hashable {
    var targetPopulation: Int
    var startPopulation: Int
    var steps: [PopBuildStep]
    var createdAt: Date = Date()

    var totalCost: ResourceCost {
        steps.reduce(ResourceCost(wood: 0, clay: 0, iron: 0, crop: 0)) { acc, step in
            ResourceCost(
                wood: acc.wood + step.cost.wood,
                clay: acc.clay + step.cost.clay,
                iron: acc.iron + step.cost.iron,
                crop: acc.crop + step.cost.crop
            )
        }
    }

    var completedSteps: Int {
        steps.filter(\.isCompleted).count
    }

    var finalPopulation: Int {
        steps.last?.popAfter ?? startPopulation
    }
}
