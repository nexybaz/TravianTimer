import SwiftUI

// MARK: - Operation Share View (Join-Code teilen)

struct OperationShareView: View {

    let operation: Operation

    @Environment(\.dismiss) var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)

                Text("Einsatz teilen")
                    .font(.title2.bold())

                Text(operation.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let code = operation.joinCode {
                    VStack(spacing: 8) {
                        Text("Beitritts-Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(code)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        UIPasteboard.general.string = code
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(
                            copied ? "Kopiert!" : "Code kopieren",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? .green : .orange)
                    .padding(.horizontal, 48)

                    Text("Teile diesen Code mit deinen Spielern.\nSie können damit dem Einsatz beitreten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Kein Beitritts-Code verfügbar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
