//
//  MockFeedService.swift
//  JogPod
//
//  Mock implementation of FeedServiceProtocol for testing.
//  Created for JogPod Revival project.
//

import Foundation
@testable import JogPod

// MARK: - Mock Feed Service

/// A mock implementation of FeedServiceProtocol for testing RSS/Atom feed parsing.
///
/// This mock allows tests to simulate various feed fetching scenarios:
///
/// - Successful feed parsing with custom feed data
/// - Network errors
/// - Invalid feed formats
/// - Timeout simulation
/// - Empty feeds
///
/// ## Usage
///
/// ```swift
/// let mockService = MockFeedService()
///
/// // Configure a successful response
/// mockService.mockFeed = MockFeedFixtures.samplePodcastFeed
///
/// // Or configure an error
/// mockService.errorToThrow = FeedParsingError.connectionFailed(underlying: "Test error")
///
/// // Use in tests
/// let feed = try await mockService.fetchFeed(from: url)
/// ```
public actor MockFeedService: FeedServiceProtocol {

    // MARK: - Configuration

    /// The mock feed to return on successful fetch.
    public var mockFeed: ParsedFeed?

    /// Error to throw instead of returning a feed.
    public var errorToThrow: FeedParsingError?

    /// Delay before completing the fetch (for timeout testing).
    public var fetchDelay: TimeInterval = 0

    /// Dictionary mapping URLs to specific feeds (for multi-feed testing).
    public var feedsByURL: [URL: ParsedFeed] = [:]

    /// Dictionary mapping URLs to specific errors.
    public var errorsByURL: [URL: FeedParsingError] = [:]

    // MARK: - Call Tracking

    /// Number of times fetchFeed was called.
    public private(set) var fetchCallCount: Int = 0

    /// Number of times parseFeed was called.
    public private(set) var parseCallCount: Int = 0

    /// The last URL that was requested.
    public private(set) var lastRequestedURL: URL?

    /// The last options that were used.
    public private(set) var lastOptions: FeedParseOptions?

    /// All URLs that have been requested.
    public private(set) var requestedURLs: [URL] = []

    // MARK: - Initialization

    public init() {
        self.mockFeed = MockFeedFixtures.samplePodcastFeed
    }

    // MARK: - FeedServiceProtocol

    public func fetchFeed(from url: URL, options: FeedParseOptions) async throws -> ParsedFeed {
        fetchCallCount += 1
        lastRequestedURL = url
        lastOptions = options
        requestedURLs.append(url)

        // Apply delay if configured
        if fetchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(fetchDelay * 1_000_000_000))
        }

        // Check for URL-specific error
        if let error = errorsByURL[url] {
            throw error
        }

        // Check for global error
        if let error = errorToThrow {
            throw error
        }

        // Check for URL-specific feed
        if let feed = feedsByURL[url] {
            return applyOptions(feed, options: options)
        }

        // Return default mock feed
        guard let feed = mockFeed else {
            throw FeedParsingError.noDataReceived
        }

        return applyOptions(feed, options: options)
    }

    public func fetchFeed(from urlString: String, options: FeedParseOptions) async throws -> ParsedFeed {
        guard let url = URL(string: urlString) else {
            throw FeedParsingError.invalidURL(urlString)
        }
        return try await fetchFeed(from: url, options: options)
    }

    public func parseFeed(data: Data, sourceURL: URL, options: FeedParseOptions) async throws -> ParsedFeed {
        parseCallCount += 1
        lastRequestedURL = sourceURL
        lastOptions = options

        if let error = errorToThrow {
            throw error
        }

        guard let feed = mockFeed else {
            throw FeedParsingError.noDataReceived
        }

        return applyOptions(feed, options: options)
    }

    // MARK: - Private Methods

    private func applyOptions(_ feed: ParsedFeed, options: FeedParseOptions) -> ParsedFeed {
        var items = feed.items

        if options.infoOnly {
            items = []
        } else if options.firstItemOnly {
            items = Array(items.prefix(1))
        } else if let maxItems = options.maxItems {
            items = Array(items.prefix(maxItems))
        }

        return ParsedFeed(
            info: feed.info,
            items: items,
            sourceURL: feed.sourceURL,
            fetchedAt: feed.fetchedAt
        )
    }

    // MARK: - Test Helpers

    /// Resets all mock state.
    public func reset() {
        mockFeed = MockFeedFixtures.samplePodcastFeed
        errorToThrow = nil
        fetchDelay = 0
        feedsByURL.removeAll()
        errorsByURL.removeAll()
        fetchCallCount = 0
        parseCallCount = 0
        lastRequestedURL = nil
        lastOptions = nil
        requestedURLs.removeAll()
    }

    /// Registers a feed for a specific URL.
    public func register(feed: ParsedFeed, for url: URL) {
        feedsByURL[url] = feed
    }

    /// Registers an error for a specific URL.
    public func register(error: FeedParsingError, for url: URL) {
        errorsByURL[url] = error
    }

    /// Simulates a successful feed fetch.
    public func simulateSuccess(with feed: ParsedFeed? = nil) {
        mockFeed = feed ?? MockFeedFixtures.samplePodcastFeed
        errorToThrow = nil
    }

    /// Simulates a network error.
    public func simulateNetworkError(message: String = "Network connection lost") {
        errorToThrow = .connectionFailed(underlying: message)
    }

    /// Simulates a timeout.
    public func simulateTimeout(seconds: TimeInterval = 30) {
        errorToThrow = .timeout(seconds: seconds)
    }

    /// Simulates an invalid feed format.
    public func simulateInvalidFeed(details: String = "Not a valid RSS/Atom feed") {
        errorToThrow = .invalidFeedFormat(details: details)
    }

    /// Simulates an HTTP error.
    public func simulateHTTPError(statusCode: Int, message: String? = nil) {
        errorToThrow = .httpError(statusCode: statusCode, message: message)
    }
}

// MARK: - Mock Feed Fixtures

/// Sample feed data for testing.
public enum MockFeedFixtures {

    // MARK: - Sample Feeds

    /// A sample podcast feed with typical data.
    public static var samplePodcastFeed: ParsedFeed {
        ParsedFeed(
            info: sampleFeedInfo,
            items: sampleFeedItems,
            sourceURL: URL(string: "https://example.com/podcast/feed.xml")!,
            fetchedAt: Date()
        )
    }

    /// An empty feed with no items.
    public static var emptyFeed: ParsedFeed {
        ParsedFeed(
            info: FeedInfo(
                title: "Empty Podcast",
                link: "https://example.com",
                summary: "A podcast with no episodes yet",
                feedType: .rss
            ),
            items: [],
            sourceURL: URL(string: "https://example.com/empty-feed.xml")!,
            fetchedAt: Date()
        )
    }

    /// A minimal feed with just one item.
    public static var minimalFeed: ParsedFeed {
        ParsedFeed(
            info: FeedInfo(
                title: "Minimal Podcast",
                feedType: .rss
            ),
            items: [
                FeedItem(
                    identifier: "minimal-1",
                    title: "Only Episode",
                    enclosures: [
                        FeedEnclosure(
                            url: "https://example.com/minimal.mp3",
                            type: "audio/mpeg"
                        )
                    ]
                )
            ],
            sourceURL: URL(string: "https://example.com/minimal.xml")!,
            fetchedAt: Date()
        )
    }

    /// A feed with many items for pagination testing.
    public static var largeFeed: ParsedFeed {
        let items = (1...100).map { index in
            FeedItem(
                identifier: "episode-\(index)",
                title: "Episode \(index)",
                link: "https://example.com/episode/\(index)",
                date: Date().addingTimeInterval(TimeInterval(-index * 86400)),
                summary: "This is episode \(index) of the podcast.",
                enclosures: [
                    FeedEnclosure(
                        url: "https://example.com/audio/episode\(index).mp3",
                        type: "audio/mpeg",
                        length: Int64(50_000_000 + index * 1000)
                    )
                ],
                duration: "\(index % 60):\(30 + (index % 30)):00"
            )
        }

        return ParsedFeed(
            info: FeedInfo(
                title: "Large Podcast",
                link: "https://example.com/large",
                summary: "A podcast with many episodes",
                imageUrl: "https://example.com/large-artwork.jpg",
                feedType: .rss
            ),
            items: items,
            sourceURL: URL(string: "https://example.com/large-feed.xml")!,
            fetchedAt: Date()
        )
    }

    // MARK: - Sample Components

    /// Sample feed info.
    public static var sampleFeedInfo: FeedInfo {
        FeedInfo(
            title: "Running with Tech",
            link: "https://runningwithtech.example.com",
            summary: "A weekly podcast about running, fitness technology, and staying healthy.",
            imageUrl: "https://runningwithtech.example.com/artwork.jpg",
            feedType: .rss
        )
    }

    /// Sample feed items.
    public static var sampleFeedItems: [FeedItem] {
        [
            FeedItem(
                identifier: "rwt-001",
                title: "Getting Started with GPS Running Watches",
                link: "https://runningwithtech.example.com/episode/1",
                date: Date().addingTimeInterval(-86400),
                summary: "In this episode, we discuss the best GPS running watches for beginners.",
                enclosures: [
                    FeedEnclosure(
                        url: "https://runningwithtech.example.com/audio/episode001.mp3",
                        type: "audio/mpeg",
                        length: 52_428_800
                    )
                ],
                duration: "45:30"
            ),
            FeedItem(
                identifier: "rwt-002",
                title: "Heart Rate Training Zones Explained",
                link: "https://runningwithtech.example.com/episode/2",
                date: Date().addingTimeInterval(-172800),
                summary: "Learn about heart rate zones and how to use them to improve your running.",
                content: "<p>Full episode content with HTML formatting...</p>",
                enclosures: [
                    FeedEnclosure(
                        url: "https://runningwithtech.example.com/audio/episode002.mp3",
                        type: "audio/mpeg",
                        length: 48_000_000
                    )
                ],
                duration: "1:02:15"
            ),
            FeedItem(
                identifier: "rwt-003",
                title: "Best Running Apps of 2024",
                link: "https://runningwithtech.example.com/episode/3",
                date: Date().addingTimeInterval(-259200),
                summary: "Our roundup of the best running apps for iOS and Android.",
                enclosures: [
                    FeedEnclosure(
                        url: "https://runningwithtech.example.com/audio/episode003.mp3",
                        type: "audio/mpeg",
                        length: 55_000_000
                    )
                ],
                duration: "38:45"
            )
        ]
    }

    // MARK: - Atom Feed

    /// A sample Atom feed.
    public static var atomFeed: ParsedFeed {
        ParsedFeed(
            info: FeedInfo(
                title: "Atom Podcast",
                link: "https://atom.example.com",
                summary: "A podcast using Atom format",
                feedType: .atom
            ),
            items: [
                FeedItem(
                    identifier: "atom-1",
                    title: "Atom Episode 1",
                    link: "https://atom.example.com/1",
                    date: Date(),
                    updated: Date(),
                    summary: "First atom episode",
                    enclosures: [
                        FeedEnclosure(
                            url: "https://atom.example.com/audio/1.mp3",
                            type: "audio/mpeg"
                        )
                    ]
                )
            ],
            sourceURL: URL(string: "https://atom.example.com/feed.atom")!,
            fetchedAt: Date()
        )
    }

    // MARK: - RSS 1.0 (RDF) Feed

    /// A sample RSS 1.0 (RDF) feed.
    public static var rss1Feed: ParsedFeed {
        ParsedFeed(
            info: FeedInfo(
                title: "RDF Podcast",
                link: "https://rdf.example.com",
                summary: "A podcast using RSS 1.0 (RDF) format",
                feedType: .rss1
            ),
            items: [
                FeedItem(
                    identifier: "rdf-1",
                    title: "RDF Episode 1",
                    link: "https://rdf.example.com/1",
                    date: Date(),
                    summary: "First RDF episode"
                )
            ],
            sourceURL: URL(string: "https://rdf.example.com/feed.rdf")!,
            fetchedAt: Date()
        )
    }
}

// MARK: - XML Feed Fixtures

/// Raw XML feed data for testing feed parsing.
public enum XMLFeedFixtures {

    /// Sample RSS 2.0 feed XML.
    public static var rss2XML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
            <channel>
                <title>Running with Tech</title>
                <link>https://runningwithtech.example.com</link>
                <description>A weekly podcast about running, fitness technology, and staying healthy.</description>
                <itunes:image href="https://runningwithtech.example.com/artwork.jpg"/>
                <item>
                    <title>Getting Started with GPS Running Watches</title>
                    <link>https://runningwithtech.example.com/episode/1</link>
                    <guid>rwt-001</guid>
                    <pubDate>Mon, 01 Jan 2024 10:00:00 GMT</pubDate>
                    <description>In this episode, we discuss the best GPS running watches for beginners.</description>
                    <enclosure url="https://runningwithtech.example.com/audio/episode001.mp3" type="audio/mpeg" length="52428800"/>
                    <itunes:duration>45:30</itunes:duration>
                </item>
                <item>
                    <title>Heart Rate Training Zones Explained</title>
                    <link>https://runningwithtech.example.com/episode/2</link>
                    <guid>rwt-002</guid>
                    <pubDate>Mon, 08 Jan 2024 10:00:00 GMT</pubDate>
                    <description>Learn about heart rate zones and how to use them to improve your running.</description>
                    <enclosure url="https://runningwithtech.example.com/audio/episode002.mp3" type="audio/mpeg" length="48000000"/>
                    <itunes:duration>1:02:15</itunes:duration>
                </item>
            </channel>
        </rss>
        """
    }

    /// Sample Atom feed XML.
    public static var atomXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Atom Podcast</title>
            <link href="https://atom.example.com" rel="alternate"/>
            <subtitle>A podcast using Atom format</subtitle>
            <entry>
                <title>Atom Episode 1</title>
                <link href="https://atom.example.com/1" rel="alternate"/>
                <id>atom-1</id>
                <published>2024-01-01T10:00:00Z</published>
                <updated>2024-01-01T10:00:00Z</updated>
                <summary>First atom episode</summary>
                <link href="https://atom.example.com/audio/1.mp3" rel="enclosure" type="audio/mpeg"/>
            </entry>
        </feed>
        """
    }

    /// Sample RSS 1.0 (RDF) feed XML.
    public static var rss1XML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns="http://purl.org/rss/1.0/"
                 xmlns:dc="http://purl.org/dc/elements/1.1/">
            <channel>
                <title>RDF Podcast</title>
                <link>https://rdf.example.com</link>
                <description>A podcast using RSS 1.0 (RDF) format</description>
            </channel>
            <item>
                <title>RDF Episode 1</title>
                <link>https://rdf.example.com/1</link>
                <dc:identifier>rdf-1</dc:identifier>
                <dc:date>2024-01-01T10:00:00Z</dc:date>
                <description>First RDF episode</description>
            </item>
        </rdf:RDF>
        """
    }

    /// Invalid XML that should cause parsing errors.
    public static var invalidXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Broken Feed</title>
                <item>
                    <title>Unclosed tag
                </item>
            </channel>
        """
    }

    /// Non-feed XML document.
    public static var nonFeedXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <html>
            <head><title>Not a Feed</title></head>
            <body><p>This is HTML, not RSS or Atom.</p></body>
        </html>
        """
    }

    /// Empty RSS feed.
    public static var emptyRSSXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Empty Podcast</title>
                <link>https://example.com</link>
                <description>No episodes yet</description>
            </channel>
        </rss>
        """
    }
}
