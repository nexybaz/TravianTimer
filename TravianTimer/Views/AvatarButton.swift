import SwiftUI

// MARK: - Avatar Helpers

/// Gibt die lokale Datei-URL fuer das Avatar-Bild eines Users zurueck.
func avatarFileURL(for userId: UUID) -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent("\(userId.uuidString)_avatar.jpg")
}

// MARK: - Avatar Image (reine Anzeige, kein Picker)

/// Zeigt das gespeicherte Avatar-Bild an — oder ein Platzhalter-Icon.
/// Wird z.B. im Settings-Menuepunkt neben dem Spielernamen verwendet.
struct AvatarImage: View {

    @Environment(AuthService.self) var authService
    @State private var avatarImage: UIImage?

    var size: CGFloat = 38

    var body: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .onAppear { loadAvatar() }
    }

    private func loadAvatar() {
        guard let userId = authService.currentUserId else { return }
        let url = avatarFileURL(for: userId)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarImage = image
        }
    }
}

// MARK: - Avatar Button (Top-Right Toolbar)

/// Avatar-Button fuer die Toolbar — oeffnet ein kompaktes Account-Info-Sheet.
struct AvatarButton: View {

    @Environment(AuthService.self) var authService
    @State private var avatarImage: UIImage?
    @State private var showSheet = false

    private let size: CGFloat = 38

    var body: some View {
        Button {
            showSheet = true
        } label: {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .sheet(isPresented: $showSheet) {
            AccountQuickSheet()
                .environment(authService)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadAvatar()
        }
    }

    private func loadAvatar() {
        guard let userId = authService.currentUserId else { return }
        let url = avatarFileURL(for: userId)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarImage = image
        }
    }
}

// MARK: - Account Quick Sheet

private struct AccountQuickSheet: View {

    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false

    private var profile: UserProfile? { authService.profile }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Header (Avatar + Name)

                VStack(spacing: 10) {
                    AvatarImage(size: 72)
                        .environment(authService)

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text(profile?.playerName ?? "Spieler")
                                .font(.title3)
                                .fontWeight(.bold)
                            if profile?.isVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                            }
                        }

                        if let tag = profile?.kingdomTag {
                            Text(tag)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                // MARK: Info Grid

                VStack(spacing: 1) {
                    if let role = profile?.role {
                        InfoRow(icon: "shield.fill", label: "Rolle", value: role.displayName)
                    }

                    if let tribe = profile?.tribe, !tribe.isEmpty {
                        InfoRow(icon: "person.3.fill", label: "Volk", value: tribe)
                    }

                    if let functions = profile?.functions, !functions.isEmpty {
                        InfoRow(
                            icon: "star.fill",
                            label: "Funktion",
                            value: functions.map(\.displayName).joined(separator: ", ")
                        )
                    }

                    if let worldId = profile?.worldId, !worldId.isEmpty {
                        InfoRow(
                            icon: "globe",
                            label: "Welt",
                            value: worldId + (profile?.worldSpeed.map { " (\($0))" } ?? "")
                        )
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                Spacer()

                // MARK: Logout

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Abmelden")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Abmelden?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) {
                    dismiss()
                    authService.signOut()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Du wirst von deinem Account abgemeldet.")
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
    }
}
