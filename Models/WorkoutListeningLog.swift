import Foundation
import SwiftData

/// Records podcast listening activity during a workout.
///
/// This model is the SwiftData equivalent of the legacy `WorkoutListeningLog` Core Data entity.
/// It tracks which podcast episodes were played during a workout session, useful for
/// correlating listening history with workout performance or generating workout summaries.
///
/// Each log entry represents a point in time when a specific episode was being played.
@Model
public final class WorkoutListeningLog {

    // MARK: - Attributes

    /// The workout session ID this listening log belongs to.
    ///
    /// Links the log entry to its parent `WorkoutSession`.
    var workoutID: String

    /// Timestamp when this entry was recorded.
    ///
    /// Used to determine what was playing at a specific point during the workout.
    var time: Date?

    /// Title of the podcast feed (RSSEntity.title).
    ///
    /// Stored denormalized to preserve the value even if the feed is deleted.
    var entityTitle: String?

    /// Title of the episode that was playing.
    ///
    /// Stored denormalized to preserve the value even if the episode is deleted.
    var entryTitle: String?

    /// Summary of the episode that was playing.
    ///
    /// Stored denormalized to preserve the value even if the episode is deleted.
    var entrySummary: String?

    // MARK: - Initialization

    /// Creates a new listening log entry.
    ///
    /// - Parameters:
    ///   - workoutID: The ID of the parent workout session.
    ///   - time: When this entry was recorded.
    init(workoutID: String, time: Date? = nil) {
        self.workoutID = workoutID
        self.time = time
    }

    /// Creates a complete listening log entry.
    ///
    /// - Parameters:
    ///   - workoutID: The ID of the parent workout session.
    ///   - time: When this entry was recorded.
    ///   - entityTitle: The podcast feed title.
    ///   - entryTitle: The episode title.
    ///   - entrySummary: The episode summary.
    convenience init(
        workoutID: String,
        time: Date,
        entityTitle: String?,
        entryTitle: String?,
        entrySummary: String? = nil
    ) {
        self.init(workoutID: workoutID, time: time)
        self.entityTitle = entityTitle
        self.entryTitle = entryTitle
        self.entrySummary = entrySummary
    }

    /// Creates a listening log entry from podcast models.
    ///
    /// - Parameters:
    ///   - workoutID: The ID of the parent workout session.
    ///   - time: When this entry was recorded.
    ///   - episode: The episode being played.
    convenience init(workoutID: String, time: Date, episode: PodcastEpisode) {
        self.init(
            workoutID: workoutID,
            time: time,
            entityTitle: episode.feed?.title,
            entryTitle: episode.title,
            entrySummary: episode.summary
        )
    }
}

// MARK: - Computed Properties

extension WorkoutListeningLog {

    /// A formatted display string for the listening entry.
    var displayDescription: String {
        let podcast = entityTitle ?? "Unknown Podcast"
        let episode = entryTitle ?? "Unknown Episode"
        return "\(podcast): \(episode)"
    }

    /// Whether this log has complete podcast information.
    var hasCompleteInfo: Bool {
        entityTitle != nil && entryTitle != nil
    }
}

// MARK: - Static Fetch Helpers

extension WorkoutListeningLog {

    /// Creates a fetch descriptor for all listening logs of a workout, ordered chronologically.
    ///
    /// - Parameter workoutID: The workout ID to filter by.
    /// - Returns: A configured FetchDescriptor with chronological sort.
    static func fetchDescriptor(forWorkoutID workoutID: String) -> FetchDescriptor<WorkoutListeningLog> {
        FetchDescriptor<WorkoutListeningLog>(
            predicate: #Predicate<WorkoutListeningLog> { $0.workoutID == workoutID },
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )
    }
}
