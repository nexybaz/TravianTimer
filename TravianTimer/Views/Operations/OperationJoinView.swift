import SwiftUI

// MARK: - Operation Join View (Beitreten via Code)

struct OperationJoinView: View {

    @Environment(OperationPlanStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var success = false

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Einsatz beitreten")
                    .font(.title2.bold())

                Text("Gib den 4-stelligen Code ein, den du vom Planer erhalten hast.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Code-Eingabe
                TextField("XXXX", text: $code)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onChange(of: code) { _, newValue in
                        // Max 4 Zeichen, Uppercase
                        let cleaned = String(newValue.uppercased().prefix(4))
                        if cleaned != newValue { code = cleaned }
                        errorMessage = nil
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 48)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if success {
                    Label("Erfolgreich beigetreten!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Button {
                    Task { await joinOperation() }
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Beitreten")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(code.count != 4 || isJoining || success)
                .padding(.horizontal, 48)

                Spacer()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func joinOperation() async {
        isJoining = true
        errorMessage = nil

        let operation = await store.joinOperation(code: code)

        if operation != nil {
            success = true
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } else {
            errorMessage = "Code ungültig oder Beitritt fehlgeschlagen."
        }

        isJoining = false
    }
}
