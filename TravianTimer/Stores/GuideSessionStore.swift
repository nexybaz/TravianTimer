import Foundation
import Supabase
import Realtime

// MARK: - Guide Session Store

@MainActor
final class GuideSessionStore: ObservableObject {

    static let shared = GuideSessionStore()

    @Published var activeSession: GuideSession?
    @Published var members: [SessionMember] = []
    @Published var checkedStepIds: Set<String> = []

    private var client: SupabaseClient { SupabaseManager.client }
    private var progressChannel: RealtimeChannelV2?
    private var membersChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []

    var isInSession: Bool { activeSession != nil }

    private init() {}

    // MARK: - Session erstellen

    /// Erstellt eine neue Session und gibt den Join-Code zurueck.
    func createSession() async throws -> String {
        guard let userId = currentUserId() else {
            throw GuideSessionError.notAuthenticated
        }

        // Session anlegen (join_code wird via DB-Default generiert)
        let session: GuideSession = try await client
            .from("guide_sessions")
            .insert(["created_by": userId, "guide_type": "schnellsiedel"])
            .select()
            .single()
            .execute()
            .value

        // Creator als erstes Mitglied hinzufuegen
        try await client
            .from("guide_session_members")
            .insert(["session_id": session.id.uuidString, "user_id": userId])
            .execute()

        // State setzen
        activeSession = session
        await loadMembers()
        await loadProgress()
        await subscribeToRealtime(sessionId: session.id)

        print("[GuideSession] Session erstellt: \(session.joinCode)")
        return session.joinCode
    }

    // MARK: - Session beitreten

    func joinSession(code: String) async throws {
        guard let userId = currentUserId() else {
            throw GuideSessionError.notAuthenticated
        }

        // Session per Code finden
        let sessions: [GuideSession] = try await client
            .from("guide_sessions")
            .select()
            .eq("join_code", value: code.uppercased())
            .execute()
            .value

        guard let session = sessions.first else {
            throw GuideSessionError.sessionNotFound
        }

        // Beitreten (Trigger prueft max 3)
        do {
            try await client
                .from("guide_session_members")
                .insert(["session_id": session.id.uuidString, "user_id": userId])
                .execute()
        } catch {
            throw GuideSessionError.sessionFull
        }

        activeSession = session
        await loadMembers()
        await loadProgress()
        await subscribeToRealtime(sessionId: session.id)

        print("[GuideSession] Session beigetreten: \(session.joinCode)")
    }

    // MARK: - Session verlassen

    func leaveSession() async throws {
        guard let session = activeSession,
              let userId = currentUserId() else { return }

        await unsubscribeFromRealtime()

        // Sich selbst entfernen
        try await client
            .from("guide_session_members")
            .delete()
            .eq("session_id", value: session.id.uuidString)
            .eq("user_id", value: userId)
            .execute()

        // Wenn Creator verlässt und niemand mehr da ist: Session loeschen
        if session.createdBy.uuidString == userId {
            let remaining: [SessionMemberRow] = try await client
                .from("guide_session_members")
                .select("user_id")
                .eq("session_id", value: session.id.uuidString)
                .execute()
                .value

            if remaining.isEmpty {
                try? await client
                    .from("guide_sessions")
                    .delete()
                    .eq("id", value: session.id.uuidString)
                    .execute()
                print("[GuideSession] Leere Session gelöscht")
            }
        }

        activeSession = nil
        members = []
        checkedStepIds = []

        print("[GuideSession] Session verlassen")
    }

    // MARK: - Fortschritt

    func toggleStep(_ stepId: String) async {
        guard let sessionId = activeSession?.id,
              let userId = currentUserId() else { return }

        if checkedStepIds.contains(stepId) {
            // Optimistisch entfernen
            checkedStepIds.remove(stepId)
            do {
                try await client
                    .from("guide_session_progress")
                    .delete()
                    .eq("session_id", value: sessionId.uuidString)
                    .eq("step_id", value: stepId)
                    .execute()
            } catch {
                // Rollback
                checkedStepIds.insert(stepId)
                print("[GuideSession] Uncheck fehlgeschlagen: \(error.localizedDescription)")
            }
        } else {
            // Optimistisch einfuegen
            checkedStepIds.insert(stepId)
            do {
                try await client
                    .from("guide_session_progress")
                    .insert([
                        "session_id": sessionId.uuidString,
                        "step_id": stepId,
                        "checked_by": userId
                    ])
                    .execute()
            } catch {
                // Rollback
                checkedStepIds.remove(stepId)
                print("[GuideSession] Check fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Bestehende Session laden (nach App-Start / Login)

    /// Prüft ob der User bereits in einer Session ist und laedt diese.
    func loadExistingSession() async {
        guard let userId = currentUserId() else { return }

        do {
            let memberships: [MembershipRow] = try await client
                .from("guide_session_members")
                .select("session_id")
                .eq("user_id", value: userId)
                .execute()
                .value

            guard let membership = memberships.first else { return }

            let session: GuideSession = try await client
                .from("guide_sessions")
                .select()
                .eq("id", value: membership.sessionId.uuidString)
                .single()
                .execute()
                .value

            activeSession = session
            await loadMembers()
            await loadProgress()
            await subscribeToRealtime(sessionId: session.id)

            print("[GuideSession] Bestehende Session geladen: \(session.joinCode)")
        } catch {
            print("[GuideSession] Keine bestehende Session: \(error.localizedDescription)")
        }
    }

    // MARK: - Daten laden

    private func loadProgress() async {
        guard let sessionId = activeSession?.id else { return }

        do {
            let rows: [ProgressRow] = try await client
                .from("guide_session_progress")
                .select("step_id")
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value

            checkedStepIds = Set(rows.map(\.stepId))
        } catch {
            print("[GuideSession] Progress laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func loadMembers() async {
        guard let sessionId = activeSession?.id else { return }

        do {
            let rows: [SessionMember] = try await client
                .from("guide_session_members")
                .select("session_id, user_id, joined_at, profiles(player_name)")
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value

            members = rows
        } catch {
            print("[GuideSession] Mitglieder laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Realtime

    func subscribeToRealtime(sessionId: UUID) async {
        await unsubscribeFromRealtime()

        let progressCh = client.realtimeV2.channel("guide-progress-\(sessionId.uuidString.prefix(8))")
        self.progressChannel = progressCh

        let membersCh = client.realtimeV2.channel("guide-members-\(sessionId.uuidString.prefix(8))")
        self.membersChannel = membersCh

        // Progress INSERT
        let insertTask = Task { [weak self] in
            for await insertion in progressCh.postgresChange(InsertAction.self, schema: "public", table: "guide_session_progress") {
                guard let self else { return }
                if let row = try? insertion.decodeRecord(as: ProgressRow.self, decoder: JSONDecoder()) {
                    self.checkedStepIds.insert(row.stepId)
                }
            }
        }

        // Progress DELETE
        let deleteTask = Task { [weak self] in
            for await deletion in progressCh.postgresChange(DeleteAction.self, schema: "public", table: "guide_session_progress") {
                guard let self else { return }
                if let old = try? deletion.decodeOldRecord(as: ProgressRow.self, decoder: JSONDecoder()) {
                    self.checkedStepIds.remove(old.stepId)
                }
            }
        }

        // Members INSERT/DELETE → Mitglieder-Liste neu laden
        let memberInsertTask = Task { [weak self] in
            for await _ in membersCh.postgresChange(InsertAction.self, schema: "public", table: "guide_session_members") {
                guard let self else { return }
                await self.loadMembers()
            }
        }

        let memberDeleteTask = Task { [weak self] in
            for await _ in membersCh.postgresChange(DeleteAction.self, schema: "public", table: "guide_session_members") {
                guard let self else { return }
                await self.loadMembers()
            }
        }

        realtimeTasks = [insertTask, deleteTask, memberInsertTask, memberDeleteTask]

        do {
            try await progressCh.subscribeWithError()
            try await membersCh.subscribeWithError()
            print("[GuideSession] Realtime subscribed ✅")
        } catch {
            print("[GuideSession] Realtime subscribe Fehler: \(error.localizedDescription)")
        }
    }

    func unsubscribeFromRealtime() async {
        for task in realtimeTasks { task.cancel() }
        realtimeTasks = []

        await progressChannel?.unsubscribe()
        await membersChannel?.unsubscribe()
        progressChannel = nil
        membersChannel = nil
    }

    // MARK: - Logout

    func handleLogout() {
        Task {
            await unsubscribeFromRealtime()
        }
        activeSession = nil
        members = []
        checkedStepIds = []
    }

    // MARK: - Helpers

    private func currentUserId() -> String? {
        guard let session = try? client.auth.currentSession else { return nil }
        return session.user.id.uuidString
    }
}

// MARK: - Errors

enum GuideSessionError: LocalizedError {
    case notAuthenticated
    case sessionNotFound
    case sessionFull

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Nicht eingeloggt"
        case .sessionNotFound:  return "Session nicht gefunden"
        case .sessionFull:      return "Session ist voll (max. 3 Spieler)"
        }
    }
}

// MARK: - Models

struct GuideSession: Codable, Identifiable {
    let id: UUID
    let joinCode: String
    let guideType: String
    let createdBy: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case joinCode   = "join_code"
        case guideType  = "guide_type"
        case createdBy  = "created_by"
        case createdAt  = "created_at"
    }
}

struct SessionMember: Codable, Identifiable {
    let sessionId: UUID
    let userId: UUID
    let joinedAt: Date?
    let profiles: ProfileName?

    var id: UUID { userId }

    var playerName: String {
        profiles?.playerName ?? "Spieler"
    }

    struct ProfileName: Codable {
        let playerName: String

        enum CodingKeys: String, CodingKey {
            case playerName = "player_name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId    = "user_id"
        case joinedAt  = "joined_at"
        case profiles
    }
}

private struct ProgressRow: Codable {
    let stepId: String

    enum CodingKeys: String, CodingKey {
        case stepId = "step_id"
    }
}

private struct MembershipRow: Codable {
    let sessionId: UUID

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

private struct SessionMemberRow: Codable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}
