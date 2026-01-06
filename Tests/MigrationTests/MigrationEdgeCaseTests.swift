//
//  MigrationEdgeCaseTests.swift
//  JogPodTests
//
//  Edge case tests for Core Data to SwiftData migration.
//  Covers empty databases, large datasets, corrupted data, and special characters.
//

import XCTest
import SwiftData
import CoreData
import CoreLocation
@testable import JogPod

// MARK: - Empty Database Tests

/// Tests for migration behavior with empty or minimal data.
@MainActor
final class EmptyDatabaseMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmptyDBTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("Empty.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testMigrationWithEmptyStore() async throws {
        // Create empty store
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.totalRecordsMigrated, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("empty") })
        XCTAssertTrue(manager.isMigrationComplete())
    }

    func testMigrationWithSingleFeed() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Single Feed", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.feedsMigrated, 1)
        XCTAssertEqual(result.episodesMigrated, 0)
    }

    func testMigrationWithOnlyPreferences() async throws {
        let context = try createTestCoreDataStore()

        let pref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        pref.setValue("testPref", forKey: "name")
        pref.setValue(true, forKey: "boolValue")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.feedsMigrated, 0)
        XCTAssertEqual(result.preferencesMigrated, 1)
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = MigrationTestHelper.createCoreDataModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: legacyStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}

// MARK: - Orphaned Data Tests

/// Tests for handling orphaned records without proper relationships.
@MainActor
final class OrphanedDataMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrphanedDataTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("Orphaned.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testMigrationHandlesOrphanedEpisodes() async throws {
        let context = try createTestCoreDataStore()

        // Create episode without a feed (orphaned)
        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Orphaned Episode", forKey: "title")
        episode.setValue("orphan-guid", forKey: "identifier")
        // No belongsTo relationship set

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Should still migrate the orphaned episode
        XCTAssertEqual(result.episodesMigrated, 1)

        // Verify episode was created without a feed
        let swiftDataContext = modelContainer.mainContext
        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try swiftDataContext.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertNil(episodes.first?.feed)
    }

    func testMigrationHandlesTrackPointsWithoutSession() async throws {
        let context = try createTestCoreDataStore()

        // Create track point referencing a non-existent workout
        let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        trackPoint.setValue("non-existent-workout-id", forKey: "workoutID")
        trackPoint.setValue(Date(), forKey: "time")
        trackPoint.setValue(Int16(140), forKey: "heartRate")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Orphaned track points should be skipped
        XCTAssertEqual(result.trackPointsMigrated, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("orphaned") })
    }

    func testMigrationHandlesListeningLogsWithoutWorkoutID() async throws {
        let context = try createTestCoreDataStore()

        // Create listening log without workoutID
        let log = NSEntityDescription.insertNewObject(forEntityName: "WorkoutListeningLog", into: context)
        log.setValue(nil, forKey: "workoutID")
        log.setValue(Date(), forKey: "time")
        log.setValue("Podcast", forKey: "entityTitle")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Logs without workoutID should be skipped
        XCTAssertEqual(result.listeningLogsMigrated, 0)
    }

    func testMigrationGeneratesWorkoutIDForMissingID() async throws {
        let context = try createTestCoreDataStore()

        // Create workout session without workoutID
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(nil, forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.workoutSessionsMigrated, 1)

        // Verify a workoutID was generated
        let swiftDataContext = modelContainer.mainContext
        let sessionDescriptor = FetchDescriptor<WorkoutSession>()
        let sessions = try swiftDataContext.fetch(sessionDescriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(sessions.first?.workoutID.isEmpty ?? true, "WorkoutID should be generated")
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = MigrationTestHelper.createCoreDataModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: legacyStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}

// MARK: - Special Character Tests

/// Tests for handling special characters and edge case string values.
@MainActor
final class SpecialCharacterMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpecialCharTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("SpecialChars.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testMigrationHandlesUnicodeCharacters() async throws {
        let context = try createTestCoreDataStore()

        // Create feed with unicode characters
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Podcast Espanol - Hoy es un buen dia", forKey: "title")
        feed.setValue("Un podcast increible sobre la vida", forKey: "summary")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.first?.title, "Podcast Espanol - Hoy es un buen dia")
        XCTAssertEqual(feeds.first?.summary, "Un podcast increible sobre la vida")
    }

    func testMigrationHandlesEmoji() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Running Podcast 🏃‍♂️🎧", forKey: "title")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.first?.title, "Running Podcast 🏃‍♂️🎧")
    }

    func testMigrationHandlesNewlinesAndTabs() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Podcast Title", forKey: "title")
        feed.setValue("Line 1\nLine 2\tTabbed\nLine 3", forKey: "summary")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertTrue(feeds.first?.summary?.contains("\n") ?? false)
        XCTAssertTrue(feeds.first?.summary?.contains("\t") ?? false)
    }

    func testMigrationHandlesEmptyStrings() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("", forKey: "title")
        feed.setValue("", forKey: "summary")
        feed.setValue("https://test.com", forKey: "link")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.first?.title, "")
        XCTAssertEqual(feeds.first?.summary, "")
    }

    func testMigrationHandlesVeryLongStrings() async throws {
        let context = try createTestCoreDataStore()

        // Create a very long string (10KB)
        let longString = String(repeating: "Lorem ipsum dolor sit amet. ", count: 500)

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Feed Title", forKey: "title")
        feed.setValue(longString, forKey: "summary")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.first?.summary?.count, longString.count)
    }

    func testMigrationHandlesSpecialURLCharacters() async throws {
        let context = try createTestCoreDataStore()

        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Episode", forKey: "title")
        episode.setValue("ep-1", forKey: "identifier")
        episode.setValue("https://example.com/path?query=value&special=50%25&name=test%20episode", forKey: "enclosureMediaLink")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        let swiftDataContext = modelContainer.mainContext
        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try swiftDataContext.fetch(episodeDescriptor)

        XCTAssertTrue(episodes.first?.enclosureMediaLink?.contains("50%25") ?? false)
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = MigrationTestHelper.createCoreDataModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: legacyStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}

// MARK: - Idempotency Tests

/// Tests to verify migration is idempotent and handles re-runs safely.
@MainActor
final class IdempotentMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdempotencyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("Idempotent.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testMigrationSkipsExistingFeeds() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Existing Feed", forKey: "title")
        feed.setValue("https://existing.com/feed", forKey: "link")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // First migration
        let result1 = try await manager.performMigration()
        XCTAssertEqual(result1.feedsMigrated, 1)

        // Reset and run again
        try manager.resetMigrationMarker()
        let result2 = try await manager.performMigration()
        XCTAssertEqual(result2.feedsMigrated, 0, "Second migration should skip existing feed")

        // Verify only one feed exists
        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 1)
    }

    func testMigrationSkipsExistingEpisodesByIdentifier() async throws {
        let context = try createTestCoreDataStore()

        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Test Episode", forKey: "title")
        episode.setValue("unique-guid-12345", forKey: "identifier")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // First migration
        _ = try await manager.performMigration()

        // Pre-insert another episode with same identifier
        let swiftDataContext = modelContainer.mainContext
        let existing = PodcastEpisode(title: "Pre-existing", identifier: "unique-guid-12345")
        swiftDataContext.insert(existing)
        try swiftDataContext.save()

        // Reset and run again
        try manager.resetMigrationMarker()
        let result2 = try await manager.performMigration()

        // Should skip the episode since identifier matches
        XCTAssertEqual(result2.episodesMigrated, 0)
    }

    func testMigrationBlocksDoubleRun() async throws {
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Complete first migration
        _ = try await manager.performMigration()

        // Second attempt should fail with invalidState
        do {
            _ = try await manager.performMigration()
            XCTFail("Expected invalidState error")
        } catch {
            guard case MigrationError.invalidState = error else {
                XCTFail("Expected invalidState error, got \(error)")
                return
            }
        }
    }

    func testMigrationMarkerPersistedAcrossRuns() async throws {
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        XCTAssertFalse(manager.isMigrationComplete())

        _ = try await manager.performMigration()

        XCTAssertTrue(manager.isMigrationComplete())

        // Create a new manager instance
        let manager2 = DataMigrationManager(modelContainer: modelContainer, importer: importer)
        XCTAssertTrue(manager2.isMigrationComplete(), "Migration marker should persist")
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = MigrationTestHelper.createCoreDataModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: legacyStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}

// MARK: - Nonexistent Store Tests

/// Tests for handling missing or inaccessible legacy stores.
@MainActor
final class NonexistentStoreMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NonexistentTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testMigrationFailsWithNonexistentStore() async {
        let nonexistentURL = tempDirectory.appendingPathComponent("nonexistent.sqlite")

        let importer = CoreDataImporter(storeURL: nonexistentURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        do {
            _ = try await manager.performMigration()
            XCTFail("Expected storeNotFound error")
        } catch {
            guard case MigrationError.storeNotFound = error else {
                XCTFail("Expected storeNotFound error, got \(error)")
                return
            }
        }
    }

    func testIsMigrationNeededReturnsFalseForNonexistentStore() {
        let nonexistentURL = tempDirectory.appendingPathComponent("nonexistent.sqlite")

        let importer = CoreDataImporter(storeURL: nonexistentURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        XCTAssertFalse(manager.isMigrationNeeded())
    }

    func testStoreExistsReturnsFalseForNonexistentStore() {
        let nonexistentURL = tempDirectory.appendingPathComponent("nonexistent.sqlite")

        let importer = CoreDataImporter(storeURL: nonexistentURL)
        XCTAssertFalse(importer.storeExists())
    }
}

// MARK: - Rollback Tests

/// Tests for migration rollback functionality.
@MainActor
final class MigrationRollbackTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RollbackTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("Rollback.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testRollbackClearsMigratedData() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Rollback Test Feed", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Run migration
        _ = try await manager.performMigration()

        // Verify data exists
        let swiftDataContext = modelContainer.mainContext
        var feedDescriptor = FetchDescriptor<PodcastFeed>()
        var feeds = try swiftDataContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 1)

        // Rollback
        try await manager.rollback()

        // Verify data cleared
        feedDescriptor = FetchDescriptor<PodcastFeed>()
        feeds = try swiftDataContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 0)
    }

    func testRollbackClearsMigrationMarker() async throws {
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()
        XCTAssertTrue(manager.isMigrationComplete())

        try await manager.rollback()
        XCTAssertFalse(manager.isMigrationComplete())
    }

    func testRollbackAllowsRemigration() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Remigration Test", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // First migration
        let result1 = try await manager.performMigration()
        XCTAssertEqual(result1.feedsMigrated, 1)

        // Rollback
        try await manager.rollback()

        // Re-migrate
        let result2 = try await manager.performMigration()
        XCTAssertEqual(result2.feedsMigrated, 1)
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = MigrationTestHelper.createCoreDataModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: legacyStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}

// MARK: - Migration Test Helper

/// Shared helper for creating Core Data test models.
enum MigrationTestHelper {

    static func createCoreDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Preference Entity
        let preferenceEntity = NSEntityDescription()
        preferenceEntity.name = "Preference"
        preferenceEntity.managedObjectClassName = "NSManagedObject"
        preferenceEntity.properties = [
            createAttribute("name", .stringAttributeType, optional: false),
            createAttribute("boolValue", .booleanAttributeType, optional: true),
            createAttribute("dateValue", .dateAttributeType, optional: true),
            createAttribute("floatValue", .floatAttributeType, optional: true),
            createAttribute("intValue", .integer16AttributeType, optional: true),
            createAttribute("latCoord", .doubleAttributeType, optional: true),
            createAttribute("longCoord", .doubleAttributeType, optional: true),
            createAttribute("stringValue", .stringAttributeType, optional: true)
        ]

        // RSSEntity
        let rssEntity = NSEntityDescription()
        rssEntity.name = "RSSEntity"
        rssEntity.managedObjectClassName = "NSManagedObject"
        rssEntity.properties = [
            createAttribute("title", .stringAttributeType, optional: true),
            createAttribute("link", .stringAttributeType, optional: true),
            createAttribute("summary", .stringAttributeType, optional: true),
            createAttribute("imageUrl", .stringAttributeType, optional: true)
        ]

        // RSSEntry
        let rssEntry = NSEntityDescription()
        rssEntry.name = "RSSEntry"
        rssEntry.managedObjectClassName = "NSManagedObject"
        rssEntry.properties = [
            createAttribute("title", .stringAttributeType, optional: true),
            createAttribute("identifier", .stringAttributeType, optional: true),
            createAttribute("enclosureMediaLink", .stringAttributeType, optional: true),
            createAttribute("currentInPlayer", .booleanAttributeType, optional: true),
            createAttribute("date", .dateAttributeType, optional: true),
            createAttribute("index", .integer32AttributeType, optional: true),
            createAttribute("lastUpdated", .dateAttributeType, optional: true),
            createAttribute("link", .stringAttributeType, optional: true),
            createAttribute("name", .stringAttributeType, optional: true),
            createAttribute("preferredPlayDurationInMinutes", .integer32AttributeType, optional: true),
            createAttribute("releaseDate", .dateAttributeType, optional: true),
            createAttribute("summary", .stringAttributeType, optional: true),
            createAttribute("type", .integer16AttributeType, optional: true),
            createAttribute("url", .stringAttributeType, optional: true)
        ]

        // WorkoutHistory
        let workoutHistory = NSEntityDescription()
        workoutHistory.name = "WorkoutHistory"
        workoutHistory.managedObjectClassName = "NSManagedObject"
        workoutHistory.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: true),
            createAttribute("address", .stringAttributeType, optional: true),
            createAttribute("startTime", .dateAttributeType, optional: true),
            createAttribute("humidity", .floatAttributeType, optional: true),
            createAttribute("temperatureInCelsius", .floatAttributeType, optional: true),
            createAttribute("windSpeedInKmh", .floatAttributeType, optional: true),
            createAttribute("weatherIconUrl", .stringAttributeType, optional: true),
            createAttribute("alertDate", .stringAttributeType, optional: true),
            createAttribute("alertDescription", .stringAttributeType, optional: true),
            createAttribute("alertExpires", .stringAttributeType, optional: true),
            createAttribute("alertType", .stringAttributeType, optional: true)
        ]

        // WorkoutLocation
        let workoutLocation = NSEntityDescription()
        workoutLocation.name = "WorkoutLocation"
        workoutLocation.managedObjectClassName = "NSManagedObject"
        workoutLocation.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: false),
            createAttribute("time", .dateAttributeType, optional: true),
            createAttribute("heartRate", .integer16AttributeType, optional: true),
            createAttribute("steps", .integer16AttributeType, optional: true)
        ]

        // WorkoutListeningLog
        let workoutListeningLog = NSEntityDescription()
        workoutListeningLog.name = "WorkoutListeningLog"
        workoutListeningLog.managedObjectClassName = "NSManagedObject"
        workoutListeningLog.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: true),
            createAttribute("time", .dateAttributeType, optional: true),
            createAttribute("entityTitle", .stringAttributeType, optional: true),
            createAttribute("entryTitle", .stringAttributeType, optional: true),
            createAttribute("entrySummary", .stringAttributeType, optional: true)
        ]

        // Set up relationships
        let containsRelation = NSRelationshipDescription()
        containsRelation.name = "contains"
        containsRelation.destinationEntity = rssEntry
        containsRelation.isOptional = true
        containsRelation.deleteRule = .nullifyDeleteRule
        containsRelation.minCount = 0
        containsRelation.maxCount = 0

        let belongsToRelation = NSRelationshipDescription()
        belongsToRelation.name = "belongsTo"
        belongsToRelation.destinationEntity = rssEntity
        belongsToRelation.isOptional = true
        belongsToRelation.deleteRule = .nullifyDeleteRule
        belongsToRelation.minCount = 0
        belongsToRelation.maxCount = 1

        containsRelation.inverseRelationship = belongsToRelation
        belongsToRelation.inverseRelationship = containsRelation

        var entityProps = rssEntity.properties
        entityProps.append(containsRelation)
        rssEntity.properties = entityProps

        var entryProps = rssEntry.properties
        entryProps.append(belongsToRelation)
        rssEntry.properties = entryProps

        model.entities = [
            preferenceEntity,
            rssEntity,
            rssEntry,
            workoutHistory,
            workoutLocation,
            workoutListeningLog
        ]

        return model
    }

    private static func createAttribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        return attr
    }
}
