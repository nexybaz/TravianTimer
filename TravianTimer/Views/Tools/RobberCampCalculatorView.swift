import SwiftUI

// MARK: - Räuberlager-Rechner

struct RobberCampCalculatorView: View {

    @Environment(AuthService.self) var authService
    @State private var heroStore = HeroStore.shared

    @State private var selectedClan: RobberClanType = .snake
    @State private var minCropText = "500"
    @State private var maxCropText = "3000"
    @State private var includeHero = false

    private let profile = ProfileStore.shared
    private static let statsLookup = buildStatsLookup()

    // MARK: Body

    var body: some View {
        List {
            // MARK: Clan-Typ
            Section {
                Picker("Clan-Typ", selection: $selectedClan) {
                    ForEach(RobberClanType.allCases) { clan in
                        Text(clan.rawValue).tag(clan)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                HStack(spacing: 6) {
                    Image(systemName: selectedClan.icon)
                        .foregroundStyle(selectedClan.color)
                    Text("Wertet: **\(selectedClan.statLabel)**")
                        .font(.subheadline)
                }
            }

            // MARK: Crop/h Limits
            Section("Beitrag (Crop/h)") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min").font(.caption).foregroundStyle(.secondary)
                        TextField("Min", text: $minCropText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max").font(.caption).foregroundStyle(.secondary)
                        TextField("Max", text: $maxCropText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            // MARK: Held-Boni
            Section {
                Toggle(isOn: $includeHero) {
                    Label("Held-Boni einberechnen", systemImage: "person.fill")
                }

                if includeHero, let bonuses = heroBonuses {
                    HStack {
                        Text(selectedClan == .wolf ? "Off-Bonus" : "Def-Bonus")
                            .font(.caption)
                        Spacer()
                        let pct = selectedClan == .wolf ? bonuses.offBonusPercent : bonuses.defBonusPercent
                        Text(String(format: "+%.1f%%", pct))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(selectedClan.color)
                    }

                    if let tb = bonuses.troopBonus {
                        HStack {
                            Text(tb.troopName)
                                .font(.caption)
                            Spacer()
                            Text(selectedClan == .wolf
                                 ? "+\(tb.attackPerTroop) Ang/Truppe"
                                 : "+\(tb.defensePerTroop) Def/Truppe")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(selectedClan.color)
                        }
                    }
                }
            }

            // MARK: Ergebnis
            if villagesWithTroops.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Truppen vorhanden",
                        systemImage: "shield.slash",
                        description: Text("Importiere zuerst Truppen in der Truppenübersicht.")
                    )
                }
            } else if let best = bestResult {
                // Empfohlenes Dorf
                Section("Empfohlenes Dorf") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(best.villageName)
                                    .font(.headline)
                                Text("\(best.totalRelevantStat) \(selectedClan.statLabel)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(selectedClan.color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(best.totalCropPerHour) Crop/h")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if best.meetsMinimum {
                                    Label("Erfüllt Min.", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Label("Unter Min.", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Truppenaufteilung
                if !best.allocations.isEmpty {
                    Section("Truppenaufteilung") {
                        ForEach(best.allocations) { alloc in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alloc.troopKind.uiName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(alloc.count) Einheiten")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(alloc.totalStat) \(selectedClan.shortLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(selectedClan.color)
                                    Text("\(alloc.cropPerHour) Crop/h")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Alle Dörfer
                if allResults.count > 1 {
                    Section {
                        DisclosureGroup("Alle Dörfer (\(allResults.count))") {
                            ForEach(allResults) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.villageName)
                                            .font(.subheadline)
                                            .fontWeight(result.id == best.id ? .semibold : .regular)
                                        Text("\(result.allocations.count) Truppentypen")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(result.totalRelevantStat)")
                                            .font(.subheadline)
                                            .foregroundStyle(selectedClan.color)
                                        HStack(spacing: 4) {
                                            Text("\(result.totalCropPerHour) Crop/h")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if !result.meetsMinimum {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                                .listRowBackground(
                                    result.id == best.id
                                        ? selectedClan.color.opacity(0.08)
                                        : Color.clear
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Räuberlager")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var minCrop: Int { Int(minCropText) ?? 0 }
    private var maxCrop: Int { Int(maxCropText) ?? 0 }

    private var currentTribe: Tribe {
        Tribe.from(profileTribe: authService.profile?.tribe)
    }

    private var heroBonuses: HeroBonusSummary? {
        guard includeHero else { return nil }
        let ws: Int = {
            if let wsStr = authService.profile?.worldSpeed, let speed = Int(wsStr), speed > 0 { return speed }
            return 1
        }()
        return HeroBonusCalculator.calculate(config: heroStore.config, tribe: currentTribe, worldSpeed: ws)
    }

    private var villagesWithTroops: [VillageProfile] {
        profile.villages.filter { !$0.troopCounts.isEmpty }
    }

    private var allResults: [VillageResult] {
        guard maxCrop > 0 else { return [] }
        return villagesWithTroops
            .map { optimize(village: $0, clan: selectedClan, minCrop: minCrop, maxCrop: maxCrop) }
            .sorted { $0.totalRelevantStat > $1.totalRelevantStat }
    }

    private var bestResult: VillageResult? {
        allResults.first
    }

    // MARK: - Algorithmus

    private func optimize(village: VillageProfile, clan: RobberClanType, minCrop: Int, maxCrop: Int) -> VillageResult {
        // 1. Kandidaten sammeln
        var candidates: [(kind: TroopKind, count: Int, stat: Int, crop: Int, efficiency: Double)] = []

        for (rawKey, count) in village.troopCounts {
            guard count > 0,
                  let kind = TroopKind(rawValue: rawKey),
                  let unit = Self.statsLookup[kind] else { continue }

            var stat = clan.relevantStat(from: unit)
            if let bonuses = heroBonuses {
                stat = clan.applyHeroBonus(baseStat: stat, troopName: kind.uiName, bonuses: bonuses)
            }
            guard stat > 0 else { continue }

            let crop = kind.cropPerHour
            guard crop > 0 else { continue }

            let efficiency = Double(stat) / Double(crop)
            candidates.append((kind, count, stat, crop, efficiency))
        }

        // 2. Nach Effizienz sortieren (beste zuerst)
        candidates.sort { $0.efficiency > $1.efficiency }

        // 3. Greedy auffüllen
        var allocations: [TroopAllocation] = []
        var remainingCrop = maxCrop

        for c in candidates {
            guard remainingCrop > 0 else { break }

            let maxAffordable = remainingCrop / c.crop
            let actualCount = min(maxAffordable, c.count)
            guard actualCount > 0 else { continue }

            allocations.append(TroopAllocation(
                troopKind: c.kind,
                count: actualCount,
                cropPerHour: actualCount * c.crop,
                totalStat: actualCount * c.stat,
                statPerCrop: c.efficiency
            ))
            remainingCrop -= actualCount * c.crop
        }

        let totalCrop = allocations.reduce(0) { $0 + $1.cropPerHour }
        let totalStat = allocations.reduce(0) { $0 + $1.totalStat }

        return VillageResult(
            id: village.id,
            villageName: village.name,
            allocations: allocations,
            totalCropPerHour: totalCrop,
            totalRelevantStat: totalStat,
            meetsMinimum: totalCrop >= minCrop
        )
    }

    // MARK: - TroopKind → TroopUnit Lookup

    private static func buildStatsLookup() -> [TroopKind: TroopUnit] {
        var lookup: [TroopKind: TroopUnit] = [:]
        let tribes: [(String, [TroopUnit])] = [
            ("romans.", TroopsRomansView.units),
            ("teutons.", TroopsTeutonsView.units),
            ("gauls.", TroopsGaulsView.units),
        ]
        for (prefix, units) in tribes {
            let kinds = TroopKind.allCases.filter { $0.rawValue.hasPrefix(prefix) }
            for (i, kind) in kinds.enumerated() where i < units.count {
                lookup[kind] = units[i]
            }
        }
        return lookup
    }
}

// MARK: - Clan Type

private enum RobberClanType: String, CaseIterable, Identifiable {
    case bear = "Bärenclan"
    case snake = "Schlangenclan"
    case wolf = "Wolfclan"

    var id: String { rawValue }

    var statLabel: String {
        switch self {
        case .bear:  return "Def. Kavallerie"
        case .snake: return "Def. Infanterie"
        case .wolf:  return "Angriff"
        }
    }

    var shortLabel: String {
        switch self {
        case .bear:  return "DefKav"
        case .snake: return "DefInf"
        case .wolf:  return "Ang"
        }
    }

    var icon: String {
        switch self {
        case .bear:  return "pawprint.fill"
        case .snake: return "leaf.fill"
        case .wolf:  return "dog.fill"
        }
    }

    var color: Color {
        switch self {
        case .bear:  return .brown
        case .snake: return .green
        case .wolf:  return .red
        }
    }

    func relevantStat(from unit: TroopUnit) -> Int {
        switch self {
        case .bear:  return unit.defCavalry
        case .snake: return unit.defInfantry
        case .wolf:  return unit.attack
        }
    }

    func applyHeroBonus(baseStat: Int, troopName: String, bonuses: HeroBonusSummary) -> Int {
        let percentBonus: Double
        switch self {
        case .wolf:          percentBonus = bonuses.offBonusPercent
        case .bear, .snake:  percentBonus = bonuses.defBonusPercent
        }

        var effective = Int(Double(baseStat) * (1.0 + percentBonus / 100.0))

        if let tb = bonuses.troopBonus, troopName == tb.troopName {
            switch self {
            case .wolf:         effective += tb.attackPerTroop
            case .snake, .bear: effective += tb.defensePerTroop
            }
        }

        return effective
    }
}

// MARK: - Result Types

private struct TroopAllocation: Identifiable {
    let id = UUID()
    let troopKind: TroopKind
    let count: Int
    let cropPerHour: Int
    let totalStat: Int
    let statPerCrop: Double
}

private struct VillageResult: Identifiable {
    let id: UUID
    let villageName: String
    let allocations: [TroopAllocation]
    let totalCropPerHour: Int
    let totalRelevantStat: Int
    let meetsMinimum: Bool
}
