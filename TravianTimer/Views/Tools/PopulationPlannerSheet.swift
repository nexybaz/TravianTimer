import SwiftUI

struct PopulationPlannerSheet: View {

    @Binding var plan: VillagePlan
    let currentPopulation: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var targetInput: String = "200"
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            Group {
                if showResults, let buildPlan = plan.populationBuildPlan {
                    resultsView(buildPlan)
                } else {
                    inputView
                }
            }
            .navigationTitle("Pop-Ziel-Planer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .onAppear {
            if plan.populationBuildPlan != nil {
                showResults = true
            }
        }
    }

    // MARK: - Eingabe

    private var inputView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(currentPopulation)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.purple)
                Text("aktuelle Bevölkerung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Ziel-Bevölkerung")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("z.B. 200", text: $targetInput)
                    .keyboardType(.numberPad)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                presetButton(200)
                presetButton(500)
            }
            .padding(.horizontal)

            Button {
                calculate()
            } label: {
                Label("Berechnen", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.horizontal)
            .disabled(targetValue <= currentPopulation)

            if targetValue <= currentPopulation && !targetInput.isEmpty {
                Text("Ziel muss grösser als \(currentPopulation) sein")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    private func presetButton(_ value: Int) -> some View {
        Button {
            targetInput = "\(value)"
        } label: {
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.purple)
    }

    private var targetValue: Int {
        Int(targetInput) ?? 0
    }

    private func calculate() {
        let target = targetValue
        guard target > currentPopulation else { return }
        let buildPlan = PopulationPlanCalculator.computePlan(plan: plan, targetPop: target)
        plan.populationBuildPlan = buildPlan
        onSave()
        showResults = true
    }

    // MARK: - Ergebnis

    private func resultsView(_ buildPlan: PopBuildPlan) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                resultHeader(buildPlan)

                // Steps
                if buildPlan.steps.isEmpty {
                    noStepsView
                } else {
                    stepsList(buildPlan)
                }

                // Neu berechnen
                Button {
                    showResults = false
                    targetInput = "\(buildPlan.targetPopulation)"
                } label: {
                    Label("Neu berechnen", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .padding(.horizontal)

                // Plan löschen
                Button(role: .destructive) {
                    plan.populationBuildPlan = nil
                    onSave()
                    showResults = false
                } label: {
                    Label("Plan löschen", systemImage: "trash")
                        .font(.subheadline)
                }
                .padding(.bottom, 24)

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func resultHeader(_ buildPlan: PopBuildPlan) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("\(buildPlan.startPopulation)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.purple)
                Text("\(buildPlan.finalPopulation)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.purple)
                Text("Pop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label("\(buildPlan.steps.count) Schritte", systemImage: "list.number")
                Label("\(buildPlan.completedSteps)/\(buildPlan.steps.count) erledigt", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func stepsList(_ buildPlan: PopBuildPlan) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(buildPlan.steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, index: index, total: buildPlan.steps.count)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func stepRow(_ step: PopBuildStep, index: Int, total: Int) -> some View {
        let isCompleted = step.isCompleted
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Checkbox
                Button {
                    toggleStep(at: index)
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                // Schrittnummer
                Text("\(step.stepNumber)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(isCompleted ? Color.gray.gradient : Color.purple.gradient)
                    .clipShape(Circle())

                // Icon
                Image(systemName: step.icon)
                    .font(.caption)
                    .foregroundStyle(isCompleted ? .secondary : iconColor(for: step))
                    .frame(width: 18)

                // Name + Level
                VStack(alignment: .leading, spacing: 1) {
                    Text(step.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .strikethrough(isCompleted)
                    Text("Stufe \(step.fromLevel) → \(step.toLevel)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Pop-Delta
                VStack(alignment: .trailing, spacing: 1) {
                    if step.popDelta > 0 {
                        Text("+\(step.popDelta) Pop")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(isCompleted ? Color.secondary : Color.purple)
                    } else {
                        Text("+0 Pop")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("Σ \(step.popAfter)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .opacity(isCompleted ? 0.5 : 1.0)

            // Kosten-Zeile
            HStack(spacing: 8) {
                Spacer().frame(width: 50)
                costLabel("🪵", value: step.cost.wood)
                costLabel("🧱", value: step.cost.clay)
                costLabel("⚙️", value: step.cost.iron)
                costLabel("🌾", value: step.cost.crop)
                Spacer()
                Text("= \(formatCost(step.cost.total))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .opacity(isCompleted ? 0.3 : 0.7)

            if index < total - 1 {
                Divider().padding(.leading, 54)
            }
        }
    }

    private func costLabel(_ emoji: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(emoji).font(.system(size: 9))
            Text(formatCost(value))
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var noStepsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Ziel bereits erreicht oder nicht erreichbar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    // MARK: - Helpers

    private func toggleStep(at index: Int) {
        guard var buildPlan = plan.populationBuildPlan,
              index < buildPlan.steps.count else { return }
        buildPlan.steps[index].isCompleted.toggle()
        plan.populationBuildPlan = buildPlan
        onSave()
    }

    private func iconColor(for step: PopBuildStep) -> Color {
        switch step.source {
        case .resourceField(_, let type):
            return type.color
        default:
            return .blue
        }
    }

    private func formatCost(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }
}
