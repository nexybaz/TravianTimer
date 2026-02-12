import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CallsTabView()
                .tabItem {
                    Label("Calls", systemImage: "paperplane")
                }

            ManualTabView()
                .tabItem {
                    Label("Manuell", systemImage: "square.and.pencil")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Calls Tab

struct CallsTabView: View {

    enum TimeSort: String, CaseIterable {
        case early = "Früh"
        case late = "Spät"
    }

    @Environment(\.openURL) private var openURL

    @State private var inputText = ""
    @State private var results: [OptionRow] = []
    @State private var errorText: String?
    @State private var headerText: String?
    @State private var evaluatedAt: Date = .now

    @State private var timeSort: TimeSort = .early
    @State private var hideLate: Bool = false

    @State private var showParserSheet: Bool = false
    @State private var parsedLink: URL? = nil

    @State private var expandedRowId: UUID? = nil
    @State private var toastText: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {

                HStack(spacing: 10) {
                    Button("Deff Call Parser") { showParserSheet = true }
                        .buttonStyle(.borderedProminent)

                    Spacer()
                }

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

                if let headerText {
                    Text(headerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let toastText {
                    Text(toastText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                                        let missed = missedSeconds(row)
                                        Text("Verpasst um \(formatHHMMSS(missed))")
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
                                .disabled(parsedLink == nil)

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
            .padding(.horizontal)
            .navigationTitle("Travian Timer")
            .sheet(isPresented: $showParserSheet) {
                ParserView(
                    inputText: $inputText,
                    onPaste: pasteFromClipboard,
                    onEvaluate: evaluate
                )
            }
        }
    }

    private func openTargetLink() {
        guard let url = parsedLink else { return }
        openURL(url)
    }

    private func createReminder(for row: OptionRow) {
        Task {
            await NotificationManager.scheduleSendReminder(row: row, targetLink: parsedLink, leadMinutes: 3)
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

    private func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string {
            inputText = clip
        }
    }

    private func evaluate() {
        errorText = nil
        headerText = nil
        results = []
        parsedLink = nil
        expandedRowId = nil
        evaluatedAt = .now

        do {
            let parsed = try CallParser.parse(text: inputText, now: evaluatedAt)
            parsedLink = parsed.link

            headerText = "Ziel \(parsed.targetX)/\(parsed.targetY)  Ankunft \(parsed.arrival.formatted(date: .numeric, time: .standard))"

            results = Calculator.calculateOptions(
                starts: Defaults.startVillages,
                targetX: parsed.targetX,
                targetY: parsed.targetY,
                arrival: parsed.arrival,
                now: evaluatedAt
            )
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Fehler beim Parsen"
        }
    }

    private func isLate(_ row: OptionRow) -> Bool {
        row.sendTime <= evaluatedAt
    }

    private func missedSeconds(_ row: OptionRow) -> TimeInterval {
        max(0, evaluatedAt.timeIntervalSince(row.sendTime))
    }

    private var displayedResults: [OptionRow] {
        let filtered = hideLate
            ? results.filter { !isLate($0) }
            : results

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

// MARK: - Manual Tab

struct ManualTabView: View {

    enum TimeSort: String, CaseIterable {
        case early = "Früh"
        case late = "Spät"
    }

    @State private var x: Int = 0
    @State private var y: Int = 0
    @State private var arrival: Date = Date()

    @State private var results: [OptionRow] = []
    @State private var headerText: String?
    @State private var errorText: String?
    @State private var evaluatedAt: Date = .now

    @State private var timeSort: TimeSort = .early
    @State private var hideLate: Bool = false

    @State private var expandedRowId: UUID? = nil
    @State private var toastText: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {

                Form {
                    Section("Ziel") {
                        Stepper(value: $x, in: -400...400) {
                            HStack {
                                Text("X")
                                Spacer()
                                Text("\(x)")
                            }
                        }

                        Stepper(value: $y, in: -400...400) {
                            HStack {
                                Text("Y")
                                Spacer()
                                Text("\(y)")
                            }
                        }
                    }

                    Section("Ankunft") {
                        DatePicker("Zeit", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                    }

                    Section {
                        Button("Auswerten") {
                            applyManual()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxHeight: 340)

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

                if let headerText {
                    Text(headerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

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
                                        let missed = missedSeconds(row)
                                        Text("Verpasst um \(formatHHMMSS(missed))")
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
            .navigationTitle("Manuell")
        }
    }

    private func applyManual() {
        errorText = nil
        evaluatedAt = .now

        headerText = "Ziel \(x)/\(y)  Ankunft \(arrival.formatted(date: .numeric, time: .standard))"

        results = Calculator.calculateOptions(
            starts: Defaults.startVillages,
            targetX: x,
            targetY: y,
            arrival: arrival,
            now: evaluatedAt
        )

        showToast("Ausgewertet")
    }

    private func createReminder(for row: OptionRow) {
        Task {
            await NotificationManager.scheduleSendReminder(row: row, targetLink: nil, leadMinutes: 3)
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
        row.sendTime <= evaluatedAt
    }

    private func missedSeconds(_ row: OptionRow) -> TimeInterval {
        max(0, evaluatedAt.timeIntervalSince(row.sendTime))
    }

    private var displayedResults: [OptionRow] {
        let filtered = hideLate
            ? results.filter { !isLate($0) }
            : results

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

// MARK: - Settings Tab

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Einstellungen kommen als nächstes")
                    .font(.headline)

                Text("Hier landen später Truppen, Dörfer und UI Optionen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Schliessen") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
