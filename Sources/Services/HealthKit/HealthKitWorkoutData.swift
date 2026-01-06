//
//  HealthKitWorkoutData.swift
//  JogPod
//
//  Data models for HealthKit workout integration.
//

import Foundation
import HealthKit

// MARK: - HealthKitWorkoutData

/// Represents workout data for syncing with HealthKit.
///
/// This struct encapsulates all the data needed to create an HKWorkout
/// and associated samples in HealthKit.
///
/// ## Usage
///
/// ```swift
/// let workoutData = HealthKitWorkoutData(
///     startTime: Date().addingTimeInterval(-3600),
///     endTime: Date(),
///     activityType: .running,
///     totalEnergyBurned: 350,
///     totalDistance: 5000,
///     distanceUnit: .meters
/// )
///
/// try await healthKitService.saveWorkout(workoutData)
/// ```
public struct HealthKitWorkoutData: Sendable, Equatable {

    // MARK: - Properties

    /// Start time of the workout.
    public let startTime: Date

    /// End time of the workout.
    public let endTime: Date

    /// Type of workout activity.
    public let activityType: HKWorkoutActivityType

    /// Total energy burned in kilocalories.
    public let totalEnergyBurned: Double

    /// Total distance traveled.
    public let totalDistance: Double

    /// Unit for distance measurement.
    public let distanceUnit: DistanceUnit

    /// Optional metadata to attach to the workout.
    public let metadata: [String: Any]?

    /// Optional heart rate samples to save with the workout.
    public let heartRateSamples: [HeartRateSample]

    /// Optional route data (latitude/longitude points).
    public let routePoints: [RoutePoint]

    // MARK: - Computed Properties

    /// Duration of the workout in seconds.
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Whether the workout data is valid for saving.
    public var isValid: Bool {
        endTime > startTime &&
        totalEnergyBurned >= 0 &&
        totalDistance >= 0 &&
        duration > 0
    }

    // MARK: - Initialization

    /// Creates workout data for HealthKit sync.
    ///
    /// - Parameters:
    ///   - startTime: When the workout started.
    ///   - endTime: When the workout ended.
    ///   - activityType: The type of workout (default: running).
    ///   - totalEnergyBurned: Calories burned in kilocalories (default: 0).
    ///   - totalDistance: Distance traveled (default: 0).
    ///   - distanceUnit: Unit for distance measurement (default: meters).
    ///   - metadata: Optional metadata dictionary.
    ///   - heartRateSamples: Optional heart rate samples to save.
    ///   - routePoints: Optional route points for workout route.
    public init(
        startTime: Date,
        endTime: Date,
        activityType: HKWorkoutActivityType = .running,
        totalEnergyBurned: Double = 0,
        totalDistance: Double = 0,
        distanceUnit: DistanceUnit = .meters,
        metadata: [String: Any]? = nil,
        heartRateSamples: [HeartRateSample] = [],
        routePoints: [RoutePoint] = []
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.activityType = activityType
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistance = totalDistance
        self.distanceUnit = distanceUnit
        self.metadata = metadata
        self.heartRateSamples = heartRateSamples
        self.routePoints = routePoints
    }

    // MARK: - Equatable

    public static func == (lhs: HealthKitWorkoutData, rhs: HealthKitWorkoutData) -> Bool {
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.activityType == rhs.activityType &&
        lhs.totalEnergyBurned == rhs.totalEnergyBurned &&
        lhs.totalDistance == rhs.totalDistance &&
        lhs.distanceUnit == rhs.distanceUnit &&
        lhs.heartRateSamples == rhs.heartRateSamples &&
        lhs.routePoints == rhs.routePoints
    }
}

// MARK: - DistanceUnit

/// Unit of measurement for distance.
public enum DistanceUnit: String, Sendable, Equatable, CaseIterable {
    case meters
    case miles
    case kilometers

    /// Converts the unit to HealthKit's HKUnit.
    public var hkUnit: HKUnit {
        switch self {
        case .meters:
            return .meter()
        case .miles:
            return .mile()
        case .kilometers:
            return .meterUnit(with: .kilo)
        }
    }

    /// Returns the distance converted to meters.
    public func toMeters(_ value: Double) -> Double {
        switch self {
        case .meters:
            return value
        case .miles:
            return value * 1609.34
        case .kilometers:
            return value * 1000
        }
    }
}

// MARK: - HeartRateSample

/// A single heart rate measurement with timestamp.
public struct HeartRateSample: Sendable, Equatable {

    /// The heart rate value in beats per minute.
    public let beatsPerMinute: Double

    /// The time of the measurement.
    public let timestamp: Date

    /// Creates a heart rate sample.
    ///
    /// - Parameters:
    ///   - beatsPerMinute: Heart rate in BPM.
    ///   - timestamp: Time of measurement.
    public init(beatsPerMinute: Double, timestamp: Date) {
        self.beatsPerMinute = beatsPerMinute
        self.timestamp = timestamp
    }

    /// Creates a heart rate sample from an integer BPM value.
    ///
    /// - Parameters:
    ///   - bpm: Heart rate in BPM as an integer.
    ///   - timestamp: Time of measurement.
    public init(bpm: Int, timestamp: Date) {
        self.beatsPerMinute = Double(bpm)
        self.timestamp = timestamp
    }
}

// MARK: - RoutePoint

/// A single GPS coordinate with timestamp for workout route.
public struct RoutePoint: Sendable, Equatable {

    /// Latitude in degrees.
    public let latitude: Double

    /// Longitude in degrees.
    public let longitude: Double

    /// Altitude in meters.
    public let altitude: Double

    /// Horizontal accuracy in meters.
    public let horizontalAccuracy: Double

    /// Vertical accuracy in meters.
    public let verticalAccuracy: Double

    /// Timestamp of the location reading.
    public let timestamp: Date

    /// Creates a route point.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees.
    ///   - longitude: Longitude in degrees.
    ///   - altitude: Altitude in meters.
    ///   - horizontalAccuracy: Horizontal accuracy in meters.
    ///   - verticalAccuracy: Vertical accuracy in meters.
    ///   - timestamp: Time of the reading.
    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        horizontalAccuracy: Double = 0,
        verticalAccuracy: Double = 0,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
    }
}

// MARK: - HealthKitWorkoutResult

/// Result of reading a workout from HealthKit.
///
/// This struct provides a simplified representation of HKWorkout
/// suitable for display and processing in the app.
public struct HealthKitWorkoutResult: Sendable, Equatable, Identifiable {

    /// Unique identifier for the workout.
    public let id: UUID

    /// Start time of the workout.
    public let startTime: Date

    /// End time of the workout.
    public let endTime: Date

    /// Activity type of the workout.
    public let activityType: HKWorkoutActivityType

    /// Duration in seconds.
    public let duration: TimeInterval

    /// Total energy burned in kilocalories, if available.
    public let totalEnergyBurned: Double?

    /// Total distance in meters, if available.
    public let totalDistanceMeters: Double?

    /// Source bundle identifier (e.g., "com.apple.Health").
    public let sourceBundleIdentifier: String?

    /// Source name (e.g., "Apple Watch").
    public let sourceName: String?

    // MARK: - Computed Properties

    /// Duration formatted as HH:MM:SS.
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

    /// Distance formatted in kilometers.
    public var distanceKilometers: Double? {
        guard let meters = totalDistanceMeters else { return nil }
        return meters / 1000.0
    }

    /// Distance formatted in miles.
    public var distanceMiles: Double? {
        guard let meters = totalDistanceMeters else { return nil }
        return meters / 1609.34
    }

    // MARK: - Initialization

    /// Creates a workout result from HealthKit data.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startTime: Workout start time.
    ///   - endTime: Workout end time.
    ///   - activityType: Type of workout.
    ///   - duration: Duration in seconds.
    ///   - totalEnergyBurned: Calories burned, if available.
    ///   - totalDistanceMeters: Distance in meters, if available.
    ///   - sourceBundleIdentifier: Source app bundle ID.
    ///   - sourceName: Source app name.
    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        activityType: HKWorkoutActivityType = .running,
        duration: TimeInterval,
        totalEnergyBurned: Double? = nil,
        totalDistanceMeters: Double? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceName: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.activityType = activityType
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistanceMeters = totalDistanceMeters
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceName = sourceName
    }
}

// MARK: - Factory Methods

extension HealthKitWorkoutResult {

    /// Creates a workout result from an HKWorkout.
    ///
    /// - Parameter workout: The HealthKit workout to convert.
    /// - Returns: A HealthKitWorkoutResult instance.
    public static func from(_ workout: HKWorkout) -> HealthKitWorkoutResult {
        let energyBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let distance = workout.totalDistance?.doubleValue(for: .meter())

        return HealthKitWorkoutResult(
            id: workout.uuid,
            startTime: workout.startDate,
            endTime: workout.endDate,
            activityType: workout.workoutActivityType,
            duration: workout.duration,
            totalEnergyBurned: energyBurned,
            totalDistanceMeters: distance,
            sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
            sourceName: workout.sourceRevision.source.name
        )
    }
}

// MARK: - HealthKitUserData

/// User health data read from HealthKit.
public struct HealthKitUserData: Sendable, Equatable {

    /// User's date of birth, if available.
    public let dateOfBirth: Date?

    /// User's biological sex, if available.
    public let biologicalSex: HKBiologicalSex?

    /// User's body mass in kilograms, if available.
    public let bodyMassKg: Double?

    /// User's height in meters, if available.
    public let heightMeters: Double?

    // MARK: - Computed Properties

    /// User's age in years based on date of birth.
    public var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }

    /// Body mass converted to pounds.
    public var bodyMassLbs: Double? {
        guard let kg = bodyMassKg else { return nil }
        return kg * 2.20462
    }

    /// Height converted to feet.
    public var heightFeet: Double? {
        guard let meters = heightMeters else { return nil }
        return meters * 3.28084
    }

    // MARK: - Initialization

    public init(
        dateOfBirth: Date? = nil,
        biologicalSex: HKBiologicalSex? = nil,
        bodyMassKg: Double? = nil,
        heightMeters: Double? = nil
    ) {
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.bodyMassKg = bodyMassKg
        self.heightMeters = heightMeters
    }
}
