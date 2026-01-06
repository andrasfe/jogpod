//
//  MockFitbitOAuthProvider.swift
//  JogPod
//
//  Mock implementation of FitbitOAuthProviding for testing.
//  Created for JogPod Revival project.
//

import AuthenticationServices
import Foundation
@testable import JogPod

// MARK: - Mock Fitbit OAuth Provider

/// A mock implementation of FitbitOAuthProviding for testing OAuth flows.
///
/// This mock allows tests to simulate various authentication scenarios without
/// requiring actual network calls or user interaction:
///
/// - Successful authentication
/// - Authentication failures
/// - Token expiration
/// - Sign out
/// - Rate limiting
///
/// ## Usage
///
/// ```swift
/// let mockProvider = MockFitbitOAuthProvider()
///
/// // Configure for success
/// mockProvider.mockProfile = FitbitUserProfile(...)
/// mockProvider.shouldSucceed = true
///
/// // Or configure for failure
/// mockProvider.errorToThrow = OAuthError.userCancelled
///
/// // Use in tests
/// let profile = try await mockProvider.authenticate(presentationContext: context)
/// ```
@MainActor
public final class MockFitbitOAuthProvider: FitbitOAuthProviding, @unchecked Sendable {

    // MARK: - Configuration Properties

    /// The mock profile to return on successful authentication.
    public var mockProfile: FitbitUserProfile?

    /// The mock access token to return.
    public var mockAccessToken: String = "mock_access_token_12345"

    /// Whether authentication should succeed.
    public var shouldSucceed: Bool = true

    /// Error to throw instead of succeeding.
    public var errorToThrow: OAuthError?

    /// Delay before completing authentication (for timeout testing).
    public var authenticationDelay: TimeInterval = 0

    /// Whether the user is currently authenticated.
    public var mockIsAuthenticated: Bool = false

    // MARK: - Call Tracking

    /// Number of times authenticate was called.
    public private(set) var authenticateCallCount: Int = 0

    /// Number of times signOut was called.
    public private(set) var signOutCallCount: Int = 0

    /// Number of times getAccessToken was called.
    public private(set) var getAccessTokenCallCount: Int = 0

    /// The last presentation context passed to authenticate.
    public private(set) var lastPresentationContext: ASWebAuthenticationPresentationContextProviding?

    // MARK: - Initialization

    public init() {
        self.mockProfile = Self.defaultProfile
    }

    // MARK: - FitbitOAuthProviding

    public var currentUser: FitbitUserProfile? {
        get async {
            return mockIsAuthenticated ? mockProfile : nil
        }
    }

    public var isAuthenticated: Bool {
        get async {
            return mockIsAuthenticated
        }
    }

    public func authenticate(
        presentationContext: ASWebAuthenticationPresentationContextProviding
    ) async throws -> FitbitUserProfile {
        authenticateCallCount += 1
        lastPresentationContext = presentationContext

        // Apply delay if configured
        if authenticationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(authenticationDelay * 1_000_000_000))
        }

        // Check for configured error
        if let error = errorToThrow {
            throw error
        }

        // Check if we should fail
        guard shouldSucceed else {
            throw OAuthError.userCancelled
        }

        // Return mock profile
        guard let profile = mockProfile else {
            throw OAuthError.unexpectedState("No mock profile configured")
        }

        mockIsAuthenticated = true
        return profile
    }

    public func signOut() async throws {
        signOutCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        mockIsAuthenticated = false
    }

    public func getAccessToken() async throws -> String {
        getAccessTokenCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard mockIsAuthenticated else {
            throw OAuthError.tokenNotFound
        }

        return mockAccessToken
    }

    // MARK: - Test Helpers

    /// Resets all mock state.
    public func reset() {
        mockProfile = Self.defaultProfile
        mockAccessToken = "mock_access_token_12345"
        shouldSucceed = true
        errorToThrow = nil
        authenticationDelay = 0
        mockIsAuthenticated = false
        authenticateCallCount = 0
        signOutCallCount = 0
        getAccessTokenCallCount = 0
        lastPresentationContext = nil
    }

    /// Simulates a successful authentication.
    public func simulateSuccessfulAuth(profile: FitbitUserProfile? = nil) {
        mockProfile = profile ?? Self.defaultProfile
        shouldSucceed = true
        errorToThrow = nil
        mockIsAuthenticated = true
    }

    /// Simulates an authentication failure.
    public func simulateAuthFailure(error: OAuthError) {
        errorToThrow = error
        shouldSucceed = false
        mockIsAuthenticated = false
    }

    /// Simulates token expiration.
    public func simulateTokenExpiration() {
        errorToThrow = OAuthError.tokenExpired
        mockIsAuthenticated = false
    }

    /// Simulates rate limiting.
    public func simulateRateLimiting(retryAfter: TimeInterval = 3600) {
        errorToThrow = OAuthError.rateLimitExceeded(retryAfter: retryAfter)
    }

    /// Simulates a network error.
    public func simulateNetworkError(message: String = "Network connection lost") {
        errorToThrow = OAuthError.networkError(underlying: message)
    }

    // MARK: - Default Profile

    /// A default mock profile for testing.
    public static var defaultProfile: FitbitUserProfile {
        // Create profile using JSON decoding since properties are let
        let json = """
        {
            "encodedId": "MOCK123",
            "displayName": "Mock User",
            "fullName": "Mock Test User",
            "avatar": "https://example.com/avatar.jpg",
            "avatar150": "https://example.com/avatar150.jpg",
            "memberSince": "2020-01-01",
            "timezone": "America/New_York",
            "strideLengthRunning": 1.2,
            "strideLengthWalking": 0.8
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(FitbitUserProfile.self, from: data)
    }
}

// MARK: - Mock Presentation Context Provider

/// A mock presentation context provider for testing.
@MainActor
public final class MockPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {

    /// The anchor to return. If nil, creates a default anchor.
    public var mockAnchor: ASPresentationAnchor?

    /// Number of times presentationAnchor was called.
    public private(set) var presentationAnchorCallCount: Int = 0

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchorCallCount += 1

        if let anchor = mockAnchor {
            return anchor
        }

        // Return a default anchor
        return ASPresentationAnchor()
    }

    /// Resets the mock state.
    public func reset() {
        mockAnchor = nil
        presentationAnchorCallCount = 0
    }
}

// MARK: - OAuth Flow Simulator

/// Utility for simulating complete OAuth flows in tests.
@MainActor
public final class OAuthFlowSimulator {

    private let provider: MockFitbitOAuthProvider
    private let presentationContext: MockPresentationContextProvider

    /// Creates a new OAuth flow simulator.
    public init() {
        self.provider = MockFitbitOAuthProvider()
        self.presentationContext = MockPresentationContextProvider()
    }

    /// The mock OAuth provider.
    public var oauthProvider: MockFitbitOAuthProvider {
        return provider
    }

    /// The mock presentation context.
    public var context: MockPresentationContextProvider {
        return presentationContext
    }

    /// Simulates a complete successful authentication flow.
    public func simulateSuccessfulLogin(
        profile: FitbitUserProfile? = nil
    ) async throws -> FitbitUserProfile {
        provider.simulateSuccessfulAuth(profile: profile)
        return try await provider.authenticate(presentationContext: presentationContext)
    }

    /// Simulates user cancellation during login.
    public func simulateUserCancellation() async throws {
        provider.simulateAuthFailure(error: .userCancelled)
        _ = try await provider.authenticate(presentationContext: presentationContext)
    }

    /// Simulates a logout flow.
    public func simulateLogout() async throws {
        provider.mockIsAuthenticated = true
        try await provider.signOut()
    }

    /// Resets all simulator state.
    public func reset() {
        provider.reset()
        presentationContext.reset()
    }
}

// MARK: - Mock OAuth Service

/// A mock implementation of OAuthServiceProtocol for testing.
@MainActor
public final class MockOAuthService: OAuthServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Mock token to return.
    public var mockToken: OAuthToken?

    /// Whether the user is authenticated.
    public var mockIsAuthenticated: Bool = false

    /// Error to throw on operations.
    public var errorToThrow: OAuthError?

    // MARK: - Call Tracking

    public private(set) var authorizeCallCount: Int = 0
    public private(set) var refreshTokenCallCount: Int = 0
    public private(set) var revokeTokenCallCount: Int = 0

    // MARK: - OAuthServiceProtocol

    public var currentToken: OAuthToken? {
        get async {
            return mockToken
        }
    }

    public var isAuthenticated: Bool {
        get async {
            return mockIsAuthenticated
        }
    }

    public func authorize(
        presentationContext: ASWebAuthenticationPresentationContextProviding
    ) async throws -> OAuthToken {
        authorizeCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let token = mockToken else {
            throw OAuthError.unexpectedState("No mock token configured")
        }

        mockIsAuthenticated = true
        return token
    }

    public func refreshToken(_ refreshToken: String) async throws -> OAuthToken {
        refreshTokenCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        guard let token = mockToken else {
            throw OAuthError.tokenRefreshFailed(underlying: "No mock token")
        }

        return token
    }

    public func revokeToken() async throws {
        revokeTokenCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        mockToken = nil
        mockIsAuthenticated = false
    }

    // MARK: - Helpers

    /// Resets all mock state.
    public func reset() {
        mockToken = nil
        mockIsAuthenticated = false
        errorToThrow = nil
        authorizeCallCount = 0
        refreshTokenCallCount = 0
        revokeTokenCallCount = 0
    }

    /// Creates a default mock token.
    public static var defaultToken: OAuthToken {
        OAuthToken(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            tokenType: "Bearer",
            expiresIn: 28800,
            scope: "activity profile heartrate location",
            issuedAt: Date(),
            userId: "MOCK123"
        )
    }
}
