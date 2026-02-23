import SwiftUI

// MARK: - Village Editor

struct VillageEditorView: View {

    let modeTitle: String
    let initial: VillageProfile
    let onSave: (VillageProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: VillageProfile

    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue

    init(modeTitle: String, initial: VillageProfile, onSave: @escaping (VillageProfile) -> Void) {
        self.modeTitle = modeTitle
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dorf") {
                    TextField("Name", text: $draft.name)
                    Stepper(value: $draft.x, in: -400...400) {
                        HStack {
                            Text("X")
                            Spacer()
                            Text("\(draft.x)")
                        }
                    }
                    Stepper(value: $draft.y, in: -400...400) {
                        HStack {
                            Text("Y")
                            Spacer()
                            Text("\(draft.y)")
                        }
                    }
                }

                Section("Truppen") {
                    if allTroops.isEmpty {
                        Text("Keine Truppenliste gefunden.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(allTroops, id: \.rawValue) { troop in
                        Button {
                            toggleTroop(troop.rawValue)
                        } label: {
                            HStack {
                                Text(troop.uiName)
                                Spacer()
                                if draft.allowedTroops.contains(troop.rawValue) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Ohne Auswahl liefert das Dorf keine Optionen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        var final = draft
                        final.name = trimmed.isEmpty ? "Dorf" : trimmed
                        onSave(final)
                        dismiss()
                    }
                }
            }
        }
    }

    private var allTroops: [TroopKind] {
        TroopKind.troops(forSelectedTribeRaw: selectedTribeRaw)
    }

    private func toggleTroop(_ raw: String) {
        if let idx = draft.allowedTroops.firstIndex(of: raw) {
            draft.allowedTroops.remove(at: idx)
            draft.troopCounts.removeValue(forKey: raw)
        } else {
            draft.allowedTroops.append(raw)
            draft.allowedTroops.sort()
            // Count remains unknown unless imported; leave unset.
        }
    }
}
