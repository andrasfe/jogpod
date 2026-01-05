import XCTest
import CoreData
import CoreLocation
@testable import JogPod

/// Unit tests for CoreDataImporter.
///
/// These tests verify the importer correctly reads legacy Core Data stores
/// and transforms data into the expected format.
final class CoreDataImporterTests: XCTestCase {

    // MARK: - Properties

    private var tempDirectory: URL!
    private var testStoreURL: URL!

    // MARK: - Setup/Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create a temporary directory for test stores
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataImporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        testStoreURL = tempDirectory.appendingPathComponent("TestStore.sqlite")
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Store Validation Tests

    func testStoreExistsReturnsFalseForNonexistent() {
        let importer = CoreDataImporter(storeURL: testStoreURL)
        XCTAssertFalse(importer.storeExists())
    }

    func testStoreExistsReturnsTrueForExisting() throws {
        // Create an empty file
        FileManager.default.createFile(atPath: testStoreURL.path, contents: nil)

        let importer = CoreDataImporter(storeURL: testStoreURL)
        XCTAssertTrue(importer.storeExists())
    }

    func testValidateStoreThrowsForNonexistent() {
        let importer = CoreDataImporter(storeURL: testStoreURL)

        XCTAssertThrowsError(try importer.validateStore()) { error in
            guard case MigrationError.storeNotFound = error else {
                XCTFail("Expected storeNotFound error, got \(error)")
                return
            }
        }
    }

    // MARK: - Default Importer Tests

    func testDefaultImporterReturnsNonNil() {
        let importer = CoreDataImporter.defaultImporter()
        XCTAssertNotNil(importer)
    }

    // MARK: - Legacy Data Types Tests

    func testLegacyPodcastFeedStructure() {
        let feed = CoreDataImporter.LegacyPodcastFeed(
            objectID: "test-id",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com",
            summary: "A great podcast",
            title: "My Podcast",
            episodeObjectIDs: ["ep1", "ep2"]
        )

        XCTAssertEqual(feed.objectID, "test-id")
        XCTAssertEqual(feed.title, "My Podcast")
        XCTAssertEqual(feed.episodeObjectIDs.count, 2)
    }

    func testLegacyPodcastEpisodeStructure() {
        let episode = CoreDataImporter.LegacyPodcastEpisode(
            objectID: "episode-id",
            isCurrentInPlayer: true,
            date: Date(),
            enclosureMediaLink: "https://example.com/episode.mp3",
            identifier: "guid-123",
            index: 5,
            lastUpdated: Date(),
            link: "https://example.com/episode",
            name: "Episode Name",
            preferredPlayDurationInMinutes: 30,
            releaseDate: Date(),
            summary: "Episode summary",
            title: "Episode Title",
            type: 1,
            url: "https://example.com/alt",
            feedObjectID: "feed-id"
        )

        XCTAssertEqual(episode.objectID, "episode-id")
        XCTAssertTrue(episode.isCurrentInPlayer)
        XCTAssertEqual(episode.identifier, "guid-123")
        XCTAssertEqual(episode.type, 1)
        XCTAssertEqual(episode.feedObjectID, "feed-id")
    }

    func testLegacyPreferenceStructure() {
        let pref = CoreDataImporter.LegacyPreference(
            objectID: "pref-id",
            name: "darkMode",
            boolValue: true,
            dateValue: Date(),
            floatValue: 1.5,
            intValue: 10,
            latCoord: 37.7749,
            longCoord: -122.4194,
            stringValue: "test"
        )

        XCTAssertEqual(pref.name, "darkMode")
        XCTAssertEqual(pref.boolValue, true)
        XCTAssertEqual(pref.latCoord, 37.7749)
        XCTAssertEqual(pref.longCoord, -122.4194)
    }

    func testLegacyWorkoutSessionStructure() {
        let session = CoreDataImporter.LegacyWorkoutSession(
            objectID: "session-id",
            workoutID: "workout-123",
            address: "123 Main St",
            startTime: Date(),
            humidity: 0.65,
            temperatureInCelsius: 22.5,
            windSpeedInKmh: 15.0,
            weatherIconUrl: "https://weather.com/sunny.png",
            alertDate: "2024-01-01",
            alertDescription: "Heat advisory",
            alertExpires: "2024-01-02",
            alertType: "heat"
        )

        XCTAssertEqual(session.workoutID, "workout-123")
        XCTAssertEqual(session.address, "123 Main St")
        XCTAssertEqual(session.temperatureInCelsius, 22.5)
        XCTAssertEqual(session.alertType, "heat")
    }

    func testLegacyWorkoutTrackPointStructure() {
        let trackPoint = CoreDataImporter.LegacyWorkoutTrackPoint(
            objectID: "point-id",
            workoutID: "workout-123",
            time: Date(),
            heartRate: 145,
            steps: 1500,
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 50.0,
            horizontalAccuracy: 5.0,
            speed: 3.5,
            course: 90.0
        )

        XCTAssertEqual(trackPoint.workoutID, "workout-123")
        XCTAssertEqual(trackPoint.heartRate, 145)
        XCTAssertEqual(trackPoint.latitude, 37.7749)
        XCTAssertEqual(trackPoint.longitude, -122.4194)
        XCTAssertEqual(trackPoint.speed, 3.5)
    }

    func testLegacyWorkoutListeningLogStructure() {
        let log = CoreDataImporter.LegacyWorkoutListeningLog(
            objectID: "log-id",
            workoutID: "workout-123",
            time: Date(),
            entityTitle: "My Podcast",
            entryTitle: "Episode 1",
            entrySummary: "Great episode"
        )

        XCTAssertEqual(log.workoutID, "workout-123")
        XCTAssertEqual(log.entityTitle, "My Podcast")
        XCTAssertEqual(log.entryTitle, "Episode 1")
    }

    // MARK: - ImportedData Tests

    func testImportedDataIsEmptyWithNoData() {
        let data = CoreDataImporter.ImportedData(
            feeds: [],
            episodes: [],
            preferences: [],
            workoutSessions: [],
            trackPoints: [],
            listeningLogs: []
        )

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(data.totalCount, 0)
    }

    func testImportedDataTotalCountIsCorrect() {
        let data = CoreDataImporter.ImportedData(
            feeds: [makeFeed()],
            episodes: [makeEpisode(), makeEpisode()],
            preferences: [makePreference()],
            workoutSessions: [makeSession()],
            trackPoints: [makeTrackPoint(), makeTrackPoint(), makeTrackPoint()],
            listeningLogs: [makeLog()]
        )

        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.totalCount, 9) // 1+2+1+1+3+1
    }

    func testImportedDataStatistics() {
        let data = CoreDataImporter.ImportedData(
            feeds: [makeFeed(), makeFeed()],
            episodes: [makeEpisode()],
            preferences: [],
            workoutSessions: [makeSession()],
            trackPoints: [],
            listeningLogs: []
        )

        let stats = data.statistics
        XCTAssertEqual(stats["Podcast Feeds"], 2)
        XCTAssertEqual(stats["Podcast Episodes"], 1)
        XCTAssertEqual(stats["Preferences"], 0)
        XCTAssertEqual(stats["Workout Sessions"], 1)
        XCTAssertEqual(stats["Track Points"], 0)
        XCTAssertEqual(stats["Listening Logs"], 0)
        XCTAssertEqual(stats["Total Records"], 4)
    }

    func testImportedDataSummaryDescription() {
        let data = CoreDataImporter.ImportedData(
            feeds: [makeFeed()],
            episodes: [makeEpisode()],
            preferences: [makePreference()],
            workoutSessions: [makeSession()],
            trackPoints: [makeTrackPoint()],
            listeningLogs: [makeLog()]
        )

        let summary = data.summaryDescription()
        XCTAssertTrue(summary.contains("Podcast Feeds: 1"))
        XCTAssertTrue(summary.contains("Podcast Episodes: 1"))
        XCTAssertTrue(summary.contains("Total: 6 records"))
    }

    // MARK: - Helper Methods

    private func makeFeed() -> CoreDataImporter.LegacyPodcastFeed {
        CoreDataImporter.LegacyPodcastFeed(
            objectID: UUID().uuidString,
            imageUrl: nil,
            link: nil,
            summary: nil,
            title: "Test Feed",
            episodeObjectIDs: []
        )
    }

    private func makeEpisode() -> CoreDataImporter.LegacyPodcastEpisode {
        CoreDataImporter.LegacyPodcastEpisode(
            objectID: UUID().uuidString,
            isCurrentInPlayer: false,
            date: nil,
            enclosureMediaLink: nil,
            identifier: UUID().uuidString,
            index: 0,
            lastUpdated: nil,
            link: nil,
            name: nil,
            preferredPlayDurationInMinutes: 0,
            releaseDate: nil,
            summary: nil,
            title: "Test Episode",
            type: 0,
            url: nil,
            feedObjectID: nil
        )
    }

    private func makePreference() -> CoreDataImporter.LegacyPreference {
        CoreDataImporter.LegacyPreference(
            objectID: UUID().uuidString,
            name: "testPref",
            boolValue: nil,
            dateValue: nil,
            floatValue: nil,
            intValue: nil,
            latCoord: nil,
            longCoord: nil,
            stringValue: nil
        )
    }

    private func makeSession() -> CoreDataImporter.LegacyWorkoutSession {
        CoreDataImporter.LegacyWorkoutSession(
            objectID: UUID().uuidString,
            workoutID: UUID().uuidString,
            address: nil,
            startTime: nil,
            humidity: nil,
            temperatureInCelsius: nil,
            windSpeedInKmh: nil,
            weatherIconUrl: nil,
            alertDate: nil,
            alertDescription: nil,
            alertExpires: nil,
            alertType: nil
        )
    }

    private func makeTrackPoint() -> CoreDataImporter.LegacyWorkoutTrackPoint {
        CoreDataImporter.LegacyWorkoutTrackPoint(
            objectID: UUID().uuidString,
            workoutID: UUID().uuidString,
            time: nil,
            heartRate: nil,
            steps: nil,
            latitude: nil,
            longitude: nil,
            altitude: nil,
            horizontalAccuracy: nil,
            speed: nil,
            course: nil
        )
    }

    private func makeLog() -> CoreDataImporter.LegacyWorkoutListeningLog {
        CoreDataImporter.LegacyWorkoutListeningLog(
            objectID: UUID().uuidString,
            workoutID: UUID().uuidString,
            time: nil,
            entityTitle: nil,
            entryTitle: nil,
            entrySummary: nil
        )
    }
}

// MARK: - Integration Tests with Real Core Data Store

extension CoreDataImporterTests {

    /// Creates a test Core Data store with sample data.
    ///
    /// This helper creates a real SQLite store that can be used to test the importer.
    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = createTestModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: testStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
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
            createAttribute("index", .integer32AttributeType, optional: true),
            createAttribute("type", .integer16AttributeType, optional: true)
        ]

        // WorkoutHistory
        let workoutHistory = NSEntityDescription()
        workoutHistory.name = "WorkoutHistory"
        workoutHistory.managedObjectClassName = "NSManagedObject"
        workoutHistory.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: true),
            createAttribute("address", .stringAttributeType, optional: true),
            createAttribute("startTime", .dateAttributeType, optional: true)
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

    func testImportFromRealCoreDataStore() async throws {
        // Create test store with data
        let context = try createTestCoreDataStore()

        // Insert test data
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Test Podcast", forKey: "title")
        feed.setValue("https://example.com", forKey: "link")

        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Test Episode", forKey: "title")
        episode.setValue("guid-123", forKey: "identifier")
        episode.setValue(feed, forKey: "belongsTo")

        let pref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        pref.setValue("testSetting", forKey: "name")
        pref.setValue(true, forKey: "boolValue")

        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue("workout-001", forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        try context.save()

        // Test import
        let importer = CoreDataImporter(storeURL: testStoreURL)
        XCTAssertTrue(importer.storeExists())

        let data = try await importer.importAllData()

        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.feeds.count, 1)
        XCTAssertEqual(data.episodes.count, 1)
        XCTAssertEqual(data.preferences.count, 1)
        XCTAssertEqual(data.workoutSessions.count, 1)

        // Verify feed data
        XCTAssertEqual(data.feeds.first?.title, "Test Podcast")
        XCTAssertEqual(data.feeds.first?.link, "https://example.com")

        // Verify episode data and relationship
        XCTAssertEqual(data.episodes.first?.title, "Test Episode")
        XCTAssertEqual(data.episodes.first?.identifier, "guid-123")
        XCTAssertNotNil(data.episodes.first?.feedObjectID)

        // Verify preference data
        XCTAssertEqual(data.preferences.first?.name, "testSetting")
        XCTAssertEqual(data.preferences.first?.boolValue, true)

        // Verify workout session data
        XCTAssertEqual(data.workoutSessions.first?.workoutID, "workout-001")
    }

    func testImportEmptyStore() async throws {
        // Create empty store
        _ = try createTestCoreDataStore()

        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(data.totalCount, 0)
    }

    func testImportWithProgressHandler() async throws {
        let context = try createTestCoreDataStore()

        // Add some data
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Test", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: testStoreURL)

        var progressMessages: [String] = []
        let data = try await importer.importAllData { message, current, total in
            progressMessages.append(message)
        }

        XCTAssertFalse(data.isEmpty)
        XCTAssertFalse(progressMessages.isEmpty)
        XCTAssertTrue(progressMessages.contains { $0.contains("podcast") || $0.contains("feed") })
    }
}
