import Foundation
import UIKit
import Combine

// MARK: - Shared Store

final class CallsStore: ObservableObject {

    private let callsKeyV1 = "callsV1"
    private let callsKeyV2 = "callsV2"
    private let callsCorruptBackupKey = "callsCorruptBackup"

    // Parser input
    @Published var inputText: String = ""

    // Call list
    @Published var calls: [CallItem] = [] {
        didSet { saveCalls() }
    }

    // Team-Calls (shared, nicht lokal persistiert)
    @Published var teamCalls: [CallItem] = []

    init() {
        loadCalls()
    }

    // Player profile (start villages + troop selection)
    @Published var profile = ProfileStore.shared

    // UI errors
    @Published var errorText: String? = nil
    @Published var hasCallsBackup: Bool = false

    // Deep link from notification
    @Published var pendingOpenCallId: UUID? = nil
    @Published var pendingOpenRowKey: String? = nil

    func pullPendingDeepLinkFromDefaults() {
        // 1. Remote Push: Call aus JSON-Payload erstellen
        pullPendingRemoteCallFromDefaults()

        // 2. Lokale Notification: bestehende Logik
        if let callIdStr = UserDefaults.standard.string(forKey: NotificationManager.userInfoCallIdKey),
           let rowKey = UserDefaults.standard.string(forKey: NotificationManager.userInfoRowKeyKey),
           let id = UUID(uuidString: callIdStr) {
            pendingOpenCallId = id
            pendingOpenRowKey = rowKey
            UserDefaults.standard.removeObject(forKey: NotificationManager.userInfoCallIdKey)
            UserDefaults.standard.removeObject(forKey: NotificationManager.userInfoRowKeyKey)
        }
    }

    /// Erstellt einen CallItem aus einem Remote-Push-Payload (gespeichert in UserDefaults).
    private func pullPendingRemoteCallFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "tt_pending_remote_call"),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let title = dict["title"] as? String ?? "Deff-Call"
        let targetX = dict["targetX"] as? Int ?? 0
        let targetY = dict["targetY"] as? Int ?? 0
        let cropLimit = dict["cropLimit"] as? Int
        let discordMsgId = dict["discordMessageId"] as? String
        let guildId = dict["guildId"] as? String
        let link: URL? = (dict["link"] as? String).flatMap { URL(string: $0) }

        var arrival = Date.now
        if let arrivalStr = dict["arrival"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = formatter.date(from: arrivalStr) {
                arrival = parsed
            } else {
                // Fallback ohne Fractional Seconds
                formatter.formatOptions = [.withInternetDateTime]
                arrival = formatter.date(from: arrivalStr) ?? Date.now
            }
        }

        // Deduplizierung: gleiche discordMessageId oder gleiche Koordinaten+Zeit
        let isDuplicate = calls.contains { c in
            if let msgId = discordMsgId, let existingId = c.discordMessageId, msgId == existingId {
                return true
            }
            return c.targetX == targetX && c.targetY == targetY &&
                   abs(c.arrival.timeIntervalSince(arrival)) < 60
        }

        guard !isDuplicate else {
            UserDefaults.standard.removeObject(forKey: "tt_pending_remote_call")
            return
        }

        let call = CallItem(
            title: title,
            targetX: targetX,
            targetY: targetY,
            arrival: arrival,
            link: link,
            status: .open,
            createdAt: .now,
            cropLimit: cropLimit,
            discordMessageId: discordMsgId,
            guildId: guildId
        )

        calls.insert(call, at: 0)
        pendingOpenCallId = call.id

        UserDefaults.standard.removeObject(forKey: "tt_pending_remote_call")
    }

    func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string {
            inputText = clip
        }
    }

    // Discord Parser -> Call erzeugen
    func createCallFromParser() {
        errorText = nil

        do {
            let parsed = try CallParser.parse(text: inputText, now: .now)

            let title = deriveTitle(from: inputText)

            let call = CallItem(
                title: title,
                targetX: parsed.targetX,
                targetY: parsed.targetY,
                arrival: parsed.arrival,
                link: parsed.link,
                status: .open,
                createdAt: .now,
                cropLimit: parsed.cropLimit
            )

            calls.insert(call, at: 0)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Fehler beim Parsen"
        }
    }

    // Manuell -> Call erzeugen
    func createCallManual(title: String, targetX: Int, targetY: Int, arrival: Date, linkString: String) {
        errorText = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Call" : trimmedTitle

        var url: URL? = nil
        let trimmed = linkString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let u = URL(string: trimmed) else {
                errorText = "Ungültige URL"
                return
            }
            url = u
        }

        let call = CallItem(
            title: finalTitle,
            targetX: targetX,
            targetY: targetY,
            arrival: arrival,
            link: url,
            status: .open,
            createdAt: .now
        )

        calls.insert(call, at: 0)
    }

    func toggleDone(_ call: CallItem) {
        guard let idx = calls.firstIndex(where: { $0.id == call.id }) else { return }
        calls[idx].status = (calls[idx].status == .open) ? .done : .open
        calls[idx].updatedAt = .now
    }

    func delete(_ call: CallItem) {
        let deletedIds = calls.filter { $0.id == call.id }.map(\.id)
        calls.removeAll { $0.id == call.id }
        // Cloud: gelöschte Calls auch serverseitig entfernen
        if canSync && !deletedIds.isEmpty {
            Task { await CallSyncService.shared.deleteCalls(ids: deletedIds) }
        }
    }

    func options(for call: CallItem, now: Date) -> [OptionRow] {
        let starts = profile.villagesAsStarts(fallback: Defaults.startVillages)

        let base = Calculator.calculateOptions(
            starts: starts,
            targetX: call.targetX,
            targetY: call.targetY,
            arrival: call.arrival,
            now: now
        )

        // Option A: Wenn ein Dorf keine Truppen gewählt hat, soll es keine Resultate liefern.
        return base.filter { row in
            profile.isTroopAllowed(forVillageName: row.start.name, troopRaw: row.troop.rawValue)
        }
    }

    private func deriveTitle(from text: String) -> String {
        // 1) Versuche Zeile mit Koordinaten: "Name (-4/3)" oder "Name (12|8)"
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            if line.contains("(") && (line.contains("/") || line.contains("|")) && line.contains(")") {
                // Nimm alles vor der Klammer als Name
                if let idx = line.firstIndex(of: "(") {
                    let name = String(line[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { return name }
                }
            }
        }

        // 2) Wenn es "für" gibt, nimm den Rest der Zeile
        for line in lines {
            let lower = line.lowercased()
            if let range = lower.range(of: "für") {
                let after = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !after.isEmpty { return after }
            }
        }

        return "Call"
    }

    private func loadCalls() {
        // 0) Backup state
        hasCallsBackup = UserDefaults.standard.data(forKey: callsCorruptBackupKey) != nil

        // 1) Neues Format (V2)
        if let data = UserDefaults.standard.data(forKey: callsKeyV2) {
            if let decoded = try? JSONDecoder().decode(CallsPayload.self, from: data) {
                self.calls = decoded.calls
                return
            } else {
                // kaputt: Backup sichern, V2 löschen, leer starten
                UserDefaults.standard.set(data, forKey: callsCorruptBackupKey)
                UserDefaults.standard.removeObject(forKey: callsKeyV2)
                self.calls = []
                self.hasCallsBackup = true
                self.errorText = "Calls konnten nicht geladen werden. Backup wurde gesichert."
                return
            }
        }

        // 2) Altes Format (V1) als Fallback
        if let data = UserDefaults.standard.data(forKey: callsKeyV1),
           let decoded = try? JSONDecoder().decode([CallItem].self, from: data) {
            self.calls = decoded
            return
        }
    }

    /// Verhindert debouncedSync bei internen Updates (z.B. transient data clearing)
    private var suppressSync = false

    private func saveCalls() {
        let payload = CallsPayload(version: 3, savedAt: .now, calls: calls)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: callsKeyV2)
        if !suppressSync { debouncedSync() }
    }

    func resetCalls() {
        calls = []
        UserDefaults.standard.removeObject(forKey: callsKeyV1)
        UserDefaults.standard.removeObject(forKey: callsKeyV2)
    }

    // MARK: - Cloud Sync

    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = {
        let ts = UserDefaults.standard.double(forKey: "lastCloudSyncTimestamp")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()
    @Published var syncError: String? = nil

    private var syncTask: Task<Void, Never>? = nil
    private var periodicSyncTimer: Timer?

    var canSync: Bool {
        AuthService.shared.isAuthenticated
    }

    /// Debounced: wartet 2s nach letzter Änderung, dann Push an Cloud.
    private func debouncedSync() {
        guard canSync else { return }
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await pushToCloud()
        }
    }

    /// Push lokale Calls in die Cloud.
    private func pushToCloud() async {
        guard canSync else { return }
        let success = await CallSyncService.shared.pushCalls(calls)
        if success {
            // Transiente Daten bereinigen ohne neuen Sync auszulösen
            suppressSync = true
            for i in calls.indices {
                calls[i].deletedPledgeIds = []
            }
            suppressSync = false

            lastSyncDate = .now
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastCloudSyncTimestamp")
            syncError = nil
        }
    }

    /// Vollständiger Sync: Push + Pull + Merge.
    func syncWithCloud() async {
        guard canSync, !isSyncing else { return }
        await MainActor.run { isSyncing = true; syncError = nil }

        // 1. Push lokale Calls
        let pushOk = await CallSyncService.shared.pushCalls(calls)

        if pushOk {
            // Transiente Daten bereinigen
            await MainActor.run {
                suppressSync = true
                for i in calls.indices { calls[i].deletedPledgeIds = [] }
                suppressSync = false
            }
        }

        // 2. Pull Cloud-Calls + Team-Calls + gelöschte IDs
        if let result = await CallSyncService.shared.pullCalls() {
            await MainActor.run {
                mergeCalls(from: result.calls, deletedIds: Set(result.deletedCallIds))
                teamCalls = result.teamCalls
                lastSyncDate = .now
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastCloudSyncTimestamp")
                syncError = nil
            }
        } else if !pushOk {
            await MainActor.run { syncError = "Sync fehlgeschlagen" }
        }

        await MainActor.run { isSyncing = false }
    }

    /// Stellt Calls aus der Cloud wieder her (ersetzt lokale Calls).
    func restoreFromCloud() async {
        guard canSync, !isSyncing else { return }
        await MainActor.run { isSyncing = true; syncError = nil }

        if let result = await CallSyncService.shared.pullCalls() {
            await MainActor.run {
                calls = result.calls
                teamCalls = result.teamCalls
                lastSyncDate = .now
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastCloudSyncTimestamp")
                syncError = nil
            }
        } else {
            await MainActor.run { syncError = "Wiederherstellen fehlgeschlagen" }
        }

        await MainActor.run { isSyncing = false }
    }

    // MARK: - Periodic Sync (Multi-Device)

    /// Startet einen Timer der alle 30s einen Pull macht (nur wenn App aktiv).
    func startPeriodicSync() {
        guard canSync else { return }
        stopPeriodicSync()
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.pullFromCloud() }
        }
    }

    /// Stoppt den periodischen Sync-Timer.
    func stopPeriodicSync() {
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
    }

    /// Leichtgewichtiger Pull-Only Sync (für periodischen Refresh).
    private func pullFromCloud() async {
        guard canSync, !isSyncing else { return }

        if let result = await CallSyncService.shared.pullCalls() {
            await MainActor.run {
                mergeCalls(from: result.calls, deletedIds: Set(result.deletedCallIds))
                teamCalls = result.teamCalls
                lastSyncDate = .now
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "lastCloudSyncTimestamp")
            }
        }
    }

    // MARK: - Team Pledges

    /// Sendet einen Pledge für einen Team-Call an den Server.
    func pushTeamPledge(callId: UUID, pledges: [TroopPledge], deletedPledgeIds: [UUID] = []) {
        guard canSync else { return }
        Task {
            let success = await CallSyncService.shared.pushTeamPledges(
                callId: callId,
                pledges: pledges,
                deletedPledgeIds: deletedPledgeIds
            )
            if success {
                // Pull um aktuellen Stand zu bekommen
                await pullFromCloud()
            }
        }
    }

    // MARK: - Merge Logic

    /// Merge: Cloud-Calls in lokale Liste integrieren.
    /// - Pledges werden additiv gemergt (Union by UUID)
    /// - Gelöschte Calls werden lokal entfernt
    /// - Discord-Message-ID Dedup verhindert Duplikate
    private func mergeCalls(from cloudCalls: [CallItem], deletedIds: Set<UUID> = []) {
        var localMap: [UUID: CallItem] = [:]
        for c in calls { localMap[c.id] = c }

        // Discord-Message-ID Map für Dedup
        var discordIdMap: [String: UUID] = [:]
        for c in calls {
            if let dmId = c.discordMessageId { discordIdMap[dmId] = c.id }
        }

        var merged: [CallItem] = []

        // 1. Lokale Calls verarbeiten
        for local in calls {
            // Auf einem anderen Gerät gelöscht?
            if deletedIds.contains(local.id) {
                continue
            }

            if let cloud = cloudCalls.first(where: { $0.id == local.id }) {
                // Beide vorhanden: Call-Felder per LWW, Pledges additiv mergen
                var winner = cloud.updatedAt > local.updatedAt ? cloud : local
                winner.pledges = mergePledges(local: local.pledges, cloud: cloud.pledges)
                // Transiente Daten vom lokalen Call behalten
                winner.deletedPledgeIds = local.deletedPledgeIds
                merged.append(winner)
            } else {
                // Nur lokal vorhanden: behalten
                merged.append(local)
            }
        }

        // 2. Cloud-Only Calls hinzufügen
        for cloud in cloudCalls {
            guard localMap[cloud.id] == nil else { continue }
            guard !deletedIds.contains(cloud.id) else { continue }

            // Discord-Message-ID Dedup: keinen Duplikat hinzufügen
            if let dmId = cloud.discordMessageId, discordIdMap[dmId] != nil {
                continue
            }

            merged.insert(cloud, at: 0)
        }

        calls = merged
    }

    /// Pledges additiv mergen: Union by UUID, Cloud gewinnt bei gleichem ID.
    private func mergePledges(local: [TroopPledge], cloud: [TroopPledge]) -> [TroopPledge] {
        var map: [UUID: TroopPledge] = [:]
        for p in local { map[p.id] = p }
        for p in cloud { map[p.id] = p }  // Cloud überschreibt bei gleicher ID
        return Array(map.values).sorted { $0.pledgedAt < $1.pledgedAt }
    }

    // MARK: - Backup

    func restoreCallsBackupIfAvailable() {
        guard let data = UserDefaults.standard.data(forKey: callsCorruptBackupKey) else { return }

        // Try V2 payload
        if let decoded = try? JSONDecoder().decode(CallsPayload.self, from: data) {
            calls = decoded.calls
            UserDefaults.standard.set(data, forKey: callsKeyV2)
            UserDefaults.standard.removeObject(forKey: callsCorruptBackupKey)
            hasCallsBackup = false
            errorText = nil
            return
        }

        // Try legacy V1 array
        if let decoded = try? JSONDecoder().decode([CallItem].self, from: data) {
            calls = decoded
            let payload = CallsPayload(version: 2, savedAt: .now, calls: decoded)
            if let newData = try? JSONEncoder().encode(payload) {
                UserDefaults.standard.set(newData, forKey: callsKeyV2)
            }
            UserDefaults.standard.removeObject(forKey: callsCorruptBackupKey)
            hasCallsBackup = false
            errorText = nil
        }
    }
}
