import Foundation

// MARK: - Credential Types

/// Identifies a specific credential stored in the system.
public enum CredentialKey: String, CaseIterable, Sendable {
    // MARK: Fitbit OAuth Credentials (App-level - should be server-side in production)
    case fitbitConsumerKey = "fitbit_consumer_key"
    case fitbitConsumerSecret = "fitbit_consumer_secret"
    case fitbitOAuthCallback = "fitbit_oauth_callback"

    // MARK: Fitbit User OAuth Tokens (User-specific, Legacy OAuth1)
    /// Legacy OAuth 1.0a token. For OAuth2, use `fitbitOAuth2Token` instead.
    case fitbitUserToken = "fitbit_user_oauth_token"
    /// Legacy OAuth 1.0a token secret. Not used in OAuth2.
    case fitbitUserSecret = "fitbit_user_oauth_secret"

    // MARK: Fitbit OAuth2 Tokens (User-specific)
    /// The complete OAuth2 token (JSON-encoded OAuthToken struct).
    /// Contains access token, refresh token, expiration, and scope.
    case fitbitOAuth2Token = "fitbit_oauth2_token"
    /// The OAuth2 refresh token for obtaining new access tokens.
    /// Stored separately for quick access during token refresh operations.
    case fitbitOAuth2RefreshToken = "fitbit_oauth2_refresh_token"
    /// The OAuth2 access token expiration timestamp (ISO 8601 format).
    /// Used to determine if token refresh is needed without decoding the full token.
    case fitbitOAuth2TokenExpiration = "fitbit_oauth2_token_expiration"
    /// The Fitbit user ID associated with the current authentication.
    case fitbitUserId = "fitbit_user_id"

    // MARK: Weather API
    case weatherAPIKey = "weather_api_key"

    /// Human-readable description of the credential.
    public var description: String {
        switch self {
        case .fitbitConsumerKey:
            return "Fitbit Consumer Key"
        case .fitbitConsumerSecret:
            return "Fitbit Consumer Secret"
        case .fitbitOAuthCallback:
            return "Fitbit OAuth Callback URL"
        case .fitbitUserToken:
            return "Fitbit User OAuth Token (Legacy)"
        case .fitbitUserSecret:
            return "Fitbit User OAuth Secret (Legacy)"
        case .fitbitOAuth2Token:
            return "Fitbit OAuth2 Token"
        case .fitbitOAuth2RefreshToken:
            return "Fitbit OAuth2 Refresh Token"
        case .fitbitOAuth2TokenExpiration:
            return "Fitbit OAuth2 Token Expiration"
        case .fitbitUserId:
            return "Fitbit User ID"
        case .weatherAPIKey:
            return "Weather API Key"
        }
    }

    /// Whether this credential is considered sensitive (secret).
    public var isSensitive: Bool {
        switch self {
        case .fitbitConsumerSecret, .fitbitUserSecret, .weatherAPIKey,
             .fitbitOAuth2Token, .fitbitOAuth2RefreshToken:
            return true
        case .fitbitConsumerKey, .fitbitOAuthCallback, .fitbitUserToken,
             .fitbitOAuth2TokenExpiration, .fitbitUserId:
            return false
        }
    }

    /// Whether this credential is a user-specific token (vs app-level credential).
    public var isUserCredential: Bool {
        switch self {
        case .fitbitUserToken, .fitbitUserSecret,
             .fitbitOAuth2Token, .fitbitOAuth2RefreshToken,
             .fitbitOAuth2TokenExpiration, .fitbitUserId:
            return true
        default:
            return false
        }
    }

    /// Whether this credential is part of the OAuth2 token set.
    public var isOAuth2Credential: Bool {
        switch self {
        case .fitbitOAuth2Token, .fitbitOAuth2RefreshToken,
             .fitbitOAuth2TokenExpiration, .fitbitUserId:
            return true
        default:
            return false
        }
    }

    /// Whether this credential is a legacy OAuth1 credential.
    public var isLegacyOAuth1Credential: Bool {
        switch self {
        case .fitbitUserToken, .fitbitUserSecret:
            return true
        default:
            return false
        }
    }
}

/// Represents the current environment for credential resolution.
public enum CredentialEnvironment: String, Sendable {
    case development
    case staging
    case production

    /// Returns the current environment based on build configuration.
    public static var current: CredentialEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - Credentials Service Error

/// Errors that can occur during credential operations.
public enum CredentialsError: Error, LocalizedError, Equatable {
    case credentialNotFound(CredentialKey)
    case credentialNotConfigured(CredentialKey)
    case storageError(String)
    case validationError(String)
    case migrationRequired

    public var errorDescription: String? {
        switch self {
        case .credentialNotFound(let key):
            return "Credential '\(key.description)' was not found."
        case .credentialNotConfigured(let key):
            return "Credential '\(key.description)' has not been configured. Please set up credentials before use."
        case .storageError(let message):
            return "Failed to access credential storage: \(message)"
        case .validationError(let message):
            return "Credential validation failed: \(message)"
        case .migrationRequired:
            return "Credentials require migration from legacy storage."
        }
    }
}

// MARK: - Credentials Service Protocol

/// Protocol for accessing and managing application credentials.
public protocol CredentialsProviding: Sendable {
    /// Retrieves a credential value.
    func credential(for key: CredentialKey) throws -> String

    /// Checks if a credential exists.
    func hasCredential(for key: CredentialKey) -> Bool

    /// Sets a credential value.
    func setCredential(_ value: String, for key: CredentialKey) throws

    /// Removes a credential.
    func removeCredential(for key: CredentialKey) throws

    /// Removes all user-specific credentials (for logout).
    func clearUserCredentials() throws
}

// MARK: - Credentials Service Implementation

/// Service for secure credential management using Keychain storage.
///
/// This service provides a high-level interface for managing application credentials
/// with support for different environments and secure storage via Keychain.
///
/// ## Initial Setup
///
/// Credentials must be configured on first launch. For app-level credentials (like API keys),
/// use the `CredentialsBootstrap` utility during app initialization.
///
/// ## Security Notes
///
/// - All credentials are stored in the iOS Keychain with appropriate protection levels.
/// - User credentials use `afterFirstUnlockThisDeviceOnly` for security.
/// - App credentials should ideally be retrieved from a server in production.
///
/// Example usage:
/// ```swift
/// let credentials = CredentialsService()
///
/// // Check if configured
/// if !credentials.hasCredential(for: .fitbitConsumerKey) {
///     // First launch setup needed
/// }
///
/// // Retrieve credential
/// let apiKey = try credentials.credential(for: .fitbitConsumerKey)
/// ```
public final class CredentialsService: CredentialsProviding, @unchecked Sendable {

    // MARK: - Properties

    private let keychain: KeychainManaging
    private let environment: CredentialEnvironment

    // MARK: - Initialization

    /// Creates a new CredentialsService instance.
    /// - Parameters:
    ///   - keychain: The keychain manager to use for storage.
    ///   - environment: The current environment for credential resolution.
    public init(
        keychain: KeychainManaging? = nil,
        environment: CredentialEnvironment = .current
    ) {
        self.keychain = keychain ?? KeychainManager(service: "com.jogpod.credentials")
        self.environment = environment
    }

    // MARK: - CredentialsProviding

    public func credential(for key: CredentialKey) throws -> String {
        let storageKey = makeStorageKey(for: key)

        do {
            return try keychain.retrieve(forKey: storageKey)
        } catch KeychainError.itemNotFound {
            throw CredentialsError.credentialNotFound(key)
        } catch {
            throw CredentialsError.storageError(error.localizedDescription)
        }
    }

    public func hasCredential(for key: CredentialKey) -> Bool {
        let storageKey = makeStorageKey(for: key)
        return keychain.exists(forKey: storageKey)
    }

    public func setCredential(_ value: String, for key: CredentialKey) throws {
        guard !value.isEmpty else {
            throw CredentialsError.validationError("Credential value cannot be empty")
        }

        let storageKey = makeStorageKey(for: key)
        let accessibility = accessibilityLevel(for: key)

        do {
            try keychain.update(value, forKey: storageKey, accessibility: accessibility)
        } catch {
            throw CredentialsError.storageError(error.localizedDescription)
        }
    }

    public func removeCredential(for key: CredentialKey) throws {
        let storageKey = makeStorageKey(for: key)

        do {
            try keychain.delete(forKey: storageKey)
        } catch KeychainError.itemNotFound {
            // Already removed, ignore
        } catch {
            throw CredentialsError.storageError(error.localizedDescription)
        }
    }

    public func clearUserCredentials() throws {
        for key in CredentialKey.allCases where key.isUserCredential {
            try removeCredential(for: key)
        }
    }

    // MARK: - Validation

    /// Validates that all required app-level credentials are configured.
    /// - Returns: An array of missing credential keys.
    public func validateAppCredentials() -> [CredentialKey] {
        let requiredKeys: [CredentialKey] = [
            .fitbitConsumerKey,
            .fitbitConsumerSecret,
            .fitbitOAuthCallback
        ]

        return requiredKeys.filter { !hasCredential(for: $0) }
    }

    /// Checks if the user has authenticated with Fitbit using OAuth2.
    public var hasFitbitOAuth2Authentication: Bool {
        hasCredential(for: .fitbitOAuth2Token)
    }

    /// Checks if the user has legacy OAuth1 authentication with Fitbit.
    public var hasLegacyFitbitAuthentication: Bool {
        hasCredential(for: .fitbitUserToken) && hasCredential(for: .fitbitUserSecret)
    }

    /// Checks if the user has any form of Fitbit authentication (OAuth2 or legacy OAuth1).
    public var hasFitbitAuthentication: Bool {
        hasFitbitOAuth2Authentication || hasLegacyFitbitAuthentication
    }

    // MARK: - Private Methods

    private func makeStorageKey(for key: CredentialKey) -> String {
        // Include environment in key to support different credentials per environment
        return "\(environment.rawValue)_\(key.rawValue)"
    }

    private func accessibilityLevel(for key: CredentialKey) -> KeychainAccessibility {
        if key.isUserCredential {
            // User tokens need to be available for background refresh
            return .afterFirstUnlockThisDeviceOnly
        } else {
            // App credentials only needed when app is active
            return .whenUnlockedThisDeviceOnly
        }
    }
}

// MARK: - Fitbit Credentials Convenience

extension CredentialsService {
    /// Represents the complete set of Fitbit OAuth credentials.
    public struct FitbitAppCredentials: Sendable {
        public let consumerKey: String
        public let consumerSecret: String
        public let callbackURL: String
    }

    /// Represents the user's Fitbit OAuth tokens.
    public struct FitbitUserTokens: Sendable {
        public let token: String
        public let secret: String
    }

    /// Retrieves all Fitbit app-level credentials.
    /// - Throws: CredentialsError if any credential is missing.
    public func fitbitAppCredentials() throws -> FitbitAppCredentials {
        FitbitAppCredentials(
            consumerKey: try credential(for: .fitbitConsumerKey),
            consumerSecret: try credential(for: .fitbitConsumerSecret),
            callbackURL: try credential(for: .fitbitOAuthCallback)
        )
    }

    /// Retrieves the user's Fitbit OAuth tokens.
    /// - Throws: CredentialsError if tokens are not available.
    public func fitbitUserTokens() throws -> FitbitUserTokens {
        FitbitUserTokens(
            token: try credential(for: .fitbitUserToken),
            secret: try credential(for: .fitbitUserSecret)
        )
    }

    /// Stores the user's Fitbit OAuth tokens after authentication.
    public func storeFitbitUserTokens(token: String, secret: String) throws {
        try setCredential(token, for: .fitbitUserToken)
        try setCredential(secret, for: .fitbitUserSecret)
    }

    /// Clears the user's Fitbit authentication.
    @available(*, deprecated, message: "Use clearFitbitOAuth2Authentication() for OAuth2 tokens")
    public func clearFitbitAuthentication() throws {
        try removeCredential(for: .fitbitUserToken)
        try removeCredential(for: .fitbitUserSecret)
    }
}

// MARK: - Fitbit OAuth2 Credentials Convenience

extension CredentialsService {
    /// Represents a complete OAuth2 token set for Fitbit.
    public struct FitbitOAuth2Credentials: Sendable, Equatable {
        /// The complete JSON-encoded token data.
        public let tokenData: String
        /// The refresh token for obtaining new access tokens.
        public let refreshToken: String?
        /// The expiration date of the access token.
        public let expirationDate: Date?
        /// The Fitbit user ID.
        public let userId: String?

        public init(
            tokenData: String,
            refreshToken: String? = nil,
            expirationDate: Date? = nil,
            userId: String? = nil
        ) {
            self.tokenData = tokenData
            self.refreshToken = refreshToken
            self.expirationDate = expirationDate
            self.userId = userId
        }
    }

    /// Stores the complete OAuth2 token set for Fitbit.
    ///
    /// This method stores the token data along with separately-indexed refresh token
    /// and expiration for efficient access during token refresh operations.
    ///
    /// - Parameters:
    ///   - tokenData: The JSON-encoded OAuthToken data.
    ///   - refreshToken: The refresh token for obtaining new access tokens.
    ///   - expirationDate: When the access token expires.
    ///   - userId: The Fitbit user ID.
    public func storeFitbitOAuth2Token(
        tokenData: String,
        refreshToken: String? = nil,
        expirationDate: Date? = nil,
        userId: String? = nil
    ) throws {
        try setCredential(tokenData, for: .fitbitOAuth2Token)

        if let refreshToken = refreshToken {
            try setCredential(refreshToken, for: .fitbitOAuth2RefreshToken)
        }

        if let expirationDate = expirationDate {
            let formatter = ISO8601DateFormatter()
            let expirationString = formatter.string(from: expirationDate)
            try setCredential(expirationString, for: .fitbitOAuth2TokenExpiration)
        }

        if let userId = userId {
            try setCredential(userId, for: .fitbitUserId)
        }
    }

    /// Retrieves the complete OAuth2 credentials for Fitbit.
    ///
    /// - Returns: The OAuth2 credentials if available.
    /// - Throws: CredentialsError if the token is not available.
    public func fitbitOAuth2Credentials() throws -> FitbitOAuth2Credentials {
        let tokenData = try credential(for: .fitbitOAuth2Token)

        let refreshToken = try? credential(for: .fitbitOAuth2RefreshToken)

        var expirationDate: Date?
        if let expirationString = try? credential(for: .fitbitOAuth2TokenExpiration) {
            let formatter = ISO8601DateFormatter()
            expirationDate = formatter.date(from: expirationString)
        }

        let userId = try? credential(for: .fitbitUserId)

        return FitbitOAuth2Credentials(
            tokenData: tokenData,
            refreshToken: refreshToken,
            expirationDate: expirationDate,
            userId: userId
        )
    }

    /// Retrieves just the refresh token for quick token refresh operations.
    ///
    /// - Returns: The refresh token if available.
    /// - Throws: CredentialsError if the refresh token is not stored.
    public func fitbitOAuth2RefreshToken() throws -> String {
        try credential(for: .fitbitOAuth2RefreshToken)
    }

    /// Checks if the OAuth2 token needs refresh based on stored expiration.
    ///
    /// - Parameter bufferSeconds: Number of seconds before expiration to consider
    ///   the token as needing refresh. Defaults to 300 (5 minutes).
    /// - Returns: `true` if the token is expired or will expire within the buffer period.
    public func fitbitOAuth2TokenNeedsRefresh(bufferSeconds: TimeInterval = 300) -> Bool {
        guard let expirationString = try? credential(for: .fitbitOAuth2TokenExpiration),
              let expirationDate = ISO8601DateFormatter().date(from: expirationString) else {
            // If we can't determine expiration, assume refresh is needed
            return true
        }

        let refreshThreshold = expirationDate.addingTimeInterval(-bufferSeconds)
        return Date() >= refreshThreshold
    }

    /// Updates just the refresh token without modifying other OAuth2 credentials.
    ///
    /// - Parameter refreshToken: The new refresh token.
    public func updateFitbitOAuth2RefreshToken(_ refreshToken: String) throws {
        try setCredential(refreshToken, for: .fitbitOAuth2RefreshToken)
    }

    /// Updates just the token expiration without modifying other OAuth2 credentials.
    ///
    /// - Parameter expirationDate: The new expiration date.
    public func updateFitbitOAuth2Expiration(_ expirationDate: Date) throws {
        let formatter = ISO8601DateFormatter()
        let expirationString = formatter.string(from: expirationDate)
        try setCredential(expirationString, for: .fitbitOAuth2TokenExpiration)
    }

    /// Clears all OAuth2 authentication data for Fitbit.
    public func clearFitbitOAuth2Authentication() throws {
        try removeCredential(for: .fitbitOAuth2Token)
        try removeCredential(for: .fitbitOAuth2RefreshToken)
        try removeCredential(for: .fitbitOAuth2TokenExpiration)
        try removeCredential(for: .fitbitUserId)
    }

    /// Clears all Fitbit authentication (both OAuth2 and legacy OAuth1).
    public func clearAllFitbitAuthentication() throws {
        // Clear OAuth2 credentials
        try clearFitbitOAuth2Authentication()

        // Clear legacy OAuth1 credentials
        try removeCredential(for: .fitbitUserToken)
        try removeCredential(for: .fitbitUserSecret)
    }
}
