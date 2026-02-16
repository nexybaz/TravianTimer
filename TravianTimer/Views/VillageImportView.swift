import SwiftUI
import UIKit

// MARK: - Village Import

struct VillageImportView: View {

    let onImport: ([VillageProfile]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    enum Step: Int {
        case tribe = 1
        case coords = 2
        case troops = 3
    }

    @State private var step: Step = .tribe

    // We persist the selected tribe globally, but we still ask here first.
    @AppStorage("selectedTribe") private var selectedTribeRaw: String = SettingsView.Tribe.gauls.rawValue
    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""
    @State private var localTribeRaw: String = SettingsView.Tribe.gauls.rawValue

    // Inputs
    @State private var coordsInput: String = ""
    @State private var troopsInput: String = ""

    // Parsed output
    @State private var parsedVillages: [VillageProfile] = [] // result after coords step
    @State private var mergedVillages: [VillageProfile] = [] // final result after troops step

    @State private var errorText: String? = nil
    @State private var successText: String? = nil
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var checkmarkOpacity: Double = 0

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 12) {

                    stepIndicator

                    header

                    switch step {
                    case .tribe:
                        tribeStep
                    case .coords:
                        coordsStep
                    case .troops:
                        troopsStep
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let successText {
                        Label(successText, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if step != .tribe {
                        preview
                    }

                    if step != .tribe {
                        Spacer()
                    }

                    footerButtons
                }
                .padding()
                .navigationTitle(step == .tribe ? "" : "Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Überspringen") { dismiss() }
                            .font(.subheadline)
                    }
                    if step == .troops {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Importieren") {
                                performImport()
                            }
                            .disabled(!canImport)
                        }
                    }
                }
                .onAppear {
                    localTribeRaw = selectedTribeRaw
                }
            }
            .allowsHitTesting(!showImportSuccess)

            if showImportSuccess {
                importSuccessOverlay
            }
        }
    }

    // MARK: - Import Success Overlay

    private var importSuccessOverlay: some View {
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
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                VStack(spacing: 8) {
                    Text("Import erfolgreich!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(importedCount) Dörfer importiert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(checkmarkOpacity)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                dismiss()
            }
        }
    }

    private func performImport() {
        importedCount = mergedVillages.count
        onImport(mergedVillages)
        TroopHistoryStore.shared.recordSnapshot(villages: mergedVillages)
        withAnimation(.easeInOut(duration: 0.3)) {
            showImportSuccess = true
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Header

    private var header: some View {
        Group {
            if step != .tribe {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schritt \(step.rawValue) von 3")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if step == .coords {
                        Text("Koordinaten importieren")
                            .font(.headline)
                    } else {
                        Text("Truppen importieren")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Step 1: Tribe

    private var tribeStep: some View {
        VStack(spacing: 24) {

            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Wähle dein Volk")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Wird für die Zuordnung der Truppen Spalten gebraucht.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(SettingsView.Tribe.allCases) { tribe in
                    Button {
                        localTribeRaw = tribe.rawValue
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: tribeIcon(tribe))
                                .font(.title3)
                                .frame(width: 28)

                            Text(tribe.rawValue)
                                .font(.body)
                                .fontWeight(.medium)

                            Spacer()

                            if localTribeRaw == tribe.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(localTribeRaw == tribe.rawValue
                                      ? Color.accentColor.opacity(0.1)
                                      : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(localTribeRaw == tribe.rawValue
                                        ? Color.accentColor.opacity(0.4)
                                        : Color.clear,
                                        lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tribeIcon(_ tribe: SettingsView.Tribe) -> String {
        switch tribe {
        case .romans:  return "building.columns"
        case .gauls:   return "leaf"
        case .teutons: return "hammer"
        }
    }

    // MARK: - Step 2: Coords

    private var coordsStep: some View {
        VStack(alignment: .leading, spacing: 10) {

            Button {
                if let clip = UIPasteboard.general.string {
                    coordsInput = clip
                    parseCoordinates()
                }
            } label: {
                Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            TextEditor(text: $coordsInput)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )

            HStack {
                Text("Format: Dorfname (-6|3) oder (12/8)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if !coordsInput.isEmpty {
                    Button {
                        parseCoordinates()
                    } label: {
                        Label("Parsen", systemImage: "wand.and.stars")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 3: Troops

    private var troopsStep: some View {
        VStack(alignment: .leading, spacing: 10) {

            Button {
                if let clip = UIPasteboard.general.string {
                    troopsInput = clip
                    parseTroopsAndMerge()
                }
            } label: {
                Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(parsedVillages.isEmpty)

            GroupBox {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tipp")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("Öffne die Truppenübersicht, kopiere die Tabelle ab Dorfname bis Gesamt und füge sie hier ein.")
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

            TextEditor(text: $troopsInput)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )

            HStack {
                Text("Tabelle ab 'Dorfname' bis 'Gesamt'.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if !troopsInput.isEmpty {
                    Button {
                        parseTroopsAndMerge()
                    } label: {
                        Label("Parsen", systemImage: "wand.and.stars")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Preview

    private var preview: some View {
        Group {
            let list = (step == .troops) ? mergedVillages : parsedVillages

            if !list.isEmpty {
                List(list) { v in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.name)
                        if v.x == 0 && v.y == 0 {
                            Text("(noch keine Koordinaten)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("(\(v.x)|\(v.y))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if step == .troops {
                            Text("Truppen: \(v.allowedTroops.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(minHeight: 180)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: step == .coords ? "map" : "person.3")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(step == .coords
                         ? "Kopiere deine Dorfkoordinaten und füge sie ein."
                         : "Kopiere die Truppentabelle und füge sie ein.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        Group {
            if step == .tribe {
                Button {
                    errorText = nil
                    successText = nil
                    selectedTribeRaw = localTribeRaw
                    step = .coords
                } label: {
                    Text("Weiter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                HStack {
                    Button("Zurück") {
                        errorText = nil
                        successText = nil
                        if step == .coords { step = .tribe }
                        else if step == .troops { step = .coords }
                    }

                    Spacer()

                    if step == .troops {
                        Button {
                            errorText = nil
                            successText = nil
                            performImport()
                        } label: {
                            Label("Importieren", systemImage: "checkmark")
                                .frame(minWidth: 140)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canImport)
                    } else {
                        Button("Weiter") {
                            errorText = nil
                            successText = nil

                            if step == .coords {
                                if parsedVillages.isEmpty {
                                    errorText = "Bitte zuerst Koordinaten parsen."
                                    return
                                }
                                step = .troops
                                return
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canGoNext)
                        .frame(minWidth: 140)
                    }
                }
            }
        }
    }

    private var canGoNext: Bool {
        switch step {
        case .tribe:
            return true
        case .coords:
            return !parsedVillages.isEmpty
        case .troops:
            return false
        }
    }

    private var canImport: Bool {
        step == .troops && !mergedVillages.isEmpty
    }

    // MARK: - Parsing helpers

    private func cleanLine(_ raw: String) -> String {
        let formatMarks: Set<Unicode.Scalar> = [
            "\u{200E}","\u{200F}","\u{202A}","\u{202B}","\u{202C}","\u{202D}","\u{202E}",
            "\u{2066}","\u{2067}","\u{2068}","\u{2069}",
            "\u{200B}","\u{FEFF}","\u{2060}"
        ]

        let strippedScalars = raw.unicodeScalars.filter { !formatMarks.contains($0) }
        var s = String(String.UnicodeScalarView(strippedScalars))
        // normalize common unicode variants from copy/paste
        s = s.replacingOccurrences(of: "\u{2212}", with: "-") // unicode minus
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
        // normalize separators/spaces
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "\t", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // some copies contain non-breaking hyphen or similar, normalize common punctuation spacing
        s = s.replacingOccurrences(of: " (", with: "(")
        s = s.replacingOccurrences(of: ") ", with: ")")

        return s.lowercased()
    }

    private func parseCoordinates() {
        errorText = nil
        successText = nil
        parsedVillages = []
        mergedVillages = []

        let lines = coordsInput
            .components(separatedBy: .newlines)
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }

        let pattern = "^\\s*(.+?)\\s*\\(\\s*([-+]?\\d+)\\s*[\\|/]\\s*([-+]?\\d+)\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            errorText = "Regex Fehler"
            return
        }

        var results: [VillageProfile] = []

        for line in lines {
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let m = regex.firstMatch(in: line, options: [], range: range) else { continue }
            guard m.numberOfRanges >= 4 else { continue }

            let name = cleanLine(ns.substring(with: m.range(at: 1)))
            let xStr = ns.substring(with: m.range(at: 2))
            let yStr = ns.substring(with: m.range(at: 3))

            guard let x = Int(xStr), let y = Int(yStr) else { continue }
            if name.isEmpty { continue }

            results.append(VillageProfile(name: name, x: x, y: y, allowedTroops: [], troopCounts: [:]))
        }

        // De-duplicate by (x,y)
        var seen: Set<String> = []
        for v in results {
            let key = "\(v.x)|\(v.y)"
            if seen.contains(key) { continue }
            seen.insert(key)
            parsedVillages.append(v)
        }

        if parsedVillages.isEmpty {
            errorText = "Keine Koordinaten erkannt.\nBeispiel: Bowser Castle (-6|3)"
        } else {
            successText = "\(parsedVillages.count) Dörfer erkannt"
        }
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

        // Spaltenreihenfolge der Truppenübersicht (deutscher Client).
        // Matching über uiName, weil rawValue intern anders sein kann.

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

        // Fallback
        return Array(all.prefix(10))
    }

    private func parseTroopsAndMerge() {
        errorText = nil
        successText = nil
        mergedVillages = []

        guard !parsedVillages.isEmpty else {
            errorText = "Bitte zuerst Koordinaten importieren."
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

        // Focus only on table area
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

        // Build name -> (counts, allowed)
        var parsedByName: [String: (counts: [String: Int], allowed: [String])] = [:]

        for line in tableLines {
            let tokens = line
                .replacingOccurrences(of: "\t", with: " ")
                .split(whereSeparator: { $0 == " " })
                .map(String.init)

            if tokens.count < 3 { continue }

            // Table contains troop counts directly (no population column).
            // Usually 10 troop columns; sometimes +1 hero column.
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

            // First N values are the 10 troop columns.
            let countsStart = 0
            let countsEnd = countsStart + troopOrder.count
            if tail.count < countsEnd { continue }
            let unitCounts = Array(tail[countsStart..<countsEnd])

            // Optional hero is the last value (ignored for allowedTroops for now).
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

        // Merge into villages imported in step 2
        var missing: [String] = []
        mergedVillages = parsedVillages.map { v in
            var out = v
            let key = normalizeVillageKey(v.name)
            if let payload = parsedByName[key] {
                out.troopCounts = payload.counts
                out.allowedTroops = payload.allowed
            } else {
                missing.append(v.name)
            }
            return out
        }

        if !missing.isEmpty {
            errorText = "Keine Truppen gefunden für: \(missing.count). Namen müssen exakt gleich sein."
        }

        // If everything merged, clear error.
        if missing.isEmpty {
            errorText = nil
            let totalTroopTypes = mergedVillages.reduce(0) { $0 + $1.allowedTroops.count }
            successText = "\(mergedVillages.count) Dörfer mit \(totalTroopTypes) Truppentypen erkannt"
        }
    }
}
