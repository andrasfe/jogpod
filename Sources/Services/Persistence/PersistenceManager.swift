//
//  PersistenceManager.swift
//  JogPod
//
//  Created for JogPod Revival project.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - PersistenceManager Protocol

/// Protocol defining the persistence operations available in JogPod.
///
/// This protocol enables dependency injection and facilitates testing
/// by allowing mock implementations.
public protocol PersistenceManaging: Sendable {

    // MARK: Container Access

    /// The underlying model container.
    var modelContainer: ModelContainer { get }

    // MARK: Podcast Feed Operations

    func createPodcastFeed(
        title: String?,
        link: String?,
        summary: String?,
        imageUrl: String?
    ) async throws -> PersistentIdentifier

    func fetchPodcastFeed(byLink link: String) async throws -> PodcastFeed?

    func fetchAllPodcastFeeds() async throws -> [PodcastFeed]

    func deletePodcastFeed(_ identifier: PersistentIdentifier) async throws

    // MARK: Podcast Episode Operations

    func createPodcastEpisode(
        title: String?,
        identifier: String?,
        enclosureMediaLink: String?,
        releaseDate: Date?,
        feedIdentifier: PersistentIdentifier?
    ) async throws -> PersistentIdentifier

    func fetchAllPodcastEpisodes(sortedByIndex: Bool) async throws -> [PodcastEpisode]

    func fetchCurrentEpisode() async throws -> PodcastEpisode?

    func setCurrentEpisode(_ identifier: PersistentIdentifier) async throws

    func clearCurrentEpisode() async throws

    func updateEpisodeIndex(_ identifier: PersistentIdentifier, newIndex: Int32) async throws

    func deletePodcastEpisode(_ identifier: PersistentIdentifier) async throws

    func saveEpisodePosition(episodeID: PersistentIdentifier, position: TimeInterval) async throws

    func fetchEpisodePosition(episodeID: PersistentIdentifier) async throws -> TimeInterval?

    // MARK: Preference Operations

    func savePreference<T>(name: String, value: T) async throws where T: Sendable

    func fetchPreference<T>(name: String, as type: T.Type) async throws -> T?

    func fetchAllPreferences() async throws -> [Preference]

    func deletePreference(name: String) async throws

    // MARK: Workout Session Operations

    func createWorkoutSession(workoutID: String?, startTime: Date?) async throws -> PersistentIdentifier

    func fetchWorkoutSession(byID workoutID: String) async throws -> WorkoutSession?

    func fetchAllWorkoutSessions(ascending: Bool) async throws -> [WorkoutSession]

    func workoutSessionCount() async throws -> Int

    func deleteWorkoutSession(_ identifier: PersistentIdentifier) async throws

    // MARK: Workout Track Point Operations

    func createTrackPoint(
        workoutID: String,
        time: Date?,
        location: CLLocation?,
        heartRate: Int16?,
        steps: Int16?
    ) async throws -> PersistentIdentifier

    func fetchTrackPoints(forWorkoutID workoutID: String) async throws -> [WorkoutTrackPoint]

    func trackPointCount() async throws -> Int

    func deleteTrackPoint(_ identifier: PersistentIdentifier) async throws

    func deleteTrackPoints(forWorkoutID workoutID: String, at time: Date) async throws

    // MARK: Workout Listening Log Operations

    func createListeningLog(
        workoutID: String,
        time: Date?,
        entityTitle: String?,
        entryTitle: String?,
        entrySummary: String?
    ) async throws -> PersistentIdentifier

    func fetchListeningLogs(forWorkoutID workoutID: String) async throws -> [WorkoutListeningLog]

    func deleteListeningLog(_ identifier: PersistentIdentifier) async throws

    // MARK: Batch Operations

    func save() async throws

    func deleteAll<T: PersistentModel>(ofType type: T.Type) async throws
}

// MARK: - PersistenceManager Actor

/// Thread-safe persistence manager using SwiftData's @ModelActor.
///
/// This actor provides centralized data access for all JogPod persistence operations.
/// It ensures thread safety through actor isolation while leveraging SwiftData's
/// efficient batching and caching mechanisms.
///
/// ## Usage
///
/// ```swift
/// // Create manager with shared container
/// let manager = PersistenceManager(modelContainer: container)
///
/// // Perform operations
/// let feedID = try await manager.createPodcastFeed(
///     title: "My Podcast",
///     link: "https://example.com/feed.xml",
///     summary: "A great podcast",
///     imageUrl: nil
/// )
/// ```
///
/// ## Thread Safety
///
/// All operations are isolated to the actor's executor, ensuring safe concurrent access.
/// The `@ModelActor` macro automatically generates proper ModelContext handling.
@ModelActor
public actor PersistenceManager: PersistenceManaging {

    // MARK: - Static Factory Methods

    /// Creates a PersistenceManager with a production ModelContainer.
    ///
    /// - Returns: A configured PersistenceManager instance.
    /// - Throws: `PersistenceError.containerCreationFailed` if container creation fails.
    public static func makeDefault() throws -> PersistenceManager {
        do {
            let container = try JogPodSchema.makeContainer()
            return PersistenceManager(modelContainer: container)
        } catch {
            throw PersistenceError.containerCreationFailed(error.localizedDescription)
        }
    }

    /// Creates a PersistenceManager with an in-memory container for testing.
    ///
    /// - Returns: A configured PersistenceManager instance with in-memory storage.
    /// - Throws: `PersistenceError.containerCreationFailed` if container creation fails.
    public static func makeForTesting() throws -> PersistenceManager {
        do {
            let container = try JogPodSchema.makeTestContainer()
            return PersistenceManager(modelContainer: container)
        } catch {
            throw PersistenceError.containerCreationFailed(error.localizedDescription)
        }
    }

    /// Creates a PersistenceManager suitable for SwiftUI previews.
    ///
    /// This uses an in-memory store and can optionally be pre-populated with sample data.
    ///
    /// - Parameter populateSampleData: Whether to add sample data for previews.
    /// - Returns: A configured PersistenceManager instance.
    /// - Throws: `PersistenceError.containerCreationFailed` if container creation fails.
    public static func makeForPreview(populateSampleData: Bool = true) throws -> PersistenceManager {
        let manager = try makeForTesting()

        if populateSampleData {
            Task {
                try? await manager.populateSampleData()
            }
        }

        return manager
    }

    // MARK: - Podcast Feed Operations

    /// Creates a new podcast feed.
    ///
    /// - Parameters:
    ///   - title: The title of the podcast.
    ///   - link: URL to the podcast's RSS feed.
    ///   - summary: Description of the podcast.
    ///   - imageUrl: URL to the podcast artwork.
    /// - Returns: The persistent identifier of the created feed.
    /// - Throws: `PersistenceError.insertFailed` if the insert fails.
    @discardableResult
    public func createPodcastFeed(
        title: String?,
        link: String?,
        summary: String?,
        imageUrl: String?
    ) async throws -> PersistentIdentifier {
        let feed = PodcastFeed(
            title: title,
            link: link,
            summary: summary,
            imageUrl: imageUrl
        )

        modelContext.insert(feed)

        do {
            try modelContext.save()
            return feed.persistentModelID
        } catch {
            throw PersistenceError.insertFailed(
                entityName: "PodcastFeed",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches a podcast feed by its link URL.
    ///
    /// - Parameter link: The RSS feed URL to search for.
    /// - Returns: The matching feed, or nil if not found.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchPodcastFeed(byLink link: String) async throws -> PodcastFeed? {
        let descriptor = FetchDescriptor<PodcastFeed>(
            predicate: #Predicate<PodcastFeed> { $0.link == link }
        )

        do {
            let feeds = try modelContext.fetch(descriptor)
            return feeds.first
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "PodcastFeed",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches all podcast feeds.
    ///
    /// - Returns: Array of all podcast feeds.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchAllPodcastFeeds() async throws -> [PodcastFeed] {
        let descriptor = FetchDescriptor<PodcastFeed>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "PodcastFeed",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a podcast feed.
    ///
    /// Due to cascade delete rules, this will also delete all episodes belonging to the feed.
    ///
    /// - Parameter identifier: The persistent identifier of the feed to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deletePodcastFeed(_ identifier: PersistentIdentifier) async throws {
        guard let feed = modelContext.model(for: identifier) as? PodcastFeed else {
            throw PersistenceError.entityNotFound(
                entityName: "PodcastFeed",
                identifier: identifier.hashValue.description
            )
        }

        modelContext.delete(feed)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "PodcastFeed",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Podcast Episode Operations

    /// Creates a new podcast episode.
    ///
    /// - Parameters:
    ///   - title: The episode title.
    ///   - identifier: Unique identifier (typically RSS GUID).
    ///   - enclosureMediaLink: URL to the media file.
    ///   - releaseDate: Publication date.
    ///   - feedIdentifier: The parent feed's persistent identifier.
    /// - Returns: The persistent identifier of the created episode.
    /// - Throws: `PersistenceError.insertFailed` if the insert fails.
    @discardableResult
    public func createPodcastEpisode(
        title: String?,
        identifier: String?,
        enclosureMediaLink: String?,
        releaseDate: Date?,
        feedIdentifier: PersistentIdentifier?
    ) async throws -> PersistentIdentifier {
        var feed: PodcastFeed?
        if let feedId = feedIdentifier {
            feed = modelContext.model(for: feedId) as? PodcastFeed
        }

        let episode = PodcastEpisode(
            title: title,
            identifier: identifier,
            enclosureMediaLink: enclosureMediaLink,
            releaseDate: releaseDate,
            feed: feed
        )

        // Generate index based on current timestamp for ordering
        let currentCount = try await episodeCount()
        episode.index = Int32(currentCount)

        modelContext.insert(episode)

        do {
            try modelContext.save()
            return episode.persistentModelID
        } catch {
            throw PersistenceError.insertFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches all podcast episodes, optionally sorted by index.
    ///
    /// - Parameter sortedByIndex: If true, sorts by index ascending; otherwise by release date descending.
    /// - Returns: Array of all podcast episodes.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchAllPodcastEpisodes(sortedByIndex: Bool = true) async throws -> [PodcastEpisode] {
        let sortDescriptor: SortDescriptor<PodcastEpisode> = sortedByIndex
            ? SortDescriptor(\.index, order: .forward)
            : SortDescriptor(\.releaseDate, order: .reverse)

        let descriptor = FetchDescriptor<PodcastEpisode>(
            sortBy: [sortDescriptor]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches the currently playing episode.
    ///
    /// - Returns: The episode marked as current, or nil if none.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchCurrentEpisode() async throws -> PodcastEpisode? {
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate<PodcastEpisode> { $0.isCurrentInPlayer == true }
        )

        do {
            let episodes = try modelContext.fetch(descriptor)
            return episodes.first
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Sets an episode as the currently playing episode.
    ///
    /// This clears the current flag on any other episode first.
    ///
    /// - Parameter identifier: The persistent identifier of the episode to set as current.
    /// - Throws: `PersistenceError.updateFailed` if the update fails.
    public func setCurrentEpisode(_ identifier: PersistentIdentifier) async throws {
        // Clear current flag on all episodes
        try await clearCurrentEpisode()

        guard let episode = modelContext.model(for: identifier) as? PodcastEpisode else {
            throw PersistenceError.entityNotFound(
                entityName: "PodcastEpisode",
                identifier: identifier.hashValue.description
            )
        }

        episode.isCurrentInPlayer = true

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.updateFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Clears the current episode flag from all episodes.
    ///
    /// - Throws: `PersistenceError.updateFailed` if the update fails.
    public func clearCurrentEpisode() async throws {
        let descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate<PodcastEpisode> { $0.isCurrentInPlayer == true }
        )

        do {
            let currentEpisodes = try modelContext.fetch(descriptor)
            for episode in currentEpisodes {
                episode.isCurrentInPlayer = false
            }
            try modelContext.save()
        } catch {
            throw PersistenceError.updateFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Updates the index of an episode for playlist ordering.
    ///
    /// - Parameters:
    ///   - identifier: The persistent identifier of the episode.
    ///   - newIndex: The new index value.
    /// - Throws: `PersistenceError.updateFailed` if the update fails.
    public func updateEpisodeIndex(_ identifier: PersistentIdentifier, newIndex: Int32) async throws {
        guard let episode = modelContext.model(for: identifier) as? PodcastEpisode else {
            throw PersistenceError.entityNotFound(
                entityName: "PodcastEpisode",
                identifier: identifier.hashValue.description
            )
        }

        episode.index = newIndex

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.updateFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a podcast episode.
    ///
    /// - Parameter identifier: The persistent identifier of the episode to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deletePodcastEpisode(_ identifier: PersistentIdentifier) async throws {
        guard let episode = modelContext.model(for: identifier) as? PodcastEpisode else {
            throw PersistenceError.entityNotFound(
                entityName: "PodcastEpisode",
                identifier: identifier.hashValue.description
            )
        }

        modelContext.delete(episode)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Returns the count of all episodes.
    private func episodeCount() async throws -> Int {
        let descriptor = FetchDescriptor<PodcastEpisode>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Saves the playback position for an episode.
    ///
    /// - Parameters:
    ///   - episodeID: The persistent identifier of the episode.
    ///   - position: The playback position in seconds.
    /// - Throws: `PersistenceError.updateFailed` if the update fails.
    public func saveEpisodePosition(
        episodeID: PersistentIdentifier,
        position: TimeInterval
    ) async throws {
        guard let episode = modelContext.model(for: episodeID) as? PodcastEpisode else {
            throw PersistenceError.entityNotFound(
                entityName: "PodcastEpisode",
                identifier: episodeID.hashValue.description
            )
        }

        episode.savedPlaybackPosition = position

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.updateFailed(
                entityName: "PodcastEpisode",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches the saved playback position for an episode.
    ///
    /// - Parameter episodeID: The persistent identifier of the episode.
    /// - Returns: The saved position in seconds, or nil if the episode doesn't exist.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchEpisodePosition(episodeID: PersistentIdentifier) async throws -> TimeInterval? {
        guard let episode = modelContext.model(for: episodeID) as? PodcastEpisode else {
            return nil
        }

        return episode.savedPlaybackPosition
    }

    // MARK: - Preference Operations

    /// Saves a preference value.
    ///
    /// If a preference with the given name exists, it is updated.
    /// Otherwise, a new preference is created.
    ///
    /// - Parameters:
    ///   - name: The unique preference key.
    ///   - value: The value to store. Supported types: Bool, Int, Int16, Float, Double, String, Date.
    /// - Throws: `PersistenceError.saveFailed` if the save fails.
    public func savePreference<T>(name: String, value: T) async throws where T: Sendable {
        // Find existing preference or create new one
        let preference: Preference
        if let existing = try await fetchPreferenceModel(name: name) {
            preference = existing
        } else {
            preference = Preference(name: name)
            modelContext.insert(preference)
        }

        // Set the appropriate value based on type
        switch value {
        case let boolValue as Bool:
            preference.boolValue = boolValue
        case let intValue as Int:
            preference.intValue = Int16(clamping: intValue)
        case let int16Value as Int16:
            preference.intValue = int16Value
        case let floatValue as Float:
            preference.floatValue = floatValue
        case let doubleValue as Double:
            preference.floatValue = Float(doubleValue)
        case let stringValue as String:
            preference.stringValue = stringValue
        case let dateValue as Date:
            preference.dateValue = dateValue
        case let coordinate as (latitude: Double, longitude: Double):
            preference.latCoord = coordinate.latitude
            preference.longCoord = coordinate.longitude
        default:
            throw PersistenceError.validationFailed(
                entityName: "Preference",
                field: "value",
                reason: "Unsupported value type: \(type(of: value))"
            )
        }

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches a preference value.
    ///
    /// - Parameters:
    ///   - name: The preference key to look up.
    ///   - type: The expected type of the value.
    /// - Returns: The preference value, or nil if not found.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchPreference<T>(name: String, as type: T.Type) async throws -> T? {
        guard let preference = try await fetchPreferenceModel(name: name) else {
            return nil
        }

        switch type {
        case is Bool.Type:
            return preference.boolValue as? T
        case is Int.Type:
            return preference.intValue.map { Int($0) } as? T
        case is Int16.Type:
            return preference.intValue as? T
        case is Float.Type:
            return preference.floatValue as? T
        case is Double.Type:
            return preference.floatValue.map { Double($0) } as? T
        case is String.Type:
            return preference.stringValue as? T
        case is Date.Type:
            return preference.dateValue as? T
        default:
            return nil
        }
    }

    /// Fetches all preferences.
    ///
    /// - Returns: Array of all preference objects.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchAllPreferences() async throws -> [Preference] {
        let descriptor = FetchDescriptor<Preference>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "Preference",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a preference by name.
    ///
    /// - Parameter name: The preference key to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deletePreference(name: String) async throws {
        guard let preference = try await fetchPreferenceModel(name: name) else {
            return // Silently succeed if preference doesn't exist
        }

        modelContext.delete(preference)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "Preference",
                reason: error.localizedDescription
            )
        }
    }

    /// Internal helper to fetch a preference by name.
    private func fetchPreferenceModel(name: String) async throws -> Preference? {
        let descriptor = Preference.fetchDescriptor(forName: name)

        do {
            let preferences = try modelContext.fetch(descriptor)
            return preferences.first
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "Preference",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Coordinate Preference Helpers

    /// Saves a coordinate as a preference.
    ///
    /// - Parameters:
    ///   - name: The preference key.
    ///   - coordinate: The coordinate to save.
    /// - Throws: `PersistenceError.saveFailed` if the save fails.
    public func saveCoordinatePreference(name: String, coordinate: CLLocationCoordinate2D) async throws {
        let preference: Preference
        if let existing = try await fetchPreferenceModel(name: name) {
            preference = existing
        } else {
            preference = Preference(name: name)
            modelContext.insert(preference)
        }

        preference.setCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Fetches a coordinate from a preference.
    ///
    /// - Parameter name: The preference key.
    /// - Returns: The stored coordinate, or nil if not found.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchCoordinatePreference(name: String) async throws -> CLLocationCoordinate2D? {
        guard let preference = try await fetchPreferenceModel(name: name),
              let coord = preference.coordinate else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
    }

    // MARK: - Workout Session Operations

    /// Creates a new workout session.
    ///
    /// - Parameters:
    ///   - workoutID: Unique identifier for the session. Defaults to a new UUID.
    ///   - startTime: When the workout started.
    /// - Returns: The persistent identifier of the created session.
    /// - Throws: `PersistenceError.insertFailed` if the insert fails.
    @discardableResult
    public func createWorkoutSession(
        workoutID: String? = nil,
        startTime: Date? = nil
    ) async throws -> PersistentIdentifier {
        let session = WorkoutSession(workoutID: workoutID ?? UUID().uuidString)
        session.startTime = startTime

        modelContext.insert(session)

        do {
            try modelContext.save()
            return session.persistentModelID
        } catch {
            throw PersistenceError.insertFailed(
                entityName: "WorkoutSession",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches a workout session by its ID.
    ///
    /// - Parameter workoutID: The workout ID to search for.
    /// - Returns: The matching session, or nil if not found.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchWorkoutSession(byID workoutID: String) async throws -> WorkoutSession? {
        let descriptor = WorkoutSession.fetchDescriptor(forWorkoutID: workoutID)

        do {
            let sessions = try modelContext.fetch(descriptor)
            return sessions.first
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutSession",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches all workout sessions.
    ///
    /// - Parameter ascending: If true, sorts by start time ascending; otherwise descending.
    /// - Returns: Array of all workout sessions.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchAllWorkoutSessions(ascending: Bool = false) async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: ascending ? .forward : .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutSession",
                reason: error.localizedDescription
            )
        }
    }

    /// Returns the count of all workout sessions.
    ///
    /// - Returns: The number of workout sessions.
    /// - Throws: `PersistenceError.fetchFailed` if the count fails.
    public func workoutSessionCount() async throws -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>()

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutSession",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a workout session.
    ///
    /// - Parameter identifier: The persistent identifier of the session to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deleteWorkoutSession(_ identifier: PersistentIdentifier) async throws {
        guard let session = modelContext.model(for: identifier) as? WorkoutSession else {
            throw PersistenceError.entityNotFound(
                entityName: "WorkoutSession",
                identifier: identifier.hashValue.description
            )
        }

        // Also delete associated track points and listening logs
        let workoutID = session.workoutID
        try await deleteAllTrackPoints(forWorkoutID: workoutID)
        try await deleteAllListeningLogs(forWorkoutID: workoutID)

        modelContext.delete(session)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutSession",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Workout Track Point Operations

    /// Creates a new track point for a workout.
    ///
    /// - Parameters:
    ///   - workoutID: The parent workout session ID.
    ///   - time: When the point was recorded.
    ///   - location: Optional CoreLocation data.
    ///   - heartRate: Optional heart rate in BPM.
    ///   - steps: Optional step count.
    /// - Returns: The persistent identifier of the created track point.
    /// - Throws: `PersistenceError.insertFailed` if the insert fails.
    @discardableResult
    public func createTrackPoint(
        workoutID: String,
        time: Date? = nil,
        location: CLLocation? = nil,
        heartRate: Int16? = nil,
        steps: Int16? = nil
    ) async throws -> PersistentIdentifier {
        let trackPoint = WorkoutTrackPoint(workoutID: workoutID, time: time)

        if let location = location {
            trackPoint.setLocation(location)
        }

        trackPoint.heartRate = heartRate
        trackPoint.steps = steps

        modelContext.insert(trackPoint)

        do {
            try modelContext.save()
            return trackPoint.persistentModelID
        } catch {
            throw PersistenceError.insertFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches all track points for a workout, ordered chronologically.
    ///
    /// - Parameter workoutID: The workout ID to filter by.
    /// - Returns: Array of track points, ordered by time.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchTrackPoints(forWorkoutID workoutID: String) async throws -> [WorkoutTrackPoint] {
        let descriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: workoutID)

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    /// Returns the count of all track points.
    ///
    /// - Returns: The total number of track points across all workouts.
    /// - Throws: `PersistenceError.fetchFailed` if the count fails.
    public func trackPointCount() async throws -> Int {
        let descriptor = FetchDescriptor<WorkoutTrackPoint>()

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a track point.
    ///
    /// - Parameter identifier: The persistent identifier of the track point to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deleteTrackPoint(_ identifier: PersistentIdentifier) async throws {
        guard let trackPoint = modelContext.model(for: identifier) as? WorkoutTrackPoint else {
            throw PersistenceError.entityNotFound(
                entityName: "WorkoutTrackPoint",
                identifier: identifier.hashValue.description
            )
        }

        modelContext.delete(trackPoint)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes track points for a workout at a specific time.
    ///
    /// - Parameters:
    ///   - workoutID: The workout ID to filter by.
    ///   - time: The time to match.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deleteTrackPoints(forWorkoutID workoutID: String, at time: Date) async throws {
        let descriptor = FetchDescriptor<WorkoutTrackPoint>(
            predicate: #Predicate<WorkoutTrackPoint> {
                $0.workoutID == workoutID && $0.time == time
            }
        )

        do {
            let trackPoints = try modelContext.fetch(descriptor)
            for trackPoint in trackPoints {
                modelContext.delete(trackPoint)
            }
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes all track points for a workout.
    private func deleteAllTrackPoints(forWorkoutID workoutID: String) async throws {
        let descriptor = FetchDescriptor<WorkoutTrackPoint>(
            predicate: #Predicate<WorkoutTrackPoint> { $0.workoutID == workoutID }
        )

        do {
            let trackPoints = try modelContext.fetch(descriptor)
            for trackPoint in trackPoints {
                modelContext.delete(trackPoint)
            }
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutTrackPoint",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Workout Listening Log Operations

    /// Creates a new listening log entry.
    ///
    /// - Parameters:
    ///   - workoutID: The parent workout session ID.
    ///   - time: When the entry was recorded.
    ///   - entityTitle: The podcast feed title.
    ///   - entryTitle: The episode title.
    ///   - entrySummary: The episode summary.
    /// - Returns: The persistent identifier of the created log.
    /// - Throws: `PersistenceError.insertFailed` if the insert fails.
    @discardableResult
    public func createListeningLog(
        workoutID: String,
        time: Date? = nil,
        entityTitle: String?,
        entryTitle: String?,
        entrySummary: String? = nil
    ) async throws -> PersistentIdentifier {
        let log = WorkoutListeningLog(
            workoutID: workoutID,
            time: time ?? Date(),
            entityTitle: entityTitle,
            entryTitle: entryTitle,
            entrySummary: entrySummary
        )

        modelContext.insert(log)

        do {
            try modelContext.save()
            return log.persistentModelID
        } catch {
            throw PersistenceError.insertFailed(
                entityName: "WorkoutListeningLog",
                reason: error.localizedDescription
            )
        }
    }

    /// Fetches all listening logs for a workout, ordered chronologically.
    ///
    /// - Parameter workoutID: The workout ID to filter by.
    /// - Returns: Array of listening logs, ordered by time.
    /// - Throws: `PersistenceError.fetchFailed` if the fetch fails.
    public func fetchListeningLogs(forWorkoutID workoutID: String) async throws -> [WorkoutListeningLog] {
        let descriptor = WorkoutListeningLog.fetchDescriptor(forWorkoutID: workoutID)

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(
                entityName: "WorkoutListeningLog",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes a listening log.
    ///
    /// - Parameter identifier: The persistent identifier of the log to delete.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deleteListeningLog(_ identifier: PersistentIdentifier) async throws {
        guard let log = modelContext.model(for: identifier) as? WorkoutListeningLog else {
            throw PersistenceError.entityNotFound(
                entityName: "WorkoutListeningLog",
                identifier: identifier.hashValue.description
            )
        }

        modelContext.delete(log)

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutListeningLog",
                reason: error.localizedDescription
            )
        }
    }

    /// Deletes all listening logs for a workout.
    private func deleteAllListeningLogs(forWorkoutID workoutID: String) async throws {
        let descriptor = FetchDescriptor<WorkoutListeningLog>(
            predicate: #Predicate<WorkoutListeningLog> { $0.workoutID == workoutID }
        )

        do {
            let logs = try modelContext.fetch(descriptor)
            for log in logs {
                modelContext.delete(log)
            }
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: "WorkoutListeningLog",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Batch Operations

    /// Saves any pending changes to the context.
    ///
    /// - Throws: `PersistenceError.saveFailed` if the save fails.
    public func save() async throws {
        guard modelContext.hasChanges else { return }

        do {
            try modelContext.save()
        } catch {
            throw PersistenceError.saveFailed(reason: error.localizedDescription)
        }
    }

    /// Deletes all instances of a model type.
    ///
    /// - Parameter type: The type of model to delete all instances of.
    /// - Throws: `PersistenceError.deleteFailed` if the delete fails.
    public func deleteAll<T: PersistentModel>(ofType type: T.Type) async throws {
        do {
            try modelContext.delete(model: type)
            try modelContext.save()
        } catch {
            throw PersistenceError.deleteFailed(
                entityName: String(describing: type),
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Preview Data

    /// Populates the database with sample data for previews.
    private func populateSampleData() async throws {
        // Create sample podcast feed
        let feedID = try await createPodcastFeed(
            title: "Running Podcast",
            link: "https://example.com/running-podcast/feed.xml",
            summary: "A podcast about running and fitness",
            imageUrl: "https://example.com/artwork.jpg"
        )

        // Create sample episodes
        for i in 1...5 {
            _ = try await createPodcastEpisode(
                title: "Episode \(i): Running Tips",
                identifier: "ep-\(i)",
                enclosureMediaLink: "https://example.com/episode\(i).mp3",
                releaseDate: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                feedIdentifier: feedID
            )
        }

        // Create sample workout session
        let workoutID = UUID().uuidString
        _ = try await createWorkoutSession(
            workoutID: workoutID,
            startTime: Date().addingTimeInterval(-3600)
        )

        // Create sample track points
        for i in 0..<10 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001
            )
            _ = try await createTrackPoint(
                workoutID: workoutID,
                time: Date().addingTimeInterval(TimeInterval(-3600 + i * 60)),
                location: location,
                heartRate: Int16(120 + i * 2),
                steps: Int16(i * 50)
            )
        }

        // Create sample listening log
        _ = try await createListeningLog(
            workoutID: workoutID,
            time: Date().addingTimeInterval(-3500),
            entityTitle: "Running Podcast",
            entryTitle: "Episode 1: Running Tips",
            entrySummary: "Great tips for runners"
        )

        // Create sample preferences
        try await savePreference(name: "volume", value: 0.8)
        try await savePreference(name: "autoPlay", value: true)
        try await savePreference(name: "theme", value: "dark")
    }
}

// MARK: - Preview Support

extension PersistenceManager {

    /// A shared preview instance for SwiftUI previews.
    ///
    /// This instance is created lazily and uses in-memory storage.
    @MainActor
    public static let preview: PersistenceManager = {
        do {
            return try makeForPreview(populateSampleData: true)
        } catch {
            fatalError("Failed to create preview PersistenceManager: \(error)")
        }
    }()
}

// MARK: - Convenience Extensions for Main Actor Access

/// Extension providing main actor isolated access for UI-related operations.
extension PersistenceManager {

    /// Creates a new ModelContext for use on the main actor.
    ///
    /// This is useful for binding to SwiftUI views that need their own context.
    @MainActor
    public func makeMainContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}
