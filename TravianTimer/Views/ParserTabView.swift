import SwiftUI

// MARK: - Parser (als Sheet aus den Settings)

struct ParserTabView: View {

    @Environment(CallsStore.self) var store
    @Environment(\.dismiss) private var dismiss

    enum ParserState {
        case parser
        case errorChoice   // Parser fehlgeschlagen → Auswahl
        case manual        // Manuell erfassen
    }

    @State private var state: ParserState = .parser

    var body: some View {
        @Bindable var store = store
        switch state {
        case .parser:
            ParserView(
                inputText: $store.inputText,
                onPaste: { store.pasteFromClipboard() },
                onEvaluate: {
                    await store.createCallFromParser()
                    if store.errorText != nil {
                        state = .errorChoice
                        return false
                    } else {
                        // Dismiss nach kurzer Pause (Success-Animation laeuft)
                        try? await Task.sleep(for: .seconds(1.1))
                        dismiss()
                        return true
                    }
                }
            )

        case .errorChoice:
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 90, height: 90)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                    }

                    Text("Parser fehlgeschlagen")
                        .font(.title3)
                        .fontWeight(.bold)

                    if let err = store.errorText {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            state = .manual
                        } label: {
                            Label("Manuell eingeben", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            store.errorText = nil
                            store.inputText = ""
                            dismiss()
                        } label: {
                            Text("Verwerfen")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .navigationTitle("Call Parser")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zurück") {
                            store.errorText = nil
                            state = .parser
                        }
                    }
                }
            }

        case .manual:
            NavigationStack {
                ManualCallForm(onCreated: {
                    dismiss()
                })
                .environment(store)
                .navigationTitle("Manuell erfassen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zurück") {
                            store.errorText = nil
                            state = .errorChoice
                        }
                    }
                }
            }
        }
    }
}
