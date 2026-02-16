import Foundation

// MARK: - Pull Result

struct PullResult {
    let calls: [CallItem]
    let teamCalls: [CallItem]
    let deletedCallIds: [UUID]
}

// MARK: - Call Sync Service (Supabase Cloud)

final class CallSyncService {

    static let shared = CallSyncService()
    private init() {}

    // MARK: - Push

    /// Sendet alle lokalen Calls (mit Pledges) an die Cloud.
    func pushCalls(_ calls: [CallItem]) async -> Bool {
        guard let (url, userId) = endpoint() else { return false }

        let callDicts: [[String: Any]] = calls.map { callToDict($0) }

        var body: [String: Any] = [
            "action": "push",
            "user_id": userId,
            "calls": callDicts
        ]

        // device_token mitsenden für Migration bestehender Calls
        if let deviceToken = PushService.shared.storedToken {
            body["device_token"] = deviceToken
        }

        return await post(url: url, body: body) != nil
    }

    // MARK: - Pull

    /// Lädt alle Calls für diesen User aus der Cloud + gelöschte Call-IDs.
    func pullCalls(since: Date? = nil) async -> PullResult? {
        guard let (url, userId) = endpoint() else { return nil }

        var body: [String: Any] = [
            "action": "pull",
            "user_id": userId
        ]

        if let since {
            body["since"] = iso8601String(since)
        }

        // device_token mitsenden für Migration
        if let deviceToken = PushService.shared.storedToken {
            body["device_token"] = deviceToken
        }

        guard let response = await post(url: url, body: body),
              let callsArray = response["calls"] as? [[String: Any]] else {
            return nil
        }

        let calls = callsArray.compactMap { dictToCall($0) }

        // Team-Calls parsen
        let teamArray = response["team_calls"] as? [[String: Any]] ?? []
        let teamCalls = teamArray.compactMap { dictToCall($0, isShared: true) }

        // Gelöschte Call-IDs parsen
        let deletedStrings = response["deleted_call_ids"] as? [String] ?? []
        let deletedIds = deletedStrings.compactMap { UUID(uuidString: $0) }

        return PullResult(calls: calls, teamCalls: teamCalls, deletedCallIds: deletedIds)
    }

    // MARK: - Team Pledges

    /// Sendet Pledges für einen Team-Call (der einem anderen User gehört).
    func pushTeamPledges(callId: UUID, pledges: [TroopPledge], deletedPledgeIds: [UUID] = []) async -> Bool {
        guard let (url, _) = endpoint() else { return false }

        var body: [String: Any] = [
            "action": "pledge",
            "call_id": callId.uuidString,
            "pledges": pledges.map { pledgeToDict($0) }
        ]

        if !deletedPledgeIds.isEmpty {
            body["deleted_pledge_ids"] = deletedPledgeIds.map(\.uuidString)
        }

        return await post(url: url, body: body) != nil
    }

    // MARK: - Delete

    /// Löscht Calls aus der Cloud.
    func deleteCalls(ids: [UUID]) async -> Bool {
        guard let (url, userId) = endpoint() else { return false }

        let body: [String: Any] = [
            "action": "delete",
            "user_id": userId,
            "call_ids": ids.map(\.uuidString)
        ]

        return await post(url: url, body: body) != nil
    }

    // MARK: - Helpers

    private func endpoint() -> (URL, String)? {
        guard let userId = AuthService.shared.userId,
              AuthService.shared.isAuthenticated,
              let url = URL(string: "\(AuthService.supabaseURL)/functions/v1/sync-calls") else {
            return nil
        }

        return (url, userId)
    }

    private func post(url: URL, body: [String: Any]) async -> [String: Any]? {
        guard let accessToken = await AuthService.shared.validAccessToken() else {
            print("[Sync] Kein gültiger Access-Token")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("[Sync] HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let success = dict?["success"] as? Bool ?? false
            return success ? dict : nil
        } catch {
            print("[Sync] Netzwerkfehler: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Serialisierung

    private func iso8601String(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func parseISO8601(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }

    private func callToDict(_ call: CallItem) -> [String: Any] {
        var dict: [String: Any] = [
            "id": call.id.uuidString,
            "title": call.title,
            "target_x": call.targetX,
            "target_y": call.targetY,
            "arrival": iso8601String(call.arrival),
            "status": call.status.rawValue,
            "created_at": iso8601String(call.createdAt),
            "updated_at": iso8601String(call.updatedAt),
        ]

        if let link = call.link { dict["link"] = link.absoluteString }
        if let cropLimit = call.cropLimit { dict["crop_limit"] = cropLimit }
        if let discordId = call.discordMessageId { dict["discord_message_id"] = discordId }
        if let guildId = call.guildId { dict["guild_id"] = guildId }

        dict["pledges"] = call.pledges.map { pledgeToDict($0) }

        // Gelöschte Pledge-IDs mitsenden
        if !call.deletedPledgeIds.isEmpty {
            dict["deleted_pledge_ids"] = call.deletedPledgeIds.map(\.uuidString)
        }

        return dict
    }

    private func pledgeToDict(_ pledge: TroopPledge) -> [String: Any] {
        var dict: [String: Any] = [
            "id": pledge.id.uuidString,
            "player_name": pledge.playerName,
            "village_name": pledge.villageName,
            "village_x": pledge.villageX,
            "village_y": pledge.villageY,
            "troop_kind": pledge.troopKind,
            "count": pledge.count,
            "pledged_at": iso8601String(pledge.pledgedAt),
        ]
        if let userId = pledge.userId { dict["user_id"] = userId }
        return dict
    }

    private func dictToCall(_ dict: [String: Any], isShared: Bool = false) -> CallItem? {
        guard let idStr = dict["id"] as? String, let id = UUID(uuidString: idStr),
              let targetX = dict["target_x"] as? Int,
              let targetY = dict["target_y"] as? Int,
              let arrivalStr = dict["arrival"] as? String,
              let arrival = parseISO8601(arrivalStr) else {
            return nil
        }

        let title = dict["title"] as? String ?? "Deff-Call"
        let link = (dict["link"] as? String).flatMap { URL(string: $0) }
        let statusRaw = dict["status"] as? String ?? "open"
        let status: CallItem.Status = statusRaw == "done" ? .done : .open
        let createdAt = (dict["created_at"] as? String).flatMap { parseISO8601($0) } ?? .now
        let updatedAt = (dict["updated_at"] as? String).flatMap { parseISO8601($0) } ?? createdAt
        let cropLimit = dict["crop_limit"] as? Int
        let discordMessageId = dict["discord_message_id"] as? String
        let guildId = dict["guild_id"] as? String

        // Pledges parsen
        let pledgesArray = dict["pledges"] as? [[String: Any]] ?? []
        let pledges: [TroopPledge] = pledgesArray.compactMap { dictToPledge($0) }

        return CallItem(
            id: id,
            title: title,
            targetX: targetX,
            targetY: targetY,
            arrival: arrival,
            link: link,
            status: status,
            createdAt: createdAt,
            cropLimit: cropLimit,
            pledges: pledges,
            discordMessageId: discordMessageId,
            updatedAt: updatedAt,
            guildId: guildId,
            isShared: isShared
        )
    }

    private func dictToPledge(_ dict: [String: Any]) -> TroopPledge? {
        guard let playerName = dict["player_name"] as? String,
              let villageName = dict["village_name"] as? String,
              let villageX = dict["village_x"] as? Int,
              let villageY = dict["village_y"] as? Int,
              let troopKind = dict["troop_kind"] as? String,
              let count = dict["count"] as? Int else {
            return nil
        }

        let idStr = dict["id"] as? String
        let id = idStr.flatMap { UUID(uuidString: $0) } ?? UUID()
        let pledgedAt = (dict["pledged_at"] as? String).flatMap { parseISO8601($0) } ?? .now

        let pledgeUserId = dict["user_id"] as? String

        return TroopPledge(
            id: id,
            playerName: playerName,
            villageName: villageName,
            villageX: villageX,
            villageY: villageY,
            troopKind: troopKind,
            count: count,
            pledgedAt: pledgedAt,
            userId: pledgeUserId
        )
    }
}
