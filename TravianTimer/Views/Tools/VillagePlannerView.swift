import SwiftUI
import PhotosUI
import UIKit

// MARK: - Tab Auswahl

private enum PlannerTab: String, CaseIterable {
    case buildings = "Gebäude"
    case resources = "Rohstofffelder"
}

/// Wrapper für sheet(item:) — vermeidet leeres Popup bei erster Interaktion
private struct SlotSelection: Identifiable {
    let id: Int // slot index
}

private struct FieldSelection: Identifiable {
    let id: Int // field index
}

// MARK: - Dorfplaner View

struct VillagePlannerView: View {

    @State private var planStore = VillagePlanStore.shared
    @State var plan: VillagePlan
    @State private var selectedTab: PlannerTab = .buildings
    @State private var isEditingName = false
    @FocusState private var nameFieldFocused: Bool

    // Gebäude-Tab State
    @State private var buildingPickerSlot: SlotSelection?

    // Rohstofffelder-Tab State
    @State private var fieldPickerSelection: FieldSelection?

    // Speicher-Feedback
    @State private var showSavedIndicator = false

    // Screenshot-Import
    @State private var showScreenshotImport = false
    @State private var showHTMLImport = false
    @State private var showPopPlanner = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Dashboard Header
                    dashboardHeader

                    // MARK: Tab-Auswahl
                    Picker("Ansicht", selection: $selectedTab) {
                        ForEach(PlannerTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // MARK: Tab Content
                    switch selectedTab {
                    case .buildings:
                        buildingsTabContent
                    case .resources:
                        resourcesTabContent
                    }

                    Spacer(minLength: 60)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))

            // MARK: Save Toast
            if showSavedIndicator {
                saveToast
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("Dorfplaner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Menu {
                        Button {
                            showHTMLImport = true
                        } label: {
                            Label("HTML importieren", systemImage: "doc.text")
                        }

                        Button {
                            showScreenshotImport = true
                        } label: {
                            Label("Screenshot importieren", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Button {
                        savePlan()
                    } label: {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    .tint(.orange)
                }
            }
        }
        .sheet(isPresented: $showScreenshotImport) {
            ScreenshotImportSheet(
                mode: selectedTab == .buildings ? .buildings : .resources,
                onApplyResources: { data in
                    VillageScreenshotService.applyToPlan(data, plan: &plan)
                    savePlan()
                    selectedTab = .resources
                },
                onApplyBuildings: { data in
                    VillageScreenshotService.applyBuildingsToPlan(data, plan: &plan)
                    savePlan()
                    selectedTab = .buildings
                }
            )
        }
        .sheet(isPresented: $showHTMLImport) {
            HTMLImportSheet { parsedVillage in
                VillageScreenshotService.applyToPlan(parsedVillage.resourceData, plan: &plan)
                HTMLVillageParser.applyToPlan(parsedVillage, plan: &plan)
                savePlan()
            }
        }
        .sheet(item: $buildingPickerSlot) { selection in
            let idx = selection.id
            let slot = plan.slots[idx]
            if slot.isRallyPointSlot {
                RallyPointPickerSheet(slot: slot) { buildingId, level in
                    plan.slots[idx].buildingId = buildingId
                    plan.slots[idx].level = buildingId != nil ? level : 0
                    savePlan()
                }
            } else {
                BuildingPickerSheet(slot: slot) { buildingId, level in
                    plan.slots[idx].buildingId = buildingId
                    plan.slots[idx].level = buildingId != nil ? level : 0
                    savePlan()
                } onClear: {
                    plan.slots[idx].buildingId = nil
                    plan.slots[idx].level = 0
                    savePlan()
                }
            }
        }
        .sheet(item: $fieldPickerSelection) { selection in
            ResourceFieldLevelSheet(field: plan.resourceFields[selection.id]) { newLevel in
                plan.resourceFields[selection.id].level = newLevel
                savePlan()
            }
        }
        .sheet(isPresented: $showPopPlanner) {
            PopulationPlannerSheet(plan: $plan, currentPopulation: totalPopulation, onSave: savePlan)
        }
        .onDisappear {
            // Auto-Save beim Verlassen (Sicherheitsnetz)
            planStore.upsert(plan)
        }
    }

    // MARK: - Speichern

    private func savePlan() {
        planStore.upsert(plan)
        // Haptic Feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            showSavedIndicator = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedIndicator = false
            }
        }
    }

    // MARK: - Save Toast

    private var saveToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text("Gespeichert")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.1))
                .overlay(Capsule().stroke(Color.green.opacity(0.2), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    // MARK: - Dashboard Header

    private var dashboardHeader: some View {
        VStack(spacing: 12) {

            // Planname + Dorf-Typ
            HStack {
                if isEditingName {
                    TextField("Plan-Name", text: $plan.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFieldFocused)
                        .onSubmit { finishEditing() }

                    Button {
                        finishEditing()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                    }
                } else {
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Button {
                        isEditingName = true
                        nameFieldFocused = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(plan.villageType.label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brown.opacity(0.7).gradient)
                    .clipShape(Capsule())
            }

            // 4-Stat-Tiles
            let filled = plan.slots.filter { !$0.isEmpty }.count
            let fieldsSet = plan.resourceFields.filter { $0.level > 0 }.count
            let totalProd = plan.totalProductionSum

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                statTile(icon: "building.2.fill", value: "\(filled)", label: "/23 Geb.", color: .blue)
                statTile(icon: "leaf.fill", value: "\(fieldsSet)", label: "/18 Feld.", color: .green)
                statTile(icon: "chart.bar.fill", value: formatNumber(totalProd), label: "/h", color: .orange)
                Button { showPopPlanner = true } label: {
                    statTile(icon: "person.2.fill", value: "\(totalPopulation)", label: "Pop", color: .purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
        )
    }

    /// Bevölkerung: Summe aller Gebäude-Pop + Rohstofffeld-Pop auf aktuellem Level
    private var totalPopulation: Int {
        var pop = 0
        for slot in plan.slots where slot.buildingId != nil {
            if let building = Building.allBuildings.first(where: { $0.id == slot.buildingId }),
               slot.level > 0,
               slot.level <= building.levels.count {
                pop += building.levels[slot.level - 1].pop
            }
        }
        for field in plan.resourceFields where field.level > 0 {
            pop += field.resourceType.population(at: field.level)
        }
        return pop
    }

    private func finishEditing() {
        isEditingName = false
        nameFieldFocused = false
        savePlan()
    }
}

// MARK: - Gebäude Tab

private extension VillagePlannerView {

    var buildingsTabContent: some View {
        VStack(spacing: 16) {

            // Zähler
            let filled = plan.slots.filter { !$0.isEmpty }.count
            HStack(spacing: 4) {
                Image(systemName: "building.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("\(filled)/\(plan.slots.count) belegt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Kreisförmiges Layout
            buildingsCircleLayout

            // Gebäude-Legende
            buildingCategoryLegend

            // Freischaltbare Slots
            unlockableSection
        }
    }

    var buildingsCircleLayout: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, 400)
            let center = CGPoint(x: size / 2, y: size / 2)
            let slotSize: CGFloat = min(52, size / 7.5)
            let innerRadius = size * 0.18
            let outerRadius = size * 0.40

            ZStack {
                // Hintergrund mit radialem Gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(.systemBackground), Color(.secondarySystemGroupedBackground)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                    .frame(width: size, height: size)

                // Radiale Wege (N, O, S, W) — dekorativ
                ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                    pathLine(from: center, angle: angle,
                             innerRadius: innerRadius * 0.6,
                             outerRadius: size / 2 - 4, viewSize: size)
                }
                .allowsHitTesting(false)

                // Zentrum (dekorativ, nicht bebaubar)
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: slotSize * 1.1, height: slotSize * 1.1)
                    .overlay(
                        Image(systemName: "house.fill")
                            .font(.system(size: slotSize * 0.3))
                            .foregroundStyle(.secondary.opacity(0.4))
                    )
                    .position(center)
                    .allowsHitTesting(false)

                // Ring-Linien (dekorativ)
                Circle()
                    .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .position(center)
                    .allowsHitTesting(false)
                Circle()
                    .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)
                    .allowsHitTesting(false)

                // Innerer Ring: Felder 1-5
                ForEach(0..<5, id: \.self) { i in
                    let slotNumber = i + 1
                    let angle = Double(i) * 72.0 - 90.0
                    let pos = polarToCartesian(center: center, radius: innerRadius, angleDeg: angle)
                    buildingSlotButton(for: slotNumber, size: slotSize)
                        .position(pos)
                }

                // Äusserer Ring: Felder 6-21 (4 × 4 Slots)
                ForEach(0..<4, id: \.self) { quadrant in
                    let baseAngle = Double(quadrant) * 90.0
                    ForEach(0..<4, id: \.self) { i in
                        let slotNumber = 6 + quadrant * 4 + i
                        let sectorStart = baseAngle + 12.0
                        let sectorSpacing = 66.0 / 3.0
                        let angle = sectorStart + Double(i) * sectorSpacing - 90.0
                        let pos = polarToCartesian(center: center, radius: outerRadius, angleDeg: angle)
                        buildingSlotButton(for: slotNumber, size: slotSize)
                            .position(pos)
                    }
                }

                // Mauer-Ring (dekorativ)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.red.opacity(0.35), .red.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 2.5, dash: [8, 4])
                    )
                    .frame(width: size - 8, height: size - 8)
                    .position(center)
                    .allowsHitTesting(false)

                Text("Mauer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.4))
                    .position(x: center.x, y: size - 14)
                    .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal)
    }

    func buildingSlotButton(for slotNumber: Int, size: CGFloat) -> some View {
        let slotIndex = slotNumber - 1
        let slot = plan.slots[slotIndex]
        let building: Building? = slot.buildingId.flatMap { id in
            Building.allBuildings.first(where: { $0.id == id })
        }

        return Button {
            buildingPickerSlot = SlotSelection(id: slotIndex)
        } label: {
            BuildingSlotView(slot: slot, building: building, size: size)
        }
        .buttonStyle(SlotPressStyle())
    }

    // MARK: Gebäude-Legende

    var buildingCategoryLegend: some View {
        let categoryCounts = Dictionary(
            grouping: plan.slots.compactMap { slot -> BuildingCategory? in
                guard let bid = slot.buildingId,
                      let b = Building.allBuildings.first(where: { $0.id == bid }) else { return nil }
                return b.category
            },
            by: { $0 }
        ).mapValues(\.count)

        return HStack(spacing: 16) {
            ForEach(BuildingCategory.allCases) { cat in
                HStack(spacing: 4) {
                    Circle()
                        .fill(cat.color)
                        .frame(width: 8, height: 8)
                    Text("\(cat.title): \(categoryCounts[cat] ?? 0)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    var unlockableSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "ticket.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Freischaltbare Bauplätze")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                buildingSlotButton(for: 22, size: 50)
                buildingSlotButton(for: 23, size: 50)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Rohstofffelder Tab

private extension VillagePlannerView {

    var resourcesTabContent: some View {
        VStack(spacing: 16) {

            // Dorf-Typ Picker (horizontal)
            villageTypePicker

            // Zusammenfassung
            resourceSummary

            // Kreisförmiges Layout
            resourceFieldsCircleLayout

            // Produktionsübersicht
            if plan.hasAnyResourceLevel {
                productionOverview

                // Link zum Ausbau-Rechner
                NavigationLink {
                    UpgradeCalculatorView(plan: plan)
                } label: {
                    Label("Ausbau-Reihenfolge berechnen", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.teal)
                .padding(.horizontal)
            }
        }
    }

    // MARK: Dorf-Typ Picker (horizontal)

    var villageTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dorf-Typ")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VillageResourceType.allCases) { type in
                        let isSelected = plan.villageType == type
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                plan.changeVillageType(to: type)
                                savePlan()
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(type.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                if !type.subtitle.isEmpty {
                                    Text(type.subtitle)
                                        .font(.system(size: 9))
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected
                                          ? Color.orange.gradient
                                          : Color(.secondarySystemGroupedBackground).gradient)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    // MARK: Ressourcen-Zusammenfassung

    var resourceSummary: some View {
        let d = plan.villageType.distribution
        return HStack(spacing: 6) {
            resourceMiniTile(emoji: "🪵", count: d.wood, color: .green)
            resourceMiniTile(emoji: "🧱", count: d.clay, color: .orange)
            resourceMiniTile(emoji: "⚙️", count: d.iron, color: .gray)
            resourceMiniTile(emoji: "🌾", count: d.crop, color: .yellow)
        }
        .padding(.horizontal)
    }

    func resourceMiniTile(emoji: String, count: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(emoji)
                .font(.callout)
            Text("×\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.4))
                        .frame(height: 3)
                        .clipShape(
                            .rect(topLeadingRadius: 10, topTrailingRadius: 10)
                        )
                }
        )
    }

    // MARK: Kreislayout Rohstofffelder

    var resourceFieldsCircleLayout: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, 400)
            let center = CGPoint(x: size / 2, y: size / 2)
            let slotSize: CGFloat = min(46, size / 8.5)
            let radius = size * 0.37

            ZStack {
                // Hintergrund mit Gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(.systemBackground), Color(.secondarySystemGroupedBackground)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                    .frame(width: size, height: size)

                // Ring-Linie
                Circle()
                    .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Zentrum: Dorf-Typ Label
                VStack(spacing: 3) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text(plan.villageType.label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .position(center)

                // 18 Rohstofffelder im Kreis
                ForEach(Array(plan.resourceFields.enumerated()), id: \.element.id) { index, field in
                    let angle = Double(index) * (360.0 / 18.0) - 90.0
                    let pos = polarToCartesian(center: center, radius: radius, angleDeg: angle)

                    Button {
                        fieldPickerSelection = FieldSelection(id: index)
                    } label: {
                        ResourceFieldSlotView(field: field, size: slotSize)
                    }
                    .buttonStyle(SlotPressStyle())
                    .position(pos)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal)
    }

    // MARK: - Produktionsübersicht

    var productionOverview: some View {
        let prod = plan.totalProduction
        let total = plan.totalProductionSum
        let setCount = plan.resourceFields.filter { $0.level > 0 }.count
        let totalCount = plan.resourceFields.count
        let progress = Double(setCount) / Double(totalCount)

        return VStack(spacing: 14) {

            // Header mit Fortschritts-Ring
            HStack(spacing: 12) {
                // Donut-Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Produktion / Stunde")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(setCount)/\(totalCount) Felder gesetzt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatNumber(total) + "/h")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }

            // Ressourcen-Balken
            VStack(spacing: 10) {
                productionRow(emoji: "🪵", label: "Holz", value: prod.wood, color: .green, maxValue: maxSingleProd)
                productionRow(emoji: "🧱", label: "Lehm", value: prod.clay, color: .orange, maxValue: maxSingleProd)
                productionRow(emoji: "⚙️", label: "Eisen", value: prod.iron, color: .gray, maxValue: maxSingleProd)
                productionRow(emoji: "🌾", label: "Getreide", value: prod.crop, color: .yellow, maxValue: maxSingleProd)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    /// Höchster Einzelwert für proportionale Balken
    private var maxSingleProd: Int {
        let p = plan.totalProduction
        return max(p.wood, p.clay, p.iron, p.crop, 1)
    }

    func productionRow(emoji: String, label: String, value: Int, color: Color, maxValue: Int) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.callout)
                .frame(width: 24)

            // Balken
            GeometryReader { geo in
                let fraction = CGFloat(value) / CGFloat(maxValue)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.gradient)
                        .frame(width: max(fraction * geo.size.width, value > 0 ? 4 : 0), height: 18)
                }
            }
            .frame(height: 18)

            // Wert
            Text(formatNumber(value))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .primary : .tertiary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let thousands = Double(n) / 1000.0
            if n % 1000 == 0 {
                return "\(n / 1000)k"
            }
            return String(format: "%.1fk", thousands)
        }
        return "\(n)"
    }
}

// MARK: - Hilfsfunktionen

private extension VillagePlannerView {

    func polarToCartesian(center: CGPoint, radius: CGFloat, angleDeg: Double) -> CGPoint {
        let rad = angleDeg * .pi / 180.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }

    func pathLine(from center: CGPoint, angle: Double, innerRadius: CGFloat, outerRadius: CGFloat, viewSize: CGFloat) -> some View {
        let rad = (angle - 90.0) * .pi / 180.0
        let start = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(rad)),
            y: center.y + innerRadius * CGFloat(sin(rad))
        )
        let end = CGPoint(
            x: center.x + outerRadius * CGFloat(cos(rad)),
            y: center.y + outerRadius * CGFloat(sin(rad))
        )
        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        .frame(width: viewSize, height: viewSize)
    }
}

// MARK: - Slot Press Button Style

private struct SlotPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Building Slot View

private struct BuildingSlotView: View {
    let slot: PlanSlot
    let building: Building?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let building {
                // Gefüllter Slot
                Image(systemName: building.icon)
                    .font(.system(size: size * 0.34))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(building.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                    .shadow(color: building.category.color.opacity(0.3), radius: 3, y: 2)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(slot.level)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.gradient)
                            .clipShape(Capsule())
                            .offset(x: 4, y: 4)
                    }
            } else if slot.isRallyPointSlot {
                // Rally-Point Slot (leer)
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.orange.opacity(0.06))
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .strokeBorder(Color.orange.opacity(0.5),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    )
                    .overlay {
                        VStack(spacing: 1) {
                            Image(systemName: "flag.2.crossed.fill")
                                .font(.system(size: size * 0.22))
                                .foregroundStyle(.orange.opacity(0.6))
                            Text("VP")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange.opacity(0.5))
                        }
                    }
            } else {
                // Leerer Slot
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .strokeBorder(
                                slot.isUnlockableSlot
                                    ? Color.orange.opacity(0.3)
                                    : Color(.separator).opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5])
                            )
                    )
                    .overlay {
                        VStack(spacing: 1) {
                            Image(systemName: slot.isUnlockableSlot ? "lock.fill" : "plus")
                                .font(.system(size: size * 0.22))
                                .foregroundStyle(slot.isUnlockableSlot ? .orange.opacity(0.5) : .orange.opacity(0.6))
                            Text("\(slot.slotNumber)")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }
}

// MARK: - Resource Field Slot View

private struct ResourceFieldSlotView: View {
    let field: ResourceFieldSlot
    let size: CGFloat

    var body: some View {
        ZStack {
            if field.level > 0 {
                // Belegtes Feld
                Image(systemName: field.resourceType.icon)
                    .font(.system(size: size * 0.34))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(field.resourceType.color.gradient)
                    .clipShape(Circle())
                    .shadow(color: field.resourceType.color.opacity(0.3), radius: 3, y: 2)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(field.level)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.gradient)
                            .clipShape(Capsule())
                            .offset(x: 3, y: 3)
                    }
            } else {
                // Leeres Feld
                Circle()
                    .fill(field.resourceType.color.opacity(0.06))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(field.resourceType.color.opacity(0.4),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    )
                    .overlay {
                        VStack(spacing: 1) {
                            Image(systemName: field.resourceType.icon)
                                .font(.system(size: size * 0.24))
                                .foregroundStyle(field.resourceType.color.opacity(0.6))
                            Text("\(field.fieldNumber)")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }
}

// MARK: - Resource Field Level Sheet

struct ResourceFieldLevelSheet: View {

    let field: ResourceFieldSlot
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLevel: Int

    init(field: ResourceFieldSlot, onSave: @escaping (Int) -> Void) {
        self.field = field
        self.onSave = onSave
        _selectedLevel = State(initialValue: max(field.level, 1))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: field.resourceType.icon)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(field.resourceType.color.gradient)
                            .clipShape(Circle())
                            .shadow(color: field.resourceType.color.opacity(0.3), radius: 4, y: 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.resourceType.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Feld \(field.fieldNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Stufe") {
                    Stepper(value: $selectedLevel, in: 0...20) {
                        HStack {
                            Text("Stufe")
                            Spacer()
                            Text(selectedLevel > 0 ? "\(selectedLevel)" : "–")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(field.resourceType.color)
                        }
                    }

                    if selectedLevel > 0 {
                        HStack {
                            Text("Produktion")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(ResourceFieldType.production(at: selectedLevel))/h")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                    }

                    if selectedLevel > 0 {
                        Button("Zurücksetzen", role: .destructive) {
                            selectedLevel = 0
                        }
                    }
                }
            }
            .navigationTitle("Rohstofffeld")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave(selectedLevel)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Rally Point Picker Sheet

struct RallyPointPickerSheet: View {

    let slot: PlanSlot
    let onSave: (Int?, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPlaced: Bool
    @State private var selectedLevel: Int

    private let rallyPoint: Building? = Building.allBuildings.first(where: { $0.id == 16 })

    init(slot: PlanSlot, onSave: @escaping (Int?, Int) -> Void) {
        self.slot = slot
        self.onSave = onSave
        _isPlaced = State(initialValue: slot.buildingId == 16)
        _selectedLevel = State(initialValue: max(1, slot.level))
    }

    var body: some View {
        NavigationStack {
            List {
                if let rp = rallyPoint {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: rp.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.orange.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: Color.orange.opacity(0.3), radius: 4, y: 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rp.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(rp.shortDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle("Versammlungsplatz bauen", isOn: $isPlaced)
                            .tint(.orange)
                    } header: {
                        Text("Rally Point")
                    } footer: {
                        Text("Auf diesem Bauplatz kann nur der Versammlungsplatz gebaut werden.")
                    }

                    if isPlaced {
                        Section("Stufe") {
                            Stepper(value: $selectedLevel, in: 1...rp.maxLevel) {
                                HStack {
                                    Text("Stufe")
                                    Spacer()
                                    Text("\(selectedLevel)")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bauplatz \(slot.slotNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave(isPlaced ? 16 : nil, isPlaced ? selectedLevel : 0)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Building Picker Sheet

struct BuildingPickerSheet: View {

    let slot: PlanSlot
    let onSave: (Int?, Int) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBuilding: Building?
    @State private var selectedLevel: Int = 1
    @State private var searchText = ""

    // Ausgeblendet: Rally Point (16, eigener Slot) + Rohstofffelder (1-4, eigener Tab)
    private let hiddenBuildingIds: Set<Int> = [1, 2, 3, 4, 16]

    init(slot: PlanSlot, onSave: @escaping (Int?, Int) -> Void, onClear: @escaping () -> Void) {
        self.slot = slot
        self.onSave = onSave
        self.onClear = onClear
        _selectedBuilding = State(initialValue:
            slot.buildingId.flatMap { id in
                Building.allBuildings.first(where: { $0.id == id })
            }
        )
        _selectedLevel = State(initialValue: max(1, slot.level))
    }

    private func filteredBuildings(for category: BuildingCategory) -> [Building] {
        let buildings = category.buildings.filter { !hiddenBuildingIds.contains($0.id) }
        if searchText.isEmpty { return buildings }
        let query = searchText.lowercased()
        return buildings.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Ausgewähltes Gebäude – prominente Karte
                if let building = selectedBuilding {
                    Section {
                        VStack(spacing: 12) {
                            HStack(spacing: 14) {
                                Image(systemName: building.icon)
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(building.category.color.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: building.category.color.opacity(0.3), radius: 4, y: 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(building.name)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text(building.shortDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            // Level Stepper
                            HStack {
                                Text("Stufe")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(selectedLevel)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(building.category.color)
                                    .frame(width: 40)
                                Stepper("", value: $selectedLevel, in: 1...building.maxLevel)
                                    .labelsHidden()
                            }
                        }
                    } header: {
                        Text("Auswahl")
                    }
                }

                // Gebäude nach Kategorie
                ForEach(BuildingCategory.allCases) { category in
                    let buildings = filteredBuildings(for: category)
                    if !buildings.isEmpty {
                        Section {
                            ForEach(buildings) { building in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedBuilding = building
                                        selectedLevel = min(selectedLevel, building.maxLevel)
                                        if selectedLevel < 1 { selectedLevel = 1 }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: building.icon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .frame(width: 34, height: 34)
                                            .background(building.category.color.gradient)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(building.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            if let tribe = building.tribe {
                                                Text(tribe)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Text("1–\(building.maxLevel)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)

                                        if selectedBuilding?.id == building.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(building.category.color)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Label(category.title, systemImage: category.icon)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Gebäude suchen")
            .navigationTitle("Bauplatz \(slot.slotNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !slot.isEmpty {
                        Button("Leeren", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if slot.isEmpty {
                        Button("Abbrechen") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave(selectedBuilding?.id, selectedLevel)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedBuilding == nil && slot.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Screenshot Import Mode

enum ScreenshotImportMode {
    case resources   // Rohstofffelder-Ansicht
    case buildings   // Dorfuebersicht (Gebaeude)

    var title: String {
        switch self {
        case .resources: return "Rohstofffelder importieren"
        case .buildings: return "Gebäude importieren"
        }
    }

    var icon: String {
        switch self {
        case .resources: return "leaf.fill"
        case .buildings: return "building.2.fill"
        }
    }

    var instruction: String {
        switch self {
        case .resources:
            return "Mache einen Screenshot der Ressourcenfelder-Ansicht in Travian Kingdoms. Die KI erkennt den Dorf-Typ und alle Feld-Stufen automatisch."
        case .buildings:
            return "Mache einen Screenshot der Dorfübersicht (Gebäude-Ansicht) in Travian Kingdoms. Die KI erkennt alle Gebäude und deren Stufen automatisch."
        }
    }
}

// MARK: - Screenshot Import Sheet

struct ScreenshotImportSheet: View {

    let mode: ScreenshotImportMode
    let onApplyResources: ((ParsedVillageData) -> Void)?
    let onApplyBuildings: ((ParsedBuildingData) -> Void)?

    init(
        mode: ScreenshotImportMode,
        onApplyResources: ((ParsedVillageData) -> Void)? = nil,
        onApplyBuildings: ((ParsedBuildingData) -> Void)? = nil
    ) {
        self.mode = mode
        self.onApplyResources = onApplyResources
        self.onApplyBuildings = onApplyBuildings
    }

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var resourceResult: ParsedVillageData?
    @State private var buildingResult: ParsedBuildingData?
    @State private var analysisError: String?

    private var hasResult: Bool {
        resourceResult != nil || buildingResult != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Anleitung
                    if selectedImage == nil && !hasResult {
                        instructionCard
                    }

                    // MARK: Bild-Auswahl
                    imagePickerSection

                    // MARK: Bild-Vorschau
                    if let image = selectedImage {
                        imagePreview(image)
                    }

                    // MARK: Analysieren-Button
                    if selectedImage != nil && !hasResult {
                        analyzeButton
                    }

                    // MARK: Fehler
                    if let error = analysisError {
                        errorCard(error)
                    }

                    // MARK: Ergebnis (Rohstofffelder)
                    if let result = resourceResult {
                        resourceResultCard(result)
                    }

                    // MARK: Ergebnis (Gebaeude)
                    if let result = buildingResult {
                        buildingResultCard(result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Screenshot Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if hasResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Übernehmen") {
                            applyResult()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: selectedPhoto) { _, newValue in
            Task { await loadImage(from: newValue) }
        }
    }

    // MARK: - Ergebnis anwenden

    private func applyResult() {
        switch mode {
        case .resources:
            if let result = resourceResult { onApplyResources?(result) }
        case .buildings:
            if let result = buildingResult { onApplyBuildings?(result) }
        }
    }

    // MARK: - Anleitung

    private var instructionCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.15), .orange.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: mode == .buildings ? "building.2.fill" : "camera.viewfinder")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange.opacity(0.7))
            }

            VStack(spacing: 4) {
                Text(mode.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(mode.instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Bild-Picker

    private var imagePickerSection: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .screenshots,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 8) {
                Image(systemName: selectedImage == nil ? "photo.on.rectangle.angled" : "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                Text(selectedImage == nil ? "Screenshot auswählen" : "Anderes Bild wählen")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Bild-Vorschau

    private func imagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Analysieren Button

    private var analyzeButton: some View {
        Button {
            Task { await analyzeScreenshot() }
        } label: {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isAnalyzing ? "Analysiere…" : "Screenshot analysieren")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(isAnalyzing)
    }

    // MARK: - Fehler-Karte

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Analyse fehlgeschlagen")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                analysisError = nil
                Task { await analyzeScreenshot() }
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Rohstofffeld-Ergebnis-Karte

    private func resourceResultCard(_ data: ParsedVillageData) -> some View {
        VStack(spacing: 14) {
            resultHeader

            Divider()

            // Dorf-Typ
            HStack {
                Text("Dorf-Typ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(data.villageType)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Feld-Übersicht nach Typ gruppiert
            let grouped = Dictionary(grouping: data.fields, by: { $0.type })
            let typeOrder = ["wood", "clay", "iron", "crop"]

            VStack(spacing: 8) {
                ForEach(typeOrder, id: \.self) { type in
                    if let fields = grouped[type], !fields.isEmpty {
                        resultFieldRow(type: type, fields: fields)
                    }
                }
            }

            Divider()
            applyButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Gebaeude-Ergebnis-Karte

    private func buildingResultCard(_ data: ParsedBuildingData) -> some View {
        VStack(spacing: 14) {
            resultHeader

            Divider()

            // Gebaeude-Anzahl
            HStack {
                Text("Erkannte Gebäude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(data.buildings.count)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Gebaeude-Liste
            VStack(spacing: 6) {
                ForEach(data.buildings, id: \.buildingId) { building in
                    buildingResultRow(building)
                }
            }

            Divider()
            applyButton
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Gemeinsame Ergebnis-Elemente

    private var resultHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Analyse abgeschlossen")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
    }

    private var applyButton: some View {
        Button {
            applyResult()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                Text("In Plan übernehmen")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    // MARK: - Rohstofffeld-Zeile

    private func resultFieldRow(type: String, fields: [ParsedVillageData.ParsedField]) -> some View {
        let fieldType = resourceFieldType(for: type)
        let levels = fields.map { $0.level }
        let levelsText = levels.map { $0 > 0 ? "\($0)" : "–" }.joined(separator: ", ")

        return HStack(spacing: 8) {
            Image(systemName: fieldType.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(fieldType.color.gradient)
                .clipShape(Circle())

            Text(fieldType.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 52, alignment: .leading)

            Text("×\(fields.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text("Lv. \(levelsText)")
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
    }

    // MARK: - Gebaeude-Zeile

    private func buildingResultRow(_ building: ParsedBuildingData.ParsedBuilding) -> some View {
        let info = Building.allBuildings.first(where: { $0.id == building.buildingId })

        return HStack(spacing: 8) {
            Image(systemName: info?.icon ?? "questionmark.square.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background((info?.category.color ?? .gray).gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(info?.name ?? "Gebäude \(building.buildingId)")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Text("Stufe \(building.level)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.orange)
        }
    }

    private func resourceFieldType(for type: String) -> ResourceFieldType {
        switch type {
        case "wood": return .wood
        case "clay": return .clay
        case "iron": return .iron
        case "crop": return .crop
        default: return .wood
        }
    }

    // MARK: - Bild laden

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        // Reset states
        resourceResult = nil
        buildingResult = nil
        analysisError = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            selectedImage = uiImage
        }
    }

    // MARK: - Screenshot analysieren

    private func analyzeScreenshot() async {
        guard let image = selectedImage else { return }

        await MainActor.run {
            isAnalyzing = true
            analysisError = nil
        }

        do {
            switch mode {
            case .resources:
                let result = try await VillageScreenshotService.parseScreenshot(image)
                await MainActor.run {
                    resourceResult = result
                    isAnalyzing = false
                }
            case .buildings:
                let result = try await VillageScreenshotService.parseBuildingScreenshot(image)
                await MainActor.run {
                    buildingResult = result
                    isAnalyzing = false
                }
            }
        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                isAnalyzing = false
            }
        }
    }
}
