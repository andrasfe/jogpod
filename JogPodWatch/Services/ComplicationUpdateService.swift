//
//  ComplicationUpdateService.swift
//  JogPodWatch
//
//  Service for updating watch face complications with workout data.
//  Bridges WatchState changes to the ComplicationDataManager for WidgetKit updates.
//

import Foundation
import WidgetKit
import Combine

// MARK: - ComplicationUpdateService

/// Service that bridges WatchState to complication updates.
///
/// This service observes changes to the app's workout state and
/// pushes updates to the shared App Group storage so that
/// WidgetKit complications can display current data.
///
/// ## Architecture
///
/// ```
/// WatchState -> ComplicationUpdateService -> SharedWorkoutData -> WidgetKit
/// ```
///
/// ## Update Triggers
///
/// Updates are triggered when:
/// - Workout starts or stops
/// - Workout metrics are updated
/// - Connection state changes
/// - Stats are received for completed workout
@MainActor
public final class ComplicationUpdateService: ObservableObject {

    // MARK: - Singleton

    public static let shared = ComplicationUpdateService()

    // MARK: - Constants

    /// App Group identifier for shared data.
    private static let appGroupIdentifier = "group.com.jogpod.shared"

    /// Key for storing workout data in UserDefaults.
    private static let workoutDataKey = "complicationWorkoutData"

    /// Minimum interval between updates during active workout (seconds).
    private static let minUpdateInterval: TimeInterval = 10

    // MARK: - Properties

    /// Shared UserDefaults for App Group.
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    /// Last time we updated complications.
    private var lastUpdateTime: Date = .distantPast

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Reference to watch state for reading current values.
    public weak var watchState: WatchState?

    /// Currently stored unit system.
    private var unitSystem: UnitSystem = .metric

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    /// Configures the service with the watch state to observe.
    ///
    /// - Parameter state: The WatchState instance to observe.
    public func configure(with state: WatchState) {
        self.watchState = state
        self.unitSystem = state.unitSystem
    }

    // MARK: - Workout State Updates

    /// Called when workout state changes (started/stopped).
    ///
    /// - Parameter isActive: Whether a workout is now active.
    public func workoutStateChanged(isActive: Bool) {
        guard let state = watchState else { return }

        if isActive {
            // Workout started - create initial entry
            updateActiveWorkout(
                distance: 0,
                pace: "--:--",
                duration: 0,
                heartRate: nil,
                calories: nil
            )
        } else {
            // Workout stopped - will update when stats arrive
            // For now, mark as inactive
            let data = SharedWorkoutData(
                isWorkoutActive: false,
                isConnected: state.isConnected,
                lastWorkoutSummary: loadExistingSummary(),
                lastUpdated: Date()
            )
            saveWorkoutData(data)
        }
    }

    /// Updates complications with current workout metrics.
    ///
    /// Call this method periodically during an active workout to keep
    /// complications showing current data.
    ///
    /// - Parameters:
    ///   - distance: Current distance in km or mi.
    ///   - pace: Current pace formatted as "M:SS".
    ///   - duration: Current duration in seconds.
    ///   - heartRate: Optional heart rate in BPM.
    ///   - calories: Optional calories burned.
    public func updateActiveWorkout(
        distance: Double,
        pace: String,
        duration: TimeInterval,
        heartRate: Int? = nil,
        calories: Int? = nil
    ) {
        // Throttle updates during active workout
        guard Date().timeIntervalSince(lastUpdateTime) >= Self.minUpdateInterval else {
            return
        }

        let existingSummary = loadExistingSummary()

        let data = SharedWorkoutData(
            isWorkoutActive: true,
            isConnected: watchState?.isConnected ?? true,
            currentDistance: distance,
            distanceUnit: unitSystem.distanceUnit,
            currentPace: pace,
            paceUnit: unitSystem.paceUnit,
            currentDuration: duration,
            currentHeartRate: heartRate,
            currentCalories: calories,
            lastWorkoutSummary: existingSummary,
            lastUpdated: Date()
        )

        saveWorkoutData(data)
        lastUpdateTime = Date()
    }

    /// Updates complications when a workout completes.
    ///
    /// - Parameters:
    ///   - distance: Total distance covered.
    ///   - averagePace: Average pace formatted as "M:SS".
    ///   - duration: Total duration in seconds.
    ///   - calories: Optional total calories burned.
    public func workoutCompleted(
        distance: Double,
        averagePace: String,
        duration: TimeInterval,
        calories: Int? = nil
    ) {
        let summary = SharedWorkoutSummary(
            workoutDate: Date(),
            distance: distance,
            distanceUnit: unitSystem.distanceUnit,
            averagePace: averagePace,
            duration: duration,
            calories: calories
        )

        let data = SharedWorkoutData(
            isWorkoutActive: false,
            isConnected: watchState?.isConnected ?? true,
            lastWorkoutSummary: summary,
            lastUpdated: Date()
        )

        saveWorkoutData(data)
    }

    /// Updates the connection state displayed on complications.
    ///
    /// - Parameter isConnected: Whether the watch is connected to iPhone.
    public func updateConnectionState(isConnected: Bool) {
        // Only update if we have existing data
        guard let existingData = loadWorkoutData() else { return }

        let data = SharedWorkoutData(
            isWorkoutActive: existingData.isWorkoutActive,
            isConnected: isConnected,
            currentDistance: existingData.currentDistance,
            distanceUnit: existingData.distanceUnit,
            currentPace: existingData.currentPace,
            paceUnit: existingData.paceUnit,
            currentDuration: existingData.currentDuration,
            currentHeartRate: existingData.currentHeartRate,
            currentCalories: existingData.currentCalories,
            lastWorkoutSummary: existingData.lastWorkoutSummary,
            lastUpdated: Date()
        )

        saveWorkoutData(data)
    }

    /// Clears all workout data (used when no workouts exist).
    public func clearWorkoutData() {
        sharedDefaults?.removeObject(forKey: Self.workoutDataKey)
        reloadComplications()
    }

    // MARK: - Private Helpers

    private func saveWorkoutData(_ data: SharedWorkoutData) {
        guard let defaults = sharedDefaults else {
            print("[ComplicationUpdateService] App Group not available")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(data)
            defaults.set(encodedData, forKey: Self.workoutDataKey)

            reloadComplications()
        } catch {
            print("[ComplicationUpdateService] Failed to encode workout data: \(error)")
        }
    }

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
            return nil
        }
    }

    private func loadExistingSummary() -> SharedWorkoutSummary? {
        loadWorkoutData()?.lastWorkoutSummary
    }

    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - SharedWorkoutData (Duplicated for App Target)

/// Data structure for sharing workout information between app and widget.
///
/// This duplicates the structure from WorkoutTimelineProvider to avoid
/// needing to share code between targets. Both must stay in sync.
public struct SharedWorkoutData: Codable {

    public let isWorkoutActive: Bool
    public let isConnected: Bool
    public let currentDistance: Double
    public let distanceUnit: String
    public let currentPace: String
    public let paceUnit: String
    public let currentDuration: TimeInterval
    public let currentHeartRate: Int?
    public let currentCalories: Int?
    public let lastWorkoutSummary: SharedWorkoutSummary?
    public let lastUpdated: Date

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

// MARK: - SharedWorkoutSummary (Duplicated for App Target)

/// Summary of a completed workout for sharing.
public struct SharedWorkoutSummary: Codable {

    public let workoutDate: Date
    public let distance: Double
    public let distanceUnit: String
    public let averagePace: String
    public let duration: TimeInterval
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
