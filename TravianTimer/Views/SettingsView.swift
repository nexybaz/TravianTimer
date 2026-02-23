import SwiftUI
import Supabase
// MARK: - Settings Tab

struct SettingsView: View {

    @Environment(AuthService.self) var authService
    @State private var lockService = BiometricLockService.shared

    @State private var showAuthSheet: Bool = false
    @State private var showVerifySheet: Bool = false
    @State private var showPrestigeAlert = false
    @State private var prestigeInput = ""

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
                                        // @Published löst automatisch UI-Update aus
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

                // MARK: Treue (Lehnssystem)

                if authService.isAuthenticated, authService.profile != nil {
                    Section {
                        // Treue-Stufe (Stepper 0–20)
                        Stepper(value: Binding(
                            get: { authService.profile?.fealtyLevel ?? 0 },
                            set: { newValue in
                                Task { await updateFealty(level: newValue) }
                            }
                        ), in: 0...20) {
                            HStack {
                                Label("Treue-Stufe", systemImage: "star.fill")
                                Spacer()
                                Text("\(authService.profile?.fealtyLevel ?? 0)")
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }

                        // Prestige-Punkte → antippbar, öffnet Alert
                        Button {
                            prestigeInput = "\(authService.profile?.prestigePoints ?? 0)"
                            showPrestigeAlert = true
                        } label: {
                            HStack {
                                Label("Prestige", systemImage: "crown.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                let pts = authService.profile?.prestigePoints ?? 0
                                let level = authService.profile?.prestigeLevel ?? 0
                                if pts > 0 {
                                    Text("\(pts) Punkte → Stufe \(level)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                } else {
                                    Text("Nicht gesetzt")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Link zur offiziellen Prestige-Übersicht
                        Link(destination: URL(string: "https://support.kingdoms.com/de/support/solutions/articles/7000092677-der-weg-zum-prestige")!) {
                            Label("Prestige-Stufen nachschauen", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }

                        // Aktive Boni anzeigen
                        if let profile = authService.profile {
                            let costPct = fealtyBuildingCostReduction(fealty: profile.fealtyLevel, prestige: profile.prestigeLevel)
                            let timePct = fealtyBuildingTimeReduction(fealty: profile.fealtyLevel, prestige: profile.prestigeLevel)

                            if costPct > 0 || timePct > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    if costPct > 0 {
                                        Label(String(format: "Baukosten  −%.1f%%", costPct), systemImage: "arrow.down.right")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                    if timePct > 0 {
                                        Label(String(format: "Bauzeit  −%.1f%%", timePct), systemImage: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Text("Treue (Lehnssystem)")
                    } footer: {
                        Text("Wird im Gebäude-Tool automatisch auf Baukosten und Bauzeiten angewendet.")
                    }
                }

            }
            .navigationTitle("Einstellungen")
            .alert("Prestige-Punkte", isPresented: $showPrestigeAlert) {
                TextField("Punktzahl", text: $prestigeInput)
                    .keyboardType(.numberPad)
                Button("Speichern") { savePrestigePoints() }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Gib deine Gesamt-Prestigepunkte ein. Die Stufe wird automatisch berechnet.")
            }
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

    // MARK: - Treue / Prestige

    private func updateFealty(level: Int) async {
        guard let userId = authService.currentUserId else { return }
        do {
            try await SupabaseManager.client
                .from("profiles")
                .update(["fealty_level": level])
                .eq("id", value: userId.uuidString)
                .execute()
            authService.profile?.fealtyLevel = level
        } catch {
            print("[SettingsView] updateFealty Fehler: \(error.localizedDescription)")
        }
    }

    private func savePrestigePoints() {
        guard let points = Int(prestigeInput), points >= 0 else { return }
        guard points != authService.profile?.prestigePoints else { return }
        Task {
            guard let userId = authService.currentUserId else { return }
            do {
                try await SupabaseManager.client
                    .from("profiles")
                    .update(["prestige_points": points])
                    .eq("id", value: userId.uuidString)
                    .execute()
                authService.profile?.prestigePoints = points
            } catch {
                print("[SettingsView] savePrestigePoints Fehler: \(error.localizedDescription)")
            }
        }
    }

    /// Offizielle Baukosten-Reduktion: 0.5 * (fealtyLevel - 11 + prestigeBonus) / 100
    private func fealtyBuildingCostReduction(fealty: Int, prestige: Int) -> Double {
        guard fealty >= 12 else { return 0 }
        let prestigeBonus: Double = prestige >= 12 ? 1.0 : 0.0
        return 0.5 * (Double(fealty) - 11.0 + prestigeBonus)
    }

    /// Offizielle Bauzeit-Reduktion (switch wie im Spiel-Code)
    private func fealtyBuildingTimeReduction(fealty: Int, prestige: Int) -> Double {
        guard fealty >= 11 else { return 0 }
        var reduction: Double
        switch fealty {
        case 11: reduction = 1.0
        case 12: reduction = 1.5
        default: reduction = Double(min(fealty, 20) - 11)
        }
        if prestige >= 11 { reduction += 1.0 }
        return reduction
    }

}
