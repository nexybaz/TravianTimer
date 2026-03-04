import SwiftUI

// MARK: - Nasen-Stile

struct AvatarNoseStyles: View {
    let variant: Int
    let skinColor: Color

    static let count = 4

    private var shadowColor: Color {
        skinColor.opacity(0.6)
    }

    var body: some View {
        switch variant {
        case 0:  smallNose
        case 1:  pointedNose
        case 2:  roundNose
        case 3:  wideNose
        default: smallNose
        }
    }

    // Klein — dezent
    private var smallNose: some View {
        VStack(spacing: 0) {
            // Nasenruecken
            RoundedRectangle(cornerRadius: 3)
                .fill(shadowColor)
                .frame(width: 6, height: 14)

            // Nasenoeffnungen
            HStack(spacing: 4) {
                Circle().fill(shadowColor).frame(width: 5, height: 5)
                Circle().fill(shadowColor).frame(width: 5, height: 5)
            }
        }
    }

    // Spitz / prominent
    private var pointedNose: some View {
        VStack(spacing: 0) {
            Path { path in
                path.move(to: CGPoint(x: 10, y: 0))
                path.addLine(to: CGPoint(x: 5, y: 22))
                path.addLine(to: CGPoint(x: 15, y: 22))
                path.closeSubpath()
            }
            .fill(shadowColor)
            .frame(width: 20, height: 22)

            HStack(spacing: 5) {
                Circle().fill(shadowColor).frame(width: 5, height: 5)
                Circle().fill(shadowColor).frame(width: 5, height: 5)
            }
        }
    }

    // Rund / knollig
    private var roundNose: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3)
                .fill(shadowColor)
                .frame(width: 7, height: 12)

            // Runde Nasenoeffnungen
            Ellipse()
                .fill(shadowColor)
                .frame(width: 18, height: 12)
        }
    }

    // Breit / flach
    private var wideNose: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3)
                .fill(shadowColor)
                .frame(width: 8, height: 10)

            HStack(spacing: 6) {
                Ellipse().fill(shadowColor).frame(width: 8, height: 6)
                Ellipse().fill(shadowColor).frame(width: 8, height: 6)
            }
        }
    }
}

#Preview("Nasen") {
    let skin = Color(hex: "FDBCB4")
    HStack(spacing: 40) {
        ForEach(0..<AvatarNoseStyles.count, id: \.self) { i in
            VStack {
                ZStack {
                    Ellipse().fill(skin).frame(width: 60, height: 70)
                    AvatarNoseStyles(variant: i, skinColor: skin)
                }
                Text("Var \(i)")
                    .font(.caption)
            }
        }
    }
    .padding()
}
