import SwiftUI

// MARK: - Verification Required View

/// Zeigt einen Hinweis an, dass der Travian-Account verknüpft werden muss.
/// Wird verwendet wenn ein nicht-verifizierter User auf Calls oder Truppen zugreift.
struct VerificationRequiredView: View {

    @EnvironmentObject private var authService: AuthService
    @State private var showVerifySheet = false

    let feature: String

    var body: some View {
        ContentUnavailableView {
            Label("Travian nicht verknüpft", systemImage: "link.badge.plus")
        } description: {
            Text("Verknüpfe deinen Travian-Account, um \(feature) zu nutzen.")
        } actions: {
            Button {
                showVerifySheet = true
            } label: {
                Text("Jetzt verknüpfen")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .sheet(isPresented: $showVerifySheet) {
            TravianVerifyView()
                .environmentObject(authService)
        }
    }
}
