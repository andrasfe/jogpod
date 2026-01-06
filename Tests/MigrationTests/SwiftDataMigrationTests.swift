//
//  SwiftDataMigrationTests.swift
//  JogPodTests
//
//  Comprehensive test suite for Core Data to SwiftData migration.
//  Tests cover schema validation, data integrity, edge cases, and performance.
//

import XCTest
import SwiftData
import CoreData
import CoreLocation
@testable import JogPod

// Note: CLLocationValueTransformer is used in createTestModel() for WorkoutLocation entity

// MARK: - SwiftData Schema Validation Tests

/// Tests to validate the SwiftData schema structure and configuration.
@MainActor
final class SwiftDataSchemaValidationTests: XCTestCase {

    // MARK: - Schema Structure Tests

    func testSchemaContainsAllRequiredModels() throws {
        let models = JogPodSchema.models

        XCTAssertEqual(models.count, 6, "Schema should contain exactly 6 model types")

        let modelNames = models.map { String(describing: $0) }
        XCTAssertTrue(modelNames.contains("PodcastFeed"))
        XCTAssertTrue(modelNames.contains("PodcastEpisode"))
        XCTAssertTrue(modelNames.contains("Preference"))
        XCTAssertTrue(modelNames.contains("WorkoutSession"))
        XCTAssertTrue(modelNames.contains("WorkoutTrackPoint"))
        XCTAssertTrue(modelNames.contains("WorkoutListeningLog"))
    }

    func testSchemaCreation() throws {
        let schema = JogPodSchema.schema
        XCTAssertNotNil(schema, "Schema should be created successfully")
    }

    func testContainerCreationWithInMemoryStore() throws {
        let container = try JogPodSchema.makeContainer(inMemory: true)
        XCTAssertNotNil(container)
        XCTAssertNotNil(container.mainContext)
    }

    func testTestContainerCreation() throws {
        let container = try JogPodSchema.makeTestContainer()
        XCTAssertNotNil(container)

        // Verify we can create and save objects
        let context = container.mainContext
        let feed = PodcastFeed(title: "Test Feed")
        context.insert(feed)
        try context.save()

        let descriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try context.fetch(descriptor)
        XCTAssertEqual(feeds.count, 1)
    }

    // MARK: - Model Attribute Tests

    func testPodcastFeedAttributeDefaults() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed()
        context.insert(feed)
        try context.save()

        XCTAssertNil(feed.title)
        XCTAssertNil(feed.link)
        XCTAssertNil(feed.summary)
        XCTAssertNil(feed.imageUrl)
        XCTAssertTrue(feed.episodes.isEmpty)
    }

    func testPodcastEpisodeAttributeDefaults() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode()
        context.insert(episode)
        try context.save()

        XCTAssertFalse(episode.isCurrentInPlayer)
        XCTAssertEqual(episode.index, 0)
        XCTAssertEqual(episode.preferredPlayDurationInMinutes, 0)
        XCTAssertEqual(episode.type, 0)
        XCTAssertNil(episode.feed)
    }

    func testPreferenceNameUniqueness() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let pref1 = Preference(name: "testPref", boolValue: true)
        context.insert(pref1)
        try context.save()

        // Second preference with same name should fail or replace
        let pref2 = Preference(name: "testPref", boolValue: false)
        context.insert(pref2)

        // SwiftData's @Attribute(.unique) should handle this
        // We expect either an error or an upsert behavior
        do {
            try context.save()
            // If save succeeds, only one preference should exist (upsert)
            let descriptor = FetchDescriptor<Preference>()
            let prefs = try context.fetch(descriptor)
            XCTAssertEqual(prefs.count, 1, "Unique constraint should prevent duplicates")
        } catch {
            // Unique constraint violation is acceptable
        }
    }

    func testWorkoutSessionWorkoutIDUniqueness() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "unique-workout-id")
        context.insert(session1)
        try context.save()

        let session2 = WorkoutSession(workoutID: "unique-workout-id")
        context.insert(session2)

        do {
            try context.save()
            // If save succeeds, only one session should exist
            let descriptor = FetchDescriptor<WorkoutSession>()
            let sessions = try context.fetch(descriptor)
            XCTAssertEqual(sessions.count, 1, "Unique constraint should prevent duplicate workoutIDs")
        } catch {
            // Unique constraint violation is acceptable
        }
    }

    func testWorkoutTrackPointWorkoutIDIndexing() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        // Create multiple track points for the same workout
        for i in 0..<10 {
            let trackPoint = WorkoutTrackPoint(
                workoutID: "workout-test",
                time: Date().addingTimeInterval(Double(i) * 60)
            )
            trackPoint.heartRate = Int16(120 + i)
            context.insert(trackPoint)
        }
        try context.save()

        // Fetch should use indexed workoutID efficiently
        let descriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: "workout-test")
        let trackPoints = try context.fetch(descriptor)
        XCTAssertEqual(trackPoints.count, 10)

        // Verify chronological ordering
        for i in 1..<trackPoints.count {
            let prev = trackPoints[i - 1].time ?? .distantPast
            let curr = trackPoints[i].time ?? .distantPast
            XCTAssertLessThanOrEqual(prev, curr, "Track points should be ordered chronologically")
        }
    }

    // MARK: - Relationship Tests

    func testPodcastFeedEpisodeRelationship() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        let episode1 = PodcastEpisode(title: "Episode 1", feed: feed)
        let episode2 = PodcastEpisode(title: "Episode 2", feed: feed)
        context.insert(episode1)
        context.insert(episode2)
        try context.save()

        // Verify bidirectional relationship
        XCTAssertEqual(feed.episodes.count, 2)
        XCTAssertTrue(episode1.feed === feed)
        XCTAssertTrue(episode2.feed === feed)
    }

    func testCascadeDeleteFeedRemovesEpisodes() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Cascade Test")
        context.insert(feed)

        for i in 1...5 {
            let episode = PodcastEpisode(title: "Episode \(i)", feed: feed)
            context.insert(episode)
        }
        try context.save()

        // Verify setup
        var episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        var episodes = try context.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 5)

        // Delete feed
        context.delete(feed)
        try context.save()

        // Verify cascade delete
        episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        episodes = try context.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 0, "Episodes should be deleted when feed is deleted (cascade)")
    }

    // MARK: - Legacy Entity Mapping Tests

    func testLegacyEntityNameMappingsComplete() {
        let mappings = JogPodSchema.legacyEntityNameMappings

        XCTAssertEqual(mappings.count, 6, "All 6 legacy entities should be mapped")
        XCTAssertTrue(mappings["RSSEntity"] == PodcastFeed.self)
        XCTAssertTrue(mappings["RSSEntry"] == PodcastEpisode.self)
        XCTAssertTrue(mappings["Preference"] == Preference.self)
        XCTAssertTrue(mappings["WorkoutHistory"] == WorkoutSession.self)
        XCTAssertTrue(mappings["WorkoutLocation"] == WorkoutTrackPoint.self)
        XCTAssertTrue(mappings["WorkoutListeningLog"] == WorkoutListeningLog.self)
    }

    func testLegacyAttributeNameMappings() {
        let mappings = JogPodSchema.legacyAttributeNameMappings

        // RSSEntry mappings
        let entryMappings = mappings["RSSEntry"]
        XCTAssertNotNil(entryMappings)
        XCTAssertEqual(entryMappings?["currentInPlayer"], "isCurrentInPlayer")
        XCTAssertEqual(entryMappings?["belongsTo"], "feed")

        // RSSEntity mappings
        let entityMappings = mappings["RSSEntity"]
        XCTAssertNotNil(entityMappings)
        XCTAssertEqual(entityMappings?["contains"], "episodes")
    }
}

// MARK: - Data Integrity Tests

/// Tests to verify data integrity during and after migration.
@MainActor
final class DataIntegrityTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataIntegrityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("LegacyIntegrity.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Data Preservation Tests

    func testAllAttributesPreservedDuringMigration() async throws {
        let context = try createTestCoreDataStore()

        // Create feed with all attributes
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Test Title", forKey: "title")
        feed.setValue("https://test.com/feed", forKey: "link")
        feed.setValue("Test summary text", forKey: "summary")
        feed.setValue("https://test.com/image.jpg", forKey: "imageUrl")

        // Create episode with all attributes
        let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
        episode.setValue("Episode Title", forKey: "title")
        episode.setValue("ep-guid-12345", forKey: "identifier")
        episode.setValue("https://test.com/episode.mp3", forKey: "enclosureMediaLink")
        episode.setValue(true, forKey: "currentInPlayer")
        episode.setValue(Date(), forKey: "date")
        episode.setValue(Int32(5), forKey: "index")
        episode.setValue(Date(), forKey: "lastUpdated")
        episode.setValue("https://test.com/episode-page", forKey: "link")
        episode.setValue("Episode Name", forKey: "name")
        episode.setValue(Int32(45), forKey: "preferredPlayDurationInMinutes")
        episode.setValue(Date(), forKey: "releaseDate")
        episode.setValue("Episode summary", forKey: "summary")
        episode.setValue(Int16(1), forKey: "type")
        episode.setValue("https://alt.url", forKey: "url")
        episode.setValue(feed, forKey: "belongsTo")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.feedsMigrated, 1)
        XCTAssertEqual(result.episodesMigrated, 1)

        // Verify all attributes were preserved
        let swiftDataContext = modelContainer.mainContext

        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)
        XCTAssertEqual(feeds.count, 1)

        let migratedFeed = feeds.first!
        XCTAssertEqual(migratedFeed.title, "Test Title")
        XCTAssertEqual(migratedFeed.link, "https://test.com/feed")
        XCTAssertEqual(migratedFeed.summary, "Test summary text")
        XCTAssertEqual(migratedFeed.imageUrl, "https://test.com/image.jpg")

        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try swiftDataContext.fetch(episodeDescriptor)
        XCTAssertEqual(episodes.count, 1)

        let migratedEpisode = episodes.first!
        XCTAssertEqual(migratedEpisode.title, "Episode Title")
        XCTAssertEqual(migratedEpisode.identifier, "ep-guid-12345")
        XCTAssertEqual(migratedEpisode.enclosureMediaLink, "https://test.com/episode.mp3")
        XCTAssertTrue(migratedEpisode.isCurrentInPlayer)
        XCTAssertEqual(migratedEpisode.index, 5)
        XCTAssertEqual(migratedEpisode.name, "Episode Name")
        XCTAssertEqual(migratedEpisode.preferredPlayDurationInMinutes, 45)
        XCTAssertEqual(migratedEpisode.type, 1)
    }

    func testRelationshipsPreservedDuringMigration() async throws {
        let context = try createTestCoreDataStore()

        // Create feed with multiple episodes
        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Parent Feed", forKey: "title")
        feed.setValue("https://parent.com/feed", forKey: "link")

        for i in 1...3 {
            let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
            episode.setValue("Episode \(i)", forKey: "title")
            episode.setValue("ep-\(i)", forKey: "identifier")
            episode.setValue(feed, forKey: "belongsTo")
        }

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        _ = try await manager.performMigration()

        // Verify relationship
        let swiftDataContext = modelContainer.mainContext
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feeds = try swiftDataContext.fetch(feedDescriptor)

        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.episodes.count, 3)

        // Verify each episode's feed reference
        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodes = try swiftDataContext.fetch(episodeDescriptor)
        for episode in episodes {
            XCTAssertNotNil(episode.feed)
            XCTAssertEqual(episode.feed?.title, "Parent Feed")
        }
    }

    func testWorkoutDataRelationshipsPreserved() async throws {
        let context = try createTestCoreDataStore()

        // Create workout session
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue("workout-integrity-test", forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")
        session.setValue("123 Test Street", forKey: "address")
        session.setValue(Float(22.5), forKey: "temperatureInCelsius")

        // Create associated track points
        for i in 0..<5 {
            let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
            trackPoint.setValue("workout-integrity-test", forKey: "workoutID")
            trackPoint.setValue(Date().addingTimeInterval(Double(i) * 60), forKey: "time")
            trackPoint.setValue(Int16(120 + i), forKey: "heartRate")
        }

        // Create listening log
        let log = NSEntityDescription.insertNewObject(forEntityName: "WorkoutListeningLog", into: context)
        log.setValue("workout-integrity-test", forKey: "workoutID")
        log.setValue(Date(), forKey: "time")
        log.setValue("Running Podcast", forKey: "entityTitle")
        log.setValue("Episode 1", forKey: "entryTitle")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.workoutSessionsMigrated, 1)
        XCTAssertEqual(result.trackPointsMigrated, 5)
        XCTAssertEqual(result.listeningLogsMigrated, 1)

        // Verify all data can be fetched by workoutID
        let swiftDataContext = modelContainer.mainContext

        let sessionDescriptor = WorkoutSession.fetchDescriptor(forWorkoutID: "workout-integrity-test")
        let sessions = try swiftDataContext.fetch(sessionDescriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.address, "123 Test Street")

        let trackPointsDescriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: "workout-integrity-test")
        let trackPoints = try swiftDataContext.fetch(trackPointsDescriptor)
        XCTAssertEqual(trackPoints.count, 5)

        let logsDescriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: "workout-integrity-test")
        let logs = try swiftDataContext.fetch(logsDescriptor)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.entityTitle, "Running Podcast")
    }

    func testPreferenceValuesPreserved() async throws {
        let context = try createTestCoreDataStore()

        // Create preferences of different types
        let boolPref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        boolPref.setValue("darkMode", forKey: "name")
        boolPref.setValue(true, forKey: "boolValue")

        let intPref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        intPref.setValue("volume", forKey: "name")
        intPref.setValue(Int16(80), forKey: "intValue")

        let floatPref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        floatPref.setValue("playbackSpeed", forKey: "name")
        floatPref.setValue(Float(1.5), forKey: "floatValue")

        let stringPref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        stringPref.setValue("theme", forKey: "name")
        stringPref.setValue("ocean", forKey: "stringValue")

        let coordPref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
        coordPref.setValue("lastLocation", forKey: "name")
        coordPref.setValue(37.7749, forKey: "latCoord")
        coordPref.setValue(-122.4194, forKey: "longCoord")

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.preferencesMigrated, 5)

        // Verify each preference value
        let swiftDataContext = modelContainer.mainContext

        let darkModeDescriptor = Preference.fetchDescriptor(forName: "darkMode")
        let darkMode = try swiftDataContext.fetch(darkModeDescriptor).first
        XCTAssertEqual(darkMode?.boolValue, true)

        let volumeDescriptor = Preference.fetchDescriptor(forName: "volume")
        let volume = try swiftDataContext.fetch(volumeDescriptor).first
        XCTAssertEqual(volume?.intValue, 80)

        let speedDescriptor = Preference.fetchDescriptor(forName: "playbackSpeed")
        let speed = try swiftDataContext.fetch(speedDescriptor).first
        XCTAssertEqual(speed?.floatValue, 1.5)

        let themeDescriptor = Preference.fetchDescriptor(forName: "theme")
        let theme = try swiftDataContext.fetch(themeDescriptor).first
        XCTAssertEqual(theme?.stringValue, "ocean")

        let locationDescriptor = Preference.fetchDescriptor(forName: "lastLocation")
        let location = try swiftDataContext.fetch(locationDescriptor).first
        XCTAssertNotNil(location?.latCoord)
        XCTAssertNotNil(location?.longCoord)
        if let lat = location?.latCoord, let long = location?.longCoord {
            XCTAssertEqual(lat, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(long, -122.4194, accuracy: 0.0001)
        }
    }

    // MARK: - Data Count Verification

    func testMigrationCountsMatchSource() async throws {
        let context = try createTestCoreDataStore()

        // Create known quantities of each entity type
        let feedCount = 3
        let episodesPerFeed = 4
        let preferenceCount = 5
        let sessionCount = 2
        let trackPointsPerSession = 10
        let logsPerSession = 2

        for i in 0..<feedCount {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")
            feed.setValue("https://feed\(i).com", forKey: "link")

            for j in 0..<episodesPerFeed {
                let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
                episode.setValue("Episode \(j)", forKey: "title")
                episode.setValue("feed\(i)-ep\(j)", forKey: "identifier")
                episode.setValue(feed, forKey: "belongsTo")
            }
        }

        for i in 0..<preferenceCount {
            let pref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
            pref.setValue("pref\(i)", forKey: "name")
            pref.setValue("value\(i)", forKey: "stringValue")
        }

        for i in 0..<sessionCount {
            let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
            session.setValue("workout-\(i)", forKey: "workoutID")
            session.setValue(Date(), forKey: "startTime")

            for j in 0..<trackPointsPerSession {
                let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
                trackPoint.setValue("workout-\(i)", forKey: "workoutID")
                trackPoint.setValue(Date().addingTimeInterval(Double(j) * 10), forKey: "time")
            }

            for j in 0..<logsPerSession {
                let log = NSEntityDescription.insertNewObject(forEntityName: "WorkoutListeningLog", into: context)
                log.setValue("workout-\(i)", forKey: "workoutID")
                log.setValue(Date().addingTimeInterval(Double(j) * 60), forKey: "time")
                log.setValue("Podcast", forKey: "entityTitle")
            }
        }

        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        // Verify counts
        XCTAssertEqual(result.feedsMigrated, feedCount)
        XCTAssertEqual(result.episodesMigrated, feedCount * episodesPerFeed)
        XCTAssertEqual(result.preferencesMigrated, preferenceCount)
        XCTAssertEqual(result.workoutSessionsMigrated, sessionCount)
        XCTAssertEqual(result.trackPointsMigrated, sessionCount * trackPointsPerSession)
        XCTAssertEqual(result.listeningLogsMigrated, sessionCount * logsPerSession)

        // Also verify via direct fetch
        let swiftDataContext = modelContainer.mainContext

        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        XCTAssertEqual(try swiftDataContext.fetchCount(feedDescriptor), feedCount)

        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        XCTAssertEqual(try swiftDataContext.fetchCount(episodeDescriptor), feedCount * episodesPerFeed)
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

        // WorkoutLocation with CLLocation transformable
        let workoutLocation = NSEntityDescription()
        workoutLocation.name = "WorkoutLocation"
        workoutLocation.managedObjectClassName = "NSManagedObject"

        // Register the CLLocation value transformer
        CLLocationValueTransformer.register()

        let locationAttr = NSAttributeDescription()
        locationAttr.name = "location"
        locationAttr.attributeType = .transformableAttributeType
        locationAttr.isOptional = true
        locationAttr.valueTransformerName = CLLocationValueTransformer.transformerName.rawValue
        locationAttr.attributeValueClassName = "CLLocation"

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
