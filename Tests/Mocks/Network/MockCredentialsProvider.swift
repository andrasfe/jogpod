//
//  MockCredentialsProvider.swift
//  JogPod
//
//  Mock implementation of CredentialsProviding for testing.
//  Created for JogPod Revival project.
//

import Foundation
@testable import JogPod

// MARK: - Mock Credentials Provider

/// A mock implementation of CredentialsProviding for testing.
///
/// This mock stores credentials in memory and allows tests to configure
/// various scenarios:
///
/// - Pre-populated credentials
/// - Missing credentials
/// - Storage errors
/// - Credential validation failures
///
/// ## Usage
///
/// ```swift
/// let mockCredentials = MockCredentialsProvider()
///
/// // Pre-configure credentials
/// mockCredentials.credentials[.fitbitConsumerKey] = "test_client_id"
///
/// // Or configure for errors
/// mockCredentials.errorToThrow = CredentialsError.storageError("Test error")
///
/// // Use in tests
/// let key = try mockCredentials.credential(for: .fitbitConsumerKey)
/// ```
public final class MockCredentialsProvider: CredentialsProviding, @unchecked Sendable {

    // MARK: - Storage

    /// In-memory storage for credentials.
    public var credentials: [CredentialKey: String] = [:]

    /// Lock for thread-safe access.
    private let lock = NSLock()

    // MARK: - Configuration

    /// Error to throw on any operation.
    public var errorToThrow: CredentialsError?

    /// Specific errors for specific keys.
    public var errorsForKeys: [CredentialKey: CredentialsError] = [:]

    /// Whether to throw on set operations.
    public var throwOnSet: Bool = false

    /// Whether to throw on remove operations.
    public var throwOnRemove: Bool = false

    // MARK: - Call Tracking

    /// Number of times credential(for:) was called.
    public private(set) var getCallCount: Int = 0

    /// Number of times hasCredential(for:) was called.
    public private(set) var hasCallCount: Int = 0

    /// Number of times setCredential was called.
    public private(set) var setCallCount: Int = 0

    /// Number of times removeCredential was called.
    public private(set) var removeCallCount: Int = 0

    /// Number of times clearUserCredentials was called.
    public private(set) var clearUserCallCount: Int = 0

    /// Keys that were accessed.
    public private(set) var accessedKeys: [CredentialKey] = []

    // MARK: - Initialization

    public init() {}

    /// Creates a mock provider with pre-configured credentials.
    public init(credentials: [CredentialKey: String]) {
        self.credentials = credentials
    }

    // MARK: - CredentialsProviding

    public func credential(for key: CredentialKey) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        getCallCount += 1
        accessedKeys.append(key)

        // Check for key-specific error
        if let error = errorsForKeys[key] {
            throw error
        }

        // Check for global error
        if let error = errorToThrow {
            throw error
        }

        guard let value = credentials[key] else {
            throw CredentialsError.credentialNotFound(key)
        }

        return value
    }

    public func hasCredential(for key: CredentialKey) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        hasCallCount += 1
        return credentials[key] != nil
    }

    public func setCredential(_ value: String, for key: CredentialKey) throws {
        lock.lock()
        defer { lock.unlock() }

        setCallCount += 1

        // Check for key-specific error
        if let error = errorsForKeys[key] {
            throw error
        }

        // Check for global error
        if throwOnSet, let error = errorToThrow {
            throw error
        }

        if value.isEmpty {
            throw CredentialsError.validationError("Credential value cannot be empty")
        }

        credentials[key] = value
    }

    public func removeCredential(for key: CredentialKey) throws {
        lock.lock()
        defer { lock.unlock() }

        removeCallCount += 1

        // Check for key-specific error
        if let error = errorsForKeys[key] {
            throw error
        }

        // Check for global error
        if throwOnRemove, let error = errorToThrow {
            throw error
        }

        credentials.removeValue(forKey: key)
    }

    public func clearUserCredentials() throws {
        lock.lock()
        defer { lock.unlock() }

        clearUserCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        for key in CredentialKey.allCases where key.isUserCredential {
            credentials.removeValue(forKey: key)
        }
    }

    // MARK: - Test Helpers

    /// Resets all mock state.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        credentials.removeAll()
        errorToThrow = nil
        errorsForKeys.removeAll()
        throwOnSet = false
        throwOnRemove = false
        getCallCount = 0
        hasCallCount = 0
        setCallCount = 0
        removeCallCount = 0
        clearUserCallCount = 0
        accessedKeys.removeAll()
    }

    /// Pre-configures all Fitbit app credentials.
    public func configureFitbitAppCredentials(
        clientId: String = "test_client_id",
        clientSecret: String = "test_client_secret",
        callbackURL: String = "jogpod://oauth/callback"
    ) {
        lock.lock()
        defer { lock.unlock() }

        credentials[.fitbitConsumerKey] = clientId
        credentials[.fitbitConsumerSecret] = clientSecret
        credentials[.fitbitOAuthCallback] = callbackURL
    }

    /// Pre-configures Fitbit user tokens.
    public func configureFitbitUserTokens(
        token: String = "test_user_token",
        secret: String = "test_user_secret"
    ) {
        lock.lock()
        defer { lock.unlock() }

        credentials[.fitbitUserToken] = token
        credentials[.fitbitUserSecret] = secret
    }

    /// Pre-configures a weather API key.
    public func configureWeatherAPI(key: String = "test_weather_api_key") {
        lock.lock()
        defer { lock.unlock() }

        credentials[.weatherAPIKey] = key
    }

    /// Simulates a credential being not found.
    public func simulateMissingCredential(_ key: CredentialKey) {
        lock.lock()
        defer { lock.unlock() }

        credentials.removeValue(forKey: key)
    }

    /// Simulates a storage error for a specific key.
    public func simulateStorageError(for key: CredentialKey, message: String = "Storage error") {
        lock.lock()
        defer { lock.unlock() }

        errorsForKeys[key] = .storageError(message)
    }

    /// Returns the stored value for a key without incrementing counters.
    public func peekCredential(for key: CredentialKey) -> String? {
        lock.lock()
        defer { lock.unlock() }

        return credentials[key]
    }
}

// MARK: - Mock Credentials Factory

/// Factory for creating pre-configured mock credentials providers.
public enum MockCredentialsFactory {

    /// Creates a mock provider with all credentials configured.
    public static func fullyConfigured() -> MockCredentialsProvider {
        let provider = MockCredentialsProvider()
        provider.configureFitbitAppCredentials()
        provider.configureFitbitUserTokens()
        provider.configureWeatherAPI()
        return provider
    }

    /// Creates a mock provider with only app credentials (not authenticated).
    public static func appCredentialsOnly() -> MockCredentialsProvider {
        let provider = MockCredentialsProvider()
        provider.configureFitbitAppCredentials()
        return provider
    }

    /// Creates a mock provider with no credentials (first launch state).
    public static func unconfigured() -> MockCredentialsProvider {
        return MockCredentialsProvider()
    }

    /// Creates a mock provider that throws errors on all operations.
    public static func failing(error: CredentialsError = .storageError("Mock storage error")) -> MockCredentialsProvider {
        let provider = MockCredentialsProvider()
        provider.errorToThrow = error
        return provider
    }
}

// MARK: - Enhanced Mock Keychain Manager

/// An enhanced mock keychain manager with additional testing features.
///
/// Extends the existing MockKeychainManager with more testing utilities.
public final class EnhancedMockKeychainManager: KeychainManaging, @unchecked Sendable {

    // MARK: - Storage

    private var storage: [String: String] = [:]
    private var accessibilityMap: [String: KeychainAccessibility] = [:]
    private let queue = DispatchQueue(label: "enhanced.mock.keychain")

    // MARK: - Configuration

    /// Error to throw on operations.
    public var errorToThrow: KeychainError?

    /// Specific errors for specific keys.
    public var errorsForKeys: [String: KeychainError] = [:]

    /// Simulate device locked state.
    public var isDeviceLocked: Bool = false

    // MARK: - Call Tracking

    public private(set) var saveCallCount: Int = 0
    public private(set) var retrieveCallCount: Int = 0
    public private(set) var deleteCallCount: Int = 0
    public private(set) var existsCallCount: Int = 0
    public private(set) var updateCallCount: Int = 0

    // MARK: - KeychainManaging

    public func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        try queue.sync {
            saveCallCount += 1

            if let error = errorsForKeys[key] ?? errorToThrow {
                throw error
            }

            if isDeviceLocked && accessibility == .whenUnlockedThisDeviceOnly {
                throw KeychainError.unexpectedStatus(-25293) // errSecAuthFailed
            }

            if storage[key] != nil {
                throw KeychainError.duplicateItem
            }

            storage[key] = value
            accessibilityMap[key] = accessibility
        }
    }

    public func retrieve(forKey key: String) throws -> String {
        try queue.sync {
            retrieveCallCount += 1

            if let error = errorsForKeys[key] ?? errorToThrow {
                throw error
            }

            if isDeviceLocked {
                if let accessibility = accessibilityMap[key],
                   accessibility == .whenUnlockedThisDeviceOnly || accessibility == .whenUnlocked {
                    throw KeychainError.unexpectedStatus(-25293)
                }
            }

            guard let value = storage[key] else {
                throw KeychainError.itemNotFound
            }

            return value
        }
    }

    public func delete(forKey key: String) throws {
        try queue.sync {
            deleteCallCount += 1

            if let error = errorsForKeys[key] ?? errorToThrow {
                throw error
            }

            storage.removeValue(forKey: key)
            accessibilityMap.removeValue(forKey: key)
        }
    }

    public func exists(forKey key: String) -> Bool {
        queue.sync {
            existsCallCount += 1
            return storage[key] != nil
        }
    }

    public func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        try queue.sync {
            updateCallCount += 1

            if let error = errorsForKeys[key] ?? errorToThrow {
                throw error
            }

            storage[key] = value
            accessibilityMap[key] = accessibility
        }
    }

    // MARK: - Test Helpers

    /// Resets all state.
    public func reset() {
        queue.sync {
            storage.removeAll()
            accessibilityMap.removeAll()
            errorToThrow = nil
            errorsForKeys.removeAll()
            isDeviceLocked = false
            saveCallCount = 0
            retrieveCallCount = 0
            deleteCallCount = 0
            existsCallCount = 0
            updateCallCount = 0
        }
    }

    /// Pre-sets a value without incrementing counters.
    public func preset(value: String, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly) {
        queue.sync {
            storage[key] = value
            accessibilityMap[key] = accessibility
        }
    }

    /// Returns all stored keys.
    public var allKeys: [String] {
        queue.sync {
            Array(storage.keys)
        }
    }

    /// Returns the accessibility level for a key.
    public func accessibility(forKey key: String) -> KeychainAccessibility? {
        queue.sync {
            accessibilityMap[key]
        }
    }
}
