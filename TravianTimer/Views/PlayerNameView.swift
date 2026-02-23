import SwiftUI
import Supabase
// MARK: - Player Name View (Onboarding fuer Apple Sign-In User)

struct PlayerNameView: View {

    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    @State private var playerName: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer().frame(height: 20)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("Spielername")
                        .font(.largeTitle.bold())

                    Text("Wie heisst du in Travian?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Textfeld
                TextField("Spielername", text: $playerName)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)

                // Fehlermeldung
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Speichern Button
                Button {
                    Task { await saveName() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Speichern")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Save

    private func saveName() async {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        guard let userId = authService.currentUserId else {
            errorMessage = "Kein Benutzer angemeldet"
            isSaving = false
            return
        }

        do {
            // Auth metadata updaten
            try await SupabaseManager.client.auth.update(
                user: .init(data: ["player_name": .string(trimmed)])
            )

            // Profiles-Tabelle updaten
            try await SupabaseManager.client
                .from("profiles")
                .update(["player_name": trimmed])
                .eq("id", value: userId.uuidString)
                .execute()

            // Profil im AuthService refreshen
            await authService.refreshProfile()

            dismiss()
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
