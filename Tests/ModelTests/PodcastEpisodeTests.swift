import Testing
import Foundation
import SwiftData
@testable import JogPod

/// Tests for the PodcastEpisode SwiftData model.
@Suite("PodcastEpisode Model Tests")
@MainActor
struct PodcastEpisodeTests {

    // MARK: - Setup

    private func makeTestContainer() throws -> ModelContainer {
        try JogPodSchema.makeTestContainer()
    }

    // MARK: - Initialization Tests

    @Test("PodcastEpisode initializes with default values")
    func testDefaultInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode()
        context.insert(episode)
        try context.save()

        #expect(episode.title == nil)
        #expect(episode.identifier == nil)
        #expect(episode.enclosureMediaLink == nil)
        #expect(episode.isCurrentInPlayer == false)
        #expect(episode.index == 0)
        #expect(episode.type == 0)
        #expect(episode.feed == nil)
    }

    @Test("PodcastEpisode initializes with provided values")
    func testInitializationWithValues() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let releaseDate = Date()
        let episode = PodcastEpisode(
            title: "Test Episode",
            identifier: "guid-123",
            enclosureMediaLink: "https://example.com/audio.mp3",
            releaseDate: releaseDate
        )
        context.insert(episode)
        try context.save()

        #expect(episode.title == "Test Episode")
        #expect(episode.identifier == "guid-123")
        #expect(episode.enclosureMediaLink == "https://example.com/audio.mp3")
        #expect(episode.releaseDate == releaseDate)
    }

    // MARK: - EpisodeType Tests

    @Test("episodeType provides type-safe access")
    func testEpisodeType() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode(title: "Test")
        context.insert(episode)

        episode.episodeType = .audio
        #expect(episode.type == 1)
        #expect(episode.episodeType == .audio)

        episode.episodeType = .video
        #expect(episode.type == 2)
        #expect(episode.episodeType == .video)

        episode.type = 0
        #expect(episode.episodeType == .unknown)
    }

    @Test("EpisodeType handles invalid raw values")
    func testEpisodeTypeInvalidValue() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode(title: "Test")
        context.insert(episode)

        episode.type = 99  // Invalid value
        #expect(episode.episodeType == .unknown)
    }

    // MARK: - Computed Property Tests

    @Test("displayTitle falls back correctly")
    func testDisplayTitle() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode1 = PodcastEpisode()
        context.insert(episode1)
        #expect(episode1.displayTitle == "Untitled Episode")

        let episode2 = PodcastEpisode()
        episode2.name = "Name Only"
        context.insert(episode2)
        #expect(episode2.displayTitle == "Name Only")

        let episode3 = PodcastEpisode(title: "Title")
        episode3.name = "Name"
        context.insert(episode3)
        #expect(episode3.displayTitle == "Title")
    }

    @Test("hasMediaLink validates media URL presence")
    func testHasMediaLink() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode1 = PodcastEpisode(title: "No Link")
        context.insert(episode1)
        #expect(episode1.hasMediaLink == false)

        let episode2 = PodcastEpisode(title: "Empty Link")
        episode2.enclosureMediaLink = ""
        context.insert(episode2)
        #expect(episode2.hasMediaLink == false)

        let episode3 = PodcastEpisode(title: "Has Link", enclosureMediaLink: "https://example.com/audio.mp3")
        context.insert(episode3)
        #expect(episode3.hasMediaLink == true)
    }

    @Test("mediaURL parses enclosure link correctly")
    func testMediaURL() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode(title: "Test", enclosureMediaLink: "https://example.com/audio.mp3")
        context.insert(episode)

        #expect(episode.mediaURL != nil)
        #expect(episode.mediaURL?.host() == "example.com")
        #expect(episode.mediaURL?.path() == "/audio.mp3")
    }

    @Test("mediaURL returns nil for invalid URLs")
    func testMediaURLInvalid() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let episode = PodcastEpisode(title: "Test")
        episode.enclosureMediaLink = "not a valid url with spaces"
        context.insert(episode)

        #expect(episode.mediaURL == nil)
    }

    // MARK: - Relationship Tests

    @Test("Episode can be associated with a feed")
    func testFeedRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        let episode = PodcastEpisode(title: "Episode 1", feed: feed)
        context.insert(episode)
        try context.save()

        #expect(episode.feed === feed)
        #expect(feed.episodes.contains(where: { $0 === episode }))
    }

    // MARK: - All 14 Attributes Test

    @Test("All 14 attributes from RSSEntry are preserved")
    func testAllAttributes() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let feed = PodcastFeed(title: "Parent Feed")
        context.insert(feed)

        let episode = PodcastEpisode()
        episode.isCurrentInPlayer = true          // 1. currentInPlayer
        episode.date = now                         // 2. date
        episode.enclosureMediaLink = "https://media.mp3"  // 3. enclosureMediaLink
        episode.identifier = "guid-abc"            // 4. identifier
        episode.index = 5                          // 5. index
        episode.lastUpdated = now                  // 6. lastUpdated
        episode.link = "https://link.com"          // 7. link
        episode.name = "Episode Name"              // 8. name
        episode.preferredPlayDurationInMinutes = 30  // 9. preferredPlayDurationInMinutes
        episode.releaseDate = now                  // 10. releaseDate
        episode.summary = "Episode summary"        // 11. summary
        episode.title = "Episode Title"            // 12. title
        episode.type = 1                           // 13. type
        episode.url = "https://url.com"            // 14. url
        episode.feed = feed                        // relationship: belongsTo

        context.insert(episode)
        try context.save()

        // Fetch and verify
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.identifier == "guid-abc" }
        )
        let fetched = try context.fetch(descriptor).first

        #expect(fetched?.isCurrentInPlayer == true)
        #expect(fetched?.date == now)
        #expect(fetched?.enclosureMediaLink == "https://media.mp3")
        #expect(fetched?.identifier == "guid-abc")
        #expect(fetched?.index == 5)
        #expect(fetched?.lastUpdated == now)
        #expect(fetched?.link == "https://link.com")
        #expect(fetched?.name == "Episode Name")
        #expect(fetched?.preferredPlayDurationInMinutes == 30)
        #expect(fetched?.releaseDate == now)
        #expect(fetched?.summary == "Episode summary")
        #expect(fetched?.title == "Episode Title")
        #expect(fetched?.type == 1)
        #expect(fetched?.url == "https://url.com")
        #expect(fetched?.feed === feed)
    }
}
