import SwiftUI

// MARK: - Varianten-Picker (fuer eine Kategorie)

struct AvatarComponentPicker: View {
    let category: AvatarCategory
    @Binding var config: AvatarConfig
    let onSelect: () -> Void  // Wird bei jeder Aenderung aufgerufen (fuer Undo)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if category.isColorCategory {
                colorPaletteView
            } else {
                variantGridView
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Varianten-Grid

    private var variantGridView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // "Keiner" Option fuer Schmuck
                    if category == .schmuck {
                        noneButton
                    }

                    ForEach(0..<variantCount, id: \.self) { index in
                        Button {
                            onSelect()
                            setVariant(index)
                        } label: {
                            variantThumbnail(index: index)
                                .frame(width: 64, height: 64)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            isSelected(index) ? Color.orange : Color.clear,
                                            lineWidth: 2.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var noneButton: some View {
        Button {
            onSelect()
            config.accessory = -1
        } label: {
            VStack {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 64)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        config.accessory == -1 ? Color.orange : Color.clear,
                        lineWidth: 2.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Farb-Palette

    private var colorPaletteView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            let palette = paletteForCategory
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(palette, id: \.hex) { item in
                    Button {
                        onSelect()
                        setColor(item.hex)
                    } label: {
                        Circle()
                            .fill(Color(hex: item.hex))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isColorSelected(item.hex) ? Color.orange : Color.white.opacity(0.3),
                                        lineWidth: isColorSelected(item.hex) ? 3 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Thumbnail-Vorschauen

    @ViewBuilder
    private func variantThumbnail(index: Int) -> some View {
        let skinColor = Color(hex: config.skinColor)
        let hairColor = Color(hex: config.hairColor)
        let eyeColor = Color(hex: config.eyeColor)

        switch category {
        case .frisur:
            AvatarHairStyles(variant: index, hairColor: hairColor)
                .scaleEffect(0.45)
        case .augen:
            AvatarEyeStyles(variant: index, eyeColor: eyeColor)
                .scaleEffect(0.9)
        case .nase:
            AvatarNoseStyles(variant: index, skinColor: skinColor)
                .scaleEffect(1.2)
        case .mund:
            AvatarMouthStyles(variant: index)
                .scaleEffect(1.1)
        case .schmuck:
            AvatarAccessoryStyles(variant: index)
                .scaleEffect(0.5)
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var variantCount: Int {
        switch category {
        case .frisur:  return AvatarHairStyles.count
        case .augen:   return AvatarEyeStyles.count
        case .nase:    return AvatarNoseStyles.count
        case .mund:    return AvatarMouthStyles.count
        case .schmuck: return AvatarAccessoryStyles.count
        default:       return 0
        }
    }

    private func isSelected(_ index: Int) -> Bool {
        switch category {
        case .frisur:  return config.hairStyle == index
        case .augen:   return config.eyeStyle == index
        case .nase:    return config.noseStyle == index
        case .mund:    return config.mouthStyle == index
        case .schmuck: return config.accessory == index
        default:       return false
        }
    }

    private func setVariant(_ index: Int) {
        switch category {
        case .frisur:  config.hairStyle = index
        case .augen:   config.eyeStyle = index
        case .nase:    config.noseStyle = index
        case .mund:    config.mouthStyle = index
        case .schmuck: config.accessory = index
        default:       break
        }
    }

    private var paletteForCategory: [(name: String, hex: String)] {
        switch category {
        case .haarfarbe:  return AvatarColorPalette.hairColors
        case .augenfarbe: return AvatarColorPalette.eyeColors
        default:          return []
        }
    }

    private func isColorSelected(_ hex: String) -> Bool {
        switch category {
        case .haarfarbe:  return config.hairColor == hex
        case .augenfarbe: return config.eyeColor == hex
        default:          return false
        }
    }

    private func setColor(_ hex: String) {
        switch category {
        case .haarfarbe:  config.hairColor = hex
        case .augenfarbe: config.eyeColor = hex
        default:          break
        }
    }
}
