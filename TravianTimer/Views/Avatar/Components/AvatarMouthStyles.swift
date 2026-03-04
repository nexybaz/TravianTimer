import SwiftUI

// MARK: - Mund-Stile

struct AvatarMouthStyles: View {
    let variant: Int

    static let count = 5

    private let mouthColor = Color(red: 0.75, green: 0.35, blue: 0.35)

    var body: some View {
        switch variant {
        case 0:  smile
        case 1:  neutral
        case 2:  serious
        case 3:  grin
        case 4:  pout
        default: smile
        }
    }

    // Laecheln
    private var smile: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 30, y: 0),
                control: CGPoint(x: 15, y: 14)
            )
        }
        .stroke(mouthColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 30, height: 16)
    }

    // Neutral — gerade Linie
    private var neutral: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 5))
            path.addLine(to: CGPoint(x: 26, y: 5))
        }
        .stroke(mouthColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 26, height: 10)
    }

    // Ernst — leicht nach unten
    private var serious: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 2))
            path.addQuadCurve(
                to: CGPoint(x: 28, y: 2),
                control: CGPoint(x: 14, y: -6)
            )
        }
        .stroke(mouthColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 28, height: 10)
    }

    // Grinsen — breit, offener Mund
    private var grin: some View {
        ZStack {
            // Mund-Oeffnung
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 36, y: 0),
                    control: CGPoint(x: 18, y: 16)
                )
                path.closeSubpath()
            }
            .fill(Color(red: 0.3, green: 0.1, blue: 0.1))
            .frame(width: 36, height: 16)

            // Zaehne
            Path { path in
                path.move(to: CGPoint(x: 6, y: 1))
                path.addLine(to: CGPoint(x: 30, y: 1))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 36, height: 16)

            // Lippen-Rand
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 36, y: 0),
                    control: CGPoint(x: 18, y: 16)
                )
            }
            .stroke(mouthColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 36, height: 16)
        }
    }

    // Schmollmund
    private var pout: some View {
        ZStack {
            // Oberlippe
            Path { path in
                path.move(to: CGPoint(x: 0, y: 8))
                path.addQuadCurve(
                    to: CGPoint(x: 12, y: 4),
                    control: CGPoint(x: 5, y: 0)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 24, y: 8),
                    control: CGPoint(x: 19, y: 0)
                )
            }
            .stroke(mouthColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 24, height: 14)

            // Unterlippe
            Path { path in
                path.move(to: CGPoint(x: 2, y: 9))
                path.addQuadCurve(
                    to: CGPoint(x: 22, y: 9),
                    control: CGPoint(x: 12, y: 16)
                )
            }
            .stroke(mouthColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 24, height: 18)
        }
    }
}

#Preview("Muender") {
    HStack(spacing: 40) {
        ForEach(0..<AvatarMouthStyles.count, id: \.self) { i in
            VStack {
                AvatarMouthStyles(variant: i)
                Text("Var \(i)")
                    .font(.caption)
            }
        }
    }
    .padding()
}
