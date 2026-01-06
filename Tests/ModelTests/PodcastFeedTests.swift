import Testing
import Foundation
import SwiftData
@testable import JogPod

/// Tests for the PodcastFeed SwiftData model.
@Suite("PodcastFeed Model Tests")
@MainActor
struct PodcastFeedTests {

    // MARK: - Setup

    /// Creates an in-memory model container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        try JogPodSchema.makeTestContainer()
    }

    // MARK: - Initialization Tests

    @Test("PodcastFeed initializes with default values")
    func testDefaultInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed()
        context.insert(feed)
        try context.save()

        #expect(feed.title == nil)
        #expect(feed.link == nil)
        #expect(feed.summary == nil)
        #expect(feed.imageUrl == nil)
        #expect(feed.episodes.isEmpty)
    }

    @Test("PodcastFeed initializes with provided values")
    func testInitializationWithValues() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(
            title: "Test Podcast",
            link: "https://example.com",
            summary: "A test podcast",
            imageUrl: "https://example.com/image.jpg"
        )
        context.insert(feed)
        try context.save()

        #expect(feed.title == "Test Podcast")
        #expect(feed.link == "https://example.com")
        #expect(feed.summary == "A test podcast")
        #expect(feed.imageUrl == "https://example.com/image.jpg")
    }

    // MARK: - Relationship Tests

    @Test("PodcastFeed has one-to-many relationship with episodes")
    func testEpisodeRelationship() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        let episode1 = PodcastEpisode(title: "Episode 1", feed: feed)
        let episode2 = PodcastEpisode(title: "Episode 2", feed: feed)
        context.insert(episode1)
        context.insert(episode2)

        try context.save()

        #expect(feed.episodes.count == 2)
        #expect(episode1.feed === feed)
        #expect(episode2.feed === feed)
    }

    @Test("Cascade delete removes episodes when feed is deleted")
    func testCascadeDelete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        let episode = PodcastEpisode(title: "Episode 1", feed: feed)
        context.insert(episode)
        try context.save()

        // Delete the feed
        context.delete(feed)
        try context.save()

        // Verify episodes are also deleted
        let descriptor = FetchDescriptor<PodcastEpisode>()
        let remainingEpisodes = try context.fetch(descriptor)
        #expect(remainingEpisodes.isEmpty)
    }

    // MARK: - Computed Property Tests

    @Test("episodeCount returns correct count")
    func testEpisodeCount() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        #expect(feed.episodeCount == 0)

        for i in 1...5 {
            let episode = PodcastEpisode(title: "Episode \(i)", feed: feed)
            context.insert(episode)
        }
        try context.save()

        #expect(feed.episodeCount == 5)
    }

    @Test("sortedEpisodes returns episodes in reverse chronological order")
    func testSortedEpisodes() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(title: "Test Podcast")
        context.insert(feed)

        let now = Date()
        let episode1 = PodcastEpisode(title: "Old Episode", releaseDate: now.addingTimeInterval(-86400), feed: feed)
        let episode2 = PodcastEpisode(title: "New Episode", releaseDate: now, feed: feed)
        let episode3 = PodcastEpisode(title: "Middle Episode", releaseDate: now.addingTimeInterval(-43200), feed: feed)

        context.insert(episode1)
        context.insert(episode2)
        context.insert(episode3)
        try context.save()

        let sorted = feed.sortedEpisodes
        #expect(sorted[0].title == "New Episode")
        #expect(sorted[1].title == "Middle Episode")
        #expect(sorted[2].title == "Old Episode")
    }

    // MARK: - Persistence Tests

    @Test("PodcastFeed persists and can be fetched")
    func testPersistence() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let feed = PodcastFeed(
            title: "Persisted Podcast",
            link: "https://persisted.com"
        )
        context.insert(feed)
        try context.save()

        let descriptor = FetchDescriptor<PodcastFeed>(
            predicate: #Predicate { $0.title == "Persisted Podcast" }
        )
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched.first?.link == "https://persisted.com")
    }
}
