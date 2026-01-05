import Foundation
import Security

// MARK: - Keychain Error Types

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, LocalizedError, Equatable {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    case encodingError
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .duplicateItem:
            return "An item with this identifier already exists in the Keychain."
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status: \(status)"
        case .invalidData:
            return "The data retrieved from Keychain is invalid."
        case .encodingError:
            return "Failed to encode the data for storage."
        case .decodingError:
            return "Failed to decode the data from storage."
        }
    }
}

// MARK: - Keychain Accessibility

/// Defines when a Keychain item is accessible.
public enum KeychainAccessibility {
    /// Item is accessible when the device is unlocked.
    case whenUnlocked
    /// Item is accessible when the device is unlocked, not included in backups.
    case whenUnlockedThisDeviceOnly
    /// Item is accessible after first unlock until device restart.
    case afterFirstUnlock
    /// Item is accessible after first unlock, not included in backups.
    case afterFirstUnlockThisDeviceOnly

    var secAccessibility: CFString {
        switch self {
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

// MARK: - Keychain Manager Protocol

/// Protocol defining the interface for Keychain operations.
public protocol KeychainManaging: Sendable {
    /// Saves a string value to the Keychain.
    func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws

    /// Retrieves a string value from the Keychain.
    func retrieve(forKey key: String) throws -> String

    /// Deletes an item from the Keychain.
    func delete(forKey key: String) throws

    /// Checks if an item exists in the Keychain.
    func exists(forKey key: String) -> Bool

    /// Updates an existing item in the Keychain or creates it if it does not exist.
    func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws
}

// MARK: - Keychain Manager Implementation

/// Thread-safe manager for Keychain operations.
///
/// This class provides secure storage for sensitive data using the iOS Keychain.
/// All operations are thread-safe and support different accessibility levels.
///
/// Example usage:
/// ```swift
/// let keychain = KeychainManager(service: "com.jogpod.credentials")
/// try keychain.save("my-secret-token", forKey: "oauth_token", accessibility: .afterFirstUnlockThisDeviceOnly)
/// let token = try keychain.retrieve(forKey: "oauth_token")
/// ```
public final class KeychainManager: KeychainManaging, @unchecked Sendable {

    // MARK: - Properties

    /// The service identifier for Keychain items.
    private let service: String

    /// Optional access group for sharing items between apps.
    private let accessGroup: String?

    /// Serial queue for thread-safe operations.
    private let queue = DispatchQueue(label: "com.jogpod.keychain", qos: .userInitiated)

    // MARK: - Initialization

    /// Creates a new KeychainManager instance.
    /// - Parameters:
    ///   - service: The service identifier for Keychain items. Typically the app's bundle identifier.
    ///   - accessGroup: Optional access group for sharing items between apps in the same group.
    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods

    public func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) throws {
        try queue.sync {
            guard let data = value.data(using: .utf8) else {
                throw KeychainError.encodingError
            }

            var query = baseQuery(forKey: key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = accessibility.secAccessibility

            let status = SecItemAdd(query as CFDictionary, nil)

            switch status {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                throw KeychainError.duplicateItem
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    public func retrieve(forKey key: String) throws -> String {
        try queue.sync {
            var query = baseQuery(forKey: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                guard let data = result as? Data,
                      let string = String(data: data, encoding: .utf8) else {
                    throw KeychainError.decodingError
                }
                return string
            case errSecItemNotFound:
                throw KeychainError.itemNotFound
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    public func delete(forKey key: String) throws {
        try queue.sync {
            let query = baseQuery(forKey: key)
            let status = SecItemDelete(query as CFDictionary)

            switch status {
            case errSecSuccess, errSecItemNotFound:
                return
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    public func exists(forKey key: String) -> Bool {
        queue.sync {
            var query = baseQuery(forKey: key)
            query[kSecReturnData as String] = false

            let status = SecItemCopyMatching(query as CFDictionary, nil)
            return status == errSecSuccess
        }
    }

    public func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) throws {
        try queue.sync {
            guard let data = value.data(using: .utf8) else {
                throw KeychainError.encodingError
            }

            let query = baseQuery(forKey: key)

            var attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            attributesToUpdate[kSecAttrAccessible as String] = accessibility.secAccessibility

            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

            switch status {
            case errSecSuccess:
                return
            case errSecItemNotFound:
                // Item does not exist, create it
                try saveInternal(data: data, forKey: key, accessibility: accessibility)
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Deletes all items for this service from the Keychain.
    /// - Warning: This operation cannot be undone.
    public func deleteAll() throws {
        try queue.sync {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]

            if let accessGroup = accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            let status = SecItemDelete(query as CFDictionary)

            switch status {
            case errSecSuccess, errSecItemNotFound:
                return
            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    // MARK: - Private Methods

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func saveInternal(data: Data, forKey key: String, accessibility: KeychainAccessibility) throws {
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessibility.secAccessibility

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - Convenience Extensions

extension KeychainManager {
    /// Saves a Codable value to the Keychain.
    /// - Parameters:
    ///   - value: The Codable value to save.
    ///   - key: The key to associate with the value.
    ///   - accessibility: When the item should be accessible.
    public func save<T: Encodable>(_ value: T, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(string, forKey: key, accessibility: accessibility)
    }

    /// Retrieves a Codable value from the Keychain.
    /// - Parameter key: The key associated with the value.
    /// - Returns: The decoded value.
    public func retrieve<T: Decodable>(forKey key: String) throws -> T {
        let string = try retrieve(forKey: key)
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.decodingError
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
