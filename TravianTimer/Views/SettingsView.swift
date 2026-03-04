import SwiftUI
import Supabase

// MARK: - Settings Tab

struct SettingsView: View {

    @Environment(AuthService.self) var authService
    @State private var lockService = BiometricLockService.shared

    @State private var showAuthSheet: Bool = false
    @State private var showVerifySheet: Bool = false

    private var isDeveloper: Bool {
        let email = SupabaseManager.client.auth.currentSession?.user.email
        return email == "bogey.01klaviere@icloud.com"
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Account (Cloud)

                Section {
                    if authService.isAuthenticated {
                        if authService.profile != nil {
                            NavigationLink {
                                AccountDetailView()
                                    .environment(authService)
                            } label: {
                                HStack(spacing: 16) {
                                    AvatarImage(size: 60)
                                        .environment(authService)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(authService.profile?.playerName ?? "Account")
                                            .font(.title3)
                                            .fontWeight(.semibold)

                                        HStack(spacing: 6) {
                                            Text(authService.profile?.role.displayName ?? "")
                                            if let tag = authService.profile?.kingdomTag {
                                                Text("·")
                                                Text(tag)
                                            }
                                            if authService.profile?.isVerified == true {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        } else {
                            HStack {
                                ProgressView()
                                Text("Profil wird geladen...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Nicht angemeldet")
                            .foregroundStyle(.secondary)

                        Button("Anmelden") {
                            showAuthSheet = true
                        }
                    }
                }

                // MARK: Verifizierungs-Hinweis

                if authService.isAuthenticated && authService.profile?.isVerified != true {
                    Section {
                        Button {
                            showVerifySheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Travian nicht verknüpft")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("Verknüpfe deinen Account um alle Features zu nutzen.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: Benachrichtigungen

                if authService.isAuthenticated {
                    Section {
                        NavigationLink {
                            NotificationsDetailView()
                        } label: {
                            Label("Benachrichtigungen", systemImage: "bell.badge")
                        }
                    }
                }

                // MARK: Sicherheit

                if authService.isAuthenticated && lockService.isBiometryAvailable {
                    Section {
                        Toggle(isOn: Binding(
                            get: { lockService.isEnabled },
                            set: { newValue in
                                Task {
                                    let success = await lockService.setEnabled(newValue)
                                    if !success {
                                        // Biometrie fehlgeschlagen → bleibt beim alten Wert
                                    }
                                }
                            }
                        )) {
                            Label("App-Sperre (\(lockService.biometryName))", systemImage: lockService.biometryIcon)
                        }
                    } header: {
                        Text("Sicherheit")
                    } footer: {
                        Text("Sperrt die App beim Start und beim Zurückkehren aus dem Hintergrund. Entsperren mit \(lockService.biometryName).")
                    }
                }

                // MARK: Debug (nur Developer)

                if isDeveloper {
                    Section("Debug") {
                        Button("Onboarding zurücksetzen", role: .destructive) {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                            UserDefaults.standard.set(false, forKey: "hasCompletedTroopImport")
                            UserDefaults.standard.set(false, forKey: "hasSkippedVerification")
                        }
                    }
                }

            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showAuthSheet) {
                AuthView()
                    .environment(authService)
            }
            .sheet(isPresented: $showVerifySheet) {
                TravianVerifyView()
                    .environment(authService)
            }
        }
    }

}
