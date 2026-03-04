import SwiftUI

// MARK: - Truppen Tab

struct TroopsOverviewView: View {

    @State private var profile = ProfileStore.shared
    @State private var history = TroopHistoryStore.shared
    @State private var streakStore = TroopUpdateStreakStore.shared

    @State private var showTroopImport = false

    // MARK: - Computed (aktueller Stand)

    private var aggregatedCounts: [(kind: TroopKind, count: Int)] {
        var totals: [String: Int] = [:]
        for village in profile.villages {
            for (key, count) in village.troopCounts where count > 0 {
                totals[key, default: 0] += count
            }
        }
        return totals.compactMap { (key, count) in
            guard let kind = TroopKind(rawValue: key) else { return nil }
            return (kind: kind, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    private var totalTroops: Int {
        aggregatedCounts.reduce(0) { $0 + $1.count }
    }

    private var totalOff: Int {
        aggregatedCounts.filter { $0.kind.isOffensive }.reduce(0) { $0 + $1.count }
    }

    private var totalDeff: Int {
        aggregatedCounts.filter { $0.kind.isDefensive }.reduce(0) { $0 + $1.count }
    }

    private var totalCrop: Int {
        aggregatedCounts.reduce(0) { $0 + $1.count * $1.kind.cropPerHour }
    }

    private var historyTotals: [TroopHistoryStore.DateTotal] {
        history.totalsByDate()
    }

    private var villageCount: Int {
        profile.villages.count
    }

    /// Delta vom letzten Import zum vorherigen (für Stat-Tiles)
    private var lastDelta: (troops: Int, off: Int, deff: Int, crop: Int)? {
        let totals = historyTotals
        guard totals.count >= 2 else { return nil }
        let last = totals[totals.count - 1]
        let prev = totals[totals.count - 2]
        return (
            troops: last.totalTroops - prev.totalTroops,
            off: last.offTroops - prev.offTroops,
            deff: last.deffTroops - prev.deffTroops,
            crop: last.totalCrop - prev.totalCrop
        )
    }

    // MARK: - Body

    @Environment(AuthService.self) var authService

    var body: some View {
        NavigationStack {
            Group {
                if authService.profile?.isVerified != true {
                    VerificationRequiredView(feature: "Truppen")
                        .environment(authService)
                } else if profile.villages.isEmpty || totalTroops == 0 {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            updateStatusBar

                            if streakStore.isStale {
                                staleWarning
                            } else if streakStore.streakAtRisk {
                                streakAtRiskNudge
                            }

                            statsGrid

                            if historyTotals.count >= 2 {
                                trendCards
                            }

                            villageSection
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Truppen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTroopImport = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .overlay(alignment: .topTrailing) {
                                if streakStore.isStale || streakStore.streakAtRisk {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 3, y: -3)
                                }
                            }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton()
                }
            }
            .sheet(isPresented: $showTroopImport) {
                TroopUpdateView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.2), .orange.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.orange.opacity(0.7))
                }

                VStack(spacing: 10) {
                    Text("Truppen importieren")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Kopiere deine Truppenübersicht aus dem Spiel\nund importiere sie hier mit einem Tap.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Button {
                    showTroopImport = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 18))
                        Text("Truppen importieren")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 14) {
                    stepRow(number: 1, text: "Öffne die Truppenübersicht im Spiel")
                    stepRow(number: 2, text: "Kopiere die Tabelle (ab Dorfname)")
                    stepRow(number: 3, text: "Tippe oben auf \"Truppen importieren\"")
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Update Status Bar

    private var updateStatusBar: some View {
        HStack(spacing: 12) {
            if streakStore.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("\(streakStore.currentStreak)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            if let timeText = streakStore.relativeTimeString() {
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
    }

    private var freshnessColor: Color {
        guard let hours = streakStore.hoursSinceUpdate else { return Color(.systemGray) }
        if hours < 12 { return .green }
        if hours < 24 { return .orange }
        return .red
    }

    // MARK: - Stale Warning

    private var staleWarning: some View {
        Button { showTroopImport = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daten veraltet")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let timeText = streakStore.relativeTimeString() {
                        Text("Letzte Aktualisierung \(timeText). Jetzt importieren!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak At Risk Nudge

    private var streakAtRiskNudge: some View {
        Button { showTroopImport = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                Text("\(streakStore.currentStreak)-Tage-Streak läuft ab!")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Text("Jetzt importieren")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Grid (2×2)

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            statTile(value: totalTroops, label: "Gesamt", icon: "shield.fill",
                     color: Color(.systemGray), delta: lastDelta?.troops)
            statTile(value: totalOff, label: "Offensiv", icon: "flame.fill",
                     color: .red, delta: lastDelta?.off)
            statTile(value: totalDeff, label: "Defensiv", icon: "shield.checkered",
                     color: .green, delta: lastDelta?.deff)
            statTile(value: totalCrop, label: "Getreide/h", icon: "leaf.fill",
                     color: .orange, delta: lastDelta?.crop)
        }
    }

    private func statTile(value: Int, label: String, icon: String, color: Color, delta: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(shortNumber(value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let delta, delta != 0 {
                HStack(spacing: 2) {
                    Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(delta > 0 ? "+\(shortNumber(abs(delta)))" : "-\(shortNumber(abs(delta)))")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(delta > 0 ? .green : .red)
            } else {
                // Platzhalter damit Tiles gleich hoch bleiben
                Text(" ")
                    .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Zahlen kompakt: 1234 → 1'234, 12345 → 12.3k
    private func shortNumber(_ value: Int) -> String {
        if value >= 10_000 {
            let k = Double(value) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(value)"
    }

    // MARK: - Trend Cards (Sparklines)

    private var trendCards: some View {
        VStack(spacing: 10) {
            // Zeitraum-Header
            if let first = historyTotals.first, let last = historyTotals.last {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(historyTotals.count) Einträge")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(first.date.formatted(.dateTime.day().month(.abbreviated))) – \(last.date.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            sparklineCard(
                title: "Gesamt",
                data: historyTotals.map(\.totalTroops),
                color: Color(.systemGray),
                icon: "shield.fill"
            )
            sparklineCard(
                title: "Offensiv",
                data: historyTotals.map(\.offTroops),
                color: .red,
                icon: "flame.fill"
            )
            sparklineCard(
                title: "Defensiv",
                data: historyTotals.map(\.deffTroops),
                color: .green,
                icon: "shield.checkered"
            )
        }
    }

    private func sparklineCard(title: String, data: [Int], color: Color, icon: String) -> some View {
        let current = data.last ?? 0
        let previous = data.count >= 2 ? data[data.count - 2] : current
        let diff = current - previous
        let hasTrend = data.contains(where: { $0 > 0 })

        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(shortNumber(current))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }

                Spacer()

                if data.count >= 2 && hasTrend {
                    trendBadge(diff: diff, previous: previous)
                }
            }

            if data.count >= 2 && hasTrend {
                sparkline(data: data, color: color)
                    .frame(height: 44)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func trendBadge(diff: Int, previous: Int) -> some View {
        let deltaColor: Color = diff > 0 ? .green : diff < 0 ? .red : Color(.systemGray)
        let iconName = diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "minus"

        let absDiff = abs(diff)
        let diffStr = absDiff >= 10_000
            ? String(format: "%.1fk", Double(absDiff) / 1000)
            : "\(absDiff)"
        let signedDiff = diff >= 0 ? "+\(diffStr)" : "-\(diffStr)"

        let label: String
        if previous > 0 {
            let pct = abs(Double(diff) / Double(previous) * 100)
            label = "\(signedDiff) (\(String(format: "%.1f", pct))%)"
        } else {
            label = signedDiff
        }

        return HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(deltaColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(deltaColor.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Sparkline Drawing

    private func sparkline(data: [Int], color: Color) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard data.count >= 2 else { return }

            let points = sparklinePoints(data: data, width: w, height: h)
            guard points.count >= 2 else { return }

            // Gefüllter Bereich
            var fillPath = smoothCurve(through: points)
            fillPath.addLine(to: CGPoint(x: points.last!.x, y: h))
            fillPath.addLine(to: CGPoint(x: points.first!.x, y: h))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .linearGradient(
                Gradient(colors: [color.opacity(0.2), color.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            ))

            // Linie
            let strokePath = smoothCurve(through: points)
            context.stroke(strokePath, with: .color(color),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Datenpunkte (nur bei ≤ 10 Einträgen, sonst zu dicht)
            if points.count <= 10 {
                for pt in points {
                    let rect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    /// Berechnet Punkte mit dynamischem Y-Bereich (Auto-Zoom)
    private func sparklinePoints(data: [Int], width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count >= 2 else { return [] }
        let rawMin = data.min() ?? 0
        let rawMax = data.max() ?? 1
        let range = rawMax - rawMin
        let pad = range == 0 ? max(1, rawMax / 5) : max(1, range / 5)
        let chartMin = max(0, rawMin - pad)
        let chartMax = rawMax + pad
        let chartRange = CGFloat(max(1, chartMax - chartMin))

        let hPad: CGFloat = 4
        let vPad: CGFloat = 4
        let usableW = width - 2 * hPad
        let usableH = height - 2 * vPad

        return data.enumerated().map { i, val in
            let x = hPad + usableW * CGFloat(i) / CGFloat(data.count - 1)
            let normalized = CGFloat(val - chartMin) / chartRange
            let y = height - vPad - (normalized * usableH)
            return CGPoint(x: x, y: y)
        }
    }

    /// Catmull-Rom Spline: Erzeugt eine glatte Kurve durch alle Punkte
    private func smoothCurve(through points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }
        var path = Path()
        path.move(to: points[0])

        guard points.count > 2 else {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2

            let tension: CGFloat = 6
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / tension,
                y: p1.y + (p2.y - p0.y) / tension
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / tension,
                y: p2.y - (p3.y - p1.y) / tension
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }

    // MARK: - Village Section

    private var villageSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)

                Text("Dörfer")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("(\(villageCount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider().padding(.horizontal)

            ForEach(Array(villagesSorted.enumerated()), id: \.element.name) { index, village in
                villageRow(village: village)
                    .padding(.horizontal)

                if index < villagesSorted.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private struct VillageSummary: Identifiable {
        let name: String
        let troops: Int
        let crop: Int
        let topTroop: TroopKind?
        var id: String { name }
    }

    private var villagesSorted: [VillageSummary] {
        profile.villages.map { village in
            let troops = village.troopCounts.values.reduce(0, +)
            let crop = village.troopCounts.reduce(0) { total, entry in
                guard let kind = TroopKind(rawValue: entry.key) else { return total }
                return total + entry.value * kind.cropPerHour
            }
            let topTroop = village.troopCounts
                .max(by: { $0.value < $1.value })
                .flatMap { TroopKind(rawValue: $0.key) }
            return VillageSummary(name: village.name, troops: troops, crop: crop, topTroop: topTroop)
        }
        .sorted { $0.crop > $1.crop }
    }

    private func villageRow(village: VillageSummary) -> some View {
        let maxCrop = villagesSorted.first?.crop ?? 1
        let ratio = CGFloat(village.crop) / CGFloat(max(1, maxCrop))

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: village.topTroop?.categoryIcon ?? "house.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(village.topTroop?.tribeColor ?? .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(village.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                        Text("\(village.crop)")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.orange)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: geo.size.width * ratio, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.vertical, 6)
    }
}
