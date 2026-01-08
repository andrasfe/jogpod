import Foundation
import SwiftData

/// Represents a single podcast episode.
///
/// This model is the SwiftData equivalent of the legacy `RSSEntry` Core Data entity.
/// It stores metadata about a podcast episode including playback state and media links.
///
/// - Note: The original Core Data model used `RSSEntry` as the class name. This has been
///   renamed to `PodcastEpisode` for clarity and Swift naming conventions.
@Model
public final class PodcastEpisode {

    // MARK: - Type Definitions

    /// Represents the type/category of the episode.
    ///
    /// The legacy Core Data model stored this as an Int16. This enum provides type safety.
    enum EpisodeType: Int, Codable, Sendable {
        case unknown = 0
        case audio = 1
        case video = 2
    }

    // MARK: - Attributes

    /// Whether this episode is currently loaded in the player.
    var isCurrentInPlayer: Bool = false

    /// Whether this episode has been added to the playback queue.
    /// Episodes only appear in "Up Next" when this is true.
    var isInQueue: Bool = false

    /// Generic date field (purpose unclear from legacy code; may be download date).
    var date: Date?

    /// URL string for the media enclosure (audio/video file).
    ///
    /// This is the primary download URL for the episode content.
    var enclosureMediaLink: String?

    /// Unique identifier for the episode (typically the GUID from the RSS feed).
    var identifier: String?

    /// Index/position in a playlist or queue.
    var index: Int32 = 0

    /// When the episode metadata was last updated.
    var lastUpdated: Date?

    /// URL string to the episode's web page.
    var link: String?

    /// Name of the episode (may differ from title).
    var name: String?

    /// User-preferred playback duration in minutes.
    ///
    /// This appears to be for limiting playback time during workouts.
    var preferredPlayDurationInMinutes: Int32 = 0

    /// Publication date of the episode.
    var releaseDate: Date?

    /// Episode summary or show notes.
    var summary: String?

    /// Episode title.
    var title: String?

    /// Type of episode (audio, video, etc.).
    ///
    /// Stored as Int16 for Core Data compatibility. Use `episodeType` for type-safe access.
    var type: Int16 = 0

    /// Alternative URL string (purpose unclear from legacy code).
    var url: String?

    /// Saved playback position in seconds.
    ///
    /// This is used to resume playback from where the user left off.
    var savedPlaybackPosition: Double = 0

    // MARK: - Relationships

    /// The podcast feed this episode belongs to.
    ///
    /// This is the inverse of `PodcastFeed.episodes`.
    var feed: PodcastFeed?

    // MARK: - Initialization

    /// Creates a new podcast episode.
    ///
    /// - Parameters:
    ///   - title: The episode title.
    ///   - identifier: Unique identifier (GUID).
    ///   - enclosureMediaLink: URL to the media file.
    ///   - releaseDate: Publication date.
    ///   - feed: The parent podcast feed.
    init(
        title: String? = nil,
        identifier: String? = nil,
        enclosureMediaLink: String? = nil,
        releaseDate: Date? = nil,
        feed: PodcastFeed? = nil
    ) {
        self.title = title
        self.identifier = identifier
        self.enclosureMediaLink = enclosureMediaLink
        self.releaseDate = releaseDate
        self.feed = feed
    }
}

// MARK: - Computed Properties

extension PodcastEpisode {

    /// Type-safe access to the episode type.
    var episodeType: EpisodeType {
        get { EpisodeType(rawValue: Int(type)) ?? .unknown }
        set { type = Int16(newValue.rawValue) }
    }

    /// The display title, falling back to name if title is nil.
    var displayTitle: String {
        title ?? name ?? "Untitled Episode"
    }

    /// Whether the episode has a valid media URL.
    var hasMediaLink: Bool {
        guard let link = enclosureMediaLink else { return false }
        return !link.isEmpty
    }

    /// Parses the enclosure media link as a URL.
    var mediaURL: URL? {
        guard let urlString = enclosureMediaLink else { return nil }
        return URL(string: urlString)
    }
}
