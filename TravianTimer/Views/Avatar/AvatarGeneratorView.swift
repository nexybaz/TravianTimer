import SwiftUI

// MARK: - Avatar Generator (Haupt-Sheet)

struct AvatarGeneratorView: View {

    @State private var store = AvatarConfigStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: AvatarCategory = .frisur
    @State private var isSaving = false

    // Callback fuer AccountDetailView — aktualisiert das Profilbild
    var onAvatarSaved: ((UIImage) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Live-Preview

                AvatarPreviewView(config: store.config, size: 160)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .animation(.easeInOut(duration: 0.2), value: store.config)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                Divider()

                // MARK: Kategorie-Tabs

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(AvatarCategory.allCases) { cat in
                            categoryTab(cat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                Divider()

                // MARK: Inhalt (Varianten / Farben)

                ScrollView {
                    VStack(spacing: 16) {
                        // Presets (nur bei Frisur-Tab sichtbar)
                        if selectedCategory == .frisur {
                            presetsSection
                        }

                        // Varianten-Picker fuer aktuelle Kategorie
                        AvatarComponentPicker(
                            category: selectedCategory,
                            config: $store.config,
                            onSelect: { store.pushUndo() }
                        )

                        // Gesichtsform (immer sichtbar wenn Frisur)
                        if selectedCategory == .frisur {
                            faceShapePicker
                        }

                        // Hautfarbe (immer sichtbar)
                        skinColorSection

                        // Hintergrundfarbe
                        backgroundColorSection
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Avatar erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Zufall
                        Button {
                            store.randomize()
                        } label: {
                            Image(systemName: "dice.fill")
                        }

                        // Undo
                        Button {
                            store.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!store.canUndo)

                        // Speichern
                        Button {
                            saveAndDismiss()
                        } label: {
                            Text("Speichern")
                                .fontWeight(.semibold)
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
    }

    // MARK: - Kategorie-Tab

    private func categoryTab(_ cat: AvatarCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = cat
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.title3)
                Text(cat.title)
                    .font(.caption2)
            }
            .foregroundStyle(selectedCategory == cat ? .orange : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                selectedCategory == cat
                    ? Color.orange.opacity(0.1) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorlagen")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AvatarPresetType.allCases) { preset in
                        Button {
                            store.applyPreset(preset)
                        } label: {
                            VStack(spacing: 6) {
                                AvatarPreviewView(config: preset.config, size: 56)

                                Text(preset.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Gesichtsform-Picker

    private var faceShapePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gesichtsform")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<AvatarFaceShape.count, id: \.self) { index in
                        Button {
                            store.pushUndo()
                            store.config.faceShape = index
                        } label: {
                            AvatarFaceShape(variant: index, skinColor: Color(hex: store.config.skinColor))
                                .scaleEffect(0.35)
                                .frame(width: 64, height: 64)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            store.config.faceShape == index ? Color.orange : Color.clear,
                                            lineWidth: 2.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Hautfarbe

    private var skinColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hautfarbe")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AvatarColorPalette.skinColors, id: \.hex) { item in
                        Button {
                            store.pushUndo()
                            store.config.skinColor = item.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: item.hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            store.config.skinColor == item.hex ? Color.orange : Color.white.opacity(0.3),
                                            lineWidth: store.config.skinColor == item.hex ? 2.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Hintergrundfarbe

    private var backgroundColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hintergrund")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AvatarColorPalette.backgroundColors, id: \.hex) { item in
                        Button {
                            store.pushUndo()
                            store.config.backgroundColor = item.hex
                        } label: {
                            Circle()
                                .fill(Color(hex: item.hex).gradient)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            store.config.backgroundColor == item.hex ? Color.orange : Color.white.opacity(0.3),
                                            lineWidth: store.config.backgroundColor == item.hex ? 2.5 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Speichern

    private func saveAndDismiss() {
        isSaving = true
        store.save()

        // Avatar zu UIImage rendern und via AvatarService hochladen
        let preview = AvatarPreviewView(config: store.config, size: 300)
        let image = preview.renderToImage()

        onAvatarSaved?(image)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Avatar Generator") {
    AvatarGeneratorView()
}
