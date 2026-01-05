import Foundation

// MARK: - Credential Types

/// Identifies a specific credential stored in the system.
public enum CredentialKey: String, CaseIterable, Sendable {
    // MARK: Fitbit OAuth Credentials (App-level - should be server-side in production)
    case fitbitConsumerKey = "fitbit_consumer_key"
    case fitbitConsumerSecret = "fitbit_consumer_secret"
    case fitbitOAuthCallback = "fitbit_oauth_callback"

    // MARK: Fitbit User OAuth Tokens (User-specific)
    case fitbitUserToken = "fitbit_user_oauth_token"
    case fitbitUserSecret = "fitbit_user_oauth_secret"

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
            return "Fitbit User OAuth Token"
        case .fitbitUserSecret:
            return "Fitbit User OAuth Secret"
        case .weatherAPIKey:
            return "Weather API Key"
        }
    }

    /// Whether this credential is considered sensitive (secret).
    public var isSensitive: Bool {
        switch self {
        case .fitbitConsumerSecret, .fitbitUserSecret, .weatherAPIKey:
            return true
        case .fitbitConsumerKey, .fitbitOAuthCallback, .fitbitUserToken:
            return false
        }
    }

    /// Whether this credential is a user-specific token (vs app-level credential).
    public var isUserCredential: Bool {
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

    /// Checks if the user has authenticated with Fitbit.
    public var hasFitbitAuthentication: Bool {
        hasCredential(for: .fitbitUserToken) && hasCredential(for: .fitbitUserSecret)
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
    public func clearFitbitAuthentication() throws {
        try removeCredential(for: .fitbitUserToken)
        try removeCredential(for: .fitbitUserSecret)
    }
}
