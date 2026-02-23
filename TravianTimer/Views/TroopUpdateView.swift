import SwiftUI
import UIKit

// MARK: - Truppen aktualisieren (Sheet)

struct TroopUpdateView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var profile = ProfileStore.shared
    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue
    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""

    /// Volk aus dem Profil (verifiziert) oder aus der manuellen AppStorage-Einstellung
    private var effectiveTribeRaw: String {
        if let tribe = AuthService.shared.profile?.tribe, !tribe.isEmpty {
            // Profil-Tribe auf Tribe mappen
            switch tribe {
            case "Gallier": return Tribe.gauls.rawValue
            case "Roemer":  return Tribe.romans.rawValue
            case "Germanen": return Tribe.teutons.rawValue
            default: return selectedTribeRaw
            }
        }
        return selectedTribeRaw
    }

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

                                Text("Öffne die Truppenübersicht im Spiel, wähle den gesamten Seiteninhalt (Ctrl+A / ⌘A) und kopiere ihn (Ctrl+C / ⌘C). Dann hier einfügen.")
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

        // Falls Villages leer sind (z.B. nach Login noch nicht geladen), aus Supabase nachladen
        if profile.villages.isEmpty {
            Task {
                await profile.loadFromSupabase()
                if profile.villages.isEmpty {
                    errorText = "Keine Dörfer vorhanden. Verifiziere zuerst deinen Travian-Account in den Einstellungen."
                } else {
                    parseTroops()
                }
            }
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

        // Tabelle erkennen (mehrsprachig: DE, EN, FR)
        let tableLines = extractTableLines(from: lines)

        if tableLines.isEmpty {
            errorText = "Keine Tabelle gefunden. Öffne die Truppenübersicht und kopiere die gesamte Seite (Ctrl+A → Ctrl+C)."
            return
        }

        // Parse: Name → (counts, allowed)
        var parsedByName: [String: (counts: [String: Int], allowed: [String])] = [:]
        let needWithoutHero = troopOrder.count   // 10
        let needWithHero = troopOrder.count + 1  // 11

        for line in tableLines {
            // Noise-Zeile? → überspringen
            if isNoiseLineForTroops(line) { continue }

            // Tokens aufbereiten: Tabs → Space, splitten
            let rawTokens = line
                .replacingOccurrences(of: "\t", with: " ")
                .split(whereSeparator: { $0 == " " })
                .map(String.init)

            if rawTokens.count < 3 { continue }

            // Phase 1: Bonus-Tokens (+40, +55 etc.) entfernen und Slash-Format normalisieren
            let cleaned = rawTokens.compactMap { token -> String? in
                // "+40", "+55", "+644" → Schmiede-Bonus → ignorieren
                if token.hasPrefix("+"), Int(token.dropFirst()) != nil {
                    return nil
                }
                // "886/6200" → "886" (aktuell/kapazität → nur aktuell)
                if token.contains("/") {
                    let parts = token.split(separator: "/", maxSplits: 1)
                    if parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil {
                        return String(parts[0])
                    }
                }
                return token
            }

            if cleaned.count < 3 { continue }

            // Phase 2: Von rechts Integers sammeln (wie vorher, aber auf bereinigten Tokens)
            var ints: [Int] = []
            var idx = cleaned.count - 1
            while idx >= 0 && ints.count < needWithHero {
                if let v = Int(cleaned[idx]) {
                    ints.insert(v, at: 0)
                    idx -= 1
                } else {
                    break
                }
            }

            if ints.count < needWithoutHero { continue }
            let hasHero = (ints.count >= needWithHero)
            let numericTailCount = hasHero ? needWithHero : needWithoutHero

            let nameTokens = cleaned.prefix(max(0, cleaned.count - numericTailCount))
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

    // MARK: - Table extraction (Ctrl+A tolerant)

    /// Extrahiert die relevanten Tabellenzeilen aus einem Ctrl+A Copy.
    /// Sucht mehrsprachig nach Header- und Footer-Markern und filtert Noise.
    private func extractTableLines(from lines: [String]) -> [String] {
        // Bekannte Header-Marker (Zeile die den Tabellenanfang markiert)
        let headerMarkers: Set<String> = ["dorfname", "village name", "nom du village", "nome del villaggio", "nazwa wioski"]
        // Bekannte Footer-Marker (Zeile die das Tabellenende markiert)
        let footerPrefixes = ["gesamt", "total", "totale", "suma"]

        var tableLines: [String] = []
        var inTable = false

        for l in lines {
            let lower = l.lowercased().trimmingCharacters(in: .whitespaces)

            if !inTable {
                if headerMarkers.contains(lower) {
                    inTable = true
                }
                continue
            }

            // Footer erreicht → Tabelle fertig
            if footerPrefixes.contains(where: { lower.hasPrefix($0) }) {
                break
            }

            tableLines.append(l)
        }

        // Fallback: Falls kein Header-Marker gefunden, versuche alle Zeilen
        // die wie Truppen-Daten aussehen (enthalten genug Zahlen)
        if tableLines.isEmpty {
            tableLines = lines.filter { line in
                let numericCount = countNumericTokens(in: line)
                return numericCount >= 5  // mindestens 5 Zahlen = wahrscheinlich Truppendaten
            }
        }

        return tableLines
    }

    /// Zaehlt wie viele Tokens in einer Zeile als Zahl parsbar sind (nach Normalisierung)
    private func countNumericTokens(in line: String) -> Int {
        let tokens = line
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: { $0 == " " })

        var count = 0
        for token in tokens {
            let s = String(token)
            // Bonus-Token (+40) nicht zaehlen
            if s.hasPrefix("+"), Int(s.dropFirst()) != nil { continue }
            // Slash-Format: 886/6200 → zaehlt als 1 Zahl
            if s.contains("/") {
                let parts = s.split(separator: "/", maxSplits: 1)
                if parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil {
                    count += 1
                    continue
                }
            }
            if Int(s) != nil { count += 1 }
        }
        return count
    }

    // MARK: - Noise-Filter

    /// Erkennt Zeilen die UI-Elemente, Navigation oder andere irrelevante Inhalte enthalten
    private func isNoiseLineForTroops(_ line: String) -> Bool {
        let lower = line.lowercased()

        // Bekannte UI-Noise-Woerter (Travian Kingdoms Oberflaeche)
        let noiseExact: Set<String> = [
            "discord", "help center", "support", "settings", "logout",
            "village name", "dorfname", "nom du village",
            "barbar", "römer", "roemer", "gallier", "germanen",
            "romans", "gauls", "teutons", "roman", "gaul", "teuton",
            "overview", "übersicht", "uebersicht",
            "troops", "truppen", "troupes",
            "hero", "held", "héros",
            "adventures", "abenteuer", "aventures",
            "profile", "profil",
            "messages", "nachrichten",
            "reports", "berichte",
            "map", "karte",
            "resources", "ressourcen",
            "building", "gebäude", "gebaeude",
            "marketplace", "marktplatz",
            "rally point", "versammlungsplatz",
            "auction", "auktion",
            "kingdom", "königreich", "koenigreich",
        ]

        // Pruefen ob die gesamte Zeile ein bekanntes Noise-Wort ist
        let trimmed = lower.trimmingCharacters(in: .whitespaces)
        if noiseExact.contains(trimmed) { return true }

        // Zeilen die nur aus einem kurzen Text ohne Zahlen bestehen (< 3 Zeichen Zahlenanteil)
        // und keine bekannten Dorfnamen sein koennten → Noise
        // Das wird aber besser durch den numericTail-Check im Haupt-Parser abgefangen.

        return false
    }

    // MARK: - Helpers

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
        let tribeRaw = effectiveTribeRaw
        let all = TroopKind.troops(forSelectedTribeRaw: tribeRaw)
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

        if tribeRaw == Tribe.gauls.rawValue {
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

        if tribeRaw == Tribe.romans.rawValue {
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

        if tribeRaw == Tribe.teutons.rawValue {
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
