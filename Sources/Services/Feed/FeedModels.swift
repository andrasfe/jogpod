//
//  FeedModels.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation

// MARK: - Feed Type

/// The type of feed being parsed.
///
/// Corresponds to the legacy MWFeedParser's FeedType enum.
public enum FeedType: String, Sendable, Equatable {
    /// RSS 2.0 feed format.
    case rss = "RSS"

    /// RSS 1.0 (RDF) feed format.
    case rss1 = "RSS1"

    /// Atom feed format.
    case atom = "Atom"

    /// Unknown or unrecognized feed format.
    case unknown = "Unknown"
}

// MARK: - Feed Info

/// Metadata about a podcast feed.
///
/// This struct represents the channel-level information in an RSS/Atom feed,
/// including the podcast title, description, website link, and artwork URL.
///
/// Equivalent to the legacy `MWFeedInfo` class.
public struct FeedInfo: Sendable, Equatable, Codable, Identifiable {

    /// Unique identifier derived from the feed link.
    public var id: String {
        link ?? UUID().uuidString
    }

    /// The title of the podcast feed.
    public var title: String?

    /// The website link for the podcast.
    public var link: String?

    /// A summary or description of the podcast.
    public var summary: String?

    /// URL string for the podcast artwork image.
    public var imageUrl: String?

    /// The type of feed (RSS, RSS1, Atom).
    public var feedType: FeedType

    /// Creates a new FeedInfo instance.
    ///
    /// - Parameters:
    ///   - title: The podcast title.
    ///   - link: The website link.
    ///   - summary: The podcast description.
    ///   - imageUrl: The artwork URL.
    ///   - feedType: The type of feed.
    public init(
        title: String? = nil,
        link: String? = nil,
        summary: String? = nil,
        imageUrl: String? = nil,
        feedType: FeedType = .unknown
    ) {
        self.title = title
        self.link = link
        self.summary = summary
        self.imageUrl = imageUrl
        self.feedType = feedType
    }
}

// MARK: - Feed Item Enclosure

/// Represents a media enclosure attached to a feed item.
///
/// Enclosures typically contain the audio file URL, MIME type, and file size
/// for podcast episodes.
public struct FeedEnclosure: Sendable, Equatable, Codable {

    /// The URL where the media file is located.
    public var url: String

    /// The MIME type of the media (e.g., "audio/mpeg").
    public var type: String?

    /// The size of the media file in bytes.
    public var length: Int64?

    /// Creates a new FeedEnclosure instance.
    ///
    /// - Parameters:
    ///   - url: The media file URL.
    ///   - type: The MIME type.
    ///   - length: The file size in bytes.
    public init(url: String, type: String? = nil, length: Int64? = nil) {
        self.url = url
        self.type = type
        self.length = length
    }
}

// MARK: - Feed Item

/// Represents a single episode item from a podcast feed.
///
/// This struct contains all metadata for a podcast episode, including
/// the title, description, publication date, and media enclosures.
///
/// Equivalent to the legacy `MWFeedItem` class.
public struct FeedItem: Sendable, Equatable, Codable, Identifiable {

    /// Unique identifier for this item (typically the GUID from the feed).
    public var id: String {
        identifier ?? link ?? UUID().uuidString
    }

    /// The unique identifier from the feed (GUID/id element).
    public var identifier: String?

    /// The episode title.
    public var title: String?

    /// The episode link/URL.
    public var link: String?

    /// The publication date of the episode.
    public var date: Date?

    /// The date the episode was last updated.
    public var updated: Date?

    /// A brief summary or description of the episode.
    public var summary: String?

    /// The full content/description of the episode (if available).
    public var content: String?

    /// Media enclosures (typically the audio file).
    public var enclosures: [FeedEnclosure]

    /// The duration of the episode as a string (e.g., "1:23:45").
    public var duration: String?

    /// Creates a new FeedItem instance.
    ///
    /// - Parameters:
    ///   - identifier: The unique identifier.
    ///   - title: The episode title.
    ///   - link: The episode link.
    ///   - date: The publication date.
    ///   - updated: The last updated date.
    ///   - summary: The episode summary.
    ///   - content: The full episode content.
    ///   - enclosures: The media enclosures.
    ///   - duration: The episode duration string.
    public init(
        identifier: String? = nil,
        title: String? = nil,
        link: String? = nil,
        date: Date? = nil,
        updated: Date? = nil,
        summary: String? = nil,
        content: String? = nil,
        enclosures: [FeedEnclosure] = [],
        duration: String? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.link = link
        self.date = date
        self.updated = updated
        self.summary = summary
        self.content = content
        self.enclosures = enclosures
        self.duration = duration
    }

    /// The primary media URL from enclosures, if available.
    public var mediaURL: URL? {
        enclosures.first.flatMap { URL(string: $0.url) }
    }

    /// The effective description, preferring summary over content.
    public var effectiveDescription: String? {
        summary ?? content
    }

    /// The effective date, preferring publication date over updated date.
    public var effectiveDate: Date? {
        date ?? updated
    }

    /// Parses the duration string into seconds.
    ///
    /// Handles formats like "HH:MM:SS", "MM:SS", or raw seconds.
    ///
    /// - Returns: The duration in seconds, or nil if parsing fails.
    public var durationInSeconds: TimeInterval? {
        guard let duration = duration else { return nil }

        let components = duration.split(separator: ":").compactMap { Int($0) }

        switch components.count {
        case 1:
            // Raw seconds
            return TimeInterval(components[0])
        case 2:
            // MM:SS
            return TimeInterval(components[0] * 60 + components[1])
        case 3:
            // HH:MM:SS
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        default:
            return nil
        }
    }
}

// MARK: - Parsed Feed Result

/// The complete result of parsing a podcast feed.
///
/// Contains both the feed metadata and all parsed episode items.
public struct ParsedFeed: Sendable, Equatable {

    /// The feed's metadata (title, description, artwork, etc.).
    public var info: FeedInfo

    /// The episodes parsed from the feed.
    public var items: [FeedItem]

    /// The source URL the feed was fetched from.
    public var sourceURL: URL

    /// When the feed was last successfully fetched.
    public var fetchedAt: Date

    /// Creates a new ParsedFeed instance.
    ///
    /// - Parameters:
    ///   - info: The feed metadata.
    ///   - items: The parsed episodes.
    ///   - sourceURL: The source URL.
    ///   - fetchedAt: When the feed was fetched.
    public init(
        info: FeedInfo,
        items: [FeedItem],
        sourceURL: URL,
        fetchedAt: Date = Date()
    ) {
        self.info = info
        self.items = items
        self.sourceURL = sourceURL
        self.fetchedAt = fetchedAt
    }

    /// The first item in the feed, if any.
    public var firstItem: FeedItem? {
        items.first
    }

    /// The number of items in the feed.
    public var itemCount: Int {
        items.count
    }

    /// Whether the feed has any items.
    public var hasItems: Bool {
        !items.isEmpty
    }
}

// MARK: - Feed Parse Options

/// Options for controlling how a feed is parsed.
public struct FeedParseOptions: Sendable {

    /// Maximum number of items to parse (nil for unlimited).
    public var maxItems: Int?

    /// Whether to stop parsing after the first item.
    public var firstItemOnly: Bool

    /// Whether to parse feed info only (no items).
    public var infoOnly: Bool

    /// Creates default parse options (parse everything).
    public static let `default` = FeedParseOptions()

    /// Creates options to parse only the first item (for quick metadata extraction).
    public static let firstItemOnly = FeedParseOptions(firstItemOnly: true)

    /// Creates options to parse only feed info (no items).
    public static let infoOnly = FeedParseOptions(infoOnly: true)

    /// Creates a new FeedParseOptions instance.
    ///
    /// - Parameters:
    ///   - maxItems: Maximum items to parse.
    ///   - firstItemOnly: Stop after first item.
    ///   - infoOnly: Parse info only.
    public init(
        maxItems: Int? = nil,
        firstItemOnly: Bool = false,
        infoOnly: Bool = false
    ) {
        self.maxItems = maxItems
        self.firstItemOnly = firstItemOnly
        self.infoOnly = infoOnly
    }
}
