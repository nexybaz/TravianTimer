import SwiftUI

// MARK: - Held Konfigurator

struct HeroConfiguratorView: View {

    @Environment(AuthService.self) var authService
    @State private var heroStore = HeroStore.shared
    @State private var tierService = ItemTierService.shared

    var body: some View {
        List {
            // MARK: Grundwerte
            Section("Grundwerte") {
                HStack {
                    Label("Level", systemImage: "star.fill")
                    Spacer()
                    TextField("1", value: $heroStore.config.level, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Label("HP", systemImage: "heart.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("100", value: $heroStore.config.hp, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Label("Erfahrung", systemImage: "sparkles")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("0", value: $heroStore.config.xp, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // MARK: Fähigkeitspunkte
            Section {
                // Status-Zeile
                HStack {
                    Text("Verfügbar")
                        .font(.subheadline)
                    Spacer()
                    let remaining = heroStore.config.remainingSkillPoints
                    let total = heroStore.config.availableSkillPoints
                    let used = heroStore.config.totalSkillPoints
                    Text("\(used) / \(total) vergeben")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(remaining >= 0 ? .green : .red)
                    if remaining > 0 {
                        Text("(\(remaining) frei)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                skillRow(
                    label: "Kampfkraft",
                    icon: "bolt.fill",
                    color: .red,
                    value: $heroStore.config.skillFight,
                    computed: "\(heroStore.config.skillFight * 80) KK"
                )

                skillRow(
                    label: "Off-Bonus",
                    icon: "arrow.up.right",
                    color: .orange,
                    value: $heroStore.config.skillOff,
                    computed: String(format: "%.1f%%", Double(heroStore.config.skillOff) * 0.2)
                )

                skillRow(
                    label: "Def-Bonus",
                    icon: "shield.fill",
                    color: .blue,
                    value: $heroStore.config.skillDef,
                    computed: String(format: "%.1f%%", Double(heroStore.config.skillDef) * 0.2)
                )

                skillRow(
                    label: "Ressourcen",
                    icon: "leaf.fill",
                    color: .green,
                    value: $heroStore.config.skillRes,
                    computed: "\(heroStore.config.skillRes * 20) /h"
                )
            } header: {
                Text("Fähigkeitspunkte")
            }

            // MARK: Ausrüstung
            Section("Ausrüstung") {
                ForEach(EquipmentSlot.allCases) { slot in
                    NavigationLink {
                        EquipmentPickerView(
                            slot: slot,
                            tribe: currentTribe,
                            selectedPiece: equipmentBinding(for: slot)
                        )
                    } label: {
                        HStack {
                            Image(systemName: slot.icon)
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            Text(slot.title)
                            Spacer()
                            if let piece = heroStore.config.piece(for: slot) {
                                Text(equipmentDisplayName(slot: slot, piece: piece))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("Leer")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            // MARK: Gesamtboni
            let summary = bonusSummary
            Section("Kampf") {
                bonusRow(icon: "bolt.fill", color: .red,
                         label: "Kampfkraft", value: "\(summary.kampfkraft)")
                bonusRow(icon: "arrow.up.right", color: .orange,
                         label: "Off-Bonus", value: String(format: "+%.1f%%", summary.offBonusPercent))
                bonusRow(icon: "shield.fill", color: .blue,
                         label: "Def-Bonus", value: String(format: "+%.1f%%", summary.defBonusPercent))
                if let tb = summary.troopBonus {
                    bonusRow(icon: "person.3.fill", color: .purple,
                             label: tb.troopName, value: "+\(tb.attackPerTroop)/+\(tb.defensePerTroop) pro Truppe")
                }
            }

            Section("Wirtschaft") {
                bonusRow(icon: "leaf.fill", color: .green,
                         label: "Ressourcen", value: "+\(summary.resourceBonusPerHour) /h")
                if summary.kulturpunktePerDay > 0 {
                    bonusRow(icon: "star.fill", color: .purple,
                             label: "Kulturpunkte", value: "+\(summary.kulturpunktePerDay) /Tag")
                }
            }

            Section("Geschwindigkeit") {
                if summary.heroSpeed > 0 {
                    bonusRow(icon: "hare.fill", color: .brown,
                             label: "Held-Geschwindigkeit", value: "\(summary.heroSpeed) Felder/h")
                    bonusRow(icon: "figure.equestrian.sports", color: .brown,
                             label: "Typ", value: summary.isCavalry ? "Kavallerie" : "Infanterie")
                }
                if summary.speedBonusPercent > 0 {
                    bonusRow(icon: "figure.run", color: .green,
                             label: "Speed-Bonus (>20F)", value: "+\(summary.speedBonusPercent)%")
                }
                if summary.spursBonusPerHour > 0 {
                    bonusRow(icon: "hare.fill", color: .blue,
                             label: "Pferdesporen", value: "+\(summary.spursBonusPerHour) Felder/h")
                }
            }

            if hasSpecialBonuses(summary) {
                Section("Spezial") {
                    if summary.hpRegenPerDay > 0 {
                        bonusRow(icon: "heart.fill", color: .red,
                                 label: "HP-Regeneration", value: "+\(summary.hpRegenPerDay) /Tag")
                    }
                    if summary.xpBonusPercent > 0 {
                        bonusRow(icon: "sparkles", color: .purple,
                                 label: "XP-Bonus", value: "+\(summary.xpBonusPercent)%")
                    }
                    if summary.barracksReductionPercent != 0 {
                        bonusRow(icon: "figure.walk", color: .orange,
                                 label: "Kaserne", value: "\(summary.barracksReductionPercent)%")
                    }
                    if summary.stableReductionPercent != 0 {
                        bonusRow(icon: "hare.fill", color: .blue,
                                 label: "Stall", value: "\(summary.stableReductionPercent)%")
                    }
                    if summary.plunderBonusPercent > 0 {
                        bonusRow(icon: "bag.fill", color: .brown,
                                 label: "Plünderung", value: "+\(summary.plunderBonusPercent)%")
                    }
                    if summary.returnSpeedPercent > 0 {
                        bonusRow(icon: "arrow.uturn.backward", color: .teal,
                                 label: "Rückkehr-Speed", value: "+\(summary.returnSpeedPercent)%")
                    }
                    if summary.ownTransferPercent > 0 {
                        bonusRow(icon: "flag.fill", color: .indigo,
                                 label: "Eigene Dörfer", value: "+\(summary.ownTransferPercent)%")
                    }
                    if summary.allianceTransferPercent > 0 {
                        bonusRow(icon: "person.2.fill", color: .cyan,
                                 label: "Bündnis-Speed", value: "+\(summary.allianceTransferPercent)%")
                    }
                    if summary.evadeTroops > 0 {
                        bonusRow(icon: "figure.walk.motion", color: .orange,
                                 label: "Ausweich-Truppen", value: "\(summary.evadeTroops)")
                    }
                    if summary.natarBonusPercent > 0 {
                        bonusRow(icon: "shield.lefthalf.filled", color: .gray,
                                 label: "Vs. Nataren", value: "+\(summary.natarBonusPercent)%")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Konfigurator")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: heroStore.config) { _, _ in
            heroStore.save()
        }
        .task {
            if let worldId = authService.profile?.worldId, !worldId.isEmpty {
                await tierService.loadTierDates(worldId: worldId)
            }
        }
    }

    // MARK: - Helpers

    private var currentTribe: Tribe {
        Tribe.from(profileTribe: authService.profile?.tribe)
    }

    private var worldSpeed: Int {
        if let ws = authService.profile?.worldSpeed, let speed = Int(ws), speed > 0 {
            return speed
        }
        return tierService.worldSpeed > 0 ? tierService.worldSpeed : 1
    }

    private var bonusSummary: HeroBonusSummary {
        HeroBonusCalculator.calculate(config: heroStore.config, tribe: currentTribe, worldSpeed: worldSpeed)
    }

    private func equipmentBinding(for slot: EquipmentSlot) -> Binding<EquipmentPiece?> {
        Binding(
            get: { heroStore.config.piece(for: slot) },
            set: { newPiece in heroStore.config.setPiece(newPiece, for: slot) }
        )
    }

    private func equipmentDisplayName(slot: EquipmentSlot, piece: EquipmentPiece) -> String {
        switch slot {
        case .helm:
            return HelmetCategory(rawValue: piece.category)?.title ?? piece.category
        case .armor:
            return ArmorCategory(rawValue: piece.category)?.title ?? piece.category
        case .boots:
            return BootsCategory(rawValue: piece.category)?.title ?? piece.category
        case .horse:
            let tiers = HorseTier.allTiers(upTo: 3)
            return tiers.first(where: { $0.level == piece.tier })?.name ?? "Pferd"
        case .leftHand:
            return LeftHandCategory(rawValue: piece.category)?.title ?? piece.category
        case .rightHand:
            switch currentTribe {
            case .romans:  return RomanWeaponCategory(rawValue: piece.category)?.title ?? piece.category
            case .gauls:   return GaulWeaponCategory(rawValue: piece.category)?.title ?? piece.category
            case .teutons: return TeutonWeaponCategory(rawValue: piece.category)?.title ?? piece.category
            }
        }
    }

    private func hasSpecialBonuses(_ s: HeroBonusSummary) -> Bool {
        s.hpRegenPerDay > 0 || s.xpBonusPercent > 0 || s.barracksReductionPercent != 0 ||
        s.stableReductionPercent != 0 || s.plunderBonusPercent > 0 || s.returnSpeedPercent > 0 ||
        s.ownTransferPercent > 0 || s.allianceTransferPercent > 0 || s.evadeTroops > 0 ||
        s.natarBonusPercent > 0
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func skillRow(label: String, icon: String, color: Color, value: Binding<Int>, computed: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)

            Spacer()

            Text(computed)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Stepper("", value: value, in: 0...maxForSkill(value.wrappedValue))
                .labelsHidden()
                .frame(width: 100)
        }
    }

    private func maxForSkill(_ currentValue: Int) -> Int {
        currentValue + max(0, heroStore.config.remainingSkillPoints)
    }

    @ViewBuilder
    private func bonusRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}
