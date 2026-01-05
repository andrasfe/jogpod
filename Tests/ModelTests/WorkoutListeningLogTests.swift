import Testing
import Foundation
import SwiftData
@testable import JogPod

/// Tests for the WorkoutListeningLog SwiftData model.
@Suite("WorkoutListeningLog Model Tests")
struct WorkoutListeningLogTests {

    // MARK: - Setup

    private func makeTestContainer() throws -> ModelContainer {
        try JogPodSchema.makeTestContainer()
    }

    // MARK: - Initialization Tests

    @Test("WorkoutListeningLog initializes with workoutID")
    func testBasicInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let log = WorkoutListeningLog(workoutID: "workout-123")
        context.insert(log)
        try context.save()

        #expect(log.workoutID == "workout-123")
        #expect(log.time == nil)
        #expect(log.entityTitle == nil)
        #expect(log.entryTitle == nil)
        #expect(log.entrySummary == nil)
    }

    @Test("WorkoutListeningLog initializes with all values")
    func testFullInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let log = WorkoutListeningLog(
            workoutID: "workout-123",
            time: now,
            entityTitle: "Test Podcast",
            entryTitle: "Episode 42",
            entrySummary: "An interesting episode"
        )
        context.insert(log)
        try context.save()

        #expect(log.workoutID == "workout-123")
        #expect(log.time == now)
        #expect(log.entityTitle == "Test Podcast")
        #expect(log.entryTitle == "Episode 42")
        #expect(log.entrySummary == "An interesting episode")
    }

    @Test("WorkoutListeningLog initializes from PodcastEpisode")
    func testInitFromEpisode() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "My Favorite Podcast")
        context.insert(feed)

        let episode = PodcastEpisode(title: "Great Episode", feed: feed)
        episode.summary = "Episode summary here"
        context.insert(episode)

        let now = Date()
        let log = WorkoutListeningLog(workoutID: "workout-123", time: now, episode: episode)
        context.insert(log)
        try context.save()

        #expect(log.entityTitle == "My Favorite Podcast")
        #expect(log.entryTitle == "Great Episode")
        #expect(log.entrySummary == "Episode summary here")
    }

    // MARK: - Computed Property Tests

    @Test("displayDescription formats correctly")
    func testDisplayDescription() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let log1 = WorkoutListeningLog(workoutID: "workout-1")
        context.insert(log1)
        #expect(log1.displayDescription == "Unknown Podcast: Unknown Episode")

        let log2 = WorkoutListeningLog(
            workoutID: "workout-2",
            time: Date(),
            entityTitle: "Tech Talk",
            entryTitle: "AI News"
        )
        context.insert(log2)
        #expect(log2.displayDescription == "Tech Talk: AI News")

        let log3 = WorkoutListeningLog(workoutID: "workout-3")
        log3.entityTitle = "Podcast Only"
        context.insert(log3)
        #expect(log3.displayDescription == "Podcast Only: Unknown Episode")
    }

    @Test("hasCompleteInfo checks for both titles")
    func testHasCompleteInfo() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let log1 = WorkoutListeningLog(workoutID: "workout-1")
        context.insert(log1)
        #expect(log1.hasCompleteInfo == false)

        let log2 = WorkoutListeningLog(workoutID: "workout-2")
        log2.entityTitle = "Podcast"
        context.insert(log2)
        #expect(log2.hasCompleteInfo == false)

        let log3 = WorkoutListeningLog(workoutID: "workout-3")
        log3.entryTitle = "Episode"
        context.insert(log3)
        #expect(log3.hasCompleteInfo == false)

        let log4 = WorkoutListeningLog(
            workoutID: "workout-4",
            time: Date(),
            entityTitle: "Podcast",
            entryTitle: "Episode"
        )
        context.insert(log4)
        #expect(log4.hasCompleteInfo == true)
    }

    // MARK: - Fetch Descriptor Tests

    @Test("fetchDescriptor returns chronologically sorted logs")
    func testChronologicalFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let workoutID = "workout-123"

        let log1 = WorkoutListeningLog(
            workoutID: workoutID,
            time: now,
            entityTitle: "Podcast",
            entryTitle: "Third"
        )
        let log2 = WorkoutListeningLog(
            workoutID: workoutID,
            time: now.addingTimeInterval(-60),
            entityTitle: "Podcast",
            entryTitle: "First"
        )
        let log3 = WorkoutListeningLog(
            workoutID: workoutID,
            time: now.addingTimeInterval(-30),
            entityTitle: "Podcast",
            entryTitle: "Second"
        )

        context.insert(log1)
        context.insert(log2)
        context.insert(log3)
        try context.save()

        let descriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: workoutID)
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].entryTitle == "First")
        #expect(results[1].entryTitle == "Second")
        #expect(results[2].entryTitle == "Third")
    }

    @Test("fetchDescriptor filters by workoutID")
    func testFilterByWorkoutID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let log1 = WorkoutListeningLog(
            workoutID: "workout-1",
            time: Date(),
            entityTitle: "P1",
            entryTitle: "E1"
        )
        let log2 = WorkoutListeningLog(
            workoutID: "workout-2",
            time: Date(),
            entityTitle: "P2",
            entryTitle: "E2"
        )
        let log3 = WorkoutListeningLog(
            workoutID: "workout-1",
            time: Date(),
            entityTitle: "P3",
            entryTitle: "E3"
        )

        context.insert(log1)
        context.insert(log2)
        context.insert(log3)
        try context.save()

        let descriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: "workout-1")
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.workoutID == "workout-1" })
    }

    // MARK: - Denormalization Tests

    @Test("Log preserves data independently of episode")
    func testDenormalization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Create feed and episode
        let feed = PodcastFeed(title: "Original Podcast Name")
        context.insert(feed)

        let episode = PodcastEpisode(title: "Original Episode Name", feed: feed)
        episode.summary = "Original summary"
        context.insert(episode)

        // Create log from episode
        let log = WorkoutListeningLog(workoutID: "workout-123", time: Date(), episode: episode)
        context.insert(log)
        try context.save()

        // Modify the original episode
        episode.title = "Changed Episode Name"
        feed.title = "Changed Podcast Name"
        try context.save()

        // The log should still have the original values (denormalized)
        #expect(log.entityTitle == "Original Podcast Name")
        #expect(log.entryTitle == "Original Episode Name")
        #expect(log.entrySummary == "Original summary")
    }

    // MARK: - All Attributes Test

    @Test("All WorkoutListeningLog attributes are preserved")
    func testAllAttributes() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let log = WorkoutListeningLog(workoutID: "test-workout", time: now)
        log.entityTitle = "Test Podcast Feed"
        log.entryTitle = "Test Episode Title"
        log.entrySummary = "This is the episode summary with details."

        context.insert(log)
        try context.save()

        let descriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: "test-workout")
        let fetched = try context.fetch(descriptor).first

        #expect(fetched?.workoutID == "test-workout")
        #expect(fetched?.time == now)
        #expect(fetched?.entityTitle == "Test Podcast Feed")
        #expect(fetched?.entryTitle == "Test Episode Title")
        #expect(fetched?.entrySummary == "This is the episode summary with details.")
    }
}
