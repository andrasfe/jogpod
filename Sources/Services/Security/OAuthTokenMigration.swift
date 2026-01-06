import Foundation
import os.log

// MARK: - OAuth Token Migration Error

/// Errors that can occur during OAuth token migration from UserDefaults to Keychain.
public enum OAuthTokenMigrationError: Error, LocalizedError, Equatable {
    case keychainStorageFailed(CredentialKey, String)
    case partialMigrationDetected(migratedKeys: [CredentialKey], failedKeys: [CredentialKey])
    case invalidTokenData(CredentialKey)

    public var errorDescription: String? {
        switch self {
        case .keychainStorageFailed(let key, let reason):
            return "Failed to store \(key.description) in Keychain: \(reason)"
        case .partialMigrationDetected(let migrated, let failed):
            let migratedNames = migrated.map(\.description).joined(separator: ", ")
            let failedNames = failed.map(\.description).joined(separator: ", ")
            return "Partial migration detected. Migrated: [\(migratedNames)], Failed: [\(failedNames)]"
        case .invalidTokenData(let key):
            return "Invalid or corrupted token data for \(key.description)"
        }
    }

    public static func == (lhs: OAuthTokenMigrationError, rhs: OAuthTokenMigrationError) -> Bool {
        switch (lhs, rhs) {
        case (.keychainStorageFailed(let lKey, let lReason), .keychainStorageFailed(let rKey, let rReason)):
            return lKey == rKey && lReason == rReason
        case (.partialMigrationDetected(let lMigrated, let lFailed), .partialMigrationDetected(let rMigrated, let rFailed)):
            return lMigrated == rMigrated && lFailed == rFailed
        case (.invalidTokenData(let lKey), .invalidTokenData(let rKey)):
            return lKey == rKey
        default:
            return false
        }
    }
}

// MARK: - Migration Status

/// Represents the result of an OAuth token migration attempt.
public enum OAuthTokenMigrationStatus: Equatable, Sendable {
    /// No legacy tokens found in UserDefaults - nothing to migrate.
    case noLegacyTokens

    /// Tokens were already migrated in a previous run (exist in Keychain, not in UserDefaults).
    case alreadyMigrated

    /// Migration completed successfully for the specified tokens.
    case migrated(tokens: [CredentialKey])

    /// Migration was skipped because tokens already exist in Keychain.
    case skippedExistingTokens(existing: [CredentialKey], legacy: [CredentialKey])

    /// Human-readable description of the migration status.
    public var description: String {
        switch self {
        case .noLegacyTokens:
            return "No legacy OAuth tokens found in UserDefaults"
        case .alreadyMigrated:
            return "OAuth tokens were previously migrated to Keychain"
        case .migrated(let tokens):
            let names = tokens.map(\.description).joined(separator: ", ")
            return "Successfully migrated OAuth tokens: \(names)"
        case .skippedExistingTokens(let existing, let legacy):
            let existingNames = existing.map(\.description).joined(separator: ", ")
            let legacyNames = legacy.map(\.description).joined(separator: ", ")
            return "Skipped migration - tokens already in Keychain: [\(existingNames)]. Legacy tokens found: [\(legacyNames)]"
        }
    }
}

// MARK: - Legacy Keys

/// Keys used in the legacy Objective-C PersistenceDefaults for OAuth token storage.
///
/// These keys match the constants from the original PersistenceDefaults.m:
/// - `fitbitAuthCode` - The user's OAuth access token
/// - `fitbitSecret` - The user's OAuth token secret
public enum LegacyOAuthKey: String, CaseIterable, Sendable {
    case fitbitAuthCode = "fitbitAuthCode"
    case fitbitSecret = "fitbitSecret"

    /// Maps the legacy key to the modern CredentialKey.
    public var credentialKey: CredentialKey {
        switch self {
        case .fitbitAuthCode:
            return .fitbitUserToken
        case .fitbitSecret:
            return .fitbitUserSecret
        }
    }
}

// MARK: - OAuth Token Migration Service

/// Service responsible for securely migrating OAuth tokens from UserDefaults to Keychain.
///
/// The legacy JogPod app stored Fitbit OAuth tokens in NSUserDefaults via PersistenceDefaults.m,
/// which is a security vulnerability because UserDefaults data:
/// - Is not encrypted at rest
/// - Can be extracted from unencrypted device backups
/// - Is accessible to other apps on jailbroken devices
///
/// This service migrates those tokens to the iOS Keychain, which provides:
/// - Hardware-backed encryption
/// - Exclusion from device backups (with `ThisDeviceOnly` accessibility)
/// - Protection against unauthorized access
///
/// ## Usage
///
/// Call `migrate()` during app launch, before any Fitbit API calls:
///
/// ```swift
/// let migration = OAuthTokenMigration(credentialsService: credentialsService)
/// do {
///     let status = try migration.migrate()
///     Logger.security.info("OAuth migration: \(status.description)")
/// } catch {
///     Logger.security.error("OAuth migration failed: \(error)")
/// }
/// ```
///
/// ## Security Notes
///
/// - Migration is idempotent: safe to call multiple times
/// - Legacy tokens are only deleted AFTER successful Keychain storage
/// - Partial migrations are detected and reported
/// - All operations are logged for debugging
public final class OAuthTokenMigration: @unchecked Sendable {

    // MARK: - Properties

    private let credentialsService: CredentialsProviding
    private let userDefaults: UserDefaults
    private let logger: Logger

    /// Key used to track whether migration has been attempted.
    private static let migrationAttemptedKey = "com.jogpod.oauth_migration_attempted"

    // MARK: - Initialization

    /// Creates a new OAuthTokenMigration instance.
    ///
    /// - Parameters:
    ///   - credentialsService: The credentials service for Keychain storage.
    ///   - userDefaults: The UserDefaults instance to migrate from. Defaults to `.standard`.
    ///   - logger: Logger for migration events. Defaults to security subsystem logger.
    public init(
        credentialsService: CredentialsProviding,
        userDefaults: UserDefaults = .standard,
        logger: Logger = Logger(subsystem: "com.jogpod", category: "OAuthMigration")
    ) {
        self.credentialsService = credentialsService
        self.userDefaults = userDefaults
        self.logger = logger
    }

    // MARK: - Migration

    /// Migrates OAuth tokens from UserDefaults to Keychain.
    ///
    /// This method is idempotent and safe to call multiple times. It performs the following:
    /// 1. Checks if tokens already exist in Keychain (skip if so)
    /// 2. Reads legacy tokens from UserDefaults
    /// 3. Validates token data
    /// 4. Stores tokens in Keychain
    /// 5. Verifies successful storage
    /// 6. Removes legacy tokens from UserDefaults
    ///
    /// - Parameter force: If true, migrates even if tokens already exist in Keychain.
    ///                    Use with caution as this may overwrite existing tokens.
    /// - Returns: The migration status indicating what action was taken.
    /// - Throws: `OAuthTokenMigrationError` if migration fails.
    @discardableResult
    public func migrate(force: Bool = false) throws -> OAuthTokenMigrationStatus {
        logger.info("Starting OAuth token migration (force: \(force))")

        // Check current state
        let legacyTokens = findLegacyTokens()
        let existingKeychainTokens = findExistingKeychainTokens()

        logger.debug("Legacy tokens found: \(legacyTokens.map(\.rawValue).joined(separator: ", "))")
        logger.debug("Existing Keychain tokens: \(existingKeychainTokens.map(\.rawValue).joined(separator: ", "))")

        // Case 1: No legacy tokens exist
        if legacyTokens.isEmpty {
            if !existingKeychainTokens.isEmpty {
                logger.info("Migration complete - tokens already in Keychain, no legacy tokens")
                return .alreadyMigrated
            }
            logger.info("No legacy tokens found - nothing to migrate")
            return .noLegacyTokens
        }

        // Case 2: Tokens already exist in Keychain and we're not forcing
        if !force && !existingKeychainTokens.isEmpty {
            let existingCredentialKeys = existingKeychainTokens.map(\.credentialKey)
            let legacyCredentialKeys = legacyTokens.map(\.credentialKey)

            logger.warning("Tokens already exist in Keychain - skipping migration")
            logger.warning("Consider removing legacy UserDefaults tokens manually")

            // Clean up legacy tokens since Keychain already has values
            cleanupLegacyTokens(legacyTokens)

            return .skippedExistingTokens(
                existing: existingCredentialKeys,
                legacy: legacyCredentialKeys
            )
        }

        // Case 3: Perform migration
        var migratedTokens: [CredentialKey] = []
        var failedTokens: [(LegacyOAuthKey, Error)] = []

        for legacyKey in legacyTokens {
            do {
                try migrateSingleToken(legacyKey)
                migratedTokens.append(legacyKey.credentialKey)
                logger.info("Successfully migrated \(legacyKey.rawValue) to Keychain")
            } catch {
                failedTokens.append((legacyKey, error))
                logger.error("Failed to migrate \(legacyKey.rawValue): \(error.localizedDescription)")
            }
        }

        // Check for partial migration
        if !failedTokens.isEmpty {
            let failedKeys = failedTokens.map { $0.0.credentialKey }

            // Rollback successful migrations if we had partial failure
            if !migratedTokens.isEmpty {
                logger.warning("Partial migration detected - rolling back")
                rollbackMigration(migratedTokens)
            }

            throw OAuthTokenMigrationError.partialMigrationDetected(
                migratedKeys: migratedTokens,
                failedKeys: failedKeys
            )
        }

        // Mark migration as completed
        userDefaults.set(true, forKey: Self.migrationAttemptedKey)

        logger.info("OAuth token migration completed successfully")
        return .migrated(tokens: migratedTokens)
    }

    /// Checks whether OAuth token migration is needed.
    ///
    /// - Returns: `true` if there are legacy tokens that need migration.
    public func needsMigration() -> Bool {
        let legacyTokens = findLegacyTokens()
        let existingTokens = findExistingKeychainTokens()

        // Migration needed if we have legacy tokens and no Keychain tokens
        return !legacyTokens.isEmpty && existingTokens.isEmpty
    }

    /// Returns information about the current migration state.
    ///
    /// - Returns: A tuple containing legacy token keys, Keychain token keys, and whether migration was attempted.
    public func migrationState() -> (legacy: [LegacyOAuthKey], keychain: [LegacyOAuthKey], attempted: Bool) {
        let legacy = findLegacyTokens()
        let keychain = findExistingKeychainTokens()
        let attempted = userDefaults.bool(forKey: Self.migrationAttemptedKey)
        return (legacy, keychain, attempted)
    }

    /// Clears the migration attempted flag, allowing migration to be retried.
    ///
    /// - Note: This does not affect the actual token storage.
    public func resetMigrationFlag() {
        userDefaults.removeObject(forKey: Self.migrationAttemptedKey)
        logger.info("Migration flag reset")
    }

    // MARK: - Private Methods

    /// Finds legacy OAuth tokens in UserDefaults.
    private func findLegacyTokens() -> [LegacyOAuthKey] {
        LegacyOAuthKey.allCases.filter { key in
            guard let value = userDefaults.string(forKey: key.rawValue) else {
                return false
            }
            return !value.isEmpty
        }
    }

    /// Finds which OAuth tokens already exist in Keychain.
    private func findExistingKeychainTokens() -> [LegacyOAuthKey] {
        LegacyOAuthKey.allCases.filter { key in
            credentialsService.hasCredential(for: key.credentialKey)
        }
    }

    /// Migrates a single token from UserDefaults to Keychain.
    private func migrateSingleToken(_ legacyKey: LegacyOAuthKey) throws {
        // Read from UserDefaults
        guard let tokenValue = userDefaults.string(forKey: legacyKey.rawValue) else {
            throw OAuthTokenMigrationError.invalidTokenData(legacyKey.credentialKey)
        }

        guard !tokenValue.isEmpty else {
            throw OAuthTokenMigrationError.invalidTokenData(legacyKey.credentialKey)
        }

        // Store in Keychain
        do {
            try credentialsService.setCredential(tokenValue, for: legacyKey.credentialKey)
        } catch {
            throw OAuthTokenMigrationError.keychainStorageFailed(
                legacyKey.credentialKey,
                error.localizedDescription
            )
        }

        // Verify storage succeeded
        guard credentialsService.hasCredential(for: legacyKey.credentialKey) else {
            throw OAuthTokenMigrationError.keychainStorageFailed(
                legacyKey.credentialKey,
                "Verification failed after storage"
            )
        }

        // Only remove from UserDefaults AFTER successful Keychain storage
        userDefaults.removeObject(forKey: legacyKey.rawValue)
    }

    /// Cleans up legacy tokens from UserDefaults.
    private func cleanupLegacyTokens(_ tokens: [LegacyOAuthKey]) {
        for token in tokens {
            userDefaults.removeObject(forKey: token.rawValue)
            logger.debug("Removed legacy token \(token.rawValue) from UserDefaults")
        }
    }

    /// Rolls back migrated tokens from Keychain.
    private func rollbackMigration(_ migratedKeys: [CredentialKey]) {
        for key in migratedKeys {
            do {
                try credentialsService.removeCredential(for: key)
                logger.debug("Rolled back \(key.rawValue) from Keychain")
            } catch {
                logger.error("Failed to rollback \(key.rawValue): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - App Launch Integration

extension OAuthTokenMigration {
    /// Performs migration during app launch with appropriate error handling.
    ///
    /// This is a convenience method that handles errors gracefully and logs
    /// the migration status. It will not throw errors, making it safe to call
    /// during app initialization without disrupting the launch sequence.
    ///
    /// - Returns: The migration status, or `nil` if migration failed.
    public func migrateOnLaunch() -> OAuthTokenMigrationStatus? {
        do {
            let status = try migrate()
            logger.info("App launch migration: \(status.description)")
            return status
        } catch {
            logger.error("App launch migration failed: \(error.localizedDescription)")
            return nil
        }
    }
}
