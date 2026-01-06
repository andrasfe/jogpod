import Testing
import Foundation
@testable import JogPod

// MARK: - Credentials Service Tests

@Suite("Credentials Service Tests")
struct CredentialsServiceTests {

    // MARK: - Mock Keychain

    /// Mock KeychainManaging implementation for testing.
    final class MockKeychain: KeychainManaging, @unchecked Sendable {
        var storage: [String: String] = [:]
        var failOnKey: String?
        var errorToThrow: KeychainError = .unexpectedStatus(-1)

        func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
            if key == failOnKey {
                throw errorToThrow
            }
            if storage[key] != nil {
                throw KeychainError.duplicateItem
            }
            storage[key] = value
        }

        func retrieve(forKey key: String) throws -> String {
            if key == failOnKey {
                throw errorToThrow
            }
            guard let value = storage[key] else {
                throw KeychainError.itemNotFound
            }
            return value
        }

        func delete(forKey key: String) throws {
            if key == failOnKey {
                throw errorToThrow
            }
            storage.removeValue(forKey: key)
        }

        func exists(forKey key: String) -> Bool {
            storage[key] != nil
        }

        func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
            if key == failOnKey {
                throw errorToThrow
            }
            storage[key] = value
        }
    }

    // MARK: - Properties

    private func createService(environment: CredentialEnvironment = .development) -> (CredentialsService, MockKeychain) {
        let mockKeychain = MockKeychain()
        let service = CredentialsService(keychain: mockKeychain, environment: environment)
        return (service, mockKeychain)
    }

    // MARK: - Basic Credential Operations

    @Test("Setting and retrieving a credential works correctly")
    func testSetAndRetrieveCredential() throws {
        let (service, _) = createService()

        try service.setCredential("test_key_value", for: .fitbitConsumerKey)
        let retrieved = try service.credential(for: .fitbitConsumerKey)

        #expect(retrieved == "test_key_value")
    }

    @Test("Checking if credential exists works correctly")
    func testHasCredential() throws {
        let (service, _) = createService()

        #expect(service.hasCredential(for: .fitbitConsumerKey) == false)

        try service.setCredential("test_value", for: .fitbitConsumerKey)

        #expect(service.hasCredential(for: .fitbitConsumerKey) == true)
    }

    @Test("Removing credential works correctly")
    func testRemoveCredential() throws {
        let (service, _) = createService()

        try service.setCredential("test_value", for: .fitbitConsumerKey)
        #expect(service.hasCredential(for: .fitbitConsumerKey) == true)

        try service.removeCredential(for: .fitbitConsumerKey)
        #expect(service.hasCredential(for: .fitbitConsumerKey) == false)
    }

    @Test("Updating credential overwrites existing value")
    func testUpdateCredential() throws {
        let (service, _) = createService()

        try service.setCredential("original_value", for: .fitbitConsumerKey)
        try service.setCredential("updated_value", for: .fitbitConsumerKey)

        let retrieved = try service.credential(for: .fitbitConsumerKey)
        #expect(retrieved == "updated_value")
    }

    // MARK: - Error Handling Tests

    @Test("Retrieving non-existent credential throws credentialNotFound")
    func testRetrieveNonExistentCredential() {
        let (service, _) = createService()

        #expect(throws: CredentialsError.self) {
            _ = try service.credential(for: .fitbitConsumerKey)
        }
    }

    @Test("Setting empty credential throws validationError")
    func testSetEmptyCredential() {
        let (service, _) = createService()

        #expect(throws: CredentialsError.self) {
            try service.setCredential("", for: .fitbitConsumerKey)
        }
    }

    @Test("Keychain storage error is wrapped in CredentialsError")
    func testKeychainStorageError() {
        let (service, mockKeychain) = createService()
        mockKeychain.failOnKey = "development_fitbit_consumer_key"
        mockKeychain.errorToThrow = KeychainError.unexpectedStatus(-34018)

        #expect(throws: CredentialsError.self) {
            try service.setCredential("test", for: .fitbitConsumerKey)
        }
    }

    @Test("Removing non-existent credential does not throw")
    func testRemoveNonExistentCredential() throws {
        let (service, _) = createService()

        // Should not throw
        try service.removeCredential(for: .fitbitConsumerKey)
    }

    // MARK: - Environment-Based Key Tests

    @Test("Credentials are stored with environment prefix")
    func testCredentialEnvironmentPrefix() throws {
        let (service, mockKeychain) = createService(environment: .development)

        try service.setCredential("test_value", for: .fitbitConsumerKey)

        // The storage key should include the environment prefix
        #expect(mockKeychain.storage["development_fitbit_consumer_key"] == "test_value")
    }

    @Test("Credentials are isolated by environment")
    func testCredentialEnvironmentIsolation() throws {
        let mockKeychain = MockKeychain()
        let devService = CredentialsService(keychain: mockKeychain, environment: .development)
        let prodService = CredentialsService(keychain: mockKeychain, environment: .production)

        try devService.setCredential("dev_value", for: .fitbitConsumerKey)
        try prodService.setCredential("prod_value", for: .fitbitConsumerKey)

        let devRetrieved = try devService.credential(for: .fitbitConsumerKey)
        let prodRetrieved = try prodService.credential(for: .fitbitConsumerKey)

        #expect(devRetrieved == "dev_value")
        #expect(prodRetrieved == "prod_value")
    }

    // MARK: - User Credentials Tests

    @Test("Clearing user credentials removes only user-specific credentials")
    func testClearUserCredentials() throws {
        let (service, _) = createService()

        // Set both app-level and user-level credentials
        try service.setCredential("app_key", for: .fitbitConsumerKey)
        try service.setCredential("user_token", for: .fitbitUserToken)
        try service.setCredential("user_secret", for: .fitbitUserSecret)

        // Clear user credentials
        try service.clearUserCredentials()

        // App credential should still exist
        #expect(service.hasCredential(for: .fitbitConsumerKey) == true)
        // User credentials should be removed
        #expect(service.hasCredential(for: .fitbitUserToken) == false)
        #expect(service.hasCredential(for: .fitbitUserSecret) == false)
    }

    // MARK: - Validation Tests

    @Test("Validate app credentials returns missing keys")
    func testValidateAppCredentialsMissing() throws {
        let (service, _) = createService()

        let missing = service.validateAppCredentials()

        #expect(missing.contains(.fitbitConsumerKey))
        #expect(missing.contains(.fitbitConsumerSecret))
        #expect(missing.contains(.fitbitOAuthCallback))
    }

    @Test("Validate app credentials returns empty when all configured")
    func testValidateAppCredentialsComplete() throws {
        let (service, _) = createService()

        try service.setCredential("key", for: .fitbitConsumerKey)
        try service.setCredential("secret", for: .fitbitConsumerSecret)
        try service.setCredential("callback", for: .fitbitOAuthCallback)

        let missing = service.validateAppCredentials()

        #expect(missing.isEmpty)
    }

    @Test("Has Fitbit authentication returns true when both tokens exist")
    func testHasFitbitAuthentication() throws {
        let (service, _) = createService()

        #expect(service.hasFitbitAuthentication == false)

        try service.setCredential("token", for: .fitbitUserToken)
        #expect(service.hasFitbitAuthentication == false)

        try service.setCredential("secret", for: .fitbitUserSecret)
        #expect(service.hasFitbitAuthentication == true)
    }

    // MARK: - Fitbit Credentials Convenience Tests

    @Test("Fitbit app credentials retrieves all three values")
    func testFitbitAppCredentials() throws {
        let (service, _) = createService()

        try service.setCredential("consumer_key_123", for: .fitbitConsumerKey)
        try service.setCredential("consumer_secret_456", for: .fitbitConsumerSecret)
        try service.setCredential("https://callback.url", for: .fitbitOAuthCallback)

        let credentials = try service.fitbitAppCredentials()

        #expect(credentials.consumerKey == "consumer_key_123")
        #expect(credentials.consumerSecret == "consumer_secret_456")
        #expect(credentials.callbackURL == "https://callback.url")
    }

    @Test("Fitbit app credentials throws when any credential is missing")
    func testFitbitAppCredentialsMissing() {
        let (service, _) = createService()

        #expect(throws: CredentialsError.self) {
            _ = try service.fitbitAppCredentials()
        }
    }

    @Test("Fitbit user tokens retrieves both token and secret")
    func testFitbitUserTokens() throws {
        let (service, _) = createService()

        try service.setCredential("user_token_123", for: .fitbitUserToken)
        try service.setCredential("user_secret_456", for: .fitbitUserSecret)

        let tokens = try service.fitbitUserTokens()

        #expect(tokens.token == "user_token_123")
        #expect(tokens.secret == "user_secret_456")
    }

    @Test("Store Fitbit user tokens saves both values")
    func testStoreFitbitUserTokens() throws {
        let (service, _) = createService()

        try service.storeFitbitUserTokens(token: "new_token", secret: "new_secret")

        let retrieved = try service.fitbitUserTokens()
        #expect(retrieved.token == "new_token")
        #expect(retrieved.secret == "new_secret")
    }

    @Test("Clear Fitbit authentication removes both tokens")
    func testClearFitbitAuthentication() throws {
        let (service, _) = createService()

        try service.storeFitbitUserTokens(token: "token", secret: "secret")
        #expect(service.hasFitbitAuthentication == true)

        try service.clearFitbitAuthentication()
        #expect(service.hasFitbitAuthentication == false)
    }
}

// MARK: - Credential Key Tests

@Suite("Credential Key Tests")
struct CredentialKeyTests {

    @Test("Credential keys have correct raw values")
    func testCredentialKeyRawValues() {
        #expect(CredentialKey.fitbitConsumerKey.rawValue == "fitbit_consumer_key")
        #expect(CredentialKey.fitbitConsumerSecret.rawValue == "fitbit_consumer_secret")
        #expect(CredentialKey.fitbitOAuthCallback.rawValue == "fitbit_oauth_callback")
        #expect(CredentialKey.fitbitUserToken.rawValue == "fitbit_user_oauth_token")
        #expect(CredentialKey.fitbitUserSecret.rawValue == "fitbit_user_oauth_secret")
        #expect(CredentialKey.weatherAPIKey.rawValue == "weather_api_key")
    }

    @Test("Credential keys have human-readable descriptions")
    func testCredentialKeyDescriptions() {
        #expect(CredentialKey.fitbitConsumerKey.description.contains("Fitbit"))
        #expect(CredentialKey.fitbitConsumerSecret.description.contains("Secret"))
        #expect(CredentialKey.weatherAPIKey.description.contains("Weather"))
    }

    @Test("Sensitive credentials are correctly identified")
    func testCredentialKeySensitivity() {
        // Secrets and API keys are sensitive
        #expect(CredentialKey.fitbitConsumerSecret.isSensitive == true)
        #expect(CredentialKey.fitbitUserSecret.isSensitive == true)
        #expect(CredentialKey.weatherAPIKey.isSensitive == true)

        // Keys and tokens are not sensitive (public identifiers)
        #expect(CredentialKey.fitbitConsumerKey.isSensitive == false)
        #expect(CredentialKey.fitbitOAuthCallback.isSensitive == false)
        #expect(CredentialKey.fitbitUserToken.isSensitive == false)
    }

    @Test("User credentials are correctly identified")
    func testCredentialKeyIsUserCredential() {
        // User-specific credentials
        #expect(CredentialKey.fitbitUserToken.isUserCredential == true)
        #expect(CredentialKey.fitbitUserSecret.isUserCredential == true)

        // App-level credentials
        #expect(CredentialKey.fitbitConsumerKey.isUserCredential == false)
        #expect(CredentialKey.fitbitConsumerSecret.isUserCredential == false)
        #expect(CredentialKey.fitbitOAuthCallback.isUserCredential == false)
        #expect(CredentialKey.weatherAPIKey.isUserCredential == false)
    }

    @Test("All credential keys are enumerable")
    func testCredentialKeyAllCases() {
        let allKeys = CredentialKey.allCases

        #expect(allKeys.count == 6)
        #expect(allKeys.contains(.fitbitConsumerKey))
        #expect(allKeys.contains(.fitbitConsumerSecret))
        #expect(allKeys.contains(.fitbitOAuthCallback))
        #expect(allKeys.contains(.fitbitUserToken))
        #expect(allKeys.contains(.fitbitUserSecret))
        #expect(allKeys.contains(.weatherAPIKey))
    }
}

// MARK: - Credential Environment Tests

@Suite("Credential Environment Tests")
struct CredentialEnvironmentTests {

    @Test("Environment raw values are correct")
    func testEnvironmentRawValues() {
        #expect(CredentialEnvironment.development.rawValue == "development")
        #expect(CredentialEnvironment.staging.rawValue == "staging")
        #expect(CredentialEnvironment.production.rawValue == "production")
    }

    @Test("Current environment is development in debug builds")
    func testCurrentEnvironmentInDebug() {
        // In test builds, we should be in DEBUG mode
        #if DEBUG
        #expect(CredentialEnvironment.current == .development)
        #else
        #expect(CredentialEnvironment.current == .production)
        #endif
    }
}

// MARK: - Credentials Error Tests

@Suite("Credentials Error Tests")
struct CredentialsErrorTests {

    @Test("Error descriptions are properly formatted")
    func testErrorDescriptions() {
        let testCases: [(CredentialsError, String)] = [
            (.credentialNotFound(.fitbitConsumerKey), "Credential 'Fitbit Consumer Key' was not found."),
            (.credentialNotConfigured(.fitbitUserToken), "Credential 'Fitbit User OAuth Token' has not been configured. Please set up credentials before use."),
            (.storageError("Keychain unavailable"), "Failed to access credential storage: Keychain unavailable"),
            (.validationError("Value too short"), "Credential validation failed: Value too short"),
            (.migrationRequired, "Credentials require migration from legacy storage."),
        ]

        for (error, expectedDescription) in testCases {
            #expect(error.errorDescription == expectedDescription)
        }
    }

    @Test("Errors are equatable")
    func testErrorEquality() {
        #expect(CredentialsError.credentialNotFound(.fitbitConsumerKey) ==
                CredentialsError.credentialNotFound(.fitbitConsumerKey))
        #expect(CredentialsError.credentialNotFound(.fitbitConsumerKey) !=
                CredentialsError.credentialNotFound(.fitbitUserToken))

        #expect(CredentialsError.storageError("Error A") ==
                CredentialsError.storageError("Error A"))
        #expect(CredentialsError.storageError("Error A") !=
                CredentialsError.storageError("Error B"))

        #expect(CredentialsError.migrationRequired ==
                CredentialsError.migrationRequired)
    }

    @Test("Errors conform to LocalizedError")
    func testLocalizedError() {
        let error = CredentialsError.credentialNotFound(.fitbitConsumerKey)

        // LocalizedError should provide errorDescription
        #expect(error.localizedDescription.contains("Fitbit Consumer Key"))
    }
}
