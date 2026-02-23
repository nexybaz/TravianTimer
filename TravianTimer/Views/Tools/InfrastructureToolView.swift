import SwiftUI
import WebKit

// MARK: - Infrastruktur Tool (Uebersicht)

struct InfrastructureToolView: View {

    @State private var favorites = FavoritesStore.shared

    private let buildingCostsFavId = FavoriteToolItem.infraBuildingCosts.rawValue

    var body: some View {
        List {
            NavigationLink {
                BuildingCostsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Baukosten")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Kosten, Bauzeit & Boni aller Gebäude")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hammer.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .contextMenu {
                Button {
                    withAnimation { favorites.toggle(buildingCostsFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(buildingCostsFavId) ? "Aus Favoriten entfernen" : "An Tools anheften",
                        systemImage: favorites.isFavorite(buildingCostsFavId) ? "pin.slash" : "pin.fill"
                    )
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    withAnimation { favorites.toggle(buildingCostsFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(buildingCostsFavId) ? "Lösen" : "Anheften",
                        systemImage: favorites.isFavorite(buildingCostsFavId) ? "pin.slash" : "pin.fill"
                    )
                }
                .tint(.orange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Infrastruktur")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Baukosten (Gebaeude-Liste)

struct BuildingCostsView: View {

    @State private var expandedCategories: Set<BuildingCategory> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(BuildingCategory.allCases) { category in
                    CategoryCard(
                        category: category,
                        isExpanded: expandedCategories.contains(category),
                        toggle: { toggleCategory(category) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Baukosten")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleCategory(_ category: BuildingCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: BuildingCategory
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (immer sichtbar) ──
            Button(action: toggle) {
                HStack(spacing: 14) {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(category.color.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(category.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(category.buildings.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(category.color)
                        .frame(width: 28, height: 28)
                        .background(category.color.opacity(0.12))
                        .clipShape(Circle())

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // ── Gebaeude-Liste (ausgeklappt) ──
            if isExpanded {
                Divider()
                    .padding(.leading, 72)

                VStack(spacing: 0) {
                    ForEach(Array(category.buildings.enumerated()), id: \.element.id) { index, building in
                        NavigationLink {
                            BuildingDetailView(building: building)
                        } label: {
                            BuildingListRow(building: building)
                        }
                        .buttonStyle(.plain)

                        if index < category.buildings.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Building List Row

private struct BuildingListRow: View {
    let building: Building

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: building.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(building.category.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(building.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(building.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let tribe = building.tribe {
                Text(tribe)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tribeColor(tribe).opacity(0.8))
                    .clipShape(Capsule())
            }

            Text("1–\(building.maxLevel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func tribeColor(_ tribe: String) -> Color {
        switch tribe {
        case "Römer":   return .blue
        case "Germanen": return .orange
        case "Gallier":  return .green
        default:         return .gray
        }
    }
}

// MARK: - Building Detail (WebView)

struct BuildingDetailView: View {

    let building: Building

    @Environment(AuthService.self) var authService

    @State private var gameSpeed: Int = 1
    @State private var mainBuildingLevel: Int = 0
    @State private var isLoading: Bool = true

    /// Fealty-Level aus globalem Profil (fallback 0)
    private var fealtyLevel: Int {
        authService.profile?.fealtyLevel ?? 0
    }

    /// Prestige-Level aus globalem Profil (fallback 0)
    private var prestigeLevel: Int {
        authService.profile?.prestigeLevel ?? 0
    }

    /// Gebäudekosten-Reduktion durch Treue (Level 12+)
    /// Offizielle Formel: g = 1 - (0.5 * (fealtyLevel - 11 + prestigeBonus)) / 100
    private var fealtyCostReduction: Double {
        guard fealtyLevel >= 12 else { return 0.0 }
        let prestigeBonus: Double = prestigeLevel >= 12 ? 1.0 : 0.0
        let reduction = 0.5 * (Double(fealtyLevel) - 11.0 + prestigeBonus)
        return reduction / 100.0
    }

    /// Bauzeit-Reduktion durch Treue (Level 11+)
    /// Offizielle Formel aus ue(): Level 11→1%, 12→1.5%, 13+→(level-11)%, Prestige→+1%
    private var fealtyTimeReduction: Double {
        guard fealtyLevel >= 11 else { return 0.0 }
        var reduction: Double
        switch fealtyLevel {
        case 11: reduction = 1.0
        case 12: reduction = 1.5
        default: reduction = Double(min(fealtyLevel, 20) - 11)
        }
        if prestigeLevel >= 11 { reduction += 1.0 }
        return reduction / 100.0
    }

    private var webURL: URL? {
        URL(string: "https://tk-kb.kingdoms.com/en-US/buildings/\(building.id)")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Konfigurations-Leiste ──
            VStack(spacing: 8) {
                // Spielgeschwindigkeit
                HStack {
                    Text("Geschwindigkeit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach([1, 2, 3, 5], id: \.self) { speed in
                            Button {
                                gameSpeed = speed
                            } label: {
                                Text("\(speed)×")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(gameSpeed == speed ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(gameSpeed == speed ? Color.accentColor : Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // HG-Stufe
                HStack {
                    Image(systemName: "hammer.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Hauptgebäude")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $mainBuildingLevel, in: 0...20) {
                        Text("Stufe \(mainBuildingLevel)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .fixedSize()
                }

                // Treue-Level (global aus Profil, einstellbar in Einstellungen)
                if fealtyLevel > 0 || prestigeLevel > 0 {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Treue \(fealtyLevel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if prestigeLevel > 0 {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Prestige \(prestigeLevel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if fealtyCostReduction > 0 {
                            Text(String(format: "Kosten −%.1f%%", fealtyCostReduction * 100))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            // ── Gebaeude-Info Header ──
            HStack(spacing: 12) {
                Image(systemName: building.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(building.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(building.name)
                        .font(.headline)
                    Text(building.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let tribe = building.tribe {
                    Text(tribe)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tribeColor(tribe))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // ── Voraussetzungen ──
            if !building.prerequisites.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(building.prerequisites.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))
                Divider()
            }

            // ── Daten-Tabelle ──
            BuildingLevelsTable(
                building: building,
                gameSpeed: gameSpeed,
                mainBuildingLevel: mainBuildingLevel,
                fealtyCostReduction: fealtyCostReduction,
                fealtyTimeReduction: fealtyTimeReduction
            )
        }
        .navigationTitle(building.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tribeColor(_ tribe: String) -> Color {
        switch tribe {
        case "Römer":   return .blue
        case "Germanen": return .orange
        case "Gallier":  return .green
        default:         return .gray
        }
    }
}

// MARK: - Building Levels Table

struct BuildingLevelsTable: View {

    let building: Building
    let gameSpeed: Int
    let mainBuildingLevel: Int
    let fealtyCostReduction: Double    // z.B. 0.025 = 2.5%
    let fealtyTimeReduction: Double    // z.B. 0.05 = 5%

    /// Reduzierte Ressourcenkosten für ein Level (floor wie im Spiel)
    private func adjustedCost(_ base: Int) -> Int {
        guard fealtyCostReduction > 0 else { return base }
        return max(0, Int(floor(Double(base) * (1.0 - fealtyCostReduction))))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                levelHeaderRow

                // Daten
                ForEach(building.levels) { level in
                    levelRow(level)
                    if level.level < building.maxLevel {
                        Divider().padding(.leading, 40)
                    }
                }

                // Summe
                if building.levels.count > 1 {
                    sumRow
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var levelHeaderRow: some View {
        HStack(spacing: 0) {
            headerCell("Stufe", width: 40)
            headerCell("🪵", width: nil)
            headerCell("🧱", width: nil)
            headerCell("⚙️", width: nil)
            headerCell("🌾", width: nil)
            headerCell("⏱️", width: 60)
            headerCell("Σ", width: nil)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
    }

    private func headerCell(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .frame(maxWidth: width ?? .infinity)
    }

    private func levelRow(_ level: BuildingLevel) -> some View {
        let w = adjustedCost(level.wood)
        let c = adjustedCost(level.clay)
        let i = adjustedCost(level.iron)
        let cr = adjustedCost(level.crop)

        return HStack(spacing: 0) {
            // Stufe
            Text("\(level.level)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(levelColor(level.level))
                .clipShape(Circle())
                .frame(width: 40)

            // Ressourcen (treue-angepasst)
            resourceCell(w, reduced: fealtyCostReduction > 0)
            resourceCell(c, reduced: fealtyCostReduction > 0)
            resourceCell(i, reduced: fealtyCostReduction > 0)
            resourceCell(cr, reduced: fealtyCostReduction > 0)

            // Bauzeit (angepasst)
            Text(adjustedBuildTime(level.baseTimeSec))
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 60)

            // Gesamtressourcen
            Text(formatNumber(w + c + i + cr))
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    private func resourceCell(_ value: Int, reduced: Bool = false) -> some View {
        Text(formatNumber(value))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(reduced ? .green : .primary)
            .frame(maxWidth: .infinity)
    }

    private var sumRow: some View {
        let totalWood = building.levels.reduce(0) { $0 + adjustedCost($1.wood) }
        let totalClay = building.levels.reduce(0) { $0 + adjustedCost($1.clay) }
        let totalIron = building.levels.reduce(0) { $0 + adjustedCost($1.iron) }
        let totalCrop = building.levels.reduce(0) { $0 + adjustedCost($1.crop) }
        let totalAll = totalWood + totalClay + totalIron + totalCrop

        return HStack(spacing: 0) {
            Text("Σ")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 40)

            sumCell(totalWood)
            sumCell(totalClay)
            sumCell(totalIron)
            sumCell(totalCrop)

            Text("")
                .frame(width: 60)

            Text(formatNumber(totalAll))
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func sumCell(_ value: Int) -> some View {
        Text(formatNumber(value))
            .font(.system(.caption2, design: .monospaced))
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func adjustedBuildTime(_ baseSec: Int) -> String {
        // Spielgeschwindigkeit
        var seconds = Double(baseSec) / Double(gameSpeed)

        // Hauptgebaeude-Reduktion
        if mainBuildingLevel > 0 {
            let reductionFactor = mainBuildingReduction(level: mainBuildingLevel)
            seconds *= reductionFactor
        }

        // Treue-Reduktion (Bauzeit)
        if fealtyTimeReduction > 0 {
            seconds *= (1.0 - fealtyTimeReduction)
        }

        let totalSec = max(1, Int(seconds))
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        let s = totalSec % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// Hauptgebaeude-Reduktionsfaktor (Level 1 = 96%, Level 20 = 50%)
    private func mainBuildingReduction(level: Int) -> Double {
        // Formel aus Travian: Bauzeit * (100% - Reduktion%) / 100
        let reductions: [Double] = [
            1.00,                                      // Level 0
            0.96, 0.93, 0.90, 0.86, 0.83,            // 1-5
            0.80, 0.77, 0.75, 0.72, 0.69,            // 6-10
            0.67, 0.64, 0.62, 0.60, 0.58,            // 11-15
            0.56, 0.54, 0.52, 0.50, 0.50             // 16-20
        ]
        guard level >= 0, level <= 20 else { return 1.0 }
        return reductions[level]
    }

    private func levelColor(_ level: Int) -> Color {
        if level <= 5      { return .gray }
        if level <= 10     { return .blue }
        if level <= 15     { return .orange }
        return .red
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            let k = Double(value) / 1000.0
            return String(format: "%.0fk", k)
        }
        return "\(value)"
    }
}

// MARK: - Building Category

enum BuildingCategory: String, CaseIterable, Identifiable {
    case resources
    case infrastructure
    case military

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resources:      return "Ressourcen"
        case .infrastructure: return "Infrastruktur"
        case .military:       return "Militär"
        }
    }

    var icon: String {
        switch self {
        case .resources:      return "leaf.fill"
        case .infrastructure: return "building.2.fill"
        case .military:       return "shield.lefthalf.filled"
        }
    }

    var subtitle: String {
        switch self {
        case .resources:      return "Holz, Lehm, Eisen, Getreide & Veredelung"
        case .infrastructure: return "Lager, Handel, Verwaltung & Ausbau"
        case .military:       return "Kaserne, Stall, Mauern & Verteidigung"
        }
    }

    var color: Color {
        switch self {
        case .resources:      return .green
        case .infrastructure: return .blue
        case .military:       return .red
        }
    }

    var buildings: [Building] {
        Building.allBuildings.filter { $0.category == self }
    }
}

// MARK: - Building Level Data

struct BuildingLevel: Identifiable {
    let level: Int
    let wood: Int
    let clay: Int
    let iron: Int
    let crop: Int
    let pop: Int
    let cp: Int
    let baseTimeSec: Int    // Bauzeit in Sekunden (1x Speed, kein HG)
    let bonusValue: Double  // Gebaeude-spezifischer Bonus

    var id: Int { level }

    var bonusDisplay: String {
        if bonusValue == bonusValue.rounded() {
            return "\(Int(bonusValue))"
        }
        return String(format: "%.1f%%", bonusValue)
    }
}

// MARK: - Building Model

struct Building: Identifiable, Hashable {
    let id: Int                    // Travian Building ID
    let name: String
    let category: BuildingCategory
    let icon: String
    let shortDescription: String
    let tribe: String?             // nil = alle Voelker
    let maxLevel: Int
    let prerequisites: [String]
    let bonusLabel: String?        // z.B. "Produktion", "Kapazität", nil = kein Bonus
    let levels: [BuildingLevel]

    // Hashable / Equatable via ID
    static func == (lhs: Building, rhs: Building) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - All Buildings Data

extension Building {

    static let allBuildings: [Building] = resourceBuildings + infrastructureBuildings + militaryBuildings

    // ────────────────────────────────────────────
    // MARK: Ressourcen-Gebaeude
    // ────────────────────────────────────────────

    static let resourceBuildings: [Building] = [
        woodcutter, clayPit, ironMine, cropland,
        sawmill, brickyard, ironFoundry, grainMill, bakery,
    ]

    static let woodcutter = Building(
        id: 1, name: "Holzfäller", category: .resources,
        icon: "tree.fill",
        shortDescription: "Produziert Holz",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Produktion",
        levels: makeLevels(costs: [
            (40,100,50,60,2,1,24), (65,165,85,100,3,1,108),
            (110,280,140,165,4,2,360), (185,465,235,280,5,2,1440),
            (310,780,390,465,6,2,2880), (520,1300,650,780,8,3,5760),
            (870,2170,1085,1300,10,4,8640), (1450,3625,1810,2175,12,4,17280),
            (2420,6050,3025,3630,14,5,25920), (4040,10105,5050,6060,16,6,38880),
            (6750,16870,8435,10125,18,7,51840), (11270,28175,14090,16905,20,9,64800),
            (18820,47055,23525,28230,22,11,77760), (31430,78580,39290,47150,24,13,95040),
            (52490,131230,65615,78740,26,15,108000), (87660,219155,109575,131490,29,18,129600),
            (146395,365985,182995,219590,32,22,172800), (244480,611195,305600,366715,35,27,216000),
            (408280,1020695,510350,612420,38,32,259200), (681825,1704565,852280,1022740,41,38,345600),
        ], bonuses: [5,9,15,22,33,50,70,100,145,200,280,375,495,635,800,1000,1300,1600,2000,2500])
    )

    static let clayPit = Building(
        id: 2, name: "Lehmgrube", category: .resources,
        icon: "square.stack.3d.up.fill",
        shortDescription: "Produziert Lehm",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Produktion",
        levels: makeLevels(costs: [
            (80,40,80,50,2,1,22), (135,65,135,85,3,1,99),
            (225,110,225,140,4,2,330), (375,185,375,235,5,2,1320),
            (620,310,620,390,6,2,2640), (1040,520,1040,650,8,3,5280),
            (1735,870,1735,1085,10,4,7920), (2900,1450,2900,1810,12,4,15840),
            (4840,2420,4840,3025,14,5,23760), (8080,4040,8080,5050,16,6,35640),
            (13500,6750,13500,8435,18,7,47520), (22540,11270,22540,14090,20,9,59400),
            (37645,18820,37645,23525,22,11,71280), (62865,31430,62865,39290,24,13,87120),
            (104985,52490,104985,65615,26,15,99000), (175320,87660,175320,109575,29,18,118800),
            (292790,146395,292790,182995,32,22,158400), (488955,244480,488955,305600,35,27,198000),
            (816555,408280,816555,510350,38,32,237600), (1363650,681825,1363650,852280,41,38,316800),
        ], bonuses: [5,9,15,22,33,50,70,100,145,200,280,375,495,635,800,1000,1300,1600,2000,2500])
    )

    static let ironMine = Building(
        id: 3, name: "Eisenmine", category: .resources,
        icon: "diamond.fill",
        shortDescription: "Produziert Eisen",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Produktion",
        levels: makeLevels(costs: [
            (100,80,30,60,3,1,30), (165,135,50,100,5,1,135),
            (280,225,85,165,7,2,450), (465,375,140,280,9,2,1800),
            (780,620,235,465,11,2,3600), (1300,1040,390,780,13,3,7200),
            (2170,1735,650,1300,15,4,10800), (3625,2900,1085,2175,17,4,21600),
            (6050,4840,1815,3630,19,5,32400), (10105,8080,3030,6060,21,6,48600),
            (16870,13500,5060,10125,24,7,64800), (28175,22540,8455,16905,27,9,81000),
            (47055,37645,14115,28230,30,11,97200), (78580,62865,23575,47150,33,13,118800),
            (131230,104985,39370,78740,36,15,135000), (219155,175320,65745,131490,39,18,162000),
            (365985,292790,109795,219590,42,22,216000), (611195,488955,183360,366715,45,27,270000),
            (1020695,816555,306210,612420,48,32,324000), (1704565,1363650,511370,1022740,51,38,432000),
        ], bonuses: [5,9,15,22,33,50,70,100,145,200,280,375,495,635,800,1000,1300,1600,2000,2500])
    )

    static let cropland = Building(
        id: 4, name: "Getreidefeld", category: .resources,
        icon: "leaf.fill",
        shortDescription: "Produziert Getreide",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Produktion",
        levels: makeLevels(costs: [
            (75,90,85,0,0,1,20), (125,150,140,0,0,1,90),
            (210,250,235,0,0,2,300), (350,420,395,0,0,2,1200),
            (585,700,660,0,0,2,2400), (975,1170,1105,0,1,3,4800),
            (1625,1950,1845,0,2,4,7200), (2715,3260,3080,0,3,4,14400),
            (4535,5445,5140,0,4,5,21600), (7575,9095,8590,0,5,6,32400),
            (12655,15185,14340,0,6,7,43200), (21130,25360,23950,0,7,9,54000),
            (35290,42350,39995,0,8,11,64800), (58935,70720,66795,0,9,13,79200),
            (98420,118105,111545,0,10,15,90000), (164365,197240,186280,0,12,18,108000),
            (274490,329385,311085,0,14,22,144000), (458395,550075,519515,0,16,27,180000),
            (765520,918625,867590,0,18,32,216000), (1278420,1534105,1448880,0,20,38,288000),
        ], bonuses: [5,9,15,22,33,50,70,100,145,200,280,375,495,635,800,1000,1300,1600,2000,2500])
    )

    static let sawmill = Building(
        id: 5, name: "Sägewerk", category: .resources,
        icon: "gearshape.2.fill",
        shortDescription: "+25% Holzproduktion",
        tribe: nil, maxLevel: 5,
        prerequisites: ["Holzfäller 10", "Hauptgebäude 5"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (520,380,290,90,4,1,480), (935,685,520,160,6,1,1500),
            (1685,1230,940,290,8,2,3300), (3035,2215,1690,525,10,2,8400),
            (5460,3990,3045,945,12,2,14400),
        ], bonuses: [5,10,15,20,25])
    )

    static let brickyard = Building(
        id: 6, name: "Lehmbrennerei", category: .resources,
        icon: "flame.fill",
        shortDescription: "+25% Lehmproduktion",
        tribe: nil, maxLevel: 5,
        prerequisites: ["Lehmgrube 10", "Hauptgebäude 5"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (440,480,320,50,3,1,480), (790,865,575,90,5,1,1500),
            (1425,1555,1035,160,7,2,3300), (2565,2800,1865,290,9,2,8400),
            (4620,5040,3360,525,11,2,14400),
        ], bonuses: [5,10,15,20,25])
    )

    static let ironFoundry = Building(
        id: 7, name: "Eisenschmelze", category: .resources,
        icon: "bolt.fill",
        shortDescription: "+25% Eisenproduktion",
        tribe: nil, maxLevel: 5,
        prerequisites: ["Eisenmine 10", "Hauptgebäude 5"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (200,450,510,120,6,1,480), (360,810,920,215,9,1,1500),
            (650,1460,1650,390,12,2,3300), (1165,2625,2975,700,15,2,8400),
            (2100,4725,5355,1260,18,2,14400),
        ], bonuses: [5,10,15,20,25])
    )

    static let grainMill = Building(
        id: 8, name: "Getreidemühle", category: .resources,
        icon: "circle.grid.cross.fill",
        shortDescription: "+25% Getreideproduktion",
        tribe: nil, maxLevel: 5,
        prerequisites: ["Getreidefeld 5"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (500,440,380,1240,3,1,480), (900,790,685,2230,5,1,1500),
            (1620,1425,1230,4020,7,2,3300), (2915,2565,2215,7230,9,2,8400),
            (5250,4620,3990,13015,11,2,14400),
        ], bonuses: [5,10,15,20,25])
    )

    static let bakery = Building(
        id: 9, name: "Bäckerei", category: .resources,
        icon: "birthday.cake.fill",
        shortDescription: "+25% Getreideproduktion",
        tribe: nil, maxLevel: 5,
        prerequisites: ["Getreidefeld 10", "Hauptgebäude 5", "Getreidemühle 5"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (1200,1480,870,1600,4,1,780), (2160,2665,1565,2880,6,1,1800),
            (3890,4795,2820,5185,8,2,3600), (7000,8630,5075,9330,10,2,8700),
            (12595,15535,9135,16795,12,2,14700),
        ], bonuses: [5,10,15,20,25])
    )

    // ────────────────────────────────────────────
    // MARK: Infrastruktur-Gebaeude (offizielle Daten)
    // ────────────────────────────────────────────

    static let infrastructureBuildings: [Building] = [
        mainBuilding, warehouse, granary,
        marketplace, tradeOffice,
        embassy, residence, palace,
        treasury, townHall, cranny,
        greatWarehouse, greatGranary,
        stonemason,
    ]

    static let mainBuilding = Building(
        id: 15, name: "Hauptgebäude", category: .infrastructure,
        icon: "hammer.fill",
        shortDescription: "Reduziert Bauzeit",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (70,40,60,20,2,2,32), (95,55,80,25,3,3,243),
            (125,70,105,35,4,3,518), (165,95,140,45,5,4,972),
            (220,125,190,65,6,5,2268), (290,165,250,85,8,6,5184),
            (385,220,330,110,10,7,7776), (515,295,440,145,12,9,10692),
            (685,390,585,195,14,10,12960), (910,520,780,260,16,12,14904),
            (1210,695,1040,345,18,15,18144), (1610,920,1380,460,20,18,21384),
            (2145,1225,1840,615,22,21,25272), (2850,1630,2445,815,24,26,28512),
            (3795,2170,3250,1085,26,31,33048), (5045,2885,4325,1440,29,37,36936),
            (6710,3835,5750,1915,32,44,42768), (8925,5100,7650,2550,35,53,50544),
            (11870,6780,10175,3390,38,64,58320), (15785,9020,13530,4510,41,77,66096),
        ], bonuses: [100,96.4,92.9,89.6,86.4,83.3,80.3,77.4,74.6,71.9,69.3,66.8,64.4,62.1,59.9,57.7,55.6,53.6,51.7,49.8])
    )

    static let warehouse = Building(
        id: 10, name: "Lager", category: .infrastructure,
        icon: "shippingbox.fill",
        shortDescription: "Lagert Holz, Lehm, Eisen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 1"],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (140,180,100,0,1,1,34), (185,240,135,0,2,1,259),
            (250,320,175,0,3,2,552), (330,425,235,0,4,2,1035),
            (440,565,315,0,5,2,2415), (585,750,415,0,6,3,5520),
            (775,995,555,0,7,4,8280), (1030,1325,735,0,8,4,11385),
            (1370,1760,980,0,9,5,13800), (1825,2345,1300,0,10,6,15870),
            (2425,3115,1730,0,12,7,19320), (3225,4145,2305,0,14,9,22770),
            (4290,5515,3065,0,16,11,26910), (5705,7335,4075,0,18,13,30360),
            (7585,9755,5420,0,20,15,35190), (10090,12975,7205,0,22,18,39330),
            (13420,17255,9585,0,24,22,45540), (17850,22950,12750,0,26,27,53820),
            (23740,30520,16955,0,28,32,62100), (31575,40595,22550,0,30,38,70380),
        ], bonuses: [1200,1700,2300,3100,4000,5000,6300,7700,9600,12000,14400,18000,22000,26000,32000,38000,45000,55000,66000,80000])
    )

    static let granary = Building(
        id: 11, name: "Kornspeicher", category: .infrastructure,
        icon: "basket.fill",
        shortDescription: "Lagert Getreide",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 1"],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (80,100,70,20,1,1,33), (105,135,95,25,2,1,248),
            (140,175,125,35,3,2,528), (190,235,165,45,4,2,990),
            (250,315,220,65,5,2,2310), (335,415,290,85,6,3,5280),
            (445,555,385,110,7,4,7920), (590,735,515,145,8,4,10890),
            (785,980,685,195,9,5,13200), (1040,1300,910,260,10,6,15180),
            (1385,1730,1210,345,12,7,18480), (1845,2305,1610,460,14,9,21780),
            (2450,3065,2145,615,16,11,25740), (3260,4075,2850,815,18,13,29040),
            (4335,5420,3795,1085,20,15,33660), (5765,7205,5045,1440,22,18,37620),
            (7670,9585,6710,1915,24,22,43560), (10200,12750,8925,2550,26,27,51480),
            (13565,16955,11870,3390,28,32,59400), (18040,22550,15785,4510,30,38,67320),
        ], bonuses: [1200,1700,2300,3100,4000,5000,6300,7700,9600,12000,14400,18000,22000,26000,32000,38000,45000,55000,66000,80000])
    )

    static let marketplace = Building(
        id: 17, name: "Marktplatz", category: .infrastructure,
        icon: "storefront.fill",
        shortDescription: "Ermöglicht Handel",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 3", "Lager 1"],
        bonusLabel: "Händler",
        levels: makeLevels(costs: [
            (80,70,120,70,4,4,34), (100,90,155,90,6,4,252),
            (130,115,195,115,8,5,538), (170,145,250,145,10,6,1008),
            (215,190,320,190,12,7,2352), (275,240,410,240,15,9,5376),
            (350,310,530,310,18,11,8064), (450,395,675,395,21,13,11088),
            (575,505,865,505,24,15,13440), (740,645,1105,645,27,19,15456),
            (945,825,1415,825,30,22,18816), (1210,1060,1815,1060,33,27,22176),
            (1545,1355,2320,1355,36,32,26208), (1980,1735,2970,1735,39,39,29568),
            (2535,2220,3805,2220,42,46,34272), (3245,2840,4870,2840,46,55,38304),
            (4155,3635,6230,3635,50,67,44352), (5315,4650,7975,4650,54,80,52416),
            (6805,5955,10210,5955,58,96,60480), (8710,7620,13065,7620,62,115,68544),
        ], bonuses: Array(1...20).map { Double($0) })
    )

    static let tradeOffice = Building(
        id: 28, name: "Handelskontor", category: .infrastructure,
        icon: "cart.fill",
        shortDescription: "Erhöht Händlerkapazität",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Marktplatz 20", "Stall 10"],
        bonusLabel: "Bonus %",
        levels: makeLevels(costs: [
            (1400,1330,1200,400,3,4,367), (1790,1700,1535,510,5,4,800),
            (2295,2180,1965,655,7,5,1366), (2935,2790,2515,840,9,6,2298),
            (3760,3570,3220,1075,11,7,4962), (4810,4570,4125,1375,13,9,10956),
            (6155,5850,5280,1760,15,11,16284), (7880,7485,6755,2250,17,13,22278),
            (10090,9585,8645,2880,19,15,26940), (12915,12265,11070,3690,21,19,30936),
            (16530,15700,14165,4720,24,22,37596), (21155,20100,18135,6045,27,27,44256),
            (27080,25725,23210,7735,30,32,52248), (34660,32930,29710,9905,33,39,58908),
            (44370,42150,38030,12675,36,46,68232), (56790,53950,48680,16225,39,55,76224),
            (72690,69060,62310,20770,42,67,88212), (93045,88395,79755,26585,45,80,104196),
            (119100,113145,102085,34030,48,96,120180), (152445,144825,130670,43555,51,115,136164),
        ], bonuses: Array(1...20).map { Double($0) * 10 })
    )

    static let embassy = Building(
        id: 18, name: "Botschaft", category: .infrastructure,
        icon: "flag.fill",
        shortDescription: "Diplomatische Beziehungen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 1"],
        bonusLabel: "Oasen",
        levels: makeLevels(costs: [
            (180,130,150,80,3,5,35), (930,890,930,320,5,6,266),
            (1240,1185,1240,425,7,7,566), (1645,1575,1645,565,9,8,1062),
            (2190,2095,2190,750,11,10,2478), (2915,2790,2915,1000,13,12,5664),
            (3875,3710,3875,1330,15,14,8496), (5155,4930,5155,1765,17,17,11682),
            (6855,6560,6855,2350,19,21,14160), (9115,8725,9115,3125,21,25,16284),
            (12125,11605,12125,4155,24,30,19824), (16125,15435,16125,5530,27,36,23364),
            (21445,20525,21445,7350,30,43,27612), (28520,27300,28520,9780,33,51,31152),
            (37935,36310,37935,13005,36,62,36108), (50450,48290,50450,17300,39,74,40356),
            (67100,64225,67100,23005,42,89,46728), (89245,85420,89245,30600,45,106,55224),
            (118695,113605,118695,40695,48,128,63720), (157865,151095,157865,54125,51,153,72216),
        ], bonuses: [1,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,3])
    )

    static let residence = Building(
        id: 25, name: "Residenz", category: .infrastructure,
        icon: "house.lodge.fill",
        shortDescription: "Schützt vor Eroberung",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 5"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (580,460,350,180,1,2,1344), (740,590,450,230,2,3,1628),
            (950,755,575,295,3,3,2001), (1215,965,735,375,4,4,2614),
            (1555,1235,940,485,5,5,4366), (1995,1580,1205,620,6,6,8308),
            (2550,2025,1540,790,7,7,11812), (3265,2590,1970,1015,8,9,15754),
            (4180,3315,2520,1295,9,10,18820), (5350,4245,3230,1660,10,12,21448),
            (6845,5430,4130,2125,12,15,25828), (8765,6950,5290,2720,14,18,30208),
            (11220,8900,6770,3480,16,21,35464), (14360,11390,8665,4455,18,26,39844),
            (18380,14580,11090,5705,20,31,45976), (23530,18660,14200,7300,22,37,51232),
            (30115,23885,18175,9345,24,44,59116), (38550,30570,23260,11965,26,53,69628),
            (49340,39130,29775,15315,28,64,80140), (63155,50090,38110,19600,30,77,90652),
        ], bonuses: [])
    )

    static let palace = Building(
        id: 26, name: "Palast", category: .infrastructure,
        icon: "crown.fill",
        shortDescription: "Hauptstadt verwalten",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 5", "Botschaft 1"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (550,800,750,250,1,6,3650), (705,1025,960,320,2,7,3976),
            (900,1310,1230,410,3,9,4402), (1155,1680,1575,525,4,10,5103),
            (1475,2145,2015,670,5,12,7107), (1890,2750,2575,860,6,15,11616),
            (2420,3520,3300,1100,7,18,15624), (3095,4505,4220,1405,8,21,20133),
            (3965,5765,5405,1800,9,26,23640), (5075,7380,6920,2305,10,31,26646),
            (6495,9445,8855,2950,12,37,31656), (8310,12090,11335,3780,14,45,36666),
            (10640,15475,14505,4835,16,53,42678), (13615,19805,18570,6190,18,64,47688),
            (17430,25355,23770,7925,20,77,54702), (22310,32450,30425,10140,22,92,60714),
            (28560,41540,38940,12980,24,111,69732), (36555,53170,49845,16615,26,133,81756),
            (46790,68055,63805,21270,28,160,93780), (59890,87110,81670,27225,30,192,105804),
        ], bonuses: [])
    )

    static let treasury = Building(
        id: 27, name: "Schatzkammer", category: .infrastructure,
        icon: "bitcoinsign.circle.fill",
        shortDescription: "Lagert Schätze",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (720,685,645,250,4,7,2069), (1815,1725,1625,625,6,9,2515),
            (2285,2175,2050,785,8,10,3099), (2880,2740,2580,990,10,12,4061),
            (3630,3455,3250,1250,12,15,6809), (4575,4350,4095,1570,15,18,12992),
            (5760,5480,5160,1980,18,21,18488), (7260,6905,6505,2495,21,26,24671),
            (9150,8705,8195,3145,24,31,29480), (11525,10965,10325,3960,27,37,33602),
            (14525,13815,13010,4990,30,45,40472), (18300,17410,16395,6290,33,53,47342),
            (23055,21935,20655,7925,36,64,55586), (29050,27640,26025,9985,39,77,62456),
            (36605,34825,32795,12585,42,92,72074), (46125,43880,41320,15855,46,111,80318),
            (58115,55290,52060,19975,50,133,92684), (73225,69665,65600,25170,54,160,109172),
            (92265,87780,82655,31715,58,192,125660), (116255,110600,104145,39960,62,230,142148),
        ], bonuses: [])
    )

    static let townHall = Building(
        id: 24, name: "Rathaus", category: .infrastructure,
        icon: "building.columns.fill",
        shortDescription: "Feierlichkeiten",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 10", "Akademie 10"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (1250,1110,1260,600,4,6,666), (1600,1420,1615,770,6,7,1093),
            (2050,1820,2065,985,8,9,1651), (2620,2330,2645,1260,10,10,2571),
            (3355,2980,3380,1610,12,12,5199), (4295,3815,4330,2060,15,15,11112),
            (5500,4880,5540,2640,18,18,16368), (7035,6250,7095,3380,21,21,22281),
            (9005,8000,9080,4325,24,26,26880), (11530,10240,11620,5535,27,31,30822),
            (14755,13105,14875,7085,30,37,37392), (18890,16775,19040,9065,33,45,43962),
            (24180,21470,24370,11605,36,53,51846), (30950,27480,31195,14855,39,64,58416),
            (39615,35175,39930,19015,42,77,67614), (50705,45025,51110,24340,46,92,75498),
            (64905,57635,65425,31155,50,111,87324), (83075,73770,83740,39875,54,133,103092),
            (106340,94430,107190,51040,58,160,118860), (136115,120870,137200,65335,62,192,134628),
        ], bonuses: [])
    )

    static let cranny = Building(
        id: 23, name: "Versteck", category: .infrastructure,
        icon: "eye.slash.fill",
        shortDescription: "Schützt Ressourcen",
        tribe: nil, maxLevel: 10,
        prerequisites: [],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (40,50,30,10,0,1,10), (50,65,40,15,0,1,74),
            (65,80,50,15,0,2,158), (85,105,65,20,0,2,297),
            (105,135,80,25,0,2,693), (135,170,105,35,1,3,1584),
            (175,220,130,45,2,4,2376), (225,280,170,55,3,4,3267),
            (290,360,215,70,4,5,3960), (370,460,275,90,5,6,4554),
        ], bonuses: [200,260,340,440,560,720,920,1200,1540,2000])
    )

    static let greatGranary = Building(
        id: 38, name: "Grosser Kornspeicher", category: .infrastructure,
        icon: "basket.fill",
        shortDescription: "Noch mehr Getreidelager (WW)",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 10", "WW-Dorf"],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (650,800,450,200,1,1,324), (830,1025,575,255,2,1,481),
            (1065,1310,735,330,3,2,686), (1365,1680,945,420,4,2,1024),
            (1745,2145,1210,535,5,2,1990), (2235,2750,1545,685,6,3,4164),
            (2860,3520,1980,880,7,4,6096), (3660,4505,2535,1125,8,4,8270),
            (4685,5765,3245,1440,9,5,9960), (5995,7380,4150,1845,10,6,11409),
            (7675,9445,5315,2360,12,7,13824), (9825,12090,6800,3020,14,9,16239),
            (12575,15475,8705,3870,16,11,19137), (16095,19805,11140,4950,18,13,21552),
            (20600,25355,14260,6340,20,15,24933), (26365,32450,18255,8115,22,18,27831),
            (33750,41540,23365,10385,24,22,32178), (43200,53170,29910,13290,26,27,37974),
            (55295,68055,38280,17015,28,32,43770), (70780,87110,49000,21780,30,38,49566),
        ], bonuses: [3600,5100,6900,9300,12000,15000,18900,23100,28800,36000,43200,54000,66000,78000,96000,114000,135000,165000,198000,240000])
    )

    static let greatWarehouse = Building(
        id: 39, name: "Grosses Lager", category: .infrastructure,
        icon: "shippingbox.and.arrow.backward.fill",
        shortDescription: "Noch mehr Lagerkapazität (WW)",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 10", "WW-Dorf"],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (400,500,350,100,1,1,321), (510,640,450,130,2,1,458),
            (655,820,575,165,3,2,636), (840,1050,735,210,4,2,930),
            (1075,1340,940,270,5,2,1770), (1375,1720,1205,345,6,3,3660),
            (1760,2200,1540,440,7,4,5340), (2250,2815,1970,565,8,4,7230),
            (2880,3605,2520,720,9,5,8700), (3690,4610,3230,920,10,6,9960),
            (4720,5905,4130,1180,12,7,12060), (6045,7555,5290,1510,14,9,14160),
            (7735,9670,6770,1935,16,11,16680), (9905,12380,8665,2475,18,13,18780),
            (12675,15845,11090,3170,20,15,21720), (16225,20280,14200,4055,22,18,24240),
            (20770,25960,18175,5190,24,22,28020), (26585,33230,23260,6645,26,27,33060),
            (34030,42535,29775,8505,28,32,38100), (43555,54445,38110,10890,30,38,43140),
        ], bonuses: [3600,5100,6900,9300,12000,15000,18900,23100,28800,36000,43200,54000,66000,78000,96000,114000,135000,165000,198000,240000])
    )

    static let stonemason = Building(
        id: 34, name: "Steinmetz", category: .infrastructure,
        icon: "mountain.2.fill",
        shortDescription: "Haltbarere Gebäude",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 5", "Nur Hauptstadt"],
        bonusLabel: "Haltbarkeit %",
        levels: makeLevels(costs: [
            (155,130,125,70,2,1,35), (200,165,160,90,3,1,261),
            (255,215,205,115,4,2,557), (325,275,260,145,5,2,1044),
            (415,350,335,190,6,2,2436), (535,445,430,240,8,3,5568),
            (680,570,550,310,10,4,8352), (875,730,705,395,12,4,11484),
            (1115,935,900,505,14,5,13920), (1430,1200,1155,645,16,6,16008),
            (1830,1535,1475,825,18,7,19488), (2340,1965,1890,1060,20,9,22968),
            (3000,2515,2420,1355,22,11,27144), (3840,3220,3095,1735,24,13,30624),
            (4910,4120,3960,2220,26,15,35496), (6290,5275,5070,2840,29,18,39672),
            (8050,6750,6490,3635,32,22,45936), (10300,8640,8310,4650,35,27,54288),
            (13185,11060,10635,5955,38,32,62640), (16880,14155,13610,7620,41,38,70992),
        ], bonuses: Array(1...20).map { Double($0) * 10 })
    )

    // ────────────────────────────────────────────
    // MARK: Militaer-Gebaeude
    // ────────────────────────────────────────────

    static let militaryBuildings: [Building] = [
        barracks, stable, workshop,
        academy, smithy, rallyPoint,
        greatBarracks, greatStable,
        tournamentSquare,
        cityWall, earthWall, palisade,
        trapper, brewery,
        horseDrinkingTrough, waterDitch,
        healingTent,
    ]

    static let barracks = Building(
        id: 19, name: "Kaserne", category: .military,
        icon: "figure.walk",
        shortDescription: "Bildet Infanterie aus",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 3", "Versammlungsplatz 1"],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (210,140,260,120,4,1,36), (280,185,345,160,6,1,270),
            (370,250,460,210,8,2,576), (495,330,610,280,10,2,1080),
            (655,440,815,375,12,2,2520), (875,585,1080,500,15,3,5760),
            (1160,775,1440,665,18,4,8640), (1545,1030,1915,885,21,4,11880),
            (2055,1370,2545,1175,24,5,14400), (2735,1825,3385,1565,27,6,16560),
            (3635,2425,4505,2080,30,7,20160), (4835,3225,5990,2765,33,9,23760),
            (6435,4290,7965,3675,36,11,28080), (8555,5705,10595,4890,39,13,31680),
            (11380,7585,14090,6505,42,15,36720), (15135,10090,18740,8650,46,18,41040),
            (20130,13420,24925,11505,50,22,47520), (26775,17850,33150,15300,54,27,56160),
            (35610,23740,44085,20345,58,32,64800), (47360,31575,58635,27060,62,38,73440),
        ], bonuses: [100,90,81,73,66,59,53,48,43,39,35,31,28,25,23,21,19,17,15,14])
    )

    static let stable = Building(
        id: 20, name: "Stall", category: .military,
        icon: "hare.fill",
        shortDescription: "Bildet Kavallerie aus",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Schmiede 3", "Akademie 5"],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (260,140,220,100,5,2,39), (345,185,295,135,8,3,292),
            (460,250,390,175,11,3,624), (610,330,520,235,14,4,1170),
            (815,440,690,315,17,5,2730), (1080,585,915,415,20,6,6240),
            (1440,775,1220,555,23,7,9360), (1915,1030,1620,735,26,9,12870),
            (2545,1370,2155,980,29,10,15600), (3385,1825,2865,1300,32,12,17940),
            (4505,2425,3810,1730,36,15,21840), (5990,3225,5065,2305,40,18,25740),
            (7965,4290,6740,3065,44,21,30420), (10595,5705,8965,4075,48,26,34320),
            (14090,7585,11920,5420,52,31,39780), (18740,10090,15855,7205,56,37,44460),
            (24925,13420,21090,9585,60,44,51480), (33150,17850,28050,12750,64,53,60840),
            (44085,23740,37305,16955,68,64,70200), (58635,31575,49615,22550,72,77,79560),
        ], bonuses: [100,90,81,73,66,59,53,48,43,39,35,31,28,25,23,21,19,17,15,14])
    )

    static let workshop = Building(
        id: 21, name: "Werkstatt", category: .military,
        icon: "wrench.and.screwdriver.fill",
        shortDescription: "Baut Belagerungswaffen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 5", "Akademie 10"],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (460,510,600,320,3,4,646), (590,655,770,410,5,4,948),
            (755,835,985,525,7,5,1344), (965,1070,1260,670,9,6,1995),
            (1235,1370,1610,860,11,7,3855), (1580,1750,2060,1100,13,9,8040),
            (2025,2245,2640,1405,15,11,11760), (2590,2870,3380,1800,17,13,15945),
            (3315,3675,4325,2305,19,15,19200), (4245,4705,5535,2950,21,19,21990),
            (5430,6020,7085,3780,24,22,26640), (6950,7705,9065,4835,27,27,31290),
            (8900,9865,11605,6190,30,32,36870), (11390,12625,14855,7925,33,39,41520),
            (14580,16165,19015,10140,36,46,48030), (18660,20690,24340,12980,39,55,53610),
            (23885,26480,31155,16615,42,67,61980), (30570,33895,39875,21270,45,80,73140),
            (39130,43385,51040,27225,48,96,84300), (50090,55535,65335,34845,51,115,95460),
        ], bonuses: [100,90,81,73,66,59,53,48,43,39,35,31,28,25,23,21,19,17,15,14])
    )

    static let academy = Building(
        id: 22, name: "Akademie", category: .military,
        icon: "graduationcap.fill",
        shortDescription: "Erforscht Truppen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 3", "Kaserne 3"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (220,160,90,40,4,5,35), (295,215,120,55,6,6,263),
            (390,285,160,70,8,7,561), (520,375,210,95,10,8,1053),
            (690,500,280,125,12,10,2457), (915,665,375,165,15,12,5616),
            (1220,885,500,220,18,14,8424), (1620,1180,665,295,21,17,11583),
            (2155,1565,880,390,24,21,14040), (2865,2085,1170,520,27,25,16145),
            (3810,2770,1560,695,30,30,19656), (5065,3685,2075,920,33,36,23166),
            (6740,4900,2755,1225,36,43,27378), (8965,6520,3665,1630,39,51,30887),
            (11920,8670,4875,2170,42,62,35802), (15855,11530,6485,2885,46,74,40014),
            (21090,15335,8625,3835,50,89,46332), (28050,20400,11475,5100,54,106,54756),
            (37305,27130,15260,6780,58,128,63179), (49615,36085,20295,9020,62,153,71604),
        ], bonuses: [])
    )

    static let smithy = Building(
        id: 13, name: "Schmiede", category: .military,
        icon: "hammer.circle.fill",
        shortDescription: "Verbessert Truppen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 3", "Akademie 1"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (180,250,500,160,4,2,39), (230,320,640,205,6,3,299),
            (295,410,820,260,8,3,638), (375,525,1050,335,10,4,1197),
            (485,670,1340,430,12,5,2793), (620,860,1720,550,15,6,6384),
            (790,1100,2200,705,18,7,9576), (1015,1405,2815,900,21,9,13167),
            (1295,1800,3605,1155,24,10,15960), (1660,2305,4610,1475,27,12,18354),
            (2125,2950,5905,1890,30,15,22344), (2720,3780,7555,2420,33,18,26334),
            (3480,4835,9670,3095,36,21,31122), (4455,6190,12380,3960,39,26,35112),
            (5705,7925,15845,5070,42,31,40698), (7300,10140,20280,6490,46,37,45486),
            (9345,12980,25960,8310,50,44,52668), (11965,16615,33230,10635,54,53,62244),
            (15315,21270,42535,13610,58,64,71820), (19600,27225,54445,17420,62,77,81396),
        ], bonuses: [])
    )

    static let rallyPoint = Building(
        id: 16, name: "Versammlungsplatz", category: .military,
        icon: "flag.2.crossed.fill",
        shortDescription: "Truppenverwaltung",
        tribe: nil, maxLevel: 20,
        prerequisites: [],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (110,160,90,70,1,1,34), (145,215,120,95,2,1,258),
            (195,285,160,125,3,2,552), (260,375,210,165,4,2,1035),
            (345,500,280,220,5,2,2415), (460,665,375,290,6,3,5520),
            (610,885,500,385,7,4,8280), (810,1180,665,515,8,4,11385),
            (1075,1565,880,685,9,5,13799), (1430,2085,1170,910,10,6,15869),
            (1905,2770,1560,1210,12,7,19320), (2535,3685,2075,1610,14,9,22770),
            (3370,4900,2755,2145,16,11,26909), (4480,6520,3665,2850,18,13,30359),
            (5960,8670,4875,3795,20,15,35190), (7930,11530,6485,5045,22,18,39330),
            (10545,15335,8625,6710,24,22,45540), (14025,20400,11475,8925,26,27,53819),
            (18650,27130,15260,11870,28,32,62099), (24805,36085,20295,15785,30,38,70380),
        ], bonuses: [])
    )

    static let greatBarracks = Building(
        id: 29, name: "Grosse Kaserne", category: .military,
        icon: "figure.walk.diamond.fill",
        shortDescription: "Zusätzliche Infanterie",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Stadt", "Kaserne 20"],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (630,420,780,360,4,1,648), (805,540,1000,460,6,1,966),
            (1030,690,1280,590,8,2,1382), (1320,880,1635,755,10,2,2067),
            (1690,1125,2095,965,12,2,4023), (2165,1445,2680,1235,15,3,8424),
            (2770,1845,3430,1585,18,4,12336), (3545,2365,4390,2025,21,4,16737),
            (4540,3025,5620,2595,24,5,20160), (5810,3875,7195,3320,27,6,23094),
            (7440,4960,9210,4250,30,7,27984), (9520,6345,11785,5440,33,9,32874),
            (12185,8125,15085,6965,36,11,38742), (15600,10400,19310,8915,39,13,43632),
            (19965,13310,24720,11410,42,15,50478), (25555,17035,31640,14605,46,18,56345),
            (32710,21810,40500,18690,50,22,65147), (41870,27915,51840,23925,54,27,76884),
            (53595,35730,66355,30625,58,32,88620), (68600,45735,84935,39200,62,38,100356),
        ], bonuses: [100,90,81,73,66,59,53,48,43,39,35,31,28,25,23,21,19,17,15,14])
    )

    static let greatStable = Building(
        id: 30, name: "Grosser Stall", category: .military,
        icon: "hare",
        shortDescription: "Zusätzliche Kavallerie",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Stadt", "Stall 20"],
        bonusLabel: "Bauzeit %",
        levels: makeLevels(costs: [
            (780,420,660,300,5,2,648), (1000,540,845,385,8,3,964),
            (1280,690,1080,490,11,3,1377), (1635,880,1385,630,14,4,2058),
            (2095,1125,1770,805,17,5,4002), (2680,1445,2270,1030,20,6,8376),
            (3430,1845,2905,1320,23,7,12264), (4390,2365,3715,1690,26,9,16638),
            (5620,3025,4755,2160,29,10,20040), (7195,3875,6085,2765,32,12,22956),
            (9210,4960,7790,3540,36,15,27816), (11785,6345,9975,4535,40,18,32676),
            (15085,8125,12765,5805,44,21,38508), (19310,10400,16340,7430,48,26,43368),
            (24720,13310,20915,9505,52,31,50172), (31640,17035,26775,12170,56,37,56004),
            (40500,21810,34270,15575,60,44,64752), (51840,27915,43865,19940,64,53,76416),
            (66355,35730,56145,25520,68,64,88080), (84935,45735,71870,32665,72,77,99744),
        ], bonuses: [100,90,81,73,66,59,53,48,43,39,35,31,28,25,23,21,19,17,15,14])
    )

    static let tournamentSquare = Building(
        id: 14, name: "Turnierplatz", category: .military,
        icon: "figure.equestrian.sports",
        shortDescription: "Truppen reisen schneller",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Versammlungsplatz 15"],
        bonusLabel: "Speed %",
        levels: makeLevels(costs: [
            (1750,2250,1530,240,1,1,378), (2240,2880,1960,305,2,1,887),
            (2865,3685,2505,395,3,2,1552), (3670,4720,3210,505,4,2,2649),
            (4700,6040,4105,645,5,2,5781), (6015,7730,5255,825,6,3,12828),
            (7695,9895,6730,1055,7,4,19092), (9850,12665,8615,1350,8,4,26139),
            (12610,16215,11025,1730,9,5,31620), (16140,20755,14110,2215,10,6,36318),
            (20660,26565,18065,2835,12,7,44148), (26445,34000,23120,3625,14,9,51978),
            (33850,43520,29595,4640,16,11,61374), (43330,55705,37880,5940,18,13,69204),
            (55460,71305,48490,7605,20,15,80166), (70990,91270,62065,9735,22,18,89562),
            (90865,116825,79440,12460,24,22,103656), (116305,149540,101685,15950,26,27,122448),
            (148875,191410,130160,20415,28,32,141240), (190560,245005,166600,26135,30,38,160032),
        ], bonuses: Array(1...20).map { Double($0) * 10 })
    )

    static let cityWall = Building(
        id: 31, name: "Stadtmauer", category: .military,
        icon: "building.fill",
        shortDescription: "Dorfverteidigung",
        tribe: "Römer", maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Def %",
        levels: makeLevels(costs: [
            (70,90,170,70,0,1,34), (90,115,220,90,0,1,256),
            (115,145,280,115,0,2,547), (145,190,355,145,0,2,1026),
            (190,240,455,190,0,2,2394), (240,310,585,240,1,3,5471),
            (310,395,750,310,2,4,8208), (395,505,955,395,3,4,11285),
            (505,650,1225,505,4,5,13679), (645,830,1570,645,5,6,15731),
            (825,1065,2005,825,6,7,19152), (1060,1360,2570,1060,7,9,22571),
            (1355,1740,3290,1355,8,11,26675), (1735,2230,4210,1735,9,13,30095),
            (2220,2850,5390,2220,10,15,34884), (2840,3650,6895,2840,12,18,38988),
            (3635,4675,8825,3635,14,22,45143), (4650,5980,11300,4650,16,27,53351),
            (5955,7655,14460,5955,18,32,61559), (7620,9800,18510,7620,20,38,69768),
        ], bonuses: [3,6,9,13,16,19,23,27,31,34,38,43,47,51,56,61,65,70,75,81])
    )

    static let earthWall = Building(
        id: 32, name: "Erdwall", category: .military,
        icon: "mountain.2.fill",
        shortDescription: "Dorfverteidigung",
        tribe: "Germanen", maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Def %",
        levels: makeLevels(costs: [
            (120,200,0,80,0,1,34), (155,255,0,100,0,1,256),
            (195,330,0,130,0,2,547), (250,420,0,170,0,2,1026),
            (320,535,0,215,0,2,2394), (410,685,0,275,1,3,5471),
            (530,880,0,350,2,4,8208), (675,1125,0,450,3,4,11285),
            (865,1440,0,575,4,5,13679), (1105,1845,0,740,5,6,15731),
            (1415,2360,0,945,6,7,19152), (1815,3020,0,1210,7,9,22571),
            (2320,3870,0,1545,8,11,26675), (2970,4950,0,1980,9,13,30095),
            (3805,6340,0,2535,10,15,34884), (4870,8115,0,3245,12,18,38988),
            (6230,10385,0,4155,14,22,45143), (7975,13290,0,5315,16,27,53351),
            (10210,17015,0,6805,18,32,61559), (13065,21780,0,8710,20,38,69768),
        ], bonuses: [2,4,6,8,10,13,15,17,20,22,24,27,29,32,35,37,40,43,46,49])
    )

    static let palisade = Building(
        id: 33, name: "Palisade", category: .military,
        icon: "rectangle.3.group.fill",
        shortDescription: "Dorfverteidigung",
        tribe: "Gallier", maxLevel: 20,
        prerequisites: [],
        bonusLabel: "Def %",
        levels: makeLevels(costs: [
            (160,100,80,60,0,1,34), (205,130,100,75,0,1,256),
            (260,165,130,100,0,2,547), (335,210,170,125,0,2,1026),
            (430,270,215,160,0,2,2394), (550,345,275,205,1,3,5471),
            (705,440,350,265,2,4,8208), (900,565,450,340,3,4,11285),
            (1155,720,575,430,4,5,13679), (1475,920,740,555,5,6,15731),
            (1890,1180,945,710,6,7,19152), (2420,1510,1210,905,7,9,22571),
            (3095,1935,1545,1160,8,11,26675), (3960,2475,1980,1485,9,13,30095),
            (5070,3170,2535,1900,10,15,34884), (6490,4055,3245,2435,12,18,38988),
            (8310,5190,4155,3115,14,22,45143), (10635,6645,5315,3990,16,27,53351),
            (13610,8505,6805,5105,18,32,61559), (17420,10890,8710,6535,20,38,69768),
        ], bonuses: [3,5,8,10,13,16,19,22,25,28,31,35,38,41,45,49,52,56,60,64])
    )

    static let trapper = Building(
        id: 36, name: "Fallensteller", category: .military,
        icon: "ant.fill",
        shortDescription: "Baut Fallen",
        tribe: "Gallier", maxLevel: 20,
        prerequisites: ["Versammlungsplatz 1"],
        bonusLabel: "Max Fallen",
        levels: makeLevels(costs: [
            (80,120,70,90,4,1,33), (105,160,95,120,6,1,254),
            (140,210,125,160,8,2,542), (190,280,165,210,10,2,1016),
            (250,375,220,280,12,2,2373), (335,500,290,375,15,3,5423),
            (445,665,385,500,18,4,8135), (590,885,515,665,21,4,11186),
            (785,1175,685,880,24,5,13559), (1040,1565,910,1170,27,6,15593),
            (1385,2080,1210,1560,30,7,18984), (1845,2765,1610,2075,33,9,22373),
            (2450,3675,2145,2755,36,11,26441), (3260,4890,2850,3665,39,13,29831),
            (4335,6505,3795,4875,42,15,34578), (5765,8650,5045,6485,46,18,38645),
            (7670,11505,6710,8625,50,22,44747), (10200,15300,8925,11475,54,27,52883),
            (13565,20345,11870,15260,58,32,61019), (18040,27060,15785,20295,62,38,69156),
        ], bonuses: [10,22,35,49,64,80,97,115,134,154,175,196,218,241,265,290,316,343,371,400])
    )

    static let brewery = Building(
        id: 35, name: "Brauerei", category: .military,
        icon: "mug.fill",
        shortDescription: "+20% Angriffsstärke",
        tribe: "Germanen", maxLevel: 20,
        prerequisites: ["Nur Hauptstadt", "Kornspeicher 20", "Versammlungsplatz 10"],
        bonusLabel: "Angriff %",
        levels: makeLevels(costs: [
            (1460,930,1250,1740,6,5,675), (1870,1190,1600,2225,9,6,1162),
            (2390,1525,2050,2850,12,7,1800), (3060,1950,2620,3650,15,8,2850),
            (3920,2495,3355,4670,18,10,5850), (5015,3195,4295,5980,22,12,12600),
            (6420,4090,5500,7655,26,14,18600), (8220,5235,7035,9795,30,17,25350),
            (10520,6700,9005,12540,34,21,30600), (13465,8580,11530,16050,38,25,35100),
            (17235,10980,14755,20540,42,30,42600), (22065,14055,18890,26295,46,36,50100),
            (28240,17990,24180,33655,50,43,59100), (36150,23025,30950,43080,54,51,66600),
            (46270,29475,39615,55145,58,62,77100), (59225,37725,50705,70585,63,74,86100),
            (75810,48290,64905,90345,68,89,99600), (97035,61810,83075,115645,73,106,117600),
            (124205,79115,106340,148025,78,128,135600), (158980,101270,136115,189470,83,153,153600),
        ], bonuses: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20])
    )

    static let horseDrinkingTrough = Building(
        id: 41, name: "Pferdetränke", category: .military,
        icon: "drop.fill",
        shortDescription: "Kavallerie-Unterhalt senken",
        tribe: "Römer", maxLevel: 20,
        prerequisites: ["Versammlungsplatz 10", "Stall 20"],
        bonusLabel: "Unterhalt %",
        levels: makeLevels(costs: [
            (780,420,660,540,5,4,650), (1000,540,845,690,8,4,980),
            (1280,690,1080,885,11,5,1411), (1635,880,1385,1130,14,6,2121),
            (2095,1125,1770,1450,17,7,4149), (2680,1445,2270,1855,20,9,8712),
            (3430,1845,2905,2375,23,11,12768), (4390,2365,3715,3040,26,13,17331),
            (5620,3025,4755,3890,29,15,20880), (7195,3875,6085,4980,32,19,23922),
            (9210,4960,7790,6375,36,22,28992), (11785,6345,9975,8160,40,27,34062),
            (15085,8125,12765,10445,44,32,40146), (19310,10400,16340,13370,48,39,45216),
            (24720,13310,20915,17115,52,46,52314), (31640,17035,26775,21905,56,55,58398),
            (40500,21810,34270,28040,60,67,67524), (51840,27915,43865,35890,64,80,79692),
            (66355,35730,56145,45940,68,96,91860), (84935,45735,71870,58800,72,115,104028),
        ], bonuses: [99,98,97,96,95,94,93,92,91,90,89,88,87,86,85,84,83,82,81,80])
    )

    static let waterDitch = Building(
        id: 42, name: "Wassergraben", category: .military,
        icon: "water.waves",
        shortDescription: "Dorfverteidigung (Stadt)",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Stadt"],
        bonusLabel: nil,
        levels: makeLevels(costs: [
            (740,850,960,620,4,4,357), (945,1090,1230,795,6,4,727),
            (1210,1395,1575,1015,8,5,1212), (1550,1785,2015,1300,10,6,2010),
            (1985,2280,2575,1665,12,7,4290), (2545,2920,3300,2130,15,9,9420),
            (3255,3740,4220,2725,18,11,13980), (4165,4785,5405,3490,21,13,19110),
            (5330,6125,6920,4470,24,15,23100), (6825,7840,8855,5720,27,19,26520),
            (8735,10035,11335,7320,30,22,32220), (11185,12845,14505,9370,33,27,37920),
            (14315,16440,18570,11995,36,32,44760), (18320,21045,23770,15350,39,39,50460),
            (23450,26940,30425,19650,42,46,58440), (30020,34480,38940,25150,46,55,65280),
            (38425,44135,49845,32190,50,67,75540), (49180,56490,63805,41205,54,80,89220),
            (62950,72310,81670,52745,58,96,102900), (80580,92555,104535,67510,62,115,116580),
        ], bonuses: [])
    )

    static let healingTent = Building(
        id: 46, name: "Heilzelt", category: .military,
        icon: "cross.circle.fill",
        shortDescription: "Heilt verwundete Truppen",
        tribe: nil, maxLevel: 20,
        prerequisites: ["Hauptgebäude 10", "Akademie 15"],
        bonusLabel: "Kapazität",
        levels: makeLevels(costs: [
            (900,800,750,650,3,5,654), (1150,1025,960,830,5,6,1005),
            (1475,1310,1230,1065,7,7,1464), (1885,1680,1575,1365,9,8,2220),
            (2415,2145,2015,1745,11,10,4380), (3090,2750,2575,2235,13,12,9240),
            (3960,3520,3300,2860,15,14,13560), (5065,4505,4220,3660,17,17,18420),
            (6485,5765,5405,4685,19,21,22200), (8300,7380,6920,5995,21,25,25440),
            (10625,9445,8855,7675,24,30,30840), (13600,12090,11335,9825,27,36,36240),
            (17410,15475,14505,12575,30,43,42720), (22285,19805,18570,16095,33,51,48120),
            (28520,25355,23770,20600,36,62,55680), (36510,32450,30425,26365,39,74,62160),
            (46730,41540,38940,33750,42,89,71880), (59815,53170,49845,43200,45,106,84840),
            (76565,68055,63805,55295,48,128,97800), (98000,87110,81670,70780,51,153,110760),
        ], bonuses: [400,800,1200,1600,2000,2400,2800,3200,3600,4000,4400,4800,5200,5600,6000,6400,6800,7200,7600,8000])
    )

    // MARK: - Helper

    /// Erstellt BuildingLevel-Array aus kompakten Daten.
    static func makeLevels(
        costs: [(Int, Int, Int, Int, Int, Int, Int)],
        bonuses: [Double]
    ) -> [BuildingLevel] {
        costs.enumerated().map { idx, c in
            BuildingLevel(
                level: idx + 1,
                wood: c.0, clay: c.1, iron: c.2, crop: c.3,
                pop: c.4, cp: c.5, baseTimeSec: c.6,
                bonusValue: idx < bonuses.count ? bonuses[idx] : 0
            )
        }
    }
}
