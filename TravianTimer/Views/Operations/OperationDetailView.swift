import SwiftUI

// MARK: - Operation Detail View

struct OperationDetailView: View {

    let operation: Operation

    @Environment(OperationPlanStore.self) var store
    @Environment(AuthService.self) var authService

    @State private var now = Date.now
    @State private var showAddAttack = false
    @State private var showEditSheet = false
    @State private var showShareSheet = false

    private var attacks: [PlannedAttack] {
        (store.attacksByOperation[operation.id] ?? [])
            .sorted { $0.departureAt < $1.departureAt }
    }

    private var currentUserId: UUID? {
        try? SupabaseManager.client.auth.currentSession?.user.id
    }

    private var isPlanner: Bool {
        guard let role = authService.profile?.role else { return false }
        return operation.createdBy == currentUserId
            || [UserRole.duke, .viceking, .king, .admin].contains(role)
    }

    private var myAttacks: [PlannedAttack] {
        attacks.filter { $0.assignedTo == currentUserId }
    }

    private var otherAttacks: [PlannedAttack] {
        attacks.filter { $0.assignedTo != currentUserId }
    }

    // Stats
    private var confirmedCount: Int { attacks.filter(\.confirmed).count }
    private var sentCount: Int { attacks.filter(\.sent).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                statsSection

                if !myAttacks.isEmpty {
                    attacksSection("Meine Angriffe", attacks: myAttacks, showAll: true)
                }

                if isPlanner || operation.visibility == .full {
                    if !otherAttacks.isEmpty {
                        attacksSection("Alle Angriffe", attacks: isPlanner ? attacks : otherAttacks, showAll: isPlanner)
                    }
                }

                if attacks.isEmpty {
                    emptyAttacksHint
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(operation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                if isPlanner {
                    Menu {
                        Button {
                            showAddAttack = true
                        } label: {
                            Label("Angriff hinzufügen", systemImage: "plus")
                        }

                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }

                        Divider()

                        if operation.status == .planning {
                            Button {
                                Task { await setStatus(.active) }
                            } label: {
                                Label("Aktivieren", systemImage: "scope")
                            }
                        }

                        if operation.status == .active {
                            Button {
                                Task { await setStatus(.completed) }
                            } label: {
                                Label("Abschliessen", systemImage: "checkmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddAttack) {
            AttackFormView(operation: operation) {
                Task { await store.loadAttacks(operationId: operation.id) }
            }
            .environment(store)
            .environment(authService)
        }
        .sheet(isPresented: $showEditSheet) {
            OperationFormView(mode: .edit(operation))
                .environment(store)
        }
        .sheet(isPresented: $showShareSheet) {
            OperationShareView(operation: operation)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = .now
        }
        .task {
            await store.loadAttacks(operationId: operation.id)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(operation.status.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                Text("\(Int(operation.worldSpeed))× Speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let code = operation.joinCode {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(code)
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.orange)
                }
            }

            if let desc = operation.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem("Angriffe", value: "\(attacks.count)", icon: "flame", color: .red)
            Divider().frame(height: 30)
            statItem("Bestätigt", value: "\(confirmedCount)/\(attacks.count)", icon: "checkmark.circle", color: .green)
            Divider().frame(height: 30)
            statItem("Gesendet", value: "\(sentCount)/\(attacks.count)", icon: "paperplane", color: .blue)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func statItem(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Attacks Section

    private func attacksSection(_ title: String, attacks: [PlannedAttack], showAll: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(attacks) { attack in
                AttackCountdownRow(
                    attack: attack,
                    isPlanner: isPlanner,
                    now: now,
                    onConfirm: { confirmed in
                        Task {
                            await store.updateConfirmation(
                                attackId: attack.id,
                                operationId: operation.id,
                                confirmed: confirmed
                            )
                        }
                    },
                    onSent: { sent in
                        Task {
                            await store.updateSent(
                                attackId: attack.id,
                                operationId: operation.id,
                                sent: sent
                            )
                        }
                    }
                )
                .contextMenu {
                    if isPlanner {
                        Button(role: .destructive) {
                            Task {
                                await store.deletePlannedAttack(attack.id, operationId: operation.id)
                            }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Empty

    private var emptyAttacksHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Noch keine Angriffe geplant")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isPlanner {
                Button {
                    showAddAttack = true
                } label: {
                    Label("Angriff hinzufügen", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch operation.status {
        case .planning:  return .orange
        case .active:    return .red
        case .completed: return .green
        case .cancelled: return .secondary
        }
    }

    private func setStatus(_ status: Operation.Status) async {
        var updated = operation
        updated.status = status
        await store.updateOperation(updated)
    }
}
