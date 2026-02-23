import Foundation
import UIKit
import Combine
import Supabase
import Realtime

// MARK: - Calls Store (Supabase CRUD + Realtime)

@MainActor
final class CallsStore: ObservableObject {

    // MARK: Published State

    @Published var calls: [CallItem] = []
    @Published var pledgesByCall: [UUID: [TroopPledge]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorText: String? = nil

    // Parser input
    @Published var inputText: String = ""

    // Deep link from notification
    @Published var pendingOpenCallId: UUID? = nil
    @Published var pendingOpenRowKey: String? = nil

    // Player profile (start villages + troop selection)
    @Published var profile = ProfileStore.shared

    // MARK: Private

    private var client: SupabaseClient { SupabaseManager.client }
    private var callsChannel: RealtimeChannelV2?
    private var pledgesChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []

    private var cancellables = Set<AnyCancellable>()

    /// Keys fuer Pledges die gerade optimistisch aktualisiert werden.
    /// Format: "callId|userId|villageName|troopKind"
    /// Realtime DELETE Events fuer diese Keys werden ignoriert,
    /// damit sie das optimistische Update nicht zerstoeren.
    private var optimisticPledgeKeys = Set<String>()

    // MARK: Init

    init() {
        // Bei Logout alles aufraeumen
        NotificationCenter.default.publisher(for: AuthService.didSignOutNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.handleLogout() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Calls (Kingdom-scoped)

    /// Laedt alle Calls des eigenen Kingdoms aus Supabase.
    func loadCalls() async {
        guard let kingdomId = AuthService.shared.profile?.kingdomId else {
            calls = []
            return
        }

        isLoading = true
        errorText = nil

        do {
            let result: [CallItem] = try await client
                .from("calls")
                .select()
                .eq("kingdom_id", value: kingdomId)
                .order("arrival", ascending: true)
                .execute()
                .value

            calls = result
        } catch {
            print("[CallsStore] loadCalls Fehler: \(error.localizedDescription)")
            errorText = "Calls konnten nicht geladen werden."
        }

        isLoading = false
    }

    // MARK: - Load Pledges

    /// Laedt alle Pledges fuer einen bestimmten Call.
    func loadPledges(callId: UUID) async {
        do {
            let result: [TroopPledge] = try await client
                .from("pledges")
                .select()
                .eq("call_id", value: callId.uuidString)
                .execute()
                .value

            pledgesByCall[callId] = result
        } catch {
            print("[CallsStore] loadPledges Fehler: \(error.localizedDescription)")
        }
    }

    /// Laedt alle Pledges fuer alle geladenen Calls.
    func loadAllPledges() async {
        for call in calls {
            await loadPledges(callId: call.id)
        }
    }

    // MARK: - Create Call

    /// Erstellt einen neuen Deff-Call in Supabase.
    func createCall(
        title: String,
        targetX: Int,
        targetY: Int,
        arrival: Date,
        link: String? = nil,
        cropLimit: Int? = nil
    ) async {
        guard let userId = AuthService.shared.currentUserId else {
            errorText = "Nicht angemeldet."
            return
        }
        let kingdomId = AuthService.shared.profile?.kingdomId

        let insert = CallInsert(
            createdBy: userId,
            kingdomId: kingdomId,
            title: title,
            targetX: targetX,
            targetY: targetY,
            arrival: arrival,
            link: link,
            cropLimit: cropLimit,
            status: "open"
        )

        do {
            let created: CallItem = try await client
                .from("calls")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            // Lokal hinzufuegen (Realtime bringt es auch, aber sofort anzeigen)
            if !calls.contains(where: { $0.id == created.id }) {
                calls.insert(created, at: 0)
            }
        } catch {
            print("[CallsStore] createCall Fehler: \(error.localizedDescription)")
            errorText = "Call konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Parser → Call erstellen

    /// Discord-Parser: Text parsen und Call erstellen.
    func createCallFromParser() async {
        errorText = nil

        do {
            let parsed = try CallParser.parse(text: inputText, now: .now)
            let title = deriveTitle(from: inputText)

            await createCall(
                title: title,
                targetX: parsed.targetX,
                targetY: parsed.targetY,
                arrival: parsed.arrival,
                link: parsed.link?.absoluteString,
                cropLimit: parsed.cropLimit
            )
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Fehler beim Parsen"
        }
    }

    /// Manuell: Call erstellen.
    func createCallManual(title: String, targetX: Int, targetY: Int, arrival: Date, linkString: String) async {
        errorText = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Call" : trimmedTitle

        let trimmedLink = linkString.trimmingCharacters(in: .whitespacesAndNewlines)
        let link: String? = trimmedLink.isEmpty ? nil : trimmedLink

        if let link, URL(string: link) == nil {
            errorText = "Ungueltige URL"
            return
        }

        await createCall(
            title: finalTitle,
            targetX: targetX,
            targetY: targetY,
            arrival: arrival,
            link: link
        )
    }

    // MARK: - Toggle Status

    /// Wechselt Call-Status zwischen open <-> inactive.
    func toggleDone(_ call: CallItem) async {
        let newStatus: CallItem.Status = (call.status == .open) ? .inactive : .open

        do {
            try await client
                .from("calls")
                .update(["status": newStatus.rawValue])
                .eq("id", value: call.id.uuidString)
                .execute()

            // Lokal sofort updaten
            if let idx = calls.firstIndex(where: { $0.id == call.id }) {
                calls[idx].status = newStatus
            }
        } catch {
            print("[CallsStore] toggleDone Fehler: \(error.localizedDescription)")
            errorText = "Status konnte nicht geaendert werden."
        }
    }

    // MARK: - Delete Call

    /// Loescht einen Call (nur admin via RLS).
    func deleteCall(_ call: CallItem) async {
        do {
            try await client
                .from("calls")
                .delete()
                .eq("id", value: call.id.uuidString)
                .execute()

            calls.removeAll { $0.id == call.id }
            pledgesByCall.removeValue(forKey: call.id)
        } catch {
            print("[CallsStore] deleteCall Fehler: \(error.localizedDescription)")
            errorText = "Call konnte nicht geloescht werden."
        }
    }

    // MARK: - Save Pledge

    /// Speichert eine Truppen-Zusicherung in Supabase.
    /// Entfernt zuerst bestehende Pledges fuer dieses Dorf+Truppentyp, dann INSERT.
    /// Optimistisches lokales Update sofort — Realtime synchronisiert andere Geraete.
    func savePledge(
        callId: UUID,
        villageName: String,
        villageX: Int,
        villageY: Int,
        troopKind: String,
        count: Int
    ) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        let playerName = AuthService.shared.profile?.playerName ?? "Unbekannt"

        let pledgeKey = "\(callId)|\(userId)|\(villageName)|\(troopKind)"

        // Markiere als optimistisch — Realtime DELETE Events fuer diesen Key werden ignoriert
        optimisticPledgeKeys.insert(pledgeKey)

        // Optimistisches lokales Update sofort (UI reagiert instant)
        var existing = pledgesByCall[callId] ?? []
        existing.removeAll { $0.userId == userId && $0.villageName == villageName && $0.troopKind == troopKind }
        if count > 0 {
            let localPledge = TroopPledge(
                callId: callId,
                userId: userId,
                playerName: playerName,
                villageName: villageName,
                villageX: villageX,
                villageY: villageY,
                troopKind: troopKind,
                count: count
            )
            existing.append(localPledge)
        }
        pledgesByCall[callId] = existing

        do {
            // 1. Alte Pledges fuer dieses Dorf+Truppentyp loeschen
            try await client
                .from("pledges")
                .delete()
                .eq("call_id", value: callId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .eq("village_name", value: villageName)
                .eq("troop_kind", value: troopKind)
                .execute()

            // 2. Neues Pledge nur wenn count > 0
            if count > 0 {
                let insert = PledgeInsert(
                    callId: callId,
                    userId: userId,
                    playerName: playerName,
                    villageName: villageName,
                    villageX: villageX,
                    villageY: villageY,
                    troopKind: troopKind,
                    count: count
                )

                try await client
                    .from("pledges")
                    .insert(insert)
                    .execute()
            }

            // Kein loadPledges() noetig — Realtime aktualisiert automatisch.
            // Das lokale optimistische Update oben sorgt fuer sofortige UI-Reaktion.
            // optimisticPledgeKeys wird vom Realtime INSERT Handler entfernt.

            // Falls count == 0 (nur DELETE, kein INSERT), Key sofort entfernen
            if count == 0 {
                optimisticPledgeKeys.remove(pledgeKey)
            }
        } catch {
            print("[CallsStore] savePledge Fehler: \(error.localizedDescription)")
            errorText = "Pledge konnte nicht gespeichert werden."
            optimisticPledgeKeys.remove(pledgeKey)
            // Bei Fehler: Korrekten Stand aus DB laden
            await loadPledges(callId: callId)
        }
    }

    // MARK: - Options (lokal, keine DB)

    func options(for call: CallItem, now: Date) -> [OptionRow] {
        let starts = profile.villagesAsStarts(fallback: Defaults.startVillages)

        let base = Calculator.calculateOptions(
            starts: starts,
            targetX: call.targetX,
            targetY: call.targetY,
            arrival: call.arrival,
            now: now
        )

        return base.filter { row in
            profile.isTroopAllowed(forVillageName: row.start.name, troopRaw: row.troop.rawValue)
        }
    }

    // MARK: - Deep Link

    func pullPendingDeepLinkFromDefaults() {
        if let callIdStr = UserDefaults.standard.string(forKey: NotificationManager.userInfoCallIdKey),
           let rowKey = UserDefaults.standard.string(forKey: NotificationManager.userInfoRowKeyKey),
           let id = UUID(uuidString: callIdStr) {
            pendingOpenCallId = id
            pendingOpenRowKey = rowKey
            UserDefaults.standard.removeObject(forKey: NotificationManager.userInfoCallIdKey)
            UserDefaults.standard.removeObject(forKey: NotificationManager.userInfoRowKeyKey)
        }
    }

    func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string {
            inputText = clip
        }
    }

    // MARK: - Realtime

    /// Abonniert Realtime-Changes fuer Calls + Pledges des eigenen Kingdoms.
    func subscribeToRealtime(kingdomId: Int) async {
        // Erst alte Subscriptions aufraeumen
        await unsubscribeFromRealtime()

        // Calls Channel
        let callsCh = client.realtimeV2.channel("calls-kingdom-\(kingdomId)")
        self.callsChannel = callsCh

        // Pledges Channel
        let pledgesCh = client.realtimeV2.channel("pledges-kingdom-\(kingdomId)")
        self.pledgesChannel = pledgesCh

        // WICHTIG: Listener VOR subscribe registrieren!

        // Calls: INSERT
        let callInsertTask = Task { [weak self] in
            for await insertion in callsCh.postgresChange(InsertAction.self, schema: "public", table: "calls") {
                guard let self else { return }
                print("[Realtime] Call INSERT empfangen")
                if let newCall = try? insertion.decodeRecord(as: CallItem.self, decoder: JSONDecoder.supabase) {
                    if !self.calls.contains(where: { $0.id == newCall.id }) {
                        self.calls.append(newCall)
                    }
                }
            }
        }

        // Calls: UPDATE
        let callUpdateTask = Task { [weak self] in
            for await update in callsCh.postgresChange(UpdateAction.self, schema: "public", table: "calls") {
                guard let self else { return }
                print("[Realtime] Call UPDATE empfangen")
                if let updated = try? update.decodeRecord(as: CallItem.self, decoder: JSONDecoder.supabase) {
                    if let idx = self.calls.firstIndex(where: { $0.id == updated.id }) {
                        self.calls[idx] = updated
                    }
                }
            }
        }

        // Calls: DELETE — leichtgewichtiges Decoding (nur ID), damit Date-Felder kein Problem machen
        let callDeleteTask = Task { [weak self] in
            for await deletion in callsCh.postgresChange(DeleteAction.self, schema: "public", table: "calls") {
                guard let self else { return }
                print("[Realtime] Call DELETE empfangen — oldRecord: \(deletion.oldRecord)")
                if let old = try? deletion.decodeOldRecord(as: CallIdOnly.self, decoder: JSONDecoder()) {
                    print("[Realtime] Call DELETE id=\(old.id) — entferne aus Liste (\(self.calls.count) Calls)")
                    self.calls.removeAll { $0.id == old.id }
                    self.pledgesByCall.removeValue(forKey: old.id)
                    print("[Realtime] Call DELETE fertig — \(self.calls.count) Calls verbleiben")
                } else {
                    print("[Realtime] Call DELETE decoding fehlgeschlagen — lade Calls neu")
                    await self.loadCalls()
                }
            }
        }

        // Pledges: INSERT
        let pledgeInsertTask = Task { [weak self] in
            for await insertion in pledgesCh.postgresChange(InsertAction.self, schema: "public", table: "pledges") {
                guard let self else { return }
                print("[Realtime] Pledge INSERT empfangen")
                if let newPledge = try? insertion.decodeRecord(as: TroopPledge.self, decoder: JSONDecoder.supabase) {
                    let pledgeKey = "\(newPledge.callId)|\(newPledge.userId?.uuidString ?? "")|\(newPledge.villageName)|\(newPledge.troopKind)"

                    // Optimistischen Key entfernen — DB hat den finalen Stand
                    self.optimisticPledgeKeys.remove(pledgeKey)

                    var existing = self.pledgesByCall[newPledge.callId] ?? []
                    // Entferne optimistisches Pledge mit gleicher Kombination
                    // (hat andere UUID, wuerde sonst Duplikat erzeugen)
                    existing.removeAll {
                        $0.userId == newPledge.userId
                        && $0.villageName == newPledge.villageName
                        && $0.troopKind == newPledge.troopKind
                    }
                    existing.append(newPledge)
                    self.pledgesByCall[newPledge.callId] = existing
                }
            }
        }

        // Pledges: UPDATE
        let pledgeUpdateTask = Task { [weak self] in
            for await update in pledgesCh.postgresChange(UpdateAction.self, schema: "public", table: "pledges") {
                guard let self else { return }
                print("[Realtime] Pledge UPDATE empfangen")
                if let updated = try? update.decodeRecord(as: TroopPledge.self, decoder: JSONDecoder.supabase) {
                    var existing = self.pledgesByCall[updated.callId] ?? []
                    if let idx = existing.firstIndex(where: { $0.id == updated.id }) {
                        existing[idx] = updated
                    }
                    self.pledgesByCall[updated.callId] = existing
                }
            }
        }

        // Pledges: DELETE — leichtgewichtiges Decoding, damit Date-Felder kein Problem machen
        let pledgeDeleteTask = Task { [weak self] in
            for await deletion in pledgesCh.postgresChange(DeleteAction.self, schema: "public", table: "pledges") {
                guard let self else { return }
                print("[Realtime] Pledge DELETE empfangen")
                if let old = try? deletion.decodeOldRecord(as: PledgeDeleteRecord.self, decoder: JSONDecoder()) {
                    let pledgeKey = "\(old.callId)|\(old.userId?.uuidString ?? "")|\(old.villageName)|\(old.troopKind)"

                    // Wenn ein optimistisches Update laeuft, DELETE ignorieren —
                    // das optimistische Update hat den korrekten Zustand bereits gesetzt.
                    if self.optimisticPledgeKeys.contains(pledgeKey) {
                        print("[Realtime] Pledge DELETE ignoriert (optimistisch): \(pledgeKey)")
                        return
                    }

                    var existing = self.pledgesByCall[old.callId] ?? []
                    existing.removeAll { $0.id == old.id }
                    self.pledgesByCall[old.callId] = existing
                } else {
                    print("[Realtime] Pledge DELETE decoding fehlgeschlagen")
                }
            }
        }

        realtimeTasks = [callInsertTask, callUpdateTask, callDeleteTask,
                         pledgeInsertTask, pledgeUpdateTask, pledgeDeleteTask]

        // JETZT erst subscriben — nachdem alle Listener registriert sind
        do {
            try await callsCh.subscribeWithError()
            print("[Realtime] Calls Channel subscribed ✅")
            try await pledgesCh.subscribeWithError()
            print("[Realtime] Pledges Channel subscribed ✅")
        } catch {
            print("[CallsStore] Realtime subscribe Fehler: \(error.localizedDescription)")
        }
    }

    /// Beendet alle Realtime-Subscriptions.
    func unsubscribeFromRealtime() async {
        for task in realtimeTasks {
            task.cancel()
        }
        realtimeTasks = []

        await callsChannel?.unsubscribe()
        await pledgesChannel?.unsubscribe()
        callsChannel = nil
        pledgesChannel = nil
    }

    /// Raeumt auf bei Logout.
    func handleLogout() async {
        await unsubscribeFromRealtime()
        calls = []
        pledgesByCall = [:]
        errorText = nil
    }

    // MARK: - Title Derivation (fuer Parser)

    private func deriveTitle(from text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            if line.contains("(") && (line.contains("/") || line.contains("|")) && line.contains(")") {
                if let idx = line.firstIndex(of: "(") {
                    let name = String(line[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { return name }
                }
            }
        }

        for line in lines {
            let lower = line.lowercased()
            if let range = lower.range(of: "fuer") ?? lower.range(of: "für") {
                let after = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !after.isEmpty { return after }
            }
        }

        return "Call"
    }
}

// MARK: - Leichtgewichtige Structs fuer Realtime DELETE

/// Nur die ID — fuer DELETE Events, damit Decoding nicht an Date-Feldern scheitert.
private struct CallIdOnly: Decodable {
    let id: UUID
}

/// Nur die Felder die wir fuer Pledge-DELETE brauchen.
private struct PledgeDeleteRecord: Decodable {
    let id: UUID
    let callId: UUID
    let userId: UUID?
    let villageName: String
    let troopKind: String

    enum CodingKeys: String, CodingKey {
        case id
        case callId = "call_id"
        case userId = "user_id"
        case villageName = "village_name"
        case troopKind = "troop_kind"
    }
}

// MARK: - JSONDecoder Extension fuer Supabase Realtime

private extension JSONDecoder {
    /// Supabase-kompatibler Decoder mit ISO8601 Datum-Strategie.
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // ISO8601 mit Fractional Seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }

            // Fallback ohne Fractional Seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ungültiges Datum: \(string)")
        }
        return decoder
    }
}
