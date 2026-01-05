import XCTest
import SwiftData
import CoreData
@testable import JogPod

/// Unit tests for DataMigrationManager.
///
/// These tests verify the migration orchestration, progress tracking,
/// rollback capabilities, and idempotent behavior.
@MainActor
final class DataMigrationManagerTests: XCTestCase {

    // MARK: - Properties

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    // MARK: - Setup/Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory SwiftData container
        modelContainer = try JogPodSchema.makeTestContainer()

        // Create temporary directory for test stores
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MigrationManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("Legacy.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitializationWithModelContainer() {
        let manager = DataMigrationManager(modelContainer: modelContainer)
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.currentState, "Ready")
    }

    func testInitializationWithCustomPath() {
        let manager = DataMigrationManager(
            modelContainer: modelContainer,
            legacyStorePath: "/custom/path/store.sqlite"
        )
        XCTAssertNotNil(manager)
    }

    // MARK: - Migration Status Tests

    func testIsMigrationCompleteInitiallyFalse() {
        let manager = DataMigrationManager(modelContainer: modelContainer)
        XCTAssertFalse(manager.isMigrationComplete())
    }

    func testIsMigrationNeededWithoutStore() {
        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // No store exists, so migration is not needed
        XCTAssertFalse(manager.isMigrationNeeded())
    }

    func testIsMigrationNeededWithStore() throws {
        // Create empty store file
        FileManager.default.createFile(atPath: legacyStoreURL.path, contents: nil)

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Store exists and migration not complete
        XCTAssertTrue(manager.isMigrationNeeded())
    }

    func testCurrentStateReturnsReady() {
        let manager = DataMigrationManager(modelContainer: modelContainer)
        XCTAssertEqual(manager.currentState, "Ready")
    }

    // MARK: - Migration Marker Tests

    func testResetMigrationMarker() throws {
        let manager = DataMigrationManager(modelContainer: modelContainer)

        // Mark complete first
        let context = modelContainer.mainContext
        let marker = Preference(name: "com.jogpod.migration.completed", boolValue: true)
        context.insert(marker)
        try context.save()

        XCTAssertTrue(manager.isMigrationComplete())

        // Reset
        try manager.resetMigrationMarker()

        XCTAssertFalse(manager.isMigrationComplete())
    }

    // MARK: - Empty Migration Tests

    func testMigrationWithEmptyStore() async throws {
        // Create a valid but empty Core Data store
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.totalRecordsMigrated, 0)
        XCTAssertTrue(result.warnings.contains { $0.contains("empty") })
        XCTAssertTrue(manager.isMigrationComplete())
    }

    // MARK: - Full Migration Tests

    func testMigrationWithSampleData() async throws {
        // Create store with sample data
        let context = try createTestCoreDataStore()
        try populateTestData(in: context)
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        var progressUpdates: [DataMigrationManager.MigrationProgress] = []
        let result = try await manager.performMigration { progress in
            progressUpdates.append(progress)
        }

        // Verify result
        XCTAssertGreaterThan(result.totalRecordsMigrated, 0)
        XCTAssertEqual(result.feedsMigrated, 2)
        XCTAssertEqual(result.episodesMigrated, 3)
        XCTAssertEqual(result.preferencesMigrated, 1)
        XCTAssertEqual(result.workoutSessionsMigrated, 1)

        // Verify progress updates
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertTrue(progressUpdates.contains { $0.phase == .migratingFeeds })
        XCTAssertTrue(progressUpdates.contains { $0.phase == .completed })

        // Verify migration is marked complete
        XCTAssertTrue(manager.isMigrationComplete())

        // Verify data in SwiftData
        let swiftDataContext = modelContainer.mainContext

        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 2)

        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try swiftDataContext.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 3)
    }

    func testMigrationPreservesRelationships() async throws {
        let context = try createTestCoreDataStore()

        // Create feed with episodes
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Test Podcast", forKey: "title")

        let episode1 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode1.setValue("Episode 1", forKey: "title")
        episode1.setValue("ep-1", forKey: "identifier")
        episode1.setValue(feed, forKey: "belongsTo")

        let episode2 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode2.setValue("Episode 2", forKey: "title")
        episode2.setValue("ep-2", forKey: "identifier")
        episode2.setValue(feed, forKey: "belongsTo")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        // Verify relationship preserved
        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.episodes.count, 2)
    }

    // MARK: - Idempotent Migration Tests

    func testMigrationIsIdempotent() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Podcast", forKey: "title")
        feed.setValue("https://example.com", forKey: "link")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // First migration
        let result1 = try await manager.performMigration()
        XCTAssertEqual(result1.feedsMigrated, 1)

        // Reset marker to allow re-run
        try manager.resetMigrationMarker()

        // Second migration should not duplicate
        let result2 = try await manager.performMigration()
        XCTAssertEqual(result2.feedsMigrated, 0) // Skipped existing

        // Verify only one feed exists
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try modelContainer.mainContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 1)
    }

    func testMigrationSkipsExistingEpisodes() async throws {
        let context = try createTestCoreDataStore()

        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Episode", forKey: "title")
        episode.setValue("unique-guid", forKey: "identifier")
        try context.save()

        // Pre-insert episode in SwiftData
        let existingEpisode = PodcastEpisode(title: "Episode", identifier: "unique-guid")
        modelContainer.mainContext.insert(existingEpisode)
        try modelContainer.mainContext.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Episode should be skipped
        XCTAssertEqual(result.episodesMigrated, 0)

        // Verify still only one episode
        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try modelContainer.mainContext.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 1)
    }

    // MARK: - Error Handling Tests

    func testMigrationFailsWithNonexistentStore() async {
        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        do {
            _ = try await manager.performMigration()
            XCTFail("Expected migration to fail")
        } catch {
            guard case MigrationError.storeNotFound = error else {
                XCTFail("Expected storeNotFound error, got \(error)")
                return
            }
        }
    }

    func testMigrationRejectsDoubleRun() async throws {
        let context = try createTestCoreDataStore()
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Complete first migration
        _ = try await manager.performMigration()

        // Second attempt should fail
        do {
            _ = try await manager.performMigration()
            XCTFail("Expected migration to fail")
        } catch {
            guard case MigrationError.invalidState = error else {
                XCTFail("Expected invalidState error, got \(error)")
                return
            }
        }
    }

    // MARK: - Rollback Tests

    func testRollbackClearsData() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Podcast", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Run migration
        _ = try await manager.performMigration()

        // Verify data exists
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        var feeds = try modelContainer.mainContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 1)

        // Rollback
        try await manager.rollback()

        // Verify data cleared
        feeds = try modelContainer.mainContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 0)

        // Verify marker cleared
        XCTAssertFalse(manager.isMigrationComplete())
    }

    // MARK: - Progress Tests

    func testMigrationProgressUpdates() async throws {
        let context = try createTestCoreDataStore()

        for i in 0..<5 {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Podcast \(i)", forKey: "title")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        var phases: Set<DataMigrationManager.MigrationPhase> = []
        var sawProgress = false

        _ = try await manager.performMigration { progress in
            phases.insert(progress.phase)
            if progress.totalItems > 1 && progress.currentItem > 0 {
                sawProgress = true
            }
        }

        XCTAssertTrue(phases.contains(.validating))
        XCTAssertTrue(phases.contains(.readingLegacyData))
        XCTAssertTrue(phases.contains(.migratingFeeds))
        XCTAssertTrue(phases.contains(.completed))
        XCTAssertTrue(sawProgress)
    }

    func testMigrationProgressPercentage() {
        let progress = DataMigrationManager.MigrationProgress(
            phase: .migratingFeeds,
            currentItem: 50,
            totalItems: 100,
            message: "Test"
        )

        XCTAssertEqual(progress.percentComplete, 50)
        XCTAssertFalse(progress.isComplete)
    }

    func testMigrationProgressPercentageWithZeroTotal() {
        let progress = DataMigrationManager.MigrationProgress(
            phase: .validating,
            currentItem: 0,
            totalItems: 0,
            message: "Test"
        )

        XCTAssertEqual(progress.percentComplete, 0)
    }

    func testMigrationProgressIsComplete() {
        let progress = DataMigrationManager.MigrationProgress(
            phase: .completed,
            currentItem: 100,
            totalItems: 100,
            message: "Done"
        )

        XCTAssertTrue(progress.isComplete)
    }

    // MARK: - MigrationResult Tests

    func testMigrationResultTotalCount() {
        let result = DataMigrationManager.MigrationResult(
            feedsMigrated: 5,
            episodesMigrated: 50,
            preferencesMigrated: 10,
            workoutSessionsMigrated: 20,
            trackPointsMigrated: 1000,
            listeningLogsMigrated: 100,
            startTime: Date(),
            endTime: Date(),
            warnings: []
        )

        XCTAssertEqual(result.totalRecordsMigrated, 1185)
    }

    func testMigrationResultDuration() {
        let start = Date()
        let end = start.addingTimeInterval(65) // 65 seconds

        let result = DataMigrationManager.MigrationResult(
            feedsMigrated: 0,
            episodesMigrated: 0,
            preferencesMigrated: 0,
            workoutSessionsMigrated: 0,
            trackPointsMigrated: 0,
            listeningLogsMigrated: 0,
            startTime: start,
            endTime: end,
            warnings: []
        )

        XCTAssertEqual(result.duration, 65, accuracy: 0.1)
        XCTAssertFalse(result.formattedDuration.isEmpty)
    }

    func testMigrationResultDescription() {
        let result = DataMigrationManager.MigrationResult(
            feedsMigrated: 5,
            episodesMigrated: 10,
            preferencesMigrated: 2,
            workoutSessionsMigrated: 3,
            trackPointsMigrated: 100,
            listeningLogsMigrated: 15,
            startTime: Date(),
            endTime: Date().addingTimeInterval(30),
            warnings: ["Warning 1", "Warning 2"]
        )

        let description = result.description
        XCTAssertTrue(description.contains("Podcast Feeds: 5"))
        XCTAssertTrue(description.contains("Podcast Episodes: 10"))
        XCTAssertTrue(description.contains("Total: 135"))
        XCTAssertTrue(description.contains("Warning 1"))
        XCTAssertTrue(description.contains("Warning 2"))
    }

    // MARK: - Edge Cases

    func testMigrationHandlesOrphanedEpisodes() async throws {
        let context = try createTestCoreDataStore()

        // Episode without feed
        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Orphaned Episode", forKey: "title")
        episode.setValue("orphan-1", forKey: "identifier")
        // No belongsTo set

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Should still migrate the episode (without a feed relationship)
        XCTAssertEqual(result.episodesMigrated, 1)

        // Verify episode was created
        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try modelContainer.mainContext.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertNil(episodes.first?.feed)
    }

    func testMigrationHandlesMissingWorkoutID() async throws {
        let context = try createTestCoreDataStore()

        // Workout without ID
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(nil, forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Should generate a UUID for the workout
        XCTAssertEqual(result.workoutSessionsMigrated, 1)

        let sessionDescriptor = FetchDescriptor<WorkoutSession>()
        let sessions = try modelContainer.mainContext.fetch(sessionDescriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(sessions.first?.workoutID.isEmpty ?? true)
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = createTestModel()
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

    private func populateTestData(in context: NSManagedObjectContext) throws {
        // Create 2 feeds with 3 episodes total
        let feed1 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed1.setValue("Podcast One", forKey: "title")
        feed1.setValue("https://podcast1.com", forKey: "link")

        let feed2 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed2.setValue("Podcast Two", forKey: "title")
        feed2.setValue("https://podcast2.com", forKey: "link")

        let ep1 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        ep1.setValue("Episode 1", forKey: "title")
        ep1.setValue("ep1", forKey: "identifier")
        ep1.setValue(feed1, forKey: "belongsTo")

        let ep2 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        ep2.setValue("Episode 2", forKey: "title")
        ep2.setValue("ep2", forKey: "identifier")
        ep2.setValue(feed1, forKey: "belongsTo")

        let ep3 = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        ep3.setValue("Episode 3", forKey: "title")
        ep3.setValue("ep3", forKey: "identifier")
        ep3.setValue(feed2, forKey: "belongsTo")

        // Preference
        let pref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        pref.setValue("darkMode", forKey: "name")
        pref.setValue(true, forKey: "boolValue")

        // Workout
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue("workout-001", forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")
    }

    private func createTestModel() -> NSManagedObjectModel {
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

        let locationAttr = NSAttributeDescription()
        locationAttr.name = "location"
        locationAttr.attributeType = .transformableAttributeType
        locationAttr.isOptional = true

        workoutLocation.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: false),
            createAttribute("time", .dateAttributeType, optional: true),
            createAttribute("heartRate", .integer16AttributeType, optional: true),
            createAttribute("steps", .integer16AttributeType, optional: true),
            locationAttr
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

    private func createAttribute(
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
