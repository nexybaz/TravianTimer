import SwiftUI

// MARK: - Biometric Lock View

/// Sperrbildschirm der App.
/// Erscheint wenn die App-Sperre aktiviert ist und der User sich noch nicht authentifiziert hat.
struct BiometricLockView: View {

    @StateObject private var lockService = BiometricLockService.shared

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // App-Icon
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                Text("TravianTimer")
                    .font(.title.bold())

                Text("App ist gesperrt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Biometrie-Button
            Button {
                Task { await lockService.authenticate() }
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: lockService.biometryIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("Mit \(lockService.biometryName) entsperren")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(lockService.isAuthenticating)
            .padding(.horizontal, 40)

            // Fehler
            if let error = lockService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            // Automatisch Biometrie triggern beim Erscheinen
            await lockService.authenticate()
        }
    }
}
