//
//  KeychainService.swift
//  Vault
//
//  Secure storage for API keys. Keys are stored in the iOS Keychain — never
//  in UserDefaults. Generic-password items keyed by a stable account string.
//

import Foundation
import Security

/// Identifiers for each secret we persist.
nonisolated enum KeychainKey: String {
    case finnhub = "com.gdinisio.Vault.finnhubAPIKey"
    case anthropic = "com.gdinisio.Vault.anthropicAPIKey"
    case gemini = "com.gdinisio.Vault.geminiAPIKey"
    case groq = "com.gdinisio.Vault.groqAPIKey"
}

nonisolated struct KeychainService {

    static let shared = KeychainService()
    private let service = "com.gdinisio.Vault"

    /// Store (or update) a value. Passing an empty string deletes the item.
    func set(_ value: String, for key: KeychainKey) {
        guard !value.isEmpty else {
            delete(key)
            return
        }
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    /// Read a value, or nil if not present.
    func get(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Remove a stored value.
    func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    func has(_ key: KeychainKey) -> Bool {
        guard let value = get(key) else { return false }
        return !value.isEmpty
    }
}
