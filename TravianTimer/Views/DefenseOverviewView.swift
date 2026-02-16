import SwiftUI

// MARK: - Navigation Route

struct DefenseOverviewRoute: Hashable {
    let callId: UUID
}

// MARK: - Deff-Übersicht

struct DefenseOverviewView: View {

    let call: CallItem

    @EnvironmentObject private var store: CallsStore

    @State private var cropLimit: Int?
    @State private var showLimitEditor = false
    @State private var limitInput: String = ""
    @State private var troopsExpanded = false

    /// Aktuellen Call aus dem Store lesen (reaktiv bei Pledge-Änderungen)
    private var liveCall: CallItem {
        store.calls.first(where: { $0.id == call.id }) ?? call
    }

    private var pledges: [TroopPledge] {
        // Echte Pledges vom Call; Mock-Daten nur wenn keine echten vorhanden
        liveCall.pledges.isEmpty ? MockPledges.forCall(call) : liveCall.pledges
    }

    private var aggregated: [AggregatedTroop] {
        DefenseAggregator.aggregate(pledges)
    }

    private var grandTotal: Int {
        DefenseAggregator.grandTotal(aggregated)
    }

    private var playerCount: Int {
        DefenseAggregator.uniquePlayerCount(pledges)
    }

    private var totalCrop: Int {
        DefenseAggregator.totalCrop(aggregated)
    }

    private var cropRatio: Double {
        guard let limit = cropLimit, limit > 0 else { return 0 }
        return min(1.0, Double(totalCrop) / Double(limit))
    }

    private var isOverLimit: Bool {
        guard let limit = cropLimit else { return false }
        return totalCrop > limit
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if liveCall.pledges.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Demo-Daten – sichere Truppen im Call zu, um echte Daten zu sehen.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }

                cropCard

                statsRow

                troopsSection
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("Deff-Übersicht")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cropLimit = call.cropLimit
        }
        .alert("Getreide-Obergrenze", isPresented: $showLimitEditor) {
            TextField("z.B. 1000", text: $limitInput)
                .keyboardType(.numberPad)
            Button("Setzen") {
                if let val = Int(limitInput), val > 0 {
                    cropLimit = val
                    saveCropLimit(val)
                }
            }
            Button("Entfernen", role: .destructive) {
                cropLimit = nil
                limitInput = ""
                saveCropLimit(nil)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Maximales Getreide/h das im Zieldorf verfügbar ist.")
        }
    }

    // MARK: - Getreide Card (Hauptelement)

    private var cropCard: some View {
        VStack(spacing: 14) {
            Text("\(call.title)  (\(call.targetX)|\(call.targetY))  \u{2022}  Ankunft \(call.arrival.formatted(date: .numeric, time: .standard))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Getreide-Zahl gross
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(isOverLimit ? .red : .orange)

                Text("\(totalCrop)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOverLimit ? .red : .primary)

                if let limit = cropLimit {
                    Text("/ \(limit)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Getreide/h")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Fortschrittsbalken (nur wenn Obergrenze gesetzt)
            if cropLimit != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(isOverLimit ? Color.red : Color.orange)
                            .frame(width: geo.size.width * cropRatio, height: 12)
                    }
                }
                .frame(height: 12)

                if isOverLimit {
                    Text("Obergrenze um \(totalCrop - (cropLimit ?? 0)) überschritten!")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }

            // Obergrenze-Button
            Button {
                limitInput = cropLimit.map { "\($0)" } ?? ""
                showLimitEditor = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: cropLimit != nil ? "pencil" : "plus")
                        .font(.caption)
                    Text(cropLimit != nil ? "Obergrenze ändern" : "Obergrenze setzen")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .tint(cropLimit != nil ? .secondary : .orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Stats Row (sekundär)

    private var statsRow: some View {
        HStack(spacing: 16) {
            statBadge(value: "\(grandTotal)", label: "Truppen", icon: "person.3.fill")
            statBadge(value: "\(playerCount)", label: "Spieler", icon: "person.fill")
            statBadge(value: "\(aggregated.count)", label: "Typen", icon: "shield.fill")
        }
    }

    private func statBadge(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Troops Section (aufklappbar)

    private var troopsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { troopsExpanded.toggle() }
            } label: {
                HStack {
                    Text("Truppentypen")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("(\(aggregated.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: troopsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if troopsExpanded {
                Divider().padding(.horizontal)

                ForEach(aggregated) { troop in
                    troopRow(troop)
                        .padding(.horizontal)
                    if troop.id != aggregated.last?.id {
                        Divider().padding(.leading, 68)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Troop Row

    private func troopRow(_ troop: AggregatedTroop) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(troop.troopKind.tribeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: troop.troopKind.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(troop.troopKind.tribeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(troop.troopKind.uiName)
                    .font(.body)
                    .fontWeight(.semibold)

                Text("\(troop.playerCount) Spieler  \u{2022}  \(troop.totalCount) Einheiten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Getreide pro Typ prominent rechts
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(troop.totalCrop)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)

                Text("/h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Persistenz

    private func saveCropLimit(_ limit: Int?) {
        guard let idx = store.calls.firstIndex(where: { $0.id == call.id }) else { return }
        store.calls[idx].cropLimit = limit
    }
}
