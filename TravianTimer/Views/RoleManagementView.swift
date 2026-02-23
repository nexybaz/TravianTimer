import SwiftUI
import Supabase

// MARK: - Mitglieder-Verwaltung (ab Herzog)
// Rollen-Picker: nur Koenig + Admin
// Funktions-Toggles: ab Herzog

struct RoleManagementView: View {

    @EnvironmentObject private var authService: AuthService

    @State private var members: [KingdomMember] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var isEditing: Bool = false

    private var client: SupabaseClient { SupabaseManager.client }

    /// Nur Koenig/Admin duerfen Rollen aendern
    private var canChangeRoles: Bool {
        authService.currentRole.canAdminister
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Lade Mitglieder...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if members.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Keine Mitglieder gefunden")
                        .font(.headline)
                    Text("Es gibt noch keine verifizierten Spieler in deinem Kingdom.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(members) { member in
                    MemberRow(
                        member: member,
                        isSelf: member.id == authService.currentUserId,
                        canChangeRoles: canChangeRoles,
                        isEditing: isEditing,
                        onRoleChange: { newRole in
                            Task { await changeRole(member: member, to: newRole) }
                        },
                        onFunctionToggle: { function in
                            Task { await toggleFunction(member: member, function: function) }
                        }
                    )
                }
            }
        }
        .navigationTitle("Mitglieder verwalten")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMembers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Fertig" : "Bearbeiten") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                    }
                }
                .fontWeight(.medium)
            }
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Load Members

    private func loadMembers() async {
        guard let kingdomId = authService.profile?.kingdomId else {
            isLoading = false
            return
        }

        do {
            let result: [KingdomMember] = try await client
                .from("profiles")
                .select("id, player_name, tribe, role, functions")
                .eq("kingdom_id", value: kingdomId)
                .order("role", ascending: true)
                .execute()
                .value

            members = result
        } catch {
            print("[RoleManagement] loadMembers Fehler: \(error.localizedDescription)")
            errorMessage = "Mitglieder konnten nicht geladen werden."
        }

        isLoading = false
    }

    // MARK: - Change Role

    private func changeRole(member: KingdomMember, to newRole: UserRole) async {
        do {
            try await client
                .from("profiles")
                .update(["role": newRole.rawValue])
                .eq("id", value: member.id.uuidString)
                .execute()

            // Lokal updaten
            if let idx = members.firstIndex(where: { $0.id == member.id }) {
                members[idx].role = newRole
            }
        } catch {
            print("[RoleManagement] changeRole Fehler: \(error.localizedDescription)")
            errorMessage = "Rolle konnte nicht geaendert werden."
        }
    }

    // MARK: - Toggle Function

    private func toggleFunction(member: KingdomMember, function: PlayerFunction) async {
        guard let idx = members.firstIndex(where: { $0.id == member.id }) else { return }

        var updated = members[idx].functions
        if updated.contains(function) {
            updated.removeAll { $0 == function }
        } else {
            updated.append(function)
        }

        // DB-Update: TEXT[] als Array von Strings
        let rawValues = updated.map { $0.rawValue }

        do {
            try await client
                .from("profiles")
                .update(["functions": rawValues])
                .eq("id", value: member.id.uuidString)
                .execute()

            members[idx].functions = updated
        } catch {
            print("[RoleManagement] toggleFunction Fehler: \(error.localizedDescription)")
            errorMessage = "Funktion konnte nicht geaendert werden."
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: KingdomMember
    let isSelf: Bool
    let canChangeRoles: Bool
    let isEditing: Bool
    let onRoleChange: (UserRole) -> Void
    let onFunctionToggle: (PlayerFunction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Kopfzeile: Name + Rolle ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.playerName)
                            .font(.headline)

                        if isSelf {
                            Text("Du")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        if let tribe = member.tribe {
                            Text(tribe)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(member.role.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(roleColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Rollen-Picker (nur im Edit-Modus, Koenig/Admin, nicht sich selbst)
                if isEditing && canChangeRoles && !isSelf {
                    Picker("", selection: Binding(
                        get: { member.role },
                        set: { newRole in onRoleChange(newRole) }
                    )) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            // ── Funktionen ──
            if isEditing {
                // Edit-Modus: antippbare Icons
                HStack(spacing: 10) {
                    ForEach(PlayerFunction.allCases) { fn in
                        let isActive = member.functions.contains(fn)

                        Button {
                            onFunctionToggle(fn)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: fn.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(isActive ? .white : fn.color)
                                    .frame(width: 32, height: 32)
                                    .background(isActive ? fn.color : fn.color.opacity(0.1))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(fn.color.opacity(0.3), lineWidth: isActive ? 0 : 1.5)
                                    )

                                Text(fn.displayName)
                                    .font(.caption2)
                                    .fontWeight(isActive ? .semibold : .regular)
                                    .foregroundStyle(isActive ? fn.color : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            } else if !member.functions.isEmpty {
                // Anzeige-Modus: nur aktive Funktionen als Badges
                HStack(spacing: 6) {
                    ForEach(member.functions) { fn in
                        Label(fn.displayName, systemImage: fn.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(fn.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var roleColor: Color {
        switch member.role {
        case .governor: return .gray
        case .duke:     return .blue
        case .viceking: return .indigo
        case .king:     return .orange
        case .admin:    return .red
        }
    }
}

// MARK: - Kingdom Member Model

struct KingdomMember: Identifiable, Codable {
    let id: UUID
    var playerName: String
    var tribe: String?
    var role: UserRole
    var functions: [PlayerFunction]

    enum CodingKeys: String, CodingKey {
        case id
        case playerName = "player_name"
        case tribe
        case role
        case functions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id         = try container.decode(UUID.self, forKey: .id)
        playerName = try container.decode(String.self, forKey: .playerName)
        tribe      = try container.decodeIfPresent(String.self, forKey: .tribe)
        role       = try container.decode(UserRole.self, forKey: .role)
        functions  = (try? container.decode([PlayerFunction].self, forKey: .functions)) ?? []
    }
}
