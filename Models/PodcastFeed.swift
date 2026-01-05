import Foundation
import SwiftData

/// Represents a podcast feed (RSS channel).
///
/// This model is the SwiftData equivalent of the legacy `RSSEntity` Core Data entity.
/// It stores metadata about a podcast feed and maintains a one-to-many relationship
/// with its episodes (`PodcastEpisode`).
///
/// - Note: The original Core Data model used `RSSEntity` as the class name. This has been
///   renamed to `PodcastFeed` for clarity and Swift naming conventions.
@Model
final class PodcastFeed {

    // MARK: - Attributes

    /// URL string for the podcast artwork image.
    var imageUrl: String?

    /// URL string for the podcast's website.
    var link: String?

    /// Description or summary of the podcast.
    var summary: String?

    /// Title of the podcast feed.
    var title: String?

    // MARK: - Relationships

    /// Episodes belonging to this podcast feed.
    ///
    /// This is the inverse of `PodcastEpisode.feed`.
    /// The cascade delete rule ensures episodes are deleted when the feed is deleted.
    @Relationship(deleteRule: .cascade, inverse: \PodcastEpisode.feed)
    var episodes: [PodcastEpisode] = []

    // MARK: - Initialization

    /// Creates a new podcast feed with optional metadata.
    ///
    /// - Parameters:
    ///   - title: The title of the podcast.
    ///   - link: URL to the podcast's website.
    ///   - summary: Description of the podcast.
    ///   - imageUrl: URL to the podcast artwork.
    init(
        title: String? = nil,
        link: String? = nil,
        summary: String? = nil,
        imageUrl: String? = nil
    ) {
        self.title = title
        self.link = link
        self.summary = summary
        self.imageUrl = imageUrl
    }
}

// MARK: - Convenience Methods

extension PodcastFeed {

    /// Returns the number of episodes in this feed.
    var episodeCount: Int {
        episodes.count
    }

    /// Returns episodes sorted by release date, most recent first.
    var sortedEpisodes: [PodcastEpisode] {
        episodes.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }
}
