import Foundation

// MARK: - Upgrade Calculator Engine

enum UpgradeCalculator {

    /// Berechnet die optimale Ausbau-Reihenfolge (Greedy-Algorithmus).
    static func computeBuildOrder(config: UpgradeCalculatorConfig) -> [UpgradeStep] {
        var state = SimulationState(config: config)
        var steps: [UpgradeStep] = []
        var cumulativeCost = 0

        for stepNumber in 1...config.maxSteps {
            guard let best = findBestUpgrade(state: state, config: config) else { break }

            // Upgrade anwenden
            state.apply(best)

            // Kumulative Produktion
            let wp = state.production(for: .wood)
            let cp = state.production(for: .clay)
            let ip = state.production(for: .iron)
            let kp = state.production(for: .crop)
            cumulativeCost += best.totalCost

            let step = UpgradeStep(
                id: stepNumber,
                upgradeType: best.upgradeType,
                buildingName: best.buildingName,
                buildingIcon: best.buildingIcon,
                fromLevel: best.fromLevel,
                toLevel: best.toLevel,
                woodCost: best.woodCost,
                clayCost: best.clayCost,
                ironCost: best.ironCost,
                cropCost: best.cropCost,
                baseTimeSec: best.baseTimeSec,
                pop: best.pop,
                productionDelta: best.productionDelta,
                efficiency: best.efficiency,
                cumulativeWoodProd: wp,
                cumulativeClayProd: cp,
                cumulativeIronProd: ip,
                cumulativeCropProd: kp,
                cumulativeTotalCost: cumulativeCost
            )
            steps.append(step)
        }

        return steps
    }
}

// MARK: - Interner Simulationszustand

private struct SimulationState {
    var fieldLevels: [Int]
    var fieldTypes: [ResourceFieldType]

    var sawmillLevel: Int
    var brickyardLevel: Int
    var ironFoundryLevel: Int
    var grainMillLevel: Int
    var bakeryLevel: Int

    let oasisBonus: OasisBonus
    let goldBoost: Bool

    init(config: UpgradeCalculatorConfig) {
        self.fieldLevels = config.resourceFieldLevels.map { $0.level }
        self.fieldTypes = config.resourceFieldLevels.map { $0.resourceType }
        self.sawmillLevel = config.sawmillLevel
        self.brickyardLevel = config.brickyardLevel
        self.ironFoundryLevel = config.ironFoundryLevel
        self.grainMillLevel = config.grainMillLevel
        self.bakeryLevel = config.bakeryLevel
        self.oasisBonus = config.oasisBonus
        self.goldBoost = config.goldBoost
    }

    /// Gesamtproduktion für einen Ressourcentyp inkl. aller Boni
    func production(for type: ResourceFieldType) -> Double {
        let baseProd = fieldLevels.enumerated()
            .filter { fieldTypes[$0.offset] == type }
            .reduce(0) { sum, pair in
                sum + ResourceFieldType.production(at: pair.element)
            }

        let boosterPct = boosterPercent(for: type)
        let oasisPct = Double(oasisBonus.percent(for: type))
        let goldPct: Double = goldBoost ? 25.0 : 0.0

        // Travian-Formel: base × (1 + (booster + oasis + gold) / 100)
        return Double(baseProd) * (1.0 + (boosterPct + oasisPct + goldPct) / 100.0)
    }

    func totalProduction() -> Double {
        ResourceFieldType.allCases.reduce(0.0) { $0 + production(for: $1) }
    }

    /// Booster-Bonus in % für einen Ressourcentyp
    private func boosterPercent(for type: ResourceFieldType) -> Double {
        switch type {
        case .wood:
            return boosterBonusValue(buildingId: 5, level: sawmillLevel)
        case .clay:
            return boosterBonusValue(buildingId: 6, level: brickyardLevel)
        case .iron:
            return boosterBonusValue(buildingId: 7, level: ironFoundryLevel)
        case .crop:
            let mill = boosterBonusValue(buildingId: 8, level: grainMillLevel)
            let bakery = boosterBonusValue(buildingId: 9, level: bakeryLevel)
            return mill + bakery
        }
    }

    /// Liest den bonusValue aus den Building-Daten
    private func boosterBonusValue(buildingId: Int, level: Int) -> Double {
        guard level >= 1,
              let building = Building.allBuildings.first(where: { $0.id == buildingId }),
              level <= building.levels.count
        else { return 0 }
        return building.levels[level - 1].bonusValue
    }

    /// Wendet ein Upgrade auf den Zustand an
    mutating func apply(_ candidate: CandidateUpgrade) {
        switch candidate.upgradeType {
        case .resourceField(let fieldIndex, _):
            fieldLevels[fieldIndex] = candidate.toLevel
        case .booster(let buildingId):
            switch buildingId {
            case 5: sawmillLevel = candidate.toLevel
            case 6: brickyardLevel = candidate.toLevel
            case 7: ironFoundryLevel = candidate.toLevel
            case 8: grainMillLevel = candidate.toLevel
            case 9: bakeryLevel = candidate.toLevel
            default: break
            }
        }
    }
}

// MARK: - Kandidat für ein Upgrade

private struct CandidateUpgrade {
    let upgradeType: UpgradeType
    let buildingName: String
    let buildingIcon: String
    let fromLevel: Int
    let toLevel: Int
    let woodCost: Int
    let clayCost: Int
    let ironCost: Int
    let cropCost: Int
    let baseTimeSec: Int
    let pop: Int
    let productionDelta: Double
    let efficiency: Double

    var totalCost: Int { woodCost + clayCost + ironCost + cropCost }
}

// MARK: - Bestes Upgrade finden

private extension UpgradeCalculator {

    static func findBestUpgrade(
        state: SimulationState,
        config: UpgradeCalculatorConfig
    ) -> CandidateUpgrade? {
        var candidates: [CandidateUpgrade] = []
        let currentTotal = state.totalProduction()

        // 1. Rohstofffelder upgraden
        for (index, currentLevel) in state.fieldLevels.enumerated() {
            // Nur Felder mit Level ≥ 1 (Level 0 = "nicht konfiguriert")
            guard currentLevel >= 1 else { continue }
            let nextLevel = currentLevel + 1
            guard nextLevel <= 20 else { continue }

            let fieldType = state.fieldTypes[index]
            guard let building = buildingForFieldType(fieldType) else { continue }
            guard nextLevel <= building.levels.count else { continue }
            let levelData = building.levels[nextLevel - 1]

            // Simulieren
            var simState = state
            simState.fieldLevels[index] = nextLevel
            let newTotal = simState.totalProduction()
            let delta = newTotal - currentTotal
            let cost = levelData.wood + levelData.clay + levelData.iron + levelData.crop
            guard cost > 0 else { continue }

            candidates.append(CandidateUpgrade(
                upgradeType: .resourceField(fieldIndex: index, resourceType: fieldType),
                buildingName: building.name,
                buildingIcon: building.icon,
                fromLevel: currentLevel,
                toLevel: nextLevel,
                woodCost: levelData.wood,
                clayCost: levelData.clay,
                ironCost: levelData.iron,
                cropCost: levelData.crop,
                baseTimeSec: levelData.baseTimeSec,
                pop: levelData.pop,
                productionDelta: delta,
                efficiency: delta / Double(cost)
            ))
        }

        // 2. Veredelungsgebäude upgraden
        let boosterCandidates = boosterUpgrades(state: state, config: config)
        for booster in boosterCandidates {
            var simState = state
            simState.apply(booster)
            let newTotal = simState.totalProduction()
            let delta = newTotal - currentTotal
            guard delta > 0 else { continue }

            // Effizienz neu berechnen
            let cost = booster.totalCost
            guard cost > 0 else { continue }

            candidates.append(CandidateUpgrade(
                upgradeType: booster.upgradeType,
                buildingName: booster.buildingName,
                buildingIcon: booster.buildingIcon,
                fromLevel: booster.fromLevel,
                toLevel: booster.toLevel,
                woodCost: booster.woodCost,
                clayCost: booster.clayCost,
                ironCost: booster.ironCost,
                cropCost: booster.cropCost,
                baseTimeSec: booster.baseTimeSec,
                pop: booster.pop,
                productionDelta: delta,
                efficiency: delta / Double(cost)
            ))
        }

        // Bestes Upgrade = höchste Effizienz
        return candidates.max(by: { $0.efficiency < $1.efficiency })
    }

    /// Alle möglichen Booster-Upgrades im aktuellen Zustand
    static func boosterUpgrades(
        state: SimulationState,
        config: UpgradeCalculatorConfig
    ) -> [CandidateUpgrade] {
        var results: [CandidateUpgrade] = []

        struct BoosterInfo {
            let id: Int
            let currentLevel: Int
            let skipWCI: Bool
        }

        let boosters: [BoosterInfo] = [
            BoosterInfo(id: 5, currentLevel: state.sawmillLevel, skipWCI: config.skipWCIBoosters),
            BoosterInfo(id: 6, currentLevel: state.brickyardLevel, skipWCI: config.skipWCIBoosters),
            BoosterInfo(id: 7, currentLevel: state.ironFoundryLevel, skipWCI: config.skipWCIBoosters),
            BoosterInfo(id: 8, currentLevel: state.grainMillLevel, skipWCI: false),
            BoosterInfo(id: 9, currentLevel: state.bakeryLevel, skipWCI: false),
        ]

        for info in boosters {
            guard !info.skipWCI else { continue }
            let nextLevel = info.currentLevel + 1
            guard nextLevel <= 5 else { continue }
            guard let building = Building.allBuildings.first(where: { $0.id == info.id }) else { continue }
            guard nextLevel <= building.levels.count else { continue }

            let levelData = building.levels[nextLevel - 1]

            results.append(CandidateUpgrade(
                upgradeType: .booster(buildingId: info.id),
                buildingName: building.name,
                buildingIcon: building.icon,
                fromLevel: info.currentLevel,
                toLevel: nextLevel,
                woodCost: levelData.wood,
                clayCost: levelData.clay,
                ironCost: levelData.iron,
                cropCost: levelData.crop,
                baseTimeSec: levelData.baseTimeSec,
                pop: levelData.pop,
                productionDelta: 0, // wird in findBestUpgrade berechnet
                efficiency: 0
            ))
        }

        return results
    }

    /// Findet das Building-Objekt für einen Feldtyp
    static func buildingForFieldType(_ type: ResourceFieldType) -> Building? {
        let id: Int
        switch type {
        case .wood: id = 1
        case .clay: id = 2
        case .iron: id = 3
        case .crop: id = 4
        }
        return Building.allBuildings.first(where: { $0.id == id })
    }
}
