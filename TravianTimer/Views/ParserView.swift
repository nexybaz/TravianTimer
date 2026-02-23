import SwiftUI
import UIKit

struct ParserView: View {

    @Binding var inputText: String
    let onPaste: () -> Void
    /// Gibt `true` zurück wenn der Call erfolgreich erstellt wurde
    let onEvaluate: () async -> Bool

    @FocusState private var isEditing: Bool

    @State private var showSuccess = false
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var checkmarkOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 12) {

                    Button {
                        if let clip = UIPasteboard.general.string {
                            inputText = clip
                        }
                    } label: {
                        Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    TextEditor(text: $inputText)
                        .focused($isEditing)
                        .frame(minHeight: 240)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.secondary.opacity(0.3))
                        )

                    HStack {
                        Text("Discord Call einfügen und auswerten.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            Task {
                                let success = await onEvaluate()
                                if success {
                                    showSuccessAnimation()
                                }
                            }
                        } label: {
                            Label("Call erstellen", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .allowsHitTesting(!showSuccess)

                if showSuccess {
                    successOverlay
                }
            }
            .navigationTitle("Call Parser")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                Text("Call erstellt!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .opacity(checkmarkOpacity)
            }
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Reset für nächste Verwendung
                showSuccess = false
                checkmarkScale = 0.3
                checkmarkOpacity = 0
                inputText = ""
            }
        }
    }

    private func showSuccessAnimation() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showSuccess = true
        }
    }
}
