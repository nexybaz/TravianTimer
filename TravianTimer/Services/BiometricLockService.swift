import Foundation
import Observation
import LocalAuthentication
import UIKit

// MARK: - Biometric Lock Service

/// Verwaltet die App-Sperre mit Face ID / Touch ID.
/// Die App wird beim Start oder beim Zurückkehren aus dem Hintergrund gesperrt.
@MainActor
@Observable
final class BiometricLockService {

    static let shared = BiometricLockService()

    // MARK: State

    /// Ob der User aktuell gesperrt (= nicht authentifiziert) ist
    var isLocked: Bool = false

    /// Ob gerade eine Biometrie-Abfrage läuft
    var isAuthenticating: Bool = false

    /// Fehlermeldung bei fehlgeschlagener Biometrie
    var errorMessage: String? = nil

    // MARK: Settings

    /// Ob die App-Sperre aktiviert ist (persistiert in UserDefaults)
    var isEnabled: Bool = UserDefaults.standard.bool(forKey: "biometricLockEnabled") {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "biometricLockEnabled") }
    }

    // MARK: Computed

    /// Welcher Biometrie-Typ verfügbar ist (Face ID, Touch ID, oder keiner)
    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Ob Biometrie überhaupt verfügbar ist auf diesem Gerät
    var isBiometryAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Anzeigename des Biometrie-Typs
    var biometryName: String {
        switch biometryType {
        case .faceID:     return "Face ID"
        case .touchID:    return "Touch ID"
        case .opticID:    return "Optic ID"
        @unknown default: return "Biometrie"
        }
    }

    /// SF Symbol für den Biometrie-Typ
    var biometryIcon: String {
        switch biometryType {
        case .faceID:     return "faceid"
        case .touchID:    return "touchid"
        case .opticID:    return "opticid"
        @unknown default: return "lock.shield"
        }
    }

    // MARK: Init

    private init() {
        // Beim App-Start sperren wenn aktiviert
        if isEnabled {
            isLocked = true
        }

        // Auf App-Lifecycle-Events lauschen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    // MARK: - App Lifecycle

    @objc private func appDidEnterBackground() {
        if isEnabled {
            isLocked = true
            errorMessage = nil
        }
    }

    // MARK: - Authenticate

    /// Führt die biometrische Authentifizierung durch.
    /// Bei Erfolg wird `isLocked` auf `false` gesetzt.
    func authenticate() async {
        guard isLocked else { return }
        guard isEnabled else {
            isLocked = false
            return
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Abbrechen"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrie nicht verfügbar → Fallback auf Device Passcode
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "App entsperren"
                )
                if success { isLocked = false }
            } catch {
                errorMessage = "Authentifizierung fehlgeschlagen."
            }
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "TravianTimer entsperren"
            )
            if success {
                isLocked = false
            }
        } catch let authError as LAError {
            switch authError.code {
            case .userCancel:
                // User hat abgebrochen → kein Fehler anzeigen
                break
            case .biometryLockout:
                errorMessage = "\(biometryName) ist gesperrt. Verwende deinen Gerätecode."
                // Fallback auf Passcode
                do {
                    let success = try await context.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: "App entsperren"
                    )
                    if success { isLocked = false }
                } catch {
                    errorMessage = "Authentifizierung fehlgeschlagen."
                }
            case .biometryNotAvailable, .biometryNotEnrolled:
                errorMessage = "\(biometryName) ist nicht eingerichtet."
            default:
                errorMessage = "Authentifizierung fehlgeschlagen."
            }
        } catch {
            errorMessage = "Authentifizierung fehlgeschlagen."
        }
    }

    // MARK: - Toggle Lock

    /// Aktiviert/deaktiviert die App-Sperre.
    /// Bei Aktivierung wird erst Biometrie geprüft um sicherzustellen dass der User berechtigt ist.
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            // Erst Biometrie testen bevor wir aktivieren
            let context = LAContext()
            context.localizedCancelTitle = "Abbrechen"

            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "\(biometryName) für App-Sperre einrichten"
                )
                if success {
                    isEnabled = true
                    return true
                }
            } catch {
                // Biometrie fehlgeschlagen → nicht aktivieren
            }
            return false
        } else {
            isEnabled = false
            isLocked = false
            return true
        }
    }
}
