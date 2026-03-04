import SwiftUI

// MARK: - Calls Tab (Call Liste)

struct CallsTabView: View {

    @Environment(CallsStore.self) var store
    @Environment(AuthService.self) var authService

    @State private var path = NavigationPath()
    @State private var showParser = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !authService.isAuthenticated {
                    notLoggedInView
                } else if authService.profile?.isVerified != true {
                    VerificationRequiredView(feature: "Deff Calls")
                        .environment(authService)
                } else if store.isLoading && store.calls.isEmpty {
                    ProgressView("Lade Calls...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    callList
                }
            }
            .navigationTitle("Deff Calls")
            .toolbar {
                if canCreateCalls {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showParser = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton()
                }
            }
            .sheet(isPresented: $showParser) {
                ParserTabView()
                    .environment(store)
            }
            .navigationDestination(for: UUID.self) { id in
                if let call = store.calls.first(where: { $0.id == id }) {
                    let rowKey = store.pendingOpenRowKey
                    CallDetailView(call: call, initialExpandedRowKey: rowKey)
                        .environment(store)
                        .onAppear { store.pendingOpenRowKey = nil }
                } else {
                    Text("Call nicht gefunden")
                }
            }
            .navigationDestination(for: DefenseOverviewRoute.self) { route in
                if let call = store.calls.first(where: { $0.id == route.callId }) {
                    DefenseOverviewView(call: call)
                } else {
                    Text("Call nicht gefunden")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openCallNotificationName)) { _ in
                navigateToDeepLinkIfNeeded()
            }
            .task(id: authService.isAuthenticated) {
                guard authService.isAuthenticated else { return }

                // Warten bis Profil geladen ist (max ~5s)
                for _ in 0..<50 {
                    if authService.profile?.kingdomId != nil { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }

                await store.loadCalls()
                await store.loadAllPledges()

                // Realtime starten
                if let kingdomId = authService.profile?.kingdomId {
                    await store.subscribeToRealtime(kingdomId: kingdomId)
                    print("[CallsTab] Realtime gestartet fuer Kingdom \(kingdomId)")
                } else {
                    print("[CallsTab] Kein kingdomId — Realtime nicht gestartet")
                }

                // Deep link pruefen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToDeepLinkIfNeeded()
                }
            }
        }
    }

    // MARK: - Not Logged In

    private var notLoggedInView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Nicht angemeldet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Melde dich an, um Deff-Calls deines Kingdoms zu sehen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Call List

    private var callList: some View {
        List {
            if !openCalls.isEmpty {
                Section("Aktuell") {
                    ForEach(openCalls) { call in
                        let pledges = store.pledgesByCall[call.id] ?? []
                        NavigationLink(value: call.id) {
                            CallRow(call: call, pledges: pledges)
                        }
                        .id(rowIdentity(call: call, pledges: pledges))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if canDelete {
                                Button(role: .destructive) {
                                    Task { await store.deleteCall(call) }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if canModifyCalls {
                                Button {
                                    Task { await store.toggleDone(call) }
                                } label: {
                                    Label("Erledigt", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }

            if !doneCalls.isEmpty {
                Section("Vergangen") {
                    ForEach(doneCalls) { call in
                        let pledges = store.pledgesByCall[call.id] ?? []
                        NavigationLink(value: call.id) {
                            CallRow(call: call, pledges: pledges, isPast: true)
                        }
                        .id(rowIdentity(call: call, pledges: pledges))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if canDelete {
                                Button(role: .destructive) {
                                    Task { await store.deleteCall(call) }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if canModifyCalls {
                                Button {
                                    Task { await store.toggleDone(call) }
                                } label: {
                                    Label("Offen", systemImage: "arrow.uturn.left")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }

            if store.calls.isEmpty {
                emptyStateView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Keine Calls")
                .font(.title3)
                .fontWeight(.semibold)

            if authService.profile?.kingdomId == nil {
                Text("Du bist keinem Kingdom zugeordnet. Verifiziere deinen Travian-Account in den Einstellungen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if canCreateCalls {
                Text("Erstelle einen Call über den Parser oder den Manuell Tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Dein Kingdom hat noch keine aktiven Calls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Rollen-Checks

    /// Ab Herzog: Calls erstellen
    private var canCreateCalls: Bool {
        authService.currentRole.canManageCalls
    }

    /// Ab Herzog: Call-Status aendern
    private var canModifyCalls: Bool {
        authService.currentRole.canManageCalls
    }

    /// Ab Koenig: Calls loeschen
    private var canDelete: Bool {
        authService.currentRole.canAdminister
    }

    // MARK: - Helpers

    /// Eindeutige Row-ID die sich aendert wenn Call oder Pledges sich aendern.
    /// Erzwingt Re-Render der CallRow (inkl. Crop-Balken).
    private func rowIdentity(call: CallItem, pledges: [TroopPledge]) -> String {
        let pledgeHash = pledges.map { "\($0.id)-\($0.count)" }.joined(separator: ",")
        return "\(call.id)-\(call.status.rawValue)-\(pledgeHash)"
    }

    private func navigateToDeepLinkIfNeeded() {
        store.pullPendingDeepLinkFromDefaults()
        if let id = store.pendingOpenCallId {
            // Nur navigieren wenn der Call bereits geladen ist.
            // Falls Calls noch nicht vom Server geladen: pendingOpenCallId bleibt
            // gesetzt und .task ruft nach dem Laden erneut auf.
            guard store.calls.contains(where: { $0.id == id }) else { return }
            path.append(id)
            store.pendingOpenCallId = nil
        }
    }

    private var openCalls: [CallItem] {
        let now = Date.now
        return store.calls
            .filter { $0.status == .open && $0.arrival > now }
            .sorted { $0.arrival < $1.arrival }
    }

    private var doneCalls: [CallItem] {
        let now = Date.now
        return store.calls
            .filter { $0.isDone || $0.arrival <= now }
            .sorted { $0.arrival > $1.arrival }
    }
}

// MARK: - Call Row

struct CallRow: View {
    let call: CallItem
    var pledges: [TroopPledge] = []
    var isPast: Bool = false

    var body: some View {
        let now = Date.now
        let late = call.arrival <= now

        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isPast ? Color(.systemGray4) : (late ? Color.red : Color.green))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(call.title)
                    .font(.headline)
                    .foregroundStyle(isPast ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text("(\(call.targetX)|\(call.targetY))")

                    Text("\u{2022}")
                        .foregroundStyle(.secondary)

                    Text("Ankunft \(call.arrival.formatted(date: .omitted, time: .standard))")

                    Spacer(minLength: 0)

                    if !isPast {
                        Text(relativeLabel(now: now))
                            .foregroundStyle(late ? .red : .secondary)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                // Crop-Fortschrittsbalken (nur bei aktiven Calls mit Limit)
                if !isPast, let limit = call.cropLimit, limit > 0 {
                    let totalCrop = cropTotal
                    let ratio = min(1.0, Double(totalCrop) / Double(limit))
                    let over = totalCrop > limit
                    let barColor = cropBarColor(ratio: ratio, over: over)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(.systemGray5))
                                .frame(height: 5)

                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(barColor)
                                .frame(width: geo.size.width * ratio, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Getreide-Total: Hoeherer Wert aus lokaler Pledge-Berechnung oder DB-Aggregat.
    /// DB-Wert (cropPledgedTotal) wird auch durch manuelle Discord-Updates gesetzt,
    /// die keine Pledges in der DB erzeugen.
    private var cropTotal: Int {
        let fromPledges = pledges.compactMap { pledge -> Int? in
            guard let kind = TroopKind(rawValue: pledge.troopKind) else { return nil }
            return pledge.count * kind.cropPerHour
        }.reduce(0, +)
        return max(fromPledges, call.cropPledgedTotal)
    }

    /// Farbe nach Fuellgrad
    private func cropBarColor(ratio: Double, over: Bool) -> Color {
        if over        { return .green }
        if ratio > 0.9 { return .green }
        if ratio > 0.5 { return .orange }
        return .red
    }

    private func relativeLabel(now: Date) -> String {
        let diff = call.arrival.timeIntervalSince(now)
        let absSeconds = Int(abs(diff).rounded(.down))

        let d = absSeconds / 86400
        let h = (absSeconds % 86400) / 3600
        let m = (absSeconds % 3600) / 60

        let time: String
        if absSeconds < 60 {
            time = "jetzt"
            return time
        } else if absSeconds < 3600 {
            time = "\(m)min"
        } else if absSeconds < 86400 {
            time = m > 0 ? "\(h)h \(m)min" : "\(h)h"
        } else {
            time = h > 0 ? "\(d)T \(h)h" : "\(d)T"
        }

        return diff >= 0 ? "in \(time)" : "vor \(time)"
    }
}
