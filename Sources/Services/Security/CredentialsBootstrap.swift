import Foundation

// MARK: - Credentials Bootstrap

/// Utility for initializing credentials on first launch or during development.
///
/// This class provides methods to bootstrap credentials from various sources:
/// - Environment variables (for CI/CD)
/// - Configuration files (for development)
/// - Programmatic setup (for testing)
///
/// ## Security Warning
///
/// **NEVER** commit actual credentials to source control. This bootstrap utility
/// is designed to load credentials from secure sources at runtime.
///
/// ## Production Recommendations
///
/// For production apps, consider:
/// 1. Moving OAuth consumer credentials server-side
/// 2. Using App Attest for secure credential delivery
/// 3. Implementing credential rotation
///
/// Example usage:
/// ```swift
/// // In AppDelegate or App initialization
/// let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)
///
/// // For development, load from environment
/// try bootstrap.loadFromEnvironment()
///
/// // Or configure programmatically
/// try bootstrap.configure(
///     fitbitConsumerKey: "key",
///     fitbitConsumerSecret: "secret",
///     fitbitCallback: "https://callback.url"
/// )
/// ```
public final class CredentialsBootstrap: @unchecked Sendable {

    // MARK: - Properties

    private let credentialsService: CredentialsProviding

    // MARK: - Environment Variable Keys

    private enum EnvironmentKey {
        static let fitbitConsumerKey = "JOGPOD_FITBIT_CONSUMER_KEY"
        static let fitbitConsumerSecret = "JOGPOD_FITBIT_CONSUMER_SECRET"
        static let fitbitCallback = "JOGPOD_FITBIT_CALLBACK"
        static let weatherAPIKey = "JOGPOD_WEATHER_API_KEY"
    }

    // MARK: - Initialization

    public init(credentialsService: CredentialsProviding) {
        self.credentialsService = credentialsService
    }

    // MARK: - Bootstrap Methods

    /// Loads credentials from environment variables.
    ///
    /// This method is useful for CI/CD pipelines where credentials are
    /// injected as environment variables.
    ///
    /// Required environment variables:
    /// - `JOGPOD_FITBIT_CONSUMER_KEY`
    /// - `JOGPOD_FITBIT_CONSUMER_SECRET`
    /// - `JOGPOD_FITBIT_CALLBACK`
    ///
    /// Optional:
    /// - `JOGPOD_WEATHER_API_KEY`
    ///
    /// - Parameter overwrite: If true, overwrites existing credentials.
    /// - Throws: CredentialsBootstrapError if required variables are missing.
    public func loadFromEnvironment(overwrite: Bool = false) throws {
        let processInfo = ProcessInfo.processInfo

        // Fitbit credentials
        if let consumerKey = processInfo.environment[EnvironmentKey.fitbitConsumerKey],
           let consumerSecret = processInfo.environment[EnvironmentKey.fitbitConsumerSecret],
           let callback = processInfo.environment[EnvironmentKey.fitbitCallback] {

            if overwrite || !credentialsService.hasCredential(for: .fitbitConsumerKey) {
                try credentialsService.setCredential(consumerKey, for: .fitbitConsumerKey)
            }
            if overwrite || !credentialsService.hasCredential(for: .fitbitConsumerSecret) {
                try credentialsService.setCredential(consumerSecret, for: .fitbitConsumerSecret)
            }
            if overwrite || !credentialsService.hasCredential(for: .fitbitOAuthCallback) {
                try credentialsService.setCredential(callback, for: .fitbitOAuthCallback)
            }
        }

        // Weather API key (optional)
        if let weatherKey = processInfo.environment[EnvironmentKey.weatherAPIKey] {
            if overwrite || !credentialsService.hasCredential(for: .weatherAPIKey) {
                try credentialsService.setCredential(weatherKey, for: .weatherAPIKey)
            }
        }
    }

    /// Configures Fitbit OAuth credentials programmatically.
    ///
    /// - Parameters:
    ///   - consumerKey: The Fitbit consumer key.
    ///   - consumerSecret: The Fitbit consumer secret.
    ///   - callback: The OAuth callback URL.
    ///   - overwrite: If true, overwrites existing credentials.
    public func configureFitbit(
        consumerKey: String,
        consumerSecret: String,
        callback: String,
        overwrite: Bool = false
    ) throws {
        if overwrite || !credentialsService.hasCredential(for: .fitbitConsumerKey) {
            try credentialsService.setCredential(consumerKey, for: .fitbitConsumerKey)
        }
        if overwrite || !credentialsService.hasCredential(for: .fitbitConsumerSecret) {
            try credentialsService.setCredential(consumerSecret, for: .fitbitConsumerSecret)
        }
        if overwrite || !credentialsService.hasCredential(for: .fitbitOAuthCallback) {
            try credentialsService.setCredential(callback, for: .fitbitOAuthCallback)
        }
    }

    /// Configures the Weather API key.
    ///
    /// - Parameters:
    ///   - apiKey: The weather service API key.
    ///   - overwrite: If true, overwrites existing credential.
    public func configureWeatherAPI(apiKey: String, overwrite: Bool = false) throws {
        if overwrite || !credentialsService.hasCredential(for: .weatherAPIKey) {
            try credentialsService.setCredential(apiKey, for: .weatherAPIKey)
        }
    }

    /// Checks if all required credentials are configured.
    /// - Returns: True if all required credentials exist.
    public func isConfigured() -> Bool {
        credentialsService.hasCredential(for: .fitbitConsumerKey) &&
        credentialsService.hasCredential(for: .fitbitConsumerSecret) &&
        credentialsService.hasCredential(for: .fitbitOAuthCallback)
    }

    /// Returns a list of missing required credentials.
    public func missingCredentials() -> [CredentialKey] {
        var missing: [CredentialKey] = []

        if !credentialsService.hasCredential(for: .fitbitConsumerKey) {
            missing.append(.fitbitConsumerKey)
        }
        if !credentialsService.hasCredential(for: .fitbitConsumerSecret) {
            missing.append(.fitbitConsumerSecret)
        }
        if !credentialsService.hasCredential(for: .fitbitOAuthCallback) {
            missing.append(.fitbitOAuthCallback)
        }

        return missing
    }
}

// MARK: - Configuration File Support

extension CredentialsBootstrap {
    /// Represents the structure of a credentials configuration file.
    public struct CredentialsConfiguration: Codable, Sendable {
        public let fitbit: FitbitConfiguration?
        public let weather: WeatherConfiguration?

        public struct FitbitConfiguration: Codable, Sendable {
            public let consumerKey: String
            public let consumerSecret: String
            public let callbackURL: String
        }

        public struct WeatherConfiguration: Codable, Sendable {
            public let apiKey: String
        }
    }

    /// Loads credentials from a configuration file.
    ///
    /// The configuration file should be a JSON file with the following structure:
    /// ```json
    /// {
    ///     "fitbit": {
    ///         "consumerKey": "your-key",
    ///         "consumerSecret": "your-secret",
    ///         "callbackURL": "https://your-callback"
    ///     },
    ///     "weather": {
    ///         "apiKey": "your-api-key"
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Do not include this file in source control.
    ///
    /// - Parameters:
    ///   - url: The URL of the configuration file.
    ///   - overwrite: If true, overwrites existing credentials.
    public func loadFromConfigurationFile(at url: URL, overwrite: Bool = false) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let config = try decoder.decode(CredentialsConfiguration.self, from: data)

        if let fitbit = config.fitbit {
            try configureFitbit(
                consumerKey: fitbit.consumerKey,
                consumerSecret: fitbit.consumerSecret,
                callback: fitbit.callbackURL,
                overwrite: overwrite
            )
        }

        if let weather = config.weather {
            try configureWeatherAPI(apiKey: weather.apiKey, overwrite: overwrite)
        }
    }
}

// MARK: - Legacy Migration Support

extension CredentialsBootstrap {
    /// Migrates credentials from legacy UserDefaults storage to Keychain.
    ///
    /// The legacy app stored OAuth tokens in UserDefaults, which is insecure.
    /// This method migrates those credentials to secure Keychain storage.
    ///
    /// - Important: This method is deprecated. Use `OAuthTokenMigration` directly
    ///   for better error handling, logging, and idempotency guarantees.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to migrate from.
    /// - Returns: True if any credentials were migrated.
    @available(*, deprecated, message: "Use OAuthTokenMigration.migrate() for improved security and error handling")
    @discardableResult
    public func migrateFromLegacyStorage(userDefaults: UserDefaults = .standard) throws -> Bool {
        let migration = OAuthTokenMigration(
            credentialsService: credentialsService,
            userDefaults: userDefaults
        )

        let status = try migration.migrate()

        switch status {
        case .migrated:
            return true
        case .noLegacyTokens, .alreadyMigrated, .skippedExistingTokens:
            return false
        }
    }

    /// Performs secure OAuth token migration with full status reporting.
    ///
    /// This is the recommended method for migrating legacy OAuth tokens from
    /// UserDefaults to Keychain. It provides:
    /// - Idempotent operation (safe to call multiple times)
    /// - Detailed status reporting
    /// - Logging for debugging
    /// - Verification of successful storage before cleanup
    ///
    /// Call this during app launch, before any Fitbit API calls:
    ///
    /// ```swift
    /// let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)
    /// let status = try bootstrap.migrateOAuthTokens()
    /// print("Migration result: \(status.description)")
    /// ```
    ///
    /// - Parameter userDefaults: The UserDefaults instance to migrate from. Defaults to `.standard`.
    /// - Returns: The migration status indicating what action was taken.
    /// - Throws: `OAuthTokenMigrationError` if migration fails.
    @discardableResult
    public func migrateOAuthTokens(from userDefaults: UserDefaults = .standard) throws -> OAuthTokenMigrationStatus {
        let migration = OAuthTokenMigration(
            credentialsService: credentialsService,
            userDefaults: userDefaults
        )
        return try migration.migrate()
    }

    /// Checks whether OAuth token migration is needed.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to check.
    /// - Returns: `true` if there are legacy tokens that need migration.
    public func needsOAuthTokenMigration(from userDefaults: UserDefaults = .standard) -> Bool {
        let migration = OAuthTokenMigration(
            credentialsService: credentialsService,
            userDefaults: userDefaults
        )
        return migration.needsMigration()
    }
}
