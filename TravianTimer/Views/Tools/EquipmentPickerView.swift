import SwiftUI

// MARK: - Equipment Picker

struct EquipmentPickerView: View {

    let slot: EquipmentSlot
    let tribe: Tribe
    @Binding var selectedPiece: EquipmentPiece?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Kein Gegenstand
            Section {
                Button {
                    selectedPiece = nil
                    dismiss()
                } label: {
                    HStack {
                        Label("Kein Gegenstand", systemImage: "xmark.circle")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedPiece == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }

            // Kategorien mit Tiers
            switch slot {
            case .helm:     helmSections
            case .armor:    armorSections
            case .boots:    bootsSections
            case .horse:    horseSections
            case .leftHand: leftHandSections
            case .rightHand: rightHandSections
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(slot.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helm

    @ViewBuilder
    private var helmSections: some View {
        ForEach(HelmetCategory.allCases) { cat in
            Section {
                ForEach(cat.tiers(upTo: 3)) { tier in
                    tierRow(
                        name: tier.name,
                        level: tier.level,
                        effect: tier.effect,
                        tierColor: tier.tierColor,
                        variantCount: tier.variantSteps.count,
                        piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                        variantSteps: tier.variantSteps,
                        baseValue: tier.baseValue,
                        unit: tier.unit,
                        prefix: tier.prefix
                    )
                }
            } header: {
                categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
            }
        }
    }

    // MARK: - Rüstung

    @ViewBuilder
    private var armorSections: some View {
        ForEach(ArmorCategory.allCases) { cat in
            Section {
                ForEach(cat.tiers(upTo: 3)) { tier in
                    tierRow(
                        name: tier.name,
                        level: tier.level,
                        effect: tier.effect,
                        tierColor: tier.tierColor,
                        variantCount: tier.variantSteps.count,
                        piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                        variantSteps: tier.variantSteps,
                        baseValue: tier.baseValue,
                        unit: tier.unit,
                        prefix: tier.prefix
                    )
                }
            } header: {
                categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
            }
        }
    }

    // MARK: - Schuhe

    @ViewBuilder
    private var bootsSections: some View {
        ForEach(BootsCategory.allCases) { cat in
            Section {
                ForEach(cat.tiers(upTo: 3)) { tier in
                    tierRow(
                        name: tier.name,
                        level: tier.level,
                        effect: tier.effect,
                        tierColor: tier.tierColor,
                        variantCount: tier.variantSteps.count,
                        piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                        variantSteps: tier.variantSteps,
                        baseValue: tier.baseValue,
                        unit: tier.unit,
                        prefix: tier.prefix
                    )
                }
            } header: {
                categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
            }
        }
    }

    // MARK: - Pferd

    @ViewBuilder
    private var horseSections: some View {
        Section {
            ForEach(HorseTier.allTiers(upTo: 3)) { tier in
                tierRow(
                    name: tier.name,
                    level: tier.level,
                    effect: tier.effect,
                    tierColor: tier.tierColor,
                    variantCount: tier.variantSteps.count,
                    piece: EquipmentPiece(category: "horse", tier: tier.level, variantIndex: 0),
                    variantSteps: tier.variantSteps,
                    baseValue: tier.baseValue,
                    unit: tier.unit,
                    prefix: "+"
                )
            }
        } header: {
            categoryHeader(title: "Reittiere", icon: "hare.fill", color: .brown)
        }
    }

    // MARK: - Linke Hand

    @ViewBuilder
    private var leftHandSections: some View {
        ForEach(LeftHandCategory.allCases) { cat in
            Section {
                ForEach(cat.tiers(upTo: 3)) { tier in
                    tierRow(
                        name: tier.name,
                        level: tier.level,
                        effect: tier.effect,
                        tierColor: tier.tierColor,
                        variantCount: tier.variantSteps.count,
                        piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                        variantSteps: tier.variantSteps,
                        baseValue: tier.baseValue,
                        unit: tier.unit,
                        prefix: tier.prefix
                    )
                }
            } header: {
                categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
            }
        }
    }

    // MARK: - Rechte Hand (tribe-spezifisch)

    @ViewBuilder
    private var rightHandSections: some View {
        switch tribe {
        case .romans:
            ForEach(RomanWeaponCategory.allCases) { cat in
                Section {
                    ForEach(cat.tiers(upTo: 3)) { tier in
                        weaponTierRow(
                            name: tier.name,
                            level: tier.level,
                            effectPrimary: tier.effectPrimary,
                            effectSecondary: tier.effectSecondary,
                            tierColor: tier.tierColor,
                            variantCount: tier.variantSteps.count,
                            piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                            variantSteps: tier.variantSteps,
                            heroStrength: tier.heroStrength
                        )
                    }
                } header: {
                    categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
                }
            }
        case .gauls:
            ForEach(GaulWeaponCategory.allCases) { cat in
                Section {
                    ForEach(cat.tiers(upTo: 3)) { tier in
                        weaponTierRow(
                            name: tier.name,
                            level: tier.level,
                            effectPrimary: tier.effectPrimary,
                            effectSecondary: tier.effectSecondary,
                            tierColor: tier.tierColor,
                            variantCount: tier.variantSteps.count,
                            piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                            variantSteps: tier.variantSteps,
                            heroStrength: tier.heroStrength
                        )
                    }
                } header: {
                    categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
                }
            }
        case .teutons:
            ForEach(TeutonWeaponCategory.allCases) { cat in
                Section {
                    ForEach(cat.tiers(upTo: 3)) { tier in
                        weaponTierRow(
                            name: tier.name,
                            level: tier.level,
                            effectPrimary: tier.effectPrimary,
                            effectSecondary: tier.effectSecondary,
                            tierColor: tier.tierColor,
                            variantCount: tier.variantSteps.count,
                            piece: EquipmentPiece(category: cat.rawValue, tier: tier.level, variantIndex: 0),
                            variantSteps: tier.variantSteps,
                            heroStrength: tier.heroStrength
                        )
                    }
                } header: {
                    categoryHeader(title: cat.title, icon: cat.icon, color: cat.color)
                }
            }
        }
    }

    // MARK: - Reusable Row Components

    private func categoryHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .textCase(nil)
    }

    @ViewBuilder
    private func tierRow(
        name: String,
        level: Int,
        effect: String,
        tierColor: Color,
        variantCount: Int,
        piece: EquipmentPiece,
        variantSteps: [Int],
        baseValue: Int,
        unit: String,
        prefix: String
    ) -> some View {
        let isSelected = selectedPiece?.category == piece.category && selectedPiece?.tier == piece.tier
        let currentVariant = isSelected ? (selectedPiece?.variantIndex ?? 0) : 0

        VStack(alignment: .leading, spacing: 8) {
            Button {
                if isSelected {
                    selectedPiece = nil
                } else {
                    selectedPiece = piece
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Stufe \(level)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(tierColor)
                                .clipShape(Capsule())
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text(effect)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Varianten-Auswahl (nur wenn selektiert und > 1 Variante)
            if isSelected && variantCount > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Variante (Rang \(currentVariant + 1)/\(variantCount))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("Variante", selection: Binding(
                        get: { currentVariant },
                        set: { newIdx in
                            selectedPiece = EquipmentPiece(category: piece.category, tier: piece.tier, variantIndex: newIdx)
                        }
                    )) {
                        ForEach(0..<variantCount, id: \.self) { idx in
                            let val = baseValue + variantSteps[idx]
                            Text(val > 0 ? "\(prefix)\(val)" : "\(val)")
                                .tag(idx)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.orange.opacity(0.08) : nil)
    }

    @ViewBuilder
    private func weaponTierRow(
        name: String,
        level: Int,
        effectPrimary: String,
        effectSecondary: String,
        tierColor: Color,
        variantCount: Int,
        piece: EquipmentPiece,
        variantSteps: [Int],
        heroStrength: Int
    ) -> some View {
        let isSelected = selectedPiece?.category == piece.category && selectedPiece?.tier == piece.tier
        let currentVariant = isSelected ? (selectedPiece?.variantIndex ?? 0) : 0

        VStack(alignment: .leading, spacing: 8) {
            Button {
                if isSelected {
                    selectedPiece = nil
                } else {
                    selectedPiece = piece
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Stufe \(level)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(tierColor)
                                .clipShape(Capsule())
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text(effectPrimary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(effectSecondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected && variantCount > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kampfkraft-Variante (Rang \(currentVariant + 1)/\(variantCount))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Picker("Variante", selection: Binding(
                        get: { currentVariant },
                        set: { newIdx in
                            selectedPiece = EquipmentPiece(category: piece.category, tier: piece.tier, variantIndex: newIdx)
                        }
                    )) {
                        ForEach(0..<variantCount, id: \.self) { idx in
                            let val = heroStrength + variantSteps[idx]
                            Text("+\(val)")
                                .tag(idx)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.orange.opacity(0.08) : nil)
    }
}
