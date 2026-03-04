import SwiftUI

// MARK: - Schmuck / Accessoires

struct AvatarAccessoryStyles: View {
    let variant: Int

    static let count = 4

    var body: some View {
        switch variant {
        case 0:  scar
        case 1:  eyePatch
        case 2:  headband
        case 3:  earring
        default: scar
        }
    }

    // Narbe — diagonal ueber Wange
    private var scar: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 4, y: 18))
            path.move(to: CGPoint(x: 2, y: 6))
            path.addLine(to: CGPoint(x: 7, y: 10))
        }
        .stroke(Color(red: 0.6, green: 0.3, blue: 0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .frame(width: 10, height: 20)
        .offset(x: 35, y: -5)
    }

    // Augenklappe — links
    private var eyePatch: some View {
        ZStack {
            // Band
            Path { path in
                path.move(to: CGPoint(x: -50, y: -30))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 50, y: -30))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 2))

            // Klappe
            Ellipse()
                .fill(.black)
                .frame(width: 28, height: 22)
        }
        .offset(x: -25, y: -18)
    }

    // Stirnband
    private var headband: some View {
        ZStack {
            // Band
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.red.opacity(0.8))
                .frame(width: 155, height: 8)

            // Knoten rechts
            Circle()
                .fill(Color.red.opacity(0.9))
                .frame(width: 10, height: 10)
                .offset(x: 72)
        }
        .offset(y: -60)
    }

    // Ohrring — rechts
    private var earring: some View {
        ZStack {
            // Ring
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 12, height: 12)

            // Perle
            Circle()
                .fill(Color.yellow)
                .frame(width: 5, height: 5)
                .offset(y: 6)
        }
        .offset(x: 68, y: 15)
    }
}

#Preview("Accessoires") {
    HStack(spacing: 30) {
        ForEach(0..<AvatarAccessoryStyles.count, id: \.self) { i in
            VStack {
                ZStack {
                    Circle().fill(Color(hex: "FDBCB4")).frame(width: 120, height: 120)
                    AvatarAccessoryStyles(variant: i)
                }
                Text("Var \(i)")
                    .font(.caption)
            }
        }
    }
    .padding()
}
