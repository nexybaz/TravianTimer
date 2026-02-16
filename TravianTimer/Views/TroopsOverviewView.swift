import SwiftUI

// MARK: - Truppen Tab

struct TroopsOverviewView: View {

    @StateObject private var profile = ProfileStore.shared
    @StateObject private var history = TroopHistoryStore.shared

    @State private var typesExpanded = false
    @State private var historyExpanded = false

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if profile.villages.isEmpty || totalTroops == 0 {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        statsCards

                        if historyTotals.count >= 2 {
                            lineChartCard
                        }

                        aggregatedTypesSection

                        if !historyTotals.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Truppen")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("Keine Truppen erfasst")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Importiere deine Dörfer in den Einstellungen\nund hinterlege Truppenzahlen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Stats Cards (Gesamt / Off / Deff)

    private var statsCards: some View {
        HStack(spacing: 10) {
            statCard(
                value: totalTroops,
                label: "Gesamt",
                color: Color(.systemGray),
                icon: "shield.fill"
            )
            statCard(
                value: totalOff,
                label: "Off",
                color: .red,
                icon: "flame.fill"
            )
            statCard(
                value: totalDeff,
                label: "Deff",
                color: .green,
                icon: "shield.checkered"
            )
        }
    }

    private func statCard(value: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Line Chart Card

    private var lineChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Legende
            HStack(spacing: 16) {
                legendDot(color: Color(.systemGray), label: "Gesamt")
                legendDot(color: .red, label: "Off")
                legendDot(color: .green, label: "Deff")

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(totalCrop)/h")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)
            }
            .padding(.horizontal, 4)

            // Chart
            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 160
                let data = historyTotals
                let maxVal = max(1, data.map(\.totalTroops).max() ?? 1)

                ZStack(alignment: .topLeading) {
                    // Gitterlinien
                    gridLines(width: w, height: h, maxVal: maxVal)

                    // Gesamt-Linie (grau, gefüllt)
                    linePath(data: data.map(\.totalTroops), maxVal: maxVal, width: w, height: h)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray).opacity(0.15), Color(.systemGray).opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                    linePath(data: data.map(\.totalTroops), maxVal: maxVal, width: w, height: h)
                        .stroke(Color(.systemGray), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Off-Linie (rot)
                    lineStroke(data: data.map(\.offTroops), maxVal: maxVal, width: w, height: h)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Deff-Linie (grün)
                    lineStroke(data: data.map(\.deffTroops), maxVal: maxVal, width: w, height: h)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Datenpunkte
                    dataPoints(data: data.map(\.totalTroops), maxVal: maxVal, width: w, height: h, color: Color(.systemGray))
                    dataPoints(data: data.map(\.offTroops), maxVal: maxVal, width: w, height: h, color: .red)
                    dataPoints(data: data.map(\.deffTroops), maxVal: maxVal, width: w, height: h, color: .green)
                }
                .frame(height: h)

                // X-Achsen-Labels
                HStack(spacing: 0) {
                    ForEach(Array(xAxisLabels(data: data, width: w).enumerated()), id: \.offset) { _, item in
                        Text(item.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: item.width, alignment: item.alignment)
                    }
                }
                .offset(y: h + 4)
            }
            .frame(height: 180)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Chart Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func gridLines(width: CGFloat, height: CGFloat, maxVal: Int) -> some View {
        Canvas { context, size in
            let steps = 4
            for i in 0...steps {
                let y = height * CGFloat(i) / CGFloat(steps)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(Color(.systemGray5)), lineWidth: 0.5)
            }
        }
        .frame(width: width, height: height)
    }

    /// Geschlossener Pfad (für Füllung): Linie + runter zur Baseline + zurück
    private func linePath(data: [Int], maxVal: Int, width: CGFloat, height: CGFloat) -> Path {
        guard data.count >= 2 else { return Path() }
        let points = chartPoints(data: data, maxVal: maxVal, width: width, height: height)

        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        // Schliessen nach unten
        path.addLine(to: CGPoint(x: points.last!.x, y: height))
        path.addLine(to: CGPoint(x: points.first!.x, y: height))
        path.closeSubpath()
        return path
    }

    /// Offener Pfad (nur Linie)
    private func lineStroke(data: [Int], maxVal: Int, width: CGFloat, height: CGFloat) -> Path {
        guard data.count >= 2 else { return Path() }
        let points = chartPoints(data: data, maxVal: maxVal, width: width, height: height)

        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        return path
    }

    private func dataPoints(data: [Int], maxVal: Int, width: CGFloat, height: CGFloat, color: Color) -> some View {
        let points = chartPoints(data: data, maxVal: maxVal, width: width, height: height)
        return ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(pt)
            }
        }
        .frame(width: width, height: height)
    }

    private func chartPoints(data: [Int], maxVal: Int, width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count >= 2 else { return [] }
        let padding: CGFloat = 6
        let usableWidth = width - 2 * padding
        return data.enumerated().map { i, val in
            let x = padding + usableWidth * CGFloat(i) / CGFloat(data.count - 1)
            let y = height - (CGFloat(val) / CGFloat(maxVal) * (height - 12) + 6)
            return CGPoint(x: x, y: y)
        }
    }

    struct XLabel {
        let label: String
        let width: CGFloat
        let alignment: Alignment
    }

    private func xAxisLabels(data: [TroopHistoryStore.DateTotal], width: CGFloat) -> [XLabel] {
        guard data.count >= 2 else { return [] }
        // Erstes und letztes Datum anzeigen, bei >4 Einträgen auch die Mitte
        let first = data.first!.date.formatted(.dateTime.day().month(.twoDigits))
        let last = data.last!.date.formatted(.dateTime.day().month(.twoDigits))

        if data.count <= 4 {
            return [
                XLabel(label: first, width: width / 2, alignment: .leading),
                XLabel(label: last, width: width / 2, alignment: .trailing)
            ]
        }

        let mid = data[data.count / 2].date.formatted(.dateTime.day().month(.twoDigits))
        return [
            XLabel(label: first, width: width / 3, alignment: .leading),
            XLabel(label: mid, width: width / 3, alignment: .center),
            XLabel(label: last, width: width / 3, alignment: .trailing)
        ]
    }

    // MARK: - Aggregierte Truppentypen

    private var aggregatedTypesSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { typesExpanded.toggle() }
            } label: {
                HStack {
                    Text("Truppentypen")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("(\(aggregatedCounts.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: typesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if typesExpanded {
                Divider().padding(.horizontal)

                ForEach(Array(aggregatedCounts.enumerated()), id: \.element.kind) { index, entry in
                    troopRow(kind: entry.kind, count: entry.count)
                        .padding(.horizontal)
                    if index < aggregatedCounts.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Troop Row

    private func troopRow(kind: TroopKind, count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(kind.tribeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: kind.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(kind.tribeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kind.uiName)
                        .font(.body)
                        .fontWeight(.semibold)

                    if kind.isOffensive {
                        Text("OFF")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else if kind.isDefensive {
                        Text("DEF")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Text("\(count) Einheiten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text("\(count * kind.cropPerHour)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)

                Text("/h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Verlauf Section

    private var historySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { historyExpanded.toggle() }
            } label: {
                HStack {
                    Text("Verlauf")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("(\(historyTotals.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if historyExpanded {
                Divider().padding(.horizontal)

                ForEach(Array(historyTotals.reversed().enumerated()), id: \.element.id) { index, entry in
                    let prevTotal = previousTotal(before: entry)
                    let diff = prevTotal.map { entry.totalTroops - $0 }

                    historyRow(entry: entry, diff: diff)
                        .padding(.horizontal)

                    if index < historyTotals.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - History Row

    private func historyRow(entry: TroopHistoryStore.DateTotal, diff: Int?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(entry.totalTroops)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 2) {
                        Circle().fill(Color.red).frame(width: 5, height: 5)
                        Text("\(entry.offTroops)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)

                    HStack(spacing: 2) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("\(entry.deffTroops)")
                            .font(.caption)
                    }
                    .foregroundStyle(.green)

                    HStack(spacing: 2) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                        Text("\(entry.totalCrop)/h")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            if let diff {
                Text(diff >= 0 ? "+\(diff)" : "\(diff)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(diff > 0 ? .green : diff < 0 ? .red : .secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func previousTotal(before entry: TroopHistoryStore.DateTotal) -> Int? {
        guard let idx = historyTotals.firstIndex(where: { $0.id == entry.id }), idx > 0 else {
            return nil
        }
        return historyTotals[idx - 1].totalTroops
    }
}
