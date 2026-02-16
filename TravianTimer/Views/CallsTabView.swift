import SwiftUI

// MARK: - Calls Tab (Call Liste)

struct CallsTabView: View {

    @EnvironmentObject private var store: CallsStore
    @State private var path = NavigationPath()
    @State private var isReady = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !openCalls.isEmpty {
                    Section("Aktuell") {
                        ForEach(openCalls) { call in
                            NavigationLink(value: call.id) {
                                CallRow(call: call)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(call)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    store.toggleDone(call)
                                } label: {
                                    Label("Erledigt", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }

                if !doneCalls.isEmpty {
                    Section("Vergangen") {
                        ForEach(doneCalls) { call in
                            NavigationLink(value: call.id) {
                                CallRow(call: call)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(call)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    store.toggleDone(call)
                                } label: {
                                    Label("Offen", systemImage: "arrow.uturn.left")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }

                if store.calls.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "scope")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary.opacity(0.5))

                        Text("Keine Calls")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Erstelle einen Call über den Parser oder den Manuell Tab.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Travian Timer")
            .navigationDestination(for: UUID.self) { id in
                if let call = store.calls.first(where: { $0.id == id }) {
                    CallDetailView(call: call, initialExpandedRowKey: store.pendingOpenRowKey)
                        .environmentObject(store)
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
            .onAppear {
                if !isReady {
                    isReady = true
                    // Beim ersten Appear: deep link prüfen nach kurzer Verzögerung
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigateToDeepLinkIfNeeded()
                    }
                }
            }
        }
    }

    private func navigateToDeepLinkIfNeeded() {
        store.pullPendingDeepLinkFromDefaults()
        if let id = store.pendingOpenCallId {
            path.append(id)
        }
    }

    private var openCalls: [CallItem] {
        store.calls
            .filter { $0.status == .open }
            .sorted { $0.arrival < $1.arrival }
    }

    private var doneCalls: [CallItem] {
        store.calls
            .filter { $0.status == .done }
            .sorted { $0.arrival > $1.arrival }
    }
}

// MARK: - Call Row

struct CallRow: View {
    let call: CallItem

    var body: some View {
        let now = Date.now
        let late = call.arrival <= now

        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(late ? Color.red : Color.green)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(call.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("(\(call.targetX)|\(call.targetY))")

                    Text("\u{2022}")
                        .foregroundStyle(.secondary)

                    Text("Ankunft \(call.arrival.formatted(date: .omitted, time: .standard))")

                    Spacer(minLength: 0)

                    Text(relativeLabel(now: now))
                        .foregroundStyle(late ? .red : .secondary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                // Crop-Fortschrittsbalken (nur wenn Limit gesetzt)
                if let limit = call.cropLimit, limit > 0 {
                    let totalCrop = cropTotal
                    let ratio = min(1.0, Double(totalCrop) / Double(limit))
                    let over = totalCrop > limit
                    let barColor = cropBarColor(ratio: ratio, over: over)

                    HStack(spacing: 6) {
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

                        HStack(spacing: 2) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 8))
                            if totalCrop >= limit {
                                Text("voll")
                                    .font(.system(size: 10, weight: .semibold))
                            } else {
                                Text("\(totalCrop)/\(limit)")
                                    .font(.system(size: 10, weight: .medium))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(barColor)
                        .fixedSize()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Getreide-Total aller Pledges im Call
    private var cropTotal: Int {
        call.pledges.compactMap { pledge -> Int? in
            guard let kind = TroopKind(rawValue: pledge.troopKind) else { return nil }
            return pledge.count * kind.cropPerHour
        }.reduce(0, +)
    }

    /// Farbe nach Füllgrad: <50% grün, 50-90% orange, >90% / über Limit rot
    private func cropBarColor(ratio: Double, over: Bool) -> Color {
        if over       { return .red }
        if ratio > 0.9 { return .red }
        if ratio > 0.5 { return .orange }
        return .green
    }

    private func relativeLabel(now: Date) -> String {
        let diff = call.arrival.timeIntervalSince(now)
        let absSeconds = Int(abs(diff).rounded(.down))

        let h = absSeconds / 3600
        let m = (absSeconds % 3600) / 60

        let time = String(format: "%02d:%02d", h, m)
        return diff >= 0 ? "in \(time)" : "vor \(time)"
    }
}
