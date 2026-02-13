import Foundation

enum ParseError: LocalizedError {
    case noCoordinates
    case noTime
    case noLink

    var errorDescription: String? {
        switch self {
        case .noCoordinates:
            return "Keine Ziel-Koordinaten gefunden. Erwartet wird (x/y), (x|y) oder ein Link mit x:-4/y:6."
        case .noTime:
            return "Keine Ankunftszeit gefunden. Erwartet wird HH:MM oder HH:MM:SS."
        case .noLink:
            return "Kein Link gefunden."
        }
    }
}

struct ParsedCall: Equatable {
    var targetX: Int
    var targetY: Int
    var arrival: Date
    var link: URL?
}

struct CallParser {

    static func parse(text: String, now: Date = .now, calendar: Calendar = .current) throws -> ParsedCall {

        let t = cleanDiscordText(text)

        guard let coords = extractCoords(from: t) else {
            throw ParseError.noCoordinates
        }

        guard let time = extractTime(from: t) else {
            throw ParseError.noTime
        }

        var arrival = combine(date: now, time: time, calendar: calendar)

        // Nur bei "Mitternacht-Fall" auf morgen schieben
        if arrival < now {
            let diff = now.timeIntervalSince(arrival)
            if diff > 12 * 3600 {
                arrival = calendar.date(byAdding: .day, value: 1, to: arrival) ?? arrival
            }
        }

        let link = extractFirstTravianLink(from: t)

        return ParsedCall(
            targetX: coords.x,
            targetY: coords.y,
            arrival: arrival,
            link: link
        )
    }

    private static func cleanDiscordText(_ raw: String) -> String {
        // Removes invisible Unicode format marks (common when copying from Discord)
        // and normalizes whitespace so regex matching is stable.

        var s = raw

        // Normalize common non-breaking spaces
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "\t", with: " ")

        // Remove Unicode "Format" characters (category Cf)
        if let re = try? NSRegularExpression(pattern: "\\p{Cf}+", options: []) {
            let range = NSRange(location: 0, length: (s as NSString).length)
            s = re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }

        // Collapse multiple spaces
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        return s
    }

    // 1) (12|8) oder (-4/3)
    // 2) Link .../x:-4/y:6
    private static func extractCoords(from text: String) -> (x: Int, y: Int)? {

        if let m = firstMatch(text, pattern: #"\(\s*(-?\d+)\s*[\/|]\s*(-?\d+)\s*\)"#) {
            return (m[1].intValue, m[2].intValue)
        }

        if let m = firstMatch(text, pattern: #"x:(-?\d+)\s*\/\s*y:(-?\d+)"#) {
            return (m[1].intValue, m[2].intValue)
        }

        return nil
    }

    // findet 18:12 oder 18:12:00
    private static func extractTime(from text: String) -> (h: Int, m: Int, s: Int)? {

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        func hasKeyword(_ line: String) -> Bool {
            let l = line.lowercased()
            return l.contains("ankunft") || l.contains("vor") || l.contains("bis")
        }

        // 1) Prefer lines with arrival keywords
        for line in lines where hasKeyword(line) {
            if let m = firstMatch(line, pattern: #"(\d{1,2}):(\d{2})(?::(\d{2}))?"#) {
                let h = m[1].intValue
                let min = m[2].intValue
                let s = m.count > 3 ? m[3].intValue : 0
                return (h, min, s)
            }
        }

        // 2) Fallback: first time anywhere
        guard let m = firstMatch(text, pattern: #"(\d{1,2}):(\d{2})(?::(\d{2}))?"#) else {
            return nil
        }

        let h = m[1].intValue
        let min = m[2].intValue
        let s = m.count > 3 ? m[3].intValue : 0

        return (h, min, s)
    }

    private static func extractFirstTravianLink(from text: String) -> URL? {
        // Nimmt den ersten https://...kingdoms... Link aus dem Text
        let pattern = #"https?://[^\s]+kingdoms\.[^\s]+"#
        guard let m = firstMatch(text, pattern: pattern) else { return nil }
        return URL(string: String(m[0]))
    }

    private static func combine(date: Date, time: (h: Int, m: Int, s: Int), calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = time.h
        comps.minute = time.m
        comps.second = time.s
        return calendar.date(from: comps) ?? date
    }

    private static func firstMatch(_ text: String, pattern: String) -> [Substring]? {
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

private extension Substring {
    var intValue: Int { Int(self) ?? 0 }
}
