import SwiftUI

// MARK: - Manual Tab

struct ManualTabView: View {

    @EnvironmentObject private var store: CallsStore
    @Binding var selection: ContentView.AppTab

    @State private var titleText: String = ""
    @State private var xText: String = "0"
    @State private var yText: String = "0"
    @State private var arrival: Date = .now
    @State private var urlText: String = ""
    @State private var inlineError: String? = nil

    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case x
        case y
        case url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Call") {
                    TextField("Dorfname", text: $titleText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .title)
                }

                Section("Ziel") {
                    TextField("X", text: $xText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .x)

                    TextField("Y", text: $yText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($focusedField, equals: .y)
                }

                Section("Ankunft") {
                    DatePicker("Zeit", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Link") {
                    TextField("Optional: Travian Link", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .url)

                    Text("Wenn du einen Link einfügst, kannst du ihn später im Call öffnen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let inlineError {
                    Section {
                        Text(inlineError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                if let err = store.errorText {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Erstellen") {
                        focusedField = nil
                        inlineError = nil

                        guard let x = parseIntStrict(xText) else {
                            inlineError = "X ist ungültig."
                            return
                        }
                        guard let y = parseIntStrict(yText) else {
                            inlineError = "Y ist ungültig."
                            return
                        }

                        store.createCallManual(
                            title: titleText,
                            targetX: x,
                            targetY: y,
                            arrival: arrival,
                            linkString: urlText
                        )

                        if store.errorText == nil {
                            selection = .calls
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Manuell")
        }
    }

    private func parseIntStrict(_ text: String) -> Int? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }
}
