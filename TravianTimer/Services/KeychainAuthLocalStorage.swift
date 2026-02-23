import Foundation
import Supabase

// MARK: - Keychain-basierte Auth Storage

/// Speichert Supabase Auth-Tokens sicher im iOS Keychain
/// statt in UserDefaults (SDK-Default).
final class KeychainAuthLocalStorage: AuthLocalStorage, Sendable {

    private let service = "tt.TravianTimer.auth"

    // MARK: - Store

    func store(key: String, value: Data) throws {
        // Bestehenden Eintrag loeschen (Upsert-Pattern)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        // Neuen Eintrag hinzufuegen
        var addQuery = query
        addQuery[kSecValueData as String] = value
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    // MARK: - Retrieve

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }
        return result as? Data
    }

    // MARK: - Remove

    func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.removeFailed(status)
        }
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case storeFailed(OSStatus)
        case retrieveFailed(OSStatus)
        case removeFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .storeFailed(let s):   return "Keychain store fehlgeschlagen (OSStatus \(s))"
            case .retrieveFailed(let s): return "Keychain retrieve fehlgeschlagen (OSStatus \(s))"
            case .removeFailed(let s):  return "Keychain remove fehlgeschlagen (OSStatus \(s))"
            }
        }
    }
}
