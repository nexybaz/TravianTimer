import SwiftUI

// MARK: - Disziplin-Auswahl

private enum ResearchDiscipline: String, CaseIterable {
    case all       = "Alle"
    case attack    = "Angriff"
    case defInf    = "Def Inf."
    case defCav    = "Def Kav."
}

// MARK: - Forschungsrechner View

struct ResearchCalculatorView: View {

    @State private var selectedTribe: TroopsTribe = .romans
    @State private var gameSpeed: Int = 1
    @State private var discipline: ResearchDiscipline = .all
    @State private var showSmithyCosts = false
    @State private var showBreakEven = false
    @State private var breakEvenUnitIndex: Int = 0

    // MARK: - Abgeleitete Werte

    private var units: [TroopUnit] {
        switch selectedTribe {
        case .gauls:   return TroopsGaulsView.units
        case .romans:  return TroopsRomansView.units
        case .teutons: return TroopsTeutonsView.units
        }
    }

    /// Sortierte Einheiten nach gewählter Disziplin (stärkste zuerst, 0-Werte am Ende)
    private var sortedUnits: [TroopUnit] {
        guard discipline != .all else { return units }

        return units.sorted { a, b in
            let va = statValue(for: a)
            let vb = statValue(for: b)
            if va == 0 && vb != 0 { return false }
            if va != 0 && vb == 0 { return true }
            return va > vb
        }
    }

    /// Basiswert der gewählten Disziplin für eine Einheit
    private func statValue(for unit: TroopUnit) -> Int {
        switch discipline {
        case .all:     return unit.attack + unit.defInfantry + unit.defCavalry
        case .attack:  return unit.attack
        case .defInf:  return unit.defInfantry
        case .defCav:  return unit.defCavalry
        }
    }

    /// Schmiede-Formel: base × (1 + level × 0.015), gerundet
    static func researchedValue(base: Int, level: Int) -> Int {
        guard base > 0 && level > 0 else { return base }
        return Int(round(Double(base) * (1.0 + Double(level) * 0.015)))
    }

    /// Schmiede-Gebäudedaten (id: 13)
    private var smithyBuilding: Building? {
        Building.allBuildings.first { $0.id == 13 }
    }

    /// Ausgewählte Einheit für Break-Even
    private var breakEvenUnit: TroopUnit {
        let idx = min(breakEvenUnitIndex, units.count - 1)
        return units[max(0, idx)]
    }

    /// Mindestanzahl Truppen, ab der sich Schmiede-Stufe N lohnt.
    ///
    /// Vergleich: Forschung (bestehende Truppen werden stärker) vs. Produktion (mehr Truppen bauen).
    /// - Research Gain: T × base × 0.015
    /// - Production Gain: (smithyCost / troopCost) × base × (1 + (N-1) × 0.015)
    /// - Break-Even: T = (smithyCost / troopCost) × (1 + (N-1) × 0.015) / 0.015
    private func breakEvenTroops(unit: TroopUnit, level: Int, stat: ResearchDiscipline) -> Int? {
        let base: Int
        switch stat {
        case .all:     return nil
        case .attack:  base = unit.attack
        case .defInf:  base = unit.defInfantry
        case .defCav:  base = unit.defCavalry
        }
        guard base > 0 else { return nil }
        guard let smithy = smithyBuilding, level >= 1, level <= smithy.levels.count else { return nil }

        let lv = smithy.levels[level - 1]
        let smithyCost = Double(lv.wood + lv.clay + lv.iron + lv.crop)
        let troopCost = Double(unit.costWood + unit.costClay + unit.costIron)
        guard troopCost > 0 else { return nil }

        let producible = smithyCost / troopCost
        let currentMultiplier = 1.0 + Double(level - 1) * 0.015
        let minTroops = producible * currentMultiplier / 0.015

        return Int(ceil(minTroops))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Eingabe
                tribePicker
                speedPicker
                disciplinePicker

                // Ergebnis
                resultSection

                // Break-Even
                breakEvenSection

                // Schmiede-Kosten
                smithyCostsSection

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Forschungsrechner")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedTribe) { _, _ in
            breakEvenUnitIndex = 0
        }
    }

    // MARK: - Tribe Picker

    private var tribePicker: some View {
        Picker("Volk", selection: $selectedTribe) {
            ForEach(TroopsTribe.allCases) { tribe in
                Text(tribe.title).tag(tribe)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Speed Picker

    private var speedPicker: some View {
        HStack {
            Text("Geschwindigkeit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach([1, 3], id: \.self) { speed in
                    Button {
                        gameSpeed = speed
                    } label: {
                        Text("\(speed)\u{00D7}")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(gameSpeed == speed ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(gameSpeed == speed ? Color.indigo : Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Discipline Picker

    private var disciplinePicker: some View {
        Picker("Disziplin", selection: $discipline) {
            ForEach(ResearchDiscipline.allCases, id: \.self) { d in
                Text(d.rawValue).tag(d)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Ergebnis

    private var resultSection: some View {
        VStack(spacing: 0) {
            if discipline == .all {
                allDisciplineView
            } else {
                singleDisciplineView
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Alle Disziplinen (Kompaktansicht)

    private var allDisciplineView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Einheit")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("⚔️")
                    .frame(width: 72)
                Text("🛡")
                    .frame(width: 72)
                Text("🐴")
                    .frame(width: 72)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            ForEach(Array(units.enumerated()), id: \.offset) { idx, unit in
                if idx > 0 {
                    Divider().padding(.leading, 14)
                }

                HStack(spacing: 0) {
                    // Name + Typ
                    VStack(alignment: .leading, spacing: 1) {
                        Text(unit.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(unit.type.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(unit.type.badgeColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Angriff
                    statCell(base: unit.attack)
                        .frame(width: 72)

                    // Def Inf
                    statCell(base: unit.defInfantry)
                        .frame(width: 72)

                    // Def Kav
                    statCell(base: unit.defCavalry)
                        .frame(width: 72)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    /// Kompakte Stat-Zelle: Basis → Stufe 20
    private func statCell(base: Int) -> some View {
        VStack(spacing: 1) {
            if base > 0 {
                Text("\(base)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                let upgraded = Self.researchedValue(base: base, level: 20)
                let delta = upgraded - base
                Text("\(upgraded)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("+\(delta)")
                    .font(.system(size: 9))
                    .foregroundStyle(.green)
            } else {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }

    // MARK: - Einzeldisziplin (Detailansicht)

    private var singleDisciplineView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Einheit")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Basis")
                    .frame(width: 44)
                ForEach([5, 10, 15, 20], id: \.self) { lvl in
                    Text("Lv\(lvl)")
                        .frame(width: 44)
                }
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            ForEach(Array(sortedUnits.enumerated()), id: \.offset) { idx, unit in
                if idx > 0 {
                    Divider().padding(.leading, 14)
                }

                let base = statValue(for: unit)
                let isZero = base == 0

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(unit.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(unit.type.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(isZero ? Color(.tertiaryLabel) : unit.type.badgeColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Basiswert
                    Text(isZero ? "–" : "\(base)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(isZero ? Color(.tertiaryLabel) : .primary)
                        .frame(width: 44)

                    // Level 5, 10, 15, 20
                    ForEach([5, 10, 15, 20], id: \.self) { lvl in
                        if isZero {
                            Text("–")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                                .frame(width: 44)
                        } else {
                            let val = Self.researchedValue(base: base, level: lvl)
                            Text("\(val)")
                                .font(.caption)
                                .fontWeight(lvl == 20 ? .bold : .regular)
                                .monospacedDigit()
                                .foregroundStyle(lvl == 20 ? .indigo : .primary)
                                .frame(width: 44)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .opacity(isZero ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Break-Even Berechnung

    private var breakEvenSection: some View {
        VStack(spacing: 0) {
            // Toggle
            Toggle(isOn: $showBreakEven.animation(.easeInOut(duration: 0.2))) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ab wann lohnt sich Forschung?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Min. Einheiten, ab denen Forschung mehr bringt als neue Truppen")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.indigo)
                }
            }
            .tint(.indigo)

            if showBreakEven {
                Divider()
                    .padding(.vertical, 8)

                // Disziplin-Hinweis wenn "Alle"
                if discipline == .all {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Wähle eine Disziplin (Angriff, Def Inf. oder Def Kav.) für die Break-Even-Berechnung.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Unit Picker
                    VStack(spacing: 10) {
                        Text("Einheit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(units.enumerated()), id: \.offset) { idx, unit in
                                    let base = baseForDiscipline(unit: unit)
                                    Button {
                                        withAnimation(.snappy(duration: 0.15)) {
                                            breakEvenUnitIndex = idx
                                        }
                                    } label: {
                                        Text(unit.name)
                                            .font(.caption2)
                                            .fontWeight(breakEvenUnitIndex == idx ? .bold : .regular)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(breakEvenUnitIndex == idx ? Color.indigo : Color(.systemGray5))
                                            .foregroundStyle(breakEvenUnitIndex == idx ? .white : (base > 0 ? .primary : Color(.tertiaryLabel)))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Ergebnis-Tabelle
                    let unit = breakEvenUnit
                    let base = baseForDiscipline(unit: unit)

                    if base == 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text("\(unit.name) hat keinen \(discipline.rawValue)-Wert.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    } else {
                        breakEvenTable(unit: unit, base: base)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// Basiswert für aktuell gewählte Disziplin
    private func baseForDiscipline(unit: TroopUnit) -> Int {
        switch discipline {
        case .all:     return 0
        case .attack:  return unit.attack
        case .defInf:  return unit.defInfantry
        case .defCav:  return unit.defCavalry
        }
    }

    /// Break-Even Tabelle für eine bestimmte Einheit
    private func breakEvenTable(unit: TroopUnit, base: Int) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Stufe")
                    .frame(width: 44, alignment: .leading)
                Text("Wert")
                    .frame(width: 44)
                Text("Min. Einheiten")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            ForEach(1...20, id: \.self) { level in
                let upgraded = Self.researchedValue(base: base, level: level)
                let minTroops = breakEvenTroops(unit: unit, level: level, stat: discipline)

                HStack(spacing: 0) {
                    Text("\(level)")
                        .fontWeight(.medium)
                        .frame(width: 44, alignment: .leading)

                    Text("\(upgraded)")
                        .frame(width: 44)

                    Spacer()

                    if let min = minTroops {
                        Text(formatBreakEven(min))
                            .fontWeight(.medium)
                            .foregroundStyle(breakEvenColor(min))
                    } else {
                        Text("–")
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

                if level < 20 {
                    Divider().padding(.leading, 8)
                }
            }
        }
    }

    /// Farbe basierend auf Break-Even Anzahl
    private func breakEvenColor(_ count: Int) -> Color {
        if count < 500 { return .green }
        if count < 2000 { return .orange }
        return .red
    }

    /// Formatiert Break-Even Zahl mit Tausender-Trennung
    private func formatBreakEven(_ value: Int) -> String {
        if value >= 100_000 {
            return String(format: "%.0fk", Double(value) / 1000.0)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "'"
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Schmiede-Kosten

    private var smithyCostsSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showSmithyCosts) {
                if let building = smithyBuilding {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                            Text("#")
                                .frame(width: 28, alignment: .leading)
                            Text("🪵")
                                .frame(maxWidth: .infinity)
                            Text("🧱")
                                .frame(maxWidth: .infinity)
                            Text("⚙️")
                                .frame(maxWidth: .infinity)
                            Text("🌾")
                                .frame(maxWidth: .infinity)
                            Text("⏱")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        ForEach(Array(building.levels.enumerated()), id: \.offset) { idx, level in
                            HStack(spacing: 0) {
                                Text("\(idx + 1)")
                                    .fontWeight(.medium)
                                    .frame(width: 28, alignment: .leading)
                                Text(formatCost(level.wood))
                                    .frame(maxWidth: .infinity)
                                Text(formatCost(level.clay))
                                    .frame(maxWidth: .infinity)
                                Text(formatCost(level.iron))
                                    .frame(maxWidth: .infinity)
                                Text(formatCost(level.crop))
                                    .frame(maxWidth: .infinity)
                                Text(formatTime(level.baseTimeSec / gameSpeed))
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .font(.caption2)
                            .monospacedDigit()
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)

                            if idx < building.levels.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            } label: {
                Label {
                    Text("Schmiede-Kosten")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "hammer.circle.fill")
                        .foregroundStyle(.indigo)
                }
            }
            .tint(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatCost(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.0fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
