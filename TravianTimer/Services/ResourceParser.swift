import Foundation

// MARK: - Geparste Ressourcen-Produktion

struct ParsedResources: Equatable {
    let wood: Int       // Produktion/h
    let clay: Int       // Produktion/h
    let iron: Int       // Produktion/h
    let crop: Int       // Produktion/h (kann negativ sein)
}

// MARK: - Ressourcen-Parser

/// Erkennt Ressourcen-Produktionsraten aus kopiertem Travian-Kingdoms-Text.
///
/// Erwartetes Muster (4× jeweils):
/// ```
/// 17747/340k      ← Bestand/Kapazitaet
/// +1759           ← Produktion/h
/// ```
/// Reihenfolge immer: Holz → Lehm → Eisen → Getreide
///
/// Der Parser ist fehlertolerant:
/// - Zwischen Paaren duerfen beliebige Zeilen stehen (z.B. Labels)
/// - Tausender-Trennzeichen (+1.363 / +1,363) werden unterstuetzt
/// - Bestand und Produktion auf einer Zeile ("5059/40000 +1363") wird erkannt
enum ResourceParser {

    static func parse(text: String) -> ParsedResources? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { TextCleaner.cleanLine($0) }
            .filter { !$0.isEmpty }

        // Strategie 1: Bestand + Produktion auf getrennten Zeilen
        //   Dazwischen duerfen beliebige Zeilen stehen (Labels etc.)
        if let result = parseWithSeparateLines(lines) {
            return result
        }

        // Strategie 2: Bestand und Produktion auf einer Zeile ("5059/40000 +1363")
        if let result = parseWithCombinedLines(lines) {
            return result
        }

        // Strategie 3: Nur 4 Produktions-Werte (+/- Zahl) ohne Bestand-Zeilen
        if let result = parseProductionOnly(lines) {
            return result
        }

        return nil
    }

    // MARK: - Strategie 1: Getrennte Zeilen (tolerant)

    /// Sucht Bestand-Zeilen und danach die naechste Produktions-Zeile.
    /// Zwischen Paaren duerfen beliebige Zeilen (Labels, Leerzeilen) stehen.
    private static func parseWithSeparateLines(_ lines: [String]) -> ParsedResources? {
        var productions: [Int] = []
        var i = 0

        while i < lines.count && productions.count < 4 {
            if isStockLine(lines[i]) {
                // Suche die Produktions-Zeile in den naechsten paar Zeilen
                let searchEnd = min(i + 4, lines.count)
                var found = false
                for j in (i + 1)..<searchEnd {
                    if let prod = parseProductionLine(lines[j]) {
                        productions.append(prod)
                        i = j + 1
                        found = true
                        break
                    }
                }
                if !found { i += 1 }
            } else {
                i += 1
            }
        }

        guard productions.count == 4 else { return nil }
        return ParsedResources(
            wood: productions[0],
            clay: productions[1],
            iron: productions[2],
            crop: productions[3]
        )
    }

    // MARK: - Strategie 2: Kombinierte Zeilen

    /// Erkennt "5059/40000 +1363" auf einer einzelnen Zeile.
    private static func parseWithCombinedLines(_ lines: [String]) -> ParsedResources? {
        let pattern = #"\d+(?:[.,]\d+)?\s*[kK]?\s*/\s*\d+(?:[.,]\d+)?\s*[kK]?\s+([+-][\d.,]+)"#
        var productions: [Int] = []

        for line in lines {
            guard let groups = TextCleaner.firstMatch(line, pattern: pattern),
                  groups.count >= 2 else { continue }
            let raw = String(groups[1])
            guard let value = parseNumber(raw) else { continue }
            productions.append(value)
            if productions.count == 4 { break }
        }

        guard productions.count == 4 else { return nil }
        return ParsedResources(
            wood: productions[0],
            clay: productions[1],
            iron: productions[2],
            crop: productions[3]
        )
    }

    // MARK: - Strategie 3: Nur Produktions-Werte

    /// Findet 4 aufeinanderfolgende Produktions-Werte ohne Bestand-Zeilen.
    private static func parseProductionOnly(_ lines: [String]) -> ParsedResources? {
        var productions: [Int] = []

        for line in lines {
            if let prod = parseProductionLine(line) {
                productions.append(prod)
                if productions.count == 4 { break }
            } else {
                // Kette unterbrochen → nur zuruecksetzen wenn wir schon Ergebnisse hatten
                if !productions.isEmpty { productions.removeAll() }
            }
        }

        guard productions.count == 4 else { return nil }
        return ParsedResources(
            wood: productions[0],
            clay: productions[1],
            iron: productions[2],
            crop: productions[3]
        )
    }

    // MARK: - Zeilen-Erkennung

    /// Erkennt eine Bestand/Kapazitaet-Zeile wie "17747/340k" oder "5059/40000"
    private static func isStockLine(_ line: String) -> Bool {
        let pattern = #"\d+(?:[.,]\d+)?\s*[kK]?\s*/\s*\d+(?:[.,]\d+)?\s*[kK]?"#
        return TextCleaner.firstMatch(line, pattern: pattern) != nil
    }

    /// Erkennt eine Produktions-Zeile wie "+1759", "-12935", "+1.363" oder "+1,363"
    private static func parseProductionLine(_ line: String) -> Int? {
        let pattern = #"^[+-][\d.,]+$"#
        guard TextCleaner.firstMatch(line, pattern: pattern) != nil else { return nil }
        return parseNumber(line)
    }

    // MARK: - Zahl parsen

    /// Parst eine Zahl mit optionalem Vorzeichen und Tausender-Trennzeichen.
    /// "+1.363" → 1363, "-12,935" → -12935, "+938" → 938
    private static func parseNumber(_ raw: String) -> Int? {
        let cleaned = raw
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Int(cleaned)
    }

}
