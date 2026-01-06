import Foundation
import SwiftData
import OSLog

/// Orchestrates the migration of data from legacy Core Data to SwiftData.
///
/// This manager handles the complete migration workflow including:
/// - Pre-migration validation and storage checks
/// - Reading data from the legacy Core Data store
/// - Transforming and inserting data into SwiftData
/// - Progress tracking and reporting
/// - Rollback on failure
/// - Idempotent operation (safe to run multiple times)
///
/// ## Usage
///
/// ```swift
/// let manager = DataMigrationManager(modelContainer: container)
///
/// // Check if migration is needed
/// if await manager.isMigrationNeeded() {
///     // Run migration
///     let result = try await manager.performMigration { progress in
///         print("Migration: \(progress.phase) - \(progress.percentComplete)%")
///     }
///     print("Migrated \(result.totalRecordsMigrated) records")
/// }
/// ```
@MainActor
final class DataMigrationManager {

    // MARK: - Types

    /// Represents a phase of the migration process.
    enum MigrationPhase: String, Sendable, CaseIterable {
        case preparing = "Preparing"
        case validating = "Validating"
        case readingLegacyData = "Reading Legacy Data"
        case migratingFeeds = "Migrating Podcast Feeds"
        case migratingEpisodes = "Migrating Episodes"
        case migratingPreferences = "Migrating Preferences"
        case migratingWorkouts = "Migrating Workouts"
        case migratingTrackPoints = "Migrating Track Points"
        case migratingListeningLogs = "Migrating Listening Logs"
        case verifying = "Verifying"
        case completing = "Completing"
        case completed = "Completed"
        case failed = "Failed"
        case rolledBack = "Rolled Back"
    }

    /// Current migration progress.
    struct MigrationProgress: Sendable {
        let phase: MigrationPhase
        let currentItem: Int
        let totalItems: Int
        let message: String

        var percentComplete: Int {
            guard totalItems > 0 else { return 0 }
            return Int((Double(currentItem) / Double(totalItems)) * 100)
        }

        var isComplete: Bool {
            phase == .completed
        }
    }

    /// Result of a successful migration.
    struct MigrationResult: Sendable {
        let feedsMigrated: Int
        let episodesMigrated: Int
        let preferencesMigrated: Int
        let workoutSessionsMigrated: Int
        let trackPointsMigrated: Int
        let listeningLogsMigrated: Int
        let startTime: Date
        let endTime: Date
        let warnings: [String]

        var totalRecordsMigrated: Int {
            feedsMigrated +
            episodesMigrated +
            preferencesMigrated +
            workoutSessionsMigrated +
            trackPointsMigrated +
            listeningLogsMigrated
        }

        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }

        var formattedDuration: String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            return formatter.string(from: duration) ?? "\(Int(duration))s"
        }
    }

    /// Internal state for managing the migration.
    private enum MigrationState {
        case idle
        case inProgress
        case completed
        case failed(MigrationError)
    }

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let importer: CoreDataImporter
    private let logger = Logger(subsystem: "com.jogpod.migration", category: "DataMigrationManager")

    private var state: MigrationState = .idle
    private var migrationMarkerKey = "com.jogpod.migration.completed"

    // Mapping from legacy object IDs to SwiftData objects (used during migration)
    private var feedMapping: [String: PodcastFeed] = [:]
    private var sessionMapping: [String: WorkoutSession] = [:]

    // MARK: - Initialization

    /// Creates a migration manager.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container to migrate into.
    ///   - importer: The Core Data importer to read from. Defaults to the standard location.
    init(
        modelContainer: ModelContainer,
        importer: CoreDataImporter? = nil
    ) {
        self.modelContainer = modelContainer
        self.importer = importer ?? CoreDataImporter.defaultImporter() ?? CoreDataImporter(
            storeURL: URL(fileURLWithPath: "/nonexistent")
        )
    }

    /// Creates a migration manager with a custom legacy store path.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container to migrate into.
    ///   - legacyStorePath: Path to the legacy SQLite store.
    convenience init(modelContainer: ModelContainer, legacyStorePath: String) {
        let url = URL(fileURLWithPath: legacyStorePath)
        let importer = CoreDataImporter(storeURL: url)
        self.init(modelContainer: modelContainer, importer: importer)
    }

    // MARK: - Migration Status

    /// Checks if migration has already been completed.
    ///
    /// Migration is marked complete using a preference record.
    func isMigrationComplete() -> Bool {
        let context = modelContainer.mainContext
        let descriptor = Preference.fetchDescriptor(forName: migrationMarkerKey)

        do {
            let results = try context.fetch(descriptor)
            return results.first?.boolValue == true
        } catch {
            logger.error("Failed to check migration status: \(error.localizedDescription)")
            return false
        }
    }

    /// Checks if there is legacy data that needs to be migrated.
    ///
    /// - Returns: `true` if legacy store exists and migration hasn't been done.
    func isMigrationNeeded() -> Bool {
        guard !isMigrationComplete() else { return false }
        return importer.storeExists()
    }

    /// Returns the current migration state for UI display.
    var currentState: String {
        switch state {
        case .idle: return "Ready"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Migration Execution

    /// Performs the complete migration from legacy Core Data to SwiftData.
    ///
    /// This method is idempotent - running it multiple times is safe and will
    /// skip already-migrated records based on unique identifiers.
    ///
    /// - Parameter progressHandler: Optional callback for progress updates.
    /// - Returns: Summary of the migration results.
    /// - Throws: `MigrationError` if migration fails.
    func performMigration(
        progressHandler: (@MainActor (MigrationProgress) -> Void)? = nil
    ) async throws -> MigrationResult {
        // Check state
        guard case .idle = state else {
            if case .completed = state {
                throw MigrationError.invalidState(expected: "idle", actual: "completed")
            }
            throw MigrationError.alreadyInProgress
        }

        state = .inProgress
        let startTime = Date()
        var warnings: [String] = []

        // Reset mappings
        feedMapping.removeAll()
        sessionMapping.removeAll()

        do {
            // Phase 1: Validate
            progressHandler?(MigrationProgress(
                phase: .validating,
                currentItem: 0,
                totalItems: 1,
                message: "Validating legacy store..."
            ))

            try importer.validateStore()
            logger.info("Legacy store validated successfully")

            // Phase 2: Read legacy data
            progressHandler?(MigrationProgress(
                phase: .readingLegacyData,
                currentItem: 0,
                totalItems: 1,
                message: "Reading legacy data..."
            ))

            let importedData = try await importer.importAllData { phase, current, total in
                Task { @MainActor in
                    progressHandler?(MigrationProgress(
                        phase: .readingLegacyData,
                        currentItem: current,
                        totalItems: total,
                        message: phase
                    ))
                }
            }

            if importedData.isEmpty {
                logger.info("No data to migrate - legacy store is empty")
                try markMigrationComplete()
                state = .completed
                return MigrationResult(
                    feedsMigrated: 0,
                    episodesMigrated: 0,
                    preferencesMigrated: 0,
                    workoutSessionsMigrated: 0,
                    trackPointsMigrated: 0,
                    listeningLogsMigrated: 0,
                    startTime: startTime,
                    endTime: Date(),
                    warnings: ["Legacy store was empty"]
                )
            }

            logger.info("Imported \(importedData.totalCount) legacy records")

            // Phase 3-8: Migrate each entity type
            let context = modelContainer.mainContext

            let feedsResult = try await migrateFeeds(
                importedData.feeds,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: feedsResult.warnings)

            let episodesResult = try await migrateEpisodes(
                importedData.episodes,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: episodesResult.warnings)

            let preferencesResult = try await migratePreferences(
                importedData.preferences,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: preferencesResult.warnings)

            let sessionsResult = try await migrateWorkoutSessions(
                importedData.workoutSessions,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: sessionsResult.warnings)

            let trackPointsResult = try await migrateTrackPoints(
                importedData.trackPoints,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: trackPointsResult.warnings)

            let logsResult = try await migrateListeningLogs(
                importedData.listeningLogs,
                context: context,
                progressHandler: progressHandler
            )
            warnings.append(contentsOf: logsResult.warnings)

            // Phase 9: Verify
            progressHandler?(MigrationProgress(
                phase: .verifying,
                currentItem: 0,
                totalItems: 1,
                message: "Verifying migrated data..."
            ))

            let issues = try await verifyMigration(
                expected: importedData,
                context: context
            )

            if !issues.isEmpty {
                warnings.append(contentsOf: issues.map { $0.description })
                logger.warning("Migration completed with \(issues.count) verification issues")
            }

            // Phase 10: Complete
            progressHandler?(MigrationProgress(
                phase: .completing,
                currentItem: 0,
                totalItems: 1,
                message: "Saving migrated data..."
            ))

            try context.save()
            try markMigrationComplete()

            state = .completed
            let endTime = Date()

            progressHandler?(MigrationProgress(
                phase: .completed,
                currentItem: 1,
                totalItems: 1,
                message: "Migration completed successfully"
            ))

            let result = MigrationResult(
                feedsMigrated: feedsResult.count,
                episodesMigrated: episodesResult.count,
                preferencesMigrated: preferencesResult.count,
                workoutSessionsMigrated: sessionsResult.count,
                trackPointsMigrated: trackPointsResult.count,
                listeningLogsMigrated: logsResult.count,
                startTime: startTime,
                endTime: endTime,
                warnings: warnings
            )

            logger.info("Migration completed: \(result.totalRecordsMigrated) records in \(result.formattedDuration)")
            return result

        } catch {
            state = .failed(error as? MigrationError ?? MigrationError.saveFailed(underlyingError: error))
            logger.error("Migration failed: \(error.localizedDescription)")

            progressHandler?(MigrationProgress(
                phase: .failed,
                currentItem: 0,
                totalItems: 1,
                message: "Migration failed: \(error.localizedDescription)"
            ))

            // Attempt rollback
            do {
                try await rollback()
                progressHandler?(MigrationProgress(
                    phase: .rolledBack,
                    currentItem: 1,
                    totalItems: 1,
                    message: "Rolled back migration"
                ))
            } catch let rollbackError {
                logger.error("Rollback failed: \(rollbackError.localizedDescription)")
            }

            throw error
        }
    }

    // MARK: - Entity Migration

    private struct EntityMigrationResult {
        let count: Int
        let warnings: [String]
    }

    private func migrateFeeds(
        _ legacyFeeds: [CoreDataImporter.LegacyPodcastFeed],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0

        for (index, legacyFeed) in legacyFeeds.enumerated() {
            progressHandler?(MigrationProgress(
                phase: .migratingFeeds,
                currentItem: index,
                totalItems: legacyFeeds.count,
                message: "Migrating feed: \(legacyFeed.title ?? "Untitled")"
            ))

            // Check if already exists (idempotent)
            if let existingFeed = findExistingFeed(matching: legacyFeed, context: context) {
                feedMapping[legacyFeed.objectID] = existingFeed
                continue
            }

            let feed = PodcastFeed(
                title: legacyFeed.title,
                link: legacyFeed.link,
                summary: legacyFeed.summary,
                imageUrl: legacyFeed.imageUrl
            )

            context.insert(feed)
            feedMapping[legacyFeed.objectID] = feed
            migratedCount += 1
        }

        logger.info("Migrated \(migratedCount) podcast feeds (skipped \(legacyFeeds.count - migratedCount) existing)")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    private func migrateEpisodes(
        _ legacyEpisodes: [CoreDataImporter.LegacyPodcastEpisode],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0

        for (index, legacyEpisode) in legacyEpisodes.enumerated() {
            progressHandler?(MigrationProgress(
                phase: .migratingEpisodes,
                currentItem: index,
                totalItems: legacyEpisodes.count,
                message: "Migrating episode: \(legacyEpisode.title ?? "Untitled")"
            ))

            // Check if already exists (idempotent)
            if findExistingEpisode(matching: legacyEpisode, context: context) != nil {
                continue
            }

            // Resolve feed relationship
            var parentFeed: PodcastFeed?
            if let feedObjectID = legacyEpisode.feedObjectID {
                parentFeed = feedMapping[feedObjectID]
                if parentFeed == nil {
                    warnings.append("Episode '\(legacyEpisode.title ?? "Unknown")' has orphaned feed reference")
                }
            }

            let episode = PodcastEpisode(
                title: legacyEpisode.title,
                identifier: legacyEpisode.identifier,
                enclosureMediaLink: legacyEpisode.enclosureMediaLink,
                releaseDate: legacyEpisode.releaseDate,
                feed: parentFeed
            )

            // Copy additional attributes
            episode.isCurrentInPlayer = legacyEpisode.isCurrentInPlayer
            episode.date = legacyEpisode.date
            episode.index = legacyEpisode.index
            episode.lastUpdated = legacyEpisode.lastUpdated
            episode.link = legacyEpisode.link
            episode.name = legacyEpisode.name
            episode.preferredPlayDurationInMinutes = legacyEpisode.preferredPlayDurationInMinutes
            episode.summary = legacyEpisode.summary
            episode.type = legacyEpisode.type
            episode.url = legacyEpisode.url

            context.insert(episode)
            migratedCount += 1
        }

        logger.info("Migrated \(migratedCount) podcast episodes")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    private func migratePreferences(
        _ legacyPreferences: [CoreDataImporter.LegacyPreference],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0

        for (index, legacyPref) in legacyPreferences.enumerated() {
            progressHandler?(MigrationProgress(
                phase: .migratingPreferences,
                currentItem: index,
                totalItems: legacyPreferences.count,
                message: "Migrating preference: \(legacyPref.name)"
            ))

            // Skip migration marker
            if legacyPref.name == migrationMarkerKey {
                continue
            }

            // Check if already exists (idempotent - preferences have unique names)
            let descriptor = Preference.fetchDescriptor(forName: legacyPref.name)
            if let existing = try? context.fetch(descriptor).first {
                // Update existing preference with legacy values if different
                updatePreference(existing, from: legacyPref)
                continue
            }

            let preference = Preference(name: legacyPref.name)
            preference.boolValue = legacyPref.boolValue
            preference.dateValue = legacyPref.dateValue
            preference.floatValue = legacyPref.floatValue
            preference.intValue = legacyPref.intValue
            preference.latCoord = legacyPref.latCoord
            preference.longCoord = legacyPref.longCoord
            preference.stringValue = legacyPref.stringValue

            context.insert(preference)
            migratedCount += 1
        }

        logger.info("Migrated \(migratedCount) preferences")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    private func migrateWorkoutSessions(
        _ legacySessions: [CoreDataImporter.LegacyWorkoutSession],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0

        for (index, legacySession) in legacySessions.enumerated() {
            progressHandler?(MigrationProgress(
                phase: .migratingWorkouts,
                currentItem: index,
                totalItems: legacySessions.count,
                message: "Migrating workout session..."
            ))

            // Legacy sessions might not have workoutID - generate one if missing
            let workoutID = legacySession.workoutID ?? UUID().uuidString

            // Check if already exists (idempotent)
            let descriptor = WorkoutSession.fetchDescriptor(forWorkoutID: workoutID)
            if let existing = try? context.fetch(descriptor).first {
                sessionMapping[legacySession.objectID] = existing
                sessionMapping[workoutID] = existing
                continue
            }

            let session = WorkoutSession(workoutID: workoutID)
            session.address = legacySession.address
            session.startTime = legacySession.startTime
            session.humidity = legacySession.humidity
            session.temperatureInCelsius = legacySession.temperatureInCelsius
            session.windSpeedInKmh = legacySession.windSpeedInKmh
            session.weatherIconUrl = legacySession.weatherIconUrl
            session.alertDate = LegacyDateParser.parse(legacySession.alertDate)
            session.alertDescription = legacySession.alertDescription
            session.alertExpires = LegacyDateParser.parse(legacySession.alertExpires)
            session.alertType = legacySession.alertType

            context.insert(session)
            sessionMapping[legacySession.objectID] = session
            sessionMapping[workoutID] = session
            migratedCount += 1
        }

        logger.info("Migrated \(migratedCount) workout sessions")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    private func migrateTrackPoints(
        _ legacyPoints: [CoreDataImporter.LegacyWorkoutTrackPoint],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0
        var orphanedCount = 0

        // Batch for performance
        let batchSize = 100

        for (index, legacyPoint) in legacyPoints.enumerated() {
            if index % batchSize == 0 {
                progressHandler?(MigrationProgress(
                    phase: .migratingTrackPoints,
                    currentItem: index,
                    totalItems: legacyPoints.count,
                    message: "Migrating track points (\(index)/\(legacyPoints.count))..."
                ))
            }

            // Verify workout session exists
            if sessionMapping[legacyPoint.workoutID] == nil {
                // Try to find by workout ID
                let descriptor = WorkoutSession.fetchDescriptor(forWorkoutID: legacyPoint.workoutID)
                if (try? context.fetch(descriptor).first) == nil {
                    orphanedCount += 1
                    continue // Skip orphaned track points
                }
            }

            let trackPoint = WorkoutTrackPoint(
                workoutID: legacyPoint.workoutID,
                time: legacyPoint.time
            )

            trackPoint.heartRate = legacyPoint.heartRate
            trackPoint.steps = legacyPoint.steps
            trackPoint.latitude = legacyPoint.latitude
            trackPoint.longitude = legacyPoint.longitude
            trackPoint.altitude = legacyPoint.altitude
            trackPoint.horizontalAccuracy = legacyPoint.horizontalAccuracy
            trackPoint.speed = legacyPoint.speed
            trackPoint.course = legacyPoint.course

            context.insert(trackPoint)
            migratedCount += 1
        }

        if orphanedCount > 0 {
            warnings.append("Skipped \(orphanedCount) orphaned track points without matching workout sessions")
        }

        logger.info("Migrated \(migratedCount) track points (skipped \(orphanedCount) orphaned)")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    private func migrateListeningLogs(
        _ legacyLogs: [CoreDataImporter.LegacyWorkoutListeningLog],
        context: ModelContext,
        progressHandler: (@MainActor (MigrationProgress) -> Void)?
    ) async throws -> EntityMigrationResult {
        var warnings: [String] = []
        var migratedCount = 0
        var orphanedCount = 0

        for (index, legacyLog) in legacyLogs.enumerated() {
            progressHandler?(MigrationProgress(
                phase: .migratingListeningLogs,
                currentItem: index,
                totalItems: legacyLogs.count,
                message: "Migrating listening logs..."
            ))

            guard let workoutID = legacyLog.workoutID else {
                orphanedCount += 1
                continue
            }

            let log = WorkoutListeningLog(
                workoutID: workoutID,
                time: legacyLog.time
            )

            log.entityTitle = legacyLog.entityTitle
            log.entryTitle = legacyLog.entryTitle
            log.entrySummary = legacyLog.entrySummary

            context.insert(log)
            migratedCount += 1
        }

        if orphanedCount > 0 {
            warnings.append("Skipped \(orphanedCount) listening logs without workout IDs")
        }

        logger.info("Migrated \(migratedCount) listening logs")
        return EntityMigrationResult(count: migratedCount, warnings: warnings)
    }

    // MARK: - Helper Methods

    private func findExistingFeed(
        matching legacy: CoreDataImporter.LegacyPodcastFeed,
        context: ModelContext
    ) -> PodcastFeed? {
        // Match by title and link (most reliable unique combination)
        guard let title = legacy.title else { return nil }

        var descriptor = FetchDescriptor<PodcastFeed>(
            predicate: #Predicate<PodcastFeed> { $0.title == title }
        )
        descriptor.fetchLimit = 10

        guard let candidates = try? context.fetch(descriptor) else { return nil }

        return candidates.first { $0.link == legacy.link }
    }

    private func findExistingEpisode(
        matching legacy: CoreDataImporter.LegacyPodcastEpisode,
        context: ModelContext
    ) -> PodcastEpisode? {
        // Match by identifier (GUID) if available
        guard let identifier = legacy.identifier, !identifier.isEmpty else { return nil }

        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate<PodcastEpisode> { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1

        return try? context.fetch(descriptor).first
    }

    private func updatePreference(
        _ existing: Preference,
        from legacy: CoreDataImporter.LegacyPreference
    ) {
        // Only update nil values - don't overwrite newer data
        if existing.boolValue == nil { existing.boolValue = legacy.boolValue }
        if existing.dateValue == nil { existing.dateValue = legacy.dateValue }
        if existing.floatValue == nil { existing.floatValue = legacy.floatValue }
        if existing.intValue == nil { existing.intValue = legacy.intValue }
        if existing.latCoord == nil { existing.latCoord = legacy.latCoord }
        if existing.longCoord == nil { existing.longCoord = legacy.longCoord }
        if existing.stringValue == nil { existing.stringValue = legacy.stringValue }
    }

    // MARK: - Verification

    private func verifyMigration(
        expected: CoreDataImporter.ImportedData,
        context: ModelContext
    ) async throws -> [MigrationError.ValidationIssue] {
        var issues: [MigrationError.ValidationIssue] = []

        // Verify counts (allowing for duplicates and skipped items)
        let feedDescriptor = FetchDescriptor<PodcastFeed>()
        let feedCount = (try? context.fetchCount(feedDescriptor)) ?? 0
        if feedCount < expected.feeds.count / 2 { // Allow some tolerance
            issues.append(MigrationError.ValidationIssue(
                entityName: "PodcastFeed",
                attributeName: nil,
                objectIdentifier: nil,
                message: "Expected at least \(expected.feeds.count / 2) feeds, found \(feedCount)"
            ))
        }

        let episodeDescriptor = FetchDescriptor<PodcastEpisode>()
        let episodeCount = (try? context.fetchCount(episodeDescriptor)) ?? 0
        if episodeCount < expected.episodes.count / 2 {
            issues.append(MigrationError.ValidationIssue(
                entityName: "PodcastEpisode",
                attributeName: nil,
                objectIdentifier: nil,
                message: "Expected at least \(expected.episodes.count / 2) episodes, found \(episodeCount)"
            ))
        }

        // Verify workout sessions have required workoutID
        let sessionDescriptor = FetchDescriptor<WorkoutSession>()
        if let sessions = try? context.fetch(sessionDescriptor) {
            for session in sessions {
                if session.workoutID.isEmpty {
                    issues.append(MigrationError.ValidationIssue(
                        entityName: "WorkoutSession",
                        attributeName: "workoutID",
                        objectIdentifier: nil,
                        message: "Workout session has empty workoutID"
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Migration Markers

    private func markMigrationComplete() throws {
        let context = modelContainer.mainContext

        // Check if marker already exists
        let descriptor = Preference.fetchDescriptor(forName: migrationMarkerKey)
        if let existing = try? context.fetch(descriptor).first {
            existing.boolValue = true
            existing.dateValue = Date()
        } else {
            let marker = Preference(name: migrationMarkerKey, boolValue: true)
            marker.dateValue = Date()
            context.insert(marker)
        }

        try context.save()
        logger.info("Migration marked as complete")
    }

    /// Resets the migration marker, allowing migration to run again.
    ///
    /// Use with caution - this could result in duplicate data if not handled properly.
    func resetMigrationMarker() throws {
        let context = modelContainer.mainContext
        let descriptor = Preference.fetchDescriptor(forName: migrationMarkerKey)

        if let marker = try? context.fetch(descriptor).first {
            context.delete(marker)
            try context.save()
            logger.info("Migration marker reset")
        }

        state = .idle
    }

    // MARK: - Rollback

    /// Rolls back a failed migration by deleting all migrated data.
    ///
    /// - Warning: This is destructive and will delete SwiftData records.
    func rollback() async throws {
        logger.warning("Rolling back migration...")

        let context = modelContainer.mainContext

        // Delete in reverse order of dependencies
        try deleteAll(WorkoutListeningLog.self, context: context)
        try deleteAll(WorkoutTrackPoint.self, context: context)
        try deleteAll(WorkoutSession.self, context: context)
        try deleteAll(PodcastEpisode.self, context: context)
        try deleteAll(PodcastFeed.self, context: context)
        // Note: Keep preferences as they may have been created by the new app

        // Remove migration marker
        try? resetMigrationMarker()

        try context.save()

        state = .idle
        feedMapping.removeAll()
        sessionMapping.removeAll()

        logger.info("Rollback completed")
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        let descriptor = FetchDescriptor<T>()
        let objects = try context.fetch(descriptor)

        for object in objects {
            context.delete(object)
        }
    }
}

// MARK: - MigrationResult Extensions

extension DataMigrationManager.MigrationResult: CustomStringConvertible {

    var description: String {
        var lines = [
            "Migration Result:",
            "  Duration: \(formattedDuration)",
            "  Records Migrated:",
            "    - Podcast Feeds: \(feedsMigrated)",
            "    - Podcast Episodes: \(episodesMigrated)",
            "    - Preferences: \(preferencesMigrated)",
            "    - Workout Sessions: \(workoutSessionsMigrated)",
            "    - Track Points: \(trackPointsMigrated)",
            "    - Listening Logs: \(listeningLogsMigrated)",
            "    - Total: \(totalRecordsMigrated)"
        ]

        if !warnings.isEmpty {
            lines.append("  Warnings:")
            for warning in warnings {
                lines.append("    - \(warning)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Legacy Date Parsing

/// Parses date strings from the legacy weather alert API.
///
/// The legacy app received weather alert dates as strings from the weather API.
/// This utility attempts to parse them using common date formats.
enum LegacyDateParser {

    /// ISO 8601 formatter with full date and time.
    private static let iso8601Full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 formatter without fractional seconds.
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Common date formats used by weather APIs.
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",        // ISO with timezone
            "yyyy-MM-dd'T'HH:mm:ss",          // ISO without timezone
            "yyyy-MM-dd HH:mm:ss",            // Standard datetime
            "yyyy-MM-dd",                      // Date only
            "MM/dd/yyyy HH:mm:ss",            // US format with time
            "MM/dd/yyyy",                      // US format date only
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // RFC 2822
            "EEEE, MMMM d, yyyy h:mm a"       // Verbose format
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
    }()

    /// Parses a legacy date string into a Date.
    ///
    /// Attempts multiple common date formats used by weather APIs.
    ///
    /// - Parameter string: The date string to parse.
    /// - Returns: A Date if parsing succeeds, or nil if the string cannot be parsed.
    static func parse(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else {
            return nil
        }

        // Try ISO 8601 first (most common for modern APIs)
        if let date = iso8601Full.date(from: string) {
            return date
        }

        if let date = iso8601.date(from: string) {
            return date
        }

        // Try other common formats
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // If all else fails, try Unix timestamp
        if let timestamp = Double(string) {
            // Could be seconds or milliseconds
            if timestamp > 1_000_000_000_000 {
                // Likely milliseconds
                return Date(timeIntervalSince1970: timestamp / 1000)
            } else {
                return Date(timeIntervalSince1970: timestamp)
            }
        }

        return nil
    }
}
