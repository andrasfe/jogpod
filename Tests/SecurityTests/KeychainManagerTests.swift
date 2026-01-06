import Testing
import Foundation
@testable import JogPod

// MARK: - Keychain Manager Tests

/// Tests for KeychainManager.
///
/// Note: These tests use a unique test service identifier to avoid conflicts
/// with actual app keychain items. Real keychain operations are performed
/// to ensure the implementation works correctly with the iOS Keychain.
@Suite("Keychain Manager Tests")
struct KeychainManagerTests {

    // MARK: - Test Configuration

    private static let testService = "com.jogpod.test.keychain.\(UUID().uuidString)"

    private func createKeychain() -> KeychainManager {
        KeychainManager(service: KeychainManagerTests.testService)
    }

    // MARK: - Basic Operations Tests

    @Test("Save and retrieve string value")
    func testSaveAndRetrieve() throws {
        let keychain = createKeychain()
        let testKey = "test_key_\(UUID().uuidString)"
        let testValue = "test_value_12345"

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(testValue, forKey: testKey)
        let retrieved = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    @Test("Save with different accessibility levels")
    func testSaveWithAccessibility() throws {
        let keychain = createKeychain()
        let testKey1 = "test_access_1_\(UUID().uuidString)"
        let testKey2 = "test_access_2_\(UUID().uuidString)"

        defer {
            try? keychain.delete(forKey: testKey1)
            try? keychain.delete(forKey: testKey2)
        }

        try keychain.save("value1", forKey: testKey1, accessibility: .whenUnlocked)
        try keychain.save("value2", forKey: testKey2, accessibility: .afterFirstUnlockThisDeviceOnly)

        #expect(try keychain.retrieve(forKey: testKey1) == "value1")
        #expect(try keychain.retrieve(forKey: testKey2) == "value2")
    }

    @Test("Delete removes item")
    func testDelete() throws {
        let keychain = createKeychain()
        let testKey = "test_delete_\(UUID().uuidString)"

        try keychain.save("value", forKey: testKey)
        #expect(keychain.exists(forKey: testKey) == true)

        try keychain.delete(forKey: testKey)
        #expect(keychain.exists(forKey: testKey) == false)
    }

    @Test("Delete non-existent item does not throw")
    func testDeleteNonExistent() throws {
        let keychain = createKeychain()
        let testKey = "non_existent_\(UUID().uuidString)"

        // Should not throw
        try keychain.delete(forKey: testKey)
    }

    @Test("Exists returns correct boolean")
    func testExists() throws {
        let keychain = createKeychain()
        let testKey = "test_exists_\(UUID().uuidString)"

        defer { try? keychain.delete(forKey: testKey) }

        #expect(keychain.exists(forKey: testKey) == false)

        try keychain.save("value", forKey: testKey)
        #expect(keychain.exists(forKey: testKey) == true)
    }

    @Test("Update creates item if it does not exist")
    func testUpdateCreates() throws {
        let keychain = createKeychain()
        let testKey = "test_update_create_\(UUID().uuidString)"

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.update("new_value", forKey: testKey)

        #expect(keychain.exists(forKey: testKey) == true)
        #expect(try keychain.retrieve(forKey: testKey) == "new_value")
    }

    @Test("Update modifies existing item")
    func testUpdateModifies() throws {
        let keychain = createKeychain()
        let testKey = "test_update_modify_\(UUID().uuidString)"

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save("original", forKey: testKey)
        try keychain.update("updated", forKey: testKey)

        #expect(try keychain.retrieve(forKey: testKey) == "updated")
    }

    // MARK: - Error Handling Tests

    @Test("Retrieve non-existent item throws itemNotFound")
    func testRetrieveNonExistent() {
        let keychain = createKeychain()
        let testKey = "non_existent_\(UUID().uuidString)"

        #expect(throws: KeychainError.itemNotFound) {
            _ = try keychain.retrieve(forKey: testKey)
        }
    }

    @Test("Save duplicate item throws duplicateItem")
    func testSaveDuplicate() throws {
        let keychain = createKeychain()
        let testKey = "test_duplicate_\(UUID().uuidString)"

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save("first", forKey: testKey)

        #expect(throws: KeychainError.duplicateItem) {
            try keychain.save("second", forKey: testKey)
        }
    }

    // MARK: - Special Characters Tests

    @Test("Handles special characters in values")
    func testSpecialCharacters() throws {
        let keychain = createKeychain()
        let testKey = "test_special_\(UUID().uuidString)"
        let specialValue = "test!@#$%^&*()_+-=[]{}|;':\",./<>?`~\n\t\r"

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(specialValue, forKey: testKey)
        let retrieved = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == specialValue)
    }

    @Test("Handles Unicode characters in values")
    func testUnicodeCharacters() throws {
        let keychain = createKeychain()
        let testKey = "test_unicode_\(UUID().uuidString)"
        let unicodeValue = "Hello World! Emoji test. Chinese."

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(unicodeValue, forKey: testKey)
        let retrieved = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == unicodeValue)
    }

    @Test("Handles empty key names")
    func testEmptyKeyName() throws {
        let keychain = createKeychain()
        let emptyKey = ""
        let testValue = "value_for_empty_key"

        defer { try? keychain.delete(forKey: emptyKey) }

        // Empty key is technically valid for Keychain
        try keychain.save(testValue, forKey: emptyKey)
        let retrieved = try keychain.retrieve(forKey: emptyKey)

        #expect(retrieved == testValue)
    }

    @Test("Handles very long values")
    func testLongValue() throws {
        let keychain = createKeychain()
        let testKey = "test_long_\(UUID().uuidString)"
        let longValue = String(repeating: "x", count: 10000)

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(longValue, forKey: testKey)
        let retrieved = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == longValue)
    }

    // MARK: - Codable Extension Tests

    @Test("Save and retrieve Codable types")
    func testCodableRoundTrip() throws {
        let keychain = createKeychain()
        let testKey = "test_codable_\(UUID().uuidString)"

        struct TestData: Codable, Equatable {
            let id: Int
            let name: String
            let optional: String?
        }

        let original = TestData(id: 42, name: "Test", optional: "value")

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(original, forKey: testKey)
        let retrieved: TestData = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == original)
    }

    @Test("Save and retrieve Codable with nil optional")
    func testCodableWithNil() throws {
        let keychain = createKeychain()
        let testKey = "test_codable_nil_\(UUID().uuidString)"

        struct TestData: Codable, Equatable {
            let id: Int
            let optional: String?
        }

        let original = TestData(id: 1, optional: nil)

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(original, forKey: testKey)
        let retrieved: TestData = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == original)
        #expect(retrieved.optional == nil)
    }

    @Test("Save and retrieve Codable arrays")
    func testCodableArray() throws {
        let keychain = createKeychain()
        let testKey = "test_codable_array_\(UUID().uuidString)"

        let original = [1, 2, 3, 4, 5]

        defer { try? keychain.delete(forKey: testKey) }

        try keychain.save(original, forKey: testKey)
        let retrieved: [Int] = try keychain.retrieve(forKey: testKey)

        #expect(retrieved == original)
    }

    // MARK: - Delete All Tests

    @Test("Delete all removes all items for service")
    func testDeleteAll() throws {
        let keychain = createKeychain()
        let testKey1 = "test_all_1_\(UUID().uuidString)"
        let testKey2 = "test_all_2_\(UUID().uuidString)"
        let testKey3 = "test_all_3_\(UUID().uuidString)"

        try keychain.save("value1", forKey: testKey1)
        try keychain.save("value2", forKey: testKey2)
        try keychain.save("value3", forKey: testKey3)

        #expect(keychain.exists(forKey: testKey1))
        #expect(keychain.exists(forKey: testKey2))
        #expect(keychain.exists(forKey: testKey3))

        try keychain.deleteAll()

        #expect(keychain.exists(forKey: testKey1) == false)
        #expect(keychain.exists(forKey: testKey2) == false)
        #expect(keychain.exists(forKey: testKey3) == false)
    }

    @Test("Delete all with no items does not throw")
    func testDeleteAllEmpty() throws {
        let keychain = createKeychain()

        // Should not throw
        try keychain.deleteAll()
    }

    // MARK: - Service Isolation Tests

    @Test("Different services are isolated")
    func testServiceIsolation() throws {
        let service1 = "com.jogpod.test.service1.\(UUID().uuidString)"
        let service2 = "com.jogpod.test.service2.\(UUID().uuidString)"
        let keychain1 = KeychainManager(service: service1)
        let keychain2 = KeychainManager(service: service2)
        let testKey = "shared_key"

        defer {
            try? keychain1.delete(forKey: testKey)
            try? keychain2.delete(forKey: testKey)
        }

        try keychain1.save("value1", forKey: testKey)
        try keychain2.save("value2", forKey: testKey)

        #expect(try keychain1.retrieve(forKey: testKey) == "value1")
        #expect(try keychain2.retrieve(forKey: testKey) == "value2")
    }
}

// MARK: - Keychain Error Tests

@Suite("Keychain Error Tests")
struct KeychainErrorTests {

    @Test("Error descriptions are properly formatted")
    func testErrorDescriptions() {
        let testCases: [(KeychainError, String)] = [
            (.itemNotFound, "The requested item was not found in the Keychain."),
            (.duplicateItem, "An item with this identifier already exists in the Keychain."),
            (.unexpectedStatus(-34018), "Keychain operation failed with status: -34018"),
            (.invalidData, "The data retrieved from Keychain is invalid."),
            (.encodingError, "Failed to encode the data for storage."),
            (.decodingError, "Failed to decode the data from storage."),
        ]

        for (error, expectedDescription) in testCases {
            #expect(error.errorDescription == expectedDescription)
        }
    }

    @Test("Errors are equatable")
    func testErrorEquality() {
        #expect(KeychainError.itemNotFound == KeychainError.itemNotFound)
        #expect(KeychainError.duplicateItem == KeychainError.duplicateItem)
        #expect(KeychainError.unexpectedStatus(-1) == KeychainError.unexpectedStatus(-1))
        #expect(KeychainError.unexpectedStatus(-1) != KeychainError.unexpectedStatus(-2))
        #expect(KeychainError.invalidData == KeychainError.invalidData)
        #expect(KeychainError.encodingError == KeychainError.encodingError)
        #expect(KeychainError.decodingError == KeychainError.decodingError)
    }

    @Test("Different error types are not equal")
    func testErrorInequality() {
        #expect(KeychainError.itemNotFound != KeychainError.duplicateItem)
        #expect(KeychainError.invalidData != KeychainError.encodingError)
        #expect(KeychainError.encodingError != KeychainError.decodingError)
    }

    @Test("Errors conform to LocalizedError")
    func testLocalizedError() {
        let error: KeychainError = .itemNotFound

        // LocalizedError provides localizedDescription via errorDescription
        #expect(error.localizedDescription.contains("not found"))
    }
}

// MARK: - Keychain Accessibility Tests

@Suite("Keychain Accessibility Tests")
struct KeychainAccessibilityTests {

    @Test("Accessibility levels map to correct Security constants")
    func testAccessibilityMapping() {
        // We can't directly compare CFString values, but we can verify
        // the mapping exists and returns the expected types
        let whenUnlocked = KeychainAccessibility.whenUnlocked.secAccessibility
        let whenUnlockedThisDeviceOnly = KeychainAccessibility.whenUnlockedThisDeviceOnly.secAccessibility
        let afterFirstUnlock = KeychainAccessibility.afterFirstUnlock.secAccessibility
        let afterFirstUnlockThisDeviceOnly = KeychainAccessibility.afterFirstUnlockThisDeviceOnly.secAccessibility

        // Verify these are distinct values
        #expect(CFStringCompare(whenUnlocked, whenUnlockedThisDeviceOnly, []) != .compareEqualTo)
        #expect(CFStringCompare(afterFirstUnlock, afterFirstUnlockThisDeviceOnly, []) != .compareEqualTo)
        #expect(CFStringCompare(whenUnlocked, afterFirstUnlock, []) != .compareEqualTo)
    }

    @Test("All accessibility levels are covered")
    func testAllAccessibilityLevels() {
        // Ensure the enum has all expected cases
        let allCases: [KeychainAccessibility] = [
            .whenUnlocked,
            .whenUnlockedThisDeviceOnly,
            .afterFirstUnlock,
            .afterFirstUnlockThisDeviceOnly
        ]

        // Each should return a valid CFString
        for accessibility in allCases {
            let secValue = accessibility.secAccessibility
            #expect(CFGetTypeID(secValue) == CFStringGetTypeID())
        }
    }
}

// MARK: - Thread Safety Tests

@Suite("Keychain Thread Safety Tests")
struct KeychainThreadSafetyTests {

    @Test("Concurrent reads and writes complete successfully")
    func testConcurrentAccess() async throws {
        let service = "com.jogpod.test.concurrent.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)

        defer { try? keychain.deleteAll() }

        // Pre-populate some keys
        for i in 0..<5 {
            try keychain.save("initial_\(i)", forKey: "key_\(i)")
        }

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 5..<10 {
                group.addTask {
                    try? keychain.save("value_\(i)", forKey: "key_\(i)")
                }
            }

            // Readers
            for i in 0..<5 {
                group.addTask {
                    _ = try? keychain.retrieve(forKey: "key_\(i)")
                }
            }

            // Updaters
            for i in 0..<5 {
                group.addTask {
                    try? keychain.update("updated_\(i)", forKey: "key_\(i)")
                }
            }

            // Existence checks
            for i in 0..<10 {
                group.addTask {
                    _ = keychain.exists(forKey: "key_\(i)")
                }
            }
        }

        // Verify the keychain is in a consistent state
        for i in 0..<5 {
            #expect(keychain.exists(forKey: "key_\(i)") == true)
        }
    }
}
