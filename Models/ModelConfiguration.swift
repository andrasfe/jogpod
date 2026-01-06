import Foundation
import SwiftData

/// Defines the SwiftData schema for the JogPod application.
///
/// This enum provides centralized schema configuration and factory methods
/// for creating `ModelContainer` instances.
public enum JogPodSchema {

    /// All model types in the JogPod schema.
    ///
    /// Order matters for proper relationship resolution during migration.
    static let models: [any PersistentModel.Type] = [
        PodcastFeed.self,
        PodcastEpisode.self,
        Preference.self,
        WorkoutSession.self,
        WorkoutTrackPoint.self,
        WorkoutListeningLog.self
    ]

    /// The SwiftData schema definition.
    static var schema: Schema {
        Schema(models)
    }

    /// Creates a ModelContainer for production use.
    ///
    /// - Parameter inMemory: If true, creates an in-memory store (useful for previews).
    /// - Returns: A configured ModelContainer.
    /// - Throws: If the container cannot be created.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Creates a ModelContainer for unit testing.
    ///
    /// Uses an in-memory store that is destroyed when the container is deallocated.
    ///
    /// - Returns: An in-memory ModelContainer for testing.
    /// - Throws: If the container cannot be created.
    static func makeTestContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }
}

// MARK: - Migration Support

extension JogPodSchema {

    /// Model name mappings from legacy Core Data entity names to new SwiftData model names.
    ///
    /// Use this when implementing data migration from the legacy Core Data store.
    static let legacyEntityNameMappings: [String: any PersistentModel.Type] = [
        "RSSEntity": PodcastFeed.self,
        "RSSEntry": PodcastEpisode.self,
        "Preference": Preference.self,
        "WorkoutHistory": WorkoutSession.self,
        "WorkoutLocation": WorkoutTrackPoint.self,
        "WorkoutListeningLog": WorkoutListeningLog.self
    ]

    /// Attribute name mappings for migration.
    ///
    /// Maps legacy attribute names to new attribute names where they differ.
    static let legacyAttributeNameMappings: [String: [String: String]] = [
        "RSSEntry": [
            "currentInPlayer": "isCurrentInPlayer",
            "belongsTo": "feed"
        ],
        "RSSEntity": [
            "contains": "episodes"
        ]
    ]
}
