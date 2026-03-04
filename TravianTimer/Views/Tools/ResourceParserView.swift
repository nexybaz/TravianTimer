import SwiftUI
import UIKit

// MARK: - Ressourcen-Parser View

struct ResourceParserView: View {

    @State private var profileStore = ProfileStore.shared

    // Eingabe
    @State private var selectedVillageId: UUID?
    @State private var inputText = ""

    // Ergebnis
    @State private var parsedResult: ParsedResources?
    @State private var parseError = false
    @State private var saved = false

    // MARK: - Abgeleitete Werte

    private var villages: [VillageProfile] {
        profileStore.villages
    }

    private var selectedVillage: VillageProfile? {
        guard let id = selectedVillageId else { return nil }
        return villages.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Dorf-Picker ──
                villagePicker

                // ── Aktuelle Werte ──
                if let village = selectedVillage, village.productionWood != nil {
                    currentValuesSection(village)
                }

                // ── Eingabe ──
                inputSection

                // ── Ergebnis ──
                if let result = parsedResult {
                    resultSection(result)
                } else if parseError {
                    errorSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ressourcen-Parser")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Erstes Dorf vorselektieren
            if selectedVillageId == nil {
                selectedVillageId = villages.first?.id
            }
        }
    }

    // MARK: - Dorf-Picker

    @ViewBuilder
    private var villagePicker: some View {
        if villages.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Keine Dörfer vorhanden. Erstelle zuerst ein Dorf-Profil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        } else {
            VStack(spacing: 6) {
                Text("Dorf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Dorf", selection: $selectedVillageId) {
                    ForEach(villages) { village in
                        Text("\(village.name) (\(village.x)|\(village.y))")
                            .tag(Optional(village.id))
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
    }

    // MARK: - Aktuelle gespeicherte Werte

    @ViewBuilder
    private func currentValuesSection(_ village: VillageProfile) -> some View {
        VStack(spacing: 8) {
            Text("Gespeicherte Produktion")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                resourceMiniCell(icon: "🪵", value: village.productionWood ?? 0)
                resourceMiniCell(icon: "🧱", value: village.productionClay ?? 0)
                resourceMiniCell(icon: "⚙️", value: village.productionIron ?? 0)
                resourceMiniCell(icon: "🌾", value: village.productionCrop ?? 0)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Eingabe-Bereich

    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 10) {

            // Paste Button (identisch zu TroopUpdateView)
            Button {
                if let clip = UIPasteboard.general.string {
                    inputText = clip
                    parseInput()
                }
            } label: {
                Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // TextEditor
            TextEditor(text: $inputText)
                .frame(minHeight: 140)
                .font(.caption)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.secondary.opacity(0.3))
                )

            // Manuell Parsen
            Button {
                parseInput()
            } label: {
                Label("Auswerten", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private func resultSection(_ result: ParsedResources) -> some View {
        VStack(spacing: 14) {

            Text("Erkannte Produktion/h")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 4 Ressourcen-Karten
            VStack(spacing: 8) {
                resourceCard(icon: "🪵", name: "Holz",     value: result.wood)
                resourceCard(icon: "🧱", name: "Lehm",     value: result.clay)
                resourceCard(icon: "⚙️", name: "Eisen",    value: result.iron)
                resourceCard(icon: "🌾", name: "Getreide", value: result.crop)
            }

            // Speichern
            if selectedVillageId != nil {
                Button {
                    saveToVillage(result)
                } label: {
                    Label(
                        saved ? "Gespeichert" : "Im Dorf speichern",
                        systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(saved ? .green : .accentColor)
                .disabled(saved)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Fehler

    @ViewBuilder
    private var errorSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text("Keine Ressourcen-Daten erkannt. Stelle sicher, dass du den gesamten Seiteninhalt kopiert hast.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Ressourcen-Karte

    @ViewBuilder
    private func resourceCard(icon: String, name: String, value: Int) -> some View {
        HStack {
            Text(icon)
                .font(.title3)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatProduction(value))
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(value >= 0 ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func resourceMiniCell(icon: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text(icon)
                .font(.caption)
            Text(formatProduction(value))
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(value >= 0 ? .green : .red)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Aktionen

    private func parseInput() {
        saved = false
        let result = ResourceParser.parse(text: inputText)
        withAnimation(.snappy(duration: 0.2)) {
            parsedResult = result
            parseError = result == nil
        }
    }

    private func saveToVillage(_ result: ParsedResources) {
        guard let id = selectedVillageId,
              let idx = profileStore.villages.firstIndex(where: { $0.id == id }) else { return }

        var village = profileStore.villages[idx]
        village.productionWood = result.wood
        village.productionClay = result.clay
        village.productionIron = result.iron
        village.productionCrop = result.crop
        profileStore.upsert(village)

        withAnimation(.snappy(duration: 0.2)) {
            saved = true
        }
    }

    // MARK: - Formatierung

    private func formatProduction(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : ""
        if abs(value) >= 10_000 {
            return String(format: "%@%.1fk", sign, Double(value) / 1_000)
        }
        return "\(sign)\(value)"
    }
}
