import Foundation

// MARK: - Shared Text Cleaning Utility

/// Wiederverwendbare Funktionen zum Bereinigen von kopiertem Text
/// (Unicode-Kontrollzeichen, Travian-spezifische Formatierung etc.)
enum TextCleaner {

    /// Bereinigt eine Zeile von Unicode-Kontrollzeichen und normalisiert Whitespace.
    /// Identisch mit der bisherigen `cleanLine()` in VillageImportView / TroopUpdateView.
    static func cleanLine(_ raw: String) -> String {
        let formatMarks: Set<Unicode.Scalar> = [
            "\u{200E}", "\u{200F}",                                     // LTR/RTL marks
            "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", // embedding/overrides
            "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}",            // isolate controls
            "\u{200B}", "\u{FEFF}", "\u{2060}",                        // zero-width space, BOM, word-joiner
        ]

        let strippedScalars = raw.unicodeScalars.filter { !formatMarks.contains($0) }
        var s = String(String.UnicodeScalarView(strippedScalars))

        // Normalize common unicode variants from copy/paste
        s = s.replacingOccurrences(of: "\u{2212}", with: "-") // unicode minus → ASCII minus
        s = s.replacingOccurrences(of: "\u{FF5C}", with: "|") // fullwidth vertical line
        s = s.replacingOccurrences(of: "\u{00A6}", with: "|") // broken bar
        s = s.replacingOccurrences(of: "\u{2223}", with: "|") // divides symbol
        s = s.replacingOccurrences(of: "\t",       with: " ")
        s = s.replacingOccurrences(of: "\r",       with: " ")
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ") // non-breaking space

        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fuehrt einen Regex-Match auf einem String aus und gibt die Gruppen als [Substring] zurueck.
    /// [0] = Full Match, [1]+ = Capture Groups.
    static func firstMatch(_ text: String, pattern: String) -> [Substring]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range) else { return nil }

        var groups: [Substring] = []
        for i in 0..<match.numberOfRanges {
            let r = match.range(at: i)
            if let rr = Range(r, in: text) {
                groups.append(text[rr])
            }
        }
        return groups
    }
}
