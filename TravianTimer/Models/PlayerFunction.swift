import SwiftUI

/// Spieler-Funktion (unabhaengig von der hierarchischen Rolle).
/// Ein Spieler kann mehrere Funktionen gleichzeitig haben.
enum PlayerFunction: String, Codable, CaseIterable, Identifiable, Sendable {
    case deffer  // Deffer
    case offer   // Offer
    case scout   // Spaeher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deffer: return "Deffer"
        case .offer:  return "Offer"
        case .scout:  return "Späher"
        }
    }

    var icon: String {
        switch self {
        case .deffer: return "shield.fill"
        case .offer:  return "flame.fill"
        case .scout:  return "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .deffer: return .blue
        case .offer:  return .red
        case .scout:  return .green
        }
    }
}
