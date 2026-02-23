import SwiftUI
import Combine

// MARK: - Call Detail (Optionen)

struct CallDetailView: View {

    enum TimeSort: String, CaseIterable {
        case early = "Frueh"
        case late = "Spaet"
    }

    @Environment(CallsStore.self) var store
    @Environment(\.openURL) private var openURL

    let call: CallItem
    let initialExpandedRowKey: String?

    init(call: CallItem, initialExpandedRowKey: String? = nil) {
        self.call = call
        self.initialExpandedRowKey = initialExpandedRowKey
    }

    @State private var timeSort: TimeSort = .early
    @State private var hideLate: Bool = false
    @State private var hideHidden: Bool = true
    @State private var hiddenRowKeys: Set<String> = []
    @State private var expandedRowKey: String? = nil
    @State private var toastText: String? = nil
    @State private var toastIsSuccess: Bool = false

    @State private var now: Date = .now

    // Pledge-Slider: Row-Key → aktueller Slider-Wert
    @State private var pledgeSliderValues: [String: Double] = [:]

    // Pledge-Direkteingabe: Row-Key des aktiven Textfelds
    @State private var pledgeEditingKey: String? = nil
    @State private var pledgeEditText: String = ""

    // Truppen-Import Sheet (wenn keine troopCounts vorhanden)
    @State private var showTroopImport = false

    // Cached: nur neu berechnen wenn sich now, timeSort oder hideLate aendert
    @State private var cachedResults: [OptionRow] = []

    // Erinnerungen: Row-Key → gewaehlte Minuten
    @State private var reminderSetKeys: [String: Int] = [:]

    // Erfolgsanimation fuer Erinnerung
    @State private var showReminderSuccess = false
    @State private var reminderSuccessText: String = ""
    @State private var reminderCheckScale: CGFloat = 0.3
    @State private var reminderCheckOpacity: Double = 0

    /// Pledges fuer diesen Call aus dem Store
    private var pledges: [TroopPledge] {
        store.pledgesByCall[call.id] ?? []
    }

    var body: some View {
        let firstId = cachedResults.first?.id

        ZStack {
            VStack(spacing: 10) {

                if let toastText {
                    HStack(spacing: 6) {
                        if toastIsSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Text(toastText)
                            .font(.caption)
                            .foregroundStyle(toastIsSuccess ? .primary : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(toastIsSuccess
                                  ? Color.green.opacity(0.1)
                                  : Color(.secondarySystemGroupedBackground))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                List(cachedResults) { row in
                    let isHidden = hiddenRowKeys.contains(rowKey(row))

                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("\(row.start.name)  \(row.troop.uiName)")
                                        .fontWeight(row.id == firstId ? .bold : .regular)
                                        .foregroundStyle(isHidden ? .secondary : .primary)

                                    if existingPledgeCount(for: row) > 0 {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.green.opacity(0.6))
                                    }

                                    if isHidden {
                                        Image(systemName: "eye.slash")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if isLate(row) {
                                    Text("Verpasst um \(formatHHMMSS(missedSeconds(row)))")
                                        .font(.footnote)
                                        .foregroundStyle(.red.opacity(isHidden ? 0.5 : 1))
                                } else {
                                    Text("Senden: \(row.sendTime.formatted(date: .omitted, time: .standard))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                if let mins = reminderSetKeys[rowKey(row)] {
                                    HStack(spacing: 3) {
                                        Image(systemName: "bell.fill")
                                            .font(.caption2)
                                        Text("\(mins)m")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(.orange)
                                }

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(isLate(row) ? "zu spät" : "ok")
                                        .foregroundStyle(isLate(row) ? .red : .green)
                                        .font(.caption)

                                    Image(systemName: expandedRowKey == rowKey(row) ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let key = rowKey(row)
                            withAnimation(.easeOut(duration: 0.15)) {
                                expandedRowKey = (expandedRowKey == key) ? nil : key
                            }
                        }
                        if expandedRowKey == rowKey(row) {
                            HStack(spacing: 10) {
                                Button {
                                    openTargetLink()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "safari")
                                        Text("Ziel öffnen")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(call.linkURL == nil)

                                if reminderSetKeys[rowKey(row)] != nil {
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
                                    .disabled(isLate(row))
                                }

                                Spacer()

                                Button {
                                    toggleHidden(row)
                                } label: {
                                    Image(systemName: isHidden ? "eye" : "eye.slash")
                                }
                                .buttonStyle(.bordered)
                                .tint(isHidden ? .blue : .secondary)
                            }

                            // MARK: Pledge Slider
                            pledgeSection(for: row)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .allowsHitTesting(!showReminderSuccess)

            if showReminderSuccess {
                reminderSuccessOverlay
            }
        }
        .navigationTitle("\(call.title) (\(call.targetX)|\(call.targetY))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: DefenseOverviewRoute(callId: call.id)) {
                    Image(systemName: "shield.checkered")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Sortierung") {
                        Button {
                            timeSort = .early
                        } label: {
                            Label("Zeit aufsteigend", systemImage: timeSort == .early ? "checkmark" : "")
                        }

                        Button {
                            timeSort = .late
                        } label: {
                            Label("Zeit absteigend", systemImage: timeSort == .late ? "checkmark" : "")
                        }
                    }

                    Section("Filter") {
                        Toggle(isOn: $hideLate) {
                            Text("Zu spät ausblenden")
                        }
                        if !hiddenRowKeys.isEmpty {
                            Toggle(isOn: $hideHidden) {
                                Text("Ausgeblendete verstecken (\(hiddenRowKeys.count))")
                            }
                            Button {
                                withAnimation {
                                    hiddenRowKeys.removeAll()
                                    rebuildResults()
                                }
                            } label: {
                                Label("Alle einblenden", systemImage: "eye")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showTroopImport, onDismiss: {
            // Nach Truppen-Import die Optionen neu berechnen
            rebuildResults()
        }) {
            TroopUpdateView()
        }
        .task {
            now = .now
            if let key = initialExpandedRowKey {
                expandedRowKey = key
            }
            // Pledges fuer diesen Call laden
            await store.loadPledges(callId: call.id)
            rebuildResults()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            guard expandedRowKey == nil else { return }
            now = tick
            rebuildResults()
        }
        .onChange(of: timeSort) { _, _ in rebuildResults() }
        .onChange(of: hideLate) { _, _ in rebuildResults() }
        .onChange(of: hideHidden) { _, _ in rebuildResults() }
        .onChange(of: expandedRowKey) { old, new in
            if old != nil && new == nil {
                now = .now
                rebuildResults()
            }
        }
    }

    private func openTargetLink() {
        guard let url = call.linkURL else { return }
        openURL(url)
    }

    private func toggleHidden(_ row: OptionRow) {
        let key = rowKey(row)
        withAnimation {
            if hiddenRowKeys.contains(key) {
                hiddenRowKeys.remove(key)
            } else {
                hiddenRowKeys.insert(key)
                expandedRowKey = nil
            }
            if hideHidden {
                rebuildResults()
            }
        }
    }

    private func cancelReminder(for row: OptionRow) {
        NotificationManager.cancelReminder(callId: call.id, row: row)
        withAnimation {
            reminderSetKeys.removeValue(forKey: rowKey(row))
        }
        showToast("Erinnerung gelöscht")
    }

    private func createReminder(for row: OptionRow, leadMinutes: Int = 3) {
        Task {
            let status = await NotificationManager.authorizationStatus()
            let allowed = await NotificationManager.ensureAuthorization()
            guard allowed else {
                if status == .denied {
                    showToast("Mitteilungen in iOS Einstellungen aktivieren")
                } else {
                    showToast("Benachrichtigungen nicht erlaubt")
                }
                return
            }
            let ok = await NotificationManager.scheduleSendReminder(
                callId: call.id,
                rowKey: rowKey(row),
                row: row,
                targetLink: call.linkURL,
                leadMinutes: leadMinutes
            )
            if ok {
                reminderSetKeys[rowKey(row)] = leadMinutes
                showReminderSuccessAnimation(leadMinutes: leadMinutes)
            } else {
                showToast("Zu spät für Erinnerung")
            }
        }
    }

    private func showReminderSuccessAnimation(leadMinutes: Int) {
        reminderSuccessText = "\(leadMinutes) Min vorher"
        withAnimation(.easeInOut(duration: 0.25)) {
            showReminderSuccess = true
        }
    }

    private func showToast(_ text: String, success: Bool = false) {
        withAnimation(.easeOut(duration: 0.15)) {
            toastIsSuccess = success
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (success ? 1.8 : 2.0)) {
            if toastText == text {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastText = nil
                }
            }
        }
    }

    // MARK: - Reminder Success Overlay

    private var reminderSuccessOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .scaleEffect(reminderCheckScale)
                        .opacity(reminderCheckOpacity)
                }

                VStack(spacing: 6) {
                    Text("Erinnerung gesetzt!")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(reminderSuccessText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(reminderCheckOpacity)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                reminderCheckScale = 1.0
                reminderCheckOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showReminderSuccess = false
                }
                reminderCheckScale = 0.3
                reminderCheckOpacity = 0
                expandedRowKey = nil
            }
        }
    }

    private func isLate(_ row: OptionRow) -> Bool {
        row.sendTime <= now
    }

    private func missedSeconds(_ row: OptionRow) -> TimeInterval {
        max(0, now.timeIntervalSince(row.sendTime))
    }

    private func rowKey(_ row: OptionRow) -> String {
        return row.start.name + "|" + row.troop.rawValue
    }

    private func rebuildResults() {
        let base = store.options(for: call, now: now)
        var filtered = hideLate ? base.filter { !isLate($0) } : base
        if hideHidden && !hiddenRowKeys.isEmpty {
            filtered = filtered.filter { !hiddenRowKeys.contains(rowKey($0)) }
        }
        let ascending = (timeSort == .early)

        let sorted = filtered.sorted {
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

        let newIds = sorted.map(\.id)
        let oldIds = cachedResults.map(\.id)
        if newIds != oldIds {
            cachedResults = sorted
        }
    }

    private func formatHHMMSS(_ secondsRaw: TimeInterval) -> String {
        let total = max(0, Int(secondsRaw.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Pledge Section

    /// Verfuegbare Truppen aus VillageProfile.troopCounts
    private func availableCount(for row: OptionRow) -> Int? {
        guard let village = ProfileStore.shared.villages.first(where: { $0.name == row.start.name }) else {
            return nil
        }
        let count = village.troopCounts[row.troop.rawValue] ?? 0
        return count > 0 ? count : nil
    }

    /// Bereits zugesicherte Menge fuer dieses Dorf+Truppentyp im aktuellen Call
    private func existingPledgeCount(for row: OptionRow) -> Int {
        pledges
            .filter { $0.villageName == row.start.name && $0.troopKind == row.troop.rawValue }
            .reduce(0) { $0 + $1.count }
    }

    /// Bereits zugesichertes Getreide/h ueber alle Pledges im Call (ohne den aktuellen Row-Typ/Dorf)
    private func usedCropExcluding(row: OptionRow) -> Int {
        pledges
            .filter { !($0.villageName == row.start.name && $0.troopKind == row.troop.rawValue) }
            .compactMap { pledge -> Int? in
                guard let kind = TroopKind(rawValue: pledge.troopKind) else { return nil }
                return pledge.count * kind.cropPerHour
            }
            .reduce(0, +)
    }

    /// Verbleibendes Crop-Budget und daraus abgeleitete max Einheiten (nil = keine Obergrenze)
    private struct CropBudget {
        let limit: Int
        let used: Int
        let remaining: Int
        let maxUnits: Int
    }

    private func cropBudget(for row: OptionRow) -> CropBudget? {
        guard let limit = call.cropLimit else { return nil }
        let usedFromPledges = usedCropExcluding(row: row)
        // DB-Wert (cropPledgedTotal) beruecksichtigen — wird auch durch manuelle Discord-Updates gesetzt.
        // Fuer den "excluding" Vergleich: DB-Wert minus den Crop des aktuellen Rows.
        let currentRowCrop = existingPledgeCount(for: row) * row.troop.cropPerHour
        let usedFromDB = max(0, call.cropPledgedTotal - currentRowCrop)
        let used = max(usedFromPledges, usedFromDB)
        let remaining = max(0, limit - used)
        let cropPerUnit = row.troop.cropPerHour
        let maxUnits = cropPerUnit > 0 ? remaining / cropPerUnit : Int.max
        return CropBudget(limit: limit, used: used, remaining: remaining, maxUnits: maxUnits)
    }

    @ViewBuilder
    private func pledgeSection(for row: OptionRow) -> some View {
        let key = rowKey(row)

        if let maxCount = availableCount(for: row) {
            let existing = existingPledgeCount(for: row)

            let budget = cropBudget(for: row)
            let effectiveMax = min(maxCount, budget?.maxUnits ?? maxCount)

            let sliderVal = effectiveMax > 0
                ? Int(min(pledgeSliderValues[key] ?? Double(existing), Double(effectiveMax)))
                : 0
            let sliderCrop = sliderVal * row.troop.cropPerHour

            Divider().padding(.vertical, 4)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Truppen zusichern")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Verfügbar: \(maxCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let budget {
                    let remainingAfterSlider = max(0, budget.remaining - sliderCrop)
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                        if remainingAfterSlider > 0 {
                            Text("Noch \(remainingAfterSlider) Getreide/h frei (Limit: \(budget.limit) Getreide/h)")
                                .font(.caption2)
                        } else {
                            Text("Obergrenze erreicht (\(budget.limit) Getreide/h)")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(remainingAfterSlider > 0 ? .orange : .red)
                }

                let isCropLimited = budget != nil && effectiveMax < maxCount

                HStack(spacing: 12) {
                    if effectiveMax > 0 {
                        if isCropLimited {
                            cropLimitedSlider(
                                key: key,
                                existing: existing,
                                effectiveMax: effectiveMax,
                                totalMax: maxCount
                            )
                        } else {
                            customSlider(
                                key: key,
                                existing: existing,
                                maxVal: effectiveMax
                            )
                        }
                    } else {
                        Text("Obergrenze erreicht")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if pledgeEditingKey == key {
                        // Direkteingabe-Modus: Textfeld mit Zahlentastatur
                        TextField("0", text: $pledgeEditText)
                            .keyboardType(.numberPad)
                            .font(.headline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 52, maxWidth: 70)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                            .onSubmit { commitPledgeEdit(key: key, maxVal: effectiveMax) }
                            .onChange(of: pledgeEditText) {
                                // Live-Sync: Slider folgt der Eingabe
                                if let val = Int(pledgeEditText) {
                                    let clamped = min(max(val, 0), effectiveMax)
                                    pledgeSliderValues[key] = Double(clamped)
                                }
                            }
                            .onAppear {
                                // Focus nach kurzer Verzoegerung
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    pledgeEditText = sliderVal > 0 ? "\(sliderVal)" : ""
                                }
                            }
                    } else {
                        // Zahl antippen → Direkteingabe oeffnen
                        Text("\(sliderVal)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .frame(minWidth: 40, alignment: .trailing)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)
                            .onTapGesture {
                                pledgeEditText = sliderVal > 0 ? "\(sliderVal)" : ""
                                pledgeEditingKey = key
                            }
                    }
                }

                HStack {
                    if existing > 0 {
                        Text("Aktuell zugesichert: \(existing)")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button {
                        Task {
                            await savePledge(for: row, count: sliderVal)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: existing > 0 ? "arrow.triangle.2.circlepath" : "checkmark.shield")
                                .font(.caption)
                            Text(existing > 0 ? "Aktualisieren" : "Zusichern")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(sliderVal == existing || (effectiveMax == 0 && existing == 0))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        } else {
            // Keine troopCounts vorhanden — Hinweis zum Truppen-Import
            Divider().padding(.vertical, 4)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Importiere deine Truppen um hier pledgen zu koennen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showTroopImport = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.caption)
                        Text("Truppen importieren")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Custom Sliders (eigene DragGesture → kein Back-Swipe-Konflikt)

    /// Einfacher Custom Slider ohne Crop-Limit (ersetzt SwiftUI Slider).
    /// Nutzt eigenen DragGesture(minimumDistance: 0) auf dem Thumb,
    /// damit der NavigationStack Back-Swipe nicht versehentlich ausgeloest wird.
    private func customSlider(key: String, existing: Int, maxVal: Int) -> some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = 26
            let usableWidth = geo.size.width - thumbSize

            let currentVal = min(pledgeSliderValues[key] ?? Double(existing), Double(maxVal))
            let valueRatio = maxVal > 0 ? CGFloat(currentVal) / CGFloat(maxVal) : 0
            let thumbX = thumbSize / 2 + usableWidth * valueRatio

            ZStack(alignment: .leading) {
                // Track Hintergrund
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)

                // Gefuellter Bereich (orange)
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.orange)
                    .frame(width: thumbX, height: trackHeight)

                // Thumb
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX - thumbSize / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if pledgeEditingKey != nil { pledgeEditingKey = nil }
                                let x = drag.location.x - thumbSize / 2
                                let clamped = min(max(0, x), usableWidth)
                                let ratio = usableWidth > 0 ? clamped / usableWidth : 0
                                let newVal = Double(maxVal) * Double(ratio)
                                pledgeSliderValues[key] = newVal.rounded()
                            }
                    )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 26)
    }

    /// Custom Slider mit Geister-Balken fuer Crop-Limit.
    private func cropLimitedSlider(key: String, existing: Int, effectiveMax: Int, totalMax: Int) -> some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = 26
            let usableWidth = geo.size.width - thumbSize

            let sliderBinding = Binding<Double>(
                get: {
                    let val = pledgeSliderValues[key] ?? Double(existing)
                    return min(val, Double(effectiveMax))
                },
                set: { newVal in
                    pledgeSliderValues[key] = min(newVal, Double(effectiveMax))
                }
            )

            let currentVal = sliderBinding.wrappedValue
            let limitRatio = totalMax > 0 ? CGFloat(effectiveMax) / CGFloat(totalMax) : 1
            let valueRatio = effectiveMax > 0 ? CGFloat(currentVal) / CGFloat(effectiveMax) : 0
            let thumbX = thumbSize / 2 + usableWidth * limitRatio * valueRatio

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(.systemGray4))
                    .frame(height: trackHeight)

                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: thumbSize / 2 + usableWidth * limitRatio, height: trackHeight)

                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.orange)
                    .frame(width: thumbX, height: trackHeight)

                Rectangle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 2, height: 16)
                    .offset(x: thumbSize / 2 + usableWidth * limitRatio - 1)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX - thumbSize / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if pledgeEditingKey != nil { pledgeEditingKey = nil }
                                let x = drag.location.x - thumbSize / 2
                                let maxX = usableWidth * limitRatio
                                let clamped = min(max(0, x), maxX)
                                let ratio = maxX > 0 ? clamped / maxX : 0
                                let newVal = Double(effectiveMax) * Double(ratio)
                                pledgeSliderValues[key] = newVal.rounded()
                            }
                    )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 26)
    }

    /// Schliesst die Direkteingabe und uebernimmt den Wert in den Slider
    private func commitPledgeEdit(key: String, maxVal: Int) {
        let parsed = Int(pledgeEditText) ?? 0
        let clamped = Swift.min(Swift.max(parsed, 0), maxVal)
        pledgeSliderValues[key] = Double(clamped)
        pledgeEditingKey = nil
    }

    private func savePledge(for row: OptionRow, count: Int) async {
        let village = ProfileStore.shared.villages.first(where: { $0.name == row.start.name })
        let key = rowKey(row)

        // Fehlertext vor dem Speichern merken
        let errorBefore = store.errorText

        await store.savePledge(
            callId: call.id,
            villageName: row.start.name,
            villageX: village?.x ?? row.start.x,
            villageY: village?.y ?? row.start.y,
            troopKind: row.troop.rawValue,
            count: count
        )

        // Slider-State und Direkteingabe zuruecksetzen
        pledgeSliderValues.removeValue(forKey: key)
        if pledgeEditingKey == key { pledgeEditingKey = nil }

        // Erfolgsmeldung nur wenn kein neuer Fehler aufgetreten ist
        let hadError = store.errorText != nil && store.errorText != errorBefore
        if hadError {
            showToast("Speichern fehlgeschlagen")
        } else if count > 0 {
            showToast("\(count)\u{00D7} \(row.troop.uiName) zugesichert", success: true)
        } else {
            showToast("Zusicherung entfernt", success: true)
        }
    }
}

