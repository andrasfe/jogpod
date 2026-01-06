//
//  HealthKitTestFixtures.swift
//  JogPodTests
//
//  Test fixtures and helpers for HealthKit testing.
//  Provides reusable test data, scenario configurations, and utility methods.
//

import Foundation
import HealthKit
@testable import JogPod

// MARK: - HealthKitTestFixtures

/// Provides reusable test data and fixtures for HealthKit tests.
public enum HealthKitTestFixtures {

    // MARK: - Workout Data Fixtures

    /// Creates valid workout data with default values.
    public static func validWorkoutData(
        duration: TimeInterval = 3600,
        calories: Double = 350,
        distance: Double = 5000,
        activityType: HKWorkoutActivityType = .running
    ) -> HealthKitWorkoutData {
        let startTime = Date().addingTimeInterval(-duration)
        return HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            activityType: activityType,
            totalEnergyBurned: calories,
            totalDistance: distance,
            distanceUnit: .meters
        )
    }

    /// Creates workout data with heart rate samples.
    public static func workoutDataWithHeartRate(
        duration: TimeInterval = 1800,
        averageHeartRate: Int = 145
    ) -> HealthKitWorkoutData {
        let startTime = Date().addingTimeInterval(-duration)
        let sampleCount = Int(duration / 60) // One sample per minute

        let heartRateSamples = (0..<sampleCount).map { index in
            let timestamp = startTime.addingTimeInterval(Double(index * 60))
            let bpm = averageHeartRate + Int.random(in: -10...10)
            return HeartRateSample(bpm: bpm, timestamp: timestamp)
        }

        return HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            activityType: .running,
            totalEnergyBurned: Double(sampleCount * 10),
            totalDistance: Double(sampleCount * 100),
            distanceUnit: .meters,
            heartRateSamples: heartRateSamples
        )
    }

    /// Creates workout data with route points.
    public static func workoutDataWithRoute(
        duration: TimeInterval = 1800,
        startLatitude: Double = 37.7749,
        startLongitude: Double = -122.4194
    ) -> HealthKitWorkoutData {
        let startTime = Date().addingTimeInterval(-duration)
        let pointCount = Int(duration / 10) // One point every 10 seconds

        let routePoints = (0..<pointCount).map { index in
            let timestamp = startTime.addingTimeInterval(Double(index * 10))
            let latOffset = Double(index) * 0.0001
            let lonOffset = Double(index) * 0.0001

            return RoutePoint(
                latitude: startLatitude + latOffset,
                longitude: startLongitude + lonOffset,
                altitude: 10 + Double.random(in: -2...2),
                horizontalAccuracy: 5,
                verticalAccuracy: 3,
                timestamp: timestamp
            )
        }

        return HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            activityType: .running,
            totalEnergyBurned: 200,
            totalDistance: 3000,
            distanceUnit: .meters,
            routePoints: routePoints
        )
    }

    /// Creates invalid workout data (end time before start time).
    public static func invalidWorkoutDataEndBeforeStart() -> HealthKitWorkoutData {
        HealthKitWorkoutData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600),
            activityType: .running
        )
    }

    /// Creates invalid workout data (negative calories).
    public static func invalidWorkoutDataNegativeCalories() -> HealthKitWorkoutData {
        HealthKitWorkoutData(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            activityType: .running,
            totalEnergyBurned: -100
        )
    }

    /// Creates invalid workout data (negative distance).
    public static func invalidWorkoutDataNegativeDistance() -> HealthKitWorkoutData {
        HealthKitWorkoutData(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            activityType: .running,
            totalDistance: -1000
        )
    }

    /// Creates invalid workout data (zero duration).
    public static func invalidWorkoutDataZeroDuration() -> HealthKitWorkoutData {
        let now = Date()
        return HealthKitWorkoutData(
            startTime: now,
            endTime: now,
            activityType: .running
        )
    }

    // MARK: - Workout Result Fixtures

    /// Creates a workout result for testing.
    public static func workoutResult(
        activityType: HKWorkoutActivityType = .running,
        duration: TimeInterval = 3600,
        distanceMeters: Double? = 5000,
        caloriesBurned: Double? = 350
    ) -> HealthKitWorkoutResult {
        let startTime = Date().addingTimeInterval(-duration)

        return HealthKitWorkoutResult(
            id: UUID(),
            startTime: startTime,
            endTime: Date(),
            activityType: activityType,
            duration: duration,
            totalEnergyBurned: caloriesBurned,
            totalDistanceMeters: distanceMeters,
            sourceBundleIdentifier: "com.jogpod.test",
            sourceName: "JogPod Tests"
        )
    }

    /// Creates a collection of workout results spanning multiple days.
    public static func workoutResultsForWeek() -> [HealthKitWorkoutResult] {
        (0..<7).map { dayOffset in
            let startTime = Calendar.current.date(
                byAdding: .day,
                value: -dayOffset,
                to: Date()
            )!.addingTimeInterval(-3600)

            return HealthKitWorkoutResult(
                id: UUID(),
                startTime: startTime,
                endTime: startTime.addingTimeInterval(3600),
                activityType: dayOffset % 2 == 0 ? .running : .walking,
                duration: 3600,
                totalEnergyBurned: Double(200 + dayOffset * 30),
                totalDistanceMeters: Double(4000 + dayOffset * 500),
                sourceBundleIdentifier: "com.jogpod.test",
                sourceName: "JogPod Tests"
            )
        }
    }

    // MARK: - User Data Fixtures

    /// Creates user data for a typical adult runner.
    public static func typicalRunnerUserData() -> HealthKitUserData {
        let calendar = Calendar.current
        let dateOfBirth = calendar.date(from: DateComponents(year: 1988, month: 3, day: 20))

        return HealthKitUserData(
            dateOfBirth: dateOfBirth,
            biologicalSex: .male,
            bodyMassKg: 72.5,
            heightMeters: 1.78
        )
    }

    /// Creates minimal user data (only body mass).
    public static func minimalUserData() -> HealthKitUserData {
        HealthKitUserData(bodyMassKg: 70)
    }

    /// Creates empty user data.
    public static func emptyUserData() -> HealthKitUserData {
        HealthKitUserData()
    }

    // MARK: - Heart Rate Sample Fixtures

    /// Creates heart rate samples for a warm-up period.
    public static func warmupHeartRateSamples(duration: TimeInterval = 300) -> [HeartRateSample] {
        let startTime = Date().addingTimeInterval(-duration)
        let sampleCount = Int(duration / 10)

        return (0..<sampleCount).map { index in
            let timestamp = startTime.addingTimeInterval(Double(index * 10))
            let progress = Double(index) / Double(sampleCount)
            let bpm = 70 + Int(progress * 60) // 70 BPM to 130 BPM
            return HeartRateSample(bpm: bpm, timestamp: timestamp)
        }
    }

    /// Creates heart rate samples for steady-state running.
    public static func steadyStateHeartRateSamples(
        duration: TimeInterval = 1800,
        targetHeartRate: Int = 155
    ) -> [HeartRateSample] {
        let startTime = Date().addingTimeInterval(-duration)
        let sampleCount = Int(duration / 10)

        return (0..<sampleCount).map { index in
            let timestamp = startTime.addingTimeInterval(Double(index * 10))
            let variance = Int.random(in: -5...5)
            return HeartRateSample(bpm: targetHeartRate + variance, timestamp: timestamp)
        }
    }

    /// Creates heart rate samples for interval training.
    public static func intervalHeartRateSamples(
        intervals: Int = 5,
        intervalDuration: TimeInterval = 180
    ) -> [HeartRateSample] {
        var samples: [HeartRateSample] = []
        let startTime = Date().addingTimeInterval(Double(-intervals * 2) * intervalDuration)

        for interval in 0..<intervals {
            let intervalStartTime = startTime.addingTimeInterval(Double(interval * 2) * intervalDuration)

            // High intensity phase
            for second in stride(from: 0, to: Int(intervalDuration), by: 10) {
                let timestamp = intervalStartTime.addingTimeInterval(Double(second))
                let bpm = 165 + Int.random(in: -5...5)
                samples.append(HeartRateSample(bpm: bpm, timestamp: timestamp))
            }

            // Recovery phase
            let recoveryStartTime = intervalStartTime.addingTimeInterval(intervalDuration)
            for second in stride(from: 0, to: Int(intervalDuration), by: 10) {
                let timestamp = recoveryStartTime.addingTimeInterval(Double(second))
                let bpm = 130 + Int.random(in: -10...10)
                samples.append(HeartRateSample(bpm: bpm, timestamp: timestamp))
            }
        }

        return samples
    }

    // MARK: - Route Point Fixtures

    /// Creates route points for a straight path.
    public static func straightPathRoutePoints(
        length: Int = 100,
        startLatitude: Double = 37.7749,
        startLongitude: Double = -122.4194
    ) -> [RoutePoint] {
        let startTime = Date().addingTimeInterval(Double(-length * 10))

        return (0..<length).map { index in
            let timestamp = startTime.addingTimeInterval(Double(index * 10))
            return RoutePoint(
                latitude: startLatitude + Double(index) * 0.0001,
                longitude: startLongitude,
                altitude: 10,
                horizontalAccuracy: 5,
                verticalAccuracy: 3,
                timestamp: timestamp
            )
        }
    }

    /// Creates route points for a circular path.
    public static func circularPathRoutePoints(
        radius: Double = 0.005,
        points: Int = 100,
        centerLatitude: Double = 37.7749,
        centerLongitude: Double = -122.4194
    ) -> [RoutePoint] {
        let startTime = Date().addingTimeInterval(Double(-points * 10))

        return (0..<points).map { index in
            let angle = (Double(index) / Double(points)) * 2 * .pi
            let timestamp = startTime.addingTimeInterval(Double(index * 10))

            return RoutePoint(
                latitude: centerLatitude + radius * cos(angle),
                longitude: centerLongitude + radius * sin(angle),
                altitude: 10 + 5 * sin(angle), // Slight elevation change
                horizontalAccuracy: 5,
                verticalAccuracy: 3,
                timestamp: timestamp
            )
        }
    }
}

// MARK: - Test Scenario Configurations

/// Predefined test scenario configurations for common HealthKit testing patterns.
public enum HealthKitTestScenario {

    /// Scenario where everything works correctly.
    case happyPath

    /// Scenario where HealthKit is not available.
    case healthKitUnavailable

    /// Scenario where authorization is denied.
    case authorizationDenied

    /// Scenario where authorization has not been requested.
    case authorizationNotDetermined

    /// Scenario where authorization request fails.
    case authorizationRequestFails

    /// Scenario where saving workouts fails.
    case workoutSaveFails

    /// Scenario where fetching workouts fails.
    case workoutFetchFails

    /// Scenario where there is no data.
    case noData

    /// Scenario with slow network/operations.
    case slowOperations

    /// Configures a mock service for this scenario.
    public func configure(service: MockHealthKitService) async {
        switch self {
        case .happyPath:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.authorized)
            await service.setMockWorkouts(MockHealthKitService.sampleWorkoutResults())
            await service.setMockUserData(MockHealthKitService.sampleUserData())
            await service.setMockBodyMass(75.0)

        case .healthKitUnavailable:
            await service.setAvailable(false)
            await service.setAuthorizationStatus(.unavailable)

        case .authorizationDenied:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.denied)

        case .authorizationNotDetermined:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.notDetermined)

        case .authorizationRequestFails:
            await service.setAvailable(true)
            await service.setAuthorizationError(.authorizationFailed("Network error"))

        case .workoutSaveFails:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.authorized)
            await service.setWorkoutSaveError(.workoutSaveFailed("Database error"))

        case .workoutFetchFails:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.authorized)
            await service.setWorkoutFetchError(.workoutReadFailed("Query timeout"))

        case .noData:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.authorized)
            await service.setMockWorkouts([])
            await service.setMockUserData(HealthKitUserData())

        case .slowOperations:
            await service.setAvailable(true)
            await service.setAuthorizationStatus(.authorized)
            await service.setOperationDelay(0.5)
        }
    }
}

// MARK: - Error Simulation Helpers

/// Helpers for simulating various error conditions in HealthKit tests.
public enum HealthKitErrorSimulator {

    /// All authorization-related errors.
    public static let authorizationErrors: [HealthKitError] = [
        .authorizationNotGranted,
        .authorizationDenied,
        .authorizationFailed("User cancelled"),
        .authorizationFailed("Network error"),
        .authorizationFailed("System error")
    ]

    /// All save-related errors.
    public static let saveErrors: [HealthKitError] = [
        .workoutSaveFailed("Database error"),
        .workoutSaveFailed("Disk full"),
        .workoutSaveFailed("Authorization expired"),
        .sampleSaveFailed("Invalid data"),
        .sampleSaveFailed("Too many samples")
    ]

    /// All read-related errors.
    public static let readErrors: [HealthKitError] = [
        .workoutReadFailed("Query timeout"),
        .workoutReadFailed("Database locked"),
        .dataReadFailed(dataType: "bodyMass", reason: "Not authorized"),
        .dataReadFailed(dataType: "heartRate", reason: "No data available"),
        .queryCancelled
    ]

    /// All validation errors.
    public static let validationErrors: [HealthKitError] = [
        .invalidWorkoutData("End time before start time"),
        .invalidWorkoutData("Negative duration"),
        .invalidWorkoutData("Invalid activity type"),
        .dataTypeNotAvailable("customType")
    ]
}

// MARK: - Date Helpers

extension HealthKitTestFixtures {

    /// Creates a date from components.
    public static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    /// Creates a date offset from now.
    public static func dateOffset(
        days: Int = 0,
        hours: Int = 0,
        minutes: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.day = days
        components.hour = hours
        components.minute = minutes
        return Calendar.current.date(byAdding: components, to: Date())!
    }
}
