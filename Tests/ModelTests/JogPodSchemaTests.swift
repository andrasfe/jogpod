import Testing
import Foundation
import SwiftData
@testable import JogPod

/// Tests for the JogPodSchema configuration.
@Suite("JogPod Schema Tests")
@MainActor
struct JogPodSchemaTests {

    // MARK: - Container Creation Tests

    @Test("makeTestContainer creates in-memory container")
    func testTestContainerCreation() throws {
        let container = try JogPodSchema.makeTestContainer()

        // Should be able to create a context
        let context = container.mainContext
        #expect(context != nil)
    }

    @Test("makeContainer creates persistent container")
    func testPersistentContainerCreation() throws {
        let container = try JogPodSchema.makeContainer(inMemory: true)

        let context = container.mainContext
        #expect(context != nil)
    }

    // MARK: - Schema Completeness Tests

    @Test("Schema includes all model types")
    func testSchemaCompleteness() {
        let models = JogPodSchema.models

        #expect(models.count == 6)

        // Verify all expected types are present
        let typeNames = models.map { String(describing: $0) }
        #expect(typeNames.contains("PodcastFeed"))
        #expect(typeNames.contains("PodcastEpisode"))
        #expect(typeNames.contains("Preference"))
        #expect(typeNames.contains("WorkoutSession"))
        #expect(typeNames.contains("WorkoutTrackPoint"))
        #expect(typeNames.contains("WorkoutListeningLog"))
    }

    // MARK: - Migration Mapping Tests

    @Test("Legacy entity name mappings are complete")
    func testLegacyEntityMappings() {
        let mappings = JogPodSchema.legacyEntityNameMappings

        #expect(mappings.count == 6)
        #expect(mappings["RSSEntity"] == PodcastFeed.self)
        #expect(mappings["RSSEntry"] == PodcastEpisode.self)
        #expect(mappings["Preference"] == Preference.self)
        #expect(mappings["WorkoutHistory"] == WorkoutSession.self)
        #expect(mappings["WorkoutLocation"] == WorkoutTrackPoint.self)
        #expect(mappings["WorkoutListeningLog"] == WorkoutListeningLog.self)
    }

    @Test("Legacy attribute name mappings are defined")
    func testLegacyAttributeMappings() {
        let mappings = JogPodSchema.legacyAttributeNameMappings

        // RSSEntry mappings
        let entryMappings = mappings["RSSEntry"]
        #expect(entryMappings?["currentInPlayer"] == "isCurrentInPlayer")
        #expect(entryMappings?["belongsTo"] == "feed")

        // RSSEntity mappings
        let entityMappings = mappings["RSSEntity"]
        #expect(entityMappings?["contains"] == "episodes")
    }

    // MARK: - Integration Tests

    @Test("All models can be inserted and fetched together")
    func testFullSchemaIntegration() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        // Create a podcast feed with episode
        let feed = PodcastFeed(title: "Integration Test Podcast")
        context.insert(feed)

        let episode = PodcastEpisode(title: "Test Episode", feed: feed)
        episode.enclosureMediaLink = "https://example.com/audio.mp3"
        context.insert(episode)

        // Create a preference
        let pref = Preference(name: "testPref", stringValue: "testValue")
        context.insert(pref)

        // Create a workout session with track points and listening log
        let workoutID = "integration-test-workout"
        let session = WorkoutSession(workoutID: workoutID, startTime: Date())
        session.temperatureInCelsius = 20.0
        context.insert(session)

        let trackPoint = WorkoutTrackPoint(workoutID: workoutID, time: Date())
        trackPoint.latitude = 47.4979
        trackPoint.longitude = 19.0402
        trackPoint.heartRate = 145
        context.insert(trackPoint)

        let listeningLog = WorkoutListeningLog(workoutID: workoutID, time: Date(), episode: episode)
        context.insert(listeningLog)

        // Save all
        try context.save()

        // Verify all can be fetched
        let feeds = try context.fetch(FetchDescriptor<PodcastFeed>())
        #expect(feeds.count == 1)

        let episodes = try context.fetch(FetchDescriptor<PodcastEpisode>())
        #expect(episodes.count == 1)

        let prefs = try context.fetch(FetchDescriptor<Preference>())
        #expect(prefs.count == 1)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)

        let trackPoints = try context.fetch(FetchDescriptor<WorkoutTrackPoint>())
        #expect(trackPoints.count == 1)

        let logs = try context.fetch(FetchDescriptor<WorkoutListeningLog>())
        #expect(logs.count == 1)

        // Verify relationships
        #expect(feeds.first?.episodes.count == 1)
        #expect(episodes.first?.feed === feeds.first)
    }

    @Test("Cascade delete works correctly for podcast hierarchy")
    func testCascadeDeleteIntegration() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        // Create feed with multiple episodes
        let feed = PodcastFeed(title: "Cascade Test Podcast")
        context.insert(feed)

        for i in 1...5 {
            let episode = PodcastEpisode(title: "Episode \(i)", feed: feed)
            context.insert(episode)
        }
        try context.save()

        // Verify setup
        var episodes = try context.fetch(FetchDescriptor<PodcastEpisode>())
        #expect(episodes.count == 5)

        // Delete feed
        context.delete(feed)
        try context.save()

        // Verify cascade
        let feeds = try context.fetch(FetchDescriptor<PodcastFeed>())
        episodes = try context.fetch(FetchDescriptor<PodcastEpisode>())

        #expect(feeds.isEmpty)
        #expect(episodes.isEmpty)
    }

    @Test("Workout data can be queried by workoutID")
    func testWorkoutDataQuery() throws {
        let container = try JogPodSchema.makeTestContainer()
        let context = container.mainContext

        let workoutID = "query-test-workout"
        let now = Date()

        // Create session
        let session = WorkoutSession(workoutID: workoutID, startTime: now)
        context.insert(session)

        // Create multiple track points
        for i in 0..<10 {
            let point = WorkoutTrackPoint(
                workoutID: workoutID,
                time: now.addingTimeInterval(Double(i) * 10)
            )
            point.heartRate = Int16(140 + i)
            context.insert(point)
        }

        // Create listening logs
        for i in 0..<3 {
            let log = WorkoutListeningLog(
                workoutID: workoutID,
                time: now.addingTimeInterval(Double(i) * 60),
                entityTitle: "Podcast \(i)",
                entryTitle: "Episode \(i)"
            )
            context.insert(log)
        }

        try context.save()

        // Query all workout data
        let sessionDescriptor = WorkoutSession.fetchDescriptor(forWorkoutID: workoutID)
        let pointsDescriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: workoutID)
        let logsDescriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: workoutID)

        let fetchedSession = try context.fetch(sessionDescriptor)
        let fetchedPoints = try context.fetch(pointsDescriptor)
        let fetchedLogs = try context.fetch(logsDescriptor)

        #expect(fetchedSession.count == 1)
        #expect(fetchedPoints.count == 10)
        #expect(fetchedLogs.count == 3)

        // Verify chronological order
        for i in 1..<fetchedPoints.count {
            let prev = fetchedPoints[i - 1].time ?? .distantPast
            let curr = fetchedPoints[i].time ?? .distantPast
            #expect(prev <= curr)
        }
    }
}
