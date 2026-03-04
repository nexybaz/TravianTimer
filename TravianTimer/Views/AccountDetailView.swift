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

    // Avatar
    @State private var avatarImage: UIImage?
    @State private var showAvatarSheet = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAvatarGenerator = false

    // Travian
    @State private var showVerifySheet = false

    // Prestige
    @State private var prestigeInput = ""
    @FocusState private var prestigeFieldFocused: Bool

    // Plus Account
    @AppStorage("hasPlusAccount") private var hasPlusAccount: Bool = false

    // Abmelden
    @State private var showLogoutConfirm = false

    // Account loeschen
    @State private var showDeleteAlert = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            if let userProfile = authService.profile {

                // MARK: Hero Header

                Section {
                    VStack(spacing: 12) {
                        // Avatar mit Kamera-Badge
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

                            Image(systemName: "camera.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .blue)
                                .offset(x: 4, y: 4)
                        }
                        .onTapGesture { showAvatarSheet = true }

                        // Name
                        Text(userProfile.playerName)
                            .font(.title2)
                            .fontWeight(.bold)

                        // Rolle + Kingdom + Verified
                        HStack(spacing: 8) {
                            Text(userProfile.role.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(roleBadgeColor(for: userProfile.role))
                                .clipShape(Capsule())

                            if let tag = userProfile.kingdomTag {
                                Text(tag)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if userProfile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                            }
                        }

                        // Funktionen als kompakte Tags
                        if !userProfile.functions.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(userProfile.functions) { fn in
                                    Label(fn.displayName, systemImage: fn.icon)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(fn.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(fn.color.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // MARK: Profil

                Section("Profil") {
                    LabeledContent("Spieler", value: userProfile.playerName)

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

                // MARK: Travian

                travianSection(for: userProfile)

                // MARK: Prestige

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

                // MARK: Account

                Section {
                    Button("Abmelden", role: .destructive) {
                        showLogoutConfirm = true
                    }

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
        .onAppear {
            loadAvatar()
            loadPrestigeInput()
        }

        // MARK: - Sheets & Dialogs

        .sheet(isPresented: $showAvatarSheet) {
            AvatarEditSheet(
                avatarImage: avatarImage,
                onPhotoPicker: { showPhotoPicker = true },
                onPreset: { applyPreset($0) },
                onRemove: { deleteAvatar() },
                onAvatarGenerator: {
                    showAvatarSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showAvatarGenerator = true
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAvatarGenerator) {
            AvatarGeneratorView(onAvatarSaved: { image in
                saveAvatar(image)
            })
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Profilbild auswählen")
            }
            .photosPickerStyle(.inline)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showVerifySheet) {
            TravianVerifyView()
                .environment(authService)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    saveAvatar(uiImage)
                    showPhotoPicker = false
                    showAvatarSheet = false
                }
            }
        }

        // Abmelden-Bestaetigung
        .alert("Abmelden?", isPresented: $showLogoutConfirm) {
            Button("Abbrechen", role: .cancel) { }
            Button("Abmelden", role: .destructive) {
                authService.signOut()
            }
        } message: {
            Text("Du wirst von deinem Account abgemeldet.")
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

        // Zweiter Alert: Finale Bestaetigung
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
                plusAccountToggle()

                Button {
                    showVerifySheet = true
                } label: {
                    Label("Welt wechseln", systemImage: "arrow.triangle.2.circlepath")
                }
            } header: {
                Text("Travian")
            } footer: {
                Text("Lehnstreuestufe gilt für dein aktuelles Kingdom und wird im Gebäude-Tool auf Baukosten und Bauzeiten angewendet.")
            }
        } else {
            Section("Travian") {
                Button {
                    showVerifySheet = true
                } label: {
                    Label("Travian-Account verknüpfen", systemImage: "link.badge.plus")
                }
                plusAccountToggle()
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
                Text("Lehnstreuestufe")
                Spacer()
                Text("\(authService.profile?.fealtyLevel ?? 0)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func plusAccountToggle() -> some View {
        Toggle(isOn: $hasPlusAccount) {
            HStack {
                Text("Plus Account")
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
    }

    // MARK: - Prestige Section (Inline)

    @ViewBuilder
    private func prestigeSection(for userProfile: UserProfile) -> some View {
        Section {
            HStack {
                Text("Prestige-Punkte")
                Spacer()
                TextField("0", text: $prestigeInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .focused($prestigeFieldFocused)
                    .onChange(of: prestigeFieldFocused) { _, focused in
                        if !focused { savePrestigePoints() }
                    }
            }

            HStack {
                Text("Stufe")
                Spacer()
                let level = computedPrestigeLevel
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
    }

    // MARK: - Computed

    private var computedPrestigeLevel: Int {
        guard let points = Int(prestigeInput), points > 0 else { return 0 }
        return UserProfile.prestigeLevel(from: points)
    }

    // MARK: - Role Badge Color

    private func roleBadgeColor(for role: UserRole) -> Color {
        switch role {
        case .governor: return .gray
        case .duke:     return .blue
        case .viceking: return .purple
        case .king:     return .orange
        case .admin:    return .red
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

    // MARK: - Avatar

    private func loadAvatar() {
        guard let userId = authService.currentUserId else { return }
        if let local = AvatarService.loadLocal(userId: userId) {
            avatarImage = local
            return
        }
        Task { avatarImage = await AvatarService.download(userId: userId) }
    }

    private func saveAvatar(_ image: UIImage) {
        guard let userId = authService.currentUserId else { return }
        avatarImage = image
        Task { await AvatarService.upload(image, userId: userId) }
    }

    private func deleteAvatar() {
        guard let userId = authService.currentUserId else { return }
        avatarImage = nil
        Task { await AvatarService.delete(userId: userId) }
    }

    @MainActor
    private func applyPreset(_ preset: AvatarPreset) {
        let size: CGFloat = 200
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))

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
        saveAvatar(image)
        showAvatarSheet = false
    }

    // MARK: - Prestige

    private func loadPrestigeInput() {
        prestigeInput = "\(authService.profile?.prestigePoints ?? 0)"
    }

    private func savePrestigePoints() {
        guard let points = Int(prestigeInput), points >= 0 else { return }
        guard points != authService.profile?.prestigePoints else { return }

        let oldPoints = authService.profile?.prestigePoints
        authService.profile?.prestigePoints = points

        Task {
            guard let userId = authService.currentUserId else { return }
            do {
                try await SupabaseManager.client
                    .from("profiles")
                    .update(["prestige_points": points])
                    .eq("id", value: userId.uuidString)
                    .execute()
            } catch {
                authService.profile?.prestigePoints = oldPoints ?? 0
                print("[AccountDetailView] savePrestigePoints Fehler: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Account loeschen

    private func performDeleteAccount() async {
        isDeletingAccount = true
        deleteError = nil

        do {
            try await authService.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }

        isDeletingAccount = false
    }

    // MARK: - Treue

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

}

// MARK: - Avatar Edit Sheet

private struct AvatarEditSheet: View {

    let avatarImage: UIImage?
    let onPhotoPicker: () -> Void
    let onPreset: (AvatarPreset) -> Void
    let onRemove: () -> Void
    var onAvatarGenerator: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Avatar Generator
                if let onAvatarGenerator {
                    Section {
                        Button {
                            dismiss()
                            onAvatarGenerator()
                        } label: {
                            Label("Avatar erstellen", systemImage: "face.smiling.inverse")
                        }
                    }
                }

                // Foto hochladen
                Section {
                    Button {
                        onPhotoPicker()
                    } label: {
                        Label("Foto aus Bibliothek wählen", systemImage: "photo.on.rectangle.angled")
                    }
                }

                // Preset-Avatare
                Section("Standardvorgaben") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(AvatarPreset.allCases) { preset in
                            Button {
                                onPreset(preset)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: preset.rawValue)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .foregroundStyle(.white)
                                        .background(.blue.gradient)
                                        .clipShape(Circle())

                                    Text(preset.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Entfernen
                if avatarImage != nil {
                    Section {
                        Button("Profilbild entfernen", role: .destructive) {
                            onRemove()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Profilbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
