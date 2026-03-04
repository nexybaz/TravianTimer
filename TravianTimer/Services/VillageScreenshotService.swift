import UIKit
import Supabase

// MARK: - Parsed Village Data (Rohstofffelder)

struct ParsedVillageData: Codable {
    let villageType: String
    let fields: [ParsedField]

    struct ParsedField: Codable {
        let type: String    // "wood", "clay", "iron", "crop"
        let level: Int      // 0-20
    }
}

// MARK: - Parsed Building Data (Gebaeude)

struct ParsedBuildingData: Codable {
    let buildings: [ParsedBuilding]

    struct ParsedBuilding: Codable {
        let buildingId: Int // 5-46 (Travian Gebaeude-ID)
        let level: Int      // 0-20
    }
}

// MARK: - Screenshot Parse Error

enum ScreenshotParseError: LocalizedError {
    case notAuthenticated
    case imageTooLarge
    case analyseFailed(String)
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Nicht angemeldet."
        case .imageTooLarge:
            return "Bild zu gross. Bitte einen normalen Screenshot verwenden."
        case .analyseFailed(let msg):
            return msg
        case .invalidResponse:
            return "Unerwartete Antwort vom Server."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        }
    }
}

// MARK: - Edge Function Responses

private struct ResourceEdgeResponse: Codable {
    let error: String?
    let villageType: String?
    let fields: [ParsedVillageData.ParsedField]?
}

private struct BuildingEdgeResponse: Codable {
    let error: String?
    let buildings: [ParsedBuildingData.ParsedBuilding]?
}

// MARK: - Village Screenshot Service

enum VillageScreenshotService {

    private static var client: SupabaseClient { SupabaseManager.client }

    // MARK: - Rohstofffelder parsen

    /// Sendet ein Screenshot-Bild an die Edge Function und gibt die erkannten Feld-Daten zurueck.
    static func parseScreenshot(_ image: UIImage) async throws -> ParsedVillageData {
        let base64String = try prepareImage(image)
        let body: [String: String] = ["image": base64String]

        let response: ResourceEdgeResponse = try await invokeFunction(
            "parse-village-screenshot", body: body
        )

        // Pruefe ob Edge Function einen Fehler zurueckgegeben hat
        if let errorMsg = response.error {
            throw ScreenshotParseError.analyseFailed(errorMsg)
        }

        guard let villageType = response.villageType,
              let fields = response.fields, !fields.isEmpty else {
            throw ScreenshotParseError.invalidResponse
        }

        return ParsedVillageData(villageType: villageType, fields: fields)
    }

    // MARK: - Gebaeude parsen

    /// Sendet ein Screenshot-Bild an die Edge Function und gibt die erkannten Gebaeude-Daten zurueck.
    static func parseBuildingScreenshot(_ image: UIImage) async throws -> ParsedBuildingData {
        let base64String = try prepareImage(image)
        let body: [String: String] = ["image": base64String]

        let response: BuildingEdgeResponse = try await invokeFunction(
            "parse-building-screenshot", body: body
        )

        // Pruefe ob Edge Function einen Fehler zurueckgegeben hat
        if let errorMsg = response.error {
            throw ScreenshotParseError.analyseFailed(errorMsg)
        }

        guard let buildings = response.buildings, !buildings.isEmpty else {
            throw ScreenshotParseError.invalidResponse
        }

        return ParsedBuildingData(buildings: buildings)
    }

    // MARK: - Daten auf Plan anwenden

    /// Wendet die erkannten Rohstofffeld-Daten auf einen VillagePlan an.
    static func applyToPlan(_ data: ParsedVillageData, plan: inout VillagePlan) {
        // 1. Village-Typ matchen
        if let matchedType = VillageResourceType.allCases.first(where: { $0.label == data.villageType }) {
            plan.changeVillageType(to: matchedType)
        }

        // 2. Felder-Level setzen
        guard data.fields.count == plan.resourceFields.count else {
            for i in 0..<min(data.fields.count, plan.resourceFields.count) {
                plan.resourceFields[i].level = data.fields[i].level
            }
            return
        }

        for i in 0..<plan.resourceFields.count {
            plan.resourceFields[i].level = data.fields[i].level
        }
    }

    /// Wendet die erkannten Gebaeude-Daten auf einen VillagePlan an.
    static func applyBuildingsToPlan(_ data: ParsedBuildingData, plan: inout VillagePlan) {
        // Alle Slots leeren
        for i in 0..<plan.slots.count {
            plan.slots[i].buildingId = nil
            plan.slots[i].level = 0
        }

        // Rally Point (ID 16) → Slot 2 (Index 1)
        var remainingBuildings = data.buildings

        if let rpIndex = remainingBuildings.firstIndex(where: { $0.buildingId == 16 }) {
            let rp = remainingBuildings.remove(at: rpIndex)
            plan.slots[1].buildingId = 16
            plan.slots[1].level = max(rp.level, 1)
        }

        // Restliche Gebaeude auf verfuegbare Slots verteilen
        // Slot-Reihenfolge: 1 (Index 0), 3-5 (Index 2-4), 6-21 (Index 5-20), 22-23 (Index 21-22)
        let availableSlotIndices = [0, 2, 3, 4] + Array(5...20) + [21, 22]

        for (i, building) in remainingBuildings.enumerated() {
            guard i < availableSlotIndices.count else { break }
            let slotIndex = availableSlotIndices[i]
            plan.slots[slotIndex].buildingId = building.buildingId
            plan.slots[slotIndex].level = max(building.level, 1)
        }
    }

    // MARK: - Hilfsfunktionen

    /// Bereitet ein Bild fuer den Upload vor: JPEG-Komprimierung + Base64
    private static func prepareImage(_ image: UIImage) throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw ScreenshotParseError.analyseFailed("Bild konnte nicht verarbeitet werden.")
        }

        let base64String = jpegData.base64EncodedString()

        guard base64String.count < 5_500_000 else {
            throw ScreenshotParseError.imageTooLarge
        }

        return base64String
    }

    /// Generische Edge Function Invocation mit Fehlerbehandlung
    private static func invokeFunction<T: Codable>(
        _ functionName: String,
        body: [String: String]
    ) async throws -> T {
        do {
            return try await client.functions.invoke(
                functionName,
                options: .init(body: body)
            ) { data, _ in
                guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                    throw ScreenshotParseError.invalidResponse
                }
                return decoded
            }
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                // Versuche Fehlermeldung aus Response-Body zu lesen
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["error"] as? String {
                    throw ScreenshotParseError.analyseFailed(msg)
                }
                if code == 401 {
                    throw ScreenshotParseError.notAuthenticated
                }
                throw ScreenshotParseError.networkError("Server-Fehler (\(code))")
            case .relayError:
                throw ScreenshotParseError.networkError("Edge Function nicht erreichbar.")
            }
        } catch let error as ScreenshotParseError {
            throw error
        } catch {
            throw ScreenshotParseError.networkError(error.localizedDescription)
        }
    }
}
