import SwiftUI

// MARK: - Ansichts-Modus

private enum ResultViewMode: String, CaseIterable {
    case compact = "Kompakt"
    case detail = "Detail"
}

// MARK: - Ausbau-Rechner View

struct UpgradeCalculatorView: View {

    @State private var config: UpgradeCalculatorConfig
    @State private var results: [UpgradeStep] = []
    @State private var hasCalculated = false
    @State private var resultViewMode: ResultViewMode = .compact
    @State private var showFieldDetail = false
    private let loadedFromPlan: Bool

    init(plan: VillagePlan? = nil) {
        if let plan {
            let cfg = UpgradeCalculatorConfig.from(plan: plan)
            _config = State(initialValue: cfg)
            // Einzelansicht automatisch öffnen wenn Felder unterschiedliche Stufen haben
            let hasMixedLevels = ResourceFieldType.allCases.contains { type in
                let levels = cfg.resourceFieldLevels
                    .filter { $0.resourceType == type }
                    .map { $0.level }
                return Set(levels).count > 1
            }
            _showFieldDetail = State(initialValue: hasMixedLevels)
            self.loadedFromPlan = true
        } else {
            _config = State(initialValue: .defaultConfig())
            self.loadedFromPlan = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: Eingabe

                if loadedFromPlan {
                    planLoadedBanner
                }

                villageTypePicker
                resourceFieldsSection
                boosterSection
                oasisSection
                optionsSection
                calculateButton

                // MARK: Ergebnis

                if hasCalculated {
                    if results.isEmpty {
                        noResultsView
                    } else {
                        resultsSummary
                        resultsViewModePicker
                        resultsList
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ausbau-Rechner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Plan-Banner

    private var planLoadedBanner: some View {
        let setCount = config.resourceFieldLevels.filter { $0.level > 0 }.count
        let totalCount = config.resourceFieldLevels.count
        return HStack(spacing: 8) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.caption)
                .foregroundStyle(.purple)
            Text("Aus Dorfplaner geladen — \(setCount)/\(totalCount) Felder mit Stufe")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    // MARK: - Dorf-Typ

    private var villageTypePicker: some View {
        VStack(spacing: 6) {
            Text("Dorf-Typ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Dorf-Typ", selection: Binding(
                get: { config.villageType },
                set: { newType in
                    config.villageType = newType
                    config.resourceFieldLevels = newType.generateFields()
                    hasCalculated = false
                    results = []
                }
            )) {
                ForEach(VillageResourceType.allCases) { type in
                    HStack {
                        Text(type.label)
                        if !type.subtitle.isEmpty {
                            Text("(\(type.subtitle))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Rohstofffelder

    private var resourceFieldsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Rohstofffelder")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button(showFieldDetail ? "Weniger" : "Einzeln") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFieldDetail.toggle()
                    }
                }
                .font(.caption2)
                .foregroundStyle(.teal)
            }

            // Gruppiert nach Typ
            ForEach(ResourceFieldType.allCases) { type in
                let indices = config.resourceFieldLevels.indices.filter {
                    config.resourceFieldLevels[$0].resourceType == type
                }
                let count = indices.count
                guard count > 0 else { return AnyView(EmptyView()) }

                return AnyView(VStack(spacing: 6) {
                    // Gruppenstepper: setzt alle Felder des Typs auf den gleichen Wert
                    HStack {
                        Text(type.emoji)
                            .font(.callout)
                        Text("\(count)× \(type.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()

                        // Stepper für Gruppen-Level
                        let groupLevel = groupLevelForType(type)
                        let hasMixed = hasMixedLevels(for: type)
                        Stepper(value: Binding(
                            get: { groupLevel },
                            set: { newLevel in
                                for idx in indices {
                                    config.resourceFieldLevels[idx].level = newLevel
                                }
                            }
                        ), in: 0...20) {
                            if hasMixed {
                                Text("gemischt")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                                    .frame(width: 70, alignment: .trailing)
                            } else {
                                Text(groupLevel > 0 ? "Stufe \(groupLevel)" : "–")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(type.color)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }

                    // Einzelne Felder (aufklappbar)
                    if showFieldDetail {
                        ForEach(indices, id: \.self) { idx in
                            HStack {
                                Text("Feld \(config.resourceFieldLevels[idx].fieldNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Stepper(value: $config.resourceFieldLevels[idx].level, in: 0...20) {
                                    Text(config.resourceFieldLevels[idx].level > 0
                                         ? "\(config.resourceFieldLevels[idx].level)"
                                         : "–")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .foregroundStyle(type.color)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                            .padding(.leading, 32)
                        }
                    }

                    if type != .crop {
                        Divider()
                    }
                })
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// Ermittelt das gemeinsame Level aller Felder eines Typs (oder das niedrigste)
    private func groupLevelForType(_ type: ResourceFieldType) -> Int {
        let levels = config.resourceFieldLevels
            .filter { $0.resourceType == type }
            .map { $0.level }
        let unique = Set(levels)
        return unique.count == 1 ? (unique.first ?? 0) : (levels.min() ?? 0)
    }

    /// Prüft ob Felder eines Typs unterschiedliche Stufen haben
    private func hasMixedLevels(for type: ResourceFieldType) -> Bool {
        let levels = config.resourceFieldLevels
            .filter { $0.resourceType == type }
            .map { $0.level }
        return Set(levels).count > 1
    }

    // MARK: - Veredelungsgebäude

    private var boosterSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                Text("Veredelungsgebäude")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            boosterStepper(emoji: "🪵", name: "Sägewerk", value: $config.sawmillLevel, color: .green)
            boosterStepper(emoji: "🧱", name: "Lehmbrennerei", value: $config.brickyardLevel, color: .orange)
            boosterStepper(emoji: "⚙️", name: "Eisenschmelze", value: $config.ironFoundryLevel, color: .gray)
            Divider()
            boosterStepper(emoji: "🌾", name: "Getreidemühle", value: $config.grainMillLevel, color: .yellow)
            boosterStepper(emoji: "🌾", name: "Bäckerei", value: $config.bakeryLevel, color: .yellow)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func boosterStepper(emoji: String, name: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Text(emoji)
                .font(.callout)
            Text(name)
                .font(.subheadline)
            Spacer()
            Stepper(value: value, in: 0...5) {
                Text(value.wrappedValue > 0 ? "\(value.wrappedValue)" : "–")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue > 0 ? color : Color(.tertiaryLabel))
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    // MARK: - Oasen-Bonus

    private var oasisSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "tree.fill")
                    .font(.caption)
                    .foregroundStyle(.brown)
                Text("Oasen-Bonus")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            oasisPicker(emoji: "🪵", label: "Holz", value: $config.oasisBonus.woodPercent, color: .green)
            oasisPicker(emoji: "🧱", label: "Lehm", value: $config.oasisBonus.clayPercent, color: .orange)
            oasisPicker(emoji: "⚙️", label: "Eisen", value: $config.oasisBonus.ironPercent, color: .gray)
            oasisPicker(emoji: "🌾", label: "Getreide", value: $config.oasisBonus.cropPercent, color: .yellow)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func oasisPicker(emoji: String, label: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Text(emoji)
                .font(.callout)
            Text(label)
                .font(.subheadline)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Picker("", selection: value) {
                Text("0%").tag(0)
                Text("25%").tag(25)
                Text("50%").tag(50)
                Text("75%").tag(75)
                Text("100%").tag(100)
                Text("125%").tag(125)
                Text("150%").tag(150)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
    }

    // MARK: - Optionen

    private var optionsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Optionen")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            Toggle(isOn: $config.goldBoost) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("Gold-Produktionsbonus (+25%)")
                        .font(.subheadline)
                }
            }
            .tint(.yellow)

            Toggle(isOn: $config.skipWCIBoosters) {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Holz/Lehm/Eisen-Booster ignorieren")
                        .font(.subheadline)
                }
            }
            .tint(.red)

            Divider()

            HStack {
                Text("Schritte")
                    .font(.subheadline)
                Spacer()
                Picker("Schritte", selection: $config.maxSteps) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Berechnen-Button

    private var calculateButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                results = UpgradeCalculator.computeBuildOrder(config: config)
                hasCalculated = true
            }
        } label: {
            Label("Berechnen", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .padding(.horizontal)
    }

    // MARK: - Kein Ergebnis

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Keine Upgrades möglich")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Setze mindestens ein Feld auf Stufe 1 oder höher.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Ergebnis-Zusammenfassung

    private var resultsSummary: some View {
        let last = results.last!
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text("Ergebnis — \(results.count) Schritte")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Endproduktion
            HStack(spacing: 0) {
                prodSummaryCell(emoji: "🪵", value: last.cumulativeWoodProd, color: .green)
                prodSummaryCell(emoji: "🧱", value: last.cumulativeClayProd, color: .orange)
                prodSummaryCell(emoji: "⚙️", value: last.cumulativeIronProd, color: .gray)
                prodSummaryCell(emoji: "🌾", value: last.cumulativeCropProd, color: .yellow)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesamt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formatProd(last.cumulativeTotalProd))/h")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.teal)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kosten")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatCost(last.cumulativeTotalCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func prodSummaryCell(emoji: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.caption)
            Text("\(formatProd(value))/h")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ansichts-Modus Toggle

    private var resultsViewModePicker: some View {
        Picker("Ansicht", selection: $resultViewMode) {
            ForEach(ResultViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Ergebnis-Liste

    private var resultsList: some View {
        LazyVStack(spacing: resultViewMode == .compact ? 0 : 8) {
            ForEach(results) { step in
                switch resultViewMode {
                case .compact:
                    compactRow(step)
                case .detail:
                    detailCard(step)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Kompakt-Zeile

    private func compactRow(_ step: UpgradeStep) -> some View {
        HStack(spacing: 8) {
            Text("\(step.id)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.teal.gradient)
                .clipShape(Circle())

            Image(systemName: step.buildingIcon)
                .font(.caption)
                .foregroundStyle(iconColor(for: step))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.buildingName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Stufe \(step.fromLevel) → \(step.toLevel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("+\(formatProd(step.productionDelta))/h")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
                Text("Σ \(formatProd(step.cumulativeTotalProd))/h")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: step.id == 1 ? 12 : 0))
        .overlay(alignment: .bottom) {
            if step.id != results.count {
                Divider().padding(.leading, 42)
            }
        }
    }

    // MARK: Detail-Card

    private func detailCard(_ step: UpgradeStep) -> some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("#\(step.id)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.teal.gradient)
                    .clipShape(Circle())

                Image(systemName: step.buildingIcon)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(iconColor(for: step).gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(step.buildingName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Stufe \(step.fromLevel) → \(step.toLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("+\(formatProd(step.productionDelta))/h")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            Divider()

            // Kosten
            HStack(spacing: 12) {
                costBadge(emoji: "🪵", value: step.woodCost)
                costBadge(emoji: "🧱", value: step.clayCost)
                costBadge(emoji: "⚙️", value: step.ironCost)
                costBadge(emoji: "🌾", value: step.cropCost)
            }

            // Bauzeit + Bevölkerung
            HStack {
                Label(formatTime(step.baseTimeSec), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("+\(step.pop)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Effizienz: \(String(format: "%.5f", step.efficiency))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Kumulative Produktion
            HStack(spacing: 0) {
                miniProdCell(emoji: "🪵", value: step.cumulativeWoodProd)
                miniProdCell(emoji: "🧱", value: step.cumulativeClayProd)
                miniProdCell(emoji: "⚙️", value: step.cumulativeIronProd)
                miniProdCell(emoji: "🌾", value: step.cumulativeCropProd)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func costBadge(emoji: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(emoji)
                .font(.caption2)
            Text(formatCost(value))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func miniProdCell(emoji: String, value: Double) -> some View {
        VStack(spacing: 1) {
            Text(emoji)
                .font(.caption2)
            Text("\(formatProd(value))")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hilfsfunktionen

    private func iconColor(for step: UpgradeStep) -> Color {
        switch step.upgradeType {
        case .resourceField(_, let type):
            return type.color
        case .booster:
            return .indigo
        }
    }

    private func formatProd(_ value: Double) -> String {
        if value >= 1000 {
            if value.truncatingRemainder(dividingBy: 1000) < 1 {
                return "\(Int(value) / 1000)k"
            }
            return String(format: "%.1fk", value / 1000.0)
        }
        if value == Double(Int(value)) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func formatCost(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000.0)
        }
        if value >= 1000 {
            if value % 1000 == 0 {
                return "\(value / 1000)k"
            }
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return String(format: "%d:%02d:00", h, m)
        }
        return String(format: "%d:%02d", m, seconds % 60)
    }
}
