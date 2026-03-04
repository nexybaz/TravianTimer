import SwiftUI
import Supabase

// MARK: - Profile Setup View (Onboarding Step 4)

struct ProfileSetupView: View {

    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss

    @State private var prestigeInput = ""
    @State private var fealtyLevel: Int = 0
    @AppStorage("hasPlusAccount") private var hasPlusAccount: Bool = false

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Header

                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)

                        Text("Fast geschafft!")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Ergänze dein Profil für genauere Berechnungen im Gebäude- und Truppen-Tool.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                // MARK: Prestige

                Section {
                    HStack {
                        Text("Prestige-Punkte")
                        Spacer()
                        TextField("0", text: $prestigeInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }

                    let level = computedPrestigeLevel
                    HStack {
                        Text("Stufe")
                        Spacer()
                        if level > 0 {
                            Text("\(level)")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://support.kingdoms.com/de/support/solutions/articles/7000092677-der-weg-zum-prestige")!) {
                        Label("Prestige-Stufen nachschauen", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                } header: {
                    Text("Prestige")
                } footer: {
                    Text("Prestige ist an deinen Travian-Account gebunden und gilt über alle Königreiche hinweg.")
                }

                // MARK: Lehnstreue & Plus

                Section {
                    Stepper(value: $fealtyLevel, in: 0...20) {
                        HStack {
                            Text("Lehnstreuestufe")
                            Spacer()
                            Text("\(fealtyLevel)")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }

                    Toggle(isOn: $hasPlusAccount) {
                        HStack {
                            Text("Plus Account")
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Lehnstreue & Plus")
                }

                // MARK: Fertig

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 6)
                            }
                            Text("Fertig")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Überspringen") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Computed

    private var computedPrestigeLevel: Int {
        guard let points = Int(prestigeInput), points > 0 else { return 0 }
        return UserProfile.prestigeLevel(from: points)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let userId = authService.currentUserId else {
            dismiss()
            return
        }

        let points = Int(prestigeInput) ?? 0

        // Optimistic update
        authService.profile?.prestigePoints = points
        authService.profile?.fealtyLevel = fealtyLevel

        do {
            try await SupabaseManager.client
                .from("profiles")
                .update([
                    "prestige_points": points,
                    "fealty_level": fealtyLevel
                ])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            print("[ProfileSetupView] save Fehler: \(error.localizedDescription)")
        }

        dismiss()
    }
}
