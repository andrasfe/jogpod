//
//  SimulatedHeartRateSensor.swift
//  JogPodTests
//
//  Generates realistic heart rate data patterns for testing workout scenarios.
//  Simulates various physiological patterns including rest, warmup, exercise, and recovery.
//

import Foundation
@testable import JogPod

// MARK: - SimulatedHeartRateSensor

/// Generates realistic heart rate measurement data for testing purposes.
///
/// This class simulates heart rate data patterns that mimic real-world scenarios,
/// including natural variation, exercise intensity changes, and physiological responses.
///
/// ## Usage
///
/// ```swift
/// // Create a sensor with a workout profile
/// let sensor = SimulatedHeartRateSensor(
///     profile: .interval5k,
///     baseHeartRate: 70
/// )
///
/// // Generate measurements
/// for _ in 0..<60 {
///     if let measurement = await sensor.nextMeasurement() {
///         print("HR: \(measurement.heartRate) BPM")
///     }
/// }
///
/// // Or use preset patterns
/// let steadyRun = SimulatedHeartRateSensor.steadyStateRun(targetHR: 150)
/// ```
public actor SimulatedHeartRateSensor {

    // MARK: - Configuration

    /// The base resting heart rate.
    private let baseHeartRate: UInt16

    /// Maximum heart rate (typically 220 - age).
    private let maxHeartRate: UInt16

    /// The simulation profile controlling HR patterns.
    private var profile: SimulationProfile

    /// Current time in the simulation (seconds).
    private var elapsedTime: TimeInterval = 0

    /// Current heart rate being simulated.
    private var currentHeartRate: Double

    /// Whether to include R-R intervals in measurements.
    private let includeRRIntervals: Bool

    /// Whether to include energy expended in measurements.
    private let includeEnergyExpended: Bool

    /// Cumulative energy expended (kJ).
    private var cumulativeEnergy: UInt16 = 0

    /// Random variation factor (0.0 to 1.0).
    private let variationFactor: Double

    /// Sensor contact status to report.
    private var contactStatus: HeartRateMeasurement.SensorContactStatus

    // MARK: - Initialization

    /// Creates a simulated heart rate sensor with the specified configuration.
    ///
    /// - Parameters:
    ///   - profile: The simulation profile controlling HR patterns.
    ///   - baseHeartRate: Resting heart rate (default 70 BPM).
    ///   - maxHeartRate: Maximum heart rate (default 190 BPM).
    ///   - includeRRIntervals: Whether to include R-R interval data.
    ///   - includeEnergyExpended: Whether to include energy expenditure.
    ///   - variationFactor: Natural HR variation (0.0-1.0, default 0.05).
    ///   - contactStatus: Initial sensor contact status.
    public init(
        profile: SimulationProfile = .constant(heartRate: 120),
        baseHeartRate: UInt16 = 70,
        maxHeartRate: UInt16 = 190,
        includeRRIntervals: Bool = true,
        includeEnergyExpended: Bool = false,
        variationFactor: Double = 0.05,
        contactStatus: HeartRateMeasurement.SensorContactStatus = .inContact
    ) {
        self.profile = profile
        self.baseHeartRate = baseHeartRate
        self.maxHeartRate = maxHeartRate
        self.currentHeartRate = Double(baseHeartRate)
        self.includeRRIntervals = includeRRIntervals
        self.includeEnergyExpended = includeEnergyExpended
        self.variationFactor = variationFactor
        self.contactStatus = contactStatus
    }

    // MARK: - Measurement Generation

    /// Generates the next heart rate measurement.
    ///
    /// Call this method at regular intervals (e.g., every second) to simulate
    /// real-time heart rate data.
    ///
    /// - Returns: A heart rate measurement, or nil if the sensor has "lost contact".
    public func nextMeasurement() -> HeartRateMeasurement? {
        // Simulate contact loss
        if contactStatus == .noContact {
            return HeartRateMeasurement(
                heartRate: 0,
                timestamp: Date(),
                sensorContactStatus: .noContact
            )
        }

        // Calculate target HR based on profile
        let targetHR = profile.heartRateAt(time: elapsedTime, base: baseHeartRate, max: maxHeartRate)

        // Smoothly transition to target
        let transitionRate = 0.1 // How quickly HR changes
        currentHeartRate += (targetHR - currentHeartRate) * transitionRate

        // Add natural variation
        let variation = (Double.random(in: -1...1) * variationFactor * currentHeartRate)
        let adjustedHR = currentHeartRate + variation

        // Clamp to valid range
        let finalHR = UInt16(max(40, min(Double(maxHeartRate), adjustedHR)))

        // Generate R-R intervals if requested
        var rrIntervals: [TimeInterval] = []
        if includeRRIntervals && finalHR > 0 {
            // R-R interval is inverse of heart rate
            // HR of 60 = 1.0 second R-R interval
            let baseRR = 60.0 / Double(finalHR)
            // Add slight variation to R-R intervals
            let rrVariation = baseRR * 0.02 * Double.random(in: -1...1)
            rrIntervals = [baseRR + rrVariation]

            // Sometimes include multiple R-R intervals
            if Bool.random() && finalHR > 80 {
                let secondRR = baseRR + (baseRR * 0.03 * Double.random(in: -1...1))
                rrIntervals.append(secondRR)
            }
        }

        // Calculate energy expended if requested
        var energyExpended: UInt16? = nil
        if includeEnergyExpended {
            // Rough approximation: higher HR = more energy
            // About 0.5-1.5 kJ per minute depending on intensity
            let energyRate = Double(finalHR - baseHeartRate) / Double(maxHeartRate - baseHeartRate)
            let energyPerSecond = (0.5 + energyRate) / 60.0
            cumulativeEnergy += UInt16(energyPerSecond)
            energyExpended = cumulativeEnergy
        }

        // Advance time
        elapsedTime += 1.0

        return HeartRateMeasurement(
            heartRate: finalHR,
            timestamp: Date(),
            sensorContactStatus: contactStatus,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals
        )
    }

    /// Resets the simulation to the beginning.
    public func reset() {
        elapsedTime = 0
        currentHeartRate = Double(baseHeartRate)
        cumulativeEnergy = 0
    }

    /// Sets the sensor contact status.
    public func setContactStatus(_ status: HeartRateMeasurement.SensorContactStatus) {
        contactStatus = status
    }

    /// Sets a new simulation profile.
    public func setProfile(_ newProfile: SimulationProfile) {
        profile = newProfile
    }

    /// Returns the current elapsed time in the simulation.
    public func getElapsedTime() -> TimeInterval {
        elapsedTime
    }

    /// Generates a batch of measurements.
    ///
    /// - Parameters:
    ///   - count: Number of measurements to generate.
    ///   - interval: Time interval between measurements (for timestamps).
    /// - Returns: Array of heart rate measurements.
    public func generateMeasurements(count: Int, interval: TimeInterval = 1.0) -> [HeartRateMeasurement] {
        var measurements: [HeartRateMeasurement] = []
        measurements.reserveCapacity(count)

        let startTime = Date()
        for i in 0..<count {
            if var measurement = nextMeasurement() {
                // Adjust timestamp based on interval
                measurement = HeartRateMeasurement(
                    heartRate: measurement.heartRate,
                    timestamp: startTime.addingTimeInterval(TimeInterval(i) * interval),
                    sensorContactStatus: measurement.sensorContactStatus,
                    energyExpended: measurement.energyExpended,
                    rrIntervals: measurement.rrIntervals
                )
                measurements.append(measurement)
            }
        }

        return measurements
    }
}

// MARK: - Simulation Profiles

extension SimulatedHeartRateSensor {

    /// Defines heart rate patterns for different workout scenarios.
    public enum SimulationProfile: Sendable {

        // MARK: - Basic Patterns

        /// Constant heart rate at a specific value.
        case constant(heartRate: UInt16)

        /// Resting heart rate with minimal variation.
        case resting

        /// Gradual increase from rest to target over specified duration.
        case warmup(targetHR: UInt16, duration: TimeInterval)

        /// Gradual decrease from current to resting over specified duration.
        case cooldown(startHR: UInt16, duration: TimeInterval)

        /// Steady state at a percentage of max HR.
        case steadyState(percentOfMax: Double)

        // MARK: - Workout Patterns

        /// Intervals alternating between high and low intensity.
        case intervals(
            highHR: UInt16,
            lowHR: UInt16,
            highDuration: TimeInterval,
            lowDuration: TimeInterval
        )

        /// Progressive increase in intensity (ladder workout).
        case progressive(
            stages: [UInt16],
            stageDuration: TimeInterval
        )

        /// Simulates a complete workout with warmup, main set, and cooldown.
        case fullWorkout(
            warmupDuration: TimeInterval,
            mainHR: UInt16,
            mainDuration: TimeInterval,
            cooldownDuration: TimeInterval
        )

        /// Custom HR curve defined by time-HR pairs.
        case custom(curve: [(time: TimeInterval, heartRate: UInt16)])

        // MARK: - Heart Rate Calculation

        /// Calculates the target heart rate at a given time.
        ///
        /// - Parameters:
        ///   - time: Current elapsed time in seconds.
        ///   - base: Base resting heart rate.
        ///   - max: Maximum heart rate.
        /// - Returns: Target heart rate for this time point.
        func heartRateAt(time: TimeInterval, base: UInt16, max: UInt16) -> Double {
            switch self {
            case .constant(let hr):
                return Double(hr)

            case .resting:
                return Double(base) + Double.random(in: -2...2)

            case .warmup(let targetHR, let duration):
                let progress = min(1.0, time / duration)
                return Double(base) + (Double(targetHR) - Double(base)) * progress

            case .cooldown(let startHR, let duration):
                let progress = min(1.0, time / duration)
                return Double(startHR) - (Double(startHR) - Double(base)) * progress

            case .steadyState(let percentOfMax):
                let targetHR = Double(base) + (Double(max) - Double(base)) * percentOfMax
                return targetHR

            case .intervals(let highHR, let lowHR, let highDuration, let lowDuration):
                let cycleLength = highDuration + lowDuration
                let timeInCycle = time.truncatingRemainder(dividingBy: cycleLength)
                return timeInCycle < highDuration ? Double(highHR) : Double(lowHR)

            case .progressive(let stages, let stageDuration):
                let stageIndex = min(stages.count - 1, Int(time / stageDuration))
                if stageIndex < stages.count {
                    let stageProgress = (time - (Double(stageIndex) * stageDuration)) / stageDuration
                    let currentHR = Double(stages[stageIndex])
                    if stageIndex + 1 < stages.count {
                        let nextHR = Double(stages[stageIndex + 1])
                        return currentHR + (nextHR - currentHR) * stageProgress
                    }
                    return currentHR
                }
                return Double(stages.last ?? base)

            case .fullWorkout(let warmupDuration, let mainHR, let mainDuration, let cooldownDuration):
                if time < warmupDuration {
                    // Warmup phase
                    let progress = time / warmupDuration
                    return Double(base) + (Double(mainHR) - Double(base)) * progress
                } else if time < warmupDuration + mainDuration {
                    // Main phase
                    return Double(mainHR)
                } else {
                    // Cooldown phase
                    let cooldownProgress = (time - warmupDuration - mainDuration) / cooldownDuration
                    return Double(mainHR) - (Double(mainHR) - Double(base)) * min(1.0, cooldownProgress)
                }

            case .custom(let curve):
                guard !curve.isEmpty else { return Double(base) }

                // Find the two surrounding points
                var prevPoint = curve[0]
                var nextPoint = curve[0]

                for point in curve {
                    if point.time <= time {
                        prevPoint = point
                    } else {
                        nextPoint = point
                        break
                    }
                }

                // If time is past all points, use the last value
                if prevPoint.time == nextPoint.time {
                    return Double(prevPoint.heartRate)
                }

                // Interpolate between points
                let progress = (time - prevPoint.time) / (nextPoint.time - prevPoint.time)
                return Double(prevPoint.heartRate) + (Double(nextPoint.heartRate) - Double(prevPoint.heartRate)) * progress
            }
        }
    }
}

// MARK: - Preset Factory Methods

extension SimulatedHeartRateSensor {

    /// Creates a sensor simulating a steady-state run at the target heart rate.
    public static func steadyStateRun(
        targetHR: UInt16 = 150,
        baseHR: UInt16 = 70
    ) -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .constant(heartRate: targetHR),
            baseHeartRate: baseHR
        )
    }

    /// Creates a sensor simulating an easy recovery run.
    public static func easyRun(baseHR: UInt16 = 70, maxHR: UInt16 = 180) -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .steadyState(percentOfMax: 0.6),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }

    /// Creates a sensor simulating a tempo/threshold run.
    public static func tempoRun(baseHR: UInt16 = 70, maxHR: UInt16 = 180) -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .steadyState(percentOfMax: 0.85),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }

    /// Creates a sensor simulating high-intensity interval training.
    public static func hiitWorkout(
        baseHR: UInt16 = 70,
        maxHR: UInt16 = 180,
        workInterval: TimeInterval = 30,
        restInterval: TimeInterval = 30
    ) -> SimulatedHeartRateSensor {
        let highHR = UInt16(Double(maxHR) * 0.9)
        let lowHR = UInt16(Double(maxHR) * 0.6)

        return SimulatedHeartRateSensor(
            profile: .intervals(
                highHR: highHR,
                lowHR: lowHR,
                highDuration: workInterval,
                lowDuration: restInterval
            ),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }

    /// Creates a sensor simulating a complete workout with warmup and cooldown.
    public static func completeWorkout(
        baseHR: UInt16 = 70,
        mainHR: UInt16 = 155,
        warmupMinutes: Double = 10,
        mainMinutes: Double = 30,
        cooldownMinutes: Double = 5
    ) -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .fullWorkout(
                warmupDuration: warmupMinutes * 60,
                mainHR: mainHR,
                mainDuration: mainMinutes * 60,
                cooldownDuration: cooldownMinutes * 60
            ),
            baseHeartRate: baseHR
        )
    }

    /// Creates a sensor simulating a 5K interval workout.
    public static func interval5K(baseHR: UInt16 = 70, maxHR: UInt16 = 185) -> SimulatedHeartRateSensor {
        // 5 x 1000m intervals with 400m recovery jogs
        // Approximate times: 4 min fast, 2 min recovery
        SimulatedHeartRateSensor(
            profile: .intervals(
                highHR: UInt16(Double(maxHR) * 0.92),
                lowHR: UInt16(Double(maxHR) * 0.65),
                highDuration: 240,  // 4 minutes
                lowDuration: 120    // 2 minutes
            ),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }

    /// Creates a sensor simulating a progressive long run.
    public static func progressiveLongRun(
        baseHR: UInt16 = 70,
        maxHR: UInt16 = 180,
        stages: Int = 4,
        stageDuration: TimeInterval = 600 // 10 minutes per stage
    ) -> SimulatedHeartRateSensor {
        // Create progressive stages from 60% to 80% of max HR
        let hrStages = (0..<stages).map { stage in
            let percent = 0.6 + (0.2 * Double(stage) / Double(stages - 1))
            return UInt16(Double(baseHR) + (Double(maxHR) - Double(baseHR)) * percent)
        }

        return SimulatedHeartRateSensor(
            profile: .progressive(stages: hrStages, stageDuration: stageDuration),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }

    /// Creates a sensor simulating sensor contact issues (intermittent signal).
    public static func unreliableContact() -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .constant(heartRate: 140),
            contactStatus: .supportedButNotDetected
        )
    }
}

// MARK: - Heart Rate Zone Helpers

extension SimulatedHeartRateSensor {

    /// Standard heart rate training zones.
    public enum HeartRateZone: Int, CaseIterable, Sendable {
        case recovery = 1    // 50-60% max HR
        case aerobic = 2     // 60-70% max HR
        case tempo = 3       // 70-80% max HR
        case threshold = 4   // 80-90% max HR
        case vo2max = 5      // 90-100% max HR

        /// Returns the percentage range for this zone.
        public var percentageRange: ClosedRange<Double> {
            switch self {
            case .recovery:  return 0.50...0.60
            case .aerobic:   return 0.60...0.70
            case .tempo:     return 0.70...0.80
            case .threshold: return 0.80...0.90
            case .vo2max:    return 0.90...1.00
            }
        }

        /// Returns the midpoint percentage for this zone.
        public var midpointPercentage: Double {
            (percentageRange.lowerBound + percentageRange.upperBound) / 2.0
        }
    }

    /// Creates a sensor targeting a specific heart rate zone.
    public static func forZone(
        _ zone: HeartRateZone,
        baseHR: UInt16 = 70,
        maxHR: UInt16 = 180
    ) -> SimulatedHeartRateSensor {
        SimulatedHeartRateSensor(
            profile: .steadyState(percentOfMax: zone.midpointPercentage),
            baseHeartRate: baseHR,
            maxHeartRate: maxHR
        )
    }
}
