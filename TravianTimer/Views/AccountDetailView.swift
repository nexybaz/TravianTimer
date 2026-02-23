import SwiftUI
import PhotosUI
import Supabase

// MARK: - Default Avatar Presets

private enum AvatarPreset: String, CaseIterable, Identifiable {
    case warrior   = "figure.fencing"
    case shield    = "shield.fill"
    case crown     = "crown.fill"
    case helm      = "helmet.fill"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .warrior: return "Krieger"
        case .shield:  return "Schild"
        case .crown:   return "König"
        case .helm:    return "Helm"
        }
    }
}

// MARK: - Account Detail View

struct AccountDetailView: View {

    @Environment(AuthService.self) var authService

    @State private var showVerifySheet: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var refreshMessage: String? = nil

    @State private var avatarImage: UIImage?
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAvatarOptions: Bool = false

    // Account löschen
    @State private var showDeleteAlert: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var deleteError: String? = nil

    // Prestige
    @State private var showPrestigeAlert = false
    @State private var prestigeInput = ""

    var body: some View {
        Form {
            if let userProfile = authService.profile {

                // MARK: Avatar

                Section {
                    VStack(spacing: 12) {
                        // Grosser Avatar
                        ZStack(alignment: .bottomTrailing) {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }

                            // Bearbeiten-Badge
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .blue)
                                .offset(x: 4, y: 4)
                        }
                        .onTapGesture { showAvatarOptions = true }

                        Text(userProfile.playerName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Standardvorgaben
                Section("Profilbild") {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Foto hochladen", systemImage: "photo.on.rectangle.angled")
                    }

                    // Standard-Avatare
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Standardvorgaben")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(AvatarPreset.allCases) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Image(systemName: preset.rawValue)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .foregroundStyle(.white)
                                        .background(.blue.gradient)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if avatarImage != nil {
                        Button("Profilbild entfernen", role: .destructive) {
                            deleteAvatar()
                        }
                    }
                }

                // MARK: Profil

                Section("Profil") {
                    LabeledContent("Spieler", value: userProfile.playerName)

                    // Dev-Rollen-Picker (nur fuer Hauptentwickler)
                    if isDeveloper {
                        Picker("Rolle", selection: Binding(
                            get: { authService.currentRole },
                            set: { newRole in
                                Task { await changeOwnRole(to: newRole) }
                            }
                        )) {
                            ForEach(UserRole.allCases, id: \.self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                    } else {
                        LabeledContent("Rolle", value: userProfile.role.displayName)
                    }

                }

                // MARK: Funktionen

                Section("Funktion") {
                    HStack(spacing: 10) {
                        ForEach(PlayerFunction.allCases) { fn in
                            let isActive = userProfile.functions.contains(fn)
                            let canEdit = authService.currentRole.canManageCalls

                            Button {
                                guard canEdit else { return }
                                Task { await toggleOwnFunction(fn) }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: fn.icon)
                                        .font(.title3)
                                        .foregroundStyle(isActive ? .white : fn.color)
                                        .frame(width: 40, height: 40)
                                        .background(isActive ? fn.color : fn.color.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(fn.color.opacity(0.3), lineWidth: isActive ? 0 : 1.5)
                                        )

                                    Text(fn.displayName)
                                        .font(.caption2)
                                        .fontWeight(isActive ? .semibold : .regular)
                                        .foregroundStyle(isActive ? fn.color : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canEdit)
                        }
                    }
                    .padding(.vertical, 4)
                }

                travianSection(for: userProfile)
                prestigeSection(for: userProfile)

                // MARK: Verwaltung

                if authService.currentRole.canManageCalls {
                    Section {
                        NavigationLink {
                            RoleManagementView()
                                .environment(authService)
                        } label: {
                            Label("Mitglieder verwalten", systemImage: "person.2.badge.gearshape")
                        }
                    }
                }

                // MARK: Abmelden

                Section {
                    Button("Abmelden", role: .destructive) {
                        authService.signOut()
                    }
                }

                // MARK: Account löschen

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(isDeletingAccount ? "Account wird gelöscht..." : "Account löschen")
                        }
                    }
                    .disabled(isDeletingAccount)

                    if let deleteError {
                        Text(deleteError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Dein Account und alle Daten werden unwiderruflich gelöscht.")
                        .font(.caption2)
                }
            }
        }
        .navigationTitle(authService.profile?.playerName ?? "Account")
        .onAppear { loadAvatar() }
        .sheet(isPresented: $showVerifySheet) {
            TravianVerifyView()
                .environment(authService)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Profilbild auswählen")
            }
            .photosPickerStyle(.inline)
            .presentationDetents([.medium])
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    avatarImage = uiImage
                    saveAvatarLocally(uiImage)
                    showPhotoPicker = false
                }
            }
        }
        .confirmationDialog("Profilbild", isPresented: $showAvatarOptions) {
            Button("Foto hochladen") { showPhotoPicker = true }
            if avatarImage != nil {
                Button("Profilbild entfernen", role: .destructive) { deleteAvatar() }
            }
            Button("Abbrechen", role: .cancel) { }
        }
        // Prestige-Alert
        .alert("Prestige-Punkte", isPresented: $showPrestigeAlert) {
            TextField("Punktzahl", text: $prestigeInput)
                .keyboardType(.numberPad)
            Button("Speichern") { savePrestigePoints() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Gib deine Gesamt-Prestigepunkte ein. Die Stufe wird automatisch berechnet.")
        }
        // Erster Alert: Warnung
        .alert("Account löschen?", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Unwiderruflich löschen", role: .destructive) {
                showDeleteConfirm = true
            }
        } message: {
            Text("Dein Account und alle zugehörigen Daten (Profil, Dörfer, Truppen, Pledges) werden dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        // Zweiter Alert: Finale Bestätigung
        .alert("Bist du sicher?", isPresented: $showDeleteConfirm) {
            Button("Abbrechen", role: .cancel) { }
            Button("Ja, Account löschen", role: .destructive) {
                Task { await performDeleteAccount() }
            }
        } message: {
            Text("Dies ist die letzte Warnung. Dein Account wird sofort und unwiderruflich gelöscht.")
        }
    }

    // MARK: - Travian Section

    @ViewBuilder
    private func travianSection(for userProfile: UserProfile) -> some View {
        if userProfile.isVerified {
            Section {
                if let worldId = userProfile.worldId, !worldId.isEmpty {
                    LabeledContent("Spielwelt", value: worldId.uppercased())
                }

                if let tag = userProfile.kingdomTag {
                    LabeledContent("Kingdom", value: tag)
                }

                fealtyStepperView()
                fealtyBonusView(fealty: userProfile.fealtyLevel, prestige: userProfile.prestigeLevel)
                refreshButton()
            } header: {
                Text("Travian")
            } footer: {
                Text("Treue-Stufe gilt für dein aktuelles Kingdom und wird im Gebäude-Tool auf Baukosten und Bauzeiten angewendet.")
            }
        } else {
            Section("Travian") {
                Button {
                    showVerifySheet = true
                } label: {
                    Label("Travian-Account verknüpfen", systemImage: "link.badge.plus")
                }
            }
        }
    }

    @ViewBuilder
    private func fealtyStepperView() -> some View {
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
    }

    @ViewBuilder
    private func refreshButton() -> some View {
        Button {
            Task { await refreshTravianData() }
        } label: {
            HStack {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Label(
                    isRefreshing ? "Aktualisiere..." : "Daten aktualisieren",
                    systemImage: "arrow.clockwise"
                )
            }
        }
        .disabled(isRefreshing)

        if let refreshMessage {
            Text(refreshMessage)
                .font(.caption)
                .foregroundStyle(refreshMessage.contains("Fehler") ? .red : .green)
        }
    }

    @ViewBuilder
    private func fealtyBonusView(fealty: Int, prestige: Int) -> some View {
        let costPct = fealtyBuildingCostReduction(fealty: fealty, prestige: prestige)
        let timePct = fealtyBuildingTimeReduction(fealty: fealty, prestige: prestige)

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

    // MARK: - Prestige Section

    @ViewBuilder
    private func prestigeSection(for userProfile: UserProfile) -> some View {
        Section {
            Button {
                prestigeInput = "\(authService.profile?.prestigePoints ?? 0)"
                showPrestigeAlert = true
            } label: {
                HStack {
                    Label("Prestige", systemImage: "crown.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    let pts = userProfile.prestigePoints
                    let level = userProfile.prestigeLevel
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

            Link(destination: URL(string: "https://support.kingdoms.com/de/support/solutions/articles/7000092677-der-weg-zum-prestige")!) {
                Label("Prestige-Stufen nachschauen", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
        } header: {
            Text("Prestige")
        } footer: {
            Text("Prestige ist an deinen Travian-Account gebunden und gilt über alle Königreiche hinweg.")
        }
    }

    // MARK: - Developer Check

    private var isDeveloper: Bool {
        let email = SupabaseManager.client.auth.currentSession?.user.email
        return email == "bogey.01klaviere@icloud.com"
    }

    private func changeOwnRole(to newRole: UserRole) async {
        guard let userId = authService.currentUserId else { return }
        do {
            try await SupabaseManager.client
                .from("profiles")
                .update(["role": newRole.rawValue])
                .eq("id", value: userId.uuidString)
                .execute()

            authService.currentRole = newRole
        } catch {
            print("[AccountDetailView] changeOwnRole Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Eigene Funktion toggeln

    private func toggleOwnFunction(_ function: PlayerFunction) async {
        guard let userId = authService.currentUserId,
              var current = authService.profile?.functions else { return }

        if current.contains(function) {
            current.removeAll { $0 == function }
        } else {
            current.append(function)
        }

        let rawValues = current.map { $0.rawValue }

        do {
            try await SupabaseManager.client
                .from("profiles")
                .update(["functions": rawValues])
                .eq("id", value: userId.uuidString)
                .execute()

            authService.profile?.functions = current
        } catch {
            print("[AccountDetailView] toggleOwnFunction Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Travian Daten aktualisieren

    private func refreshTravianData() async {
        guard let worldId = authService.profile?.worldId, !worldId.isEmpty else {
            refreshMessage = "Fehler: Keine Spielwelt gesetzt"
            return
        }

        isRefreshing = true
        refreshMessage = nil

        do {
            let result = try await TravianAPIService.refreshWorldData(worldId: worldId)
            await authService.refreshProfile()
            await ProfileStore.shared.loadFromSupabase()
            await updateTroopMultiplier(worldId: worldId)

            if result.cached == true {
                refreshMessage = "Daten sind aktuell (bereits heute geladen)"
            } else {
                refreshMessage = "Daten aktualisiert (\(result.villages.count) Dörfer)"
            }
        } catch {
            refreshMessage = "Fehler: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    // MARK: - Avatar

    private func loadAvatar() {
        guard let userId = authService.currentUserId else { return }
        let url = avatarFileURL(for: userId)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarImage = image
        }
    }

    private func saveAvatarLocally(_ image: UIImage) {
        guard let userId = authService.currentUserId,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = avatarFileURL(for: userId)
        try? data.write(to: url)
    }

    private func deleteAvatar() {
        guard let userId = authService.currentUserId else { return }
        let url = avatarFileURL(for: userId)
        try? FileManager.default.removeItem(at: url)
        avatarImage = nil
    }

    @MainActor
    private func applyPreset(_ preset: AvatarPreset) {
        let size: CGFloat = 200
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            // Hintergrund
            UIColor.systemBlue.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))

            // SF Symbol rendern
            let config = UIImage.SymbolConfiguration(pointSize: size * 0.45, weight: .medium)
            if let symbol = UIImage(systemName: preset.rawValue, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolSize = symbol.size
                let origin = CGPoint(
                    x: (size - symbolSize.width) / 2,
                    y: (size - symbolSize.height) / 2
                )
                symbol.draw(at: origin)
            }
        }
        avatarImage = image
        saveAvatarLocally(image)
    }

    // MARK: - Account löschen

    private func performDeleteAccount() async {
        isDeletingAccount = true
        deleteError = nil

        do {
            try await authService.deleteAccount()
            // Erfolg → authStateChanges leitet zurück zum Login-Screen
        } catch {
            deleteError = error.localizedDescription
        }

        isDeletingAccount = false
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
            print("[AccountDetailView] updateFealty Fehler: \(error.localizedDescription)")
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
                print("[AccountDetailView] savePrestigePoints Fehler: \(error.localizedDescription)")
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

    private func updateTroopMultiplier(worldId: String) async {
        struct GameworldRow: Decodable {
            let speed_troops: Int?
        }

        do {
            let row: GameworldRow = try await SupabaseManager.client
                .from("gameworlds")
                .select("speed_troops")
                .eq("world_id", value: worldId)
                .single()
                .execute()
                .value

            if let speedTroops = row.speed_troops, speedTroops > 0 {
                UserDefaults.standard.set(Double(speedTroops), forKey: "troopMultiplier")
            }
        } catch {
            // Nicht kritisch — Multiplier bleibt auf altem Wert
        }
    }
}
