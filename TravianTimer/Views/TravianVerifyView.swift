import SwiftUI

// MARK: - Travian Account Verifizierung

struct TravianVerifyView: View {

    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("selectedWorldId") private var savedWorldId: String = ""

    @State private var worlds: [GameworldListItem] = []
    @State private var isLoadingWorlds = true
    @State private var worldLoadError: String?
    @State private var worldId: String = ""
    @State private var accessToken: String = ""
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    @State private var verifyResult: VerifyResult?
    @State private var keyCopied = false

    /// Die aktuell gewaehlte Spielwelt
    private var selectedWorld: GameworldListItem? {
        worlds.first(where: { $0.worldId == worldId })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Header

                    headerSection

                    if verifyResult != nil {
                        successSection
                    } else {
                        worldPickerSection
                        if selectedWorld != nil {
                            instructionsSection
                            accessTokenSection
                            verifyButton
                        }
                    }

                    if let errorMessage {
                        errorSection(errorMessage)
                    }

                    // Überspringen-Hinweis (nur wenn noch nicht verifiziert und kein Erfolg)
                    if verifyResult == nil {
                        Button {
                            dismiss()
                        } label: {
                            Text("Später verknüpfen")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Travian verknüpfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task {
                await loadWorlds()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            Text("Travian-Account verknüpfen")
                .font(.title2)
                .fontWeight(.bold)

            Text("Verknüpfe deinen Travian-Account, um Profil und Dörfer automatisch zu laden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Spielwelt-Auswahl

    private var worldPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1. Spielwelt wählen")
                .font(.headline)

            if isLoadingWorlds {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Lade Spielwelten...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if worlds.isEmpty {
                // Fallback: Freitext wenn Edge Function fehlschlaegt
                TextField("z.B. de1n, com1", text: $worldId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let worldLoadError {
                    Text(worldLoadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Picker("Spielwelt", selection: $worldId) {
                    Text("Bitte wählen").tag("")
                    ForEach(worlds) { w in
                        Text(w.label).tag(w.worldId)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: worldId) {
                    // Reset bei Weltwechsel
                    keyCopied = false
                    errorMessage = nil
                }

                if !worldId.isEmpty, let world = selectedWorld, !world.isConfigured {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Für diese Spielwelt ist noch kein API-Key konfiguriert.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Anleitung mit Public Site Key

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. In Travian verknüpfen")
                .font(.headline)

            InstructionRow(
                step: "1",
                text: "Kopiere den Schlüssel unten"
            )

            // Public Site Key anzeigen + kopieren
            if let key = selectedWorld?.publicSiteKey, !key.isEmpty {
                HStack {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = key
                        withAnimation { keyCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { keyCopied = false }
                        }
                    } label: {
                        Image(systemName: keyCopied ? "checkmark" : "doc.on.doc")
                            .font(.body)
                            .foregroundStyle(keyCopied ? .green : .accentColor)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if keyCopied {
                    Text("Kopiert!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            InstructionRow(
                step: "2",
                text: "Öffne Travian Kingdoms → Einstellungen → Externe Tools"
            )

            InstructionRow(
                step: "3",
                text: "Klicke auf \"Zugang erstellen\" und füge den kopierten Schlüssel ein"
            )

            InstructionRow(
                step: "4",
                text: "Travian zeigt dir einen Access-Token — kopiere diesen und füge ihn unten ein"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Access Token Eingabe

    private var accessTokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("3. Access-Token eingeben")
                .font(.headline)

            HStack {
                TextField("Access-Token von Travian einfügen", text: $accessToken)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    if let clipboard = UIPasteboard.general.string {
                        accessToken = clipboard
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Verifizieren Button

    private var verifyButton: some View {
        Button {
            Task { await verify() }
        } label: {
            HStack {
                if isVerifying {
                    ProgressView()
                        .tint(.white)
                }
                Text(isVerifying ? "Verifiziere..." : "Verifizieren")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canVerify ? Color.accentColor : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canVerify || isVerifying)
    }

    private var canVerify: Bool {
        !worldId.trimmingCharacters(in: .whitespaces).isEmpty
        && !accessToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Erfolg

    private var successSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            if let result = verifyResult {
                Text("Willkommen, \(result.player.name)!")
                    .font(.title2)
                    .fontWeight(.bold)

                // Player Info
                VStack(spacing: 8) {
                    if let tribe = result.player.tribe {
                        LabeledContent("Volk", value: tribe)
                    }
                    if let tag = result.player.kingdomTag {
                        LabeledContent("Kingdom", value: tag)
                    }
                    LabeledContent("Dörfer", value: "\(result.villages.count)")

                    if result.mock == true {
                        Text("(Mock-Daten — kein API-Key konfiguriert)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Doerfer-Liste
                if !result.villages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deine Dörfer:")
                            .font(.headline)

                        ForEach(result.villages, id: \.villageId) { village in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(village.name)
                                        .fontWeight(.medium)
                                    Text("(\(village.x)|\(village.y))  Pop: \(village.population)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if village.isMainVillage == true {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                }
                                if village.isCity == true {
                                    Image(systemName: "building.2.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Fertig Button
                Button {
                    dismiss()
                } label: {
                    Text("Fertig")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Fehler

    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Load Worlds (via Edge Function)

    private func loadWorlds() async {
        isLoadingWorlds = true
        defer { isLoadingWorlds = false }

        do {
            let items = try await TravianAPIService.listWorlds()
            worlds = items

            // Gespeicherte Welt vorselektieren
            if !savedWorldId.isEmpty, items.contains(where: { $0.worldId == savedWorldId }) {
                worldId = savedWorldId
            }
        } catch {
            print("[loadWorlds] Fehler: \(error)")
            worldLoadError = "Fehler beim Laden: \(error.localizedDescription)"
        }
    }

    // MARK: - Verify Action

    private func verify() async {
        isVerifying = true
        errorMessage = nil

        do {
            let result = try await TravianAPIService.verifyPlayer(
                worldId: worldId.trimmingCharacters(in: .whitespaces).lowercased(),
                accessToken: accessToken.trimmingCharacters(in: .whitespaces)
            )
            verifyResult = result

            // Spielwelt in AppStorage speichern
            savedWorldId = worldId.trimmingCharacters(in: .whitespaces).lowercased()

            // Truppengeschwindigkeit aus Gameworld setzen
            if let speedTroops = result.gameworld?.speedTroops, speedTroops > 0 {
                UserDefaults.standard.set(Double(speedTroops), forKey: "troopMultiplier")
            }

            // Profil + Villages sofort neu laden (Edge Function hat sie in die DB geschrieben)
            await authService.refreshProfile()

        } catch {
            errorMessage = error.localizedDescription
        }

        isVerifying = false
    }
}

// MARK: - Instruction Row Helper

private struct InstructionRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
