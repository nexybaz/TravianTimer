import SwiftUI
import UIKit

// MARK: - Truppen aktualisieren (Sheet)

struct TroopUpdateView: View {

    /// Wenn true, zeigt "Überspringen" statt "Abbrechen" in der Toolbar (Onboarding-Modus)
    var isOnboarding: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var profile = ProfileStore.shared
    @AppStorage("selectedTribe") private var selectedTribeRaw: String = Tribe.gauls.rawValue
    @AppStorage("selectedWorldId") private var selectedWorldId: String = ""

    /// Volk aus dem Profil (verifiziert) oder aus der manuellen AppStorage-Einstellung
    private var effectiveTribeRaw: String {
        if let tribe = AuthService.shared.profile?.tribe, !tribe.isEmpty {
            // Profil-Tribe auf Tribe mappen
            switch tribe {
            case "Gallier": return Tribe.gauls.rawValue
            case "Roemer":  return Tribe.romans.rawValue
            case "Germanen": return Tribe.teutons.rawValue
            default: return selectedTribeRaw
            }
        }
        return selectedTribeRaw
    }

    @State private var troopsInput: String = ""
    @State private var errorText: String? = nil
    @State private var successText: String? = nil
    @State private var updatedCount: Int = 0

    @State private var streak = TroopUpdateStreakStore.shared
    @State private var updateDelta: TroopUpdateDelta? = nil

    @State private var showSuccess = false
    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0

    // Animation Phasen (Overlay)
    @State private var showDeltaCards = false
    @State private var showHighlight = false
    @State private var showStreak = false

    // Haptic Trigger
    @State private var hapticSuccess = false
    @State private var hapticError = false
    @State private var hapticPaste = false

    @State private var showManualInput = false

    /// Aktuelle Armee (aggregiert) — nil wenn keine Truppen vorhanden
    private var currentArmy: AggregatedTroops? {
        let agg = aggregateTroopCounts(profile.villages)
        return agg.total > 0 ? agg : nil
    }

    private var freshnessColor: Color {
        guard let hours = streak.hoursSinceUpdate else { return Color(.systemGray) }
        if hours < 12 { return .green }
        if hours < 24 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {

                        // ── Aktuelle Armee (nur für wiederkehrende User) ──
                        if let army = currentArmy {
                            currentArmyCard(army)
                        }

                        // ── Streak-Motivation ──
                        if streak.currentStreak > 0 && !streak.hasUpdatedToday {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.orange)
                                    .symbolEffect(.pulse, options: .repeating)
                                Text("Tag \(streak.currentStreak + 1) deiner Serie!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }

                        // ── Error Banner ──
                        if let errorText {
                            errorBanner(errorText)
                        }

                        // ── Hero Paste Button ──
                        pasteHeroButton

                        // ── Erste Schritte (nur wenn noch nie importiert) ──
                        if currentArmy == nil && !streak.hasUpdatedToday {
                            firstTimeCard
                        }

                        // ── Manuell einfügen (collapsed) ──
                        manualInputSection

                        // ── Safari-Link ──
                        helpLink
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .navigationTitle("Truppen aktualisieren")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isOnboarding {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Überspringen") { dismiss() }
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Abbrechen") { dismiss() }
                        }
                    }
                }
            }
            .allowsHitTesting(!showSuccess)

            if showSuccess {
                successOverlay
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
            }
        }
        .sensoryFeedback(.success, trigger: hapticSuccess)
        .sensoryFeedback(.error, trigger: hapticError)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticPaste)
    }

    // MARK: - Current Army Card

    private func currentArmyCard(_ army: AggregatedTroops) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Deine Armee")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                if let timeText = streak.relativeTimeString() {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(freshnessColor)
                            .frame(width: 6, height: 6)
                        Text(timeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 0) {
                armyStat(shortValue(army.total), label: "Truppen", icon: "shield.fill", color: .blue)
                armyStat(shortValue(army.off), label: "Off", icon: "flame.fill", color: .orange)
                armyStat(shortValue(army.deff), label: "Deff", icon: "shield.checkered", color: .green)
                armyStat(shortValue(army.crop), label: "Crop/h", icon: "leaf.fill", color: .yellow)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private func armyStat(_ value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortValue(_ v: Int) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 10_000 { return String(format: "%.1fk", Double(v) / 1_000) }
        if v >= 1_000 {
            let formatted = String(format: "%.1fk", Double(v) / 1_000)
            return formatted.hasSuffix(".0k") ? "\(v / 1000)k" : formatted
        }
        return "\(v)"
    }

    // MARK: - Hero Paste Button

    private var pasteHeroButton: some View {
        Button {
            hapticPaste.toggle()
            if let clip = UIPasteboard.general.string {
                troopsInput = clip
                parseTroops()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Aus Zwischenablage aktualisieren")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("1 Tap — Truppen sofort updaten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange.opacity(0.04))
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Error Banner

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                withAnimation { errorText = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - First Time Card

    private var firstTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So geht's")
                .font(.subheadline)
                .fontWeight(.semibold)

            importStep(number: 1, icon: "safari", text: "Truppenübersicht im Spiel öffnen")
            importStep(number: 2, icon: "rectangle.dashed", text: "Alles markieren (⌘A / Ctrl+A)")
            importStep(number: 3, icon: "doc.on.clipboard", text: "Kopieren & oben einfügen")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }

    private func importStep(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }

            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Manual Input Section (Collapsed)

    private var manualInputSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showManualInput.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Manuell einfügen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showManualInput ? 90 : 0))
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if showManualInput {
                VStack(spacing: 8) {
                    TextEditor(text: $troopsInput)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.2))
                        )

                    HStack {
                        if let successText {
                            Label(successText, systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        if !troopsInput.isEmpty {
                            Button {
                                parseTroops()
                            } label: {
                                Label("Parsen", systemImage: "wand.and.stars")
                                    .font(.footnote)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Help Link

    private var helpLink: some View {
        Button {
            let worldId = selectedWorldId.isEmpty ? "de1n" : selectedWorldId
            if let url = URL(string: "https://\(worldId).kingdoms.com/#/window:villagesOverview/page:village/tab:Troops") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "safari")
                    .font(.system(size: 12))
                Text("Truppenübersicht im Browser öffnen")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Rich Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Phase 1: Checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                        .scaleEffect(checkScale)
                        .opacity(checkOpacity)
                }

                // Phase 2: Titel + Untertitel
                VStack(spacing: 6) {
                    Text("Truppen aktualisiert!")
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Text("\(updatedCount) Dörfer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if streak.currentStreak > 0 {
                            Text("·")
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                Text("Tag \(streak.currentStreak)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                .opacity(checkOpacity)

                // Phase 3: Delta-Cards (nur wenn nicht erster Import)
                if let delta = updateDelta, !delta.isFirstImport {
                    HStack(spacing: 8) {
                        deltaCard("Gesamt", delta: delta.totalDelta, icon: "shield.fill")
                        deltaCard("Off", delta: delta.offDelta, icon: "flame.fill")
                        deltaCard("Deff", delta: delta.deffDelta, icon: "shield.checkered")
                        deltaCard("Crop/h", delta: delta.cropDelta, icon: "leaf.fill")
                    }
                    .padding(.horizontal)
                    .offset(y: showDeltaCards ? 0 : 20)
                    .opacity(showDeltaCards ? 1 : 0)
                } else if let delta = updateDelta, delta.isFirstImport {
                    // Erster Import: Absolute Werte statt Deltas
                    VStack(spacing: 4) {
                        Text("Erster Import!")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("\(delta.totalAfter) Truppen · \(delta.cropAfter) Getreide/h")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: showDeltaCards ? 0 : 20)
                    .opacity(showDeltaCards ? 1 : 0)
                }

                // Phase 4: Highlight (grösster Zuwachs)
                if let delta = updateDelta, let gain = delta.biggestGain, gain.delta > 0, !delta.isFirstImport {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("Grösster Zuwachs: +\(gain.delta) \(gain.name)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                    .offset(y: showHighlight ? 0 : 10)
                    .opacity(showHighlight ? 1 : 0)
                }

                // Phase 5: Streak
                if streak.currentStreak > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text("\(streak.currentStreak)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("Tage in Folge")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if streak.longestStreak > streak.currentStreak {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10))
                                Text("Rekord: \(streak.longestStreak)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .scaleEffect(showStreak ? 1 : 0.8)
                    .opacity(showStreak ? 1 : 0)
                }
            }
        }
        .transition(.opacity)
        .onAppear { startOverlayAnimation() }
    }

    private func startOverlayAnimation() {
        // Phase 1: Checkmark
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            checkScale = 1.0
            checkOpacity = 1.0
        }
        hapticSuccess.toggle()

        // Phase 2: Delta-Cards
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showDeltaCards = true
            }
        }

        // Phase 3: Highlight
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showHighlight = true
            }
        }

        // Phase 4: Streak
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showStreak = true
            }
        }

        // Auto-Dismiss nach 3.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            dismiss()
        }
    }

    private func deltaCard(_ label: String, delta: Int, icon: String) -> some View {
        let color: Color = delta > 0 ? .green : delta < 0 ? .red : Color(.systemGray)
        let text: String = {
            let abs = abs(delta)
            if abs >= 10_000 {
                return (delta >= 0 ? "+" : "-") + String(format: "%.1fk", Double(abs) / 1000)
            }
            return delta >= 0 ? "+\(abs)" : "-\(abs)"
        }()

        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.7))
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Parsing

    private func parseTroops() {
        errorText = nil
        successText = nil

        // Falls Villages leer sind (z.B. nach Login noch nicht geladen), aus Supabase nachladen
        if profile.villages.isEmpty {
            Task {
                await profile.loadFromSupabase()
                if profile.villages.isEmpty {
                    errorText = "Keine Dörfer vorhanden. Verifiziere zuerst deinen Travian-Account in den Einstellungen."
                } else {
                    parseTroops()
                }
            }
            return
        }

        let troopOrder = troopTableOrder()
        if troopOrder.count != 10 {
            errorText = "Truppenreihenfolge konnte nicht bestimmt werden. Volk prüfen."
            hapticError.toggle()
            withAnimation { showManualInput = true }
            return
        }

        let lines = troopsInput
            .components(separatedBy: .newlines)
            .map { TextCleaner.cleanLine($0) }
            .filter { !$0.isEmpty }

        // Tabelle erkennen (mehrsprachig: DE, EN, FR)
        let tableLines = extractTableLines(from: lines)

        if tableLines.isEmpty {
            errorText = "Keine Tabelle gefunden. Öffne die Truppenübersicht und kopiere die gesamte Seite (Ctrl+A → Ctrl+C)."
            hapticError.toggle()
            withAnimation { showManualInput = true }
            return
        }

        // Parse: Name → (counts, allowed)
        var parsedByName: [String: (counts: [String: Int], allowed: [String])] = [:]
        let needWithoutHero = troopOrder.count   // 10
        let needWithHero = troopOrder.count + 1  // 11

        for line in tableLines {
            // Noise-Zeile? → überspringen
            if isNoiseLineForTroops(line) { continue }

            // Tokens aufbereiten: Tabs → Space, splitten
            let rawTokens = line
                .replacingOccurrences(of: "\t", with: " ")
                .split(whereSeparator: { $0 == " " })
                .map(String.init)

            if rawTokens.count < 3 { continue }

            // Phase 1: Bonus-Tokens (+40, +55 etc.) entfernen und Slash-Format normalisieren
            let cleaned = rawTokens.compactMap { token -> String? in
                // "+40", "+55", "+644" → Schmiede-Bonus → ignorieren
                if token.hasPrefix("+"), Int(token.dropFirst()) != nil {
                    return nil
                }
                // "886/6200" → "886" (aktuell/kapazität → nur aktuell)
                if token.contains("/") {
                    let parts = token.split(separator: "/", maxSplits: 1)
                    if parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil {
                        return String(parts[0])
                    }
                }
                return token
            }

            if cleaned.count < 3 { continue }

            // Phase 2: Von rechts Integers sammeln (wie vorher, aber auf bereinigten Tokens)
            var ints: [Int] = []
            var idx = cleaned.count - 1
            while idx >= 0 && ints.count < needWithHero {
                if let v = Int(cleaned[idx]) {
                    ints.insert(v, at: 0)
                    idx -= 1
                } else {
                    break
                }
            }

            if ints.count < needWithoutHero { continue }
            let hasHero = (ints.count >= needWithHero)
            let numericTailCount = hasHero ? needWithHero : needWithoutHero

            let nameTokens = cleaned.prefix(max(0, cleaned.count - numericTailCount))
            let nameRaw = nameTokens.joined(separator: " ")
            let name = TextCleaner.cleanLine(nameRaw)
            if name.isEmpty { continue }

            let tail = Array(ints.suffix(numericTailCount))
            let countsEnd = troopOrder.count
            if tail.count < countsEnd { continue }
            let unitCounts = Array(tail[0..<countsEnd])

            let heroCount: Int? = (tail.count > troopOrder.count) ? tail.last : nil

            var countsByKey: [String: Int] = [:]
            var allowed: [String] = []
            for i in 0..<min(troopOrder.count, unitCounts.count) {
                let key = troopOrder[i].rawValue
                let c = unitCounts[i]
                countsByKey[key] = c
                if c > 0 { allowed.append(key) }
            }
            if let heroCount {
                countsByKey["__hero__"] = heroCount
            }

            parsedByName[normalizeVillageKey(name)] = (countsByKey, Array(Set(allowed)).sorted())
        }

        if parsedByName.isEmpty {
            errorText = "Keine Dörfer in der Tabelle erkannt."
            hapticError.toggle()
            withAnimation { showManualInput = true }
            return
        }

        // Before-Snapshot für Delta-Berechnung
        let beforeAgg = aggregateTroopCounts(profile.villages)

        // Match auf bestehende Dörfer und aktualisieren
        var matched = 0
        var missing: [String] = []

        for village in profile.villages {
            let key = normalizeVillageKey(village.name)
            if let payload = parsedByName[key] {
                var updated = village
                updated.troopCounts = payload.counts
                updated.allowedTroops = payload.allowed
                profile.upsert(updated)
                matched += 1
            } else {
                missing.append(village.name)
            }
        }

        if matched == 0 {
            errorText = "Keine Dörfer zugeordnet. Namen müssen exakt übereinstimmen."
            hapticError.toggle()
            withAnimation { showManualInput = true }
            return
        }

        // Snapshot speichern
        let updatedVillages = profile.villages.filter { v in
            parsedByName[normalizeVillageKey(v.name)] != nil
        }
        TroopHistoryStore.shared.recordSnapshot(villages: updatedVillages)

        // After-Snapshot und Delta berechnen
        let afterAgg = aggregateTroopCounts(profile.villages)

        var biggest: (name: String, delta: Int)? = nil
        for (key, afterCount) in afterAgg.perKind {
            let beforeCount = beforeAgg.perKind[key] ?? 0
            let d = afterCount - beforeCount
            if d > 0, d > (biggest?.delta ?? 0) {
                let name = TroopKind(rawValue: key)?.uiName ?? key
                biggest = (name: name, delta: d)
            }
        }

        updateDelta = TroopUpdateDelta(
            villagesUpdated: matched,
            totalBefore: beforeAgg.total, totalAfter: afterAgg.total,
            offBefore: beforeAgg.off, offAfter: afterAgg.off,
            deffBefore: beforeAgg.deff, deffAfter: afterAgg.deff,
            cropBefore: beforeAgg.crop, cropAfter: afterAgg.crop,
            biggestGain: biggest
        )

        // Streak aktualisieren
        streak.recordUpdate()

        updatedCount = matched
        if !missing.isEmpty && missing.count < profile.villages.count {
            successText = "\(matched) Dörfer aktualisiert (\(missing.count) ohne Match)"
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccess = true
        }
    }

    // MARK: - Table extraction (Ctrl+A tolerant)

    /// Extrahiert die relevanten Tabellenzeilen aus einem Ctrl+A Copy.
    /// Sucht mehrsprachig nach Header- und Footer-Markern und filtert Noise.
    private func extractTableLines(from lines: [String]) -> [String] {
        // Bekannte Header-Marker (Zeile die den Tabellenanfang markiert)
        let headerMarkers: Set<String> = ["dorfname", "village name", "nom du village", "nome del villaggio", "nazwa wioski"]
        // Bekannte Footer-Marker (Zeile die das Tabellenende markiert)
        let footerPrefixes = ["gesamt", "total", "totale", "suma"]

        var tableLines: [String] = []
        var inTable = false

        for l in lines {
            let lower = l.lowercased().trimmingCharacters(in: .whitespaces)

            if !inTable {
                if headerMarkers.contains(lower) {
                    inTable = true
                }
                continue
            }

            // Footer erreicht → Tabelle fertig
            if footerPrefixes.contains(where: { lower.hasPrefix($0) }) {
                break
            }

            tableLines.append(l)
        }

        // Fallback: Falls kein Header-Marker gefunden, versuche alle Zeilen
        // die wie Truppen-Daten aussehen (enthalten genug Zahlen)
        if tableLines.isEmpty {
            tableLines = lines.filter { line in
                let numericCount = countNumericTokens(in: line)
                return numericCount >= 5  // mindestens 5 Zahlen = wahrscheinlich Truppendaten
            }
        }

        return tableLines
    }

    /// Zaehlt wie viele Tokens in einer Zeile als Zahl parsbar sind (nach Normalisierung)
    private func countNumericTokens(in line: String) -> Int {
        let tokens = line
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: { $0 == " " })

        var count = 0
        for token in tokens {
            let s = String(token)
            // Bonus-Token (+40) nicht zaehlen
            if s.hasPrefix("+"), Int(s.dropFirst()) != nil { continue }
            // Slash-Format: 886/6200 → zaehlt als 1 Zahl
            if s.contains("/") {
                let parts = s.split(separator: "/", maxSplits: 1)
                if parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil {
                    count += 1
                    continue
                }
            }
            if Int(s) != nil { count += 1 }
        }
        return count
    }

    // MARK: - Noise-Filter

    /// Erkennt Zeilen die UI-Elemente, Navigation oder andere irrelevante Inhalte enthalten
    private func isNoiseLineForTroops(_ line: String) -> Bool {
        let lower = line.lowercased()

        // Bekannte UI-Noise-Woerter (Travian Kingdoms Oberflaeche)
        let noiseExact: Set<String> = [
            "discord", "help center", "support", "settings", "logout",
            "village name", "dorfname", "nom du village",
            "barbar", "römer", "roemer", "gallier", "germanen",
            "romans", "gauls", "teutons", "roman", "gaul", "teuton",
            "overview", "übersicht", "uebersicht",
            "troops", "truppen", "troupes",
            "hero", "held", "héros",
            "adventures", "abenteuer", "aventures",
            "profile", "profil",
            "messages", "nachrichten",
            "reports", "berichte",
            "map", "karte",
            "resources", "ressourcen",
            "building", "gebäude", "gebaeude",
            "marketplace", "marktplatz",
            "rally point", "versammlungsplatz",
            "auction", "auktion",
            "kingdom", "königreich", "koenigreich",
        ]

        // Pruefen ob die gesamte Zeile ein bekanntes Noise-Wort ist
        let trimmed = lower.trimmingCharacters(in: .whitespaces)
        if noiseExact.contains(trimmed) { return true }

        // Zeilen die nur aus einem kurzen Text ohne Zahlen bestehen (< 3 Zeichen Zahlenanteil)
        // und keine bekannten Dorfnamen sein koennten → Noise
        // Das wird aber besser durch den numericTail-Check im Haupt-Parser abgefangen.

        return false
    }

    // MARK: - Helpers

    private func normalizeVillageKey(_ raw: String) -> String {
        var s = TextCleaner.cleanLine(raw)
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        s = s.replacingOccurrences(of: "\t", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: " (", with: "(")
        s = s.replacingOccurrences(of: ") ", with: ")")
        return s.lowercased()
    }

    private func troopTableOrder() -> [TroopKind] {
        let tribeRaw = effectiveTribeRaw
        let all = TroopKind.troops(forSelectedTribeRaw: tribeRaw)
        if all.isEmpty { return [] }

        func matches(_ troop: TroopKind, aliases: [String]) -> Bool {
            let name = troop.uiName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return aliases.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name }
        }

        func pick(_ columns: [[String]]) -> [TroopKind] {
            var out: [TroopKind] = []
            out.reserveCapacity(columns.count)
            for aliases in columns {
                if let t = all.first(where: { matches($0, aliases: aliases) }) {
                    out.append(t)
                }
            }
            return out
        }

        if tribeRaw == Tribe.gauls.rawValue {
            let order = pick([
                ["Phalanx", "Phalanxe"],
                ["Schwertkämpfer"],
                ["Späher", "Kundschafter"],
                ["Theutates Blitz"],
                ["Druidenreiter"],
                ["Haeduaner"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Häuptling"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        if tribeRaw == Tribe.romans.rawValue {
            let order = pick([
                ["Legionär"],
                ["Prätorianer"],
                ["Imperianer"],
                ["Equites Legati"],
                ["Equites Imperatoris"],
                ["Equites Caesaris"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Senator"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        if tribeRaw == Tribe.teutons.rawValue {
            let order = pick([
                ["Keulenschwinger"],
                ["Speerkämpfer"],
                ["Axtkämpfer"],
                ["Kundschafter", "Späher"],
                ["Paladin"],
                ["Teutonen-Reiter"],
                ["Ramme"],
                ["Feuerkatapult", "Katapult"],
                ["Stammesführer"],
                ["Siedler"]
            ])
            if order.count == 10 { return order }
        }

        return Array(all.prefix(10))
    }

    // MARK: - Delta Helpers

    private struct AggregatedTroops {
        let total: Int
        let off: Int
        let deff: Int
        let crop: Int
        let perKind: [String: Int]
    }

    private func aggregateTroopCounts(_ villages: [VillageProfile]) -> AggregatedTroops {
        var total = 0, off = 0, deff = 0, crop = 0
        var perKind: [String: Int] = [:]
        for village in villages {
            for (key, count) in village.troopCounts where count > 0 {
                total += count
                perKind[key, default: 0] += count
                if let kind = TroopKind(rawValue: key) {
                    if kind.isOffensive { off += count }
                    if kind.isDefensive { deff += count }
                    crop += count * kind.cropPerHour
                }
            }
        }
        return AggregatedTroops(total: total, off: off, deff: deff, crop: crop, perKind: perKind)
    }
}

// MARK: - TroopUpdateDelta

struct TroopUpdateDelta {
    let villagesUpdated: Int
    let totalBefore: Int
    let totalAfter: Int
    let offBefore: Int
    let offAfter: Int
    let deffBefore: Int
    let deffAfter: Int
    let cropBefore: Int
    let cropAfter: Int
    let biggestGain: (name: String, delta: Int)?

    var totalDelta: Int { totalAfter - totalBefore }
    var offDelta: Int { offAfter - offBefore }
    var deffDelta: Int { deffAfter - deffBefore }
    var cropDelta: Int { cropAfter - cropBefore }
    var isFirstImport: Bool { totalBefore == 0 }
}
