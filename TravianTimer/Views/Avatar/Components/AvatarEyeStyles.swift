import SwiftUI

// MARK: - Augen-Stile

struct AvatarEyeStyles: View {
    let variant: Int
    let eyeColor: Color

    static let count = 5

    var body: some View {
        switch variant {
        case 0:  roundEyes
        case 1:  almondEyes
        case 2:  narrowEyes
        case 3:  wideEyes
        case 4:  droopyEyes
        default: roundEyes
        }
    }

    // Rund
    private var roundEyes: some View {
        HStack(spacing: 28) {
            singleEye(width: 22, height: 22, pupilSize: 10)
            singleEye(width: 22, height: 22, pupilSize: 10)
        }
    }

    // Mandel
    private var almondEyes: some View {
        HStack(spacing: 26) {
            singleEye(width: 26, height: 16, pupilSize: 9)
            singleEye(width: 26, height: 16, pupilSize: 9)
        }
    }

    // Schmal
    private var narrowEyes: some View {
        HStack(spacing: 28) {
            singleEye(width: 28, height: 12, pupilSize: 8)
            singleEye(width: 28, height: 12, pupilSize: 8)
        }
    }

    // Weit / gross
    private var wideEyes: some View {
        HStack(spacing: 24) {
            singleEye(width: 26, height: 24, pupilSize: 12)
            singleEye(width: 26, height: 24, pupilSize: 12)
        }
    }

    // Haengend / muede
    private var droopyEyes: some View {
        HStack(spacing: 26) {
            singleEye(width: 24, height: 16, pupilSize: 9)
                .rotationEffect(.degrees(-5))
            singleEye(width: 24, height: 16, pupilSize: 9)
                .rotationEffect(.degrees(5))
        }
    }

    // MARK: - Einzelnes Auge

    private func singleEye(width: CGFloat, height: CGFloat, pupilSize: CGFloat) -> some View {
        ZStack {
            // Augweiss
            Ellipse()
                .fill(.white)
                .frame(width: width, height: height)

            // Iris
            Circle()
                .fill(eyeColor)
                .frame(width: pupilSize, height: pupilSize)

            // Pupille
            Circle()
                .fill(.black)
                .frame(width: pupilSize * 0.5, height: pupilSize * 0.5)

            // Glanzpunkt
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: pupilSize * 0.22, height: pupilSize * 0.22)
                .offset(x: pupilSize * 0.15, y: -pupilSize * 0.15)

            // Augenlid-Rand
            Ellipse()
                .stroke(.black.opacity(0.3), lineWidth: 1)
                .frame(width: width, height: height)
        }
    }
}

#Preview("Augen") {
    let color = Color(hex: "4169E1")
    HStack(spacing: 30) {
        ForEach(0..<AvatarEyeStyles.count, id: \.self) { i in
            VStack {
                AvatarEyeStyles(variant: i, eyeColor: color)
                Text("Var \(i)")
                    .font(.caption)
            }
        }
    }
    .padding()
}
