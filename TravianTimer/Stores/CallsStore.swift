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
            discordMessageId: discordMsgId
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
    }

    func delete(_ call: CallItem) {
        calls.removeAll { $0.id == call.id }
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

    private func saveCalls() {
        let payload = CallsPayload(version: 2, savedAt: .now, calls: calls)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: callsKeyV2)
    }

    func resetCalls() {
        calls = []
        UserDefaults.standard.removeObject(forKey: callsKeyV1)
        UserDefaults.standard.removeObject(forKey: callsKeyV2)
    }

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
