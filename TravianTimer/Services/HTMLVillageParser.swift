import Foundation

// MARK: - HTML Parsed Village

struct HTMLParsedVillage {
    let villageName: String?
    let resourceData: ParsedVillageData
    let buildingData: ParsedBuildingData
    /// Slot-genaue Gebaeude-Zuweisung (Key = slotNumber 1-23)
    let slotAssignments: [Int: (buildingId: Int, level: Int)]
}

// MARK: - HTML Village Parser

enum HTMLVillageParser {

    // MARK: - Errors

    enum ParseError: LocalizedError {
        case noDataFound
        case invalidHTML

        var errorDescription: String? {
            switch self {
            case .noDataFound:
                return "Keine Gebaeude- oder Rohstoffdaten im HTML gefunden."
            case .invalidHTML:
                return "Das HTML konnte nicht verarbeitet werden."
            }
        }
    }

    // MARK: - Parse

    /// Parst eine gespeicherte Travian-Kingdoms HTML-Seite und extrahiert
    /// Gebaeude, Rohstofffelder und den Dorfnamen.
    static func parse(html: String) throws -> HTMLParsedVillage {
        guard !html.isEmpty else { throw ParseError.invalidHTML }

        // 1. Alle Location-Eintraege extrahieren (type + location + level)
        let entries = extractEntries(from: html)
        guard !entries.isEmpty else { throw ParseError.noDataFound }

        // 2. Aufteilen: Locations 1-18 = Ressourcen, 19+ = Gebaeude
        var resourceEntries: [(type: Int, location: Int, level: Int)] = []
        var buildingEntries: [(type: Int, location: Int, level: Int)] = []

        for entry in entries {
            if entry.location >= 1 && entry.location <= 18 {
                resourceEntries.append(entry)
            } else if entry.location >= 19 {
                buildingEntries.append(entry)
            }
        }

        // 3. Rohstofffelder parsen
        let resourceData = parseResourceFields(resourceEntries)

        // 4. Gebaeude parsen
        let (buildingData, slotAssignments) = parseBuildings(buildingEntries)

        // 5. Dorfname extrahieren
        let villageName = extractVillageName(from: html)

        return HTMLParsedVillage(
            villageName: villageName,
            resourceData: resourceData,
            buildingData: buildingData,
            slotAssignments: slotAssignments
        )
    }

    // MARK: - Gebaeude auf Plan anwenden (slot-genau)

    /// Wendet die HTML-Gebaeude-Daten auf einen VillagePlan an.
    /// Anders als `applyBuildingsToPlan` werden Gebaeude an ihre exakten Slot-Positionen gesetzt.
    static func applyToPlan(_ data: HTMLParsedVillage, plan: inout VillagePlan) {
        // Alle Slots leeren
        for i in 0..<plan.slots.count {
            plan.slots[i].buildingId = nil
            plan.slots[i].level = 0
        }

        // Gebaeude mit exakter Slot-Zuweisung setzen
        for (slotNumber, building) in data.slotAssignments {
            guard slotNumber >= 1, slotNumber <= plan.slots.count else { continue }
            let index = slotNumber - 1
            plan.slots[index].buildingId = building.buildingId
            plan.slots[index].level = max(building.level, 1)
        }
    }

    // MARK: - Private: Eintraege extrahieren

    /// Extrahiert alle (type, location, level) Tripel aus dem HTML.
    ///
    /// HTML-Pattern:
    /// ```
    /// <span ... class="buildingStatusButton location type_24 location_20 ..."
    ///   ...
    ///   <span ... class="buildingLevel">10</span>
    /// ```
    private static func extractEntries(from html: String) -> [(type: Int, location: Int, level: Int)] {
        // Regex: type_XX und location_YY innerhalb eines buildingStatusButton,
        // gefolgt von buildingLevel mit dem Level-Wert
        let pattern = #"type_(\d+)\s+location_(\d+)[\s\S]*?class="buildingLevel"[^>]*>(\d+)<"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        return matches.compactMap { match -> (type: Int, location: Int, level: Int)? in
            guard match.numberOfRanges >= 4,
                  let type = Int(nsHTML.substring(with: match.range(at: 1))),
                  let location = Int(nsHTML.substring(with: match.range(at: 2))),
                  let level = Int(nsHTML.substring(with: match.range(at: 3)))
            else { return nil }

            return (type: type, location: location, level: level)
        }
    }

    // MARK: - Private: Rohstofffelder parsen

    private static func parseResourceFields(_ entries: [(type: Int, location: Int, level: Int)]) -> ParsedVillageData {
        // Sortiere nach Location (1-18)
        let sorted = entries.sorted { $0.location < $1.location }

        // Typ-Mapping: 1=wood, 2=clay, 3=iron, 4=crop
        let typeMap: [Int: String] = [1: "wood", 2: "clay", 3: "iron", 4: "crop"]

        let fields = sorted.map { entry in
            ParsedVillageData.ParsedField(
                type: typeMap[entry.type] ?? "crop",
                level: entry.level
            )
        }

        // Dorftyp aus Verteilung bestimmen
        var counts: [String: Int] = ["wood": 0, "clay": 0, "iron": 0, "crop": 0]
        for field in fields {
            counts[field.type, default: 0] += 1
        }

        let villageType = "\(counts["wood"] ?? 0)-\(counts["clay"] ?? 0)-\(counts["iron"] ?? 0)-\(counts["crop"] ?? 0)"

        return ParsedVillageData(villageType: villageType, fields: fields)
    }

    // MARK: - Private: Gebaeude parsen

    private static func parseBuildings(_ entries: [(type: Int, location: Int, level: Int)])
        -> (ParsedBuildingData, [Int: (buildingId: Int, level: Int)])
    {
        var slotAssignments: [Int: (buildingId: Int, level: Int)] = [:]
        var buildings: [ParsedBuildingData.ParsedBuilding] = []

        for entry in entries {
            let slotNumber: Int
            if entry.location >= 19 && entry.location <= 40 {
                // Regulaere Slots: location 19 → slot 1, ..., location 40 → slot 22
                slotNumber = entry.location - 18
            } else if entry.location == 42 {
                // Bonus-Slot 1
                slotNumber = 23
            } else {
                // Unbekannte Location (41, 43+) → ueberspringen
                continue
            }

            slotAssignments[slotNumber] = (buildingId: entry.type, level: entry.level)
            buildings.append(ParsedBuildingData.ParsedBuilding(
                buildingId: entry.type,
                level: entry.level
            ))
        }

        return (ParsedBuildingData(buildings: buildings), slotAssignments)
    }

    // MARK: - Private: Dorfname extrahieren

    /// Sucht den ausgewaehlten Dorfnamen aus dem Village-Dropdown.
    ///
    /// HTML-Pattern:
    /// ```
    /// <li ... class="... selected ..." ...>
    ///   <div class="villageEntry" ...>1.0 Bowser Castle</div>
    /// ```
    private static func extractVillageName(from html: String) -> String? {
        // Suche: <li ... selected ... > ... <div class="villageEntry" ...>NAME</div>
        let pattern = #"<li[^>]*class="[^"]*selected[^"]*"[^>]*>[\s\S]*?<div\s+class="villageEntry"[^>]*>([^<]+)<"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
              match.numberOfRanges >= 2
        else { return nil }

        let name = (html as NSString).substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? nil : name
    }
}
