import XCTest
@testable import JogPod

/// Unit tests for OAuth token migration from UserDefaults to Keychain.
final class OAuthTokenMigrationTests: XCTestCase {

    // MARK: - Test Fixtures

    private var mockCredentialsService: MockCredentialsService!
    private var testUserDefaults: UserDefaults!
    private var migration: OAuthTokenMigration!

    private let testSuiteName = "com.jogpod.test.oauth_migration"

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockCredentialsService = MockCredentialsService()
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!

        // Clear test UserDefaults
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        migration = OAuthTokenMigration(
            credentialsService: mockCredentialsService,
            userDefaults: testUserDefaults
        )
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        mockCredentialsService = nil
        migration = nil
        super.tearDown()
    }

    // MARK: - No Legacy Tokens Tests

    func testMigrateWithNoLegacyTokensReturnsNoLegacyTokens() throws {
        // Given: No tokens in UserDefaults or Keychain

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .noLegacyTokens)
    }

    func testMigrateWithNoLegacyTokensButKeychainTokensReturnsAlreadyMigrated() throws {
        // Given: Tokens exist in Keychain but not UserDefaults
        mockCredentialsService.storedCredentials[.fitbitUserToken] = "existing_token"
        mockCredentialsService.storedCredentials[.fitbitUserSecret] = "existing_secret"

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .alreadyMigrated)
    }

    // MARK: - Successful Migration Tests

    func testMigrateWithLegacyTokensSucceeds() throws {
        // Given: Tokens in UserDefaults, none in Keychain
        testUserDefaults.set("legacy_auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserToken, .fitbitUserSecret]))

        // Verify tokens were stored in Keychain
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserToken], "legacy_auth_token")
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "legacy_secret")

        // Verify tokens were removed from UserDefaults
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue))
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitSecret.rawValue))
    }

    func testMigrateWithOnlyAuthTokenSucceeds() throws {
        // Given: Only auth token in UserDefaults
        testUserDefaults.set("legacy_auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserToken]))
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserToken], "legacy_auth_token")
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue))
    }

    func testMigrateWithOnlySecretSucceeds() throws {
        // Given: Only secret in UserDefaults
        testUserDefaults.set("legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserSecret]))
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "legacy_secret")
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitSecret.rawValue))
    }

    // MARK: - Idempotency Tests

    func testMigrateIsIdempotent() throws {
        // Given: Tokens in UserDefaults
        testUserDefaults.set("legacy_auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When: Migrate twice
        let firstStatus = try migration.migrate()
        let secondStatus = try migration.migrate()

        // Then
        XCTAssertEqual(firstStatus, .migrated(tokens: [.fitbitUserToken, .fitbitUserSecret]))
        XCTAssertEqual(secondStatus, .alreadyMigrated)

        // Tokens should still be in Keychain
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserToken], "legacy_auth_token")
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "legacy_secret")
    }

    func testMigrateMultipleTimesWithNoTokensIsIdempotent() throws {
        // When: Migrate multiple times with no tokens
        let status1 = try migration.migrate()
        let status2 = try migration.migrate()
        let status3 = try migration.migrate()

        // Then: All return noLegacyTokens
        XCTAssertEqual(status1, .noLegacyTokens)
        XCTAssertEqual(status2, .noLegacyTokens)
        XCTAssertEqual(status3, .noLegacyTokens)
    }

    // MARK: - Existing Keychain Tokens Tests

    func testMigrateSkipsWhenKeychainHasTokens() throws {
        // Given: Tokens in both UserDefaults and Keychain
        testUserDefaults.set("legacy_auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)
        mockCredentialsService.storedCredentials[.fitbitUserToken] = "existing_token"
        mockCredentialsService.storedCredentials[.fitbitUserSecret] = "existing_secret"

        // When
        let status = try migration.migrate()

        // Then: Skip migration, preserve Keychain values, clean up UserDefaults
        if case .skippedExistingTokens(let existing, let legacy) = status {
            XCTAssertTrue(existing.contains(.fitbitUserToken))
            XCTAssertTrue(existing.contains(.fitbitUserSecret))
            XCTAssertTrue(legacy.contains(.fitbitUserToken))
            XCTAssertTrue(legacy.contains(.fitbitUserSecret))
        } else {
            XCTFail("Expected skippedExistingTokens status")
        }

        // Keychain values should be preserved
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserToken], "existing_token")
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "existing_secret")

        // UserDefaults should be cleaned up
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue))
        XCTAssertNil(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitSecret.rawValue))
    }

    func testMigrateForceOverwritesKeychainTokens() throws {
        // Given: Tokens in both UserDefaults and Keychain
        testUserDefaults.set("new_legacy_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("new_legacy_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)
        mockCredentialsService.storedCredentials[.fitbitUserToken] = "old_token"
        mockCredentialsService.storedCredentials[.fitbitUserSecret] = "old_secret"

        // When: Force migration
        let status = try migration.migrate(force: true)

        // Then: Overwrite Keychain values
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserToken, .fitbitUserSecret]))
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserToken], "new_legacy_token")
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "new_legacy_secret")
    }

    // MARK: - Empty Token Handling Tests

    func testMigrateIgnoresEmptyTokens() throws {
        // Given: Empty tokens in UserDefaults
        testUserDefaults.set("", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When
        let status = try migration.migrate()

        // Then: Treats as no legacy tokens
        XCTAssertEqual(status, .noLegacyTokens)
    }

    func testMigrateIgnoresNilTokens() throws {
        // Given: Explicitly set nil (via removeObject)
        testUserDefaults.removeObject(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.removeObject(forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When
        let status = try migration.migrate()

        // Then
        XCTAssertEqual(status, .noLegacyTokens)
    }

    func testMigrateWithMixedEmptyAndValidTokens() throws {
        // Given: One empty, one valid
        testUserDefaults.set("", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("valid_secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // When
        let status = try migration.migrate()

        // Then: Only migrate valid token
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserSecret]))
        XCTAssertNil(mockCredentialsService.storedCredentials[.fitbitUserToken])
        XCTAssertEqual(mockCredentialsService.storedCredentials[.fitbitUserSecret], "valid_secret")
    }

    // MARK: - Error Handling Tests

    func testMigrateRollsBackOnPartialFailure() throws {
        // Given: Tokens in UserDefaults, Keychain will fail on second write
        testUserDefaults.set("auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        testUserDefaults.set("secret", forKey: LegacyOAuthKey.fitbitSecret.rawValue)

        // Configure mock to fail on second credential
        mockCredentialsService.failOnKey = .fitbitUserSecret
        mockCredentialsService.errorToThrow = CredentialsError.storageError("Simulated failure")

        // When/Then
        XCTAssertThrowsError(try migration.migrate()) { error in
            guard case OAuthTokenMigrationError.partialMigrationDetected(let migrated, let failed) = error else {
                XCTFail("Expected partialMigrationDetected error")
                return
            }
            XCTAssertEqual(migrated, [.fitbitUserToken])
            XCTAssertEqual(failed, [.fitbitUserSecret])
        }

        // Verify rollback: first token should be removed from Keychain
        XCTAssertNil(mockCredentialsService.storedCredentials[.fitbitUserToken])

        // UserDefaults should still have both tokens (rollback preserves them)
        XCTAssertEqual(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue), "auth_token")
        XCTAssertEqual(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitSecret.rawValue), "secret")
    }

    func testMigrateFailsOnKeychainStorageError() throws {
        // Given: Token in UserDefaults, Keychain will fail
        testUserDefaults.set("auth_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        mockCredentialsService.failOnKey = .fitbitUserToken
        mockCredentialsService.errorToThrow = CredentialsError.storageError("Keychain unavailable")

        // When/Then
        XCTAssertThrowsError(try migration.migrate()) { error in
            guard case OAuthTokenMigrationError.partialMigrationDetected = error else {
                XCTFail("Expected partialMigrationDetected error")
                return
            }
        }

        // UserDefaults should preserve token on failure
        XCTAssertEqual(testUserDefaults.string(forKey: LegacyOAuthKey.fitbitAuthCode.rawValue), "auth_token")
    }

    // MARK: - needsMigration Tests

    func testNeedsMigrationReturnsTrueWithLegacyTokensOnly() {
        // Given: Tokens in UserDefaults, none in Keychain
        testUserDefaults.set("legacy_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)

        // When/Then
        XCTAssertTrue(migration.needsMigration())
    }

    func testNeedsMigrationReturnsFalseWithNoTokens() {
        // Given: No tokens anywhere
        XCTAssertFalse(migration.needsMigration())
    }

    func testNeedsMigrationReturnsFalseWithKeychainTokens() {
        // Given: Tokens in Keychain
        mockCredentialsService.storedCredentials[.fitbitUserToken] = "token"

        // When/Then
        XCTAssertFalse(migration.needsMigration())
    }

    func testNeedsMigrationReturnsFalseWhenBothHaveTokens() {
        // Given: Tokens in both locations
        testUserDefaults.set("legacy_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        mockCredentialsService.storedCredentials[.fitbitUserToken] = "keychain_token"

        // When/Then
        XCTAssertFalse(migration.needsMigration())
    }

    // MARK: - migrationState Tests

    func testMigrationStateReflectsCurrentState() {
        // Given
        testUserDefaults.set("legacy_token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        mockCredentialsService.storedCredentials[.fitbitUserSecret] = "keychain_secret"

        // When
        let state = migration.migrationState()

        // Then
        XCTAssertEqual(state.legacy, [.fitbitAuthCode])
        XCTAssertEqual(state.keychain, [.fitbitSecret])
        XCTAssertFalse(state.attempted)
    }

    func testMigrationStateShowsAttemptedAfterMigration() throws {
        // Given
        testUserDefaults.set("token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)

        // When
        _ = try migration.migrate()
        let state = migration.migrationState()

        // Then
        XCTAssertTrue(state.attempted)
    }

    // MARK: - resetMigrationFlag Tests

    func testResetMigrationFlagClearsAttemptedState() throws {
        // Given: Migration was performed
        testUserDefaults.set("token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        _ = try migration.migrate()
        XCTAssertTrue(migration.migrationState().attempted)

        // When
        migration.resetMigrationFlag()

        // Then
        XCTAssertFalse(migration.migrationState().attempted)
    }

    // MARK: - migrateOnLaunch Tests

    func testMigrateOnLaunchReturnsStatusOnSuccess() {
        // Given: Tokens in UserDefaults
        testUserDefaults.set("token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)

        // When
        let status = migration.migrateOnLaunch()

        // Then
        XCTAssertNotNil(status)
        XCTAssertEqual(status, .migrated(tokens: [.fitbitUserToken]))
    }

    func testMigrateOnLaunchReturnsNilOnFailure() {
        // Given: Token in UserDefaults, Keychain will fail
        testUserDefaults.set("token", forKey: LegacyOAuthKey.fitbitAuthCode.rawValue)
        mockCredentialsService.failOnKey = .fitbitUserToken
        mockCredentialsService.errorToThrow = CredentialsError.storageError("Failure")

        // When
        let status = migration.migrateOnLaunch()

        // Then
        XCTAssertNil(status)
    }

    // MARK: - LegacyOAuthKey Tests

    func testLegacyOAuthKeyRawValues() {
        XCTAssertEqual(LegacyOAuthKey.fitbitAuthCode.rawValue, "fitbitAuthCode")
        XCTAssertEqual(LegacyOAuthKey.fitbitSecret.rawValue, "fitbitSecret")
    }

    func testLegacyOAuthKeyCredentialKeyMapping() {
        XCTAssertEqual(LegacyOAuthKey.fitbitAuthCode.credentialKey, .fitbitUserToken)
        XCTAssertEqual(LegacyOAuthKey.fitbitSecret.credentialKey, .fitbitUserSecret)
    }

    // MARK: - OAuthTokenMigrationError Tests

    func testErrorDescriptions() {
        let storageError = OAuthTokenMigrationError.keychainStorageFailed(.fitbitUserToken, "Access denied")
        XCTAssertTrue(storageError.errorDescription?.contains("Fitbit User OAuth Token") ?? false)
        XCTAssertTrue(storageError.errorDescription?.contains("Access denied") ?? false)

        let partialError = OAuthTokenMigrationError.partialMigrationDetected(
            migratedKeys: [.fitbitUserToken],
            failedKeys: [.fitbitUserSecret]
        )
        XCTAssertTrue(partialError.errorDescription?.contains("Partial migration") ?? false)

        let invalidError = OAuthTokenMigrationError.invalidTokenData(.fitbitUserSecret)
        XCTAssertTrue(invalidError.errorDescription?.contains("Invalid") ?? false)
    }

    func testErrorEquality() {
        let error1 = OAuthTokenMigrationError.keychainStorageFailed(.fitbitUserToken, "Error A")
        let error2 = OAuthTokenMigrationError.keychainStorageFailed(.fitbitUserToken, "Error A")
        let error3 = OAuthTokenMigrationError.keychainStorageFailed(.fitbitUserToken, "Error B")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)

        let partial1 = OAuthTokenMigrationError.partialMigrationDetected(
            migratedKeys: [.fitbitUserToken],
            failedKeys: [.fitbitUserSecret]
        )
        let partial2 = OAuthTokenMigrationError.partialMigrationDetected(
            migratedKeys: [.fitbitUserToken],
            failedKeys: [.fitbitUserSecret]
        )
        XCTAssertEqual(partial1, partial2)
    }

    // MARK: - OAuthTokenMigrationStatus Tests

    func testStatusDescriptions() {
        XCTAssertTrue(OAuthTokenMigrationStatus.noLegacyTokens.description.contains("No legacy"))
        XCTAssertTrue(OAuthTokenMigrationStatus.alreadyMigrated.description.contains("previously migrated"))

        let migrated = OAuthTokenMigrationStatus.migrated(tokens: [.fitbitUserToken])
        XCTAssertTrue(migrated.description.contains("Successfully migrated"))

        let skipped = OAuthTokenMigrationStatus.skippedExistingTokens(
            existing: [.fitbitUserToken],
            legacy: [.fitbitUserSecret]
        )
        XCTAssertTrue(skipped.description.contains("Skipped"))
    }

    func testStatusEquality() {
        XCTAssertEqual(OAuthTokenMigrationStatus.noLegacyTokens, .noLegacyTokens)
        XCTAssertEqual(OAuthTokenMigrationStatus.alreadyMigrated, .alreadyMigrated)
        XCTAssertNotEqual(OAuthTokenMigrationStatus.noLegacyTokens, .alreadyMigrated)

        let migrated1 = OAuthTokenMigrationStatus.migrated(tokens: [.fitbitUserToken])
        let migrated2 = OAuthTokenMigrationStatus.migrated(tokens: [.fitbitUserToken])
        let migrated3 = OAuthTokenMigrationStatus.migrated(tokens: [.fitbitUserSecret])
        XCTAssertEqual(migrated1, migrated2)
        XCTAssertNotEqual(migrated1, migrated3)
    }
}

// MARK: - Mock Credentials Service

/// Mock implementation of CredentialsProviding for testing.
private final class MockCredentialsService: CredentialsProviding {

    /// In-memory storage for credentials.
    var storedCredentials: [CredentialKey: String] = [:]

    /// Optional key to fail on for error simulation.
    var failOnKey: CredentialKey?

    /// Error to throw when failOnKey is set.
    var errorToThrow: Error?

    func credential(for key: CredentialKey) throws -> String {
        if key == failOnKey, let error = errorToThrow {
            throw error
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
        if key == failOnKey, let error = errorToThrow {
            throw error
        }
        storedCredentials[key] = value
    }

    func removeCredential(for key: CredentialKey) throws {
        storedCredentials.removeValue(forKey: key)
    }

    func clearUserCredentials() throws {
        for key in CredentialKey.allCases where key.isUserCredential {
            storedCredentials.removeValue(forKey: key)
        }
    }
}
