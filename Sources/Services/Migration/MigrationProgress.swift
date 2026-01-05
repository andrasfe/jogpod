import Foundation
import Observation

/// Observable state for tracking migration progress in UI.
///
/// This class provides a SwiftUI-compatible way to observe migration progress.
/// Use it with the `DataMigrationManager` to display progress to users.
///
/// ## Usage
///
/// ```swift
/// struct MigrationView: View {
///     @State private var migrationState = MigrationProgressState()
///
///     var body: some View {
///         VStack {
///             if migrationState.isInProgress {
///                 ProgressView(value: migrationState.progress)
///                 Text(migrationState.currentPhaseDescription)
///                 Text(migrationState.statusMessage)
///             }
///         }
///         .task {
///             await runMigration()
///         }
///     }
///
///     private func runMigration() async {
///         let manager = DataMigrationManager(modelContainer: container)
///         do {
///             _ = try await manager.performMigration { progress in
///                 migrationState.update(from: progress)
///             }
///             migrationState.markComplete()
///         } catch {
///             migrationState.markFailed(error)
///         }
///     }
/// }
/// ```
@Observable
@MainActor
final class MigrationProgressState {

    // MARK: - Properties

    /// Whether migration is currently in progress.
    private(set) var isInProgress: Bool = false

    /// Whether migration has completed successfully.
    private(set) var isComplete: Bool = false

    /// Whether migration failed.
    private(set) var isFailed: Bool = false

    /// Current progress as a value from 0.0 to 1.0.
    private(set) var progress: Double = 0.0

    /// Human-readable description of the current phase.
    private(set) var currentPhaseDescription: String = ""

    /// Detailed status message.
    private(set) var statusMessage: String = ""

    /// Error if migration failed.
    private(set) var error: Error?

    /// Total number of items being processed in current phase.
    private(set) var totalItems: Int = 0

    /// Number of items processed so far in current phase.
    private(set) var processedItems: Int = 0

    /// The current migration phase.
    private(set) var currentPhase: DataMigrationManager.MigrationPhase = .preparing

    /// Migration result if completed successfully.
    private(set) var result: DataMigrationManager.MigrationResult?

    // MARK: - Initialization

    init() {}

    // MARK: - Update Methods

    /// Updates the state from a migration progress report.
    ///
    /// - Parameter progress: The progress update from the migration manager.
    func update(from progress: DataMigrationManager.MigrationProgress) {
        isInProgress = true
        isFailed = false
        error = nil

        currentPhase = progress.phase
        currentPhaseDescription = progress.phase.rawValue
        statusMessage = progress.message
        totalItems = progress.totalItems
        processedItems = progress.currentItem

        if progress.totalItems > 0 {
            self.progress = Double(progress.currentItem) / Double(progress.totalItems)
        } else {
            // Estimate progress based on phase
            self.progress = estimatedProgress(for: progress.phase)
        }

        if progress.isComplete {
            isComplete = true
            isInProgress = false
            self.progress = 1.0
        }
    }

    /// Marks the migration as complete with a result.
    ///
    /// - Parameter result: The migration result.
    func markComplete(with result: DataMigrationManager.MigrationResult? = nil) {
        self.result = result
        isComplete = true
        isInProgress = false
        isFailed = false
        progress = 1.0
        currentPhaseDescription = "Completed"
        statusMessage = result.map { "Migrated \($0.totalRecordsMigrated) records" } ?? "Migration completed"
    }

    /// Marks the migration as failed.
    ///
    /// - Parameter error: The error that caused the failure.
    func markFailed(_ error: Error) {
        self.error = error
        isFailed = true
        isInProgress = false
        isComplete = false
        currentPhaseDescription = "Failed"
        statusMessage = error.localizedDescription
    }

    /// Resets the state for a new migration attempt.
    func reset() {
        isInProgress = false
        isComplete = false
        isFailed = false
        progress = 0.0
        currentPhaseDescription = ""
        statusMessage = ""
        error = nil
        totalItems = 0
        processedItems = 0
        currentPhase = .preparing
        result = nil
    }

    // MARK: - Private Methods

    private func estimatedProgress(for phase: DataMigrationManager.MigrationPhase) -> Double {
        switch phase {
        case .preparing: return 0.0
        case .validating: return 0.05
        case .readingLegacyData: return 0.15
        case .migratingFeeds: return 0.25
        case .migratingEpisodes: return 0.40
        case .migratingPreferences: return 0.50
        case .migratingWorkouts: return 0.60
        case .migratingTrackPoints: return 0.75
        case .migratingListeningLogs: return 0.85
        case .verifying: return 0.95
        case .completing: return 0.98
        case .completed: return 1.0
        case .failed, .rolledBack: return progress // Keep current
        }
    }
}

// MARK: - Phase Display Names

extension DataMigrationManager.MigrationPhase {

    /// User-friendly description of the phase.
    var userDescription: String {
        switch self {
        case .preparing:
            return "Preparing migration..."
        case .validating:
            return "Checking legacy data..."
        case .readingLegacyData:
            return "Reading your old data..."
        case .migratingFeeds:
            return "Migrating podcasts..."
        case .migratingEpisodes:
            return "Migrating episodes..."
        case .migratingPreferences:
            return "Migrating settings..."
        case .migratingWorkouts:
            return "Migrating workout history..."
        case .migratingTrackPoints:
            return "Migrating workout tracks..."
        case .migratingListeningLogs:
            return "Migrating listening history..."
        case .verifying:
            return "Verifying migration..."
        case .completing:
            return "Finishing up..."
        case .completed:
            return "Migration complete!"
        case .failed:
            return "Migration failed"
        case .rolledBack:
            return "Migration rolled back"
        }
    }

    /// Icon name (SF Symbols) for the phase.
    var iconName: String {
        switch self {
        case .preparing, .validating:
            return "gear"
        case .readingLegacyData:
            return "doc.text.magnifyingglass"
        case .migratingFeeds:
            return "antenna.radiowaves.left.and.right"
        case .migratingEpisodes:
            return "play.circle"
        case .migratingPreferences:
            return "slider.horizontal.3"
        case .migratingWorkouts:
            return "figure.run"
        case .migratingTrackPoints:
            return "mappin.and.ellipse"
        case .migratingListeningLogs:
            return "headphones"
        case .verifying:
            return "checkmark.shield"
        case .completing:
            return "flag.checkered"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .rolledBack:
            return "arrow.uturn.backward"
        }
    }
}

// MARK: - Migration Statistics Display

extension DataMigrationManager.MigrationResult {

    /// Returns statistics suitable for display in a summary view.
    var displayStatistics: [(label: String, value: String, icon: String)] {
        [
            ("Podcasts", "\(feedsMigrated)", "antenna.radiowaves.left.and.right"),
            ("Episodes", "\(episodesMigrated)", "play.circle"),
            ("Settings", "\(preferencesMigrated)", "slider.horizontal.3"),
            ("Workouts", "\(workoutSessionsMigrated)", "figure.run"),
            ("Track Points", "\(trackPointsMigrated)", "mappin"),
            ("Listening Logs", "\(listeningLogsMigrated)", "headphones")
        ].filter { $0.value != "0" } // Only show non-zero
    }
}
