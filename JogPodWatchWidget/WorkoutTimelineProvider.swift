//
//  WorkoutTimelineProvider.swift
//  JogPodWatchWidget
//
//  TimelineProvider for workout complications.
//  Manages timeline entries and refresh policies for WidgetKit complications.
//

import WidgetKit
import SwiftUI

// MARK: - WorkoutTimelineProvider

/// Timeline provider for workout complications.
///
/// This provider manages the creation and scheduling of timeline entries
/// for watch face complications. It reads shared data from the App Group
/// and creates appropriate entries based on workout state.
///
/// ## Timeline Strategy
///
/// - **Active Workout**: Refreshes every 30 seconds to show updated metrics
/// - **No Active Workout**: Shows last workout summary, refreshes hourly
/// - **No Data**: Shows placeholder until data becomes available
///
/// ## watchOS 10+ Features
///
/// Uses WidgetKit for complications, which provides:
/// - Consistent API with iOS widgets
/// - Automatic timeline management
/// - Efficient battery usage through scheduled updates
public struct WorkoutTimelineProvider: TimelineProvider {

    // MARK: - Types

    public typealias Entry = WorkoutComplicationEntry

    // MARK: - Constants

    /// App Group identifier for shared data.
    private static let appGroupIdentifier = "group.com.jogpod.shared"

    /// Key for storing workout data in UserDefaults.
    private static let workoutDataKey = "complicationWorkoutData"

    /// Refresh interval during active workout (seconds).
    private static let activeWorkoutRefreshInterval: TimeInterval = 30

    /// Refresh interval when no workout is active (seconds).
    private static let idleRefreshInterval: TimeInterval = 3600 // 1 hour

    // MARK: - Shared Data Access

    /// Shared UserDefaults for App Group.
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    // MARK: - TimelineProvider Protocol

    /// Provides a placeholder entry for the complication.
    ///
    /// This is used when the system needs to display a preview of the
    /// complication before real data is available.
    public func placeholder(in context: Context) -> WorkoutComplicationEntry {
        WorkoutComplicationEntry.placeholder
    }

    /// Provides a snapshot entry for gallery preview.
    ///
    /// Called when the user is browsing available complications in the
    /// watch face customization interface.
    public func getSnapshot(
        in context: Context,
        completion: @escaping (WorkoutComplicationEntry) -> Void
    ) {
        if context.isPreview {
            // Show attractive preview data for gallery
            completion(WorkoutComplicationEntry.placeholder)
        } else {
            // Show current real data
            let entry = createCurrentEntry()
            completion(entry)
        }
    }

    /// Provides a timeline of entries for the complication.
    ///
    /// Creates entries for the current time and schedules future updates
    /// based on workout state.
    public func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<WorkoutComplicationEntry>) -> Void
    ) {
        let currentDate = Date()
        let entry = createCurrentEntry()

        // Determine refresh policy based on workout state
        let refreshDate: Date
        let policy: TimelineReloadPolicy

        if entry.isWorkoutActive {
            // Active workout: refresh more frequently
            refreshDate = currentDate.addingTimeInterval(Self.activeWorkoutRefreshInterval)
            policy = .after(refreshDate)
        } else {
            // No active workout: refresh less frequently
            refreshDate = currentDate.addingTimeInterval(Self.idleRefreshInterval)
            policy = .after(refreshDate)
        }

        let timeline = Timeline(entries: [entry], policy: policy)
        completion(timeline)
    }

    // MARK: - Entry Creation

    /// Creates a timeline entry based on current workout data.
    private func createCurrentEntry() -> WorkoutComplicationEntry {
        guard let data = loadWorkoutData() else {
            return WorkoutComplicationEntry.noData
        }

        if data.isWorkoutActive {
            return createActiveWorkoutEntry(from: data)
        } else if let summary = data.lastWorkoutSummary {
            return createLastWorkoutEntry(summary: summary)
        } else {
            return WorkoutComplicationEntry.noData
        }
    }

    /// Creates an entry for an active workout.
    private func createActiveWorkoutEntry(from data: SharedWorkoutData) -> WorkoutComplicationEntry {
        let metrics = ComplicationWorkoutMetrics(
            distance: data.currentDistance,
            distanceUnit: data.distanceUnit,
            pace: data.currentPace,
            paceUnit: data.paceUnit,
            duration: data.currentDuration,
            heartRate: data.currentHeartRate,
            calories: data.currentCalories
        )

        // Higher relevance during active workout
        let relevance = TimelineEntryRelevance(score: 1.0)

        return WorkoutComplicationEntry(
            date: Date(),
            isWorkoutActive: true,
            currentMetrics: metrics,
            isConnected: data.isConnected,
            relevance: relevance
        )
    }

    /// Creates an entry showing last workout summary.
    private func createLastWorkoutEntry(summary: SharedWorkoutSummary) -> WorkoutComplicationEntry {
        let workoutSummary = ComplicationWorkoutSummary(
            workoutDate: summary.workoutDate,
            distance: summary.distance,
            distanceUnit: summary.distanceUnit,
            averagePace: summary.averagePace,
            duration: summary.duration,
            calories: summary.calories
        )

        // Lower relevance when showing past workout
        let relevance = TimelineEntryRelevance(score: 0.3)

        return WorkoutComplicationEntry(
            date: Date(),
            isWorkoutActive: false,
            lastWorkoutSummary: workoutSummary,
            isConnected: true,
            relevance: relevance
        )
    }

    // MARK: - Data Loading

    /// Loads workout data from shared App Group storage.
    private func loadWorkoutData() -> SharedWorkoutData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Self.workoutDataKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SharedWorkoutData.self, from: data)
        } catch {
            print("[WorkoutTimelineProvider] Failed to decode workout data: \(error)")
            return nil
        }
    }
}

// MARK: - SharedWorkoutData

/// Data structure for sharing workout information between app and widget.
///
/// This structure is serialized to JSON and stored in the App Group
/// UserDefaults for access by both the main app and the widget extension.
public struct SharedWorkoutData: Codable {

    // MARK: - Workout State

    /// Whether a workout is currently active.
    public let isWorkoutActive: Bool

    /// Whether the watch is connected to the iPhone.
    public let isConnected: Bool

    // MARK: - Current Workout Metrics

    /// Current distance in workout (km or mi).
    public let currentDistance: Double

    /// Unit for distance (km or mi).
    public let distanceUnit: String

    /// Current pace formatted as "M:SS".
    public let currentPace: String

    /// Unit for pace (min/km or min/mi).
    public let paceUnit: String

    /// Current duration in seconds.
    public let currentDuration: TimeInterval

    /// Current heart rate (optional).
    public let currentHeartRate: Int?

    /// Current calories burned (optional).
    public let currentCalories: Int?

    // MARK: - Last Workout Summary

    /// Summary of the last completed workout.
    public let lastWorkoutSummary: SharedWorkoutSummary?

    // MARK: - Timestamp

    /// When this data was last updated.
    public let lastUpdated: Date

    // MARK: - Initialization

    public init(
        isWorkoutActive: Bool = false,
        isConnected: Bool = true,
        currentDistance: Double = 0,
        distanceUnit: String = "km",
        currentPace: String = "--:--",
        paceUnit: String = "min/km",
        currentDuration: TimeInterval = 0,
        currentHeartRate: Int? = nil,
        currentCalories: Int? = nil,
        lastWorkoutSummary: SharedWorkoutSummary? = nil,
        lastUpdated: Date = Date()
    ) {
        self.isWorkoutActive = isWorkoutActive
        self.isConnected = isConnected
        self.currentDistance = currentDistance
        self.distanceUnit = distanceUnit
        self.currentPace = currentPace
        self.paceUnit = paceUnit
        self.currentDuration = currentDuration
        self.currentHeartRate = currentHeartRate
        self.currentCalories = currentCalories
        self.lastWorkoutSummary = lastWorkoutSummary
        self.lastUpdated = lastUpdated
    }
}

// MARK: - SharedWorkoutSummary

/// Summary of a completed workout for sharing.
public struct SharedWorkoutSummary: Codable {

    /// Date of the workout.
    public let workoutDate: Date

    /// Total distance.
    public let distance: Double

    /// Unit for distance.
    public let distanceUnit: String

    /// Average pace formatted as "M:SS".
    public let averagePace: String

    /// Total duration in seconds.
    public let duration: TimeInterval

    /// Total calories burned.
    public let calories: Int?

    public init(
        workoutDate: Date,
        distance: Double,
        distanceUnit: String,
        averagePace: String,
        duration: TimeInterval,
        calories: Int? = nil
    ) {
        self.workoutDate = workoutDate
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.averagePace = averagePace
        self.duration = duration
        self.calories = calories
    }
}

// MARK: - ComplicationDataManager

/// Manager for updating shared workout data from the main app.
///
/// The main watchOS app uses this manager to write workout data to
/// the shared App Group storage, which the widget then reads.
@MainActor
public final class ComplicationDataManager {

    // MARK: - Singleton

    public static let shared = ComplicationDataManager()

    // MARK: - Constants

    private static let appGroupIdentifier = "group.com.jogpod.shared"
    private static let workoutDataKey = "complicationWorkoutData"

    // MARK: - Properties

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Data Updates

    /// Updates the shared workout data for complications.
    ///
    /// Call this method whenever workout state changes to keep
    /// complications up to date.
    ///
    /// - Parameter data: The current workout data.
    public func updateWorkoutData(_ data: SharedWorkoutData) {
        guard let defaults = sharedDefaults else {
            print("[ComplicationDataManager] App Group not available")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(data)
            defaults.set(encodedData, forKey: Self.workoutDataKey)

            // Request complication refresh
            reloadComplications()
        } catch {
            print("[ComplicationDataManager] Failed to encode workout data: \(error)")
        }
    }

    /// Updates complications with active workout metrics.
    ///
    /// Convenience method for updating during an active workout.
    public func updateActiveWorkout(
        distance: Double,
        distanceUnit: String,
        pace: String,
        paceUnit: String,
        duration: TimeInterval,
        heartRate: Int? = nil,
        calories: Int? = nil
    ) {
        // Load existing summary
        let existingSummary = loadExistingSummary()

        let data = SharedWorkoutData(
            isWorkoutActive: true,
            isConnected: true,
            currentDistance: distance,
            distanceUnit: distanceUnit,
            currentPace: pace,
            paceUnit: paceUnit,
            currentDuration: duration,
            currentHeartRate: heartRate,
            currentCalories: calories,
            lastWorkoutSummary: existingSummary,
            lastUpdated: Date()
        )

        updateWorkoutData(data)
    }

    /// Updates complications when workout ends.
    ///
    /// - Parameter summary: Summary of the completed workout.
    public func updateWorkoutEnded(summary: SharedWorkoutSummary) {
        let data = SharedWorkoutData(
            isWorkoutActive: false,
            isConnected: true,
            lastWorkoutSummary: summary,
            lastUpdated: Date()
        )

        updateWorkoutData(data)
    }

    /// Clears all workout data (used when no workouts exist).
    public func clearWorkoutData() {
        sharedDefaults?.removeObject(forKey: Self.workoutDataKey)
        reloadComplications()
    }

    // MARK: - Private Helpers

    private func loadExistingSummary() -> SharedWorkoutSummary? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Self.workoutDataKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let workoutData = try decoder.decode(SharedWorkoutData.self, from: data)
            return workoutData.lastWorkoutSummary
        } catch {
            return nil
        }
    }

    /// Requests WidgetKit to reload all complications.
    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Requests reload of specific complication timeline.
    public func reloadTimeline(for kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
