import Testing
import Foundation
@testable import JogPod

// MARK: - OAuth Service Tests

@Suite("OAuth Service Tests")
@MainActor
struct OAuthServiceTests {

    // MARK: - Test Fixtures

    private static func makeConfiguration() -> OAuthConfiguration {
        OAuthConfiguration(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            callbackURLScheme: "jogpod",
            callbackURL: URL(string: "jogpod://oauth/callback")!,
            authorizationURL: URL(string: "https://api.example.com/oauth/authorize")!,
            tokenURL: URL(string: "https://api.example.com/oauth/token")!,
            scopes: ["activity", "profile"],
            usePKCE: true,
            oauthVersion: .oauth2
        )
    }

    private static func makeService(
        mockKeychain: MockKeychainManager = MockKeychainManager()
    ) -> OAuthService {
        let credentials = CredentialsService(keychain: mockKeychain, environment: .development)
        return OAuthService(
            configuration: makeConfiguration(),
            credentials: credentials
        )
    }

    // MARK: - Initialization Tests

    @Test("Service initializes with configuration")
    func testServiceInitialization() {
        let service = Self.makeService()
        // Service should be created successfully
        #expect(service != nil)
    }

    // MARK: - Authentication State Tests

    @Test("Service reports not authenticated when no token stored")
    func testNotAuthenticatedWithoutToken() async {
        let service = Self.makeService()

        let isAuthenticated = await service.isAuthenticated
        #expect(isAuthenticated == false)
    }

    @Test("Service returns nil token when none stored")
    func testNoCurrentToken() async {
        let service = Self.makeService()

        let token = await service.currentToken
        #expect(token == nil)
    }

    // MARK: - Token Storage Tests

    @Test("Service stores token correctly")
    func testStoreToken() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        let token = OAuthToken(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            tokenType: "Bearer",
            expiresIn: 3600
        )

        try await service.storeToken(token)

        let retrievedToken = await service.currentToken
        #expect(retrievedToken?.accessToken == "access_123")
        #expect(retrievedToken?.refreshToken == "refresh_456")
    }

    @Test("Service reports authenticated after storing valid token")
    func testAuthenticatedAfterStoringToken() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: 3600
        )

        try await service.storeToken(token)

        let isAuthenticated = await service.isAuthenticated
        #expect(isAuthenticated == true)
    }

    @Test("Service reports not authenticated with expired token")
    func testNotAuthenticatedWithExpiredToken() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        // Create an already-expired token
        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: 1, // 1 second
            issuedAt: Date().addingTimeInterval(-3600) // Issued 1 hour ago
        )

        try await service.storeToken(token)

        let isAuthenticated = await service.isAuthenticated
        #expect(isAuthenticated == false)
    }

    // MARK: - Token Retrieval Tests

    @Test("getValidAccessToken throws when no token stored")
    func testGetValidAccessTokenThrowsWhenNoToken() async {
        let service = Self.makeService()

        do {
            _ = try await service.getValidAccessToken()
            Issue.record("Expected tokenNotFound error")
        } catch let error as OAuthError {
            #expect(error == .tokenNotFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("getValidAccessToken throws when token expired without refresh token")
    func testGetValidAccessTokenThrowsWhenExpiredNoRefresh() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        // Store expired token without refresh token
        let token = OAuthToken(
            accessToken: "expired_token",
            refreshToken: nil,
            expiresIn: 1,
            issuedAt: Date().addingTimeInterval(-3600)
        )
        try await service.storeToken(token)

        do {
            _ = try await service.getValidAccessToken()
            Issue.record("Expected tokenExpired error")
        } catch let error as OAuthError {
            #expect(error == .tokenExpired)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("getValidAccessToken returns valid token")
    func testGetValidAccessTokenReturnsValidToken() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        let token = OAuthToken(
            accessToken: "valid_token_123",
            expiresIn: 3600
        )
        try await service.storeToken(token)

        let accessToken = try await service.getValidAccessToken()
        #expect(accessToken == "valid_token_123")
    }

    // MARK: - Token Revocation Tests

    @Test("revokeToken clears stored tokens")
    func testRevokeTokenClearsStorage() async throws {
        let mockKeychain = MockKeychainManager()
        let service = Self.makeService(mockKeychain: mockKeychain)

        // Store a token
        let token = OAuthToken(accessToken: "access_123")
        try await service.storeToken(token)

        // Verify it's stored
        let storedToken = await service.currentToken
        #expect(storedToken != nil)

        // Revoke
        try await service.revokeToken()

        // Verify it's cleared
        let clearedToken = await service.currentToken
        #expect(clearedToken == nil)
    }
}

// MARK: - Default Presentation Context Provider Tests

@Suite("Default Presentation Context Provider Tests")
struct DefaultPresentationContextProviderTests {

    @Test("Provider can be instantiated")
    func testProviderInstantiation() {
        let provider = DefaultPresentationContextProvider()
        #expect(provider != nil)
    }
}

// MARK: - Token Refresh Configuration Tests

@Suite("Token Refresh Configuration Tests")
struct TokenRefreshConfigurationTests {

    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = TokenRefreshConfiguration.default

        #expect(config.maxRetryCount == 3)
        #expect(config.baseDelay == 1.0)
        #expect(config.maxDelay == 30.0)
        #expect(config.multiplier == 2.0)
        #expect(config.jitterFactor == 0.25)
    }

    @Test("Aggressive configuration has expected values")
    func testAggressiveConfiguration() {
        let config = TokenRefreshConfiguration.aggressive

        #expect(config.maxRetryCount == 5)
        #expect(config.baseDelay == 0.5)
        #expect(config.maxDelay == 60.0)
        #expect(config.multiplier == 2.0)
        #expect(config.jitterFactor == 0.3)
    }

    @Test("No retry configuration has zero retries")
    func testNoRetryConfiguration() {
        let config = TokenRefreshConfiguration.noRetry

        #expect(config.maxRetryCount == 0)
    }

    @Test("Custom configuration stores values correctly")
    func testCustomConfiguration() {
        let config = TokenRefreshConfiguration(
            maxRetryCount: 7,
            baseDelay: 2.0,
            maxDelay: 120.0,
            multiplier: 3.0,
            jitterFactor: 0.5
        )

        #expect(config.maxRetryCount == 7)
        #expect(config.baseDelay == 2.0)
        #expect(config.maxDelay == 120.0)
        #expect(config.multiplier == 3.0)
        #expect(config.jitterFactor == 0.5)
    }

    @Test("Negative values are clamped")
    func testNegativeValuesClamped() {
        let config = TokenRefreshConfiguration(
            maxRetryCount: -5,
            baseDelay: -1.0,
            maxDelay: -10.0,
            multiplier: 0.5, // Less than 1
            jitterFactor: -0.3
        )

        #expect(config.maxRetryCount == 0)
        #expect(config.baseDelay == 0)
        #expect(config.maxDelay >= 0)
        #expect(config.multiplier >= 1.0)
        #expect(config.jitterFactor == 0)
    }

    @Test("Jitter factor is capped at 1.0")
    func testJitterFactorCapped() {
        let config = TokenRefreshConfiguration(jitterFactor: 2.0)
        #expect(config.jitterFactor == 1.0)
    }

    @Test("Delay calculation uses exponential backoff")
    func testExponentialBackoff() {
        // Use zero jitter for predictable testing
        let config = TokenRefreshConfiguration(
            baseDelay: 1.0,
            maxDelay: 100.0,
            multiplier: 2.0,
            jitterFactor: 0
        )

        // Expected delays: 1, 2, 4, 8, 16, 32, 64
        #expect(config.delay(forAttempt: 0) == 1.0)
        #expect(config.delay(forAttempt: 1) == 2.0)
        #expect(config.delay(forAttempt: 2) == 4.0)
        #expect(config.delay(forAttempt: 3) == 8.0)
        #expect(config.delay(forAttempt: 4) == 16.0)
    }

    @Test("Delay is capped at maxDelay")
    func testDelayCappedAtMax() {
        let config = TokenRefreshConfiguration(
            baseDelay: 10.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitterFactor: 0
        )

        // Attempt 0: 10, Attempt 1: 20, Attempt 2: 40 -> capped at 30
        #expect(config.delay(forAttempt: 2) == 30.0)
        #expect(config.delay(forAttempt: 10) == 30.0)
    }

    @Test("Jitter adds randomness within expected range")
    func testJitterRange() {
        let config = TokenRefreshConfiguration(
            baseDelay: 10.0,
            maxDelay: 100.0,
            multiplier: 1.0, // No exponential growth
            jitterFactor: 0.5 // +/- 50%
        )

        // Run multiple times and verify delays are within expected range
        for _ in 0..<100 {
            let delay = config.delay(forAttempt: 0)
            // Expected: 10 +/- 5 (50% of 10)
            #expect(delay >= 5.0)
            #expect(delay <= 15.0)
        }
    }

    @Test("Negative attempt number returns zero delay")
    func testNegativeAttemptReturnsZero() {
        let config = TokenRefreshConfiguration.default
        #expect(config.delay(forAttempt: -1) == 0)
    }

    @Test("Configuration is Equatable")
    func testConfigurationEquatable() {
        let config1 = TokenRefreshConfiguration(maxRetryCount: 3, baseDelay: 1.0)
        let config2 = TokenRefreshConfiguration(maxRetryCount: 3, baseDelay: 1.0)
        let config3 = TokenRefreshConfiguration(maxRetryCount: 5, baseDelay: 1.0)

        #expect(config1 == config2)
        #expect(config1 != config3)
    }

    @Test("Configuration is Sendable")
    func testConfigurationSendable() async {
        let config = TokenRefreshConfiguration.default

        // Verify configuration can be safely passed across concurrency boundaries
        await Task.detached {
            let _ = config.maxRetryCount
        }.value
    }
}

// MARK: - OAuth Service Retry Tests

@Suite("OAuth Service Retry Configuration Tests")
@MainActor
struct OAuthServiceRetryTests {

    private static func makeConfiguration() -> OAuthConfiguration {
        OAuthConfiguration(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            callbackURLScheme: "jogpod",
            callbackURL: URL(string: "jogpod://oauth/callback")!,
            authorizationURL: URL(string: "https://api.example.com/oauth/authorize")!,
            tokenURL: URL(string: "https://api.example.com/oauth/token")!,
            scopes: ["activity", "profile"],
            usePKCE: true,
            oauthVersion: .oauth2
        )
    }

    @Test("Service uses default refresh configuration")
    func testDefaultRefreshConfiguration() {
        let credentials = CredentialsService(
            keychain: MockKeychainManager(),
            environment: .development
        )
        let service = OAuthService(
            configuration: Self.makeConfiguration(),
            credentials: credentials
        )

        #expect(service.refreshConfiguration == .default)
    }

    @Test("Service uses custom refresh configuration")
    func testCustomRefreshConfiguration() {
        let credentials = CredentialsService(
            keychain: MockKeychainManager(),
            environment: .development
        )
        let customConfig = TokenRefreshConfiguration(
            maxRetryCount: 5,
            baseDelay: 0.5
        )
        let service = OAuthService(
            configuration: Self.makeConfiguration(),
            credentials: credentials,
            refreshConfiguration: customConfig
        )

        #expect(service.refreshConfiguration.maxRetryCount == 5)
        #expect(service.refreshConfiguration.baseDelay == 0.5)
    }

    @Test("Service accepts no-retry configuration")
    func testNoRetryConfiguration() {
        let credentials = CredentialsService(
            keychain: MockKeychainManager(),
            environment: .development
        )
        let service = OAuthService(
            configuration: Self.makeConfiguration(),
            credentials: credentials,
            refreshConfiguration: .noRetry
        )

        #expect(service.refreshConfiguration.maxRetryCount == 0)
    }
}
