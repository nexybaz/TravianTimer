import SwiftUI

// MARK: - Avatar Preview (Layer-Komposition)

struct AvatarPreviewView: View {
    let config: AvatarConfig
    var size: CGFloat = 200

    private var hairColor: Color { Color(hex: config.hairColor) }
    private var eyeColor: Color { Color(hex: config.eyeColor) }
    private var skinColor: Color { Color(hex: config.skinColor) }
    private var bgColor: Color { Color(hex: config.backgroundColor) }

    var body: some View {
        ZStack {
            // Hintergrund-Kreis mit Gradient
            Circle()
                .fill(bgColor.gradient)

            // Gesichts-Komposition
            faceComposition
                .scaleEffect(size / 250)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // MARK: - Layer-Aufbau

    private var faceComposition: some View {
        ZStack {
            // 1. Ohren (hinter dem Gesicht)
            ears

            // 2. Gesicht
            AvatarFaceShape(variant: config.faceShape, skinColor: skinColor)

            // 3. Augen
            AvatarEyeStyles(variant: config.eyeStyle, eyeColor: eyeColor)
                .offset(y: -15)

            // 4. Augenbrauen
            eyebrows

            // 5. Nase
            AvatarNoseStyles(variant: config.noseStyle, skinColor: skinColor)
                .offset(y: 12)

            // 6. Mund
            AvatarMouthStyles(variant: config.mouthStyle)
                .offset(y: 38)

            // 7. Haare (auf dem Gesicht)
            AvatarHairStyles(variant: config.hairStyle, hairColor: hairColor)
                .offset(y: -55)

            // 8. Accessoire (zuoberst)
            if config.accessory >= 0 {
                AvatarAccessoryStyles(variant: config.accessory)
            }
        }
    }

    // MARK: - Hilfselemente

    private var ears: some View {
        HStack(spacing: 130) {
            Ellipse()
                .fill(skinColor)
                .frame(width: 16, height: 22)
            Ellipse()
                .fill(skinColor)
                .frame(width: 16, height: 22)
        }
    }

    private var eyebrows: some View {
        HStack(spacing: 30) {
            RoundedRectangle(cornerRadius: 2)
                .fill(hairColor.opacity(0.7))
                .frame(width: 22, height: 3)
                .rotationEffect(.degrees(-3))
            RoundedRectangle(cornerRadius: 2)
                .fill(hairColor.opacity(0.7))
                .frame(width: 22, height: 3)
                .rotationEffect(.degrees(3))
        }
        .offset(y: -30)
    }

    // MARK: - Render zu UIImage

    /// Rendert den Avatar als UIImage (fuer AvatarService.upload).
    @MainActor
    func renderToImage() -> UIImage {
        let renderView = AvatarPreviewView(config: config, size: 300)
        let renderer = ImageRenderer(content: renderView.frame(width: 300, height: 300))
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage(systemName: "person.crop.circle.fill")!
    }
}

// MARK: - Preview

#Preview("Avatar Preview") {
    VStack(spacing: 20) {
        // Standard
        AvatarPreviewView(config: AvatarConfig(), size: 200)

        // Krieger
        AvatarPreviewView(config: AvatarPresetType.krieger.config, size: 150)

        // Klein
        HStack(spacing: 10) {
            ForEach(AvatarPresetType.allCases) { preset in
                AvatarPreviewView(config: preset.config, size: 60)
            }
        }
    }
    .padding()
}
