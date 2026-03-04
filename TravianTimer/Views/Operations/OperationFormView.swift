import SwiftUI

// MARK: - Operation Form (Create / Edit)

struct OperationFormView: View {

    enum Mode {
        case create
        case edit(Operation)
    }

    let mode: Mode

    @Environment(OperationPlanStore.self) var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var worldSpeed: Double = 1.0
    @State private var visibility: Operation.Visibility = .full
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let worldSpeedOptions: [Double] = [1, 2, 3, 5]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Titel", text: $title)
                    TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Einstellungen") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welt-Geschwindigkeit")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Speed", selection: $worldSpeed) {
                            ForEach(Self.worldSpeedOptions, id: \.self) { s in
                                Text("\(Int(s))×").tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Picker("Sichtbarkeit (Link)", selection: $visibility) {
                        Text("Ganzer Plan").tag(Operation.Visibility.full)
                        Text("Nur eigene Aufträge").tag(Operation.Visibility.personal)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isCreate ? "Neuer Einsatz" : "Einsatz bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreate ? "Erstellen" : "Speichern") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if case .edit(let op) = mode {
                    title = op.title
                    description = op.description ?? ""
                    worldSpeed = op.worldSpeed
                    visibility = op.visibility
                }
            }
        }
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        switch mode {
        case .create:
            let result = await store.createOperation(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                worldSpeed: worldSpeed,
                visibility: visibility
            )

            isSaving = false

            if result != nil {
                dismiss()
            } else {
                errorMessage = store.errorText ?? "Einsatz konnte nicht erstellt werden."
            }

        case .edit(var op):
            op.title = title.trimmingCharacters(in: .whitespaces)
            op.description = description.isEmpty ? nil : description
            op.worldSpeed = worldSpeed
            op.visibility = visibility
            await store.updateOperation(op)

            isSaving = false
            dismiss()
        }
    }
}
