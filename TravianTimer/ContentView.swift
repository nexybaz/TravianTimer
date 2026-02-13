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

    // Player profile (start villages + troop selection)
    @Published var profile = ProfileStore.shared

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
}

// MARK: - Player Profile (Local)

struct VillageProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var x: Int
    var y: Int

    // Option A: default leer. Nur ausgewählte Truppen werden berücksichtigt.
    var allowedTroops: [String] = []

    // Exact troop counts per troop key (TroopKind.rawValue). Filled by the troop overview import.
    // Presence filtering in the app still uses `allowedTroops`.
    var troopCounts: [String: Int] = [:]
}

final class ProfileStore: ObservableObject {

    static let shared = ProfileStore()

    @Published var villages: [VillageProfile] = [] {
        didSet { save() }
    }

    private let key = "profileVillagesV1"

    private init() {
        load()
    }

    func seedFromDefaultsIfEmpty() {
        guard villages.isEmpty else { return }
        villages = Defaults.startVillages.map { v in
            VillageProfile(name: v.name, x: v.x, y: v.y, allowedTroops: [], troopCounts: [:])
        }
    }

    func villagesAsStarts(fallback: [StartVillage]) -> [StartVillage] {
        if villages.isEmpty {
            return fallback
        }

        // StartVillage verlangt zusätzlich die Truppenliste.
        // Option A: Wenn keine Truppen gewählt sind, bleibt die Liste leer.
        return villages.map { vp in
            let troops: [TroopKind] = vp.allowedTroops.compactMap { stored in
                if let direct = TroopKind.allCases.first(where: { $0.rawValue == stored }) {
                    return direct
                }
                return TroopKind.migrateLegacyStoredName(stored)
            }
            return StartVillage(name: vp.name, x: vp.x, y: vp.y, troops: troops)
        }
    }

    func isTroopAllowed(forVillageName name: String, troopRaw: String) -> Bool {
        guard let v = villages.first(where: { $0.name == name }) else {
            // Wenn noch kein Profil gepflegt ist, lieber nichts verstecken.
            // Sobald Profil existiert, gilt Auswahl.
            return villages.isEmpty
        }
        return v.allowedTroops.contains(troopRaw)
    }

    func upsert(_ village: VillageProfile) {
        if let idx = villages.firstIndex(where: { $0.id == village.id }) {
            villages[idx] = village
        } else {
            villages.append(village)
        }
    }

    func delete(_ village: VillageProfile) {
        villages.removeAll { $0.id == village.id }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([VillageProfile].self, from: data) else { return }
        villages = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(villages) else { return }
        UserDefaults.standard.set(data, forKey: key)
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

                                Text("\(row.start.name)  \(row.troop.uiName)")
                                    .fontWeight(row.id == displayedResults.first?.id ? .bold : .regular)
                                    .foregroundStyle(.primary)

                                if isLate(row) {
                                    Text("Verpasst um \(formatHHMMSS(missedSeconds(row)))")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("Senden: \(row.sendTime.formatted(date: .omitted, time: .standard))")
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

    enum Tribe: String, CaseIterable, Identifiable {
        case romans = "Römer"
        case gauls = "Gallier"
        case teutons = "Germanen"

        var id: String { rawValue }
    }

    struct GameWorld: Identifiable, Hashable {
        var id: String { worldId }
        let worldId: String
        let speedTag: String // x1, x2, x3, x5
    }

    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""
    @AppStorage("selectedWorldSpeedTag") private var selectedWorldSpeedTag: String = ""
    @AppStorage("troopMultiplier") private var troopMultiplier: Double = 1.0

    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue

    @StateObject private var profile = ProfileStore.shared

    @State private var showAddVillage: Bool = false
    @State private var editVillage: VillageProfile? = nil

    @State private var worlds: [GameWorld] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            Form {

                Section("Profil") {
                    Picker("Volk", selection: $selectedTribeRaw) {
                        ForEach(Tribe.allCases) { t in
                            Text(t.rawValue).tag(t.rawValue)
                        }
                    }
                }

                Section("Spielwelt") {

                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Lade Spielwelten...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let loadError {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !worlds.isEmpty {
                        Picker("Welt", selection: $selectedWorldId) {
                            Text("Nicht gewählt").tag("")
                            ForEach(worlds) { w in
                                Text("\(w.worldId)").tag(w.worldId)
                            }
                        }

                        if !selectedWorldId.isEmpty {
                            Text("Truppengeschwindigkeit: \(multiplierLabel(from: selectedWorldSpeedTag))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Keine Welten geladen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Spielwelten aktualisieren") {
                        Task { await fetchWorlds() }
                    }
                }

                Section("Startdörfer") {

                    if profile.villages.isEmpty {
                        Button("Aus Defaults übernehmen") {
                            profile.seedFromDefaultsIfEmpty()
                        }
                        Text("Danach pro Dorf die Truppen auswählen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(profile.villages) { v in
                        Button {
                            editVillage = v
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name)
                                Text("(\(v.x)|\(v.y))  Truppen: \(v.allowedTroops.count)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idxSet in
                        for idx in idxSet {
                            let v = profile.villages[idx]
                            profile.delete(v)
                        }
                    }

                    Button {
                        showAddVillage = true
                    } label: {
                        Label("Dörfer importieren", systemImage: "text.badge.plus")
                    }

                    Text("Neue Dörfer starten ohne Truppen Auswahl.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if worlds.isEmpty {
                    await fetchWorlds()
                }
            }
            .onChange(of: selectedWorldId) { _, newValue in
                applySelectedWorld(newValue)
            }
            .sheet(isPresented: $showAddVillage) {
                VillageImportView(
                    onImport: { imported in
                        for v in imported {
                            profile.upsert(v)
                        }
                    }
                )
            }
            .sheet(item: $editVillage) { v in
                VillageEditorView(
                    modeTitle: "Dorf bearbeiten",
                    initial: v,
                    onSave: { profile.upsert($0) }
                )
            }
        }
    }

    private func applySelectedWorld(_ worldId: String) {
        guard let w = worlds.first(where: { $0.worldId == worldId }) else {
            selectedWorldSpeedTag = ""
            troopMultiplier = 1.0
            return
        }

        selectedWorldSpeedTag = w.speedTag
        troopMultiplier = multiplier(from: w.speedTag)
    }

    private func multiplier(from speedTag: String) -> Double {
        switch speedTag.lowercased() {
        case "x1": return 1.0
        case "x2": return 1.5
        case "x3": return 2.0
        case "x5": return 3.0
        default: return 1.0
        }
    }

    private func multiplierLabel(from speedTag: String) -> String {
        let m = multiplier(from: speedTag)
        if m == 1.0 { return "1.0×" }
        if m == 1.5 { return "1.5×" }
        if m == 2.0 { return "2.0×" }
        if m == 3.0 { return "3.0×" }
        return "1.0×" 
    }

    private func fetchWorlds() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://blog.kingdoms.com/de/game-world-calendar/") else {
            loadError = "Ungültige URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                loadError = "Konnte Daten nicht lesen"
                return
            }

            let parsed = parseWorldsFromHTML(html)
            worlds = parsed

            if !selectedWorldId.isEmpty, parsed.contains(where: { $0.worldId == selectedWorldId }) {
                applySelectedWorld(selectedWorldId)
            } else if selectedWorldId.isEmpty, let first = parsed.first {
                selectedWorldId = first.worldId
                applySelectedWorld(first.worldId)
            }
        } catch {
            loadError = "Fehler beim Laden"
        }
    }

    private func parseWorldsFromHTML(_ html: String) -> [GameWorld] {
        // Ziel: Nur echte Spielwelten aus der Tabelle ziehen.
        // Vorgehen: HTML grob in <tr> Zeilen splitten, dann pro Zeile Text aus <td> extrahieren.

        let lower = html.lowercased()

        // 1) Alle Tabellenzeilen holen
        let rowPattern = "<tr[^>]*>(.*?)</tr>"
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsLower = lower as NSString
        let rowMatches = rowRegex.matches(in: lower, options: [], range: NSRange(location: 0, length: nsLower.length))

        // 2) Helper: Tags entfernen
        func stripTags(_ s: String) -> String {
            let tagPattern = "<[^>]+>"
            guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) else { return s }
            let ns = s as NSString
            let range = NSRange(location: 0, length: ns.length)
            return tagRegex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: " ")
        }

        func normalizeText(_ s: String) -> String {
            stripTags(s)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 3) Weltcode sehr strikt validieren
        // Beispiele: de1, de1n, com1, com1x3, testx5
        // Wir lassen bewusst nur Buchstaben+Zahlen zu, optional ein trailing x2/x3/x5.
        let worldIdPattern = "^[a-z]{2,8}\\d+[a-z0-9]{0,8}(x2|x3|x5)?$"
        let worldIdRegex = try? NSRegularExpression(pattern: worldIdPattern, options: [])

        func isValidWorldId(_ s: String) -> Bool {
            guard let worldIdRegex else { return false }
            let candidate = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let ns = candidate as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard worldIdRegex.firstMatch(in: candidate, options: [], range: range) != nil else { return false }
            // harte Ausschlüsse
            if candidate.contains("window") || candidate.contains("profile") || candidate.contains("vill") { return false }
            if candidate.contains("http") || candidate.contains("/") || candidate.contains("#") || candidate.contains(".") { return false }
            return true
        }

        // 4) Pro Zeile: erste echte Welt in <td> nehmen, Speed aus derselben Zeile bestimmen
        var worlds: [GameWorld] = []
        var seen: Set<String> = []

        for rm in rowMatches {
            guard rm.numberOfRanges >= 2 else { continue }
            let rowHtml = nsLower.substring(with: rm.range(at: 1))

            // alle TDs in dieser Zeile
            let tdPattern = "<td[^>]*>(.*?)</td>"
            guard let tdRegex = try? NSRegularExpression(pattern: tdPattern, options: [.dotMatchesLineSeparators]) else { continue }
            let nsRow = rowHtml as NSString
            let tdMatches = tdRegex.matches(in: rowHtml, options: [], range: NSRange(location: 0, length: nsRow.length))
            if tdMatches.isEmpty { continue }

            var cells: [String] = []
            cells.reserveCapacity(tdMatches.count)
            for tm in tdMatches {
                guard tm.numberOfRanges >= 2 else { continue }
                let cellHtml = nsRow.substring(with: tm.range(at: 1))
                let txt = normalizeText(cellHtml)
                if !txt.isEmpty {
                    cells.append(txt)
                }
            }
            if cells.isEmpty { continue }

            // Weltcode ist praktisch immer in der ersten Spalte.
            // Falls nicht, nehmen wir die erste Zelle, die wie ein Weltcode aussieht.
            var worldId: String? = nil
            if isValidWorldId(cells[0]) {
                worldId = cells[0]
            } else {
                for c in cells {
                    let token = c.split(separator: " ").first.map(String.init) ?? c
                    if isValidWorldId(token) {
                        worldId = token
                        break
                    }
                }
            }
            guard let wid = worldId else { continue }
            if seen.contains(wid) { continue }

            // Speed Tag: Suche in der Zeile nach x1/x2/x3/x5.
            // Manche Tabellen haben Speed separat, manche im Namen.
            let rowText = cells.joined(separator: " ").lowercased()
            let speedTag: String
            if rowText.contains("x5") || wid.contains("x5") {
                speedTag = "x5"
            } else if rowText.contains("x3") || wid.contains("x3") {
                speedTag = "x3"
            } else if rowText.contains("x2") || wid.contains("x2") {
                speedTag = "x2"
            } else {
                speedTag = "x1"
            }

            seen.insert(wid)
            worlds.append(GameWorld(worldId: wid, speedTag: speedTag))
        }

        return worlds.sorted { $0.worldId < $1.worldId }
    }
}

// MARK: - Village Import

struct VillageImportView: View {

    let onImport: ([VillageProfile]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var input: String = ""
    @State private var parsed: [VillageProfile] = []
    @State private var errorText: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                Text("Text einfügen und Dörfer importieren")
                    .font(.headline)

                HStack {
                    Button {
                        if let clip = UIPasteboard.general.string {
                            input = clip
                        }
                    } label: {
                        Label("Einfügen", systemImage: "doc.on.clipboard")
                    }

                    Spacer()

                    Button {
                        parse()
                    } label: {
                        Label("Parsen", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextEditor(text: $input)
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !parsed.isEmpty {
                    List(parsed) { v in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name)
                            Text("(\(v.x)|\(v.y))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 180)
                } else {
                    Text("Keine Dörfer erkannt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schliessen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Importieren") {
                        onImport(parsed)
                        dismiss()
                    }
                    .disabled(parsed.isEmpty)
                }
            }
            .onAppear {
                // optional: auto paste if clipboard looks like villages
            }
        }
    }

    private func cleanVillageLine(_ raw: String) -> String {
        // Remove common Unicode format/control marks that appear when copying from chats.
        let formatMarks: Set<Unicode.Scalar> = [
            "\u{200E}", // LRM
            "\u{200F}", // RLM
            "\u{202A}", // LRE
            "\u{202B}", // RLE
            "\u{202C}", // PDF
            "\u{202D}", // LRO
            "\u{202E}", // RLO
            "\u{2066}", // LRI
            "\u{2067}", // RLI
            "\u{2068}", // FSI
            "\u{2069}"  // PDI
        ]

        let strippedScalars = raw.unicodeScalars.filter { !formatMarks.contains($0) }
        var s = String(String.UnicodeScalarView(strippedScalars))

        // Normalize whitespace
        s = s.replacingOccurrences(of: "\t", with: " ")
        s = s.replacingOccurrences(of: "\r", with: " ")

        // Collapse multiple spaces
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parse() {
        errorText = nil
        parsed = []

        // Some clipboard sources contain invisible Unicode “format” marks around brackets and digits.
        // We strip those so the regex can match reliably.
        let lines = input
            .components(separatedBy: .newlines)
            .map { cleanVillageLine($0) }
            .filter { !$0.isEmpty }

        // Accept formats:
        // 1) "1.0 Bowser Castle (-6|3) 894"
        // 2) "Bowser Castle (-6/3)"
        // 3) "Bowser Castle ( -6 | 3 )   1234"
        // Anything after the closing bracket is ignored (e.g. inhabitants).
        let pattern = "^\\s*(.+?)\\s*\\(\\s*([-+]?\\d+)\\s*[\\|/]\\s*([-+]?\\d+)\\s*\\)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            errorText = "Parser Fehler"
            return
        }

        var results: [VillageProfile] = []

        for line in lines {
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let m = regex.firstMatch(in: line, options: [], range: range) else { continue }
            guard m.numberOfRanges >= 4 else { continue }

            let name = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let xStr = ns.substring(with: m.range(at: 2))
            let yStr = ns.substring(with: m.range(at: 3))

            guard let x = Int(xStr), let y = Int(yStr) else { continue }
            if name.isEmpty { continue }

            results.append(VillageProfile(name: name, x: x, y: y, allowedTroops: [], troopCounts: [:]))
        }

        // De-duplicate by (x,y)
        var seen: Set<String> = []
        for v in results {
            let key = "\(v.x)|\(v.y)"
            if seen.contains(key) { continue }
            seen.insert(key)
            parsed.append(v)
        }

        if parsed.isEmpty {
            errorText = "Keine Zeilen mit Koordinaten gefunden.\nBeispiel: Bowser Castle (-6|3)"
        }
    }
}

// MARK: - Village Editor

struct VillageEditorView: View {

    let modeTitle: String
    let initial: VillageProfile
    let onSave: (VillageProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: VillageProfile

    @AppStorage("selectedTribe") private var selectedTribeRaw: String = SettingsView.Tribe.gauls.rawValue

    init(modeTitle: String, initial: VillageProfile, onSave: @escaping (VillageProfile) -> Void) {
        self.modeTitle = modeTitle
        self.initial = initial
        self.onSave = onSave
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dorf") {
                    TextField("Name", text: $draft.name)
                    Stepper(value: $draft.x, in: -400...400) {
                        HStack {
                            Text("X")
                            Spacer()
                            Text("\(draft.x)")
                        }
                    }
                    Stepper(value: $draft.y, in: -400...400) {
                        HStack {
                            Text("Y")
                            Spacer()
                            Text("\(draft.y)")
                        }
                    }
                }

                Section("Truppen") {
                    if allTroops.isEmpty {
                        Text("Keine Truppenliste gefunden.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(allTroops, id: \.rawValue) { troop in
                        Button {
                            toggleTroop(troop.rawValue)
                        } label: {
                            HStack {
                                Text(troop.uiName)
                                Spacer()
                                if draft.allowedTroops.contains(troop.rawValue) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Ohne Auswahl liefert das Dorf keine Optionen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        var final = draft
                        final.name = trimmed.isEmpty ? "Dorf" : trimmed
                        onSave(final)
                        dismiss()
                    }
                }
            }
        }
    }

    private var allTroops: [TroopKind] {
        TroopKind.troops(forSelectedTribeRaw: selectedTribeRaw)
    }

    private func toggleTroop(_ raw: String) {
        if let idx = draft.allowedTroops.firstIndex(of: raw) {
            draft.allowedTroops.remove(at: idx)
            draft.troopCounts.removeValue(forKey: raw)
        } else {
            draft.allowedTroops.append(raw)
            draft.allowedTroops.sort()
            // Count remains unknown unless imported; leave unset.
        }
    }
}
