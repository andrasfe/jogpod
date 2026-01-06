import AuthenticationServices
import Foundation

// MARK: - OAuth Token

/// Represents an OAuth token with expiration tracking.
public struct OAuthToken: Codable, Sendable, Equatable {
    /// The access token for API requests.
    public let accessToken: String

    /// The refresh token for obtaining new access tokens.
    public let refreshToken: String?

    /// The token type (typically "Bearer").
    public let tokenType: String

    /// Time interval until the token expires (from when it was issued).
    public let expiresIn: TimeInterval?

    /// The granted scopes, space-separated.
    public let scope: String?

    /// When the token was issued.
    public let issuedAt: Date

    /// The Fitbit user ID (for OAuth2 responses).
    public let userId: String?

    /// Computed expiration date.
    public var expirationDate: Date? {
        guard let expiresIn = expiresIn else { return nil }
        return issuedAt.addingTimeInterval(expiresIn)
    }

    /// Whether the token has expired.
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            // No expiration info means we assume it's valid
            return false
        }
        // Consider expired 60 seconds before actual expiration for safety margin
        return Date() >= expirationDate.addingTimeInterval(-60)
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: TimeInterval? = nil,
        scope: String? = nil,
        issuedAt: Date = Date(),
        userId: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.issuedAt = issuedAt
        self.userId = userId
    }
}

// MARK: - OAuth1 Token (Legacy Support)

/// Represents OAuth 1.0a tokens for backward compatibility.
public struct OAuth1Token: Codable, Sendable, Equatable {
    /// The OAuth token.
    public let token: String

    /// The OAuth token secret.
    public let tokenSecret: String

    /// The user ID associated with this token.
    public let userId: String?

    public init(token: String, tokenSecret: String, userId: String? = nil) {
        self.token = token
        self.tokenSecret = tokenSecret
        self.userId = userId
    }
}

// MARK: - OAuth Configuration

/// Configuration for an OAuth provider.
public struct OAuthConfiguration: Sendable {
    /// The client ID (OAuth2) or consumer key (OAuth1).
    public let clientId: String

    /// The client secret (OAuth2) or consumer secret (OAuth1).
    public let clientSecret: String

    /// The callback URL scheme (e.g., "jogpod").
    public let callbackURLScheme: String

    /// The full callback URL.
    public let callbackURL: URL

    /// The authorization endpoint URL.
    public let authorizationURL: URL

    /// The token endpoint URL.
    public let tokenURL: URL

    /// The scopes to request.
    public let scopes: [String]

    /// Whether to use PKCE (Proof Key for Code Exchange).
    public let usePKCE: Bool

    /// OAuth version being used.
    public let oauthVersion: OAuthVersion

    public enum OAuthVersion: String, Sendable {
        case oauth1 = "1.0"
        case oauth2 = "2.0"
    }

    public init(
        clientId: String,
        clientSecret: String,
        callbackURLScheme: String,
        callbackURL: URL,
        authorizationURL: URL,
        tokenURL: URL,
        scopes: [String] = [],
        usePKCE: Bool = true,
        oauthVersion: OAuthVersion = .oauth2
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackURLScheme = callbackURLScheme
        self.callbackURL = callbackURL
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.scopes = scopes
        self.usePKCE = usePKCE
        self.oauthVersion = oauthVersion
    }
}

// MARK: - PKCE Generator

/// Generates PKCE (Proof Key for Code Exchange) values for secure OAuth2 flows.
public struct PKCEGenerator: Sendable {
    /// The code verifier (random string).
    public let codeVerifier: String

    /// The code challenge (derived from verifier).
    public let codeChallenge: String

    /// The challenge method used.
    public let codeChallengeMethod: String = "S256"

    public init() {
        // Generate a random 32-byte code verifier
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        self.codeVerifier = Data(bytes).base64URLEncodedString()

        // Generate SHA256 code challenge
        let verifierData = Data(codeVerifier.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        verifierData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        self.codeChallenge = Data(hash).base64URLEncodedString()
    }
}

// MARK: - Base64 URL Encoding

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// CommonCrypto import for SHA256
import CommonCrypto

// MARK: - Token Refresh Configuration

/// Configuration for token refresh retry behavior with exponential backoff.
///
/// This configuration controls how the OAuth service handles transient failures
/// during token refresh operations. It implements exponential backoff with jitter
/// to prevent thundering herd problems when many clients attempt to refresh simultaneously.
///
/// ## Default Behavior
///
/// The default configuration performs up to 3 retry attempts with the following delays:
/// - Attempt 1: ~1 second (with jitter)
/// - Attempt 2: ~2 seconds (with jitter)
/// - Attempt 3: ~4 seconds (with jitter)
///
/// ## Jitter
///
/// Jitter adds randomness to the delay to prevent synchronized retries across multiple
/// clients, which could overwhelm the OAuth server after an outage (thundering herd).
/// The jitter factor determines what percentage of the delay is randomized.
///
/// ## Example
///
/// ```swift
/// let config = TokenRefreshConfiguration(
///     maxRetryCount: 5,
///     baseDelay: 0.5,
///     maxDelay: 30.0,
///     jitterFactor: 0.3
/// )
/// ```
public struct TokenRefreshConfiguration: Sendable, Equatable {
    /// Maximum number of retry attempts (not counting the initial attempt).
    /// A value of 0 means no retries; only the initial attempt is made.
    public let maxRetryCount: Int

    /// Base delay in seconds for the first retry.
    /// Subsequent retries will increase exponentially from this base.
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds between retries.
    /// The exponential backoff will cap at this value.
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff (delay = baseDelay * multiplier^attempt).
    public let multiplier: Double

    /// Jitter factor (0.0 to 1.0) to randomize delays.
    /// A value of 0.25 means up to +/- 25% variation in delay.
    public let jitterFactor: Double

    /// Default configuration suitable for most OAuth providers.
    public static let `default` = TokenRefreshConfiguration(
        maxRetryCount: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitterFactor: 0.25
    )

    /// Aggressive retry configuration for critical operations.
    public static let aggressive = TokenRefreshConfiguration(
        maxRetryCount: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitterFactor: 0.3
    )

    /// No retry configuration (fails immediately on first error).
    public static let noRetry = TokenRefreshConfiguration(
        maxRetryCount: 0,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 1.0,
        jitterFactor: 0
    )

    public init(
        maxRetryCount: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        jitterFactor: Double = 0.25
    ) {
        self.maxRetryCount = max(0, maxRetryCount)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.multiplier = max(1.0, multiplier)
        self.jitterFactor = min(1.0, max(0, jitterFactor))
    }

    /// Calculates the delay for a given retry attempt with jitter.
    /// - Parameter attempt: The retry attempt number (0-based).
    /// - Returns: The delay in seconds with jitter applied.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt >= 0 else { return 0 }

        // Calculate exponential delay: baseDelay * multiplier^attempt
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt))

        // Cap at maximum delay
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Apply jitter: randomize within +/- jitterFactor of the delay
        let jitterRange = cappedDelay * jitterFactor
        let jitter = Double.random(in: -jitterRange...jitterRange)

        return max(0, cappedDelay + jitter)
    }
}

// MARK: - OAuth Service Protocol

/// Protocol defining the interface for OAuth authentication services.
@MainActor
public protocol OAuthServiceProtocol: Sendable {
    /// Initiates the OAuth authorization flow.
    /// - Parameter presentationContext: The window to present the authentication session from.
    /// - Returns: The resulting OAuth token.
    func authorize(presentationContext: ASWebAuthenticationPresentationContextProviding) async throws -> OAuthToken

    /// Refreshes an expired access token.
    /// - Parameter refreshToken: The refresh token to use.
    /// - Returns: The new OAuth token.
    func refreshToken(_ refreshToken: String) async throws -> OAuthToken

    /// Revokes the current token.
    func revokeToken() async throws

    /// Returns the current stored token, if any.
    var currentToken: OAuthToken? { get async }

    /// Whether the user is currently authenticated.
    var isAuthenticated: Bool { get async }
}

// MARK: - OAuth Service Implementation

/// Modern OAuth service using ASWebAuthenticationSession.
///
/// This service replaces the legacy UIWebView-based OAuth implementation with
/// Apple's recommended ASWebAuthenticationSession, providing:
/// - Secure browser-based authentication
/// - Cookie isolation for privacy
/// - Support for PKCE (OAuth 2.0)
/// - Automatic state parameter validation
/// - Token refresh handling
///
/// ## Migration from Legacy OAuth
///
/// The legacy OAuth1Controller used UIWebView which is deprecated and removed in iOS 12+.
/// This service uses ASWebAuthenticationSession which:
/// - Works with iOS 12 and later
/// - Provides Single Sign-On with Safari
/// - Handles the web-based OAuth flow securely
///
/// ## Usage
///
/// ```swift
/// let config = try OAuthConfiguration(...)
/// let service = OAuthService(configuration: config, credentials: credentialsService)
///
/// // Present authentication
/// let token = try await service.authorize(presentationContext: self)
///
/// // Use token for API requests
/// // Token is automatically stored in Keychain
/// ```
@MainActor
public final class OAuthService: OAuthServiceProtocol {

    // MARK: - Properties

    private let configuration: OAuthConfiguration
    private let credentials: CredentialsProviding
    private let urlSession: URLSession
    private let tokenStorageKey: String

    /// Configuration for token refresh retry behavior.
    public let refreshConfiguration: TokenRefreshConfiguration

    /// Current authentication session, if one is in progress.
    private var currentSession: ASWebAuthenticationSession?

    /// PKCE values for the current authorization flow.
    private var currentPKCE: PKCEGenerator?

    /// State parameter for CSRF protection.
    private var currentState: String?

    // MARK: - Initialization

    /// Creates a new OAuth service.
    /// - Parameters:
    ///   - configuration: The OAuth provider configuration.
    ///   - credentials: The credentials service for token storage.
    ///   - urlSession: The URL session for network requests.
    ///   - tokenStorageKey: The key for storing tokens in credentials.
    ///   - refreshConfiguration: Configuration for token refresh retry behavior.
    public init(
        configuration: OAuthConfiguration,
        credentials: CredentialsProviding,
        urlSession: URLSession = .shared,
        tokenStorageKey: String = "oauth_token",
        refreshConfiguration: TokenRefreshConfiguration = .default
    ) {
        self.configuration = configuration
        self.credentials = credentials
        self.urlSession = urlSession
        self.tokenStorageKey = tokenStorageKey
        self.refreshConfiguration = refreshConfiguration
    }

    // MARK: - OAuthServiceProtocol

    public var currentToken: OAuthToken? {
        get async {
            do {
                let tokenJSON = try credentials.credential(for: .fitbitUserToken)
                let data = Data(tokenJSON.utf8)
                return try JSONDecoder().decode(OAuthToken.self, from: data)
            } catch {
                return nil
            }
        }
    }

    public var isAuthenticated: Bool {
        get async {
            guard let token = await currentToken else { return false }
            return !token.isExpired
        }
    }

    public func authorize(
        presentationContext: ASWebAuthenticationPresentationContextProviding
    ) async throws -> OAuthToken {
        // Ensure no operation is in progress
        guard currentSession == nil else {
            throw OAuthError.operationInProgress
        }

        // Generate PKCE values if using OAuth2 with PKCE
        if configuration.usePKCE && configuration.oauthVersion == .oauth2 {
            currentPKCE = PKCEGenerator()
        }

        // Generate state parameter for CSRF protection
        currentState = generateState()

        // Build authorization URL
        let authURL = try buildAuthorizationURL()

        // Create and configure authentication session
        let callbackURLScheme = configuration.callbackURLScheme

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume(throwing: OAuthError.unexpectedState("Service deallocated"))
                        return
                    }

                    self.currentSession = nil

                    do {
                        if let error = error {
                            throw self.handleSessionError(error)
                        }

                        guard let callbackURL = callbackURL else {
                            throw OAuthError.invalidCallback(reason: "No callback URL received")
                        }

                        let token = try await self.handleCallback(callbackURL)
                        continuation.resume(returning: token)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = true

            self.currentSession = session

            if !session.start() {
                self.currentSession = nil
                continuation.resume(throwing: OAuthError.sessionStartFailed(underlying: "Session failed to start"))
            }
        }
    }

    public func refreshToken(_ refreshToken: String) async throws -> OAuthToken {
        try await refreshTokenWithRetry(refreshToken, configuration: refreshConfiguration)
    }

    /// Refreshes an expired access token with configurable retry behavior.
    ///
    /// This method implements exponential backoff with jitter for transient failures.
    /// It will immediately fail without retries for non-retryable errors such as
    /// invalid refresh tokens (which require re-authentication).
    ///
    /// - Parameters:
    ///   - refreshToken: The refresh token to use.
    ///   - configuration: The retry configuration to use.
    /// - Returns: The new OAuth token.
    /// - Throws: `OAuthError.refreshTokenExpired` if the refresh token is invalid,
    ///           `OAuthError.tokenRefreshExhausted` if all retries fail.
    public func refreshTokenWithRetry(
        _ refreshToken: String,
        configuration retryConfig: TokenRefreshConfiguration
    ) async throws -> OAuthToken {
        var lastError: OAuthError = .tokenRefreshFailed(underlying: "No attempts made")
        let totalAttempts = retryConfig.maxRetryCount + 1  // Initial attempt + retries

        for attempt in 0..<totalAttempts {
            do {
                return try await performTokenRefresh(refreshToken)
            } catch let error as OAuthError {
                lastError = error

                // Check if this is a non-retryable error (refresh token expired/invalid)
                if error.isRefreshTokenInvalid {
                    throw OAuthError.refreshTokenExpired
                }

                // Check if we should retry
                let isLastAttempt = attempt == totalAttempts - 1
                if isLastAttempt || !error.isRetryable {
                    // Either we've exhausted retries or the error is not retryable
                    break
                }

                // Calculate delay with jitter and wait before retrying
                let delay = retryConfig.delay(forAttempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Unexpected non-OAuthError
                lastError = .tokenRefreshFailed(underlying: error.localizedDescription)
                break
            }
        }

        // All attempts failed
        if totalAttempts > 1 {
            throw OAuthError.tokenRefreshExhausted(
                attempts: totalAttempts,
                lastError: lastError.localizedDescription
            )
        } else {
            throw lastError
        }
    }

    /// Performs a single token refresh attempt without retries.
    /// - Parameter refreshToken: The refresh token to use.
    /// - Returns: The new OAuth token.
    private func performTokenRefresh(_ refreshToken: String) async throws -> OAuthToken {
        var request = URLRequest(url: configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build refresh token request body
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]

        // Add client secret if required
        if !configuration.clientSecret.isEmpty {
            components.queryItems?.append(
                URLQueryItem(name: "client_secret", value: configuration.clientSecret)
            )
        }

        request.httpBody = components.query?.data(using: .utf8)

        // Add Basic auth header for Fitbit
        let credentials = "\(configuration.clientId):\(configuration.clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            return try handleTokenResponse(data: data, response: response)
        } catch let error as OAuthError {
            throw error
        } catch {
            throw OAuthError.tokenRefreshFailed(underlying: error.localizedDescription)
        }
    }

    public func revokeToken() async throws {
        // Clear stored tokens
        do {
            try credentials.removeCredential(for: .fitbitUserToken)
            try credentials.removeCredential(for: .fitbitUserSecret)
        } catch {
            throw OAuthError.tokenStorageFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Token Management

    /// Gets a valid access token, refreshing if necessary.
    /// - Returns: A valid access token.
    public func getValidAccessToken() async throws -> String {
        guard let token = await currentToken else {
            throw OAuthError.tokenNotFound
        }

        if token.isExpired {
            guard let refreshToken = token.refreshToken else {
                throw OAuthError.tokenExpired
            }

            let newToken = try await self.refreshToken(refreshToken)
            try await storeToken(newToken)
            return newToken.accessToken
        }

        return token.accessToken
    }

    /// Stores a token in secure storage.
    public func storeToken(_ token: OAuthToken) async throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(token)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw OAuthError.tokenStorageFailed(underlying: "Failed to encode token")
            }
            try credentials.setCredential(jsonString, for: .fitbitUserToken)
        } catch let error as OAuthError {
            throw error
        } catch {
            throw OAuthError.tokenStorageFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func buildAuthorizationURL() throws -> URL {
        var components = URLComponents(url: configuration.authorizationURL, resolvingAgainstBaseURL: false)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: configuration.callbackURL.absoluteString)
        ]

        if !configuration.scopes.isEmpty {
            queryItems.append(URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")))
        }

        if let state = currentState {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let pkce = currentPKCE {
            queryItems.append(URLQueryItem(name: "code_challenge", value: pkce.codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw OAuthError.invalidAuthorizationURL(configuration.authorizationURL.absoluteString)
        }

        return url
    }

    private func handleCallback(_ callbackURL: URL) async throws -> OAuthToken {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw OAuthError.invalidCallback(reason: "Could not parse callback URL")
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        // Check for error response
        if let error = params["error"] {
            let description = params["error_description"]
            throw OAuthError.providerError(error: error, description: description)
        }

        // Validate state
        if let returnedState = params["state"], returnedState != currentState {
            throw OAuthError.stateMismatch
        }

        // Extract authorization code
        guard let code = params["code"] else {
            throw OAuthError.missingAuthorizationCode
        }

        // Exchange code for token
        let token = try await exchangeCodeForToken(code)

        // Store token
        try await storeToken(token)

        // Clear PKCE and state
        currentPKCE = nil
        currentState = nil

        return token
    }

    private func exchangeCodeForToken(_ code: String) async throws -> OAuthToken {
        var request = URLRequest(url: configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: configuration.callbackURL.absoluteString),
            URLQueryItem(name: "client_id", value: configuration.clientId)
        ]

        if let pkce = currentPKCE {
            queryItems.append(URLQueryItem(name: "code_verifier", value: pkce.codeVerifier))
        }

        components.queryItems = queryItems
        request.httpBody = components.query?.data(using: .utf8)

        // Add Basic auth header for Fitbit
        let credentials = "\(configuration.clientId):\(configuration.clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            return try handleTokenResponse(data: data, response: response)
        } catch let error as OAuthError {
            throw error
        } catch {
            throw OAuthError.tokenExchangeFailed(underlying: error.localizedDescription)
        }
    }

    private func handleTokenResponse(data: Data, response: URLResponse) throws -> OAuthToken {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError(underlying: "Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error response
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorDict["error"] as? String {
                let description = errorDict["error_description"] as? String
                throw OAuthError.providerError(error: error, description: description)
            }
            throw OAuthError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            return OAuthToken(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                tokenType: tokenResponse.tokenType ?? "Bearer",
                expiresIn: tokenResponse.expiresIn.map { TimeInterval($0) },
                scope: tokenResponse.scope,
                issuedAt: Date(),
                userId: tokenResponse.userId
            )
        } catch {
            throw OAuthError.invalidTokenResponse(reason: error.localizedDescription)
        }
    }

    private func handleSessionError(_ error: Error) -> OAuthError {
        if let authError = error as? ASWebAuthenticationSessionError {
            switch authError.code {
            case .canceledLogin:
                return .userCancelled
            case .presentationContextNotProvided:
                return .sessionStartFailed(underlying: "No presentation context")
            case .presentationContextInvalid:
                return .sessionStartFailed(underlying: "Invalid presentation context")
            @unknown default:
                return .sessionStartFailed(underlying: authError.localizedDescription)
            }
        }
        return .sessionStartFailed(underlying: error.localizedDescription)
    }

    private func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

// MARK: - Token Response DTO

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let scope: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case userId = "user_id"
    }
}

// MARK: - Presentation Context Provider

/// A default presentation context provider using the key window.
public final class DefaultPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the first connected scene's key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback: create a new window (should not happen in practice)
            return ASPresentationAnchor()
        }
        return window
    }
}
