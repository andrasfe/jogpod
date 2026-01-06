//
//  WorkoutListeningLogService.swift
//  JogPod
//
//  Service for tracking podcast listening activity during workouts.
//

import Foundation
import SwiftData
import Combine

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a listening event is logged during a workout.
    public static let workoutListeningEventLogged = Notification.Name("workoutListeningEventLogged")
}

// MARK: - WorkoutListeningLogServiceProtocol

/// Protocol defining the listening log service interface for dependency injection.
public protocol WorkoutListeningLogServiceProtocol: Sendable {

    /// Logs a listening event for the current workout if conditions are met.
    ///
    /// - Parameters:
    ///   - episodeID: The episode's persistent identifier.
    ///   - episodeTitle: The episode title.
    ///   - podcastTitle: The podcast feed title.
    ///   - episodeSummary: Optional episode summary.
    ///   - isPlaying: Whether the player is currently playing.
    func logListeningEvent(
        episodeID: String?,
        episodeTitle: String?,
        podcastTitle: String?,
        episodeSummary: String?,
        isPlaying: Bool
    ) async

    /// Logs a listening event using a PlayableItem.
    ///
    /// - Parameters:
    ///   - item: The playable item currently being played.
    ///   - isPlaying: Whether the player is currently playing.
    func logListeningEvent(
        item: PlayableItem,
        isPlaying: Bool
    ) async

    /// Resets the tracking state.
    ///
    /// Call this when a workout ends to ensure fresh tracking for the next workout.
    func resetTrackingState() async

    /// Fetches all listening logs for a specific workout.
    ///
    /// - Parameter workoutID: The workout session ID.
    /// - Returns: Array of listening logs ordered chronologically.
    func fetchListeningLogs(forWorkoutID workoutID: String) async throws -> [WorkoutListeningLog]
}

// MARK: - WorkoutListeningLogService

/// Service for tracking podcast listening activity during active workouts.
///
/// This service is the Swift modernization of the legacy `logWorkoutListeningEventForPodcast`
/// method from `PlayerController.m`. It tracks which episodes are played during workout
/// sessions, creating `WorkoutListeningLog` entries in the database.
///
/// ## Deduplication
///
/// The service tracks the last logged episode per workout to avoid creating duplicate
/// log entries when the same episode is playing during repeated timer callbacks.
///
/// ## Integration Points
///
/// - **AudioPlayerService**: Should call `logListeningEvent` during playback timer events
/// - **WorkoutService**: Provides the active workout ID for logging
///
/// ## Usage
///
/// ```swift
/// let logService = WorkoutListeningLogService(
///     persistence: persistenceManager,
///     workoutService: workoutService
/// )
///
/// // During playback timer events
/// await logService.logListeningEvent(
///     item: currentPlayableItem,
///     isPlaying: audioPlayer.isPlaying
/// )
///
/// // When workout ends
/// await logService.resetTrackingState()
/// ```
public actor WorkoutListeningLogService: WorkoutListeningLogServiceProtocol {

    // MARK: - Tracking State

    /// Represents the last logged episode for deduplication.
    private struct LastLoggedEntry: Equatable {
        let episodeID: String
        let workoutID: String
    }

    // MARK: - Dependencies

    private let persistence: PersistenceManaging
    private let workoutService: WorkoutServiceProtocol

    // MARK: - State

    /// Tracks the last logged entry to prevent duplicate logging.
    private var lastLoggedEntry: LastLoggedEntry?

    // MARK: - Initialization

    /// Creates a new WorkoutListeningLogService.
    ///
    /// - Parameters:
    ///   - persistence: The persistence manager for database operations.
    ///   - workoutService: The workout service for checking active workout state.
    public init(
        persistence: PersistenceManaging,
        workoutService: WorkoutServiceProtocol
    ) {
        self.persistence = persistence
        self.workoutService = workoutService
    }

    // MARK: - Public Interface

    /// Logs a listening event for the current workout if conditions are met.
    ///
    /// This method mirrors the legacy `logWorkoutListeningEventForPodcast:` behavior:
    /// - Only logs if a workout is in progress
    /// - Only logs if the player is actively playing
    /// - Avoids duplicate logging for the same episode in the same workout
    ///
    /// - Parameters:
    ///   - episodeID: The episode's unique identifier (typically RSS GUID).
    ///   - episodeTitle: The episode title.
    ///   - podcastTitle: The podcast feed title.
    ///   - episodeSummary: Optional episode summary.
    ///   - isPlaying: Whether the player is currently playing.
    public func logListeningEvent(
        episodeID: String?,
        episodeTitle: String?,
        podcastTitle: String?,
        episodeSummary: String?,
        isPlaying: Bool
    ) async {
        // Guard: Only log when player is actively playing
        guard isPlaying else {
            return
        }

        // Guard: Only log when a workout is in progress
        guard await workoutService.isWorkoutInProgress else {
            return
        }

        // Get the active workout ID
        guard let workoutID = await workoutService.activeWorkoutID else {
            return
        }

        // Guard: Need at least an episode identifier for deduplication
        guard let episodeID = episodeID, !episodeID.isEmpty else {
            return
        }

        // Check for duplicate logging
        let currentEntry = LastLoggedEntry(episodeID: episodeID, workoutID: workoutID)
        if currentEntry == lastLoggedEntry {
            return
        }

        // Create the listening log entry
        do {
            _ = try await persistence.createListeningLog(
                workoutID: workoutID,
                time: Date(),
                entityTitle: podcastTitle,
                entryTitle: episodeTitle,
                entrySummary: episodeSummary
            )

            // Update tracking state
            lastLoggedEntry = currentEntry

            // Post notification
            await postListeningEventNotification(
                workoutID: workoutID,
                episodeTitle: episodeTitle,
                podcastTitle: podcastTitle
            )

            #if DEBUG
            print("[WorkoutListeningLogService] Logged listening event: \(podcastTitle ?? "Unknown") - \(episodeTitle ?? "Unknown")")
            #endif

        } catch {
            // Log but don't throw - listening log failures shouldn't interrupt playback
            #if DEBUG
            print("[WorkoutListeningLogService] Failed to log listening event: \(error)")
            #endif
        }
    }

    /// Logs a listening event using a PlayableItem.
    ///
    /// Convenience method that extracts the necessary information from a `PlayableItem`.
    ///
    /// - Parameters:
    ///   - item: The playable item currently being played.
    ///   - isPlaying: Whether the player is currently playing.
    public func logListeningEvent(
        item: PlayableItem,
        isPlaying: Bool
    ) async {
        await logListeningEvent(
            episodeID: item.id,
            episodeTitle: item.title,
            podcastTitle: item.podcastTitle,
            episodeSummary: nil, // PlayableItem doesn't carry summary
            isPlaying: isPlaying
        )
    }

    /// Resets the tracking state.
    ///
    /// Call this method when a workout ends to ensure the next workout
    /// starts with a clean tracking slate. This allows the first episode
    /// of a new workout to be logged even if it was the last episode
    /// logged in the previous workout.
    public func resetTrackingState() async {
        lastLoggedEntry = nil

        #if DEBUG
        print("[WorkoutListeningLogService] Tracking state reset")
        #endif
    }

    /// Fetches all listening logs for a specific workout.
    ///
    /// - Parameter workoutID: The workout session ID.
    /// - Returns: Array of listening logs ordered chronologically.
    /// - Throws: `PersistenceError` if the fetch fails.
    public func fetchListeningLogs(forWorkoutID workoutID: String) async throws -> [WorkoutListeningLog] {
        try await persistence.fetchListeningLogs(forWorkoutID: workoutID)
    }

    // MARK: - Notifications

    /// Posts a notification when a listening event is logged.
    @MainActor
    private func postListeningEventNotification(
        workoutID: String,
        episodeTitle: String?,
        podcastTitle: String?
    ) {
        NotificationCenter.default.post(
            name: .workoutListeningEventLogged,
            object: nil,
            userInfo: [
                "workoutID": workoutID,
                "episodeTitle": episodeTitle as Any,
                "podcastTitle": podcastTitle as Any
            ]
        )
    }
}

// MARK: - Factory Methods

extension WorkoutListeningLogService {

    /// Creates a WorkoutListeningLogService with the provided dependencies.
    ///
    /// - Parameters:
    ///   - persistence: The persistence manager.
    ///   - workoutService: The workout service.
    /// - Returns: A configured WorkoutListeningLogService instance.
    public static func make(
        persistence: PersistenceManaging,
        workoutService: WorkoutServiceProtocol
    ) -> WorkoutListeningLogService {
        WorkoutListeningLogService(
            persistence: persistence,
            workoutService: workoutService
        )
    }
}

// MARK: - Listening Log Summary

/// A summary of listening activity during a workout.
public struct WorkoutListeningSummary: Sendable, Equatable {

    /// The workout session ID.
    public let workoutID: String

    /// All episodes listened to during the workout.
    public let episodes: [ListenedEpisode]

    /// Total number of unique episodes played.
    public var episodeCount: Int {
        episodes.count
    }

    /// Total number of unique podcasts played.
    public var podcastCount: Int {
        Set(episodes.compactMap { $0.podcastTitle }).count
    }

    /// A brief text summary for display.
    public var briefSummary: String {
        if episodes.isEmpty {
            return "No podcasts played during this workout"
        }

        let episodeText = episodeCount == 1 ? "episode" : "episodes"
        let podcastText = podcastCount == 1 ? "podcast" : "podcasts"

        return "Listened to \(episodeCount) \(episodeText) from \(podcastCount) \(podcastText)"
    }

    /// Creates a summary from listening logs.
    ///
    /// - Parameters:
    ///   - workoutID: The workout session ID.
    ///   - logs: The listening logs to summarize.
    public init(workoutID: String, logs: [WorkoutListeningLog]) {
        self.workoutID = workoutID

        // Deduplicate by episode title (logs may have multiple entries for same episode)
        var seenTitles = Set<String>()
        var uniqueEpisodes: [ListenedEpisode] = []

        for log in logs {
            let key = "\(log.entityTitle ?? "")-\(log.entryTitle ?? "")"
            if !seenTitles.contains(key) {
                seenTitles.insert(key)
                uniqueEpisodes.append(ListenedEpisode(
                    podcastTitle: log.entityTitle,
                    episodeTitle: log.entryTitle,
                    startTime: log.time
                ))
            }
        }

        self.episodes = uniqueEpisodes
    }
}

/// Represents an episode that was listened to during a workout.
public struct ListenedEpisode: Sendable, Equatable, Identifiable {

    /// Unique identifier for the episode in the context of this summary.
    public var id: String {
        "\(podcastTitle ?? "")-\(episodeTitle ?? "")"
    }

    /// The podcast feed title.
    public let podcastTitle: String?

    /// The episode title.
    public let episodeTitle: String?

    /// When listening to this episode started.
    public let startTime: Date?

    /// A display string for the episode.
    public var displayDescription: String {
        let podcast = podcastTitle ?? "Unknown Podcast"
        let episode = episodeTitle ?? "Unknown Episode"
        return "\(podcast): \(episode)"
    }
}

// MARK: - Convenience Extension for Fetching Summary

extension WorkoutListeningLogService {

    /// Fetches a listening summary for a specific workout.
    ///
    /// - Parameter workoutID: The workout session ID.
    /// - Returns: A summary of listening activity during the workout.
    /// - Throws: `PersistenceError` if the fetch fails.
    public func fetchListeningSummary(forWorkoutID workoutID: String) async throws -> WorkoutListeningSummary {
        let logs = try await fetchListeningLogs(forWorkoutID: workoutID)
        return WorkoutListeningSummary(workoutID: workoutID, logs: logs)
    }
}
