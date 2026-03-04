import SwiftUI
import UniformTypeIdentifiers

// MARK: - HTML Import Sheet

struct HTMLImportSheet: View {

    let onApply: (HTMLParsedVillage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var parsedVillage: HTMLParsedVillage?
    @State private var errorMessage: String?
    @State private var isParsing = false
    @State private var showFilePicker = false

    private var hasResult: Bool { parsedVillage != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Anleitung
                    if !hasResult {
                        instructionCard
                    }

                    // MARK: Import-Buttons
                    if !hasResult {
                        importButtons
                    }

                    // MARK: Fehler
                    if let error = errorMessage {
                        errorCard(error)
                    }

                    // MARK: Ergebnis
                    if let result = parsedVillage {
                        resultCard(result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("HTML Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if hasResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Uebernehmen") {
                            if let result = parsedVillage {
                                onApply(result)
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.html],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .presentationDetents([.large])
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

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange.opacity(0.7))
            }

            VStack(spacing: 4) {
                Text("HTML importieren")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Speichere deine Dorfansicht als HTML-Datei im Browser (Rechtsklick → \"Seite speichern als...\"). Alle Gebaeude und Rohstofffelder werden automatisch erkannt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Import-Buttons

    private var importButtons: some View {
        VStack(spacing: 10) {
            // Datei waehlen
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.subheadline)
                    Text("HTML-Datei waehlen")
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

            // Aus Zwischenablage
            Button {
                parseFromClipboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.subheadline)
                    Text("Aus Zwischenablage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Fehler-Karte

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Ergebnis-Karte

    private func resultCard(_ data: HTMLParsedVillage) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = data.villageName {
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Daten erkannt")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("Dorf-Typ: \(data.resourceData.villageType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Stats
            HStack(spacing: 6) {
                resultStat(
                    icon: "building.2.fill",
                    value: "\(data.buildingData.buildings.count)",
                    label: "Gebaeude",
                    color: .blue
                )
                resultStat(
                    icon: "leaf.fill",
                    value: "\(data.resourceData.fields.count)",
                    label: "Felder",
                    color: .green
                )

                let maxLevel = data.buildingData.buildings.map(\.level).max() ?? 0
                resultStat(
                    icon: "arrow.up.right",
                    value: "Lv.\(maxLevel)",
                    label: "Max",
                    color: .orange
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func resultStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Aktionen

    private func handleFileImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        parsedVillage = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Kein Zugriff auf die Datei moeglich."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let html = try String(contentsOf: url, encoding: .utf8)
                let parsed = try HTMLVillageParser.parse(html: html)
                withAnimation { parsedVillage = parsed }
            } catch let error as HTMLVillageParser.ParseError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Datei konnte nicht gelesen werden: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "Datei-Auswahl fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func parseFromClipboard() {
        errorMessage = nil
        parsedVillage = nil

        guard let html = UIPasteboard.general.string, !html.isEmpty else {
            errorMessage = "Die Zwischenablage ist leer oder enthaelt keinen Text."
            return
        }

        do {
            let parsed = try HTMLVillageParser.parse(html: html)
            withAnimation { parsedVillage = parsed }
        } catch let error as HTMLVillageParser.ParseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Parsing fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
