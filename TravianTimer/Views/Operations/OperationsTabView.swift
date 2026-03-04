import SwiftUI

// MARK: - Einsatzplaner (Operations List)

struct OperationsTabView: View {

    @Environment(OperationPlanStore.self) var store
    @Environment(AuthService.self) var authService

    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    private var canCreate: Bool {
        guard let role = authService.profile?.role else { return false }
        return [UserRole.duke, .viceking, .king, .admin].contains(role)
    }

    private var currentUserId: UUID? {
        try? SupabaseManager.client.auth.currentSession?.user.id
    }

    // MARK: - Body

    var body: some View {
        Group {
            if !authService.isAuthenticated {
                notLoggedInView
            } else if authService.profile?.isVerified != true {
                VerificationRequiredView(feature: "Einsätze")
                    .environment(authService)
            } else if store.isLoading && store.operations.isEmpty {
                ProgressView("Lade Einsätze...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                operationList
            }
        }
        .navigationTitle("Einsatzplaner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canCreate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showJoinSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            OperationFormView(mode: .create)
                .environment(store)
        }
        .sheet(isPresented: $showJoinSheet) {
            OperationJoinView()
                .environment(store)
        }
        .task(id: authService.isAuthenticated) {
            guard authService.isAuthenticated else { return }

            for _ in 0..<50 {
                if authService.profile?.kingdomId != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }

            await store.loadOperations()

            if let kingdomId = authService.profile?.kingdomId {
                await store.subscribeToRealtime(kingdomId: kingdomId)
            }
        }
    }

    // MARK: - Operations List

    private var operationList: some View {
        List {
            let active = store.operations.filter { $0.status == .planning || $0.status == .active }
            let done = store.operations.filter { $0.isDone }

            if active.isEmpty && done.isEmpty {
                emptyState
            }

            if !active.isEmpty {
                Section("Aktive Einsätze") {
                    ForEach(active) { op in
                        operationRow(op)
                    }
                }
            }

            if !done.isEmpty {
                Section("Abgeschlossen") {
                    ForEach(done) { op in
                        operationRow(op)
                    }
                }
            }
        }
        .refreshable {
            await store.loadOperations()
        }
    }

    private func operationRow(_ op: Operation) -> some View {
        NavigationLink {
            OperationDetailView(operation: op)
                .environment(store)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: statusIcon(op.status))
                    .font(.title3)
                    .foregroundStyle(statusColor(op.status))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(op.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        let attacks = store.attacksByOperation[op.id] ?? []
                        Label("\(attacks.count)", systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(op.status.label)
                            .font(.caption)
                            .foregroundStyle(statusColor(op.status))

                        Text("\(Int(op.worldSpeed))×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canCreate || op.createdBy == currentUserId {
                Button(role: .destructive) {
                    Task { await store.deleteOperation(op.id) }
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusIcon(_ status: Operation.Status) -> String {
        switch status {
        case .planning:  return "pencil.circle.fill"
        case .active:    return "scope"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: Operation.Status) -> Color {
        switch status {
        case .planning:  return .orange
        case .active:    return .red
        case .completed: return .green
        case .cancelled: return .secondary
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scope")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Keine Einsätze")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(canCreate
                 ? "Erstelle einen neuen Einsatz mit + oben rechts."
                 : "Tritt einem Einsatz bei oder warte auf eine Zuweisung.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var notLoggedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Melde dich an, um Einsätze zu sehen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
