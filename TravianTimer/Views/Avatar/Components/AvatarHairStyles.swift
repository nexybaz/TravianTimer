import SwiftUI

// MARK: - Frisuren

struct AvatarHairStyles: View {
    let variant: Int
    let hairColor: Color

    static let count = 6

    var body: some View {
        switch variant {
        case 0:  shortHair
        case 1:  mediumHair
        case 2:  longHair
        case 3:  slickedBack
        case 4:  mohawk
        case 5:  bald
        default: shortHair
        }
    }

    // Kurz — Haube oben
    private var shortHair: some View {
        Path { path in
            let w: CGFloat = 150
            let h: CGFloat = 80
            let startX = -w / 2
            path.move(to: CGPoint(x: startX, y: 10))
            path.addQuadCurve(
                to: CGPoint(x: startX + w, y: 10),
                control: CGPoint(x: 0, y: -h)
            )
            path.addLine(to: CGPoint(x: startX + w - 10, y: 20))
            path.addQuadCurve(
                to: CGPoint(x: startX + 10, y: 20),
                control: CGPoint(x: 0, y: -h + 20)
            )
            path.closeSubpath()
        }
        .fill(hairColor)
        .frame(width: 150, height: 80)
    }

    // Mittel — seitlich herunter
    private var mediumHair: some View {
        ZStack {
            // Oberteil
            Path { path in
                let w: CGFloat = 160
                let startX = -w / 2
                path.move(to: CGPoint(x: startX - 5, y: 30))
                path.addQuadCurve(
                    to: CGPoint(x: startX + w + 5, y: 30),
                    control: CGPoint(x: 0, y: -70)
                )
                path.addLine(to: CGPoint(x: startX + w, y: 50))
                path.addQuadCurve(
                    to: CGPoint(x: startX, y: 50),
                    control: CGPoint(x: 0, y: -50)
                )
                path.closeSubpath()
            }
            .fill(hairColor)
            .frame(width: 170, height: 80)

            // Seiten
            HStack(spacing: 100) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(hairColor)
                    .frame(width: 18, height: 50)
                    .offset(y: 30)
                RoundedRectangle(cornerRadius: 6)
                    .fill(hairColor)
                    .frame(width: 18, height: 50)
                    .offset(y: 30)
            }
        }
    }

    // Lang — bis Schultern
    private var longHair: some View {
        ZStack {
            // Oberteil
            Path { path in
                let w: CGFloat = 160
                let startX = -w / 2
                path.move(to: CGPoint(x: startX - 8, y: 30))
                path.addQuadCurve(
                    to: CGPoint(x: startX + w + 8, y: 30),
                    control: CGPoint(x: 0, y: -75)
                )
                path.addLine(to: CGPoint(x: startX + w + 5, y: 45))
                path.addQuadCurve(
                    to: CGPoint(x: startX - 5, y: 45),
                    control: CGPoint(x: 0, y: -55)
                )
                path.closeSubpath()
            }
            .fill(hairColor)
            .frame(width: 180, height: 80)

            // Lange Seiten
            HStack(spacing: 95) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(hairColor)
                    .frame(width: 22, height: 90)
                    .offset(y: 50)
                RoundedRectangle(cornerRadius: 8)
                    .fill(hairColor)
                    .frame(width: 22, height: 90)
                    .offset(y: 50)
            }
        }
    }

    // Nach hinten gekaemmt
    private var slickedBack: some View {
        Path { path in
            let w: CGFloat = 145
            let startX = -w / 2
            path.move(to: CGPoint(x: startX, y: 20))
            path.addQuadCurve(
                to: CGPoint(x: startX + w, y: 20),
                control: CGPoint(x: 0, y: -65)
            )
            path.addLine(to: CGPoint(x: startX + w + 10, y: 10))
            path.addQuadCurve(
                to: CGPoint(x: startX - 10, y: 10),
                control: CGPoint(x: 0, y: -80)
            )
            path.closeSubpath()
        }
        .fill(hairColor)
        .frame(width: 170, height: 80)
    }

    // Irokese
    private var mohawk: some View {
        VStack(spacing: -5) {
            // Kamm
            RoundedRectangle(cornerRadius: 6)
                .fill(hairColor)
                .frame(width: 30, height: 50)
                .offset(y: -15)

            // Basis
            Path { path in
                let w: CGFloat = 100
                let startX = -w / 2
                path.move(to: CGPoint(x: startX, y: 10))
                path.addQuadCurve(
                    to: CGPoint(x: startX + w, y: 10),
                    control: CGPoint(x: 0, y: -30)
                )
                path.addLine(to: CGPoint(x: startX + w - 10, y: 18))
                path.addQuadCurve(
                    to: CGPoint(x: startX + 10, y: 18),
                    control: CGPoint(x: 0, y: -20)
                )
                path.closeSubpath()
            }
            .fill(hairColor)
            .frame(width: 100, height: 30)
        }
    }

    // Glatze — nur leichte Schatten-Linie
    private var bald: some View {
        // Kein Haar, nur ein subtiler Schatten am Haaransatz
        Path { path in
            let w: CGFloat = 130
            let startX = -w / 2
            path.move(to: CGPoint(x: startX + 20, y: 5))
            path.addQuadCurve(
                to: CGPoint(x: startX + w - 20, y: 5),
                control: CGPoint(x: 0, y: -8)
            )
        }
        .stroke(hairColor.opacity(0.3), lineWidth: 2)
        .frame(width: 140, height: 15)
    }
}

#Preview("Frisuren") {
    let color = Color(hex: "8B4513")
    ScrollView(.horizontal) {
        HStack(spacing: 20) {
            ForEach(0..<AvatarHairStyles.count, id: \.self) { i in
                VStack {
                    ZStack {
                        Circle().fill(Color(hex: "FDBCB4")).frame(width: 100, height: 100)
                        AvatarHairStyles(variant: i, hairColor: color)
                            .offset(y: -30)
                    }
                    Text("Var \(i)")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
