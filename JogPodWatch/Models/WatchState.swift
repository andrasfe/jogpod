//
//  WatchState.swift
//  JogPodWatch
//
//  Observable state container for the watchOS app.
//  Uses the modern @Observable macro for efficient SwiftUI updates.
//

import Foundation
import SwiftUI

// MARK: - WatchState

/// Observable state container for the watchOS app.
///
/// This class centralizes all watch app state and serves as the single source
/// of truth for UI updates. It receives data from the iPhone via WatchConnectivity.
///
/// ## Architecture
///
/// The state follows a unidirectional data flow:
/// 1. iPhone sends updates via WatchConnectivity
/// 2. WatchConnectivityManager updates WatchState
/// 3. SwiftUI views observe changes and re-render
///
/// ## watchOS 10+ Features
///
/// Uses the @Observable macro for efficient property observation,
/// reducing overhead compared to @Published properties.
@Observable
@MainActor
public final class WatchState {

    // MARK: - Initialization State

    /// Whether the iPhone app has been initialized (disclaimer accepted).
    public var isInitialized: Bool = false

    /// Whether we have an active connection to the iPhone.
    public var isConnected: Bool = false

    /// Whether the iPhone is reachable for live messaging.
    public var isReachable: Bool = false

    // MARK: - Workout State

    /// Whether a workout is currently in progress.
    public var workoutInProgress: Bool = false

    /// Current workout metrics.
    public var workoutMetrics: WatchWorkoutMetrics = WatchWorkoutMetrics()

    /// Number of saved workouts.
    public var workoutCount: Int = 0

    /// Whether the workout is being tracked independently on watch.
    public var isIndependentWorkout: Bool = false

    /// Independent workout metrics from WatchWorkoutService.
    public var independentMetrics: WatchWorkoutMetricsData?

    /// Current heart rate during independent workout.
    public var currentHeartRate: Double = 0

    /// Number of pending workouts awaiting sync.
    public var pendingSyncCount: Int = 0

    // MARK: - Podcast State

    /// Whether a podcast is currently playing.
    public var podcastPlaying: Bool = false

    /// Title of the current podcast episode.
    public var podcastTitle: String = "No podcast selected"

    // MARK: - Location State

    /// Current location for map display.
    public var currentLocation: WatchLocation?

    // MARK: - Stats State

    /// Stats from the most recent or current workout.
    public var workoutStats: WatchWorkoutStats?

    // MARK: - Settings State

    /// User's preferred unit system.
    public var unitSystem: UnitSystem = .metric

    // MARK: - Error State

    /// Current error message to display, if any.
    public var errorMessage: String?

    /// Whether to show the error alert.
    public var showError: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - State Updates

    /// Updates workout metrics from a dictionary received via WatchConnectivity.
    ///
    /// - Parameter dict: Dictionary with metric values keyed by field ID.
    public func updateMetrics(from dict: [Int: String]) {
        if let description = dict[1] {
            workoutMetrics.currentMetricDescription = description
        }
        if let value = dict[2] {
            workoutMetrics.currentMetricValue = value
        }
        if let units = dict[3] {
            workoutMetrics.currentMetricUnits = units
        }
    }

    /// Updates dashboard state from response data.
    ///
    /// - Parameter data: Dashboard data from the iPhone.
    public func updateDashboard(
        workoutInProgress: Bool,
        podcastPlaying: Bool,
        podcastTitle: String,
        workoutCount: Int,
        isInitialized: Bool
    ) {
        self.workoutInProgress = workoutInProgress
        self.podcastPlaying = podcastPlaying
        self.podcastTitle = podcastTitle
        self.workoutCount = workoutCount
        self.isInitialized = isInitialized
    }

    /// Updates podcast state.
    ///
    /// - Parameters:
    ///   - isPlaying: Whether the podcast is playing.
    ///   - title: Optional new title.
    public func updatePodcast(isPlaying: Bool, title: String? = nil) {
        podcastPlaying = isPlaying
        if let title = title {
            podcastTitle = title
        }
    }

    /// Updates location for map display.
    ///
    /// - Parameter location: New location data.
    public func updateLocation(_ location: WatchLocation) {
        currentLocation = location
    }

    /// Updates workout stats.
    ///
    /// - Parameter stats: New stats data.
    public func updateStats(_ stats: WatchWorkoutStats) {
        workoutStats = stats
    }

    /// Displays an error message.
    ///
    /// - Parameter message: The error message to show.
    public func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Clears the current error.
    public func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - WatchWorkoutMetrics

/// Current workout metrics for display.
@Observable
public final class WatchWorkoutMetrics {

    /// Description of the current metric (e.g., "AVG SPEED").
    public var currentMetricDescription: String = "---"

    /// Value of the current metric (e.g., "6.7").
    public var currentMetricValue: String = "--"

    /// Units of the current metric (e.g., "mph").
    public var currentMetricUnits: String = ""

    /// Index of the current metric in the carousel.
    public var currentMetricIndex: Int = 0

    /// Total number of available metrics.
    public var metricCount: Int = 6

    public init() {}

    /// Advances to the next metric.
    public func nextMetric() {
        currentMetricIndex = (currentMetricIndex + 1) % metricCount
    }

    /// Goes to the previous metric.
    public func previousMetric() {
        currentMetricIndex = currentMetricIndex == 0 ? metricCount - 1 : currentMetricIndex - 1
    }
}

// MARK: - WatchLocation

/// Location data for map display.
///
/// This struct matches the `LocationUpdateData` format from the iOS
/// `WatchConnectivityService` to ensure proper data exchange.
public struct WatchLocation: Sendable, Equatable {
    /// Latitude in degrees.
    public let latitude: Double

    /// Longitude in degrees.
    public let longitude: Double

    /// Horizontal accuracy in meters.
    public let horizontalAccuracy: Double

    /// Speed in meters per second. Negative if invalid.
    public let speed: Double

    /// Course/heading in degrees (0-360). Negative if invalid.
    public let course: Double

    /// Timestamp of the location reading.
    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double = 0,
        speed: Double = -1,
        course: Double = -1,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }

    /// Whether the speed value is valid.
    public var hasValidSpeed: Bool {
        speed >= 0
    }

    /// Whether the course value is valid.
    public var hasValidCourse: Bool {
        course >= 0
    }
}

// MARK: - WatchWorkoutStats

/// Workout statistics for the stats view.
public struct WatchWorkoutStats: Sendable, Equatable {
    public let distance: String
    public let avgSpeed: String
    public let calories: String
    public let duration: String
    public let mapImageData: Data?

    public init(
        distance: String = "N/A",
        avgSpeed: String = "N/A",
        calories: String = "N/A",
        duration: String = "N/A",
        mapImageData: Data? = nil
    ) {
        self.distance = distance
        self.avgSpeed = avgSpeed
        self.calories = calories
        self.duration = duration
        self.mapImageData = mapImageData
    }
}

// MARK: - UnitSystem

/// Preferred unit system for displaying measurements.
public enum UnitSystem: String, CaseIterable, Sendable {
    case metric
    case imperial

    public var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    public var speedUnit: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }

    public var paceUnit: String {
        switch self {
        case .metric: return "min/km"
        case .imperial: return "min/mi"
        }
    }

    public var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}
