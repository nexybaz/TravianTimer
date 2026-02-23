import SwiftUI

// MARK: - Truppen Tab

struct TroopsOverviewView: View {

    @State private var profile = ProfileStore.shared
    @State private var history = TroopHistoryStore.shared

    @State private var typesExpanded = false
    @State private var historyExpanded = false
    @State private var showTroopImport = false
    @State private var expandedCard: StatCardType? = nil

    enum StatCardType: Hashable {
        case gesamt, off, deff, crop
    }

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
                        VStack(spacing: 14) {
                            statsCards

                            if historyTotals.count >= 2 {
                                lineChartCard
                            }

                            // Dorfuebersicht
                            villageBreakdownSection

                            aggregatedTypesSection

                            if !historyTotals.isEmpty {
                                historySection
                            }
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
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarButton()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showTroopImport) {
                TroopUpdateView()
            }
        }
    }

    // MARK: - Empty State (Prominenter Import-CTA)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Hero Icon
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

                // Grosser Import Button
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

                // Anleitung-Steps
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

    // MARK: - Stats Cards (Gesamt / Off / Deff / Crop)

    private var statsCards: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                statCard(type: .gesamt, value: totalTroops, label: "Gesamt", color: Color(.systemGray), icon: "shield.fill")
                statCard(type: .off, value: totalOff, label: "Off", color: .red, icon: "flame.fill")
                statCard(type: .deff, value: totalDeff, label: "Deff", color: .green, icon: "shield.checkered")
                statCard(type: .crop, value: totalCrop, label: "Getreide/h", color: .orange, icon: "leaf.fill")
            }

            // Expandierter Detail-Bereich
            if let expanded = expandedCard {
                cardDetail(for: expanded)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func statCard(type: StatCardType, value: Int, label: String, color: Color, icon: String) -> some View {
        let isSelected = expandedCard == type

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedCard = isSelected ? nil : type
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)

                Text(shortNumber(value))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Zahlen kompakt darstellen: 1234 → 1.2k, 12345 → 12.3k
    private func shortNumber(_ value: Int) -> String {
        if value >= 10000 {
            let k = Double(value) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(value)"
    }

    // MARK: - Card Detail

    @ViewBuilder
    private func cardDetail(for type: StatCardType) -> some View {
        switch type {
        case .gesamt:
            gesamtDetail
        case .off:
            offDetail
        case .deff:
            deffDetail
        case .crop:
            cropDetail
        }
    }

    // MARK: Gesamt Detail — Aufschlüsselung nach Truppentyp

    private var gesamtDetail: some View {
        let sorted = aggregatedCounts
        let maxCount = sorted.first?.count ?? 1

        return VStack(spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.kind) { index, entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.kind.categoryIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kind.tribeColor)
                        .frame(width: 20)

                    Text(entry.kind.uiName)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer()

                    // Mini-Balken
                    let ratio = CGFloat(entry.count) / CGFloat(max(1, maxCount))
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.kind.tribeColor.opacity(0.4))
                            .frame(width: geo.size.width * ratio, height: 4)
                    }
                    .frame(width: 60, height: 4)

                    Text("\(entry.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)

                if index < sorted.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Off Detail — Top 3 + bestes Dorf

    private var offDetail: some View {
        let offTroops = aggregatedCounts.filter { $0.kind.isOffensive }.prefix(3)
        let bestVillage = bestVillage(filter: { $0.isOffensive })

        return VStack(spacing: 0) {
            // Top 3
            ForEach(Array(offTroops.enumerated()), id: \.element.kind) { index, entry in
                HStack(spacing: 10) {
                    Text("\(index + 1).")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(width: 20)

                    Image(systemName: entry.kind.categoryIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kind.tribeColor)

                    Text(entry.kind.uiName)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer()

                    Text("\(entry.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)

                if index < offTroops.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }

            // Bestes Dorf
            if let village = bestVillage {
                Divider().padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.6))

                    Text("Stärkstes Dorf")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(village.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text("(\(village.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Deff Detail — Top 3 + bestes Dorf

    private var deffDetail: some View {
        let deffTroops = aggregatedCounts.filter { $0.kind.isDefensive }.prefix(3)
        let bestVillage = bestVillage(filter: { $0.isDefensive })

        return VStack(spacing: 0) {
            ForEach(Array(deffTroops.enumerated()), id: \.element.kind) { index, entry in
                HStack(spacing: 10) {
                    Text("\(index + 1).")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green.opacity(0.6))
                        .frame(width: 20)

                    Image(systemName: entry.kind.categoryIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.kind.tribeColor)

                    Text(entry.kind.uiName)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer()

                    Text("\(entry.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)

                if index < deffTroops.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }

            if let village = bestVillage {
                Divider().padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.6))

                    Text("Stärkstes Dorf")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(village.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text("(\(village.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Crop Detail — Off vs Deff + teuerste Truppe

    private var cropDetail: some View {
        let offCrop = aggregatedCounts.filter { $0.kind.isOffensive }.reduce(0) { $0 + $1.count * $1.kind.cropPerHour }
        let deffCrop = aggregatedCounts.filter { $0.kind.isDefensive }.reduce(0) { $0 + $1.count * $1.kind.cropPerHour }
        let cropTotal = max(1, totalCrop)
        let offRatio = CGFloat(offCrop) / CGFloat(cropTotal)
        let deffRatio = CGFloat(deffCrop) / CGFloat(cropTotal)

        // Teuerste Truppe (höchster Gesamt-Crop-Anteil)
        let mostExpensive = aggregatedCounts
            .map { (kind: $0.kind, crop: $0.count * $0.kind.cropPerHour) }
            .sorted { $0.crop > $1.crop }
            .first

        return VStack(spacing: 10) {
            // Off vs Deff Balken
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Off")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(offCrop) Getreide/h")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.6))
                            .frame(width: max(2, geo.size.width * offRatio))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.opacity(0.6))
                            .frame(width: max(2, geo.size.width * deffRatio))

                        if offRatio + deffRatio < 1 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                        }
                    }
                }
                .frame(height: 8)

                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Deff")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(deffCrop) Getreide/h")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }

            // Teuerste Truppe
            if let top = mostExpensive {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)

                    Text("Teuerste Einheit")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(top.kind.uiName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text("\(top.crop) Getreide/h")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Village Helpers

    private struct VillageRank {
        let name: String
        let count: Int
    }

    private func bestVillage(filter: (TroopKind) -> Bool) -> VillageRank? {
        var villageTotals: [(name: String, count: Int)] = []
        for village in profile.villages {
            let count = village.troopCounts.reduce(0) { total, entry in
                guard let kind = TroopKind(rawValue: entry.key), filter(kind) else { return total }
                return total + entry.value
            }
            if count > 0 {
                villageTotals.append((name: village.name, count: count))
            }
        }
        guard let best = villageTotals.max(by: { $0.count < $1.count }) else { return nil }
        return VillageRank(name: best.name, count: best.count)
    }

    // MARK: - Village Breakdown Section

    private var villageBreakdownSection: some View {
        VStack(spacing: 0) {
            // Header
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
                    Text("\(totalCrop) Getreide/h")
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
        let maxCount = aggregatedCounts.first?.count ?? 1
        let ratio = CGFloat(count) / CGFloat(max(1, maxCount))
        let barColor = kind.isOffensive ? Color.red : kind.isDefensive ? Color.green : kind.tribeColor

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(kind.tribeColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: kind.categoryIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(kind.tribeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(kind.uiName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if kind.isOffensive {
                        Text("OFF")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else if kind.isDefensive {
                        Text("DEF")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                // Anteilsbalken
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(0.6))
                            .frame(width: geo.size.width * ratio, height: 4)
                    }
                }
                .frame(height: 4)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    miniStat(icon: "shield.fill", value: "\(entry.totalTroops)", color: Color(.systemGray))
                    miniStat(icon: "flame.fill", value: "\(entry.offTroops)", color: .red)
                    miniStat(icon: "shield.checkered", value: "\(entry.deffTroops)", color: .green)
                    miniStat(icon: "leaf.fill", value: "\(entry.totalCrop) Getreide/h", color: .orange)
                }
            }

            Spacer()

            if let diff {
                let color: Color = diff > 0 ? .green : diff < 0 ? .red : Color(.systemGray)
                let icon = diff > 0 ? "arrow.up.right" : diff < 0 ? "arrow.down.right" : "minus"

                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(diff >= 0 ? "+\(diff)" : "\(diff)")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 7))
            Text(value)
                .font(.system(size: 10))
                .monospacedDigit()
        }
        .foregroundStyle(color)
    }

    // MARK: - Helpers

    private func previousTotal(before entry: TroopHistoryStore.DateTotal) -> Int? {
        guard let idx = historyTotals.firstIndex(where: { $0.id == entry.id }), idx > 0 else {
            return nil
        }
        return historyTotals[idx - 1].totalTroops
    }
}
