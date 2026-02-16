import SwiftUI

// MARK: - Parser Tab

struct ParserTabView: View {

    @EnvironmentObject private var store: CallsStore
    @Binding var selection: ContentView.AppTab

    var body: some View {
        ParserView(
            inputText: $store.inputText,
            onPaste: { store.pasteFromClipboard() },
            onEvaluate: {
                store.createCallFromParser()
                // Tab-Wechsel verzögert, damit Success-Animation sichtbar bleibt
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    selection = .calls
                }
            }
        )
    }
}
