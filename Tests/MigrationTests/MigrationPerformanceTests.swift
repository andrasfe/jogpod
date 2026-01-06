//
//  MigrationPerformanceTests.swift
//  JogPodTests
//
//  Performance tests for Core Data to SwiftData migration.
//  Tests migration of large datasets and measures execution time.
//

import XCTest
import SwiftData
import CoreData
import CoreLocation
@testable import JogPod

// MARK: - Large Dataset Migration Tests

/// Tests for migration performance with large datasets.
@MainActor
final class LargeDatasetMigrationTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var tempDirectory: URL!
    private var legacyStoreURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        modelContainer = try JogPodSchema.makeTestContainer()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LargeDatasetTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        legacyStoreURL = tempDirectory.appendingPathComponent("LargeDataset.sqlite")
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Medium Dataset Tests (100+ records)

    func testMigration100Feeds() async throws {
        let context = try createTestCoreDataStore()
        let feedCount = 100

        for i in 0..<feedCount {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")
            feed.setValue("https://feed\(i).example.com/feed.xml", forKey: "link")
            feed.setValue("Summary for feed \(i) - a podcast about interesting topics", forKey: "summary")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.feedsMigrated, feedCount)

        // Verify all feeds migrated
        let swiftDataContext = modelContainer.mainContext
        let descriptor = FetchDescriptor<PodcastFeed>()
        let count = try swiftDataContext.fetchCount(descriptor)
        XCTAssertEqual(count, feedCount)
    }

    func testMigration500Episodes() async throws {
        let context = try createTestCoreDataStore()
        let episodeCount = 500

        for i in 0..<episodeCount {
            let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
            episode.setValue("Episode \(i)", forKey: "title")
            episode.setValue("guid-\(i)", forKey: "identifier")
            episode.setValue("https://cdn.example.com/episode\(i).mp3", forKey: "enclosureMediaLink")
            episode.setValue(Date().addingTimeInterval(Double(-i * 86400)), forKey: "releaseDate")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.episodesMigrated, episodeCount)
    }

    func testMigration1000TrackPoints() async throws {
        let context = try createTestCoreDataStore()
        let trackPointCount = 1000

        // Create a workout session
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue("large-workout-1", forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        // Create 1000 track points (simulating a ~1 hour workout at 1 point/second)
        let baseTime = Date()
        for i in 0..<trackPointCount {
            let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
            trackPoint.setValue("large-workout-1", forKey: "workoutID")
            trackPoint.setValue(baseTime.addingTimeInterval(Double(i)), forKey: "time")
            trackPoint.setValue(Int16(120 + (i % 60)), forKey: "heartRate")
            trackPoint.setValue(Int16(i * 2), forKey: "steps")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertEqual(result.trackPointsMigrated, trackPointCount)
        XCTAssertEqual(result.workoutSessionsMigrated, 1)
    }

    // MARK: - Large Dataset Tests (1000+ records)

    func testMigrationComplexDataset() async throws {
        let context = try createTestCoreDataStore()

        // Create realistic dataset:
        // - 20 podcast feeds
        // - 50 episodes per feed = 1000 episodes
        // - 30 preferences
        // - 10 workout sessions
        // - 500 track points per workout = 5000 track points
        // - 5 listening logs per workout = 50 logs

        let feedCount = 20
        let episodesPerFeed = 50
        let preferenceCount = 30
        let sessionCount = 10
        let trackPointsPerSession = 500
        let logsPerSession = 5

        // Create feeds with episodes
        for i in 0..<feedCount {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Podcast \(i)", forKey: "title")
            feed.setValue("https://podcast\(i).example.com/feed", forKey: "link")

            for j in 0..<episodesPerFeed {
                let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
                episode.setValue("Podcast \(i) - Episode \(j)", forKey: "title")
                episode.setValue("podcast\(i)-ep\(j)", forKey: "identifier")
                episode.setValue(feed, forKey: "belongsTo")
            }
        }

        // Create preferences
        for i in 0..<preferenceCount {
            let pref = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: context)
            pref.setValue("setting_\(i)", forKey: "name")
            pref.setValue("value_\(i)", forKey: "stringValue")
        }

        // Create workout sessions with track points and logs
        for i in 0..<sessionCount {
            let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
            session.setValue("workout-\(i)", forKey: "workoutID")
            session.setValue(Date().addingTimeInterval(Double(-i * 86400)), forKey: "startTime")

            let baseTime = Date()
            for j in 0..<trackPointsPerSession {
                let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
                trackPoint.setValue("workout-\(i)", forKey: "workoutID")
                trackPoint.setValue(baseTime.addingTimeInterval(Double(j)), forKey: "time")
                trackPoint.setValue(Int16(120 + j % 50), forKey: "heartRate")
            }

            for j in 0..<logsPerSession {
                let log = NSEntityDescription.insertNewObject(forEntityName: "WorkoutListeningLog", into: context)
                log.setValue("workout-\(i)", forKey: "workoutID")
                log.setValue(baseTime.addingTimeInterval(Double(j * 600)), forKey: "time")
                log.setValue("Podcast", forKey: "entityTitle")
                log.setValue("Episode \(j)", forKey: "entryTitle")
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

        // Calculate total
        let expectedTotal = feedCount +
            (feedCount * episodesPerFeed) +
            preferenceCount +
            sessionCount +
            (sessionCount * trackPointsPerSession) +
            (sessionCount * logsPerSession)
        XCTAssertEqual(result.totalRecordsMigrated, expectedTotal)
    }

    // MARK: - Performance Measurement Tests

    func testMigrationPerformanceWith100Feeds() async throws {
        let context = try createTestCoreDataStore()

        for i in 0..<100 {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")
            feed.setValue("https://feed\(i).com", forKey: "link")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let startTime = Date()
        let result = try await manager.performMigration()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(result.feedsMigrated, 100)
        // Migration of 100 feeds should complete in under 5 seconds
        XCTAssertLessThan(duration, 5.0, "Migration took too long: \(duration) seconds")
    }

    func testMigrationPerformanceWith1000Episodes() async throws {
        let context = try createTestCoreDataStore()

        for i in 0..<1000 {
            let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
            episode.setValue("Episode \(i)", forKey: "title")
            episode.setValue("ep-\(i)", forKey: "identifier")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let startTime = Date()
        let result = try await manager.performMigration()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(result.episodesMigrated, 1000)
        // Migration of 1000 episodes should complete in under 10 seconds
        XCTAssertLessThan(duration, 10.0, "Migration took too long: \(duration) seconds")
    }

    func testMigrationPerformanceWith5000TrackPoints() async throws {
        let context = try createTestCoreDataStore()

        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue("perf-workout", forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        let baseTime = Date()
        for i in 0..<5000 {
            let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
            trackPoint.setValue("perf-workout", forKey: "workoutID")
            trackPoint.setValue(baseTime.addingTimeInterval(Double(i)), forKey: "time")
            trackPoint.setValue(Int16(120 + i % 80), forKey: "heartRate")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let startTime = Date()
        let result = try await manager.performMigration()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(result.trackPointsMigrated, 5000)
        // Migration of 5000 track points should complete in under 15 seconds
        XCTAssertLessThan(duration, 15.0, "Migration took too long: \(duration) seconds")
    }

    // MARK: - Progress Tracking Tests

    func testMigrationProgressUpdatesReceived() async throws {
        let context = try createTestCoreDataStore()

        // Create enough data to ensure progress callbacks
        for i in 0..<50 {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")

            for j in 0..<10 {
                let episode = NSEntityDescription.insertNewObject(forEntityName: "RSSEntry", into: context)
                episode.setValue("Episode \(j)", forKey: "title")
                episode.setValue("feed\(i)-ep\(j)", forKey: "identifier")
                episode.setValue(feed, forKey: "belongsTo")
            }
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        var progressUpdates: [DataMigrationManager.MigrationProgress] = []
        var seenPhases: Set<DataMigrationManager.MigrationPhase> = []

        let result = try await manager.performMigration { progress in
            progressUpdates.append(progress)
            seenPhases.insert(progress.phase)
        }

        XCTAssertFalse(progressUpdates.isEmpty, "Should receive progress updates")
        XCTAssertTrue(seenPhases.contains(.validating))
        XCTAssertTrue(seenPhases.contains(.readingLegacyData))
        XCTAssertTrue(seenPhases.contains(.migratingFeeds))
        XCTAssertTrue(seenPhases.contains(.migratingEpisodes))
        XCTAssertTrue(seenPhases.contains(.completed))

        // Verify final progress is complete
        XCTAssertTrue(progressUpdates.last?.isComplete ?? false)

        XCTAssertEqual(result.feedsMigrated, 50)
        XCTAssertEqual(result.episodesMigrated, 500)
    }

    func testMigrationProgressPercentageProgresses() async throws {
        let context = try createTestCoreDataStore()

        for i in 0..<100 {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        var percentages: [Int] = []

        _ = try await manager.performMigration { progress in
            if progress.phase == .migratingFeeds && progress.totalItems > 0 {
                percentages.append(progress.percentComplete)
            }
        }

        // Verify percentages are non-decreasing
        for i in 1..<percentages.count {
            XCTAssertGreaterThanOrEqual(
                percentages[i],
                percentages[i - 1],
                "Progress should not decrease"
            )
        }
    }

    // MARK: - Memory Efficiency Tests

    func testMigrationDoesNotRetainExcessiveMemory() async throws {
        let context = try createTestCoreDataStore()

        // Create a moderate dataset
        for i in 0..<200 {
            let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
            feed.setValue("Feed \(i)", forKey: "title")
        }
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        // Get initial memory footprint (approximation)
        let initialMemory = getMemoryUsage()

        _ = try await manager.performMigration()

        // Check memory hasn't grown excessively
        let finalMemory = getMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory

        // Allow up to 50MB growth for 200 feeds (generous for test)
        let maxAllowedGrowthMB: UInt64 = 50 * 1024 * 1024
        XCTAssertLessThan(
            memoryGrowth,
            maxAllowedGrowthMB,
            "Memory grew by \(memoryGrowth / 1024 / 1024)MB which exceeds limit"
        )
    }

    // MARK: - Duration Reporting Tests

    func testMigrationReportsDuration() async throws {
        let context = try createTestCoreDataStore()

        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
        feed.setValue("Duration Test Feed", forKey: "title")
        try context.save()

        let importer = CoreDataImporter(storeURL: legacyStoreURL)
        let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

        let result = try await manager.performMigration()

        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertFalse(result.formattedDuration.isEmpty)
        XCTAssertLessThan(result.startTime, result.endTime)
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

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}

// MARK: - XCTest Performance Metrics

/// Performance measurement tests using XCTest's measure APIs.
@MainActor
final class MigrationPerformanceMetricsTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerfMetrics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testFeedMigrationPerformance() throws {
        measure {
            let expectation = self.expectation(description: "Migration")

            Task { @MainActor in
                do {
                    let modelContainer = try JogPodSchema.makeTestContainer()
                    let storeURL = self.tempDirectory.appendingPathComponent("perf-\(UUID()).sqlite")

                    let model = MigrationTestHelper.createCoreDataModel()
                    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
                    try coordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: storeURL,
                        options: nil
                    )
                    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                    context.persistentStoreCoordinator = coordinator

                    for i in 0..<50 {
                        let feed = NSEntityDescription.insertNewObject(forEntityName: "RSSEntity", into: context)
                        feed.setValue("Feed \(i)", forKey: "title")
                    }
                    try context.save()

                    let importer = CoreDataImporter(storeURL: storeURL)
                    let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

                    _ = try await manager.performMigration()

                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

    func testTrackPointMigrationPerformance() throws {
        measure {
            let expectation = self.expectation(description: "Migration")

            Task { @MainActor in
                do {
                    let modelContainer = try JogPodSchema.makeTestContainer()
                    let storeURL = self.tempDirectory.appendingPathComponent("perf-tp-\(UUID()).sqlite")

                    let model = MigrationTestHelper.createCoreDataModel()
                    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
                    try coordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: storeURL,
                        options: nil
                    )
                    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                    context.persistentStoreCoordinator = coordinator

                    let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
                    session.setValue("perf-workout", forKey: "workoutID")

                    for i in 0..<500 {
                        let tp = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
                        tp.setValue("perf-workout", forKey: "workoutID")
                        tp.setValue(Date().addingTimeInterval(Double(i)), forKey: "time")
                    }
                    try context.save()

                    let importer = CoreDataImporter(storeURL: storeURL)
                    let manager = DataMigrationManager(modelContainer: modelContainer, importer: importer)

                    _ = try await manager.performMigration()

                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 60.0)
        }
    }
}
