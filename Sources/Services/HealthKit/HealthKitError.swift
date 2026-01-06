//
//  HealthKitError.swift
//  JogPod
//
//  Modern error handling for HealthKit operations.
//

import Foundation

// MARK: - HealthKitError

/// Errors that can occur during HealthKit operations.
///
/// This error type provides structured error handling for all HealthKit
/// operations including authorization, reading, and writing workout data.
public enum HealthKitError: Error, Equatable, Sendable {

    // MARK: - Availability Errors

    /// HealthKit is not available on this device (e.g., iPad).
    case healthKitNotAvailable

    /// A required HealthKit data type is not available.
    case dataTypeNotAvailable(String)

    // MARK: - Authorization Errors

    /// User has not granted authorization for the requested types.
    case authorizationNotGranted

    /// Authorization request was denied by the user.
    case authorizationDenied

    /// Authorization request failed with an underlying error.
    case authorizationFailed(String)

    // MARK: - Read Errors

    /// Failed to read workouts from HealthKit.
    case workoutReadFailed(String)

    /// Failed to read a specific data type.
    case dataReadFailed(dataType: String, reason: String)

    /// Query was cancelled before completion.
    case queryCancelled

    // MARK: - Write Errors

    /// Failed to save workout to HealthKit.
    case workoutSaveFailed(String)

    /// Failed to save samples to HealthKit.
    case sampleSaveFailed(String)

    /// Workout data is invalid (e.g., end time before start time).
    case invalidWorkoutData(String)

    // MARK: - Route Errors

    /// Failed to save workout route to HealthKit.
    case routeSaveFailed(String)

    /// Failed to read workout route from HealthKit.
    case routeReadFailed(String)

    /// Insufficient route data to create a route (need at least 2 points).
    case insufficientRouteData

    // MARK: - General Errors

    /// An unknown error occurred.
    case unknown(String)
}

// MARK: - LocalizedError

extension HealthKitError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."

        case .dataTypeNotAvailable(let type):
            return "The HealthKit data type '\(type)' is not available."

        case .authorizationNotGranted:
            return "HealthKit authorization has not been granted."

        case .authorizationDenied:
            return "HealthKit authorization was denied."

        case .authorizationFailed(let reason):
            return "HealthKit authorization failed: \(reason)"

        case .workoutReadFailed(let reason):
            return "Failed to read workouts: \(reason)"

        case .dataReadFailed(let dataType, let reason):
            return "Failed to read \(dataType): \(reason)"

        case .queryCancelled:
            return "The HealthKit query was cancelled."

        case .workoutSaveFailed(let reason):
            return "Failed to save workout: \(reason)"

        case .sampleSaveFailed(let reason):
            return "Failed to save samples: \(reason)"

        case .invalidWorkoutData(let reason):
            return "Invalid workout data: \(reason)"

        case .routeSaveFailed(let reason):
            return "Failed to save workout route: \(reason)"

        case .routeReadFailed(let reason):
            return "Failed to read workout route: \(reason)"

        case .insufficientRouteData:
            return "Insufficient route data to create a workout route."

        case .unknown(let reason):
            return "An unknown HealthKit error occurred: \(reason)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit requires an iPhone or Apple Watch."

        case .authorizationDenied, .authorizationNotGranted:
            return "Please enable HealthKit access in Settings > Privacy > Health."

        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .authorizationDenied, .authorizationNotGranted:
            return "Go to Settings > Privacy & Security > Health > JogPod to enable access."

        case .authorizationFailed:
            return "Try restarting the app and requesting permissions again."

        default:
            return nil
        }
    }
}

// MARK: - CustomNSError

extension HealthKitError: CustomNSError {

    public static var errorDomain: String {
        "com.jogpod.healthkit"
    }

    public var errorCode: Int {
        switch self {
        case .healthKitNotAvailable: return 1001
        case .dataTypeNotAvailable: return 1002
        case .authorizationNotGranted: return 2001
        case .authorizationDenied: return 2002
        case .authorizationFailed: return 2003
        case .workoutReadFailed: return 3001
        case .dataReadFailed: return 3002
        case .queryCancelled: return 3003
        case .workoutSaveFailed: return 4001
        case .sampleSaveFailed: return 4002
        case .invalidWorkoutData: return 4003
        case .routeSaveFailed: return 5001
        case .routeReadFailed: return 5002
        case .insufficientRouteData: return 5003
        case .unknown: return 9999
        }
    }

    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]

        if let description = errorDescription {
            userInfo[NSLocalizedDescriptionKey] = description
        }

        if let reason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }

        if let suggestion = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }

        return userInfo
    }
}
