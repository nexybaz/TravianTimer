import SwiftUI

// MARK: - Quests Guide View

struct QuestsGuideView: View {

    @State private var selectedGiver: QuestGiver?
    @State private var tribeFilter: QuestTribeFilter = .all
    @State private var searchText = ""
    @State private var expandedId: String?

    var body: some View {
        VStack(spacing: 0) {

            // ── Quest Giver Picker ──
            giverPicker
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // ── Tribe Filter (bei Markus/Häuptling/Alle) ──
            if selectedGiver == nil || selectedGiver == .markus || selectedGiver == .chieftain {
                tribeFilterBar
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            // ── Quest List ──
            ScrollView {
                LazyVStack(spacing: 10) {
                    // ── Total rewards banner ──
                    totalRewardsBanner

                    ForEach(filteredQuests, id: \.id) { quest in
                        questCard(quest)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .searchable(text: $searchText, prompt: "Quest suchen…")
        .navigationTitle("Aufgaben (Quests)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Giver Picker

    private var giverPicker: some View {
        HStack(spacing: 8) {
            ForEach(QuestGiver.allCases, id: \.self) { giver in
                let isSelected = selectedGiver == giver
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGiver = isSelected ? nil : giver
                        expandedId = nil
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(isSelected
                                      ? giver.color.opacity(0.2)
                                      : Color(.tertiarySystemGroupedBackground))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Circle()
                                        .strokeBorder(isSelected ? giver.color : .clear, lineWidth: 2)
                                }
                            Image(systemName: giver.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? giver.color
                                                 : selectedGiver == nil ? giver.color.opacity(0.7)
                                                 : .secondary)
                        }
                        Text(giver.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.primary
                                             : selectedGiver == nil ? Color.primary.opacity(0.8)
                                             : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tribe Filter Bar

    private var tribeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QuestTribeFilter.allCases, id: \.self) { tribe in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tribeFilter = tribe
                        }
                    } label: {
                        Text(tribe.label)
                            .font(.caption)
                            .fontWeight(tribeFilter == tribe ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(tribeFilter == tribe
                                          ? Color.accentColor.opacity(0.15)
                                          : Color(.tertiarySystemGroupedBackground))
                            )
                            .foregroundStyle(tribeFilter == tribe ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Total Rewards Banner

    private var totalRewardsBanner: some View {
        let quests = filteredQuests
        let totalW = quests.reduce(0) { $0 + $1.wood }
        let totalC = quests.reduce(0) { $0 + $1.clay }
        let totalI = quests.reduce(0) { $0 + $1.iron }
        let totalK = quests.reduce(0) { $0 + $1.crop }
        let total = totalW + totalC + totalI + totalK
        let count = quests.count

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Aufgaben")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Gesamt: \(shortRes(total)) Rohstoffe")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Spacer()
            HStack(spacing: 8) {
                resIcon("🪵", value: totalW)
                resIcon("🧱", value: totalC)
                resIcon("⚙️", value: totalI)
                resIcon("🌾", value: totalK)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func resIcon(_ emoji: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text(emoji)
                .font(.system(size: 12))
            Text(shortRes(value))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quest Card

    private func questCard(_ quest: QuestItem) -> some View {
        let isExpanded = expandedId == quest.id

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                // Quest title + prerequisite
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        // Giver badge (nur wenn alle angezeigt)
                        if selectedGiver == nil, let giver = quest.giver {
                            Image(systemName: giver.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(giver.color)
                        }

                        Text(quest.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(isExpanded ? nil : 1)

                        if quest.tribe != .all {
                            tribeBadge(quest.tribe)
                        }
                    }

                    if !quest.requires.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8))
                            Text(quest.requires)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                // Expand chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            // Resource reward row
            if quest.hasResources {
                resourceRow(quest)
            }

            // Other rewards
            if !quest.other.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text(quest.other)
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }

            // Expanded: description
            if isExpanded, !quest.desc.isEmpty {
                Text(quest.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedId = isExpanded ? nil : quest.id
            }
        }
    }

    // MARK: - Resource Row

    private func resourceRow(_ quest: QuestItem) -> some View {
        HStack(spacing: 6) {
            if quest.wood > 0 { resourceChip("Holz", value: quest.wood, color: .brown) }
            if quest.clay > 0 { resourceChip("Lehm", value: quest.clay, color: .orange) }
            if quest.iron > 0 { resourceChip("Eisen", value: quest.iron, color: Color(.systemGray)) }
            if quest.crop > 0 { resourceChip("Getreide", value: quest.crop, color: .yellow) }
            Spacer(minLength: 0)
        }
    }

    private func resourceChip(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(shortRes(value))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func tribeBadge(_ tribe: QuestTribeFilter) -> some View {
        Text(tribe.shortLabel)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tribe.color.opacity(0.15))
            .foregroundStyle(tribe.color)
            .clipShape(Capsule())
    }

    // MARK: - Filtering

    private var filteredQuests: [QuestItem] {
        let base: [QuestItem]
        if let giver = selectedGiver {
            switch giver {
            case .wren:      base = Self.wrenQuests
            case .markus:    base = Self.markusQuests
            case .chieftain: base = Self.chieftainQuests
            }
        } else {
            base = Self.wrenQuests + Self.markusQuests + Self.chieftainQuests
        }

        var result = base

        // Tribe filter
        if tribeFilter != .all {
            result = result.filter { $0.tribe == .all || $0.tribe == tribeFilter }
        }

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.requires.lowercased().contains(q) ||
                $0.other.lowercased().contains(q)
            }
        }

        return result
    }

    // MARK: - Helpers

    private func shortRes(_ v: Int) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 10_000 { return String(format: "%.0fk", Double(v) / 1_000) }
        if v >= 1_000 { return String(format: "%.1fk", Double(v) / 1_000) }
        return "\(v)"
    }
}

// MARK: - Data Types

private enum QuestGiver: String, CaseIterable {
    case wren, markus, chieftain

    var title: String {
        switch self {
        case .wren:      return "Wren"
        case .markus:    return "Markus"
        case .chieftain: return "Häuptling"
        }
    }

    var icon: String {
        switch self {
        case .wren:      return "leaf.fill"
        case .markus:    return "shield.fill"
        case .chieftain: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .wren:      return .green
        case .markus:    return .red
        case .chieftain: return .orange
        }
    }
}

enum QuestTribeFilter: String, CaseIterable {
    case all, romans, gauls, teutons, king, governor

    var label: String {
        switch self {
        case .all:       return "Alle"
        case .romans:    return "Römer"
        case .gauls:     return "Gallier"
        case .teutons:   return "Germanen"
        case .king:      return "König"
        case .governor:  return "Statthalter"
        }
    }

    var shortLabel: String {
        switch self {
        case .all:       return "Alle"
        case .romans:    return "ROM"
        case .gauls:     return "GAL"
        case .teutons:   return "GER"
        case .king:      return "König"
        case .governor:  return "Statthalter"
        }
    }

    var color: Color {
        switch self {
        case .all:       return .primary
        case .romans:    return .red
        case .gauls:     return .green
        case .teutons:   return .blue
        case .king:      return .orange
        case .governor:  return .purple
        }
    }
}

private struct QuestItem: Identifiable {
    let id: String
    let title: String
    let desc: String
    let requires: String
    let wood: Int
    let clay: Int
    let iron: Int
    let crop: Int
    let other: String
    let tribe: QuestTribeFilter

    var hasResources: Bool { wood > 0 || clay > 0 || iron > 0 || crop > 0 }

    var giver: QuestGiver? {
        if id.hasPrefix("w") { return .wren }
        if id.hasPrefix("m") { return .markus }
        if id.hasPrefix("c") { return .chieftain }
        return nil
    }

    init(_ title: String, desc: String = "", requires: String = "",
         wood: Int = 0, clay: Int = 0, iron: Int = 0, crop: Int = 0,
         other: String = "", tribe: QuestTribeFilter = .all, idPrefix: String = "") {
        self.id = idPrefix + title + tribe.rawValue
        self.title = title
        self.desc = desc
        self.requires = requires
        self.wood = wood
        self.clay = clay
        self.iron = iron
        self.crop = crop
        self.other = other
        self.tribe = tribe
    }
}

// MARK: - Quest Data

extension QuestsGuideView {

    // ── WREN (42 Quests) ──

    fileprivate static let wrenQuests: [QuestItem] = [
        QuestItem("Je ein Feld auf 1", desc: "Baue je ein Rohstofffeld von Holz, Lehm und Eisen auf Stufe 1 aus.", wood: 150, clay: 150, iron: 100, crop: 50, idPrefix: "w"),
        QuestItem("Errichte einen Kornspeicher", desc: "Damit erhöhst du die maximale Menge an Getreide, die dein Dorf lagern kann.", crop: 500, idPrefix: "w"),
        QuestItem("Getreidefeld bis Stufe 1", desc: "Baue alle Getreidefelder auf Stufe 1 aus.", wood: 260, clay: 350, iron: 260, crop: 70, idPrefix: "w"),
        QuestItem("Rohstofflager bauen", desc: "Erhöht die maximale Menge an Holz, Lehm und Eisen.", wood: 300, clay: 300, iron: 300, idPrefix: "w"),
        QuestItem("Lehmgruben auf 1", wood: 150, clay: 350, iron: 50, crop: 100, idPrefix: "w"),
        QuestItem("Holzfäller auf 1", wood: 100, clay: 250, iron: 120, crop: 150, idPrefix: "w"),
        QuestItem("Eisenminen auf Stufe 1", wood: 260, clay: 210, iron: 60, crop: 150, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 2", requires: "Getreidefeld bis Stufe 1", wood: 1000, clay: 1400, iron: 1000, crop: 350, idPrefix: "w"),
        QuestItem("Je ein Feld auf 2", requires: "Je ein Feld auf 1", wood: 350, clay: 350, iron: 300, crop: 300, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder 2", requires: "Je ein Feld auf 2", wood: 975, clay: 1000, iron: 1050, crop: 750, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 3", requires: "Alle Getreidefelder 2", wood: 1200, clay: 1500, iron: 1200, crop: 500, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder auf 3", requires: "Alle Rohstofffelder 2", wood: 1200, clay: 1200, iron: 1000, crop: 750, idPrefix: "w"),
        QuestItem("Rohstofflager Stufe 3", requires: "Rohstofflager bauen", wood: 500, clay: 600, iron: 360, idPrefix: "w"),
        QuestItem("Ein Getreidefeld auf Stufe 5", requires: "Alle Getreidefelder 3", wood: 625, clay: 800, iron: 600, crop: 200, idPrefix: "w"),
        QuestItem("Kornspeicher Stufe 3", requires: "Errichte einen Kornspeicher", wood: 300, clay: 400, iron: 250, idPrefix: "w"),
        QuestItem("Je ein Feld auf 5", requires: "Je ein Feld auf 2", wood: 2400, clay: 2400, iron: 2400, crop: 2400, idPrefix: "w"),
        QuestItem("Getreidemühle bauen", desc: "Gibt einen Bonus auf deine Getreideproduktion.", requires: "Ein Getreidefeld auf Stufe 5", crop: 1400, idPrefix: "w"),
        QuestItem("Rohstofflager Stufe 5", requires: "Rohstofflager Stufe 3", wood: 700, clay: 800, iron: 400, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder auf 5", requires: "Je ein Feld auf 5", wood: 5000, clay: 5000, iron: 4000, crop: 4000, idPrefix: "w"),
        QuestItem("Kornspeicher Stufe 5", requires: "Kornspeicher Stufe 3", wood: 300, clay: 400, iron: 250, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 5", requires: "Ein Getreidefeld auf Stufe 5", wood: 3000, clay: 4000, iron: 3000, crop: 1000, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder auf 7", requires: "Alle Rohstofffelder auf 5", wood: 11500, clay: 12000, iron: 8000, crop: 7000, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 7", requires: "Alle Getreidefelder 5", wood: 5000, clay: 6000, iron: 5000, crop: 1500, idPrefix: "w"),
        QuestItem("Rohstofflager Stufe 10", requires: "Rohstofflager Stufe 5", other: "Rohstofflager Stufe 12", idPrefix: "w"),
        QuestItem("Kornspeicher Stufe 10", requires: "Kornspeicher Stufe 5", wood: 500, clay: 550, iron: 400, idPrefix: "w"),
        QuestItem("Lehmgrube Stufe 10", requires: "Alle Rohstofffelder auf 7", wood: 5000, clay: 2500, iron: 5000, crop: 3333, idPrefix: "w"),
        QuestItem("Holzfäller Stufe 10", requires: "Alle Rohstofffelder auf 7", wood: 2500, clay: 6000, iron: 3500, crop: 4000, idPrefix: "w"),
        QuestItem("Eisenmine bis Level 10", requires: "Alle Rohstofffelder auf 7", wood: 6000, clay: 5000, iron: 1500, crop: 3500, idPrefix: "w"),
        QuestItem("Lehmbrennerei bauen", desc: "Bonus auf Lehmproduktion.", requires: "Lehmgrube Stufe 10", clay: 1000, idPrefix: "w"),
        QuestItem("Sägewerk bauen", desc: "Bonus auf Holzproduktion.", requires: "Holzfäller Stufe 10", wood: 1000, idPrefix: "w"),
        QuestItem("Eisengießerei bauen", desc: "Bonus auf Eisenproduktion.", requires: "Eisenmine bis Level 10", iron: 1000, idPrefix: "w"),
        QuestItem("Getreidefeld Stufe 10", requires: "Alle Getreidefelder 7", wood: 4500, clay: 5500, iron: 4500, crop: 1000, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder auf 10", requires: "Alle Rohstofffelder auf 7", wood: 30000, clay: 30000, iron: 20000, crop: 25000, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 10", requires: "Getreidefeld Stufe 10", wood: 25000, clay: 30000, iron: 25000, crop: 7000, idPrefix: "w"),
        QuestItem("Eine Bäckerei bauen", desc: "Bonus auf Getreideproduktion.", requires: "Getreidefeld Stufe 10", crop: 7000, idPrefix: "w"),
        QuestItem("Alle Rohstofffelder auf 12", requires: "Alle Rohstofffelder auf 10", wood: 66000, clay: 66000, iron: 33000, crop: 44000, idPrefix: "w"),
        QuestItem("Alle Getreidefelder 12", requires: "Alle Getreidefelder 10", wood: 33000, clay: 35000, iron: 30000, crop: 10000, idPrefix: "w"),
        QuestItem("Felder auf 10 in 5 Dörfern", requires: "Alle Rohstofffelder auf 10", wood: 100000, clay: 100000, iron: 100000, idPrefix: "w"),
        QuestItem("Getreidefelder auf 10 in 5", crop: 100000, idPrefix: "w"),
        QuestItem("Felder auf 10 in 12 Dörfern", requires: "Felder auf 10 in 5 Dörfern", wood: 150000, clay: 150000, iron: 150000, idPrefix: "w"),
        QuestItem("Getreidefelder auf 10 in 12", requires: "Getreidefelder auf 10 in 5", crop: 150000, idPrefix: "w"),
        QuestItem("Sofort fertig machen", desc: "Stelle den Bau eines Gebäudes sofort fertig.", other: "3 Gold", idPrefix: "w"),
    ]

    // ── MARKUS (68 Quests) ──

    fileprivate static let markusQuests: [QuestItem] = [
        QuestItem("Tutorial beenden", wood: 25, clay: 25, iron: 25, crop: 25, idPrefix: "m"),
        QuestItem("Benenne dein Dorf um", desc: "Im Hauptgebäude.", wood: 50, clay: 75, iron: 25, crop: 100, idPrefix: "m"),
        QuestItem("5 Einheiten", desc: "Bilde 5 Einheiten in der Kaserne aus.", wood: 550, clay: 350, iron: 650, tribe: .romans, idPrefix: "m"),
        QuestItem("5 Einheiten", desc: "Bilde 5 Einheiten in der Kaserne aus.", wood: 450, clay: 550, iron: 250, tribe: .gauls, idPrefix: "m"),
        QuestItem("5 Einheiten", desc: "Bilde 5 Einheiten in der Kaserne aus.", wood: 475, clay: 325, iron: 175, tribe: .teutons, idPrefix: "m"),
        QuestItem("Sammle einen Tribut", desc: "Hole Tribute von deinen Statthaltern ab.", requires: "König", other: "35 XP", tribe: .king, idPrefix: "m"),
        QuestItem("Verkaufe Diebesgut", requires: "Statthalter", other: "35 SP", tribe: .governor, idPrefix: "m"),
        QuestItem("Eine Botschaft bauen", desc: "Ermöglicht Oasen zuzuweisen und Allianzen beizutreten.", wood: 150, clay: 100, iron: 120, crop: 60, idPrefix: "m"),
        QuestItem("Tiere fangen", desc: "Fange Tiere in wilden Oasen mit Käfigen.", requires: "3 Abenteuer", wood: 150, clay: 200, iron: 110, crop: 90, idPrefix: "m"),
        QuestItem("Kaserne Stufe 3", desc: "Höheres Level = schnellere Ausbildung.", wood: 600, clay: 350, iron: 700, crop: 300, idPrefix: "m"),
        QuestItem("Baue eine Akademie", requires: "Kaserne Stufe 3", other: "Sofort beenden", idPrefix: "m"),
        QuestItem("3 Diebesgut verkaufen", requires: "Verkaufe Diebesgut", other: "50 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("25 Einheiten", requires: "5 Einheiten", wood: 1500, clay: 900, iron: 1600, tribe: .romans, idPrefix: "m"),
        QuestItem("25 Einheiten", requires: "5 Einheiten", wood: 1050, clay: 1300, iron: 600, tribe: .gauls, idPrefix: "m"),
        QuestItem("25 Einheiten", requires: "5 Einheiten", wood: 1200, clay: 1000, iron: 500, tribe: .teutons, idPrefix: "m"),
        QuestItem("Akademie Stufe 5", requires: "Baue eine Akademie", wood: 1300, clay: 1000, iron: 600, crop: 300, idPrefix: "m"),
        QuestItem("Schmiede Stufe 3", requires: "Akademie Stufe 5", wood: 500, clay: 700, iron: 1000, crop: 300, idPrefix: "m"),
        QuestItem("Stall 1", desc: "Im Stall kannst du Kavallerie ausbilden.", requires: "Schmiede Stufe 3", wood: 200, clay: 120, iron: 150, crop: 100, idPrefix: "m"),
        QuestItem("Erforschung Equites Legati", requires: "Stall 1", wood: 600, clay: 500, iron: 200, tribe: .romans, idPrefix: "m"),
        QuestItem("Erforschung Späher", requires: "Stall 1", wood: 700, clay: 500, iron: 300, tribe: .gauls, idPrefix: "m"),
        QuestItem("Erforschung Kundschafter", requires: "Stall 1", wood: 700, clay: 500, iron: 300, tribe: .teutons, idPrefix: "m"),
        QuestItem("Baue 5 Equites Legati", requires: "Erforschung Equites Legati", wood: 350, clay: 400, iron: 25, tribe: .romans, idPrefix: "m"),
        QuestItem("Baue 5 Späher", requires: "Erforschung Späher", wood: 450, clay: 200, iron: 75, tribe: .gauls, idPrefix: "m"),
        QuestItem("Baue 5 Kundschafter", requires: "Erforschung Kundschafter", wood: 450, clay: 250, iron: 50, tribe: .teutons, idPrefix: "m"),
        QuestItem("Spionage durchführen", desc: "Spioniere ein Dorf oder eine Oase aus.", other: "100 XP", idPrefix: "m"),
        QuestItem("100 Einheiten", requires: "25 Einheiten", wood: 5000, clay: 3000, iron: 6000, tribe: .romans, idPrefix: "m"),
        QuestItem("100 Einheiten", requires: "25 Einheiten", wood: 4000, clay: 5000, iron: 2000, tribe: .gauls, idPrefix: "m"),
        QuestItem("100 Einheiten", requires: "25 Einheiten", wood: 4200, clay: 3200, iron: 1800, tribe: .teutons, idPrefix: "m"),
        QuestItem("10 Tribute abholen", requires: "Sammle 3 Tribute", other: "100 XP", tribe: .king, idPrefix: "m"),
        QuestItem("10 Diebesgut verkaufen", requires: "Verkaufe Diebesgut", other: "100 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("250 Einheiten", requires: "100 Einheiten", wood: 10000, clay: 6000, iron: 14000, tribe: .romans, idPrefix: "m"),
        QuestItem("250 Einheiten", requires: "100 Einheiten", wood: 8000, clay: 12000, iron: 4000, tribe: .gauls, idPrefix: "m"),
        QuestItem("250 Einheiten", requires: "100 Einheiten", wood: 9000, clay: 7000, iron: 3500, tribe: .teutons, idPrefix: "m"),
        QuestItem("Werkstatt bauen", desc: "Baue Katapulte und Rammen.", requires: "Akademie Stufe 5", wood: 200, clay: 2000, iron: 200, idPrefix: "m"),
        QuestItem("10 Belagerungseinheiten", requires: "Werkstatt bauen", wood: 5000, clay: 1000, iron: 1000, crop: 1000, idPrefix: "m"),
        QuestItem("50 Tribute abholen", requires: "10 Tribute", other: "200 XP", tribe: .king, idPrefix: "m"),
        QuestItem("50 Diebesgut verkaufen", requires: "10 Diebesgut", other: "200 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("500 Einheiten", requires: "250 Einheiten", wood: 15000, clay: 9000, iron: 20000, tribe: .romans, idPrefix: "m"),
        QuestItem("500 Einheiten", requires: "250 Einheiten", wood: 10000, clay: 17000, iron: 6000, tribe: .gauls, idPrefix: "m"),
        QuestItem("500 Einheiten", requires: "250 Einheiten", wood: 12500, clay: 10000, iron: 5000, tribe: .teutons, idPrefix: "m"),
        QuestItem("1.000 Einheiten", requires: "500 Einheiten", wood: 30000, clay: 18500, iron: 37500, tribe: .romans, idPrefix: "m"),
        QuestItem("1.000 Einheiten", requires: "500 Einheiten", wood: 22500, clay: 26000, iron: 11250, tribe: .gauls, idPrefix: "m"),
        QuestItem("1.000 Einheiten", requires: "500 Einheiten", wood: 25000, clay: 18500, iron: 9000, tribe: .teutons, idPrefix: "m"),
        QuestItem("100 Tribute abholen", requires: "50 Tribute", other: "300 XP", tribe: .king, idPrefix: "m"),
        QuestItem("100 Diebesgut verkaufen", requires: "50 Diebesgut", other: "300 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("3.000 Einheiten", requires: "1.000 Einheiten", wood: 33333, clay: 16666, iron: 33333, tribe: .romans, idPrefix: "m"),
        QuestItem("3.000 Einheiten", requires: "1.000 Einheiten", wood: 23333, clay: 30000, iron: 13333, tribe: .gauls, idPrefix: "m"),
        QuestItem("3.000 Einheiten", requires: "1.000 Einheiten", wood: 26666, clay: 20000, iron: 10000, tribe: .teutons, idPrefix: "m"),
        QuestItem("10.000 Einheiten", requires: "3.000 Einheiten", wood: 66666, clay: 33333, iron: 66666, tribe: .romans, idPrefix: "m"),
        QuestItem("10.000 Einheiten", requires: "3.000 Einheiten", wood: 46666, clay: 60000, iron: 26666, tribe: .gauls, idPrefix: "m"),
        QuestItem("10.000 Einheiten", requires: "3.000 Einheiten", wood: 53333, clay: 40000, iron: 20000, tribe: .teutons, idPrefix: "m"),
        QuestItem("30.000 Einheiten", requires: "10.000 Einheiten", wood: 88888, clay: 55555, iron: 88888, tribe: .romans, idPrefix: "m"),
        QuestItem("30.000 Einheiten", requires: "10.000 Einheiten", wood: 66666, clay: 80000, iron: 33333, tribe: .gauls, idPrefix: "m"),
        QuestItem("30.000 Einheiten", requires: "10.000 Einheiten", wood: 77777, clay: 60000, iron: 40000, tribe: .teutons, idPrefix: "m"),
        QuestItem("300 Tribute abholen", requires: "100 Tribute", other: "400 XP", tribe: .king, idPrefix: "m"),
        QuestItem("300 Diebesgut verkaufen", requires: "100 Diebesgut", other: "200 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("1.000 Tribute abholen", requires: "300 Tribute", other: "500 XP", tribe: .king, idPrefix: "m"),
        QuestItem("1.000 Diebesgut verkaufen", requires: "300 Diebesgut", other: "500 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("100.000 Einheiten", requires: "30.000 Einheiten", wood: 100000, clay: 70000, iron: 100000, tribe: .romans, idPrefix: "m"),
        QuestItem("100.000 Einheiten", requires: "30.000 Einheiten", wood: 88888, clay: 90000, iron: 50000, tribe: .gauls, idPrefix: "m"),
        QuestItem("100.000 Einheiten", requires: "30.000 Einheiten", wood: 90000, clay: 75000, iron: 55555, tribe: .teutons, idPrefix: "m"),
        QuestItem("3.000 Tribute abholen", requires: "1.000 Tribute", other: "1000 XP", tribe: .king, idPrefix: "m"),
        QuestItem("3.000 Diebesgut verkaufen", requires: "1.000 Diebesgut", other: "1000 XP", tribe: .governor, idPrefix: "m"),
        QuestItem("Unterstütze einen Spieler", desc: "Unterstütze einen anderen Spieler mit Truppen.", other: "65 XP", idPrefix: "m"),
        QuestItem("Versteck bauen", desc: "Schützt Rohstoffe vor Angreifern.", wood: 70, clay: 50, iron: 50, idPrefix: "m"),
        QuestItem("Versteck auf Stufe 5", wood: 150, clay: 200, iron: 115, crop: 50, idPrefix: "m"),
        QuestItem("Angriff auf Räuberversteck", desc: "Rohstoffe und Diebesgut erbeuten.", requires: "Statthalter", wood: 500, clay: 500, iron: 500, crop: 500, tribe: .governor, idPrefix: "m"),
        QuestItem("Oase zuordnen", desc: "Ordne eine Oase deinem Dorf zu.", requires: "Botschaft", wood: 400, clay: 350, iron: 250, crop: 150, idPrefix: "m"),
    ]

    // ── HÄUPTLING (48 Quests) ──

    fileprivate static let chieftainQuests: [QuestItem] = [
        QuestItem("Schutt abtragen", desc: "Trage den Schutt eines zerstörten Gebäudes ab.", wood: 50, clay: 50, iron: 100, crop: 50, idPrefix: "c"),
        QuestItem("Abenteuer", desc: "Lass deinen Helden ein Abenteuer erleben.", other: "25 XP", idPrefix: "c"),
        QuestItem("Ein Pferd ausrüsten", desc: "Lege das Pferd im Heldeninventar an.", requires: "Abenteuer", wood: 120, clay: 150, iron: 80, crop: 140, idPrefix: "c"),
        QuestItem("Einen Marktplatz aufbauen", desc: "Ermöglicht Handel mit anderen Spielern.", wood: 50, clay: 50, iron: 100, crop: 50, idPrefix: "c"),
        QuestItem("Mit Rohstoffen handeln", requires: "Einen Marktplatz aufbauen", other: "NPC-Händler", idPrefix: "c"),
        QuestItem("Heldenproduktion", desc: "Wähle einen Ressourcentyp für deinen Helden.", other: "700 Rohstoffe (Wahl)", idPrefix: "c"),
        QuestItem("NPC-Händler", requires: "Einen Marktplatz aufbauen", wood: 125, clay: 150, iron: 70, crop: 100, idPrefix: "c"),
        QuestItem("Gegenstand verkaufen", desc: "Verkaufe einen Gegenstand im Auktionshaus.", other: "500 Silber", idPrefix: "c"),
        QuestItem("Biete auf etwas", desc: "Biete auf etwas im Auktionshaus.", other: "2 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("3 Abenteuer", requires: "Abenteuer", other: "75 XP", idPrefix: "c"),
        QuestItem("10 Abenteuer", requires: "3 Abenteuer", other: "100 XP", idPrefix: "c"),
        QuestItem("Held Stufe 5", desc: "Sammle Erfahrung durch Abenteuer und Kämpfe.", other: "3 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("20 Abenteuer", requires: "10 Abenteuer", other: "125 XP", idPrefix: "c"),
        QuestItem("Residenz/Palast bauen", desc: "Ermöglicht die Gründung weiterer Dörfer.", wood: 5000, clay: 3500, iron: 3500, crop: 4000, idPrefix: "c"),
        QuestItem("Residenz/Palast Stufe 5", desc: "Ermöglicht Siedler auszubilden.", requires: "Residenz/Palast bauen", other: "Residenz Stufe 10", idPrefix: "c"),
        QuestItem("3 Siedler ausbilden", requires: "Residenz/Palast Stufe 5", wood: 5000, clay: 4000, iron: 6000, tribe: .romans, idPrefix: "c"),
        QuestItem("3 Siedler ausbilden", requires: "Residenz/Palast Stufe 5", wood: 4500, clay: 6000, iron: 4500, tribe: .gauls, idPrefix: "c"),
        QuestItem("3 Siedler ausbilden", requires: "Residenz/Palast Stufe 5", wood: 6000, clay: 5000, iron: 4000, tribe: .teutons, idPrefix: "c"),
        QuestItem("Volle Ausrüstung", desc: "Rüste deinen Helden komplett aus (Helm, Rüstung, Schuhe, L+R Hand).", other: "150 XP", idPrefix: "c"),
        QuestItem("Marktplatz bis Stufe 5", requires: "Einen Marktplatz aufbauen", wood: 200, clay: 200, iron: 333, crop: 150, idPrefix: "c"),
        QuestItem("Neues Dorf gefunden", desc: "Gründe ein neues Dorf.", requires: "3 Siedler ausbilden", wood: 3500, clay: 3500, iron: 3500, crop: 1000, idPrefix: "c"),
        QuestItem("Rohstoffe abschicken", requires: "Neues Dorf gefunden", other: "Instant Händler", idPrefix: "c"),
        QuestItem("Sofortlieferung", desc: "Benutze Sofortlieferung für Rohstoffe zum 2. Dorf.", requires: "Rohstoffe abschicken", wood: 700, clay: 1000, iron: 1300, crop: 300, idPrefix: "c"),
        QuestItem("Errichte ein Rathaus", desc: "Ermöglicht Feste für Kulturpunkte.", requires: "Neues Dorf gefunden", other: "800 Kulturpunkte", idPrefix: "c"),
        QuestItem("Kleines Fest", desc: "Feiere ein kleines Fest für Kulturpunkte.", requires: "Errichte ein Rathaus", other: "500 Kulturpunkte", idPrefix: "c"),
        QuestItem("Held Stufe 10", requires: "Held Stufe 5", other: "3 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("33 Abenteuer", requires: "20 Abenteuer", other: "250 XP", idPrefix: "c"),
        QuestItem("Stadt oder neues Dorf", requires: "Neues Dorf gefunden", wood: 6000, clay: 7500, iron: 5000, idPrefix: "c"),
        QuestItem("50 Abenteuer", requires: "33 Abenteuer", other: "350 XP", idPrefix: "c"),
        QuestItem("Großes Fest", desc: "Feiere ein großes Fest für Kulturpunkte.", requires: "Kleines Fest", wood: 10000, clay: 11000, iron: 11000, crop: 1500, other: "2000 Kulturpunkte", idPrefix: "c"),
        QuestItem("Held Stufe 25", requires: "Held Stufe 10", other: "4 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("Held Stufe 50", requires: "Held Stufe 25", other: "5 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("Besitze 5 Dörfer", requires: "Stadt oder neues Dorf", wood: 9500, clay: 7000, iron: 8000, idPrefix: "c"),
        QuestItem("100 Abenteuer", requires: "50 Abenteuer", other: "750 XP", idPrefix: "c"),
        QuestItem("Held Stufe 100", requires: "Held Stufe 50", other: "6 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("Besitze 10 Dörfer", requires: "Besitze 5 Dörfer", wood: 18000, clay: 22000, iron: 12000, idPrefix: "c"),
        QuestItem("Besitze 15 Dörfer", requires: "Besitze 10 Dörfer", wood: 24000, clay: 27000, iron: 16000, idPrefix: "c"),
        QuestItem("200 Abenteuer", requires: "100 Abenteuer", other: "1000 XP", idPrefix: "c"),
        QuestItem("Held Stufe 150", requires: "Held Stufe 100", other: "7 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("350 Abenteuer", requires: "200 Abenteuer", other: "2000 XP", idPrefix: "c"),
        QuestItem("Besitze 20 Dörfer", requires: "Besitze 15 Dörfer", wood: 30000, clay: 32000, iron: 20000, idPrefix: "c"),
        QuestItem("Held Stufe 200", requires: "Held Stufe 150", other: "8 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("500 Abenteuer", requires: "350 Abenteuer", other: "3000 XP", idPrefix: "c"),
        QuestItem("Held Stufe 250", requires: "Held Stufe 200", other: "10 Abenteuerpunkte", idPrefix: "c"),
        QuestItem("Einen Herzog fördern", desc: "Befördere einen Statthalter zum Herzog.", requires: "König", other: "40 XP", tribe: .king, idPrefix: "c"),
        QuestItem("Verbessere deinen Held", desc: "Verteile Attributspunkte.", wood: 150, clay: 150, iron: 100, crop: 75, idPrefix: "c"),
        QuestItem("Heile deinen Helden", desc: "Benutze Salben um Gesundheit wiederherzustellen.", other: "30 XP", idPrefix: "c"),
        QuestItem("Einen Spieler einladen", desc: "Lade einen Statthalter in dein Königreich ein.", requires: "König", other: "55 XP", tribe: .king, idPrefix: "c"),
    ]
}
