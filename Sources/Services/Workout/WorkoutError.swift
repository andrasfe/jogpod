//
//  WorkoutError.swift
//  JogPod
//
//  Error types for workout tracking operations.
//

import Foundation

// MARK: - WorkoutError

/// Errors that can occur during workout operations.
///
/// These errors cover the full range of failure scenarios in workout tracking,
/// from initialization failures to location services issues.
public enum WorkoutError: Error, Equatable, Sendable {

    // MARK: - State Errors

    /// Attempted to start a workout while one is already in progress.
    case workoutAlreadyInProgress

    /// Attempted to stop or modify a workout when none is active.
    case noActiveWorkout

    /// The workout was in an invalid state for the requested operation.
    case invalidWorkoutState(expected: WorkoutState, actual: WorkoutState)

    // MARK: - Location Errors

    /// Location services are not available on this device.
    case locationServicesUnavailable

    /// Location authorization was denied by the user.
    case locationAuthorizationDenied

    /// Location authorization is restricted (e.g., parental controls).
    case locationAuthorizationRestricted

    /// Location authorization status could not be determined.
    case locationAuthorizationUndetermined

    /// Failed to receive location updates within the expected timeout.
    case locationTimeout

    /// The received location data was invalid or unusable.
    case invalidLocationData(reason: String)

    // MARK: - Heart Rate Errors

    /// Heart rate monitoring is not available.
    case heartRateMonitoringUnavailable

    /// Failed to connect to heart rate sensor.
    case heartRateSensorConnectionFailed

    /// Heart rate reading was invalid or out of expected range.
    case invalidHeartRateData(value: Int)

    // MARK: - Persistence Errors

    /// Failed to create a workout session in the database.
    case sessionCreationFailed(underlyingError: String)

    /// Failed to save workout data.
    case persistenceFailed(underlyingError: String)

    /// The specified workout session was not found.
    case workoutNotFound(workoutID: String)

    // MARK: - Authorization Errors

    /// The user has not granted necessary permissions.
    case permissionsNotGranted(missing: [String])

    // MARK: - General Errors

    /// An unexpected error occurred.
    case unexpected(description: String)

    /// Operation was cancelled.
    case cancelled
}

// MARK: - LocalizedError Conformance

extension WorkoutError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .workoutAlreadyInProgress:
            return "A workout is already in progress. Stop the current workout before starting a new one."

        case .noActiveWorkout:
            return "No workout is currently active."

        case .invalidWorkoutState(let expected, let actual):
            return "Invalid workout state. Expected \(expected), but was \(actual)."

        case .locationServicesUnavailable:
            return "Location services are not available on this device."

        case .locationAuthorizationDenied:
            return "Location access has been denied. Please enable location services in Settings."

        case .locationAuthorizationRestricted:
            return "Location access is restricted on this device."

        case .locationAuthorizationUndetermined:
            return "Location authorization has not been determined."

        case .locationTimeout:
            return "Failed to receive location updates in time."

        case .invalidLocationData(let reason):
            return "Invalid location data: \(reason)"

        case .heartRateMonitoringUnavailable:
            return "Heart rate monitoring is not available."

        case .heartRateSensorConnectionFailed:
            return "Failed to connect to heart rate sensor."

        case .invalidHeartRateData(let value):
            return "Invalid heart rate value: \(value)"

        case .sessionCreationFailed(let error):
            return "Failed to create workout session: \(error)"

        case .persistenceFailed(let error):
            return "Failed to save workout data: \(error)"

        case .workoutNotFound(let workoutID):
            return "Workout not found: \(workoutID)"

        case .permissionsNotGranted(let missing):
            return "Required permissions not granted: \(missing.joined(separator: ", "))"

        case .unexpected(let description):
            return "An unexpected error occurred: \(description)"

        case .cancelled:
            return "The operation was cancelled."
        }
    }

    public var failureReason: String? {
        switch self {
        case .locationAuthorizationDenied:
            return "The user denied location access."
        case .locationAuthorizationRestricted:
            return "Location access is restricted by device policy."
        case .heartRateSensorConnectionFailed:
            return "Could not establish connection with the heart rate sensor."
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .workoutAlreadyInProgress:
            return "Stop the current workout first, then start a new one."
        case .locationAuthorizationDenied:
            return "Go to Settings > Privacy > Location Services to enable location access for this app."
        case .locationAuthorizationUndetermined:
            return "The app will request location permissions."
        case .heartRateSensorConnectionFailed:
            return "Ensure your heart rate sensor is powered on and within range."
        default:
            return nil
        }
    }
}

// MARK: - WorkoutState

/// Represents the current state of a workout session.
public enum WorkoutState: String, Sendable, Equatable, CaseIterable {

    /// No workout is active.
    case idle

    /// Workout is starting up (acquiring GPS lock, etc.).
    case starting

    /// Workout is actively recording.
    case active

    /// Workout is paused.
    case paused

    /// Workout is being finalized (saving data, computing stats).
    case stopping

    /// Workout has completed.
    case completed

    /// Workout encountered an error.
    case error
}

// MARK: - GPSSignalLevel

/// Represents GPS signal quality levels.
///
/// Maps to the horizontal accuracy values from CLLocation.
/// Lower accuracy values indicate better signal.
public enum GPSSignalLevel: Int, Sendable, Comparable, CaseIterable {

    /// No signal or invalid reading.
    case none = 0

    /// Very poor signal (accuracy > 163m).
    case veryPoor = 1

    /// Poor signal (accuracy > 120m).
    case poor = 2

    /// Fair signal (accuracy > 95m).
    case fair = 3

    /// Good signal (accuracy > 48m).
    case good = 4

    /// Excellent signal (accuracy <= 48m).
    case excellent = 5

    /// Creates a signal level from horizontal accuracy in meters.
    ///
    /// - Parameter horizontalAccuracy: The CLLocation horizontal accuracy value.
    /// - Returns: The corresponding signal level.
    public init(horizontalAccuracy: Double) {
        if horizontalAccuracy < 0 {
            self = .none
        } else if horizontalAccuracy > 163 {
            self = .veryPoor
        } else if horizontalAccuracy > 120 {
            self = .poor
        } else if horizontalAccuracy > 95 {
            self = .fair
        } else if horizontalAccuracy > 48 {
            self = .good
        } else {
            self = .excellent
        }
    }

    public static func < (lhs: GPSSignalLevel, rhs: GPSSignalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
