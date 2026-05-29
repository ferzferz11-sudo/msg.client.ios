import Foundation
import Security

// MARK: - Credential Store

/// Secure credential storage using the iOS Keychain.
/// Matches Android's CredentialStore using EncryptedSharedPreferences.
final class CredentialStore {

    static let shared = CredentialStore()

    private let service = "com.lavender.messenger"
    private let accessGroup: String? = nil

    private enum Key: String {
        case username
        case password
        case userId
        case email
        case serverAddress
    }

    private init() {}

    // MARK: - Save

    func save(username: String? = nil,
              password: String? = nil,
              userId: String? = nil,
              email: String? = nil,
              serverAddress: String? = nil) {

        if let username = username {
            set(key: .username, value: username)
        }
        if let password = password {
            set(key: .password, value: password)
        }
        if let userId = userId {
            set(key: .userId, value: userId)
        }
        if let email = email {
            set(key: .email, value: email)
        }
        if let serverAddress = serverAddress {
            set(key: .serverAddress, value: serverAddress)
        }
    }

    // MARK: - Read

    func getUsername() -> String {
        get(key: .username) ?? ""
    }

    func getPassword() -> String {
        get(key: .password) ?? ""
    }

    func getUserId() -> String {
        get(key: .userId) ?? ""
    }

    func getEmail() -> String {
        get(key: .email) ?? ""
    }

    func getServerAddress() -> String {
        get(key: .serverAddress) ?? "13.140.25.249:50051"
    }

    // MARK: - Clear

    func clear() {
        let keys: [Key] = [.username, .password, .userId, .email, .serverAddress]
        for key in keys {
            delete(key: key)
        }
    }

    // MARK: - Keychain Operations

    private func set(key: Key, value: String) {
        let data = Data(value.utf8)

        // Delete existing item first
        delete(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("[CredentialStore] Failed to save \(key.rawValue): \(status)")
        }
    }

    private func get(key: Key) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: Key) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        SecItemDelete(query as CFDictionary)
    }
}
