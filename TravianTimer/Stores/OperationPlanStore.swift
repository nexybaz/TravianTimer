import Foundation
import Combine
import Observation
import Supabase
import Realtime

// MARK: - Operation Plan Store (CRUD + Realtime + Timing)

@MainActor
@Observable
final class OperationPlanStore {

    // MARK: Published State

    var operations: [Operation] = []
    var attacksByOperation: [UUID: [PlannedAttack]] = [:]
    var kingdomVillages: [KingdomVillage] = []
    var isLoading = false
    var errorText: String?

    // MARK: Private

    @ObservationIgnored private var client: SupabaseClient { SupabaseManager.client }
    @ObservationIgnored private var operationsChannel: RealtimeChannelV2?
    @ObservationIgnored private var attacksChannel: RealtimeChannelV2?
    @ObservationIgnored private var realtimeTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    init() {
        NotificationCenter.default.publisher(for: AuthService.didSignOutNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleLogout() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Timing Engine

    /// Berechnet Abmarsch-Zeitpunkt und Laufzeit.
    static func calculateDeparture(
        arrival: Date,
        fromX: Int, fromY: Int,
        toX: Int, toY: Int,
        troopSpeed: Double,
        worldSpeed: Double
    ) -> (departureAt: Date, travelSeconds: Double) {
        let dist = Calculator.distance(fromX: fromX, fromY: fromY, toX: toX, toY: toY)
        let effectiveSpeed = troopSpeed * worldSpeed
        guard effectiveSpeed > 0 else { return (arrival, 0) }
        let travelSeconds = (dist / effectiveSpeed) * 3600.0
        let departureAt = arrival.addingTimeInterval(-travelSeconds)
        return (departureAt, travelSeconds)
    }

    // MARK: - Load Operations

    func loadOperations() async {
        isLoading = true
        errorText = nil

        do {
            let result: [Operation] = try await client
                .from("operations")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            operations = result
        } catch {
            print("[OperationPlanStore] Fehler beim Laden: \(error)")
            errorText = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load Attacks

    func loadAttacks(operationId: UUID) async {
        do {
            let result: [PlannedAttack] = try await client
                .from("planned_attacks")
                .select()
                .eq("operation_id", value: operationId)
                .order("sort_order", ascending: true)
                .order("departure_at", ascending: true)
                .execute()
                .value

            attacksByOperation[operationId] = result
        } catch {
            print("[OperationPlanStore] Fehler beim Laden der Angriffe: \(error)")
        }
    }

    // MARK: - Load Kingdom Villages

    func loadKingdomVillages() async {
        guard let kingdomId = AuthService.shared.profile?.kingdomId else { return }

        do {
            let result: [KingdomVillageRow] = try await client
                .from("villages")
                .select("id, name, x, y, population, user_id, profiles!inner(player_name, kingdom_id)")
                .eq("profiles.kingdom_id", value: kingdomId)
                .order("name", ascending: true)
                .execute()
                .value

            kingdomVillages = result.map { row in
                KingdomVillage(
                    id: row.id,
                    userId: row.userId,
                    playerName: row.profiles.playerName,
                    villageName: row.name,
                    x: row.x,
                    y: row.y,
                    population: row.population
                )
            }
        } catch {
            print("[OperationPlanStore] Fehler beim Laden der Kingdom-Dörfer: \(error)")
        }
    }

    // MARK: - Fetch Enemy Kingdoms (from map_players)

    func fetchEnemyKingdoms() async -> [EnemyKingdom] {
        guard let profile = AuthService.shared.profile,
              let worldId = profile.worldId else { return [] }
        let myKingdomId = profile.kingdomId

        do {
            let rows: [MapPlayerRow] = try await client
                .from("map_players")
                .select("kingdom_id, kingdom_tag")
                .eq("world_id", value: worldId)
                .not("kingdom_id", operator: .is, value: "null")
                .execute()
                .value

            var seen = Set<Int>()
            var result: [EnemyKingdom] = []
            for row in rows {
                guard let kid = row.kingdomId, kid != myKingdomId, !seen.contains(kid) else { continue }
                seen.insert(kid)
                result.append(EnemyKingdom(kingdomId: kid, tag: row.kingdomTag))
            }
            return result.sorted { ($0.tag ?? "") < ($1.tag ?? "") }
        } catch {
            print("[OperationPlanStore] Fehler beim Laden der Koenigreiche: \(error)")
            return []
        }
    }

    // MARK: - Fetch Enemy Players (from map_players)

    func fetchEnemyPlayers(kingdomId: Int) async -> [EnemyPlayer] {
        guard let worldId = AuthService.shared.profile?.worldId else { return [] }

        do {
            let rows: [MapPlayerRow] = try await client
                .from("map_players")
                .select("travian_player_id, player_name")
                .eq("world_id", value: worldId)
                .eq("kingdom_id", value: kingdomId)
                .order("player_name", ascending: true)
                .execute()
                .value

            return rows.compactMap { row in
                guard let pid = row.travianPlayerId else { return nil }
                return EnemyPlayer(userId: pid, playerName: row.playerName)
            }
        } catch {
            print("[OperationPlanStore] Fehler beim Laden der Spieler: \(error)")
            return []
        }
    }

    // MARK: - Fetch Enemy Villages (from map_players JSONB)

    func fetchEnemyVillages(playerId: Int) async -> [EnemyVillage] {
        guard let worldId = AuthService.shared.profile?.worldId else { return [] }

        do {
            let row: MapPlayerVillagesRow = try await client
                .from("map_players")
                .select("villages")
                .eq("world_id", value: worldId)
                .eq("travian_player_id", value: playerId)
                .single()
                .execute()
                .value

            return row.villages.map {
                EnemyVillage(id: UUID(), name: $0.name, x: $0.x, y: $0.y, population: $0.population)
            }
        } catch {
            print("[OperationPlanStore] Fehler beim Laden der Doerfer: \(error)")
            return []
        }
    }

    // MARK: - Create Operation

    func createOperation(
        title: String,
        description: String? = nil,
        worldSpeed: Double = 1.0,
        visibility: Operation.Visibility = .full
    ) async -> Operation? {
        guard let userId = try? await client.auth.session.user.id else {
            print("[OperationPlanStore] Kein User eingeloggt")
            errorText = "Nicht eingeloggt"
            return nil
        }

        let kingdomId = AuthService.shared.profile?.kingdomId

        let insert = OperationInsert(
            createdBy: userId,
            kingdomId: kingdomId,
            title: title,
            description: description,
            worldSpeed: worldSpeed,
            visibility: visibility.rawValue
        )

        do {
            let result: Operation = try await client
                .from("operations")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            operations.insert(result, at: 0)
            return result
        } catch {
            print("[OperationPlanStore] Fehler beim Erstellen: \(error)")
            errorText = error.localizedDescription
            return nil
        }
    }

    // MARK: - Update Operation

    func updateOperation(_ op: Operation) async {
        do {
            try await client
                .from("operations")
                .update([
                    "title": AnyJSON.string(op.title),
                    "description": op.description.map { AnyJSON.string($0) } ?? AnyJSON.null,
                    "world_speed": AnyJSON.double(op.worldSpeed),
                    "status": AnyJSON.string(op.status.rawValue),
                    "visibility": AnyJSON.string(op.visibility.rawValue)
                ])
                .eq("id", value: op.id)
                .execute()

            if let idx = operations.firstIndex(where: { $0.id == op.id }) {
                operations[idx] = op
            }
        } catch {
            print("[OperationPlanStore] Fehler beim Aktualisieren: \(error)")
            errorText = error.localizedDescription
        }
    }

    // MARK: - Delete Operation

    func deleteOperation(_ id: UUID) async {
        do {
            try await client
                .from("operations")
                .delete()
                .eq("id", value: id)
                .execute()

            operations.removeAll { $0.id == id }
            attacksByOperation.removeValue(forKey: id)
        } catch {
            print("[OperationPlanStore] Fehler beim Loeschen: \(error)")
        }
    }

    // MARK: - Add Planned Attack

    func addPlannedAttack(
        operationId: UUID,
        assignedTo: UUID? = nil,
        attackType: AttackType = .attack,
        playerName: String,
        villageName: String,
        villageX: Int, villageY: Int,
        targetX: Int, targetY: Int,
        targetPlayer: String? = nil,
        targetVillage: String? = nil,
        arrival: Date,
        troopSpeed: Double,
        worldSpeed: Double,
        notes: String? = nil
    ) async -> PlannedAttack? {
        let timing = Self.calculateDeparture(
            arrival: arrival,
            fromX: villageX, fromY: villageY,
            toX: targetX, toY: targetY,
            troopSpeed: troopSpeed,
            worldSpeed: worldSpeed
        )

        let insert = PlannedAttackInsert(
            operationId: operationId,
            assignedTo: assignedTo,
            attackType: attackType,
            playerName: playerName,
            villageName: villageName,
            villageX: villageX,
            villageY: villageY,
            targetX: targetX,
            targetY: targetY,
            targetPlayer: targetPlayer,
            targetVillage: targetVillage,
            arrival: arrival,
            travelSeconds: timing.travelSeconds,
            departureAt: timing.departureAt,
            troopSpeed: troopSpeed,
            notes: notes,
            sortOrder: (attacksByOperation[operationId]?.count ?? 0)
        )

        do {
            let result: PlannedAttack = try await client
                .from("planned_attacks")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            attacksByOperation[operationId, default: []].append(result)
            return result
        } catch {
            print("[OperationPlanStore] Fehler beim Hinzufuegen: \(error)")
            errorText = error.localizedDescription
            return nil
        }
    }

    // MARK: - Delete Planned Attack

    func deletePlannedAttack(_ id: UUID, operationId: UUID) async {
        do {
            try await client
                .from("planned_attacks")
                .delete()
                .eq("id", value: id)
                .execute()

            attacksByOperation[operationId]?.removeAll { $0.id == id }
        } catch {
            print("[OperationPlanStore] Fehler beim Loeschen: \(error)")
        }
    }

    // MARK: - Confirmation Workflow

    func updateConfirmation(attackId: UUID, operationId: UUID, confirmed: Bool) async {
        do {
            try await client
                .from("planned_attacks")
                .update([
                    "confirmed": AnyJSON.bool(confirmed),
                    "confirmed_at": confirmed ? AnyJSON.string(ISO8601DateFormatter().string(from: .now)) : AnyJSON.null
                ])
                .eq("id", value: attackId)
                .execute()

            if var attacks = attacksByOperation[operationId],
               let idx = attacks.firstIndex(where: { $0.id == attackId }) {
                attacks[idx].confirmed = confirmed
                attacks[idx].confirmedAt = confirmed ? .now : nil
                attacksByOperation[operationId] = attacks
            }
        } catch {
            print("[OperationPlanStore] Fehler bei Bestaetigung: \(error)")
        }
    }

    func updateSent(attackId: UUID, operationId: UUID, sent: Bool) async {
        do {
            try await client
                .from("planned_attacks")
                .update([
                    "sent": AnyJSON.bool(sent),
                    "sent_at": sent ? AnyJSON.string(ISO8601DateFormatter().string(from: .now)) : AnyJSON.null
                ])
                .eq("id", value: attackId)
                .execute()

            if var attacks = attacksByOperation[operationId],
               let idx = attacks.firstIndex(where: { $0.id == attackId }) {
                attacks[idx].sent = sent
                attacks[idx].sentAt = sent ? .now : nil
                attacksByOperation[operationId] = attacks
            }
        } catch {
            print("[OperationPlanStore] Fehler bei Sendebestaetigung: \(error)")
        }
    }

    // MARK: - Join via Code

    func joinOperation(code: String) async -> Operation? {
        do {
            // 1. Operation per Code finden
            let ops: [Operation] = try await client
                .from("operations")
                .select()
                .eq("join_code", value: code.uppercased())
                .execute()
                .value

            guard let op = ops.first else {
                errorText = "Kein Einsatz mit diesem Code gefunden."
                return nil
            }

            // 2. Beitreten
            guard let userId = try? await client.auth.session.user.id else { return nil }

            try await client
                .from("operation_members")
                .upsert([
                    "operation_id": AnyJSON.string(op.id.uuidString),
                    "user_id": AnyJSON.string(userId.uuidString)
                ], onConflict: "operation_id,user_id")
                .execute()

            // 3. In lokale Liste aufnehmen
            if !operations.contains(where: { $0.id == op.id }) {
                operations.insert(op, at: 0)
            }

            return op
        } catch {
            print("[OperationPlanStore] Fehler beim Beitreten: \(error)")
            errorText = error.localizedDescription
            return nil
        }
    }

    // MARK: - Realtime

    func subscribeToRealtime(kingdomId: Int) async {
        await unsubscribeFromRealtime()

        let opsCh = client.realtimeV2.channel("operations-kingdom-\(kingdomId)")
        self.operationsChannel = opsCh

        let attacksCh = client.realtimeV2.channel("attacks-kingdom-\(kingdomId)")
        self.attacksChannel = attacksCh

        // Operations: INSERT
        let opInsertTask = Task { [weak self] in
            for await insertion in opsCh.postgresChange(InsertAction.self, schema: "public", table: "operations") {
                guard let self else { return }
                if let op = try? insertion.decodeRecord(as: Operation.self, decoder: JSONDecoder.supabaseRT) {
                    if !self.operations.contains(where: { $0.id == op.id }) {
                        self.operations.insert(op, at: 0)
                    }
                }
            }
        }

        // Operations: UPDATE
        let opUpdateTask = Task { [weak self] in
            for await update in opsCh.postgresChange(UpdateAction.self, schema: "public", table: "operations") {
                guard let self else { return }
                if let updated = try? update.decodeRecord(as: Operation.self, decoder: JSONDecoder.supabaseRT) {
                    if let idx = self.operations.firstIndex(where: { $0.id == updated.id }) {
                        self.operations[idx] = updated
                    }
                }
            }
        }

        // Operations: DELETE
        let opDeleteTask = Task { [weak self] in
            for await deletion in opsCh.postgresChange(DeleteAction.self, schema: "public", table: "operations") {
                guard let self else { return }
                if let old = try? deletion.decodeOldRecord(as: OperationIdOnly.self, decoder: JSONDecoder()) {
                    self.operations.removeAll { $0.id == old.id }
                    self.attacksByOperation.removeValue(forKey: old.id)
                }
            }
        }

        // Attacks: INSERT
        let attackInsertTask = Task { [weak self] in
            for await insertion in attacksCh.postgresChange(InsertAction.self, schema: "public", table: "planned_attacks") {
                guard let self else { return }
                if let attack = try? insertion.decodeRecord(as: PlannedAttack.self, decoder: JSONDecoder.supabaseRT) {
                    var existing = self.attacksByOperation[attack.operationId] ?? []
                    if !existing.contains(where: { $0.id == attack.id }) {
                        existing.append(attack)
                        self.attacksByOperation[attack.operationId] = existing
                    }
                }
            }
        }

        // Attacks: UPDATE
        let attackUpdateTask = Task { [weak self] in
            for await update in attacksCh.postgresChange(UpdateAction.self, schema: "public", table: "planned_attacks") {
                guard let self else { return }
                if let updated = try? update.decodeRecord(as: PlannedAttack.self, decoder: JSONDecoder.supabaseRT) {
                    var existing = self.attacksByOperation[updated.operationId] ?? []
                    if let idx = existing.firstIndex(where: { $0.id == updated.id }) {
                        existing[idx] = updated
                        self.attacksByOperation[updated.operationId] = existing
                    }
                }
            }
        }

        // Attacks: DELETE
        let attackDeleteTask = Task { [weak self] in
            for await deletion in attacksCh.postgresChange(DeleteAction.self, schema: "public", table: "planned_attacks") {
                guard let self else { return }
                if let old = try? deletion.decodeOldRecord(as: PlannedAttackDeleteRecord.self, decoder: JSONDecoder()) {
                    self.attacksByOperation[old.operationId]?.removeAll { $0.id == old.id }
                }
            }
        }

        realtimeTasks = [opInsertTask, opUpdateTask, opDeleteTask, attackInsertTask, attackUpdateTask, attackDeleteTask]

        await opsCh.subscribe()
        await attacksCh.subscribe()
    }

    func unsubscribeFromRealtime() async {
        for task in realtimeTasks { task.cancel() }
        realtimeTasks = []

        await operationsChannel?.unsubscribe()
        await attacksChannel?.unsubscribe()
        operationsChannel = nil
        attacksChannel = nil
    }

    func handleLogout() async {
        await unsubscribeFromRealtime()
        operations = []
        attacksByOperation = [:]
        errorText = nil
    }
}

// MARK: - Leichtgewichtiges Struct fuer Realtime DELETE

private struct PlannedAttackDeleteRecord: Codable {
    let id: UUID
    let operationId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case operationId = "operation_id"
    }
}

// MARK: - Kingdom Village Models

struct KingdomVillage: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let playerName: String
    let villageName: String
    let x: Int
    let y: Int
    let population: Int?
}

struct KingdomVillageRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let x: Int
    let y: Int
    let population: Int?
    let profiles: KingdomVillageProfile

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, x, y, population, profiles
    }
}

struct KingdomVillageProfile: Codable {
    let playerName: String
    let kingdomId: Int?

    enum CodingKeys: String, CodingKey {
        case playerName = "player_name"
        case kingdomId = "kingdom_id"
    }
}

// MARK: - Enemy Target Models

struct EnemyKingdom: Identifiable, Hashable {
    let kingdomId: Int
    let tag: String?
    var id: Int { kingdomId }

    var displayName: String {
        if let tag, !tag.isEmpty { return tag }
        return "Kingdom \(kingdomId)"
    }
}

struct EnemyPlayer: Identifiable, Hashable {
    let userId: Int
    let playerName: String
    var id: Int { userId }
}

struct EnemyVillage: Identifiable, Hashable {
    let id: UUID
    let name: String
    let x: Int
    let y: Int
    let population: Int?
}

// MARK: - Supabase Row Decoders (map_players)

private struct MapPlayerRow: Codable {
    let travianPlayerId: Int?
    let playerName: String
    let kingdomId: Int?
    let kingdomTag: String?

    enum CodingKeys: String, CodingKey {
        case travianPlayerId = "travian_player_id"
        case playerName      = "player_name"
        case kingdomId       = "kingdom_id"
        case kingdomTag      = "kingdom_tag"
    }
}

private struct MapPlayerVillagesRow: Decodable {
    let villages: [MapVillageJSON]
}

private struct MapVillageJSON: Decodable {
    let id: Int?
    let name: String
    let x: Int
    let y: Int
    let population: Int?
}

// MARK: - JSONDecoder Extension fuer Supabase Realtime

private extension JSONDecoder {
    static var supabaseRT: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ungültiges Datum: \(string)")
        }
        return decoder
    }
}
