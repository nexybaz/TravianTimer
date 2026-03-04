import SwiftUI

// MARK: - Gesichtsformen

struct AvatarFaceShape: View {
    let variant: Int
    let skinColor: Color

    static let count = 4

    var body: some View {
        switch variant {
        case 0:  ovalFace
        case 1:  roundFace
        case 2:  angularFace
        case 3:  longFace
        default: ovalFace
        }
    }

    // Oval — Standard
    private var ovalFace: some View {
        Ellipse()
            .fill(skinColor)
            .frame(width: 140, height: 170)
    }

    // Rund
    private var roundFace: some View {
        Ellipse()
            .fill(skinColor)
            .frame(width: 160, height: 160)
    }

    // Eckig / kantig
    private var angularFace: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(skinColor)
            .frame(width: 140, height: 165)
    }

    // Lang / schmal
    private var longFace: some View {
        Ellipse()
            .fill(skinColor)
            .frame(width: 125, height: 180)
    }
}

#Preview("Gesichtsformen") {
    HStack(spacing: 20) {
        ForEach(0..<AvatarFaceShape.count, id: \.self) { i in
            VStack {
                AvatarFaceShape(variant: i, skinColor: Color(hex: "FDBCB4"))
                Text("Var \(i)")
                    .font(.caption)
            }
        }
    }
    .padding()
}
