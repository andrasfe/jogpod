//
//  DataPersistenceEquivalenceTests.swift
//  JogPod Tests
//
//  Equivalence tests for data persistence functionality.
//  Verifies the Swift/SwiftData implementation behaves equivalently to legacy Core Data code.
//
//  Reference: EQUIVALENCE_TESTING_STRATEGY.md Section 3.6
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - Data Persistence Equivalence Tests

/// Tests data persistence equivalence with legacy Core Data implementation.
///
/// These tests verify behavioral equivalence according to:
/// - Golden Dataset Oracles (GD-001 through GD-005)
/// - Invariant Oracles (INV-001 through INV-007)
/// - Specification Oracles (SO-002)
@Suite("Data Persistence Equivalence")
struct DataPersistenceEquivalenceTests {

    // MARK: - DP-ENT-001: WorkoutSession Creation (GD-001)

    @Test("DP-ENT-001: WorkoutSession creation assigns UUID and startTime")
    func workoutSessionCreation() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let startTime = Date()

        let sessionID = try await persistence.createWorkoutSession(
            workoutID: nil, // Let it auto-generate
            startTime: startTime
        )

        let sessions = try await persistence.fetchAllWorkoutSessions()
        #expect(sessions.count == 1)

        let session = sessions.first!
        #expect(session.persistentModelID == sessionID)

        // Verify UUID format (INV-001)
        let uuid = UUID(uuidString: session.workoutID)
        #expect(uuid != nil, "workoutID should be valid UUID format")

        // Verify startTime is set
        #expect(session.startTime != nil)
        #expect(abs(session.startTime!.timeIntervalSince(startTime)) < 1.0)
    }

    // MARK: - DP-ENT-002: WorkoutTrackPoint Creation (GD-002)

    @Test("DP-ENT-002: WorkoutTrackPoint linked to session by workoutID")
    func trackPointLinkedToSession() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = UUID().uuidString

        // Create track point
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        _ = try await persistence.createTrackPoint(
            workoutID: workoutID,
            time: Date(),
            location: location,
            heartRate: 120,
            steps: 500
        )

        // Fetch by workoutID
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)
        #expect(trackPoints.count == 1)

        let trackPoint = trackPoints.first!
        #expect(trackPoint.workoutID == workoutID)
        #expect(trackPoint.latitude == location.coordinate.latitude)
        #expect(trackPoint.longitude == location.coordinate.longitude)
        #expect(trackPoint.heartRate == 120)
        #expect(trackPoint.steps == 500)
    }

    // MARK: - DP-ENT-003: WorkoutListeningLog Creation

    @Test("DP-ENT-003: WorkoutListeningLog linked by workoutID")
    func listeningLogLinkedToWorkout() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = UUID().uuidString

        _ = try await persistence.createListeningLog(
            workoutID: workoutID,
            time: Date(),
            entityTitle: "Running Podcast",
            entryTitle: "Episode 1",
            entrySummary: "A great episode"
        )

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 1)

        let log = logs.first!
        #expect(log.workoutID == workoutID)
        #expect(log.entityTitle == "Running Podcast")
        #expect(log.entryTitle == "Episode 1")
        #expect(log.entrySummary == "A great episode")
    }

    // MARK: - DP-ENT-004: PodcastFeed Creation (GD-003)

    @Test("DP-ENT-004: PodcastFeed with unique link")
    func podcastFeedUniqueLink() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let link = "https://example.com/feed.xml"

        _ = try await persistence.createPodcastFeed(
            title: "Test Podcast",
            link: link,
            summary: "A test podcast",
            imageUrl: "https://example.com/art.jpg"
        )

        // Fetch by link
        let feed = try await persistence.fetchPodcastFeed(byLink: link)
        #expect(feed != nil)
        #expect(feed?.title == "Test Podcast")
        #expect(feed?.link == link)
    }

    // MARK: - DP-ENT-005: PodcastEpisode Creation (GD-003)

    @Test("DP-ENT-005: PodcastEpisode linked to feed with index")
    func podcastEpisodeLinkedToFeed() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let feedID = try await persistence.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        _ = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/ep1.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        #expect(episodes.count == 1)

        let episode = episodes.first!
        #expect(episode.title == "Episode 1")
        #expect(episode.feed != nil)
        #expect(episode.feed?.title == "Test Podcast")
        #expect(episode.index >= 0)
    }

    // MARK: - DP-ENT-006: Preference Creation (INV-005)

    @Test("DP-ENT-006: Preference name is unique")
    func preferenceNameUnique() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        // Save initial preference
        try await persistence.savePreference(name: "testKey", value: 100)

        // Save again with same name - should update
        try await persistence.savePreference(name: "testKey", value: 200)

        // Fetch all preferences
        let prefs = try await persistence.fetchAllPreferences()
        let testPrefs = prefs.filter { $0.name == "testKey" }

        #expect(testPrefs.count == 1, "Only one preference with same name should exist")

        let value: Int? = try await persistence.fetchPreference(name: "testKey", as: Int.self)
        #expect(value == 200)
    }
}

// MARK: - Preference Default Tests (SO-002)

@Suite("Preference Defaults Equivalence")
struct PreferenceDefaultsEquivalenceTests {

    // MARK: - DP-PRF-001: Missing Bool Preference Returns Default

    @Test("DP-PRF-001: Missing bool preference returns nil")
    func missingBoolPreference() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let value: Bool? = try await persistence.fetchPreference(
            name: "nonExistentBoolKey",
            as: Bool.self
        )

        #expect(value == nil)
    }

    // MARK: - DP-PRF-002: Missing Int Preference Returns Default

    @Test("DP-PRF-002: Missing int preference returns nil")
    func missingIntPreference() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let value: Int? = try await persistence.fetchPreference(
            name: "nonExistentIntKey",
            as: Int.self
        )

        #expect(value == nil)
    }

    // MARK: - DP-PRF-003: Missing String Preference Returns Default

    @Test("DP-PRF-003: Missing string preference returns nil")
    func missingStringPreference() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let value: String? = try await persistence.fetchPreference(
            name: "nonExistentStringKey",
            as: String.self
        )

        #expect(value == nil)
    }

    // MARK: - Preference Type Storage

    @Test("Bool preference stored and retrieved correctly")
    func boolPreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        try await persistence.savePreference(name: "boolKey", value: true)

        let value: Bool? = try await persistence.fetchPreference(name: "boolKey", as: Bool.self)
        #expect(value == true)
    }

    @Test("Int preference stored and retrieved correctly")
    func intPreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        try await persistence.savePreference(name: "intKey", value: 42)

        let value: Int? = try await persistence.fetchPreference(name: "intKey", as: Int.self)
        #expect(value == 42)
    }

    @Test("String preference stored and retrieved correctly")
    func stringPreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        try await persistence.savePreference(name: "stringKey", value: "Hello World")

        let value: String? = try await persistence.fetchPreference(name: "stringKey", as: String.self)
        #expect(value == "Hello World")
    }

    @Test("Float preference stored and retrieved correctly")
    func floatPreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        try await persistence.savePreference(name: "floatKey", value: Float(3.14))

        let value: Float? = try await persistence.fetchPreference(name: "floatKey", as: Float.self)
        #expect(value != nil)
        #expect(abs(value! - 3.14) < 0.001)
    }

    @Test("Date preference stored and retrieved correctly")
    func datePreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let testDate = Date()

        try await persistence.savePreference(name: "dateKey", value: testDate)

        let value: Date? = try await persistence.fetchPreference(name: "dateKey", as: Date.self)
        #expect(value != nil)
        #expect(abs(value!.timeIntervalSince(testDate)) < 1.0)
    }
}

// MARK: - Entity Invariant Tests

@Suite("Entity Invariants")
struct EntityInvariantTests {

    // MARK: - INV-001: WorkoutID UUID Format

    @Test("INV-001: WorkoutSession.workoutID is UUID format")
    func workoutIDUUIDFormat() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createWorkoutSession(startTime: Date())

        let sessions = try await persistence.fetchAllWorkoutSessions()
        for session in sessions {
            let uuid = UUID(uuidString: session.workoutID)
            #expect(uuid != nil, "workoutID '\(session.workoutID)' should be valid UUID")
        }
    }

    // MARK: - INV-002: Time Chronologically Ordered

    @Test("INV-002: WorkoutTrackPoint.time is chronologically ordered")
    func trackPointTimeOrdered() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = UUID().uuidString

        let times = [
            Date().addingTimeInterval(-300),
            Date().addingTimeInterval(-200),
            Date().addingTimeInterval(-100),
        ]

        // Insert in random order
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: times[1])
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: times[2])
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: times[0])

        // Should be returned in chronological order
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

        for i in 0..<(trackPoints.count - 1) {
            let current = trackPoints[i].time ?? Date.distantPast
            let next = trackPoints[i + 1].time ?? Date.distantPast
            #expect(current <= next, "Track points should be chronologically ordered")
        }
    }

    // MARK: - INV-003: Heart Rate in Range

    @Test("INV-003: Heart rate values in range 0-255")
    func heartRateInRange() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = UUID().uuidString

        // Int16 can store 0-255 easily
        let heartRates: [Int16] = [60, 120, 180, 200, 0]

        for hr in heartRates {
            _ = try await persistence.createTrackPoint(
                workoutID: workoutID,
                time: Date(),
                location: nil,
                heartRate: hr,
                steps: nil
            )
        }

        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

        for point in trackPoints {
            if let hr = point.heartRate {
                #expect(hr >= 0 && hr <= 255, "Heart rate \(hr) should be in range 0-255")
            }
        }
    }

    // MARK: - INV-004: At Most One Current Episode

    @Test("INV-004: At most one episode is current in player")
    func atMostOneCurrentEpisode() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        // Create multiple episodes
        for i in 1...5 {
            _ = try await persistence.createPodcastEpisode(
                title: "Episode \(i)",
                identifier: "ep-\(i)",
                enclosureMediaLink: nil,
                releaseDate: nil,
                feedIdentifier: nil
            )
        }

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)

        // Set each episode as current, one at a time
        for episode in episodes {
            try await persistence.setCurrentEpisode(episode.persistentModelID)

            let allEpisodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
            let currentCount = allEpisodes.filter { $0.isCurrentInPlayer }.count

            #expect(currentCount <= 1, "At most one episode should be current")
        }
    }

    // MARK: - INV-005: Preference Name is Unique

    @Test("INV-005: Preference name is unique (constraint)")
    func preferenceNameConstraint() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        try await persistence.savePreference(name: "uniqueKey", value: "first")
        try await persistence.savePreference(name: "uniqueKey", value: "second")

        let prefs = try await persistence.fetchAllPreferences()
        let matchingPrefs = prefs.filter { $0.name == "uniqueKey" }

        #expect(matchingPrefs.count == 1)
    }
}

// MARK: - Relationship Integrity Tests

@Suite("Relationship Integrity")
struct RelationshipIntegrityTests {

    // MARK: - DP-REL-001: Episode.feed Relationship

    @Test("DP-REL-001: PodcastEpisode.feed points to valid PodcastFeed")
    func episodeFeedRelationship() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let feedID = try await persistence.createPodcastFeed(
            title: "Parent Feed",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        _ = try await persistence.createPodcastEpisode(
            title: "Child Episode",
            identifier: "ep-001",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        #expect(episode.feed != nil)
        #expect(episode.feed?.title == "Parent Feed")
    }

    // MARK: - DP-REL-002: Feed.episodes Inverse

    @Test("DP-REL-002: PodcastFeed.episodes contains all related episodes")
    func feedEpisodesInverse() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let feedID = try await persistence.createPodcastFeed(
            title: "Parent Feed",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        for i in 1...3 {
            _ = try await persistence.createPodcastEpisode(
                title: "Episode \(i)",
                identifier: "ep-\(i)",
                enclosureMediaLink: nil,
                releaseDate: nil,
                feedIdentifier: feedID
            )
        }

        let feed = try await persistence.fetchPodcastFeed(byLink: "https://example.com/feed.xml")
        #expect(feed != nil)
        #expect(feed?.episodes.count == 3)
    }

    // MARK: - DP-REL-003: Orphan Entry Handling

    @Test("DP-REL-003: Episode without feed is handled gracefully")
    func orphanEpisodeHandling() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createPodcastEpisode(
            title: "Orphan Episode",
            identifier: "ep-orphan",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil  // No parent feed
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        #expect(episode.feed == nil)
        #expect(episode.title == "Orphan Episode")
    }
}

// MARK: - Batch Operation Tests

@Suite("Batch Operations")
struct BatchOperationTests {

    @Test("Save commits pending changes")
    func saveCommitsPendingChanges() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = UUID().uuidString

        // Create multiple track points
        for i in 0..<25 {
            _ = try await persistence.createTrackPoint(
                workoutID: workoutID,
                time: Date().addingTimeInterval(TimeInterval(i * 10)),
                location: nil,
                heartRate: Int16(100 + i),
                steps: nil
            )
        }

        // Explicit save
        try await persistence.save()

        // Verify all track points were saved
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)
        #expect(trackPoints.count == 25)
    }

    @Test("deleteAll removes all entities of type")
    func deleteAllRemovesEntities() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        // Create some preferences
        for i in 1...5 {
            try await persistence.savePreference(name: "key\(i)", value: i)
        }

        var prefs = try await persistence.fetchAllPreferences()
        #expect(prefs.count == 5)

        // Delete all preferences
        try await persistence.deleteAll(ofType: Preference.self)

        prefs = try await persistence.fetchAllPreferences()
        #expect(prefs.count == 0)
    }
}

// MARK: - Schema Compatibility Tests

@Suite("Schema Compatibility")
struct SchemaCompatibilityTests {

    @Test("Legacy entity name mappings are defined")
    func legacyEntityNameMappings() {
        let mappings = JogPodSchema.legacyEntityNameMappings

        // Verify all legacy entity names are mapped
        #expect(mappings["RSSEntity"] != nil)
        #expect(mappings["RSSEntry"] != nil)
        #expect(mappings["Preference"] != nil)
        #expect(mappings["WorkoutHistory"] != nil)
        #expect(mappings["WorkoutLocation"] != nil)
        #expect(mappings["WorkoutListeningLog"] != nil)
    }

    @Test("Legacy attribute name mappings are defined")
    func legacyAttributeNameMappings() {
        let mappings = JogPodSchema.legacyAttributeNameMappings

        // RSSEntry mappings
        let rssEntryMappings = mappings["RSSEntry"]
        #expect(rssEntryMappings?["currentInPlayer"] == "isCurrentInPlayer")
        #expect(rssEntryMappings?["belongsTo"] == "feed")

        // RSSEntity mappings
        let rssEntityMappings = mappings["RSSEntity"]
        #expect(rssEntityMappings?["contains"] == "episodes")
    }

    @Test("All model types are in schema")
    func allModelsInSchema() {
        let models = JogPodSchema.models

        #expect(models.contains { $0 == PodcastFeed.self })
        #expect(models.contains { $0 == PodcastEpisode.self })
        #expect(models.contains { $0 == Preference.self })
        #expect(models.contains { $0 == WorkoutSession.self })
        #expect(models.contains { $0 == WorkoutTrackPoint.self })
        #expect(models.contains { $0 == WorkoutListeningLog.self })
    }
}

// MARK: - Coordinate Preference Tests

@Suite("Coordinate Preference")
struct CoordinatePreferenceTests {

    @Test("Coordinate preference stores lat/long correctly")
    func coordinatePreferenceStorage() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        try await persistence.saveCoordinatePreference(name: "lastLocation", coordinate: coordinate)

        let retrieved = try await persistence.fetchCoordinatePreference(name: "lastLocation")

        #expect(retrieved != nil)
        #expect(abs(retrieved!.latitude - coordinate.latitude) < 0.0001)
        #expect(abs(retrieved!.longitude - coordinate.longitude) < 0.0001)
    }

    @Test("Missing coordinate preference returns nil")
    func missingCoordinatePreference() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let retrieved = try await persistence.fetchCoordinatePreference(name: "nonExistent")

        #expect(retrieved == nil)
    }
}
