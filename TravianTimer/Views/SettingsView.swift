import SwiftUI

// MARK: - Settings Tab

struct SettingsView: View {

    @EnvironmentObject private var store: CallsStore

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

    @AppStorage("accountName") private var accountName: String = ""
    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""
    @AppStorage("selectedWorldSpeedTag") private var selectedWorldSpeedTag: String = ""
    @AppStorage("troopMultiplier") private var troopMultiplier: Double = 1.0

    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue

    @ObservedObject private var auth = AuthService.shared

    @StateObject private var profile = ProfileStore.shared

    @State private var showAddVillage: Bool = false
    @State private var editVillage: VillageProfile? = nil
    @State private var villagesExpanded: Bool = false

    @State private var worlds: [GameWorld] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var showConfirmResetVillages: Bool = false
    @State private var showConfirmResetCalls: Bool = false
    @State private var showTroopUpdate: Bool = false

    @State private var showConfirmRestore: Bool = false

    var body: some View {
        NavigationStack {
            Form {

                Section("Profil") {
                    HStack {
                        Text("Account")
                        Spacer()
                        TextField("Spielername", text: $accountName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }

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

                Section("Account") {
                    if auth.isAuthenticated {
                        HStack {
                            Text("E-Mail")
                            Spacer()
                            Text(auth.userEmail ?? "")
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if PushService.shared.isRegistered {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Push aktiv")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else if PushService.shared.storedToken == nil {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Push nicht verfügbar (Simulator)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text("Push nicht aktiv")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button("Abmelden", role: .destructive) {
                            auth.logout()
                        }
                    }
                }

                if !profile.villages.isEmpty {
                    Section("Startdörfer") {

                        // Gruppen-Header: tippbar zum Auf-/Zuklappen, swipebar zum Löschen
                        Button {
                            withAnimation { villagesExpanded.toggle() }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "building.2")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(accountName.isEmpty ? "Kein Account" : accountName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 6) {
                                        if !selectedWorldId.isEmpty {
                                            Text(selectedWorldId.uppercased())
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                        Text("\(profile.villages.count) Dörfer")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: villagesExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                showConfirmResetVillages = true
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }

                        if villagesExpanded {
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
                        }
                    }
                }

                Section {
                    Button {
                        showAddVillage = true
                    } label: {
                        Label("Dörfer importieren", systemImage: "text.badge.plus")
                    }

                    if !profile.villages.isEmpty {
                        Button {
                            showTroopUpdate = true
                        } label: {
                            Label("Truppen aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }

                    Text("Neue Dörfer starten ohne Truppen Auswahl.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Cloud") {
                    if store.canSync {
                        HStack {
                            Text("Letzter Sync")
                            Spacer()
                            if let date = store.lastSyncDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Nie")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task { await store.syncWithCloud() }
                        } label: {
                            HStack {
                                if store.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Jetzt synchronisieren")
                            }
                        }
                        .disabled(store.isSyncing)

                        Button("Aus Cloud wiederherstellen") {
                            showConfirmRestore = true
                        }
                        .foregroundStyle(.blue)

                        if let err = store.syncError {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Melde dich an, um Cloud-Sync zu aktivieren.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Daten") {
                    Button("Startdörfer zurücksetzen") {
                        showConfirmResetVillages = true
                    }
                    .foregroundStyle(.red)

                    Button("Calls zurücksetzen") {
                        showConfirmResetCalls = true
                    }
                    .foregroundStyle(.red)

                    if store.hasCallsBackup {
                        Button("Backup wiederherstellen") {
                            store.restoreCallsBackupIfAvailable()
                        }
                    }
                }

            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Startdörfer wirklich zurücksetzen?",
                   isPresented: $showConfirmResetVillages) {
                Button("Abbrechen", role: .cancel) {}
                Button("Zurücksetzen", role: .destructive) {
                    profile.resetVillages()
                }
            } message: {
                Text("Alle importierten Dörfer und Truppen-Auswahlen werden gelöscht.")
            }

            .alert("Calls wirklich zurücksetzen?",
                   isPresented: $showConfirmResetCalls) {
                Button("Abbrechen", role: .cancel) {}
                Button("Zurücksetzen", role: .destructive) {
                    store.resetCalls()
                }
            } message: {
                Text("Alle offenen und vergangenen Calls werden gelöscht.")
            }
            .alert("Aus Cloud wiederherstellen?",
                   isPresented: $showConfirmRestore) {
                Button("Abbrechen", role: .cancel) {}
                Button("Wiederherstellen") {
                    Task { await store.restoreFromCloud() }
                }
            } message: {
                Text("Lokale Calls werden durch die Cloud-Version ersetzt.")
            }
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
            .sheet(isPresented: $showTroopUpdate) {
                TroopUpdateView()
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
        if m == 1.0 { return "1.0\u{00D7}" }
        if m == 1.5 { return "1.5\u{00D7}" }
        if m == 2.0 { return "2.0\u{00D7}" }
        if m == 3.0 { return "3.0\u{00D7}" }
        return "1.0\u{00D7}"
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
