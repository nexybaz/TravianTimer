import SwiftUI

// MARK: - Schnellsiedel Guide

struct SchnellsiedelGuideView: View {

    @AppStorage("guide_schnellsiedel_checked") private var checkedData: Data = Data()
    @Bindable private var sessionStore = GuideSessionStore.shared
    @State private var showResetConfirm = false
    @State private var ongoingExpanded = false
    @State private var showJoinSheet = false
    @State private var joinCode = ""
    @State private var sessionError: String?
    @State private var isCreatingSession = false
    @State private var isJoiningSession = false

    /// IDs aller abgehakten Eintraege (lokal, fuer Solo-Modus)
    private var localCheckedIds: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: checkedData)) ?? []
    }

    /// Aktive checked-IDs: Session oder lokal
    private var checkedIds: Set<String> {
        sessionStore.isInSession ? sessionStore.checkedStepIds : localCheckedIds
    }

    var body: some View {
        List {

            // MARK: Session Banner

            Section {
                if sessionStore.isInSession {
                    activeSessionBanner
                } else {
                    soloModeBanner
                }
            }

            // MARK: Einleitung

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dieser Guide ist darauf ausgerichtet, dass das Startdorf nach dem Schnellsiedeln vollständig abgerissen werden kann. Es werden keine Rohstofffelder gebaut.")
                        .font(.subheadline)

                    HStack(spacing: 8) {
                        Image(systemName: "eurosign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("Benötigt Travian Plus und ca. 200 Gold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Stand: 13.11.2025 (nach Menhir-Änderungen)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Einleitung", systemImage: "info.circle.fill")
            }

            // MARK: Laufende Aufgaben

            Section {
                DisclosureGroup(isExpanded: $ongoingExpanded) {
                    ForEach(OngoingTask.allCases) { task in
                        CheckableRow(
                            id: task.id,
                            isChecked: checkedIds.contains(task.id),
                            onToggle: { toggleCheck(task.id) }
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let warning = task.warning {
                                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                }
                                Text(task.text)
                                    .font(.subheadline)
                                if let detail = task.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label("Laufende Aufgaben", systemImage: "arrow.trianglehead.2.counterclockwise")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(ongoingProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if ongoingExpanded {
                    Text("Diese Aufgaben laufen parallel zu den Schritten und sollten so schnell wie möglich erledigt werden.")
                }
            }

            // MARK: Bauanleitung

            Section {
                ForEach(BuildStep.allSteps) { step in
                    CheckableRow(
                        id: step.id,
                        isChecked: checkedIds.contains(step.id),
                        onToggle: { toggleCheck(step.id) }
                    ) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(step.number)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(stepColor(step.number).gradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let detail = step.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let warning = step.warning {
                                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            } header: {
                Label("Bauanleitung", systemImage: "list.number")
            } footer: {
                Text("Diese Schritte müssen in exakt dieser Reihenfolge abgearbeitet werden.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Schnellsiedeln")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !sessionStore.isInSession {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label("Fortschritt zurücksetzen", systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Fortschritt zurücksetzen?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                withAnimation { checkedData = Data() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Häkchen werden entfernt.")
        }
        .sheet(isPresented: $showJoinSheet) {
            joinSessionSheet
        }
    }

    // MARK: - Session Banner Views

    /// Solo-Modus Banner: Buttons zum Erstellen/Beitreten
    private var soloModeBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                Text("Solo-Modus")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    createSession()
                } label: {
                    HStack(spacing: 6) {
                        if isCreatingSession {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Session erstellen")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isCreatingSession)

                Button {
                    joinCode = ""
                    sessionError = nil
                    showJoinSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                        Text("Beitreten")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .buttonStyle(.plain)

            if let error = sessionError, !sessionStore.isInSession {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Aktive Session Banner: Code, Mitglieder, Verlassen-Button
    private var activeSessionBanner: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Session:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(sessionStore.activeSession?.joinCode ?? "")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .fontDesign(.monospaced)

                        Text("(\(sessionStore.members.count)/3)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(memberNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    leaveSession()
                } label: {
                    Text("Verlassen")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Join-Session Sheet
    private var joinSessionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Session beitreten")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Gib den 4-stelligen Code ein, den der Session-Ersteller erhalten hat.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TextField("CODE", text: $joinCode)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .frame(maxWidth: 200)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: joinCode) { _, newValue in
                        joinCode = String(newValue.prefix(4)).uppercased()
                    }

                if let error = sessionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    joinSession()
                } label: {
                    HStack {
                        if isJoiningSession {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Beitreten")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(joinCode.count == 4 ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(joinCode.count != 4 || isJoiningSession)
                .buttonStyle(.plain)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abbrechen") { showJoinSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private var memberNames: String {
        sessionStore.members.map(\.playerName).joined(separator: ", ")
    }

    private var ongoingProgress: String {
        let done = OngoingTask.allCases.filter { checkedIds.contains($0.id) }.count
        return "\(done)/\(OngoingTask.allCases.count)"
    }

    private func toggleCheck(_ id: String) {
        if sessionStore.isInSession {
            // Sync-Modus: über GuideSessionStore
            Task { await sessionStore.toggleStep(id) }
        } else {
            // Solo-Modus: lokal via AppStorage
            var ids = localCheckedIds
            if ids.contains(id) {
                ids.remove(id)
            } else {
                ids.insert(id)
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                checkedData = (try? JSONEncoder().encode(ids)) ?? Data()
            }
        }
    }

    private func createSession() {
        isCreatingSession = true
        sessionError = nil
        Task {
            do {
                let code = try await sessionStore.createSession()
                sessionError = nil
                print("[Guide] Session erstellt: \(code)")
            } catch {
                sessionError = error.localizedDescription
            }
            isCreatingSession = false
        }
    }

    private func joinSession() {
        guard joinCode.count == 4 else { return }
        isJoiningSession = true
        sessionError = nil
        Task {
            do {
                try await sessionStore.joinSession(code: joinCode)
                showJoinSheet = false
                sessionError = nil
            } catch {
                sessionError = error.localizedDescription
            }
            isJoiningSession = false
        }
    }

    private func leaveSession() {
        Task {
            do {
                try await sessionStore.leaveSession()
                sessionError = nil
            } catch {
                sessionError = error.localizedDescription
            }
        }
    }

    private func stepColor(_ number: Int) -> Color {
        switch number {
        case 1...8:   return .blue
        case 9...15:  return .orange
        case 16...22: return .purple
        case 23...29: return .green
        default:      return .gray
        }
    }
}

// MARK: - Checkable Row

private struct CheckableRow<Content: View>: View {
    let id: String
    let isChecked: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .frame(width: 24)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isChecked ? 0.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Laufende Aufgaben

private enum OngoingTask: String, CaseIterable, Identifiable {
    case raeuberverstecke
    case heldAuslasten
    case truemmerAbbauen
    case sofortFertigstellen
    case keinMenhir
    case heldenpunkteRohstoff
    case heldNichtSterben
    case questsAnnehmen
    case truppenTrennen
    case travianPlus
    case dorfUmbenennen
    case heldenproduktion
    case kartenspiel
    case tierEinfangen
    case auktionshaus
    case menhirAbklaeren

    var id: String { "ongoing_\(rawValue)" }

    var text: String {
        switch self {
        case .raeuberverstecke:
            return "Räuberverstecke mit dem Held angreifen und so schnell wie möglich vollständig abfarmen. Erhaltenes DG direkt verkaufen."
        case .heldAuslasten:
            return "Den Held maximal auslasten. Er muss im RV angreifen oder auf Abenteuer sein."
        case .truemmerAbbauen:
            return "Alle Trümmer abbauen ohne Rohstoffe überlaufen zu lassen."
        case .sofortFertigstellen:
            return "Bei allen Gebäuden und Trümmern die Sofortfertigstellen-Funktion anwenden."
        case .keinMenhir:
            return "Keinen Menhir nutzen! Der Menhir setzt Räuberversteck-Spawn-Zeiten zurück."
        case .heldenpunkteRohstoff:
            return "Alle Heldenpunkte in Rohstoffproduktion setzen."
        case .heldNichtSterben:
            return "Den Helden nicht sterben lassen. Du brauchst seine Ressourcenproduktion!"
        case .questsAnnehmen:
            return "Alle Quests annehmen, außer der Guide sagt etwas anderes. Dabei darauf achten, dass Ressourcen nicht überlaufen."
        case .truppenTrennen:
            return "Langsame Truppen von schnellen Truppen beim Räumen der RV trennen."
        case .travianPlus:
            return "Travian Plus und ggf. Rohstoffboni aktivieren."
        case .dorfUmbenennen:
            return "Dorf umbenennen (Quest)."
        case .heldenproduktion:
            return "Heldenproduktion umstellen (Quest, gibt 800 vom gewählten Rohstoff)."
        case .kartenspiel:
            return "Das Kartenspiel spielen, bis je eine 5% Getreide- und Rohstoff-Kiste verfügbar sind."
        case .tierEinfangen:
            return "Sobald der Held Käfige gefunden hat, mindestens 1 Tier einfangen."
        case .auktionshaus:
            return "1x im Auktionshaus bieten."
        case .menhirAbklaeren:
            return "Abklären ob menhirt werden soll bzw. ob dafür Kapazität vorhanden ist."
        }
    }

    var warning: String? {
        switch self {
        case .keinMenhir:       return "Wichtig!"
        case .heldNichtSterben: return "Achtung!"
        case .raeuberverstecke: return "Priorität!"
        default:                return nil
        }
    }

    var detail: String? {
        switch self {
        case .raeuberverstecke:
            return "Erst wenn ein RV besiegt wird, spawnt ein neues. Insgesamt min. 6 RV müssen geräumt werden!"
        case .sofortFertigstellen:
            return "Ca. 200 Gold benötigt (Ressourcen-Boosts nicht inbegriffen)."
        default:
            return nil
        }
    }
}

// MARK: - Bauanleitung Schritte

private struct BuildStep: Identifiable {
    let number: Int
    let title: String
    let detail: String?
    let warning: String?

    var id: String { "step_\(number)" }

    static let allSteps: [BuildStep] = [
        BuildStep(
            number: 1,
            title: "5 günstigste Einheiten trainieren",
            detail: "Phalanx, Legionäre oder Keulenschwinger",
            warning: nil
        ),
        BuildStep(
            number: 2,
            title: "Rohstofflager auf Stufe 3",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 3,
            title: "Kornspeicher auf Stufe 3",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 4,
            title: "Botschaft auf Stufe 1",
            detail: "Oase zuweisen, sobald dies möglich ist.",
            warning: nil
        ),
        BuildStep(
            number: 5,
            title: "Versteck auf Stufe 1",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 6,
            title: "Alle Getreidefelder auf Stufe 1",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 7,
            title: "Alle Getreidefelder auf Stufe 2",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 8,
            title: "Alle Getreidefelder auf Stufe 3",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 9,
            title: "Marktplatz auf Stufe 1",
            detail: "Einen Handel einrichten und sofort wieder abbrechen.",
            warning: nil
        ),
        BuildStep(
            number: 10,
            title: "Rohstofflager Stufe 5",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 11,
            title: "Kornspeicher Stufe 5",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 12,
            title: "Hauptgebäude Stufe 5",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 13,
            title: "Residenz Stufe 1",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 14,
            title: "Residenz Stufe 5",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 15,
            title: "Rohstofflager Stufe 6",
            detail: "Residenz 1 und Residenz 5 Quest annehmen.",
            warning: nil
        ),
        BuildStep(
            number: 16,
            title: "2 Siedler bauen",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 17,
            title: "Beide 5%-Kisten verwenden",
            detail: "Sobald der Held Stufe 4 ist. Rohstoffkiste: Produktion auf einen Rohstoff umstellen. Getreidekiste: auf Getreide.",
            warning: nil
        ),
        BuildStep(
            number: 18,
            title: "Dritten Siedler ausbilden",
            detail: "Fleissig Abenteuer machen und RV abfarmen. Siedler können helfen RV abzufarmen.",
            warning: "Siedler nur auf leere RV und niemals ohne starken Begleitschutz schicken!"
        ),
        BuildStep(
            number: 19,
            title: "Hauptgebäude Stufe 10",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 20,
            title: "Residenz abreissen (getimt!)",
            detail: "So timen, dass die Residenz direkt nach der Ausbildung des 3. Siedlers kaputt ist. Die Trümmer-Rohstoffe sind unerlässlich! Abrisszeit: 4h 15min.",
            warning: "Demontage NICHT vor dem 3. Siedler starten, sonst ist das Schnellsiedeln ruiniert!"
        ),
        BuildStep(
            number: 21,
            title: "Kaserne auf Level 3",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 22,
            title: "Akademie auf Stufe 10",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 23,
            title: "Werkstatt Stufe 1",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 24,
            title: "Rathaus Stufe 1",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 25,
            title: "Kornspeicher Stufe 8",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 26,
            title: "Kaserne, Werkstatt und Akademie abreissen",
            detail: "Sollten Rohstoffe fehlen, kann zur Not auch das HG abgerissen werden.",
            warning: nil
        ),
        BuildStep(
            number: 27,
            title: "Kleines Fest feiern im Rathaus",
            detail: nil,
            warning: nil
        ),
        BuildStep(
            number: 28,
            title: "Ggf. menhiren lassen",
            detail: "Falls gewünscht und falls Kapazität dafür da ist.",
            warning: nil
        ),
        BuildStep(
            number: 29,
            title: "Siedler abschicken",
            detail: nil,
            warning: nil
        ),
    ]
}
