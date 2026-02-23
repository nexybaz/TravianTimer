import Foundation

// MARK: - User Roles

/// Rollen im TravianTimer-System (Travian-Hierarchie).
/// Matcht DB-Schema: profiles.role TEXT ('governor' | 'duke' | 'viceking' | 'king' | 'admin')
enum UserRole: String, Codable, CaseIterable, Sendable {
    case governor   // Statthalter — Calls sehen, Truppen zusichern
    case duke       // Herzog      — + Deff-Calls erstellen & aendern
    case viceking   // Vize-Koenig — + Deff-Calls erstellen & aendern
    case king       // Koenig      — + Calls loeschen, Rollen verwalten
    case admin      // Admin       — Vollzugriff

    var displayName: String {
        switch self {
        case .governor: return "Statthalter"
        case .duke:     return "Herzog"
        case .viceking: return "Vize-König"
        case .king:     return "König"
        case .admin:    return "Admin"
        }
    }

    /// Kann Deff-Calls erstellen und Status aendern (ab Herzog)
    var canManageCalls: Bool {
        switch self {
        case .governor: return false
        case .duke, .viceking, .king, .admin: return true
        }
    }

    /// Kann Calls loeschen und Rollen verwalten (ab Koenig)
    var canAdminister: Bool {
        switch self {
        case .governor, .duke, .viceking: return false
        case .king, .admin: return true
        }
    }
}
