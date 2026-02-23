import Foundation
import Supabase

// MARK: - Travian API Response Models

struct VerifyResult: Codable, Sendable {
    let player: TravianPlayerInfo
    let villages: [TravianVillage]
    let gameworld: GameworldMeta?
    let mock: Bool?
}

struct RefreshResult: Codable, Sendable {
    let player: TravianPlayerInfo
    let villages: [TravianVillage]
    let cached: Bool?
    let mock: Bool?
}

struct TravianPlayerInfo: Codable, Sendable {
    let playerId: Int?
    let name: String
    let tribeId: Int?
    let tribe: String?
    let kingdomId: Int?
    let kingdomTag: String?
    let role: Int?
}

struct TravianVillage: Codable, Sendable {
    let villageId: Int
    let name: String
    let x: Int
    let y: Int
    let population: Int
    let isMainVillage: Bool?
    let isCity: Bool?
}

struct GameworldMeta: Codable, Sendable {
    let speed: Int
    let speedTroops: Int
}

struct GameworldListItem: Codable, Sendable, Identifiable {
    let worldId: String
    let subdomain: String?
    let speed: Int?
    let speedTroops: Int?
    let publicSiteKey: String?

    var id: String { worldId }

    /// Ob fuer diese Welt ein API-Key konfiguriert ist (App kann verifizieren)
    var isConfigured: Bool { publicSiteKey != nil && !publicSiteKey!.isEmpty }

    var label: String {
        let s = speed ?? 1
        return s > 1 ? "\(worldId.uppercased()) (x\(s))" : worldId.uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case worldId = "world_id"
        case subdomain
        case speed
        case speedTroops = "speed_troops"
        case publicSiteKey = "public_site_key"
    }
}

struct ListWorldsResult: Codable, Sendable {
    let worlds: [GameworldListItem]
    let scraped: Int
}

// MARK: - Error Types

enum TravianAPIError: LocalizedError {
    case notAuthenticated
    case notVerified
    case playerNotFound
    case apiUnavailable(String)
    case invalidResponse
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Nicht angemeldet."
        case .notVerified:
            return "Account nicht verifiziert. Bitte zuerst Travian-Account verknüpfen."
        case .playerNotFound:
            return "Spieler nicht gefunden. Bitte Access-Token prüfen."
        case .apiUnavailable(let msg):
            return "Travian API nicht erreichbar: \(msg)"
        case .invalidResponse:
            return "Unerwartete Antwort vom Server."
        case .unknown(let msg):
            return msg
        }
    }
}

// MARK: - Edge Function Error Response

private struct EdgeFunctionError: Codable {
    let error: String?
}

// MARK: - Travian API Service

enum TravianAPIService {

    private static var client: SupabaseClient { SupabaseManager.client }

    // MARK: - Einmalige Verifizierung

    /// Verifiziert den Travian-Account des Spielers.
    /// Schreibt Profil + Doerfer in die DB und gibt das Ergebnis zurueck.
    static func verifyPlayer(worldId: String, accessToken: String) async throws -> VerifyResult {
        let body: [String: String] = [
            "worldId": worldId,
            "accessToken": accessToken,
        ]

        let result: VerifyResult = try await client.functions.invoke(
            "verify-player",
            options: .init(body: body)
        ) { data, _ in
            // Pruefe zuerst ob die Edge Function einen Fehler zurueckgegeben hat
            if let errorResponse = try? JSONDecoder().decode(EdgeFunctionError.self, from: data),
               let errorMsg = errorResponse.error {
                throw mapEdgeFunctionError(errorMsg)
            }

            guard let decoded = try? JSONDecoder().decode(VerifyResult.self, from: data) else {
                throw TravianAPIError.invalidResponse
            }
            return decoded
        }

        return result
    }

    // MARK: - Taeglicher Refresh

    /// Aktualisiert Profil + Doerfer aus der Travian API (max 1x/Tag).
    /// Gibt cached Daten zurueck wenn heute schon abgerufen wurde.
    static func refreshWorldData(worldId: String) async throws -> RefreshResult {
        let body: [String: String] = [
            "worldId": worldId,
        ]

        let result: RefreshResult = try await client.functions.invoke(
            "fetch-world-data",
            options: .init(body: body)
        ) { data, _ in
            if let errorResponse = try? JSONDecoder().decode(EdgeFunctionError.self, from: data),
               let errorMsg = errorResponse.error {
                throw mapEdgeFunctionError(errorMsg)
            }

            guard let decoded = try? JSONDecoder().decode(RefreshResult.self, from: data) else {
                throw TravianAPIError.invalidResponse
            }
            return decoded
        }

        return result
    }

    // MARK: - Spielwelten laden

    /// Laedt alle aktiven Spielwelten von status.kingdoms.com (via Edge Function).
    /// Die Edge Function scraped die Status-Seite und upserted die Welten in die DB.
    static func listWorlds() async throws -> [GameworldListItem] {
        let result: ListWorldsResult = try await client.functions.invoke(
            "list-worlds"
        ) { data, _ in
            if let errorResponse = try? JSONDecoder().decode(EdgeFunctionError.self, from: data),
               let errorMsg = errorResponse.error {
                throw mapEdgeFunctionError(errorMsg)
            }

            do {
                return try JSONDecoder().decode(ListWorldsResult.self, from: data)
            } catch {
                print("[listWorlds] Decode error: \(error)")
                print("[listWorlds] Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw TravianAPIError.invalidResponse
            }
        }

        return result.worlds
    }

    // MARK: - Error Mapping

    private static func mapEdgeFunctionError(_ message: String) -> TravianAPIError {
        let lower = message.lowercased()
        if lower.contains("nicht verifiziert") || lower.contains("not verified") {
            return .notVerified
        }
        if lower.contains("nicht gefunden") || lower.contains("not found") {
            return .playerNotFound
        }
        if lower.contains("travian api") {
            return .apiUnavailable(message)
        }
        if lower.contains("nicht authentifiziert") || lower.contains("session") {
            return .notAuthenticated
        }
        return .unknown(message)
    }
}
