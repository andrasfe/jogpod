import Testing
import Foundation
@testable import JogPod

// MARK: - Fitbit OAuth Constants Tests

@Suite("Fitbit OAuth Constants Tests")
struct FitbitOAuthConstantsTests {

    @Test("API base URL is correct")
    func testAPIBaseURL() {
        #expect(FitbitOAuthConstants.apiBaseURL.absoluteString == "https://api.fitbit.com")
    }

    @Test("Authorization URL is correct")
    func testAuthorizationURL() {
        #expect(FitbitOAuthConstants.authorizationURL.absoluteString == "https://www.fitbit.com/oauth2/authorize")
    }

    @Test("Token URL is correct")
    func testTokenURL() {
        #expect(FitbitOAuthConstants.tokenURL.absoluteString == "https://api.fitbit.com/oauth2/token")
    }

    @Test("Revoke URL is correct")
    func testRevokeURL() {
        #expect(FitbitOAuthConstants.revokeURL.absoluteString == "https://api.fitbit.com/oauth2/revoke")
    }

    @Test("Introspect URL is correct")
    func testIntrospectURL() {
        #expect(FitbitOAuthConstants.introspectURL.absoluteString == "https://api.fitbit.com/1.1/oauth2/introspect")
    }

    @Test("Default scopes include activity and profile")
    func testDefaultScopes() {
        let scopes = FitbitOAuthConstants.defaultScopes

        #expect(scopes.contains(.activity))
        #expect(scopes.contains(.profile))
        #expect(scopes.contains(.heartrate))
        #expect(scopes.contains(.location))
    }

    @Test("Token expiration buffer is 5 minutes")
    func testTokenExpirationBuffer() {
        #expect(FitbitOAuthConstants.tokenExpirationBuffer == 300)
    }
}

// MARK: - Fitbit Scope Tests

@Suite("Fitbit Scope Tests")
struct FitbitScopeTests {

    @Test("Activity scope has correct raw value")
    func testActivityScope() {
        #expect(FitbitScope.activity.rawValue == "activity")
    }

    @Test("Cardio fitness scope has correct raw value")
    func testCardioFitnessScope() {
        #expect(FitbitScope.cardioFitness.rawValue == "cardio_fitness")
    }

    @Test("Heart rate scope has correct raw value")
    func testHeartrateScope() {
        #expect(FitbitScope.heartrate.rawValue == "heartrate")
    }

    @Test("Location scope has correct raw value")
    func testLocationScope() {
        #expect(FitbitScope.location.rawValue == "location")
    }

    @Test("All scopes have descriptions")
    func testScopeDescriptions() {
        for scope in FitbitScope.allCases {
            #expect(!scope.description.isEmpty)
        }
    }

    @Test("Activity scope description is correct")
    func testActivityScopeDescription() {
        #expect(FitbitScope.activity.description == "Activity & exercise data")
    }

    @Test("Profile scope description is correct")
    func testProfileScopeDescription() {
        #expect(FitbitScope.profile.description == "User profile")
    }
}

// MARK: - Fitbit User Profile Tests

@Suite("Fitbit User Profile Tests")
struct FitbitUserProfileTests {

    @Test("Profile decodes from JSON correctly")
    func testProfileDecoding() throws {
        let json = """
        {
            "encodedId": "ABC123",
            "displayName": "John",
            "fullName": "John Doe",
            "avatar": "https://example.com/avatar.jpg",
            "avatar150": "https://example.com/avatar150.jpg",
            "memberSince": "2020-01-01",
            "timezone": "America/New_York",
            "strideLengthRunning": 1.2,
            "strideLengthWalking": 0.8
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try decoder.decode(FitbitUserProfile.self, from: data)

        #expect(profile.userId == "ABC123")
        #expect(profile.displayName == "John")
        #expect(profile.fullName == "John Doe")
        #expect(profile.avatar?.absoluteString == "https://example.com/avatar.jpg")
        #expect(profile.memberSince == "2020-01-01")
        #expect(profile.timezone == "America/New_York")
        #expect(profile.strideLengthRunning == 1.2)
        #expect(profile.strideLengthWalking == 0.8)
    }

    @Test("Profile decodes with minimal fields")
    func testProfileMinimalDecoding() throws {
        let json = """
        {
            "encodedId": "ABC123",
            "displayName": "John"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try decoder.decode(FitbitUserProfile.self, from: data)

        #expect(profile.userId == "ABC123")
        #expect(profile.displayName == "John")
        #expect(profile.fullName == nil)
        #expect(profile.avatar == nil)
        #expect(profile.memberSince == nil)
    }

    @Test("Profile is Equatable")
    func testProfileEquatable() throws {
        let json = """
        {
            "encodedId": "ABC123",
            "displayName": "John"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let profile1 = try decoder.decode(FitbitUserProfile.self, from: data)
        let profile2 = try decoder.decode(FitbitUserProfile.self, from: data)

        #expect(profile1 == profile2)
    }

    @Test("Profile is Sendable")
    func testProfileSendable() async throws {
        let json = """
        {
            "encodedId": "ABC123",
            "displayName": "John"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try decoder.decode(FitbitUserProfile.self, from: data)

        let result = await Task.detached {
            return profile.displayName
        }.value

        #expect(result == "John")
    }
}

// MARK: - Fitbit OAuth Provider Initialization Tests

@Suite("Fitbit OAuth Provider Initialization Tests")
struct FitbitOAuthProviderInitTests {

    @Test("Provider throws when credentials not configured")
    func testProviderThrowsWithoutCredentials() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        // No credentials set, should throw
        #expect(throws: OAuthError.self) {
            try FitbitOAuthProvider(credentials: credentials)
        }
    }

    @Test("Provider throws with invalid callback URL")
    func testProviderThrowsWithInvalidCallbackURL() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        // Set up credentials with invalid callback URL
        try credentials.setCredential("client_id", for: .fitbitConsumerKey)
        try credentials.setCredential("client_secret", for: .fitbitConsumerSecret)
        try credentials.setCredential("not a valid url", for: .fitbitOAuthCallback)

        #expect(throws: OAuthError.self) {
            try FitbitOAuthProvider(credentials: credentials)
        }
    }

    @Test("Provider initializes with valid credentials")
    func testProviderInitializesWithValidCredentials() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        try credentials.setCredential("client_id_123", for: .fitbitConsumerKey)
        try credentials.setCredential("client_secret_456", for: .fitbitConsumerSecret)
        try credentials.setCredential("jogpod://oauth/callback", for: .fitbitOAuthCallback)

        let provider = try FitbitOAuthProvider(credentials: credentials)

        // Provider should be created successfully
        let isAuthenticated = await provider.isAuthenticated
        #expect(isAuthenticated == false) // No tokens stored yet
    }

    @Test("Provider accepts custom refresh configuration")
    func testProviderWithCustomRefreshConfiguration() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        try credentials.setCredential("client_id_123", for: .fitbitConsumerKey)
        try credentials.setCredential("client_secret_456", for: .fitbitConsumerSecret)
        try credentials.setCredential("jogpod://oauth/callback", for: .fitbitOAuthCallback)

        let customConfig = TokenRefreshConfiguration(
            maxRetryCount: 5,
            baseDelay: 0.5,
            maxDelay: 60.0
        )

        // Provider should accept custom configuration without throwing
        let provider = try FitbitOAuthProvider(
            credentials: credentials,
            refreshConfiguration: customConfig
        )

        let isAuthenticated = await provider.isAuthenticated
        #expect(isAuthenticated == false)
    }

    @Test("Provider uses aggressive refresh configuration")
    func testProviderWithAggressiveRefreshConfiguration() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        try credentials.setCredential("client_id_123", for: .fitbitConsumerKey)
        try credentials.setCredential("client_secret_456", for: .fitbitConsumerSecret)
        try credentials.setCredential("jogpod://oauth/callback", for: .fitbitOAuthCallback)

        // Provider should accept aggressive configuration for critical operations
        let provider = try FitbitOAuthProvider(
            credentials: credentials,
            refreshConfiguration: .aggressive
        )

        let isAuthenticated = await provider.isAuthenticated
        #expect(isAuthenticated == false)
    }

    @Test("Provider uses no-retry configuration")
    func testProviderWithNoRetryConfiguration() async throws {
        let mockKeychain = MockKeychainManager()
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)

        try credentials.setCredential("client_id_123", for: .fitbitConsumerKey)
        try credentials.setCredential("client_secret_456", for: .fitbitConsumerSecret)
        try credentials.setCredential("jogpod://oauth/callback", for: .fitbitOAuthCallback)

        // Provider should accept no-retry configuration for testing
        let provider = try FitbitOAuthProvider(
            credentials: credentials,
            refreshConfiguration: .noRetry
        )

        let isAuthenticated = await provider.isAuthenticated
        #expect(isAuthenticated == false)
    }
}

// MARK: - Legacy Migration Tests

@Suite("Fitbit Legacy Migration Tests")
struct FitbitLegacyMigrationTests {

    @Test("Detects legacy tokens in UserDefaults")
    func testDetectsLegacyTokens() {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        defaults.set("legacy_token", forKey: "fitbitAuthCode")

        let hasLegacy = FitbitOAuthProvider.hasLegacyTokens(in: defaults)
        #expect(hasLegacy == true)

        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
    }

    @Test("Reports no legacy tokens when none exist")
    func testNoLegacyTokens() {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!

        let hasLegacy = FitbitOAuthProvider.hasLegacyTokens(in: defaults)
        #expect(hasLegacy == false)

        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
    }

    @Test("Clears legacy tokens from UserDefaults")
    func testClearsLegacyTokens() {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        defaults.set("legacy_token", forKey: "fitbitAuthCode")
        defaults.set("legacy_secret", forKey: "fitbitSecret")
        defaults.set("legacy_user", forKey: "fitbitUserId")

        FitbitOAuthProvider.clearLegacyTokens(from: defaults)

        #expect(defaults.string(forKey: "fitbitAuthCode") == nil)
        #expect(defaults.string(forKey: "fitbitSecret") == nil)
        #expect(defaults.string(forKey: "fitbitUserId") == nil)

        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
    }
}

// MARK: - Mock Keychain Manager

/// A mock keychain manager for testing that stores data in memory.
final class MockKeychainManager: KeychainManaging, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let queue = DispatchQueue(label: "mock.keychain")

    func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        try queue.sync {
            if storage[key] != nil {
                throw KeychainError.duplicateItem
            }
            storage[key] = value
        }
    }

    func retrieve(forKey key: String) throws -> String {
        try queue.sync {
            guard let value = storage[key] else {
                throw KeychainError.itemNotFound
            }
            return value
        }
    }

    func delete(forKey key: String) throws {
        queue.sync {
            storage.removeValue(forKey: key)
        }
    }

    func exists(forKey key: String) -> Bool {
        queue.sync {
            storage[key] != nil
        }
    }

    func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        queue.sync {
            storage[key] = value
        }
    }

    func clear() {
        queue.sync {
            storage.removeAll()
        }
    }
}
