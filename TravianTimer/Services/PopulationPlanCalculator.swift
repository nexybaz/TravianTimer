import Foundation

// MARK: - Population Plan Calculator (Greedy-Algorithmus)

enum PopulationPlanCalculator {

    /// Berechnet einen kostenoptimierten Bauplan um die Ziel-Bevölkerung zu erreichen.
    static func computePlan(plan: VillagePlan, targetPop: Int) -> PopBuildPlan {
        var state = SimState(plan: plan)
        var steps: [PopBuildStep] = []
        let startPop = state.totalPopulation

        while state.totalPopulation < targetPop {
            guard let best = findCheapestCandidate(state: state) else { break }

            // Bundle emittieren: jede Stufe als einzelner Step
            for upgrade in best.levels {
                let popBefore = state.totalPopulation
                state.apply(upgrade)
                let popAfter = state.totalPopulation

                let step = PopBuildStep(
                    id: UUID(),
                    stepNumber: steps.count + 1,
                    source: upgrade.source,
                    name: upgrade.name,
                    icon: upgrade.icon,
                    fromLevel: upgrade.fromLevel,
                    toLevel: upgrade.toLevel,
                    cost: upgrade.cost,
                    popBefore: popBefore,
                    popAfter: popAfter
                )
                steps.append(step)

                if popAfter >= targetPop { break }
            }
        }

        return PopBuildPlan(
            targetPopulation: targetPop,
            startPopulation: startPop,
            steps: steps
        )
    }
}

// MARK: - Simulation State

private struct SimState {
    var fieldLevels: [Int]
    var fieldTypes: [ResourceFieldType]
    var slotBuildingIds: [Int?]
    var slotLevels: [Int]

    init(plan: VillagePlan) {
        self.fieldLevels = plan.resourceFields.map(\.level)
        self.fieldTypes = plan.resourceFields.map(\.resourceType)
        self.slotBuildingIds = plan.slots.map(\.buildingId)
        self.slotLevels = plan.slots.map(\.level)
    }

    var totalPopulation: Int {
        var pop = 0
        // Rohstofffelder
        for (i, level) in fieldLevels.enumerated() where level > 0 {
            pop += fieldTypes[i].population(at: level)
        }
        // Gebäude
        for (i, buildingId) in slotBuildingIds.enumerated() {
            guard let bid = buildingId, slotLevels[i] > 0 else { continue }
            if let building = Building.allBuildings.first(where: { $0.id == bid }),
               slotLevels[i] <= building.levels.count {
                pop += building.levels[slotLevels[i] - 1].pop
            }
        }
        return pop
    }

    /// Prüft ob eine Gebäude-Voraussetzung im aktuellen Zustand erfüllt ist.
    /// Format: "Gebäudename Level" z.B. "Hauptgebäude 5", "Kaserne 3"
    func prerequisiteMet(_ prereq: String) -> Bool {
        // Spezial-Voraussetzungen → nicht erfüllbar im Algorithmus
        if prereq == "Stadt" || prereq == "WW-Dorf" || prereq == "Nur Hauptstadt" { return false }

        // "Name Level" parsen
        guard let lastSpace = prereq.lastIndex(of: " "),
              let requiredLevel = Int(prereq[prereq.index(after: lastSpace)...])
        else { return false }
        let name = String(prereq[..<lastSpace])

        // Rohstofffeld-Voraussetzungen
        let fieldTypeForName: ResourceFieldType? = switch name {
        case "Holzfäller": .wood
        case "Lehmgrube": .clay
        case "Eisenmine": .iron
        case "Getreidefeld": .crop
        default: nil
        }
        if let fieldType = fieldTypeForName {
            return fieldLevels.enumerated().contains { i, level in
                fieldTypes[i] == fieldType && level >= requiredLevel
            }
        }

        // Gebäude-Name → ID Mapping
        let nameToId: [String: Int] = [
            "Hauptgebäude": 15, "Rohstofflager": 10, "Lager": 10,
            "Kornspeicher": 11, "Versammlungsplatz": 16,
            "Kaserne": 19, "Stall": 20, "Werkstatt": 21,
            "Akademie": 22, "Schmiede": 13, "Marktplatz": 17,
            "Botschaft": 18, "Residenz": 25, "Palast": 26,
            "Schatzkammer": 27, "Rathaus": 24, "Versteck": 23,
            "Sägewerk": 5, "Lehmbrennerei": 6, "Eisenschmelze": 7,
            "Getreidemühle": 8, "Bäckerei": 9, "Turnierplatz": 14,
            "Handelskontor": 28,
        ]

        guard let buildingId = nameToId[name] else { return false }
        return slotBuildingIds.enumerated().contains { i, bid in
            bid == buildingId && slotLevels[i] >= requiredLevel
        }
    }

    /// Prüft ob alle Voraussetzungen eines Gebäudes erfüllt sind
    func allPrerequisitesMet(for building: Building) -> Bool {
        building.prerequisites.allSatisfy { prerequisiteMet($0) }
    }

    mutating func apply(_ upgrade: SingleUpgrade) {
        switch upgrade.source {
        case .resourceField(let idx, _):
            fieldLevels[idx] = upgrade.toLevel
        case .existingBuilding(let idx, _):
            slotLevels[idx] = upgrade.toLevel
        case .newBuilding(let idx, let bid):
            slotBuildingIds[idx] = bid
            slotLevels[idx] = upgrade.toLevel
        }
    }
}

// MARK: - Einzelnes Level-Upgrade

private struct SingleUpgrade {
    let source: PopBuildSource
    let name: String
    let icon: String
    let fromLevel: Int
    let toLevel: Int
    let cost: ResourceCost
}

// MARK: - Bundled Candidate (ggf. mehrere Stufen ohne Pop-Zuwachs zusammengefasst)

private struct BundledCandidate {
    let levels: [SingleUpgrade]
    let bundledCost: Int       // Summe aller Rohstoffkosten im Bundle
    let bundledPopGain: Int    // Pop-Zuwachs am Ende des Bundles
}

// MARK: - Kandidaten-Suche

private extension PopulationPlanCalculator {

    static let multiInstanceIds: Set<Int> = [10, 11, 23] // Rohstofflager, Kornspeicher, Versteck

    static func findCheapestCandidate(state: SimState) -> BundledCandidate? {
        var candidates: [BundledCandidate] = []

        // 1. Rohstofffelder
        for (index, currentLevel) in state.fieldLevels.enumerated() {
            guard currentLevel < 20 else { continue }
            if let bundle = buildBundle(
                currentLevel: currentLevel,
                maxLevel: 20,
                popAt: { state.fieldTypes[index].population(at: $0) },
                costAt: { state.fieldTypes[index].resourceCost(at: $0) },
                makeSource: { .resourceField(fieldIndex: index, resourceType: state.fieldTypes[index]) },
                name: "\(state.fieldTypes[index].name) #\(index + 1)",
                icon: state.fieldTypes[index].icon
            ) {
                candidates.append(bundle)
            }
        }

        // 2. Belegte Gebäude-Slots
        for (slotIdx, buildingId) in state.slotBuildingIds.enumerated() {
            guard let bid = buildingId else { continue }
            guard let building = Building.allBuildings.first(where: { $0.id == bid }) else { continue }
            let currentLevel = state.slotLevels[slotIdx]
            guard currentLevel < building.maxLevel else { continue }

            if let bundle = buildBundle(
                currentLevel: currentLevel,
                maxLevel: building.maxLevel,
                popAt: { level in
                    guard level >= 1 && level <= building.levels.count else { return 0 }
                    return building.levels[level - 1].pop
                },
                costAt: { level in
                    guard level >= 1 && level <= building.levels.count else {
                        return ResourceCost(wood: 0, clay: 0, iron: 0, crop: 0)
                    }
                    let l = building.levels[level - 1]
                    return ResourceCost(wood: l.wood, clay: l.clay, iron: l.iron, crop: l.crop)
                },
                makeSource: { .existingBuilding(slotIndex: slotIdx, buildingId: bid) },
                name: building.name,
                icon: building.icon
            ) {
                candidates.append(bundle)
            }
        }

        // 3. Leere Slots — neue Gebäude vorschlagen
        let emptySlots = state.slotBuildingIds.enumerated().filter { $0.element == nil }
        if !emptySlots.isEmpty {
            let eligible = eligibleNewBuildings(state: state)
            for building in eligible {
                guard let firstEmpty = emptySlots.first(where: { idx, _ in
                    // Slot 2 = nur Rally Point
                    if idx == 1 { return building.id == 16 }
                    return building.id != 16
                }) else { continue }

                let slotIdx = firstEmpty.offset
                guard building.levels.count >= 1 else { continue }
                let l = building.levels[0]
                let pop = l.pop
                let cost = ResourceCost(wood: l.wood, clay: l.clay, iron: l.iron, crop: l.crop)

                guard pop > 0 else { continue } // Nur Gebäude die Pop bringen

                let upgrade = SingleUpgrade(
                    source: .newBuilding(slotIndex: slotIdx, buildingId: building.id),
                    name: "\(building.name) (neu)",
                    icon: building.icon,
                    fromLevel: 0,
                    toLevel: 1,
                    cost: cost
                )
                candidates.append(BundledCandidate(
                    levels: [upgrade],
                    bundledCost: cost.total,
                    bundledPopGain: pop
                ))
            }
        }

        guard !candidates.isEmpty else { return nil }

        // Sortiere nach bundledCost aufsteigend (günstigste zuerst)
        return candidates.min(by: { $0.bundledCost < $1.bundledCost })
    }

    /// Baut ein Bundle: wenn die nächste Stufe 0 Pop-Zuwachs gibt,
    /// schaue voraus bis eine Stufe Pop bringt. Summiere alle Kosten.
    static func buildBundle(
        currentLevel: Int,
        maxLevel: Int,
        popAt: (Int) -> Int,
        costAt: (Int) -> ResourceCost,
        makeSource: () -> PopBuildSource,
        name: String,
        icon: String
    ) -> BundledCandidate? {
        let currentPop = currentLevel > 0 ? popAt(currentLevel) : 0
        var bundledCost = 0
        var upgrades: [SingleUpgrade] = []

        for level in (currentLevel + 1)...min(maxLevel, 20) {
            let cost = costAt(level)
            bundledCost += cost.total
            let popAtLevel = popAt(level)
            let popGain = popAtLevel - currentPop

            upgrades.append(SingleUpgrade(
                source: makeSource(),
                name: name,
                icon: icon,
                fromLevel: level - 1,
                toLevel: level,
                cost: cost
            ))

            if popGain > 0 {
                return BundledCandidate(
                    levels: upgrades,
                    bundledCost: bundledCost,
                    bundledPopGain: popGain
                )
            }
        }

        // Keine Stufe bringt mehr Pop → nicht nutzbar
        guard !upgrades.isEmpty else { return nil }
        let finalPop = popAt(min(maxLevel, 20))
        let totalGain = finalPop - currentPop
        guard totalGain > 0 else { return nil }

        return BundledCandidate(
            levels: upgrades,
            bundledCost: bundledCost,
            bundledPopGain: totalGain
        )
    }

    /// Ermittelt welche Gebäude in leere Slots gebaut werden können
    static func eligibleNewBuildings(state: SimState) -> [Building] {
        let usedIds = Set(state.slotBuildingIds.compactMap { $0 })
        // Ressourcenfeld-IDs (1-4), WW/Hauptstadt-Gebäude, Wassergraben (braucht Stadt = 500 Pop)
        let excludedIds: Set<Int> = [1, 2, 3, 4, 34, 38, 39, 42]
        // Residenz (25) / Palast (26): nur eines von beiden baubar
        let residenzPalastIds: Set<Int> = [25, 26]

        return Building.allBuildings.filter { building in
            guard !excludedIds.contains(building.id) else { return false }
            guard building.tribe == nil else { return false }

            // Voraussetzungen prüfen (Hauptgebäude X, Kaserne Y, etc.)
            guard state.allPrerequisitesMet(for: building) else { return false }

            // Residenz/Palast: nur eines von beiden
            if residenzPalastIds.contains(building.id) {
                let hasResidenzOrPalast = usedIds.contains(25) || usedIds.contains(26)
                if hasResidenzOrPalast { return false }
            }

            if multiInstanceIds.contains(building.id) {
                // Multi-Instanz: zweites nur wenn alle bestehenden auf Max-Level
                let existing = state.slotBuildingIds.enumerated()
                    .filter { $0.element == building.id }
                if existing.isEmpty { return true }
                return existing.allSatisfy { state.slotLevels[$0.offset] >= building.maxLevel }
            } else {
                return !usedIds.contains(building.id)
            }
        }
    }
}
