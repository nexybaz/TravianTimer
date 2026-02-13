import SwiftUI
import UIKit
import Combine

struct ContentView: View {

    enum AppTab: Hashable {
        case calls
        case parser
        case manuell
        case settings
    }

    @StateObject private var callsStore = CallsStore()
    @State private var selection: AppTab = .calls

    var body: some View {
        TabView(selection: $selection) {

            CallsTabView()
                .environmentObject(callsStore)
                .tabItem {
                    Label("Calls", systemImage: "list.bullet")
                }
                .tag(AppTab.calls)

            ParserTabView(selection: $selection)
                .environmentObject(callsStore)
                .tabItem {
                    Label("Parser", systemImage: "paperplane")
                }
                .tag(AppTab.parser)

            ManualTabView(selection: $selection)
                .environmentObject(callsStore)
                .tabItem {
                    Label("Manuell", systemImage: "square.and.pencil")
                }
                .tag(AppTab.manuell)

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Call Model

struct CallItem: Identifiable, Hashable {

    enum Status: String, Codable {
        case open
        case done
    }

    var id: UUID = UUID()
    var title: String
    var targetX: Int
    var targetY: Int
    var arrival: Date
    var link: URL?
    var status: Status = .open
    var createdAt: Date = .now
}

// MARK: - Shared Store

final class CallsStore: ObservableObject {

    // Parser input
    @Published var inputText: String = ""

    // Call list
    @Published var calls: [CallItem] = []

    // UI errors
    @Published var errorText: String? = nil

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
                createdAt: .now
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
        Calculator.calculateOptions(
            starts: Defaults.startVillages,
            targetX: call.targetX,
            targetY: call.targetY,
            arrival: call.arrival,
            now: now
        )
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
}

// MARK: - Calls Tab (Call Liste)

struct CallsTabView: View {

    @EnvironmentObject private var store: CallsStore

    var body: some View {
        NavigationStack {
            List {
                if !openCalls.isEmpty {
                    Section("Aktuell") {
                        ForEach(openCalls) { call in
                            NavigationLink {
                                CallDetailView(call: call)
                                    .environmentObject(store)
                            } label: {
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
                            NavigationLink {
                                CallDetailView(call: call)
                                    .environmentObject(store)
                            } label: {
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
                    VStack(spacing: 8) {
                        Text("Keine Calls")
                            .font(.headline)
                        Text("Erstelle einen Call über Parser oder Manuell.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Travian Timer")
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

struct CallRow: View {
    let call: CallItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(call.title)
                .font(.headline)

            Text("(\(call.targetX)|\(call.targetY))  Ankunft \(call.arrival.formatted(date: .omitted, time: .standard))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Call Detail (Optionen)

struct CallDetailView: View {

    enum TimeSort: String, CaseIterable {
        case early = "Früh"
        case late = "Spät"
    }

    @EnvironmentObject private var store: CallsStore
    @Environment(\.openURL) private var openURL

    let call: CallItem

    @State private var timeSort: TimeSort = .early
    @State private var hideLate: Bool = false
    @State private var expandedRowId: UUID? = nil
    @State private var toastText: String? = nil

    @State private var now: Date = .now

    var body: some View {
        VStack(spacing: 10) {

            HStack {
                Picker("", selection: $timeSort) {
                    ForEach(TimeSort.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Zu spät ausblenden", isOn: $hideLate)
                    .toggleStyle(.switch)

                Spacer()
            }
            .padding(.horizontal)

            Text("Ziel \(call.title)  (\(call.targetX)|\(call.targetY))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Text("Ankunft \(call.arrival.formatted(date: .numeric, time: .standard))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let toastText {
                Text(toastText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            List(displayedResults) { row in
                VStack(spacing: 8) {

                    Button {
                        withAnimation {
                            expandedRowId = (expandedRowId == row.id) ? nil : row.id
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {

                                Text("\(row.start.name)  \(row.troop.rawValue)")
                                    .fontWeight(row.id == displayedResults.first?.id ? .bold : .regular)
                                    .foregroundStyle(.primary)

                                if isLate(row) {
                                    Text("Verpasst um \(formatHHMMSS(missedSeconds(row)))")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("Senden: \(row.sendTime.formatted(date: .omitted, time: .standard))  Speed \(Int(row.troop.speed))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(isLate(row) ? "zu spät" : "ok")
                                    .foregroundStyle(isLate(row) ? .red : .green)
                                    .font(.caption)

                                Image(systemName: expandedRowId == row.id ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if expandedRowId == row.id {
                        HStack(spacing: 10) {

                            Button {
                                openTargetLink()
                            } label: {
                                Label("Ziel öffnen", systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                            .disabled(call.link == nil)

                            Button {
                                createReminder(for: row)
                            } label: {
                                Label("Erinnerung", systemImage: "bell")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLate(row))

                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Call")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            now = .now
        }
    }

    private func openTargetLink() {
        guard let url = call.link else { return }
        openURL(url)
    }

    private func createReminder(for row: OptionRow) {
        Task {
            await NotificationManager.scheduleSendReminder(row: row, targetLink: call.link, leadMinutes: 3)
            showToast("Erinnerung gesetzt")
        }
    }

    private func showToast(_ text: String) {
        toastText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if toastText == text {
                toastText = nil
            }
        }
    }

    private func isLate(_ row: OptionRow) -> Bool {
        row.sendTime <= now
    }

    private func missedSeconds(_ row: OptionRow) -> TimeInterval {
        max(0, now.timeIntervalSince(row.sendTime))
    }

    private var displayedResults: [OptionRow] {
        let base = store.options(for: call, now: now)
        let filtered = hideLate ? base.filter { !isLate($0) } : base
        let ascending = (timeSort == .early)

        return filtered.sorted {
            if isLate($0) != isLate($1) {
                return isLate($0) == false
            }

            if !isLate($0) && !isLate($1) {
                return ascending ? ($0.sendTime < $1.sendTime) : ($0.sendTime > $1.sendTime)
            }

            let missA = missedSeconds($0)
            let missB = missedSeconds($1)
            return ascending ? (missA < missB) : (missA > missB)
        }
    }

    private func formatHHMMSS(_ secondsRaw: TimeInterval) -> String {
        let total = max(0, Int(secondsRaw.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Parser Tab

struct ParserTabView: View {

    @EnvironmentObject private var store: CallsStore
    @Binding var selection: ContentView.AppTab

    var body: some View {
        ParserView(
            inputText: $store.inputText,
            onPaste: { store.pasteFromClipboard() },
            onEvaluate: {
                store.createCallFromParser()
                selection = .calls
            }
        )
    }
}

// MARK: - Manual Tab

struct ManualTabView: View {

    @EnvironmentObject private var store: CallsStore
    @Binding var selection: ContentView.AppTab

    @State private var titleText: String = ""
    @State private var xText: String = "0"
    @State private var yText: String = "0"
    @State private var arrival: Date = .now
    @State private var urlText: String = ""

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case x
        case y
        case url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Call") {
                    TextField("Dorfname", text: $titleText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .title)
                }

                Section("Ziel") {
                    TextField("X", text: $xText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .x)

                    TextField("Y", text: $yText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .y)
                }

                Section("Ankunft") {
                    DatePicker("Zeit", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Link") {
                    TextField("Optional: Travian Link", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .url)

                    Text("Wenn du einen Link einfügst, kannst du ihn später im Call öffnen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let err = store.errorText {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Erstellen") {
                        focusedField = nil

                        let x = parseInt(xText)
                        let y = parseInt(yText)

                        store.createCallManual(
                            title: titleText,
                            targetX: x,
                            targetY: y,
                            arrival: arrival,
                            linkString: urlText
                        )

                        selection = .calls
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Manuell")
        }
    }

    private func parseInt(_ text: String) -> Int {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "|", with: "")
        return Int(cleaned) ?? 0
    }
}

// MARK: - Settings Tab

struct SettingsView: View {

    @AppStorage("speedMultiplier") private var speedMultiplier: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Geschwindigkeit") {
                    Picker("Welt", selection: $speedMultiplier) {
                        Text("1x").tag(1)
                        Text("2x").tag(2)
                        Text("3x").tag(3)
                    }
                    .pickerStyle(.segmented)

                    Text("Wirkt auf alle Truppen und alle Berechnungen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
