import SwiftUI
import UIKit

// MARK: - Truppen aktualisieren (Sheet)

struct TroopUpdateView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var profile = ProfileStore.shared
    @AppStorage("selectedTribe") private var selectedTribeRaw: String = SettingsView.Tribe.gauls.rawValue
    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""

    @State private var troopsInput: String = ""
    @State private var errorText: String? = nil
    @State private var successText: String? = nil
    @State private var updatedCount: Int = 0

    @State private var showSuccess = false
    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 12) {

                    GroupBox {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Truppenübersicht kopieren")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Öffne die Truppenübersicht im Spiel, kopiere die Tabelle ab Dorfname bis Gesamt und füge sie hier ein.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Button {
                                    let worldId = selectedWorldId.isEmpty ? "de1n" : selectedWorldId
                                    if let url = URL(string: "https://\(worldId).kingdoms.com/#/window:villagesOverview/page:village/tab:Troops") {
                                        openURL(url)
                                    }
                                } label: {
                                    Label("Truppenübersicht öffnen", systemImage: "safari")
                                        .font(.footnote)
                                }
                                .buttonStyle(.borderless)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        if let clip = UIPasteboard.general.string {
                            troopsInput = clip
                            parseTroops()
                        }
                    } label: {
                        Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    TextEditor(text: $troopsInput)
                        .frame(minHeight: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                        .padding(.horizontal)

                    HStack {
                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if let successText {
                            Label(successText, systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        if !troopsInput.isEmpty {
                            Button {
                                parseTroops()
                            } label: {
                                Label("Parsen", systemImage: "wand.and.stars")
                                    .font(.footnote)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
                .navigationTitle("Truppen aktualisieren")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
            }
            .allowsHitTesting(!showSuccess)

            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .scaleEffect(checkScale)
                        .opacity(checkOpacity)
                }

                VStack(spacing: 8) {
                    Text("Truppen aktualisiert!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(updatedCount) Dörfer aktualisiert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(checkOpacity)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkScale = 1.0
                checkOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                dismiss()
            }
        }
    }

    // MARK: - Parsing

    private func parseTroops() {
        errorText = nil
        successText = nil

        guard !profile.villages.isEmpty else {
            errorText = "Keine Dörfer vorhanden. Importiere zuerst Dörfer."
            return
        }

        let troopOrder = troopTableOrder()
        if troopOrder.count != 10 {
            errorText = "Truppenreihenfolge konnte nicht bestimmt werden. Volk prüfen."
            return
        }

        let lines = troopsInput
            .components(separatedBy: .newlines)
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }

        // Tabelle erkennen
        var tableLines: [String] = []
        var inTable = false
        for l in lines {
            let lower = l.lowercased()
            if !inTable {
                if lower == "dorfname" { inTable = true }
                continue
            }
            if lower.hasPrefix("gesamt") { break }
            tableLines.append(l)
        }

        if tableLines.isEmpty {
            errorText = "Keine Tabelle gefunden. Bitte ab 'Dorfname' kopieren."
            return
        }

        // Parse: Name → (counts, allowed)
        var parsedByName: [String: (counts: [String: Int], allowed: [String])] = [:]

        for line in tableLines {
            let tokens = line
                .replacingOccurrences(of: "\t", with: " ")
                .split(whereSeparator: { $0 == " " })
                .map(String.init)

            if tokens.count < 3 { continue }

            let needWithoutHero = troopOrder.count
            let needWithHero = troopOrder.count + 1

            var ints: [Int] = []
            var idx = tokens.count - 1
            while idx >= 0 && ints.count < needWithHero {
                if let v = Int(tokens[idx]) {
                    ints.insert(v, at: 0)
                    idx -= 1
                } else {
                    break
                }
            }

            if ints.count < needWithoutHero { continue }
            let hasHero = (ints.count >= needWithHero)
            let numericTailCount = hasHero ? needWithHero : needWithoutHero

            let nameTokens = tokens.prefix(max(0, tokens.count - numericTailCount))
            let nameRaw = nameTokens.joined(separator: " ")
            let name = cleanLine(nameRaw)
            if name.isEmpty { continue }

            let tail = Array(ints.suffix(numericTailCount))
            let countsEnd = troopOrder.count
            if tail.count < countsEnd { continue }
            let unitCounts = Array(tail[0..<countsEnd])

            let heroCount: Int? = (tail.count > troopOrder.count) ? tail.last : nil

            var countsByKey: [String: Int] = [:]
            var allowed: [String] = []
            for i in 0..<min(troopOrder.count, unitCounts.count) {
                let key = troopOrder[i].rawValue
                let c = unitCounts[i]
                countsByKey[key] = c
                if c > 0 { allowed.append(key) }
            }
            if let heroCount {
                countsByKey["__hero__"] = heroCount
            }

            parsedByName[normalizeVillageKey(name)] = (countsByKey, Array(Set(allowed)).sorted())
        }

        if parsedByName.isEmpty {
            errorText = "Keine Dörfer in der Tabelle erkannt."
            return
        }

        // Match auf bestehende Dörfer und aktualisieren
        var matched = 0
        var missing: [String] = []

        for village in profile.villages {
            let key = normalizeVillageKey(village.name)
            if let payload = parsedByName[key] {
                var updated = village
                updated.troopCounts = payload.counts
                updated.allowedTroops = payload.allowed
                profile.upsert(updated)
                matched += 1
            } else {
                missing.append(village.name)
            }
        }

        if matched == 0 {
            errorText = "Keine Dörfer zugeordnet. Namen müssen exakt übereinstimmen."
            return
        }

        // Snapshot speichern
        let updatedVillages = profile.villages.filter { v in
            parsedByName[normalizeVillageKey(v.name)] != nil
        }
        TroopHistoryStore.shared.recordSnapshot(villages: updatedVillages)

        updatedCount = matched
        if !missing.isEmpty && missing.count < profile.villages.count {
            successText = "\(matched) Dörfer aktualisiert (\(missing.count) ohne Match)"
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccess = true
        }
    }

    // MARK: - Helpers (gleiche Logik wie VillageImportView)

    private func cleanLine(_ raw: String) -> String {
        let formatMarks: Set<Unicode.Scalar> = [
            "\u{200E}","\u{200F}","\u{202A}","\u{202B}","\u{202C}","\u{202D}","\u{202E}",
            "\u{2066}","\u{2067}","\u{2068}","\u{2069}",
            "\u{200B}","\u{FEFF}","\u{2060}"
        ]

        let strippedScalars = raw.unicodeScalars.filter { !formatMarks.contains($0) }
        var s = String(String.UnicodeScalarView(strippedScalars))
        s = s.replacingOccurrences(of: "\u{2212}", with: "-")
        s = s.replacingOccurrences(of: "\u{FF5C}", with: "|")
        s = s.replacingOccurrences(of: "\u{00A6}", with: "|")
        s = s.replacingOccurrences(of: "\u{2223}", with: "|")
        s = s.replacingOccurrences(of: "\t", with: " ")
        s = s.replacingOccurrences(of: "\r", with: " ")
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeVillageKey(_ raw: String) -> String {
        var s = cleanLine(raw)
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "\t", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: " (", with: "(")
        s = s.replacingOccurrences(of: ") ", with: ")")
        return s.lowercased()
    }

    private func troopTableOrder() -> [TroopKind] {
        let all = TroopKind.troops(forSelectedTribeRaw: selectedTribeRaw)
        if all.isEmpty { return [] }

        func matches(_ troop: TroopKind, aliases: [String]) -> Bool {
            let name = troop.uiName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return aliases.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name }
        }

        func pick(_ columns: [[String]]) -> [TroopKind] {
            var out: [TroopKind] = []
            out.reserveCapacity(columns.count)
            for aliases in columns {
                if let t = all.first(where: { matches($0, aliases: aliases) }) {
                    out.append(t)
                }
            }
            return out
        }

        if selectedTribeRaw == SettingsView.Tribe.gauls.rawValue {
            let order = pick([
                ["Phalanx", "Phalanxe"],
                ["Schwertkämpfer"],
                ["Späher", "Kundschafter"],
                ["Theutates Blitz"],
                ["Druidenreiter"],
                ["Haeduaner"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Häuptling"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        if selectedTribeRaw == SettingsView.Tribe.romans.rawValue {
            let order = pick([
                ["Legionär"],
                ["Prätorianer"],
                ["Imperianer"],
                ["Equites Legati"],
                ["Equites Imperatoris"],
                ["Equites Caesaris"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Senator"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        if selectedTribeRaw == SettingsView.Tribe.teutons.rawValue {
            let order = pick([
                ["Keulenschwinger"],
                ["Speerkämpfer"],
                ["Axtkämpfer"],
                ["Kundschafter", "Späher"],
                ["Paladin"],
                ["Teutonen-Reiter"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Stammesführer"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        return Array(all.prefix(10))
    }
}
