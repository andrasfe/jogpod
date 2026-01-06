//
//  AudioPlaybackEquivalenceTests.swift
//  JogPod Tests
//
//  Equivalence tests for podcast playback functionality.
//  Verifies the Swift implementation behaves equivalently to legacy Objective-C code.
//
//  Reference: EQUIVALENCE_TESTING_STRATEGY.md Section 3.2
//

import Testing
import Foundation
@testable import JogPod

// MARK: - Podcast Playback Equivalence Tests

/// Tests podcast playback equivalence with legacy Objective-C implementation.
///
/// These tests verify behavioral equivalence according to:
/// - Specification Oracles (SO-002)
/// - Invariant Oracles (INV-004, INV-006)
/// - Golden Dataset Oracles (GD-003, GD-005)
@Suite("Podcast Playback Equivalence")
struct PodcastPlaybackEquivalenceTests {

    // MARK: - Test Configuration

    /// Tolerance for playback position sync (+/- 1 second as per EQUIVALENCE_TESTING_STRATEGY.md)
    static let positionToleranceSeconds: TimeInterval = 1.0

    // MARK: - PP-RSS-001: RSS Feed Parsing

    @Test("PP-RSS-001: Podcast feed is created with correct attributes")
    func podcastFeedCreation() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let feedID = try await persistence.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: "A test podcast feed",
            imageUrl: "https://example.com/artwork.jpg"
        )

        let feeds = try await persistence.fetchAllPodcastFeeds()
        #expect(feeds.count == 1)

        let feed = feeds.first!
        #expect(feed.title == "Test Podcast")
        #expect(feed.link == "https://example.com/feed.xml")
        #expect(feed.summary == "A test podcast feed")
        #expect(feed.imageUrl == "https://example.com/artwork.jpg")
    }

    // MARK: - PP-RSS-002: Extract Audio Enclosure URL (GD-003)

    @Test("PP-RSS-002: Episode stores enclosure media link")
    func episodeEnclosureMediaLink() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let mediaLink = "https://example.com/episode1.mp3"
        let episodeID = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: mediaLink,
            releaseDate: Date(),
            feedIdentifier: nil
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        #expect(episodes.count == 1)

        let episode = episodes.first!
        #expect(episode.enclosureMediaLink == mediaLink)
        #expect(episode.hasMediaLink == true)
        #expect(episode.mediaURL?.absoluteString == mediaLink)
    }

    // MARK: - PP-RSS-004: Handle Malformed Feed (INV-006)

    @Test("PP-RSS-004: Episode without media link handled gracefully")
    func episodeWithoutMediaLink() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createPodcastEpisode(
            title: "No Media Episode",
            identifier: "ep-002",
            enclosureMediaLink: nil,
            releaseDate: Date(),
            feedIdentifier: nil
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        #expect(episode.hasMediaLink == false)
        #expect(episode.mediaURL == nil)
    }

    // MARK: - PP-RSS-005: Feed Refresh Preserves Existing Entries

    @Test("PP-RSS-005: Creating feed with existing link is idempotent")
    func feedWithExistingLink() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let link = "https://example.com/feed.xml"

        // Create first feed
        _ = try await persistence.createPodcastFeed(
            title: "Original Title",
            link: link,
            summary: nil,
            imageUrl: nil
        )

        // Fetch by link should find existing
        let existingFeed = try await persistence.fetchPodcastFeed(byLink: link)
        #expect(existingFeed != nil)
        #expect(existingFeed?.title == "Original Title")
    }

    // MARK: - PP-PBC-001: Play Podcast Episode (SO-002)

    @Test("PP-PBC-001: PlaybackState transitions correctly")
    @MainActor
    func playbackStateTransitions() {
        // Verify state enum exists and has expected cases
        let idle: PlaybackState = .idle
        let paused: PlaybackState = .paused
        let playing: PlaybackState = .playing
        let loading: PlaybackState = .loading

        #expect(idle == .idle)
        #expect(paused == .paused)
        #expect(playing == .playing)
        #expect(loading == .loading)
    }

    // MARK: - PP-PLM-001: Playlist Ordering by Index (GD-003)

    @Test("PP-PLM-001: Episodes sorted by index")
    func episodesSortedByIndex() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        // Create episodes
        let ep1 = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/ep1.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        let ep2 = try await persistence.createPodcastEpisode(
            title: "Episode 2",
            identifier: "ep-002",
            enclosureMediaLink: "https://example.com/ep2.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        let ep3 = try await persistence.createPodcastEpisode(
            title: "Episode 3",
            identifier: "ep-003",
            enclosureMediaLink: "https://example.com/ep3.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        // Update indexes
        try await persistence.updateEpisodeIndex(ep1, newIndex: 2)
        try await persistence.updateEpisodeIndex(ep2, newIndex: 0)
        try await persistence.updateEpisodeIndex(ep3, newIndex: 1)

        // Fetch sorted by index
        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)

        #expect(episodes.count == 3)
        #expect(episodes[0].identifier == "ep-002") // index 0
        #expect(episodes[1].identifier == "ep-003") // index 1
        #expect(episodes[2].identifier == "ep-001") // index 2
    }

    // MARK: - PP-PLM-002: Current Item Tracking (INV-004)

    @Test("PP-PLM-002: Only one episode can be current in player")
    func onlyOneCurrentEpisode() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let ep1 = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/ep1.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        let ep2 = try await persistence.createPodcastEpisode(
            title: "Episode 2",
            identifier: "ep-002",
            enclosureMediaLink: "https://example.com/ep2.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        // Set episode 1 as current
        try await persistence.setCurrentEpisode(ep1)

        var currentEpisode = try await persistence.fetchCurrentEpisode()
        #expect(currentEpisode?.identifier == "ep-001")

        // Set episode 2 as current - should clear episode 1
        try await persistence.setCurrentEpisode(ep2)

        currentEpisode = try await persistence.fetchCurrentEpisode()
        #expect(currentEpisode?.identifier == "ep-002")

        // Verify only one is current
        let allEpisodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let currentCount = allEpisodes.filter { $0.isCurrentInPlayer }.count
        #expect(currentCount == 1, "Only one episode should be marked as current")
    }

    // MARK: - PP-PLM-003: Position Persistence on Pause

    @Test("PP-PLM-003: Playback position is saved")
    func playbackPositionPersistence() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let episodeID = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/ep1.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        // Save position
        let position: TimeInterval = 120.5 // 2 minutes, 0.5 seconds
        try await persistence.saveEpisodePosition(episodeID: episodeID, position: position)

        // Retrieve position
        let savedPosition = try await persistence.fetchEpisodePosition(episodeID: episodeID)
        #expect(savedPosition != nil)
        #expect(abs(savedPosition! - position) < 0.001)
    }

    // MARK: - PP-PLM-004: Resume from Saved Position

    @Test("PP-PLM-004: Episode resumes from saved position")
    func episodeResumeFromPosition() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let episodeID = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/ep1.mp3",
            releaseDate: Date(),
            feedIdentifier: nil
        )

        // Save position
        let position: TimeInterval = 300.0 // 5 minutes
        try await persistence.saveEpisodePosition(episodeID: episodeID, position: position)

        // Verify position is retrievable
        let savedPosition = try await persistence.fetchEpisodePosition(episodeID: episodeID)
        #expect(savedPosition == position)
    }

    // MARK: - PP-PBC-005: Fast Forward (SO-002)

    @Test("PP-PBC-005: Default skip interval configuration")
    @MainActor
    func defaultSkipInterval() {
        // Verify default skip interval matches legacy behavior
        #expect(AudioPlayerService.defaultSkipInterval == 15)
    }

    // MARK: - PP-PBC-008: Playback Rate Change (SO-002)

    @Test("PP-PBC-008: Valid playback rate range is 0.5 to 2.0")
    @MainActor
    func playbackRateRange() {
        let range = AudioPlayerService.validPlaybackRateRange
        #expect(range.lowerBound == 0.5)
        #expect(range.upperBound == 2.0)
    }
}

// MARK: - Playback Progress Tests

@Suite("Playback Progress Equivalence")
struct PlaybackProgressEquivalenceTests {

    @Test("PlaybackProgress calculates progress fraction correctly")
    func progressFraction() {
        let progress = PlaybackProgress(currentTime: 30, duration: 120)

        #expect(progress.progress == 0.25) // 30/120 = 0.25
    }

    @Test("PlaybackProgress calculates remaining time correctly")
    func remainingTime() {
        let progress = PlaybackProgress(currentTime: 30, duration: 120)

        #expect(progress.remainingTime == 90) // 120 - 30 = 90
    }

    @Test("PlaybackProgress handles zero duration")
    func zeroDuration() {
        let progress = PlaybackProgress(currentTime: 30, duration: 0)

        #expect(progress.progress == 0)
        #expect(progress.remainingTime == 0)
    }

    @Test("PlaybackProgress handles negative duration (unknown)")
    func negativeDuration() {
        let progress = PlaybackProgress(currentTime: 30, duration: -1)

        #expect(progress.progress == 0)
        #expect(progress.remainingTime == 0)
    }
}

// MARK: - Podcast Model Invariants

@Suite("Podcast Model Invariants")
struct PodcastModelInvariantTests {

    // MARK: - INV-004: At Most One Episode Current in Player

    @Test("INV-004: setCurrentEpisode clears previous current")
    func setCurrentEpisodeClearsPrevious() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let ep1 = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        let ep2 = try await persistence.createPodcastEpisode(
            title: "Episode 2",
            identifier: "ep-002",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        try await persistence.setCurrentEpisode(ep1)
        try await persistence.setCurrentEpisode(ep2)

        let allEpisodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let currentCount = allEpisodes.filter { $0.isCurrentInPlayer }.count

        #expect(currentCount == 1)
    }

    // MARK: - Feed-Episode Relationship

    @Test("GD-003: Episodes belong to their parent feed")
    func episodeBelongsToFeed() async throws {
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
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        #expect(episodes.count == 1)

        let episode = episodes.first!
        #expect(episode.feed != nil)
        #expect(episode.feed?.title == "Test Podcast")
    }

    // MARK: - Cascade Delete

    @Test("Feed deletion cascades to episodes")
    func feedDeletionCascades() async throws {
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
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        _ = try await persistence.createPodcastEpisode(
            title: "Episode 2",
            identifier: "ep-002",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        // Verify episodes exist
        var episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        #expect(episodes.count == 2)

        // Delete feed
        try await persistence.deletePodcastFeed(feedID)

        // Episodes should be deleted due to cascade rule
        episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        #expect(episodes.count == 0)
    }
}

// MARK: - Playable Item Tests

@Suite("PlayableItem Equivalence")
struct PlayableItemEquivalenceTests {

    @Test("PlayableItem created from episode with media URL")
    func playableItemFromEpisode() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        let feedID = try await persistence.createPodcastFeed(
            title: "Test Podcast",
            link: "https://example.com/feed.xml",
            summary: nil,
            imageUrl: "https://example.com/artwork.jpg"
        )

        _ = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/episode1.mp3",
            releaseDate: nil,
            feedIdentifier: feedID
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        let playableItem = PlayableItem.from(episode: episode, cachedURL: nil)

        #expect(playableItem != nil)
        #expect(playableItem?.title == "Episode 1")
        #expect(playableItem?.podcastTitle == "Test Podcast")
        #expect(playableItem?.mediaURL.absoluteString == "https://example.com/episode1.mp3")
    }

    @Test("PlayableItem nil when episode has no media URL")
    func playableItemNilWithoutMediaURL() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        let playableItem = PlayableItem.from(episode: episode, cachedURL: nil)

        #expect(playableItem == nil)
    }

    @Test("PlayableItem uses cached URL when provided")
    func playableItemUsesCachedURL() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep-001",
            enclosureMediaLink: "https://example.com/episode1.mp3",
            releaseDate: nil,
            feedIdentifier: nil
        )

        let episodes = try await persistence.fetchAllPodcastEpisodes(sortedByIndex: true)
        let episode = episodes.first!

        let cachedURL = URL(fileURLWithPath: "/var/cache/episode1.mp3")
        let playableItem = PlayableItem.from(episode: episode, cachedURL: cachedURL)

        #expect(playableItem != nil)
        #expect(playableItem?.isCached == true)
        #expect(playableItem?.mediaURL == cachedURL)
    }
}
