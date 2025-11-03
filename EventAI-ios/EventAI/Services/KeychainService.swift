import Foundation
import Security

/// Service for securely storing and retrieving API keys using iOS Keychain
class KeychainService {

    // MARK: - Keychain Keys
    private static let serviceIdentifier = "com.eventai.apikeys"
    private static let apiKeyAccount = "user_api_key"

    // MARK: - Save API Key
    static func saveAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw KeychainError.emptyKey
        }

        // Convert key to Data
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First, try to delete any existing key
        try? deleteAPIKey()

        // Create query for adding new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    // MARK: - Load API Key
    static func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }

        guard let keyData = result as? Data,
              let key = String(data: keyData, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return key
    }

    // MARK: - Delete API Key
    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Check if API Key Exists
    static func hasAPIKey() -> Bool {
        do {
            return try loadAPIKey() != nil
        } catch {
            return false
        }
    }
}

// MARK: - Keychain Errors
enum KeychainError: LocalizedError {
    case emptyKey
    case encodingFailed
    case decodingFailed
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .encodingFailed:
            return "Failed to encode API key"
        case .decodingFailed:
            return "Failed to decode API key"
        case .saveFailed(let status):
            return "Failed to save API key to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load API key from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete API key from Keychain (status: \(status))"
        }
    }
}
