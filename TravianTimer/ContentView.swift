import SwiftUI

struct ContentView: View {

    enum SortMode: String, CaseIterable {
        case time = "Zeit"
        case speed = "Speed"
        case village = "Dorf"
    }

    @Environment(\.openURL) private var openURL

    @State private var inputText = ""
    @State private var results: [OptionRow] = []
    @State private var errorText: String?
    @State private var headerText: String?
    @State private var evaluatedAt: Date = .now

    @State private var showOnlyValid: Bool = false
    @State private var sortMode: SortMode = .time
    @State private var speedAscending: Bool = false

    @State private var showParserSheet: Bool = false
    @State private var parsedLink: URL? = nil

    @State private var expandedRowId: UUID? = nil
    @State private var toastText: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {

                HStack {
                    Button("Call") { showParserSheet = true }
                        .buttonStyle(.bordered)

                    Spacer()
                }

                HStack {
                    Toggle("Nur gültige", isOn: $showOnlyValid)
                        .toggleStyle(.switch)

                    Picker("", selection: $sortMode) {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if sortMode == .speed {
                    Toggle("Speed aufsteigend", isOn: $speedAscending)
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

                                    if row.isLate {
                                        let missed = evaluatedAt.timeIntervalSince(row.sendTime)
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
                                    Text(row.isLate ? "zu spät" : "ok")
                                        .foregroundStyle(row.isLate ? .red : .green)
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
                                .disabled(row.isLate)

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

    private var displayedResults: [OptionRow] {

        var filtered = results
        if showOnlyValid {
            filtered = filtered.filter { !$0.isLate }
        }

        switch sortMode {

        case .time:
            return filtered.sorted {

                if $0.isLate != $1.isLate {
                    return $0.isLate == false
                }

                if !$0.isLate && !$1.isLate {
                    return $0.sendTime < $1.sendTime
                }

                let missA = evaluatedAt.timeIntervalSince($0.sendTime)
                let missB = evaluatedAt.timeIntervalSince($1.sendTime)
                return missA < missB
            }

        case .speed:
            return filtered.sorted {
                speedAscending
                ? $0.troop.speed < $1.troop.speed
                : $0.troop.speed > $1.troop.speed
            }

        case .village:
            return filtered.sorted {
                $0.start.name < $1.start.name
            }
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
