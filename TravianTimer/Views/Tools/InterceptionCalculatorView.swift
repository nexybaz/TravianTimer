import SwiftUI
import Combine

// MARK: - Abfang-Rechner (Interception Calculator)

struct InterceptionCalculatorView: View {

    // MARK: - Input State

    @Environment(AuthService.self) var authService
    @State private var heroStore = HeroStore.shared

    @State private var attackerX = ""
    @State private var attackerY = ""
    @State private var attackerSpeedText = "7"
    @AppStorage("troopMultiplier") private var worldSpeed: Double = 1.0

    @State private var selectedVillageId: UUID?
    @State private var attackDate = Date()
    @State private var attackSeconds: Int = 0

    @State private var includeHero = false

    // MARK: - Result State

    @State private var results: [InterceptionRow] = []
    @State private var heroResults: [HeroInterceptionRow] = []
    @State private var hasCalculated = false
    @State private var returnTime: Date?
    @State private var hideLate = false

    // MARK: - Reminder State

    @State private var expandedRowKey: String?
    @State private var reminderSetKeys: [String: Int] = [:]
    @State private var toastText: String?
    @State private var toastIsSuccess = false

    // MARK: - Timer

    @State private var now = Date.now

    // MARK: - Focus

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case attackerX, attackerY, speed }

    // MARK: - Derived

    private let profile = ProfileStore.shared

    private var multiplier: Double {
        worldSpeed > 0 ? worldSpeed : 1.0
    }

    private static let worldSpeedOptions: [Double] = [1, 2, 3, 5]

    private var villages: [VillageProfile] { profile.villages }

    private var selectedVillage: VillageProfile? {
        guard let id = selectedVillageId else { return nil }
        return villages.first { $0.id == id }
    }

    private var attackerBaseSpeed: Double? {
        guard let v = Double(attackerSpeedText.replacingOccurrences(of: ",", with: ".")),
              v > 0 else { return nil }
        return v
    }

    private var canCalculate: Bool {
        guard let _ = Int(attackerX), let _ = Int(attackerY) else { return false }
        return selectedVillage != nil && attackerBaseSpeed != nil
    }

    private var displayResults: [InterceptionRow] {
        let items = hideLate ? results.filter { $0.sendTime >= now } : results
        return items.sorted {
            let late0 = $0.sendTime < now
            let late1 = $1.sendTime < now
            if late0 != late1 { return !late0 }
            if late0 { return $0.sendTime > $1.sendTime }
            return $0.sendTime < $1.sendTime
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    attackerSection
                    defenderSection
                    heroSection

                    calculateButton

                    if hasCalculated, let rt = returnTime {
                        returnTimeBanner(rt)

                        if !heroResults.isEmpty {
                            heroResultsSection
                        }

                        if !results.isEmpty {
                            filterBar
                            resultsList
                        } else if heroResults.isEmpty {
                            noVillagesHint
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))

            // Toast overlay
            if let toast = toastText {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if toastIsSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Text(toast)
                            .font(.caption)
                            .foregroundStyle(toastIsSuccess ? .primary : .secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Abfang-Rechner")
        .navigationBarTitleDisplayMode(.inline)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = .now
        }
        .onAppear {
            if selectedVillageId == nil, let first = villages.first {
                selectedVillageId = first.id
            }
        }
    }

    // MARK: - Angreifer Section

    private var attackerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Angreifer", icon: "flame.fill", color: .red)

            // Coordinate input
            HStack(spacing: 0) {
                Text("(")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                TextField("X", text: $attackerX)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .focused($focusedField, equals: .attackerX)

                Text(" | ")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                TextField("Y", text: $attackerY)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .focused($focusedField, equals: .attackerY)

                Text(")")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // World speed
            VStack(alignment: .leading, spacing: 4) {
                Text("Welt-Geschwindigkeit")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Speed", selection: $worldSpeed) {
                    ForEach(Self.worldSpeedOptions, id: \.self) { s in
                        Text("\(Int(s))×").tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Troop speed input + presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Truppengeschwindigkeit")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "hare.fill")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.6))

                        TextField("Speed", text: $attackerSpeedText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                            .focused($focusedField, equals: .speed)
                    }

                    Menu {
                        ForEach(Self.speedOptions, id: \.speed) { opt in
                            Button(opt.label) {
                                attackerSpeedText = opt.speed.truncatingRemainder(dividingBy: 1) == 0
                                    ? "\(Int(opt.speed))"
                                    : "\(opt.speed)"
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("Vorlagen")
                        }
                        .font(.caption)
                    }
                    .tint(.red)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Verteidiger Section

    private var defenderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Verteidiger", icon: "shield.fill", color: .blue)

            if villages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Richte zuerst deine Dörfer unter \"Mein Account\" ein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Angegriffenes Dorf")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Dorf", selection: $selectedVillageId) {
                        ForEach(villages) { v in
                            Text("\(v.name)  (\(v.x)|\(v.y))")
                                .tag(v.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue)
                }

                if let v = selectedVillage {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("(\(v.x)|\(v.y))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            // Attack time
            VStack(alignment: .leading, spacing: 6) {
                Text("Angriff trifft ein am")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $attackDate)
                    .labelsHidden()

                // Seconds precision
                HStack(spacing: 8) {
                    Text("Sekunden:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Stepper(value: $attackSeconds, in: 0...59) {
                        Text("\(attackSeconds)")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .frame(minWidth: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Held Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Held", icon: "person.fill", color: .orange)

            Toggle(isOn: $includeHero) {
                Text("Held mitschicken")
                    .font(.subheadline)
            }
            .tint(.orange)

            if includeHero {
                let bonuses = computeHeroBonuses()
                if bonuses.heroSpeed > 0 {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "hare.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(bonuses.heroSpeed + bonuses.spursBonusPerHour) F/h")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        if bonuses.speedBonusPercent > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text("+\(bonuses.speedBonusPercent)% (>20F)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Kein Pferd im Konfigurator ausgerüstet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Hero Results Section

    private var heroResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Held", systemImage: "person.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal)

            ForEach(heroResults) { row in
                heroResultRow(row)
            }
        }
        .padding(.horizontal)
    }

    private func heroResultRow(_ row: HeroInterceptionRow) -> some View {
        let isLate = row.sendTime < now

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isLate ? Color.red : Color.orange)
                .frame(width: 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)

                        Text(row.villageName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }

                    Text("Held (\(row.heroSpeed) F/h)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Label("(\(row.villageX)|\(row.villageY))", systemImage: "mappin")
                        Label(formatDuration(row.travelSeconds), systemImage: "arrow.right")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if isLate {
                        Text("zu spät")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        let missed = now.timeIntervalSince(row.sendTime)
                        Text("vor \(formatDuration(missed))")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.7))
                            .monospacedDigit()
                    } else {
                        Text(row.sendTime.formatted(date: .omitted, time: .standard))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        let remaining = row.sendTime.timeIntervalSince(now)
                        Text("in \(formatDuration(remaining))")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isLate
                      ? Color.red.opacity(0.04)
                      : Color.orange.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Calculate Button

    private var calculateButton: some View {
        Button {
            focusedField = nil
            calculate()
        } label: {
            Label("Berechnen", systemImage: "arrow.trianglehead.clockwise")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(!canCalculate)
        .padding(.horizontal)
    }

    // MARK: - Return Time Banner

    private func returnTimeBanner(_ time: Date) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text("Rückkehr des Angreifers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(time.formatted(date: .abbreviated, time: .standard))
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()

            // Live countdown
            let remaining = time.timeIntervalSince(now)
            if remaining > 0 {
                Text("in \(formatDuration(remaining))")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            } else {
                Text("bereits zurückgekehrt")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        let okCount = results.filter { $0.sendTime >= now }.count
        let lateCount = results.count - okCount

        return HStack {
            HStack(spacing: 6) {
                Text("\(okCount) möglich")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)

                Text("·")
                    .foregroundStyle(.secondary)

                Text("\(lateCount) zu spät")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hideLate.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: hideLate ? "eye.slash" : "eye")
                        .font(.caption)
                    Text(hideLate ? "Verspätete ausgeblendet" : "Alle anzeigen")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Results List

    private var resultsList: some View {
        LazyVStack(spacing: 8) {
            let items = displayResults

            if items.isEmpty {
                emptyFilterHint
            } else {
                ForEach(items) { row in
                    interceptionRow(row)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Interception Row

    private func interceptionRow(_ row: InterceptionRow) -> some View {
        let isLate = row.sendTime < now
        let key = rowKey(row)
        let isExpanded = expandedRowKey == key

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Color accent strip
                RoundedRectangle(cornerRadius: 2)
                    .fill(isLate ? Color.red : Color.green)
                    .frame(width: 4)

                // Content
                HStack {
                    // Left: village + troop info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: row.troop.categoryIcon)
                                .font(.system(size: 11))
                                .foregroundStyle(row.troop.tribeColor)

                            Text(row.villageName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if let mins = reminderSetKeys[key] {
                                HStack(spacing: 2) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 8))
                                    Text("\(mins)m")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(.orange)
                            }
                        }

                        Text(row.troop.uiName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Label("(\(row.villageX)|\(row.villageY))", systemImage: "mappin")
                            Label(formatDuration(row.travelSeconds), systemImage: "arrow.right")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    // Right: send time + status + chevron
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 4) {
                            if isLate {
                                Text("zu spät")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)

                                let missed = now.timeIntervalSince(row.sendTime)
                                Text("vor \(formatDuration(missed))")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.7))
                                    .monospacedDigit()
                            } else {
                                Text(row.sendTime.formatted(date: .omitted, time: .standard))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .monospacedDigit()

                                let remaining = row.sendTime.timeIntervalSince(now)
                                Text("in \(formatDuration(remaining))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .monospacedDigit()
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(12)
            }

            // Expanded: reminder actions
            if isExpanded {
                HStack(spacing: 10) {
                    if reminderSetKeys[key] != nil {
                        Button(role: .destructive) {
                            cancelReminder(for: row)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.slash.fill")
                                Text("Löschen")
                            }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Menu {
                            ForEach([1, 3, 5, 10], id: \.self) { mins in
                                Button("\(mins) Min vorher") {
                                    createReminder(for: row, leadMinutes: mins)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell")
                                Text("Erinnerung")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLate)
                    }

                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isLate
                      ? Color.red.opacity(0.04)
                      : Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                expandedRowKey = isExpanded ? nil : key
            }
        }
    }

    // MARK: - Empty States

    private var noVillagesHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "house.lodge")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Keine Dörfer mit Truppen konfiguriert")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Richte deine Dörfer unter \"Mein Account\" ein, um Abfangoptionen zu sehen.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    private var emptyFilterHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Keine rechtzeitigen Optionen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(color)
    }

    // MARK: - Hero Helpers

    private func computeHeroBonuses() -> HeroBonusSummary {
        let tribe = Tribe.from(profileTribe: authService.profile?.tribe)
        let ws: Int = {
            if let wsStr = authService.profile?.worldSpeed, let speed = Int(wsStr), speed > 0 { return speed }
            return 1
        }()
        return HeroBonusCalculator.calculate(config: heroStore.config, tribe: tribe, worldSpeed: ws)
    }

    // MARK: - Calculation

    private func calculate() {
        guard let ax = Int(attackerX),
              let ay = Int(attackerY),
              let def = selectedVillage,
              let baseSpeed = attackerBaseSpeed else { return }

        // Build attack time with seconds precision
        var attackWithSeconds = attackDate
        let cal = Calendar.current
        let currentSec = cal.component(.second, from: attackDate)
        attackWithSeconds = cal.date(byAdding: .second, value: attackSeconds - currentSec, to: attackDate) ?? attackDate

        // 1. Attacker return time
        let distAttackerDefender = Calculator.distance(fromX: ax, fromY: ay, toX: def.x, toY: def.y)
        let attackerEffectiveSpeed = baseSpeed * multiplier
        guard attackerEffectiveSpeed > 0 else { return }

        let returnSeconds = (distAttackerDefender / attackerEffectiveSpeed) * 3600.0
        let rt = attackWithSeconds.addingTimeInterval(returnSeconds)
        returnTime = rt

        // 2. Calculate interception options from all user villages
        let starts = profile.villagesAsStarts(fallback: [])
        var rows: [InterceptionRow] = []

        for village in starts {
            let dist = Calculator.distance(
                fromX: village.x, fromY: village.y,
                toX: ax, toY: ay
            )

            for troop in village.troops {
                guard troop != .discordPlayer else { continue }
                let troopEffSpeed = troop.speed * multiplier
                guard troopEffSpeed > 0 else { continue }

                let travel = (dist / troopEffSpeed) * 3600.0
                let sendTime = rt.addingTimeInterval(-travel)

                rows.append(InterceptionRow(
                    villageName: village.name,
                    villageX: village.x,
                    villageY: village.y,
                    troop: troop,
                    sendTime: sendTime,
                    travelSeconds: travel
                ))
            }
        }

        // 3. Hero interception rows
        var hRows: [HeroInterceptionRow] = []
        if includeHero {
            let bonuses = computeHeroBonuses()
            let heroBaseSpeed = Double(bonuses.heroSpeed + bonuses.spursBonusPerHour)
            if heroBaseSpeed > 0 {
                for village in starts {
                    let dist = Calculator.distance(
                        fromX: village.x, fromY: village.y,
                        toX: ax, toY: ay
                    )

                    var effSpeed = heroBaseSpeed
                    // Ausdauer-Bonus: +X% für Distanzen > 20 Felder
                    if dist > 20, bonuses.speedBonusPercent > 0 {
                        effSpeed *= (1.0 + Double(bonuses.speedBonusPercent) / 100.0)
                    }

                    let heroEffSpeed = effSpeed * multiplier
                    guard heroEffSpeed > 0 else { continue }

                    let travel = (dist / heroEffSpeed) * 3600.0
                    let sendTime = rt.addingTimeInterval(-travel)

                    hRows.append(HeroInterceptionRow(
                        villageName: village.name,
                        villageX: village.x,
                        villageY: village.y,
                        sendTime: sendTime,
                        travelSeconds: travel,
                        heroSpeed: Int(effSpeed)
                    ))
                }
            }
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            results = rows
            heroResults = hRows
            hasCalculated = true
            expandedRowKey = nil
            reminderSetKeys = [:]
        }
    }

    // MARK: - Reminders

    private func createReminder(for row: InterceptionRow, leadMinutes: Int) {
        Task {
            let status = await NotificationManager.authorizationStatus()
            let allowed = await NotificationManager.ensureAuthorization()
            guard allowed else {
                if status == .denied {
                    showToast("Mitteilungen in iOS Einstellungen aktivieren", success: false)
                } else {
                    showToast("Benachrichtigungen nicht erlaubt", success: false)
                }
                return
            }

            let ok = await NotificationManager.scheduleInterceptionReminder(
                villageName: row.villageName,
                troop: row.troop,
                sendTime: row.sendTime,
                leadMinutes: leadMinutes
            )

            if ok {
                let key = rowKey(row)
                withAnimation {
                    reminderSetKeys[key] = leadMinutes
                    expandedRowKey = nil
                }
                showToast("Erinnerung \(leadMinutes) Min vorher gesetzt", success: true)
            } else {
                showToast("Zu spät für Erinnerung", success: false)
            }
        }
    }

    private func cancelReminder(for row: InterceptionRow) {
        NotificationManager.cancelInterceptionReminder(
            villageName: row.villageName,
            troop: row.troop
        )
        withAnimation {
            reminderSetKeys.removeValue(forKey: rowKey(row))
            expandedRowKey = nil
        }
        showToast("Erinnerung gelöscht", success: false)
    }

    // MARK: - Helpers

    private func rowKey(_ row: InterceptionRow) -> String {
        row.villageName + "|" + row.troop.rawValue
    }

    private func showToast(_ text: String, success: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastText = text
            toastIsSuccess = success
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                toastText = nil
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(abs(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Data

private struct InterceptionRow: Identifiable {
    let id = UUID()
    let villageName: String
    let villageX: Int
    let villageY: Int
    let troop: TroopKind
    let sendTime: Date
    let travelSeconds: Double
}

private struct HeroInterceptionRow: Identifiable {
    let id = UUID()
    let villageName: String
    let villageX: Int
    let villageY: Int
    let sendTime: Date
    let travelSeconds: Double
    let heroSpeed: Int
}

// MARK: - Speed Options (dynamisch aus TroopKind)

extension InterceptionCalculatorView {

    /// Generiert Geschwindigkeitsauswahl automatisch aus dem TroopKind-Enum.
    /// Gruppiert nach Base-Speed, dedupliziert UI-Namen, disambiguiert bei
    /// gleichem Namen auf verschiedenen Geschwindigkeiten (z.B. "Späher", "Stammesführer").
    fileprivate static let speedOptions: [(speed: Double, label: String)] = {

        // 1. Nach Geschwindigkeit gruppieren (ohne Discord-Platzhalter)
        var grouped: [Double: [TroopKind]] = [:]
        for troop in TroopKind.allCases where troop != .discordPlayer && troop.speed > 0 {
            grouped[troop.speed, default: []].append(troop)
        }

        // 2. Namen die bei mehreren Geschwindigkeiten vorkommen → brauchen Volk-Suffix
        var nameToSpeeds: [String: Set<Double>] = [:]
        for (speed, troops) in grouped {
            for t in troops {
                nameToSpeeds[t.uiName, default: []].insert(speed)
            }
        }
        let ambiguous = Set(nameToSpeeds.filter { $0.value.count > 1 }.keys)

        // 3. Sortiert aufbauen
        return grouped.keys.sorted().map { speed in
            let troops = grouped[speed]!
            var labels: [String] = []
            var seen = Set<String>()

            for t in troops {
                guard seen.insert(t.uiName).inserted else { continue }
                if ambiguous.contains(t.uiName) {
                    let suffix = t.tribe == "romans" ? "Röm."
                              : t.tribe == "teutons" ? "Germ." : "Gall."
                    labels.append("\(t.uiName) (\(suffix))")
                } else {
                    labels.append(t.uiName)
                }
            }

            let display = labels.count <= 3
                ? labels.joined(separator: ", ")
                : labels.prefix(3).joined(separator: ", ") + " …"

            return (speed: speed, label: "\(Int(speed)) · \(display)")
        }
    }()
}
