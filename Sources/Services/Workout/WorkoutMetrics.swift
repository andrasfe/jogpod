//
//  WorkoutMetrics.swift
//  JogPod
//
//  Real-time workout metrics computation with rolling averages and peak detection.
//

import Foundation
import CoreLocation

// MARK: - WorkoutMetrics

/// Computes real-time workout metrics from location and biometric data.
///
/// This class is responsible for computing all workout statistics including
/// distance, speed, elevation, heart rate, and calorie burn. It maintains
/// rolling averages for speed and detects peak performance.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` to ensure all UI-bound stats updates
/// happen on the main thread.
///
/// ## Legacy Equivalence
///
/// Replaces the legacy `WorkoutMetricsManager` and `SpeedStats` classes,
/// consolidating all metrics computation into a single, testable component.
@MainActor
public final class WorkoutMetrics: ObservableObject {

    // MARK: - Published Properties (Observable)

    /// Total distance traveled in meters.
    @Published public private(set) var totalDistance: CLLocationDistance = 0

    /// Current speed in meters per second (rolling average).
    @Published public private(set) var currentSpeed: Double = 0

    /// Average speed in meters per second.
    @Published public private(set) var averageSpeed: Double = 0

    /// Maximum speed achieved in meters per second.
    @Published public private(set) var maxSpeed: Double = 0

    /// Minimum non-zero speed in meters per second.
    @Published public private(set) var minSpeed: Double = 0

    /// Total elevation gain in meters.
    @Published public private(set) var totalElevationGain: Double = 0

    /// Total elevation loss in meters.
    @Published public private(set) var totalElevationLoss: Double = 0

    /// Current elevation in meters.
    @Published public private(set) var currentElevation: Double = 0

    /// Maximum elevation in meters.
    @Published public private(set) var maxElevation: Double = 0

    /// Minimum elevation in meters.
    @Published public private(set) var minElevation: Double = 0

    /// Current heart rate in BPM.
    @Published public private(set) var currentHeartRate: Int = 0

    /// Average heart rate in BPM.
    @Published public private(set) var averageHeartRate: Int = 0

    /// Maximum heart rate in BPM.
    @Published public private(set) var maxHeartRate: Int = 0

    /// Minimum heart rate in BPM (excluding zeros).
    @Published public private(set) var minHeartRate: Int = 0

    /// Total step count.
    @Published public private(set) var totalSteps: Int = 0

    /// Estimated calories burned.
    @Published public private(set) var caloriesBurned: Int = 0

    /// Whether the user is currently at their peak speed.
    @Published public private(set) var isAtPeakSpeed: Bool = false

    /// The current GPS signal level.
    @Published public private(set) var gpsSignalLevel: GPSSignalLevel = .none

    // MARK: - Computed Properties

    /// Workout duration based on start time.
    public var duration: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Current pace in minutes per kilometer.
    public var pacePerKilometer: Double? {
        guard currentSpeed > 0 else { return nil }
        let metersPerMinute = currentSpeed * 60
        let kilometersPerMinute = metersPerMinute / 1000
        return 1.0 / kilometersPerMinute
    }

    /// Current pace in minutes per mile.
    public var pacePerMile: Double? {
        guard let paceKm = pacePerKilometer else { return nil }
        return paceKm * 1.60934
    }

    /// Average step length in meters.
    public var averageStepLength: Double? {
        guard totalSteps > 0 else { return nil }
        return totalDistance / Double(totalSteps)
    }

    // MARK: - Private Properties

    private let startTime: Date?
    private let userWeight: Double // kilograms

    /// Rolling buffer for speed calculations (keeps last 3 readings).
    private var speedBuffer: RollingBuffer<SpeedReading>

    /// Time of last max speed for peak detection.
    private var maxSpeedTime: Date?

    /// Previous location for distance calculations.
    private var previousLocation: CLLocation?

    /// Previous altitude for elevation calculations.
    private var previousAltitude: Double?

    /// Counters for heart rate averaging.
    private var heartRateSum: Int = 0
    private var heartRateCount: Int = 0

    /// Total location count.
    private var locationCount: Int = 0

    /// Sum of all speed readings for average calculation.
    private var speedSum: Double = 0
    private var speedCount: Int = 0

    // MARK: - Configuration

    /// Number of readings to keep for moving average.
    public static let rollingAverageWindowSize = 3

    /// Peak speed detection window in seconds.
    public static let peakSpeedWindowSeconds: TimeInterval = 10

    // MARK: - Initialization

    /// Creates a new WorkoutMetrics instance.
    ///
    /// - Parameters:
    ///   - startTime: The workout start time.
    ///   - userWeight: The user's weight in kilograms for calorie calculations.
    public init(startTime: Date = Date(), userWeight: Double = 70.0) {
        self.startTime = startTime
        self.userWeight = userWeight
        self.speedBuffer = RollingBuffer(maxSize: Self.rollingAverageWindowSize)
    }

    // MARK: - Public Methods

    /// Updates metrics with a new location reading.
    ///
    /// - Parameters:
    ///   - location: The new location from CLLocationManager.
    ///   - steps: Optional current step count.
    public func updateWithLocation(_ location: CLLocation, steps: Int? = nil) {
        locationCount += 1

        // Update GPS signal level
        gpsSignalLevel = GPSSignalLevel(horizontalAccuracy: location.horizontalAccuracy)

        // Update steps if provided
        if let steps = steps {
            totalSteps = steps
        }

        // Calculate distance from previous location
        if let previous = previousLocation {
            let distance = location.distance(from: previous)

            // Filter out unreasonably large distances (GPS jumps)
            if distance < 1000 { // Less than 1km between readings
                totalDistance += distance
            }
        }

        // Update elevation
        let altitude = location.altitude
        currentElevation = altitude

        if let previous = previousAltitude {
            let elevationChange = altitude - previous
            if elevationChange > 0 {
                totalElevationGain += elevationChange
            } else {
                totalElevationLoss += abs(elevationChange)
            }
        } else {
            minElevation = altitude
            maxElevation = altitude
        }

        if altitude > maxElevation {
            maxElevation = altitude
        }
        if altitude < minElevation {
            minElevation = altitude
        }

        previousAltitude = altitude

        // Update speed using rolling average
        updateSpeed(from: location)

        // Calculate calories burned
        updateCalories()

        // Store for next calculation
        previousLocation = location
    }

    /// Updates metrics with a new heart rate reading.
    ///
    /// - Parameters:
    ///   - heartRate: Heart rate in BPM.
    ///   - steps: Optional current step count.
    public func updateWithHeartRate(_ heartRate: Int, steps: Int? = nil) {
        guard heartRate > 0 && heartRate < 250 else { return }

        currentHeartRate = heartRate

        // Update min/max
        if heartRateCount == 0 || heartRate > maxHeartRate {
            maxHeartRate = heartRate
        }
        if heartRateCount == 0 || (heartRate > 0 && heartRate < minHeartRate) {
            minHeartRate = heartRate
        }

        // Update average
        heartRateSum += heartRate
        heartRateCount += 1
        averageHeartRate = heartRateSum / heartRateCount

        // Update steps if provided
        if let steps = steps {
            totalSteps = steps
        }

        // Recalculate calories with heart rate data
        updateCalories()
    }

    /// Resets all metrics to initial values.
    public func reset() {
        totalDistance = 0
        currentSpeed = 0
        averageSpeed = 0
        maxSpeed = 0
        minSpeed = 0
        totalElevationGain = 0
        totalElevationLoss = 0
        currentElevation = 0
        maxElevation = 0
        minElevation = 0
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = 0
        totalSteps = 0
        caloriesBurned = 0
        isAtPeakSpeed = false
        gpsSignalLevel = .none

        speedBuffer = RollingBuffer(maxSize: Self.rollingAverageWindowSize)
        maxSpeedTime = nil
        previousLocation = nil
        previousAltitude = nil
        heartRateSum = 0
        heartRateCount = 0
        locationCount = 0
        speedSum = 0
        speedCount = 0
    }

    /// Returns a snapshot of current workout stats.
    ///
    /// - Returns: A `WorkoutSnapshot` containing all current metrics.
    public func snapshot() -> WorkoutSnapshot {
        WorkoutSnapshot(
            totalDistance: totalDistance,
            duration: duration,
            currentSpeed: currentSpeed,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            minSpeed: minSpeed,
            totalElevationGain: totalElevationGain,
            totalElevationLoss: totalElevationLoss,
            currentElevation: currentElevation,
            currentHeartRate: currentHeartRate,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            totalSteps: totalSteps,
            caloriesBurned: caloriesBurned,
            isAtPeakSpeed: isAtPeakSpeed,
            gpsSignalLevel: gpsSignalLevel,
            pacePerKilometer: pacePerKilometer,
            pacePerMile: pacePerMile,
            averageStepLength: averageStepLength
        )
    }

    // MARK: - Private Methods

    private func updateSpeed(from location: CLLocation) {
        let speed = location.speed

        // Ignore invalid speed readings
        guard speed >= 0 else { return }

        // Add to rolling buffer
        let reading = SpeedReading(speed: speed, time: location.timestamp)
        speedBuffer.add(reading)

        // Calculate rolling average
        let movingAverage = speedBuffer.elements.reduce(0.0) { $0 + $1.speed } / Double(speedBuffer.count)
        currentSpeed = movingAverage

        // Update sum for overall average
        speedSum += speed
        speedCount += 1
        averageSpeed = speedSum / Double(speedCount)

        // Update min/max
        if movingAverage > maxSpeed {
            maxSpeed = movingAverage
            maxSpeedTime = Date()
        }

        if movingAverage > 0 && (minSpeed == 0 || movingAverage < minSpeed) {
            minSpeed = movingAverage
        }

        // Check if at peak speed (max speed achieved within last 10 seconds)
        if let maxTime = maxSpeedTime {
            isAtPeakSpeed = Date().timeIntervalSince(maxTime) < Self.peakSpeedWindowSeconds
        }
    }

    private func updateCalories() {
        // Use heart rate-based calculation if available, otherwise use MET-based
        if averageHeartRate > 0 {
            // Heart rate based formula (more accurate)
            // Male: Calories = [(Age x 0.2017) - (Weight x 0.09036) + (HR x 0.6309) - 55.0969] x Time / 4.184
            // Simplified version using weight and heart rate
            let caloriesPerMinute = (0.6309 * Double(averageHeartRate) + 0.1988 * userWeight - 55.0969) / 4.184
            caloriesBurned = max(0, Int(caloriesPerMinute * (duration / 60)))
        } else {
            // MET-based calculation using speed
            // Running METs vary from ~6 (slow jog) to ~15 (fast run)
            let speedKmh = averageSpeed * 3.6 // Convert m/s to km/h
            let met: Double

            if speedKmh < 6 {
                met = 3.5 // Walking
            } else if speedKmh < 8 {
                met = 6.0 // Light jog
            } else if speedKmh < 10 {
                met = 8.0 // Jogging
            } else if speedKmh < 12 {
                met = 10.0 // Running
            } else {
                met = 12.0 // Fast running
            }

            // Calories = MET * weight(kg) * time(hours)
            let hours = duration / 3600
            caloriesBurned = Int(met * userWeight * hours)
        }
    }
}

// MARK: - SpeedReading

/// A single speed reading with timestamp.
private struct SpeedReading {
    let speed: Double
    let time: Date
}

// MARK: - RollingBuffer

/// A fixed-size buffer that discards oldest elements when full.
private struct RollingBuffer<Element> {
    private var buffer: [Element] = []
    let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    var elements: [Element] { buffer }
    var count: Int { buffer.count }
    var isEmpty: Bool { buffer.isEmpty }

    mutating func add(_ element: Element) {
        buffer.append(element)
        if buffer.count > maxSize {
            buffer.removeFirst()
        }
    }

    mutating func clear() {
        buffer.removeAll()
    }
}

// MARK: - WorkoutSnapshot

/// An immutable snapshot of workout metrics at a point in time.
///
/// This struct is `Sendable` and can be safely passed across actor boundaries.
public struct WorkoutSnapshot: Sendable, Equatable {

    /// Total distance traveled in meters.
    public let totalDistance: CLLocationDistance

    /// Workout duration in seconds.
    public let duration: TimeInterval

    /// Current speed in meters per second.
    public let currentSpeed: Double

    /// Average speed in meters per second.
    public let averageSpeed: Double

    /// Maximum speed in meters per second.
    public let maxSpeed: Double

    /// Minimum non-zero speed in meters per second.
    public let minSpeed: Double

    /// Total elevation gain in meters.
    public let totalElevationGain: Double

    /// Total elevation loss in meters.
    public let totalElevationLoss: Double

    /// Current elevation in meters.
    public let currentElevation: Double

    /// Current heart rate in BPM.
    public let currentHeartRate: Int

    /// Average heart rate in BPM.
    public let averageHeartRate: Int

    /// Maximum heart rate in BPM.
    public let maxHeartRate: Int

    /// Minimum heart rate in BPM.
    public let minHeartRate: Int

    /// Total step count.
    public let totalSteps: Int

    /// Estimated calories burned.
    public let caloriesBurned: Int

    /// Whether user is at peak speed.
    public let isAtPeakSpeed: Bool

    /// Current GPS signal level.
    public let gpsSignalLevel: GPSSignalLevel

    /// Pace in minutes per kilometer, if available.
    public let pacePerKilometer: Double?

    /// Pace in minutes per mile, if available.
    public let pacePerMile: Double?

    /// Average step length in meters, if available.
    public let averageStepLength: Double?

    // MARK: - Formatting Helpers

    /// Distance formatted in kilometers.
    public var distanceInKilometers: Double {
        totalDistance / 1000.0
    }

    /// Distance formatted in miles.
    public var distanceInMiles: Double {
        totalDistance / 1609.34
    }

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

    /// Speed formatted in km/h.
    public var currentSpeedKmh: Double {
        currentSpeed * 3.6
    }

    /// Speed formatted in mph.
    public var currentSpeedMph: Double {
        currentSpeed * 2.23694
    }

    /// Pace formatted as MM:SS per kilometer.
    public var formattedPacePerKm: String? {
        guard let pace = pacePerKilometer, pace.isFinite && pace > 0 else { return nil }
        let totalSeconds = Int(pace * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Pace formatted as MM:SS per mile.
    public var formattedPacePerMile: String? {
        guard let pace = pacePerMile, pace.isFinite && pace > 0 else { return nil }
        let totalSeconds = Int(pace * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - WorkoutSnapshot Default

extension WorkoutSnapshot {

    /// An empty snapshot with all values at zero/default.
    public static let empty = WorkoutSnapshot(
        totalDistance: 0,
        duration: 0,
        currentSpeed: 0,
        averageSpeed: 0,
        maxSpeed: 0,
        minSpeed: 0,
        totalElevationGain: 0,
        totalElevationLoss: 0,
        currentElevation: 0,
        currentHeartRate: 0,
        averageHeartRate: 0,
        maxHeartRate: 0,
        minHeartRate: 0,
        totalSteps: 0,
        caloriesBurned: 0,
        isAtPeakSpeed: false,
        gpsSignalLevel: .none,
        pacePerKilometer: nil,
        pacePerMile: nil,
        averageStepLength: nil
    )
}
