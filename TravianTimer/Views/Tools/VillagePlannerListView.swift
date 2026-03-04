import SwiftUI
import PhotosUI
import UIKit

// MARK: - Dorfplaner Liste

struct VillagePlannerListView: View {

    @State private var profileStore = ProfileStore.shared
    @State private var planStore = VillagePlanStore.shared
    @State private var selectedVillageId: UUID?
    @State private var showScreenshotImport = false
    @State private var showHTMLImport = false
    @State private var importTargetPlanId: UUID?
    @State private var showNewPlanDialog = false
    @State private var newPlanName = ""

    private var villages: [VillageProfile] {
        profileStore.villages
    }

    private var plansForVillage: [VillagePlan] {
        guard let id = selectedVillageId else { return [] }
        return planStore.plans(for: id)
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: Dorf-Picker
                villagePicker

                // MARK: Pläne
                if selectedVillageId != nil {
                    plansList
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dorfplaner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedVillageId != nil {
                    HStack(spacing: 12) {
                        Button {
                            showHTMLImport = true
                        } label: {
                            Image(systemName: "doc.text")
                        }

                        Button {
                            showScreenshotImport = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }

                        Button {
                            newPlanName = ""
                            showNewPlanDialog = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showScreenshotImport) {
            ScreenshotImportSheet(
                mode: .resources,
                onApplyResources: { data in
                    createPlanFromScreenshot(data)
                }
            )
        }
        .sheet(isPresented: $showHTMLImport) {
            HTMLImportSheet { parsedVillage in
                createPlanFromHTML(parsedVillage)
            }
        }
        .onAppear {
            if selectedVillageId == nil {
                selectedVillageId = villages.first?.id
            }
        }
        .alert("Neuer Plan", isPresented: $showNewPlanDialog) {
            TextField("Plan-Name", text: $newPlanName)
            Button("Erstellen") {
                createPlan(name: newPlanName.isEmpty ? nil : newPlanName)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gib deinem Bauplan einen Namen.")
        }
    }

    // MARK: - Dorf-Picker

    @ViewBuilder
    private var villagePicker: some View {
        if villages.isEmpty {
            // Leerer Zustand
            VStack(spacing: 16) {
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

                    Image(systemName: "house.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange.opacity(0.6))
                }

                VStack(spacing: 4) {
                    Text("Keine Dörfer vorhanden")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Erstelle zuerst ein Dorf-Profil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            Menu {
                ForEach(villages) { village in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedVillageId = village.id
                        }
                    } label: {
                        if selectedVillageId == village.id {
                            Label(village.name, systemImage: "checkmark")
                        } else {
                            Text(village.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text(selectedVillageName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .padding(.horizontal)
        }
    }

    private var selectedVillageName: String {
        villages.first(where: { $0.id == selectedVillageId })?.name ?? "Dorf wählen"
    }

    // MARK: - Pläne-Liste

    @ViewBuilder
    private var plansList: some View {
        if plansForVillage.isEmpty {
            // Leerer Zustand
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.15), .orange.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange.opacity(0.6))
                }

                VStack(spacing: 6) {
                    Text("Noch keine Pläne")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Erstelle einen Bauplan für dein Dorf.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    newPlanName = ""
                    showNewPlanDialog = true
                } label: {
                    Label("Plan erstellen", systemImage: "plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 10) {
                ForEach(plansForVillage) { plan in
                    NavigationLink {
                        VillagePlannerView(plan: plan)
                    } label: {
                        planCard(plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Plan Card

    private func planCard(_ plan: VillagePlan) -> some View {
        let filledCount = plan.slots.filter { !$0.isEmpty }.count
        let resourceCount = plan.resourceFields.filter { $0.level > 0 }.count
        let totalProd = plan.totalProductionSum
        let totalItems = plan.slots.count + plan.resourceFields.count // 23 + 18 = 41
        let completedItems = filledCount + resourceCount
        let progress = Double(completedItems) / Double(totalItems)

        return VStack(spacing: 12) {
            // Titel-Zeile
            HStack {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                Text(plan.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Text(plan.villageType.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.brown.opacity(0.65).gradient)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Mini-Stats
            HStack(spacing: 6) {
                miniStat(icon: "building.2.fill", value: "\(filledCount)/23", color: .blue)
                miniStat(icon: "leaf.fill", value: "\(resourceCount)/18", color: .green)
                miniStat(icon: "chart.bar.fill", value: totalProd > 0 ? formatNumber(totalProd) + "/h" : "–", color: .orange)
            }

            // Fortschrittsbalken
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.gradient)
                            .frame(width: max(progress * geo.size.width, progress > 0 ? 4 : 0), height: 5)
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("\(Int(progress * 100))% komplett")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(plan.createdAt, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { planStore.delete(plan) }
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.06))
        )
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let thousands = Double(n) / 1000.0
            if n % 1000 == 0 { return "\(n / 1000)k" }
            return String(format: "%.1fk", thousands)
        }
        return "\(n)"
    }

    // MARK: - Aktionen

    private func createPlan(name: String? = nil) {
        guard let villageId = selectedVillageId else { return }
        let planName = name ?? "Plan \(plansForVillage.count + 1)"
        let plan = VillagePlan.empty(villageId: villageId, name: planName)
        withAnimation {
            planStore.upsert(plan)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func createPlanFromScreenshot(_ data: ParsedVillageData) {
        guard let villageId = selectedVillageId else { return }
        let count = plansForVillage.count + 1
        var plan = VillagePlan.empty(villageId: villageId, name: "Import \(count)")
        VillageScreenshotService.applyToPlan(data, plan: &plan)
        withAnimation {
            planStore.upsert(plan)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func createPlanFromHTML(_ data: HTMLParsedVillage) {
        guard let villageId = selectedVillageId else { return }
        let name = data.villageName ?? "HTML Import \(plansForVillage.count + 1)"
        var plan = VillagePlan.empty(villageId: villageId, name: name)

        // Rohstofffelder anwenden (Typ + Level)
        VillageScreenshotService.applyToPlan(data.resourceData, plan: &plan)

        // Gebaeude mit exakten Slot-Zuweisungen anwenden
        HTMLVillageParser.applyToPlan(data, plan: &plan)

        withAnimation {
            planStore.upsert(plan)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
