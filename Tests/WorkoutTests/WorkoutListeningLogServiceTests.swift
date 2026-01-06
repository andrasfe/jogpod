//
//  WorkoutListeningLogServiceTests.swift
//  JogPod Tests
//
//  Tests for WorkoutListeningLogService.
//

import Testing
import Foundation
import SwiftData
@testable import JogPod

// MARK: - WorkoutListeningLogService Tests

@Suite("WorkoutListeningLogService")
struct WorkoutListeningLogServiceTests {

    // MARK: - Mock Workout Service

    actor MockWorkoutServiceForListening: WorkoutServiceProtocol {
        var mockIsInProgress: Bool = false
        var mockWorkoutID: String?
        var mockState: WorkoutState = .idle

        var state: WorkoutState {
            mockState
        }

        var activeWorkoutID: String? {
            mockWorkoutID
        }

        var isWorkoutInProgress: Bool {
            mockIsInProgress
        }

        func startWorkout() async throws -> String {
            let id = UUID().uuidString
            mockWorkoutID = id
            mockState = .active
            mockIsInProgress = true
            return id
        }

        func stopWorkout() async throws {
            mockWorkoutID = nil
            mockState = .idle
            mockIsInProgress = false
        }

        func requestAuthorization() async throws {}

        func currentMetrics() async -> WorkoutSnapshot? {
            nil
        }

        // Test configuration methods
        func setWorkoutInProgress(_ inProgress: Bool, workoutID: String?) async {
            mockIsInProgress = inProgress
            mockWorkoutID = workoutID
            mockState = inProgress ? .active : .idle
        }
    }

    // MARK: - Helper Methods

    private func makePersistence() throws -> PersistenceManager {
        try PersistenceManager.makeForTesting()
    }

    private func makeWorkoutService() -> MockWorkoutServiceForListening {
        MockWorkoutServiceForListening()
    }

    private func makeService(
        persistence: PersistenceManaging? = nil,
        workoutService: WorkoutServiceProtocol? = nil
    ) async throws -> (WorkoutListeningLogService, PersistenceManaging, MockWorkoutServiceForListening) {
        let p = try persistence.map { $0 as! PersistenceManager } ?? makePersistence()
        let w = (workoutService as? MockWorkoutServiceForListening) ?? makeWorkoutService()

        let service = WorkoutListeningLogService(
            persistence: p,
            workoutService: w
        )

        return (service, p, w)
    }

    // MARK: - Logging When No Workout

    @Test("does not log when no workout in progress")
    func doesNotLogWhenNoWorkout() async throws {
        let (service, persistence, _) = try await makeService()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: "Summary",
            isPlaying: true
        )

        // Should not create any logs
        let logs = try await persistence.fetchListeningLogs(forWorkoutID: "any-workout")
        #expect(logs.isEmpty)
    }

    // MARK: - Logging When Not Playing

    @Test("does not log when not playing")
    func doesNotLogWhenNotPlaying() async throws {
        let (service, persistence, workoutService) = try await makeService()

        // Start a workout
        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: "Summary",
            isPlaying: false  // Not playing
        )

        // Should not create any logs
        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.isEmpty)
    }

    // MARK: - Successful Logging

    @Test("logs event when workout in progress and playing")
    func logsEventWhenWorkoutInProgressAndPlaying() async throws {
        let (service, persistence, workoutService) = try await makeService()

        // Start a workout
        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: "Great episode",
            isPlaying: true
        )

        // Should create a log
        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 1)
        #expect(logs.first?.entryTitle == "Test Episode")
        #expect(logs.first?.entityTitle == "Test Podcast")
        #expect(logs.first?.entrySummary == "Great episode")
    }

    @Test("logs event using PlayableItem")
    func logsEventUsingPlayableItem() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        // Create a mock PlayableItem
        let item = PlayableItem(
            id: "ep-123",
            episodeID: PersistentIdentifier.placeholder, // Would be real in production
            title: "Playable Episode",
            podcastTitle: "Playable Podcast",
            mediaURL: URL(string: "https://example.com/episode.mp3")!,
            isCached: false,
            artworkURL: nil,
            savedPosition: 0
        )

        await service.logListeningEvent(item: item, isPlaying: true)

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 1)
        #expect(logs.first?.entryTitle == "Playable Episode")
        #expect(logs.first?.entityTitle == "Playable Podcast")
    }

    // MARK: - Deduplication

    @Test("does not create duplicate logs for same episode in same workout")
    func noDuplicateLogsForSameEpisode() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        // Log the same episode multiple times
        for _ in 0..<5 {
            await service.logListeningEvent(
                episodeID: "ep-1",
                episodeTitle: "Test Episode",
                podcastTitle: "Test Podcast",
                episodeSummary: nil,
                isPlaying: true
            )
        }

        // Should only have one log
        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 1)
    }

    @Test("logs different episodes separately")
    func logsDifferentEpisodesSeparately() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Episode 1",
            podcastTitle: "Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        await service.logListeningEvent(
            episodeID: "ep-2",
            episodeTitle: "Episode 2",
            podcastTitle: "Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        await service.logListeningEvent(
            episodeID: "ep-3",
            episodeTitle: "Episode 3",
            podcastTitle: "Different Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 3)
    }

    // MARK: - Reset Tracking State

    @Test("reset allows re-logging same episode after workout ends")
    func resetAllowsReloggingSameEpisode() async throws {
        let (service, persistence, workoutService) = try await makeService()

        // First workout
        let workoutID1 = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        try await workoutService.stopWorkout()
        await service.resetTrackingState()

        // Second workout
        let workoutID2 = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",  // Same episode
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        let logs1 = try await persistence.fetchListeningLogs(forWorkoutID: workoutID1)
        let logs2 = try await persistence.fetchListeningLogs(forWorkoutID: workoutID2)

        #expect(logs1.count == 1)
        #expect(logs2.count == 1)
    }

    // MARK: - Missing Episode ID

    @Test("does not log when episode ID is nil")
    func doesNotLogWhenEpisodeIDNil() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: nil,
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.isEmpty)
    }

    @Test("does not log when episode ID is empty")
    func doesNotLogWhenEpisodeIDEmpty() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "",
            episodeTitle: "Test Episode",
            podcastTitle: "Test Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.isEmpty)
    }

    // MARK: - Fetch Logs

    @Test("fetchListeningLogs returns logs for workout")
    func fetchListeningLogsReturnsLogs() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Episode 1",
            podcastTitle: "Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        await service.logListeningEvent(
            episodeID: "ep-2",
            episodeTitle: "Episode 2",
            podcastTitle: "Podcast",
            episodeSummary: nil,
            isPlaying: true
        )

        let logs = try await service.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 2)
    }

    // MARK: - Fetch Summary

    @Test("fetchListeningSummary returns correct summary")
    func fetchListeningSummaryReturnsCorrectSummary() async throws {
        let (service, _, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        await service.logListeningEvent(
            episodeID: "ep-1",
            episodeTitle: "Episode 1",
            podcastTitle: "Podcast A",
            episodeSummary: nil,
            isPlaying: true
        )

        await service.logListeningEvent(
            episodeID: "ep-2",
            episodeTitle: "Episode 2",
            podcastTitle: "Podcast A",
            episodeSummary: nil,
            isPlaying: true
        )

        await service.logListeningEvent(
            episodeID: "ep-3",
            episodeTitle: "Episode 3",
            podcastTitle: "Podcast B",
            episodeSummary: nil,
            isPlaying: true
        )

        let summary = try await service.fetchListeningSummary(forWorkoutID: workoutID)

        #expect(summary.workoutID == workoutID)
        #expect(summary.episodeCount == 3)
        #expect(summary.podcastCount == 2)
    }

    // MARK: - Summary With Empty Logs

    @Test("summary handles no listening logs")
    func summaryHandlesNoLogs() async throws {
        let (service, _, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        let summary = try await service.fetchListeningSummary(forWorkoutID: workoutID)

        #expect(summary.episodeCount == 0)
        #expect(summary.podcastCount == 0)
        #expect(summary.briefSummary == "No podcasts played during this workout")
    }

    // MARK: - Thread Safety

    @Test("concurrent logging is safe")
    func concurrentLoggingIsSafe() async throws {
        let (service, persistence, workoutService) = try await makeService()

        let workoutID = try await workoutService.startWorkout()

        // Log from multiple concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await service.logListeningEvent(
                        episodeID: "ep-\(i)",
                        episodeTitle: "Episode \(i)",
                        podcastTitle: "Podcast",
                        episodeSummary: nil,
                        isPlaying: true
                    )
                }
            }
        }

        let logs = try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
        #expect(logs.count == 10)
    }
}

// MARK: - WorkoutListeningSummary Tests

@Suite("WorkoutListeningSummary")
struct WorkoutListeningSummaryTests {

    @Test("deduplicates episodes with same title")
    func deduplicatesEpisodes() {
        let logs = [
            makeLog(entityTitle: "Podcast", entryTitle: "Episode 1"),
            makeLog(entityTitle: "Podcast", entryTitle: "Episode 1"), // Duplicate
            makeLog(entityTitle: "Podcast", entryTitle: "Episode 2"),
        ]

        let summary = WorkoutListeningSummary(workoutID: "test", logs: logs)

        #expect(summary.episodeCount == 2)
    }

    @Test("counts unique podcasts correctly")
    func countsUniquePodcasts() {
        let logs = [
            makeLog(entityTitle: "Podcast A", entryTitle: "Episode 1"),
            makeLog(entityTitle: "Podcast A", entryTitle: "Episode 2"),
            makeLog(entityTitle: "Podcast B", entryTitle: "Episode 1"),
            makeLog(entityTitle: "Podcast C", entryTitle: "Episode 1"),
        ]

        let summary = WorkoutListeningSummary(workoutID: "test", logs: logs)

        #expect(summary.podcastCount == 3)
    }

    @Test("briefSummary singular forms")
    func briefSummarySingular() {
        let logs = [
            makeLog(entityTitle: "Podcast", entryTitle: "Episode 1"),
        ]

        let summary = WorkoutListeningSummary(workoutID: "test", logs: logs)

        #expect(summary.briefSummary.contains("1 episode"))
        #expect(summary.briefSummary.contains("1 podcast"))
    }

    @Test("briefSummary plural forms")
    func briefSummaryPlural() {
        let logs = [
            makeLog(entityTitle: "Podcast A", entryTitle: "Episode 1"),
            makeLog(entityTitle: "Podcast A", entryTitle: "Episode 2"),
            makeLog(entityTitle: "Podcast B", entryTitle: "Episode 1"),
        ]

        let summary = WorkoutListeningSummary(workoutID: "test", logs: logs)

        #expect(summary.briefSummary.contains("3 episodes"))
        #expect(summary.briefSummary.contains("2 podcasts"))
    }

    // Helper to create WorkoutListeningLog for tests
    private func makeLog(entityTitle: String?, entryTitle: String?) -> WorkoutListeningLog {
        WorkoutListeningLog(
            workoutID: "test",
            time: Date(),
            entityTitle: entityTitle,
            entryTitle: entryTitle
        )
    }
}

// MARK: - ListenedEpisode Tests

@Suite("ListenedEpisode")
struct ListenedEpisodeTests {

    @Test("displayDescription formats correctly")
    func displayDescriptionFormats() {
        let episode = ListenedEpisode(
            podcastTitle: "Running Podcast",
            episodeTitle: "Episode 42",
            startTime: Date()
        )

        #expect(episode.displayDescription == "Running Podcast: Episode 42")
    }

    @Test("displayDescription handles nil values")
    func displayDescriptionHandlesNil() {
        let episode = ListenedEpisode(
            podcastTitle: nil,
            episodeTitle: nil,
            startTime: nil
        )

        #expect(episode.displayDescription == "Unknown Podcast: Unknown Episode")
    }

    @Test("id is unique per podcast-episode combination")
    func idIsUnique() {
        let ep1 = ListenedEpisode(podcastTitle: "P1", episodeTitle: "E1", startTime: nil)
        let ep2 = ListenedEpisode(podcastTitle: "P1", episodeTitle: "E2", startTime: nil)
        let ep3 = ListenedEpisode(podcastTitle: "P2", episodeTitle: "E1", startTime: nil)

        #expect(ep1.id != ep2.id)
        #expect(ep1.id != ep3.id)
        #expect(ep2.id != ep3.id)
    }
}

// MARK: - Notification Tests

@Suite("WorkoutListeningLogService Notifications")
struct WorkoutListeningLogNotificationTests {

    @Test("notification name is defined correctly")
    func notificationNameDefined() {
        #expect(Notification.Name.workoutListeningEventLogged.rawValue == "workoutListeningEventLogged")
    }
}

// MARK: - PersistentIdentifier Extension for Testing

extension PersistentIdentifier {
    /// A placeholder identifier for testing purposes.
    static var placeholder: PersistentIdentifier {
        // This is a hack for testing - in real code, identifiers come from SwiftData
        // We use a simple approach of creating a temporary model context
        let container = try! JogPodSchema.makeTestContainer()
        let context = ModelContext(container)
        let episode = PodcastEpisode(title: "Placeholder")
        context.insert(episode)
        return episode.persistentModelID
    }
}
