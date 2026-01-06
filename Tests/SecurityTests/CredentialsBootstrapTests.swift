import Testing
import Foundation
@testable import JogPod

// MARK: - Credentials Bootstrap Tests

@Suite("Credentials Bootstrap Tests")
struct CredentialsBootstrapTests {

    // MARK: - Mock Credentials Service

    /// Mock CredentialsProviding implementation for testing.
    final class MockCredentialsService: CredentialsProviding, @unchecked Sendable {
        var storedCredentials: [CredentialKey: String] = [:]
        var failOnKey: CredentialKey?
        var errorToThrow: Error = CredentialsError.storageError("Mock error")

        func credential(for key: CredentialKey) throws -> String {
            if key == failOnKey {
                throw errorToThrow
            }
            guard let value = storedCredentials[key] else {
                throw CredentialsError.credentialNotFound(key)
            }
            return value
        }

        func hasCredential(for key: CredentialKey) -> Bool {
            storedCredentials[key] != nil
        }

        func setCredential(_ value: String, for key: CredentialKey) throws {
            if key == failOnKey {
                throw errorToThrow
            }
            storedCredentials[key] = value
        }

        func removeCredential(for key: CredentialKey) throws {
            if key == failOnKey {
                throw errorToThrow
            }
            storedCredentials.removeValue(forKey: key)
        }

        func clearUserCredentials() throws {
            for key in CredentialKey.allCases where key.isUserCredential {
                storedCredentials.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Helper Methods

    private func createBootstrap() -> (CredentialsBootstrap, MockCredentialsService) {
        let mockService = MockCredentialsService()
        let bootstrap = CredentialsBootstrap(credentialsService: mockService)
        return (bootstrap, mockService)
    }

    // MARK: - Configure Fitbit Tests

    @Test("Configure Fitbit sets all three credentials")
    func testConfigureFitbit() throws {
        let (bootstrap, mockService) = createBootstrap()

        try bootstrap.configureFitbit(
            consumerKey: "test_consumer_key",
            consumerSecret: "test_consumer_secret",
            callback: "https://test.callback/oauth"
        )

        #expect(mockService.storedCredentials[.fitbitConsumerKey] == "test_consumer_key")
        #expect(mockService.storedCredentials[.fitbitConsumerSecret] == "test_consumer_secret")
        #expect(mockService.storedCredentials[.fitbitOAuthCallback] == "https://test.callback/oauth")
    }

    @Test("Configure Fitbit does not overwrite existing credentials by default")
    func testConfigureFitbitNoOverwrite() throws {
        let (bootstrap, mockService) = createBootstrap()

        // Pre-populate credentials
        mockService.storedCredentials[.fitbitConsumerKey] = "existing_key"
        mockService.storedCredentials[.fitbitConsumerSecret] = "existing_secret"
        mockService.storedCredentials[.fitbitOAuthCallback] = "existing_callback"

        try bootstrap.configureFitbit(
            consumerKey: "new_key",
            consumerSecret: "new_secret",
            callback: "new_callback"
        )

        // Should retain original values
        #expect(mockService.storedCredentials[.fitbitConsumerKey] == "existing_key")
        #expect(mockService.storedCredentials[.fitbitConsumerSecret] == "existing_secret")
        #expect(mockService.storedCredentials[.fitbitOAuthCallback] == "existing_callback")
    }

    @Test("Configure Fitbit with overwrite replaces existing credentials")
    func testConfigureFitbitWithOverwrite() throws {
        let (bootstrap, mockService) = createBootstrap()

        // Pre-populate credentials
        mockService.storedCredentials[.fitbitConsumerKey] = "existing_key"
        mockService.storedCredentials[.fitbitConsumerSecret] = "existing_secret"
        mockService.storedCredentials[.fitbitOAuthCallback] = "existing_callback"

        try bootstrap.configureFitbit(
            consumerKey: "new_key",
            consumerSecret: "new_secret",
            callback: "new_callback",
            overwrite: true
        )

        // Should have new values
        #expect(mockService.storedCredentials[.fitbitConsumerKey] == "new_key")
        #expect(mockService.storedCredentials[.fitbitConsumerSecret] == "new_secret")
        #expect(mockService.storedCredentials[.fitbitOAuthCallback] == "new_callback")
    }

    // MARK: - Configure Weather API Tests

    @Test("Configure Weather API sets API key")
    func testConfigureWeatherAPI() throws {
        let (bootstrap, mockService) = createBootstrap()

        try bootstrap.configureWeatherAPI(apiKey: "weather_api_123")

        #expect(mockService.storedCredentials[.weatherAPIKey] == "weather_api_123")
    }

    @Test("Configure Weather API does not overwrite by default")
    func testConfigureWeatherAPINoOverwrite() throws {
        let (bootstrap, mockService) = createBootstrap()

        mockService.storedCredentials[.weatherAPIKey] = "existing_key"

        try bootstrap.configureWeatherAPI(apiKey: "new_key")

        #expect(mockService.storedCredentials[.weatherAPIKey] == "existing_key")
    }

    @Test("Configure Weather API with overwrite replaces existing")
    func testConfigureWeatherAPIWithOverwrite() throws {
        let (bootstrap, mockService) = createBootstrap()

        mockService.storedCredentials[.weatherAPIKey] = "existing_key"

        try bootstrap.configureWeatherAPI(apiKey: "new_key", overwrite: true)

        #expect(mockService.storedCredentials[.weatherAPIKey] == "new_key")
    }

    // MARK: - isConfigured Tests

    @Test("isConfigured returns false when no credentials set")
    func testIsConfiguredFalseWhenEmpty() {
        let (bootstrap, _) = createBootstrap()

        #expect(bootstrap.isConfigured() == false)
    }

    @Test("isConfigured returns false when partially configured")
    func testIsConfiguredFalseWhenPartial() {
        let (bootstrap, mockService) = createBootstrap()

        mockService.storedCredentials[.fitbitConsumerKey] = "key"
        mockService.storedCredentials[.fitbitConsumerSecret] = "secret"
        // Missing callback

        #expect(bootstrap.isConfigured() == false)
    }

    @Test("isConfigured returns true when all required credentials set")
    func testIsConfiguredTrueWhenComplete() throws {
        let (bootstrap, _) = createBootstrap()

        try bootstrap.configureFitbit(
            consumerKey: "key",
            consumerSecret: "secret",
            callback: "callback"
        )

        #expect(bootstrap.isConfigured() == true)
    }

    // MARK: - missingCredentials Tests

    @Test("missingCredentials returns all required keys when empty")
    func testMissingCredentialsAllMissing() {
        let (bootstrap, _) = createBootstrap()

        let missing = bootstrap.missingCredentials()

        #expect(missing.contains(.fitbitConsumerKey))
        #expect(missing.contains(.fitbitConsumerSecret))
        #expect(missing.contains(.fitbitOAuthCallback))
        #expect(missing.count == 3)
    }

    @Test("missingCredentials returns only missing keys")
    func testMissingCredentialsPartial() {
        let (bootstrap, mockService) = createBootstrap()

        mockService.storedCredentials[.fitbitConsumerKey] = "key"

        let missing = bootstrap.missingCredentials()

        #expect(!missing.contains(.fitbitConsumerKey))
        #expect(missing.contains(.fitbitConsumerSecret))
        #expect(missing.contains(.fitbitOAuthCallback))
        #expect(missing.count == 2)
    }

    @Test("missingCredentials returns empty array when all configured")
    func testMissingCredentialsNone() throws {
        let (bootstrap, _) = createBootstrap()

        try bootstrap.configureFitbit(
            consumerKey: "key",
            consumerSecret: "secret",
            callback: "callback"
        )

        let missing = bootstrap.missingCredentials()

        #expect(missing.isEmpty)
    }

    // MARK: - Configuration File Tests

    @Test("Configuration struct is Codable")
    func testConfigurationStructCodable() throws {
        let config = CredentialsBootstrap.CredentialsConfiguration(
            fitbit: CredentialsBootstrap.CredentialsConfiguration.FitbitConfiguration(
                consumerKey: "key",
                consumerSecret: "secret",
                callbackURL: "https://callback.url"
            ),
            weather: CredentialsBootstrap.CredentialsConfiguration.WeatherConfiguration(
                apiKey: "weather_key"
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CredentialsBootstrap.CredentialsConfiguration.self, from: data)

        #expect(decoded.fitbit?.consumerKey == "key")
        #expect(decoded.fitbit?.consumerSecret == "secret")
        #expect(decoded.fitbit?.callbackURL == "https://callback.url")
        #expect(decoded.weather?.apiKey == "weather_key")
    }

    @Test("Configuration with only Fitbit is valid")
    func testConfigurationOnlyFitbit() throws {
        let json = """
        {
            "fitbit": {
                "consumerKey": "key",
                "consumerSecret": "secret",
                "callbackURL": "https://callback"
            }
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(
            CredentialsBootstrap.CredentialsConfiguration.self,
            from: json.data(using: .utf8)!
        )

        #expect(config.fitbit != nil)
        #expect(config.weather == nil)
    }

    @Test("Configuration with only weather is valid")
    func testConfigurationOnlyWeather() throws {
        let json = """
        {
            "weather": {
                "apiKey": "weather_123"
            }
        }
        """

        let decoder = JSONDecoder()
        let config = try decoder.decode(
            CredentialsBootstrap.CredentialsConfiguration.self,
            from: json.data(using: .utf8)!
        )

        #expect(config.fitbit == nil)
        #expect(config.weather?.apiKey == "weather_123")
    }

    @Test("Load from configuration file loads all credentials")
    func testLoadFromConfigurationFile() throws {
        let (bootstrap, mockService) = createBootstrap()

        // Create a temporary config file
        let config = """
        {
            "fitbit": {
                "consumerKey": "file_key",
                "consumerSecret": "file_secret",
                "callbackURL": "https://file.callback"
            },
            "weather": {
                "apiKey": "file_weather_key"
            }
        }
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_config_\(UUID().uuidString).json")

        try config.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try bootstrap.loadFromConfigurationFile(at: tempURL)

        #expect(mockService.storedCredentials[.fitbitConsumerKey] == "file_key")
        #expect(mockService.storedCredentials[.fitbitConsumerSecret] == "file_secret")
        #expect(mockService.storedCredentials[.fitbitOAuthCallback] == "https://file.callback")
        #expect(mockService.storedCredentials[.weatherAPIKey] == "file_weather_key")
    }

    @Test("Load from configuration file respects overwrite flag")
    func testLoadFromConfigurationFileNoOverwrite() throws {
        let (bootstrap, mockService) = createBootstrap()

        // Pre-populate
        mockService.storedCredentials[.fitbitConsumerKey] = "existing_key"

        let config = """
        {
            "fitbit": {
                "consumerKey": "new_key",
                "consumerSecret": "new_secret",
                "callbackURL": "https://new.callback"
            }
        }
        """

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_config_\(UUID().uuidString).json")

        try config.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try bootstrap.loadFromConfigurationFile(at: tempURL, overwrite: false)

        // Consumer key should not be overwritten
        #expect(mockService.storedCredentials[.fitbitConsumerKey] == "existing_key")
        // Other credentials should be set
        #expect(mockService.storedCredentials[.fitbitConsumerSecret] == "new_secret")
    }

    // MARK: - OAuth Token Migration Tests

    @Test("Needs OAuth token migration checks correctly")
    func testNeedsOAuthTokenMigration() {
        let mockService = MockCredentialsService()
        let testUserDefaults = UserDefaults(suiteName: "com.jogpod.test.bootstrap.\(UUID().uuidString)")!

        defer {
            testUserDefaults.removePersistentDomain(forName: testUserDefaults.suiteName ?? "")
        }

        let bootstrap = CredentialsBootstrap(credentialsService: mockService)

        // No legacy tokens - should not need migration
        #expect(bootstrap.needsOAuthTokenMigration(from: testUserDefaults) == false)

        // Add legacy token
        testUserDefaults.set("legacy_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)

        // Now should need migration
        #expect(bootstrap.needsOAuthTokenMigration(from: testUserDefaults) == true)

        // Add keychain token
        mockService.storedCredentials[.fitbitUserToken] = "keychain_token"

        // Should not need migration when keychain has tokens
        #expect(bootstrap.needsOAuthTokenMigration(from: testUserDefaults) == false)
    }

    @Test("Migrate OAuth tokens performs migration")
    func testMigrateOAuthTokens() throws {
        let mockService = MockCredentialsService()
        let testSuiteName = "com.jogpod.test.bootstrap.\(UUID().uuidString)"
        let testUserDefaults = UserDefaults(suiteName: testSuiteName)!

        defer {
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
        }

        // Setup legacy tokens
        testUserDefaults.set("legacy_auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        let bootstrap = CredentialsBootstrap(credentialsService: mockService)

        let status = try bootstrap.migrateOAuthTokens(from: testUserDefaults)

        // Verify migration succeeded
        if case .migrated(let tokens) = status {
            #expect(tokens.contains(.fitbitUserToken))
            #expect(tokens.contains(.fitbitUserSecret))
        } else {
            Issue.record("Expected migrated status but got \(status)")
        }

        // Verify tokens are in keychain
        #expect(mockService.storedCredentials[.fitbitUserToken] == "legacy_auth_token")
        #expect(mockService.storedCredentials[.fitbitUserSecret] == "legacy_secret")

        // Verify legacy tokens are removed
        #expect(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue) == nil)
        #expect(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitSecret.rawValue) == nil)
    }
}

// MARK: - Credentials Configuration Tests

@Suite("Credentials Configuration Tests")
struct CredentialsConfigurationTests {

    @Test("Fitbit configuration is Sendable")
    func testFitbitConfigurationSendable() async {
        let config = CredentialsBootstrap.CredentialsConfiguration.FitbitConfiguration(
            consumerKey: "key",
            consumerSecret: "secret",
            callbackURL: "https://callback"
        )

        let result = await Task.detached {
            return config.consumerKey
        }.value

        #expect(result == "key")
    }

    @Test("Weather configuration is Sendable")
    func testWeatherConfigurationSendable() async {
        let config = CredentialsBootstrap.CredentialsConfiguration.WeatherConfiguration(
            apiKey: "weather_key"
        )

        let result = await Task.detached {
            return config.apiKey
        }.value

        #expect(result == "weather_key")
    }

    @Test("Full configuration is Sendable")
    func testFullConfigurationSendable() async {
        let config = CredentialsBootstrap.CredentialsConfiguration(
            fitbit: CredentialsBootstrap.CredentialsConfiguration.FitbitConfiguration(
                consumerKey: "key",
                consumerSecret: "secret",
                callbackURL: "https://callback"
            ),
            weather: CredentialsBootstrap.CredentialsConfiguration.WeatherConfiguration(
                apiKey: "weather_key"
            )
        )

        let result = await Task.detached {
            return config.fitbit?.consumerKey
        }.value

        #expect(result == "key")
    }
}
