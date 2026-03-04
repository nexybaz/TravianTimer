import SwiftUI

// MARK: - Attack Form (Angriff hinzufuegen)

struct AttackFormView: View {

    let operation: Operation
    let onSave: () -> Void

    @Environment(OperationPlanStore.self) var store
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    // Angreifer
    @State private var playerName = ""
    @State private var villageName = ""
    @State private var villageXText = ""
    @State private var villageYText = ""

    // Ziel
    @State private var targetXText = ""
    @State private var targetYText = ""
    @State private var targetPlayer = ""
    @State private var targetVillage = ""
    @State private var useManualTarget = false
    @State private var enemyKingdoms: [EnemyKingdom] = []
    @State private var enemyPlayers: [EnemyPlayer] = []
    @State private var enemyVillages: [EnemyVillage] = []
    @State private var selectedEnemyKingdom: Int?
    @State private var selectedEnemyPlayerId: Int?
    @State private var selectedEnemyVillageId: UUID?

    // Timing
    @State private var arrival = Date().addingTimeInterval(3600 * 12)
    @State private var arrivalSeconds: Int = 0
    @State private var selectedTroop: TroopKind?

    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue

    // Typ
    @State private var attackType: AttackType = .attack

    // Optionen
    @State private var notes = ""
    @State private var isSaving = false
    @State private var useManualEntry = false

    // Kingdom village selection
    @State private var selectedPlayer: String?
    @State private var selectedVillageId: UUID?

    // Tribe expansion
    @State private var expandedRomans = false
    @State private var expandedGauls = false
    @State private var expandedTeutons = false

    private var kingdomVillages: [KingdomVillage] { store.kingdomVillages }

    /// Unique players sorted alphabetically, own player first
    private var playerNames: [String] {
        let unique = Set(kingdomVillages.map(\.playerName))
        let myName = authService.profile?.playerName ?? ""
        return unique.sorted { a, b in
            if a == myName { return true }
            if b == myName { return false }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    /// Villages for selected player
    private var villagesForPlayer: [KingdomVillage] {
        guard let player = selectedPlayer else { return [] }
        return kingdomVillages
            .filter { $0.playerName == player }
            .sorted { $0.villageName.localizedCaseInsensitiveCompare($1.villageName) == .orderedAscending }
    }

    /// The user ID of the selected player (for assignedTo)
    private var selectedPlayerId: UUID? {
        guard let player = selectedPlayer else { return nil }
        return kingdomVillages.first(where: { $0.playerName == player })?.userId
    }

    private var troopSpeed: Double? {
        guard let troop = selectedTroop else { return nil }
        let s = troop.speed
        return s > 0 ? s : nil
    }

    /// Combat troops grouped by tribe (excluding settlers, discord)
    private var troopsByTribe: [(tribe: String, troops: [TroopKind])] {
        let tribes: [(String, String)] = [("Römer", "romans"), ("Gallier", "gauls"), ("Germanen", "teutons")]
        return tribes.map { (label, prefix) in
            let troops = TroopKind.allCases.filter {
                $0.rawValue.hasPrefix("\(prefix).") && $0 != .discordPlayer
                && !$0.rawValue.hasSuffix(".settler")
            }
            return (label, troops)
        }
    }

    private func expansionBinding(for tribe: String) -> Binding<Bool> {
        switch tribe {
        case "Römer": return $expandedRomans
        case "Germanen": return $expandedTeutons
        default: return $expandedGauls
        }
    }

    private var isValid: Bool {
        !playerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !villageName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(villageXText) != nil && Int(villageYText) != nil &&
        Int(targetXText) != nil && Int(targetYText) != nil &&
        troopSpeed != nil
    }

    // Vorberechnete Werte
    private var preview: (departureAt: Date, travelSeconds: Double)? {
        guard let vx = Int(villageXText), let vy = Int(villageYText),
              let tx = Int(targetXText), let ty = Int(targetYText),
              let speed = troopSpeed else { return nil }

        let cal = Calendar.current
        let currentSec = cal.component(.second, from: arrival)
        let arrivalWithSec = cal.date(byAdding: .second, value: arrivalSeconds - currentSec, to: arrival) ?? arrival

        return OperationPlanStore.calculateDeparture(
            arrival: arrivalWithSec,
            fromX: vx, fromY: vy,
            toX: tx, toY: ty,
            troopSpeed: speed,
            worldSpeed: operation.worldSpeed
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Angreifer
                Section("Angreifer") {
                    if !kingdomVillages.isEmpty && !useManualEntry {
                        Picker("Spieler", selection: $selectedPlayer) {
                            Text("Wählen…").tag(nil as String?)
                            ForEach(playerNames, id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        }
                        .onChange(of: selectedPlayer) { _, newPlayer in
                            // Reset village when player changes
                            selectedVillageId = nil
                            if let newPlayer {
                                playerName = newPlayer
                                // Auto-select first village if only one
                                let villages = kingdomVillages.filter { $0.playerName == newPlayer }
                                if villages.count == 1, let v = villages.first {
                                    selectVillage(v)
                                }
                            }
                        }

                        if selectedPlayer != nil {
                            Picker("Dorf", selection: $selectedVillageId) {
                                Text("Wählen…").tag(nil as UUID?)
                                ForEach(villagesForPlayer) { v in
                                    Text("\(v.villageName) (\(v.x)|\(v.y))")
                                        .tag(v.id as UUID?)
                                }
                            }
                            .onChange(of: selectedVillageId) { _, newId in
                                if let v = kingdomVillages.first(where: { $0.id == newId }) {
                                    selectVillage(v)
                                }
                            }
                        }

                        Button("Manuell eingeben") {
                            useManualEntry = true
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        // Manual entry
                        TextField("Spielername", text: $playerName)
                        TextField("Dorfname", text: $villageName)
                        HStack {
                            TextField("X", text: $villageXText)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 80)
                            Text("|")
                                .foregroundStyle(.secondary)
                            TextField("Y", text: $villageYText)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 80)
                        }

                        if !kingdomVillages.isEmpty {
                            Button("Aus Kingdom wählen") {
                                useManualEntry = false
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Ziel
                Section("Ziel") {
                    if !enemyKingdoms.isEmpty && !useManualTarget {
                        Picker("Königreich", selection: $selectedEnemyKingdom) {
                            Text("Wählen…").tag(nil as Int?)
                            ForEach(enemyKingdoms) { k in
                                Text(k.displayName).tag(k.kingdomId as Int?)
                            }
                        }
                        .onChange(of: selectedEnemyKingdom) { _, newKingdom in
                            selectedEnemyPlayerId = nil
                            selectedEnemyVillageId = nil
                            enemyPlayers = []
                            enemyVillages = []
                            guard let newKingdom else { return }
                            Task { enemyPlayers = await store.fetchEnemyPlayers(kingdomId: newKingdom) }
                        }

                        if selectedEnemyKingdom != nil && !enemyPlayers.isEmpty {
                            Picker("Spieler", selection: $selectedEnemyPlayerId) {
                                Text("Wählen…").tag(nil as Int?)
                                ForEach(enemyPlayers) { p in
                                    Text(p.playerName).tag(p.userId as Int?)
                                }
                            }
                            .onChange(of: selectedEnemyPlayerId) { _, newPlayer in
                                selectedEnemyVillageId = nil
                                enemyVillages = []
                                if let newPlayer {
                                    targetPlayer = enemyPlayers.first(where: { $0.userId == newPlayer })?.playerName ?? ""
                                    Task { enemyVillages = await store.fetchEnemyVillages(playerId: newPlayer) }
                                }
                            }
                        }

                        if selectedEnemyPlayerId != nil && !enemyVillages.isEmpty {
                            Picker("Dorf", selection: $selectedEnemyVillageId) {
                                Text("Wählen…").tag(nil as UUID?)
                                ForEach(enemyVillages) { v in
                                    Text("\(v.name) (\(v.x)|\(v.y))")
                                        .tag(v.id as UUID?)
                                }
                            }
                            .onChange(of: selectedEnemyVillageId) { _, newId in
                                if let v = enemyVillages.first(where: { $0.id == newId }) {
                                    targetVillage = v.name
                                    targetXText = "\(v.x)"
                                    targetYText = "\(v.y)"
                                }
                            }
                        }

                        Button("Manuell eingeben") {
                            useManualTarget = true
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        TextField("Spieler (optional)", text: $targetPlayer)
                        TextField("Dorf (optional)", text: $targetVillage)
                        HStack {
                            TextField("X", text: $targetXText)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 80)
                            Text("|")
                                .foregroundStyle(.secondary)
                            TextField("Y", text: $targetYText)
                                .keyboardType(.numbersAndPunctuation)
                                .frame(width: 80)
                        }

                        if !enemyKingdoms.isEmpty {
                            Button("Aus Datenbank wählen") {
                                useManualTarget = false
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Typ
                Section("Aktionstyp") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AttackType.commonTypes) { type in
                                Button {
                                    attackType = type
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                            .font(.caption2)
                                        Text(type.shortLabel)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(attackType == type ? type.color : Color(.systemGray5))
                                    .foregroundStyle(attackType == type ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: Geschwindigkeit
                Section("Langsamste Einheit") {
                    ForEach(troopsByTribe, id: \.tribe) { group in
                        DisclosureGroup(isExpanded: expansionBinding(for: group.tribe)) {
                            ForEach(group.troops, id: \.self) { troop in
                                Button {
                                    selectedTroop = troop
                                } label: {
                                    HStack {
                                        Image(systemName: troop.categoryIcon)
                                            .frame(width: 20)
                                            .foregroundStyle(troop.tribeColor)
                                        Text(troop.uiName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(Int(troop.speed)) F/h")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                        if selectedTroop == troop {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.orange)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } label: {
                            Text(group.tribe)
                        }
                    }

                    if let troop = selectedTroop {
                        HStack {
                            Text("Gewählt:")
                                .foregroundStyle(.secondary)
                            Text("\(troop.uiName)")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(troop.speed)) F/h")
                                .monospacedDigit()
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                    }
                }

                // MARK: Timing
                Section("Timing") {
                    DatePicker("Ankunft", selection: $arrival)

                    HStack {
                        Text("Sekunden:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: $arrivalSeconds, in: 0...59) {
                            Text("\(arrivalSeconds)")
                                .monospacedDigit()
                                .fontWeight(.bold)
                        }
                    }
                }

                // MARK: Vorschau
                if let p = preview {
                    Section("Vorschau") {
                        HStack {
                            Text("Abmarsch")
                            Spacer()
                            Text(p.departureAt.formatted(date: .abbreviated, time: .standard))
                                .monospacedDigit()
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Laufzeit")
                            Spacer()
                            Text(formatDuration(p.travelSeconds))
                                .monospacedDigit()
                        }
                    }
                }

                // MARK: Notizen
                Section("Notizen") {
                    TextField("Optionale Notizen", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Angriff hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .task {
                async let villagesTask: () = store.loadKingdomVillages()
                async let kingdomsTask = store.fetchEnemyKingdoms()
                _ = await villagesTask
                enemyKingdoms = await kingdomsTask

                // Pre-select own player
                if let myName = authService.profile?.playerName,
                   kingdomVillages.contains(where: { $0.playerName == myName }) {
                    selectedPlayer = myName
                }
                // Auto-expand user's tribe
                let raw = selectedTribeRaw.lowercased()
                if raw.contains("römer") || raw.contains("roemer") || raw.contains("roman") {
                    expandedRomans = true
                } else if raw.contains("german") || raw.contains("teuton") || raw.contains("germanen") {
                    expandedTeutons = true
                } else {
                    expandedGauls = true
                }
            }
        }
    }

    private func selectVillage(_ v: KingdomVillage) {
        selectedVillageId = v.id
        playerName = v.playerName
        villageName = v.villageName
        villageXText = "\(v.x)"
        villageYText = "\(v.y)"
    }

    private func save() async {
        guard let vx = Int(villageXText), let vy = Int(villageYText),
              let tx = Int(targetXText), let ty = Int(targetYText),
              let speed = troopSpeed else { return }

        isSaving = true

        let cal = Calendar.current
        let currentSec = cal.component(.second, from: arrival)
        let arrivalWithSec = cal.date(byAdding: .second, value: arrivalSeconds - currentSec, to: arrival) ?? arrival

        _ = await store.addPlannedAttack(
            operationId: operation.id,
            assignedTo: selectedPlayerId,
            attackType: attackType,
            playerName: playerName.trimmingCharacters(in: .whitespaces),
            villageName: villageName.trimmingCharacters(in: .whitespaces),
            villageX: vx, villageY: vy,
            targetX: tx, targetY: ty,
            targetPlayer: targetPlayer.isEmpty ? nil : targetPlayer,
            targetVillage: targetVillage.isEmpty ? nil : targetVillage,
            arrival: arrivalWithSec,
            troopSpeed: speed,
            worldSpeed: operation.worldSpeed,
            notes: notes.isEmpty ? nil : notes
        )

        isSaving = false
        onSave()
        dismiss()
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(abs(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
