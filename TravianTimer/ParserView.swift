import SwiftUI
import UIKit

struct ParserView: View {

    @Binding var inputText: String
    let onPaste: () -> Void
    let onEvaluate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                TextEditor(text: $inputText)
                    .focused($isEditing)
                    .frame(minHeight: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.3))
                    )

                HStack {
                    Button("Einfügen") {
                        onPaste()
                    }
                    .buttonStyle(.bordered)

                    Button("Auswerten") {
                        onEvaluate()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Call Parser")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isEditing = true
                }
            }
        }
    }
}
