//
//  ComplicationEntry.swift
//  JogPodWatchWidget
//
//  Data models for watch face complications.
//  Provides timeline entries for WidgetKit-based watchOS complications.
//

import WidgetKit
import SwiftUI

// MARK: - WorkoutComplicationEntry

/// Timeline entry for workout complications.
///
/// This entry contains all the data needed to render workout information
/// on watch face complications. It supports both active workout display
/// and last workout summary display.
///
/// ## WidgetKit Integration
///
/// WidgetKit uses these entries to render complications at specific points
/// in time. The timeline provider creates entries for the current state
/// and schedules future updates as workout data changes.
public struct WorkoutComplicationEntry: TimelineEntry {

    // MARK: - TimelineEntry Conformance

    /// The date for this timeline entry.
    public let date: Date

    // MARK: - Workout State

    /// Whether a workout is currently active.
    public let isWorkoutActive: Bool

    /// Current workout metrics (when active).
    public let currentMetrics: ComplicationWorkoutMetrics?

    /// Last workout summary (when not active).
    public let lastWorkoutSummary: ComplicationWorkoutSummary?

    // MARK: - Connection State

    /// Whether the watch is connected to the iPhone.
    public let isConnected: Bool

    // MARK: - Configuration

    /// The relevance score for timeline selection (0.0 - 1.0).
    /// Higher values indicate more important entries.
    public let relevance: TimelineEntryRelevance?

    // MARK: - Initialization

    public init(
        date: Date = Date(),
        isWorkoutActive: Bool = false,
        currentMetrics: ComplicationWorkoutMetrics? = nil,
        lastWorkoutSummary: ComplicationWorkoutSummary? = nil,
        isConnected: Bool = true,
        relevance: TimelineEntryRelevance? = nil
    ) {
        self.date = date
        self.isWorkoutActive = isWorkoutActive
        self.currentMetrics = currentMetrics
        self.lastWorkoutSummary = lastWorkoutSummary
        self.isConnected = isConnected
        self.relevance = relevance
    }

    // MARK: - Factory Methods

    /// Creates a placeholder entry for preview purposes.
    public static var placeholder: WorkoutComplicationEntry {
        WorkoutComplicationEntry(
            date: Date(),
            isWorkoutActive: true,
            currentMetrics: ComplicationWorkoutMetrics(
                distance: 5.2,
                distanceUnit: "km",
                pace: "5:30",
                paceUnit: "min/km",
                duration: 1800, // 30 minutes
                heartRate: 145,
                calories: 320
            ),
            isConnected: true
        )
    }

    /// Creates an entry for when no data is available.
    public static var noData: WorkoutComplicationEntry {
        WorkoutComplicationEntry(
            date: Date(),
            isWorkoutActive: false,
            lastWorkoutSummary: nil,
            isConnected: false
        )
    }
}

// MARK: - ComplicationWorkoutMetrics

/// Current workout metrics for active workout display.
///
/// Contains real-time metrics updated during an active workout session.
/// All values are formatted for compact display on watch face.
public struct ComplicationWorkoutMetrics: Codable, Sendable {

    /// Distance covered in the current workout.
    public let distance: Double

    /// Unit for distance display (km or mi).
    public let distanceUnit: String

    /// Current or average pace formatted as "M:SS".
    public let pace: String

    /// Unit for pace display (min/km or min/mi).
    public let paceUnit: String

    /// Duration in seconds.
    public let duration: TimeInterval

    /// Current heart rate in BPM (optional).
    public let heartRate: Int?

    /// Calories burned (optional).
    public let calories: Int?

    // MARK: - Computed Properties

    /// Formatted distance string (e.g., "5.2").
    public var formattedDistance: String {
        if distance < 10 {
            return String(format: "%.2f", distance)
        } else if distance < 100 {
            return String(format: "%.1f", distance)
        } else {
            return String(format: "%.0f", distance)
        }
    }

    /// Formatted duration string (e.g., "30:45" or "1:30:45").
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Short duration for compact complications (minutes only).
    public var shortDuration: String {
        let totalMinutes = Int(duration) / 60
        return "\(totalMinutes)m"
    }

    // MARK: - Initialization

    public init(
        distance: Double,
        distanceUnit: String,
        pace: String,
        paceUnit: String,
        duration: TimeInterval,
        heartRate: Int? = nil,
        calories: Int? = nil
    ) {
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.pace = pace
        self.paceUnit = paceUnit
        self.duration = duration
        self.heartRate = heartRate
        self.calories = calories
    }
}

// MARK: - ComplicationWorkoutSummary

/// Summary of the last completed workout.
///
/// Displayed when no workout is active to show the user's most recent
/// workout statistics at a glance.
public struct ComplicationWorkoutSummary: Codable, Sendable {

    /// Date of the workout.
    public let workoutDate: Date

    /// Total distance covered.
    public let distance: Double

    /// Unit for distance (km or mi).
    public let distanceUnit: String

    /// Average pace formatted as "M:SS".
    public let averagePace: String

    /// Total duration in seconds.
    public let duration: TimeInterval

    /// Total calories burned.
    public let calories: Int?

    // MARK: - Computed Properties

    /// Formatted distance string.
    public var formattedDistance: String {
        if distance < 10 {
            return String(format: "%.2f", distance)
        } else if distance < 100 {
            return String(format: "%.1f", distance)
        } else {
            return String(format: "%.0f", distance)
        }
    }

    /// Formatted duration string.
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// How long ago the workout was (e.g., "2h ago", "Yesterday").
    public var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(workoutDate) {
            let hours = calendar.dateComponents([.hour], from: workoutDate, to: now).hour ?? 0
            if hours == 0 {
                return "Just now"
            } else if hours == 1 {
                return "1h ago"
            } else {
                return "\(hours)h ago"
            }
        } else if calendar.isDateInYesterday(workoutDate) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: workoutDate, to: now).day ?? 0
            return "\(days)d ago"
        }
    }

    // MARK: - Initialization

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
