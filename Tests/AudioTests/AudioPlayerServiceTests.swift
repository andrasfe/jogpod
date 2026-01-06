//
//  AudioPlayerServiceTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import Testing
import AVFoundation
import SwiftData
@testable import JogPod

/// Tests for PlaybackState enum.
@Suite("PlaybackState Tests")
struct PlaybackStateTests {

    @Test("PlaybackState.idle equals itself")
    func idleEqualsItself() {
        #expect(PlaybackState.idle == PlaybackState.idle)
    }

    @Test("PlaybackState.paused equals itself")
    func pausedEqualsItself() {
        #expect(PlaybackState.paused == PlaybackState.paused)
    }

    @Test("PlaybackState.playing equals itself")
    func playingEqualsItself() {
        #expect(PlaybackState.playing == PlaybackState.playing)
    }

    @Test("PlaybackState.loading equals itself")
    func loadingEqualsItself() {
        #expect(PlaybackState.loading == PlaybackState.loading)
    }

    @Test("Different PlaybackState cases are not equal")
    func differentStatesNotEqual() {
        #expect(PlaybackState.idle != PlaybackState.paused)
        #expect(PlaybackState.paused != PlaybackState.playing)
        #expect(PlaybackState.playing != PlaybackState.loading)
    }

    @Test("PlaybackState.error with same error is equal")
    func errorWithSameErrorIsEqual() {
        let error = AudioPlayerError.noCurrentItem
        let state1 = PlaybackState.error(error)
        let state2 = PlaybackState.error(error)

        #expect(state1 == state2)
    }

    @Test("PlaybackState.error with different errors is not equal")
    func errorWithDifferentErrorsNotEqual() {
        let state1 = PlaybackState.error(.noCurrentItem)
        let state2 = PlaybackState.error(.emptyPlaylist)

        #expect(state1 != state2)
    }
}

/// Tests for PlaybackProgress struct.
@Suite("PlaybackProgress Tests")
struct PlaybackProgressTests {

    @Test("PlaybackProgress initializes with default values")
    func defaultInitialization() {
        let progress = PlaybackProgress()

        #expect(progress.currentTime == 0)
        #expect(progress.duration == -1)
    }

    @Test("PlaybackProgress initializes with custom values")
    func customInitialization() {
        let progress = PlaybackProgress(currentTime: 100, duration: 600)

        #expect(progress.currentTime == 100)
        #expect(progress.duration == 600)
    }

    @Test("PlaybackProgress.progress calculates correctly")
    func progressCalculation() {
        let progress = PlaybackProgress(currentTime: 150, duration: 600)

        #expect(progress.progress == 0.25)
    }

    @Test("PlaybackProgress.progress returns 0 when duration is 0")
    func progressWithZeroDuration() {
        let progress = PlaybackProgress(currentTime: 100, duration: 0)

        #expect(progress.progress == 0)
    }

    @Test("PlaybackProgress.progress returns 0 when duration is negative")
    func progressWithNegativeDuration() {
        let progress = PlaybackProgress(currentTime: 100, duration: -1)

        #expect(progress.progress == 0)
    }

    @Test("PlaybackProgress.progress is clamped to 1.0")
    func progressClampedToOne() {
        let progress = PlaybackProgress(currentTime: 700, duration: 600)

        #expect(progress.progress == 1.0)
    }

    @Test("PlaybackProgress.progress is clamped to 0.0")
    func progressClampedToZero() {
        let progress = PlaybackProgress(currentTime: -100, duration: 600)

        #expect(progress.progress == 0.0)
    }

    @Test("PlaybackProgress.remainingTime calculates correctly")
    func remainingTimeCalculation() {
        let progress = PlaybackProgress(currentTime: 150, duration: 600)

        #expect(progress.remainingTime == 450)
    }

    @Test("PlaybackProgress.remainingTime returns 0 when duration is unknown")
    func remainingTimeWithUnknownDuration() {
        let progress = PlaybackProgress(currentTime: 100, duration: -1)

        #expect(progress.remainingTime == 0)
    }

    @Test("PlaybackProgress.remainingTime is never negative")
    func remainingTimeNeverNegative() {
        let progress = PlaybackProgress(currentTime: 700, duration: 600)

        #expect(progress.remainingTime == 0)
    }

    @Test("PlaybackProgress is Equatable")
    func equatable() {
        let progress1 = PlaybackProgress(currentTime: 100, duration: 600)
        let progress2 = PlaybackProgress(currentTime: 100, duration: 600)
        let progress3 = PlaybackProgress(currentTime: 200, duration: 600)

        #expect(progress1 == progress2)
        #expect(progress1 != progress3)
    }
}

/// Tests for PlayableItem struct.
/// Note: PlayableItem tests require SwiftData integration since PersistentIdentifier
/// cannot be created without a model context.
@Suite("PlayableItem Integration Tests")
struct PlayableItemTests {

    #if DEBUG
    @Test("PlayableItem is identifiable by id")
    @MainActor
    func identifiable() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()

        // Create a feed first
        let feedID = try await persistenceManager.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        // Create an episode
        let episodeID = try await persistenceManager.createPodcastEpisode(
            title: "Test Episode",
            identifier: "ep-1",
            enclosureMediaLink: "https://example.com/audio.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        let item = PlayableItem(
            id: "unique-id",
            episodeID: episodeID,
            title: "Test",
            podcastTitle: "Podcast",
            mediaURL: URL(string: "https://example.com/audio.mp3")!,
            isCached: false,
            artworkURL: nil,
            savedPosition: 0
        )

        #expect(item.id == "unique-id")
    }

    @Test("PlayableItem is Equatable")
    @MainActor
    func equatable() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()

        // Create a feed first
        let feedID = try await persistenceManager.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        // Create an episode
        let episodeID = try await persistenceManager.createPodcastEpisode(
            title: "Test Episode",
            identifier: "ep-1",
            enclosureMediaLink: "https://example.com/audio.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        let url = URL(string: "https://example.com/audio.mp3")!

        let item1 = PlayableItem(
            id: "id1",
            episodeID: episodeID,
            title: "Test",
            podcastTitle: "Podcast",
            mediaURL: url,
            isCached: false,
            artworkURL: nil,
            savedPosition: 0
        )

        let item2 = PlayableItem(
            id: "id1",
            episodeID: episodeID,
            title: "Test",
            podcastTitle: "Podcast",
            mediaURL: url,
            isCached: false,
            artworkURL: nil,
            savedPosition: 0
        )

        #expect(item1 == item2)
    }

    @Test("PlayableItem stores saved position")
    @MainActor
    func savedPosition() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()

        // Create a feed first
        let feedID = try await persistenceManager.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: nil
        )

        // Create an episode
        let episodeID = try await persistenceManager.createPodcastEpisode(
            title: "Test Episode",
            identifier: "ep-1",
            enclosureMediaLink: "https://example.com/audio.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        var item = PlayableItem(
            id: "id",
            episodeID: episodeID,
            title: "Test",
            podcastTitle: "Podcast",
            mediaURL: URL(string: "https://example.com/audio.mp3")!,
            isCached: false,
            artworkURL: nil,
            savedPosition: 120
        )

        #expect(item.savedPosition == 120)

        item.savedPosition = 300
        #expect(item.savedPosition == 300)
    }

    @Test("PlayableItem.from creates item from episode")
    @MainActor
    func fromEpisode() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()

        // Create a feed first
        let feedID = try await persistenceManager.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: "https://example.com/artwork.jpg"
        )

        // Create an episode
        _ = try await persistenceManager.createPodcastEpisode(
            title: "Test Episode",
            identifier: "ep-1",
            enclosureMediaLink: "https://example.com/audio.mp3",
            releaseDate: Date(),
            feedIdentifier: feedID
        )

        // Fetch the episode
        let episodes = try await persistenceManager.fetchAllPodcastEpisodes(sortedByIndex: true)
        guard let episode = episodes.first else {
            Issue.record("Expected episode to exist")
            return
        }

        // Create PlayableItem from episode
        guard let item = PlayableItem.from(episode: episode) else {
            Issue.record("Expected PlayableItem to be created")
            return
        }

        #expect(item.title == "Test Episode")
        #expect(item.podcastTitle == "Test Podcast")
        #expect(item.mediaURL.absoluteString == "https://example.com/audio.mp3")
        #expect(item.isCached == false)
    }

    @Test("PlayableItem.from returns nil for episode without media URL")
    @MainActor
    func fromEpisodeWithoutMediaURL() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()

        // Create an episode without media URL
        _ = try await persistenceManager.createPodcastEpisode(
            title: "Test Episode",
            identifier: "ep-1",
            enclosureMediaLink: nil,
            releaseDate: Date(),
            feedIdentifier: nil
        )

        // Fetch the episode
        let episodes = try await persistenceManager.fetchAllPodcastEpisodes(sortedByIndex: true)
        guard let episode = episodes.first else {
            Issue.record("Expected episode to exist")
            return
        }

        // Create PlayableItem from episode should return nil
        let item = PlayableItem.from(episode: episode)
        #expect(item == nil)
    }
    #endif
}

/// Tests for Notification.Name extensions.
@Suite("Audio Notification Names Tests")
struct AudioNotificationNamesTests {

    @Test("playerStatusChanged notification name is defined")
    func playerStatusChangedNotification() {
        let name = Notification.Name.playerStatusChanged
        #expect(name.rawValue == "playerStatusChanged")
    }

    @Test("podcastItemChanged notification name is defined")
    func podcastItemChangedNotification() {
        let name = Notification.Name.podcastItemChanged
        #expect(name.rawValue == "podcastItemChanged")
    }

    @Test("playlistRefreshed notification name is defined")
    func playlistRefreshedNotification() {
        let name = Notification.Name.playlistRefreshed
        #expect(name.rawValue == "playlistRefreshed")
    }

    @Test("playbackPositionUpdated notification name is defined")
    func playbackPositionUpdatedNotification() {
        let name = Notification.Name.playbackPositionUpdated
        #expect(name.rawValue == "playbackPositionUpdated")
    }
}

/// Tests for AudioPlayerService constants.
@Suite("AudioPlayerService Constants Tests")
struct AudioPlayerServiceConstantsTests {

    @Test("Valid playback rate range is 0.5 to 2.0")
    func validPlaybackRateRange() {
        let range = AudioPlayerService.validPlaybackRateRange

        #expect(range.lowerBound == 0.5)
        #expect(range.upperBound == 2.0)
        #expect(range.contains(1.0))
        #expect(range.contains(0.5))
        #expect(range.contains(2.0))
        #expect(!range.contains(0.4))
        #expect(!range.contains(2.1))
    }

    @Test("Default skip interval is 15 seconds")
    func defaultSkipInterval() {
        #expect(AudioPlayerService.defaultSkipInterval == 15)
    }
}

/// Integration tests for AudioPlayerService requiring SwiftData.
@Suite("AudioPlayerService Integration Tests")
struct AudioPlayerServiceIntegrationTests {

    #if DEBUG
    @Test("AudioPlayerService initializes with mock dependencies")
    @MainActor
    func initializesWithMockDependencies() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        #expect(service.state == .idle)
        #expect(service.isPlaying == false)
        #expect(service.isEmpty == true)
        #expect(service.itemCount == 0)
        #expect(service.currentItem == nil)
        #expect(service.playbackRate == 1.0)
    }

    @Test("AudioPlayerService throws when playing without item")
    @MainActor
    func throwsWhenPlayingWithoutItem() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        #expect(throws: AudioPlayerError.self) {
            try service.play()
        }
    }

    @Test("AudioPlayerService pause does not throw when idle")
    @MainActor
    func pauseDoesNotThrowWhenIdle() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        // Should not throw
        service.pause()

        #expect(service.state == .paused)
    }

    @Test("AudioPlayerService stop clears state")
    @MainActor
    func stopClearsState() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        service.stop()

        #expect(service.state == .idle)
        #expect(service.currentItem == nil)
        #expect(nowPlayingManager.didClearNowPlayingInfo == true)
    }

    @Test("AudioPlayerService setRate validates range")
    @MainActor
    func setRateValidatesRange() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        // Valid rates should succeed
        try service.setRate(1.0)
        #expect(service.playbackRate == 1.0)

        try service.setRate(0.5)
        #expect(service.playbackRate == 0.5)

        try service.setRate(2.0)
        #expect(service.playbackRate == 2.0)

        // Invalid rates should throw
        #expect(throws: AudioPlayerError.self) {
            try service.setRate(0.4)
        }

        #expect(throws: AudioPlayerError.self) {
            try service.setRate(2.1)
        }

        #expect(throws: AudioPlayerError.self) {
            try service.setRate(3.0)
        }
    }

    @Test("AudioPlayerService loads empty playlist")
    @MainActor
    func loadsEmptyPlaylist() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        try await service.loadPlaylist()

        #expect(service.playlist.isEmpty)
        #expect(service.isEmpty == true)
        #expect(service.itemCount == 0)
    }

    @Test("AudioPlayerService goToItem throws for invalid index")
    @MainActor
    func goToItemThrowsForInvalidIndex() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        await #expect(throws: AudioPlayerError.self) {
            try await service.goToItem(at: 0)
        }

        await #expect(throws: AudioPlayerError.self) {
            try await service.goToItem(at: 5)
        }

        await #expect(throws: AudioPlayerError.self) {
            try await service.goToItem(at: -1)
        }
    }

    @Test("AudioPlayerService isAtLastItem when empty")
    @MainActor
    func isAtLastItemWhenEmpty() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        // With empty playlist, isAtLastItem should be true (index 0 >= count - 1 when count is 0)
        #expect(service.isAtLastItem == true)
    }

    @Test("AudioPlayerService currentItemDuration returns -1 when no item")
    @MainActor
    func currentItemDurationWhenNoItem() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        #expect(service.currentItemDuration == -1)
    }

    @Test("AudioPlayerService currentPosition is 0 initially")
    @MainActor
    func currentPositionInitiallyZero() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        #expect(service.currentPosition == 0)
    }

    @Test("AudioPlayerService togglePlayPause when idle throws")
    @MainActor
    func togglePlayPauseWhenIdleThrows() async throws {
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        // When idle (no item), togglePlayPause should try to play and fail
        #expect(throws: AudioPlayerError.self) {
            try service.togglePlayPause()
        }
    }
    #endif
}

/// Tests for AudioPlayerServiceDelegate default implementations.
@Suite("AudioPlayerServiceDelegate Default Implementation Tests")
struct AudioPlayerServiceDelegateTests {

    /// A delegate that does nothing but tracks calls for testing.
    final class TrackingDelegate: AudioPlayerServiceDelegate {
        var stateChanges: [PlaybackState] = []
        var itemChanges: [PlayableItem?] = []
        var progressUpdates: [PlaybackProgress] = []
        var errors: [AudioPlayerError] = []
        var finishedItems: [PlayableItem] = []

        func audioPlayerService(_ service: AudioPlayerService, didChangeState state: PlaybackState) {
            stateChanges.append(state)
        }

        func audioPlayerService(_ service: AudioPlayerService, didChangeItem item: PlayableItem?) {
            itemChanges.append(item)
        }

        func audioPlayerService(_ service: AudioPlayerService, didUpdateProgress progress: PlaybackProgress) {
            progressUpdates.append(progress)
        }

        func audioPlayerService(_ service: AudioPlayerService, didEncounterError error: AudioPlayerError) {
            errors.append(error)
        }

        func audioPlayerService(_ service: AudioPlayerService, didFinishItem item: PlayableItem) {
            finishedItems.append(item)
        }
    }

    /// An empty delegate using default implementations.
    final class EmptyDelegate: AudioPlayerServiceDelegate {}

    @Test("Default delegate implementations do not crash")
    @MainActor
    func defaultImplementationsDoNotCrash() async throws {
        #if DEBUG
        let persistenceManager = try PersistenceManager.makeForTesting()
        let nowPlayingManager = MockNowPlayingManager()

        let service = AudioPlayerService(
            persistenceManager: persistenceManager,
            nowPlayingManager: nowPlayingManager
        )

        let delegate = EmptyDelegate()
        service.delegate = delegate

        // These should not crash due to default empty implementations
        delegate.audioPlayerService(service, didChangeState: .idle)
        delegate.audioPlayerService(service, didChangeItem: nil)
        delegate.audioPlayerService(service, didUpdateProgress: PlaybackProgress())
        delegate.audioPlayerService(service, didEncounterError: .noCurrentItem)
        // Cannot test didFinishItem without a real PlayableItem
        #endif
    }
}
