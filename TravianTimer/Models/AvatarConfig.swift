import Foundation
import SwiftUI

// MARK: - Avatar Kategorie

enum AvatarCategory: String, CaseIterable, Codable, Identifiable {
    case frisur
    case augen
    case nase
    case mund
    case schmuck
    case haarfarbe
    case augenfarbe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frisur:     return "Frisur"
        case .augen:      return "Augen"
        case .nase:       return "Nase"
        case .mund:       return "Mund"
        case .schmuck:    return "Schmuck"
        case .haarfarbe:  return "Haarfarbe"
        case .augenfarbe: return "Augenfarbe"
        }
    }

    var icon: String {
        switch self {
        case .frisur:     return "comb.fill"
        case .augen:      return "eye.fill"
        case .nase:       return "nose"
        case .mund:       return "mouth.fill"
        case .schmuck:    return "star.circle.fill"
        case .haarfarbe:  return "paintpalette.fill"
        case .augenfarbe: return "circle.lefthalf.filled"
        }
    }

    /// Ob diese Kategorie einen Farb-Picker statt Varianten-Grid zeigt
    var isColorCategory: Bool {
        self == .haarfarbe || self == .augenfarbe
    }
}

// MARK: - Avatar Konfiguration

struct AvatarConfig: Codable, Equatable {
    var faceShape: Int = 0
    var hairStyle: Int = 0
    var eyeStyle: Int = 0
    var noseStyle: Int = 0
    var mouthStyle: Int = 0
    var accessory: Int = -1           // -1 = keiner
    var hairColor: String = "8B4513"  // Braun
    var eyeColor: String = "4169E1"   // Blau
    var skinColor: String = "FDBCB4"  // Hell
    var backgroundColor: String = "4A90D9" // Blau

    enum CodingKeys: String, CodingKey {
        case faceShape       = "face_shape"
        case hairStyle       = "hair_style"
        case eyeStyle        = "eye_style"
        case noseStyle       = "nose_style"
        case mouthStyle      = "mouth_style"
        case accessory
        case hairColor       = "hair_color"
        case eyeColor        = "eye_color"
        case skinColor       = "skin_color"
        case backgroundColor = "background_color"
    }
}

// MARK: - Avatar Presets

enum AvatarPresetType: String, CaseIterable, Identifiable {
    case krieger
    case koenig
    case spaeherin
    case druide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .krieger:   return "Krieger"
        case .koenig:    return "Koenig"
        case .spaeherin: return "Spaeherin"
        case .druide:    return "Druide"
        }
    }

    var icon: String {
        switch self {
        case .krieger:   return "figure.fencing"
        case .koenig:    return "crown.fill"
        case .spaeherin: return "eye.trianglebadge.exclamationmark"
        case .druide:    return "leaf.fill"
        }
    }

    var config: AvatarConfig {
        switch self {
        case .krieger:
            return AvatarConfig(
                faceShape: 2, hairStyle: 0, eyeStyle: 1, noseStyle: 0,
                mouthStyle: 2, accessory: 0, hairColor: "2C1810",
                eyeColor: "4A6741", skinColor: "D4A574", backgroundColor: "8B0000"
            )
        case .koenig:
            return AvatarConfig(
                faceShape: 1, hairStyle: 3, eyeStyle: 0, noseStyle: 1,
                mouthStyle: 0, accessory: 2, hairColor: "DAA520",
                eyeColor: "4169E1", skinColor: "FDBCB4", backgroundColor: "4A0080"
            )
        case .spaeherin:
            return AvatarConfig(
                faceShape: 0, hairStyle: 2, eyeStyle: 2, noseStyle: 2,
                mouthStyle: 1, accessory: -1, hairColor: "1A1A2E",
                eyeColor: "228B22", skinColor: "C68642", backgroundColor: "2F4F4F"
            )
        case .druide:
            return AvatarConfig(
                faceShape: 0, hairStyle: 4, eyeStyle: 3, noseStyle: 0,
                mouthStyle: 0, accessory: 3, hairColor: "CCCCCC",
                eyeColor: "9370DB", skinColor: "FFE0BD", backgroundColor: "006400"
            )
        }
    }
}

// MARK: - Farbpaletten

enum AvatarColorPalette {

    static let hairColors: [(name: String, hex: String)] = [
        ("Schwarz",     "1A1A1A"),
        ("Dunkelbraun", "3B2314"),
        ("Braun",       "8B4513"),
        ("Kastanie",    "954535"),
        ("Rotbraun",    "A0522D"),
        ("Rot",         "B22222"),
        ("Blond",       "DAA520"),
        ("Hellblond",   "F0E68C"),
        ("Grau",        "A9A9A9"),
        ("Weiss",       "E8E8E8"),
    ]

    static let eyeColors: [(name: String, hex: String)] = [
        ("Braun",      "8B4513"),
        ("Dunkelbraun","3B2314"),
        ("Haselnuss",  "8E7618"),
        ("Gruen",      "228B22"),
        ("Hellgruen",  "6B8E23"),
        ("Blau",       "4169E1"),
        ("Hellblau",   "87CEEB"),
        ("Grau",       "708090"),
        ("Violett",    "9370DB"),
        ("Bernstein",  "FFBF00"),
    ]

    static let skinColors: [(name: String, hex: String)] = [
        ("Sehr hell",  "FFEBD2"),
        ("Hell",       "FDBCB4"),
        ("Beige",      "FFE0BD"),
        ("Mittel",     "D4A574"),
        ("Oliv",       "C68642"),
        ("Braun",      "8D5524"),
        ("Dunkel",     "6B3A2A"),
        ("Sehr dunkel","3B1F12"),
    ]

    static let backgroundColors: [(name: String, hex: String)] = [
        ("Blau",       "4A90D9"),
        ("Dunkelblau", "2C3E50"),
        ("Gruen",      "27AE60"),
        ("Rot",        "C0392B"),
        ("Lila",       "8E44AD"),
        ("Orange",     "E67E22"),
        ("Dunkelgruen","2F4F4F"),
        ("Grau",       "7F8C8D"),
    ]
}

// MARK: - Supabase Row

struct AvatarConfigRow: Codable {
    let id: UUID?
    let userId: String
    let config: AvatarConfig

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case config
    }

    init(userId: String, config: AvatarConfig) {
        self.id = nil
        self.userId = userId
        self.config = config
    }
}

// MARK: - Color Extension (Hex)

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var hexNumber: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&hexNumber)
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
