//
//  WorkoutMetricsTests.swift
//  JogPod Tests
//
//  Tests for WorkoutMetrics computation and WorkoutSnapshot.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - WorkoutMetrics Tests

@Suite("WorkoutMetrics")
@MainActor
struct WorkoutMetricsTests {

    // MARK: - Initialization

    @Test("initializes with default values")
    func initializesWithDefaults() {
        let metrics = WorkoutMetrics()

        #expect(metrics.totalDistance == 0)
        #expect(metrics.currentSpeed == 0)
        #expect(metrics.averageSpeed == 0)
        #expect(metrics.maxSpeed == 0)
        #expect(metrics.minSpeed == 0)
        #expect(metrics.totalElevationGain == 0)
        #expect(metrics.totalElevationLoss == 0)
        #expect(metrics.currentHeartRate == 0)
        #expect(metrics.averageHeartRate == 0)
        #expect(metrics.totalSteps == 0)
        #expect(metrics.caloriesBurned == 0)
        #expect(metrics.isAtPeakSpeed == false)
        #expect(metrics.gpsSignalLevel == .none)
    }

    @Test("initializes with custom start time and weight")
    func initializesWithCustomValues() {
        let startTime = Date().addingTimeInterval(-3600)
        let metrics = WorkoutMetrics(startTime: startTime, userWeight: 80.0)

        // Duration should be approximately 1 hour
        #expect(metrics.duration >= 3599 && metrics.duration <= 3601)
    }

    // MARK: - Location Updates

    @Test("updates distance correctly from consecutive locations")
    func updatesDistanceFromLocations() {
        let metrics = WorkoutMetrics()

        // Create two locations approximately 100 meters apart
        let loc1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let loc2 = CLLocation(latitude: 37.7759, longitude: -122.4194) // ~111m north

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)

        // Distance should be approximately 111 meters (1 degree lat ≈ 111km)
        #expect(metrics.totalDistance > 100)
        #expect(metrics.totalDistance < 150)
    }

    @Test("ignores GPS jumps over 1km")
    func ignoresGPSJumps() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let loc2 = CLLocation(latitude: 38.7749, longitude: -122.4194) // ~111km north (GPS jump)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)

        // Distance should not include the jump
        #expect(metrics.totalDistance < 1000)
    }

    @Test("updates GPS signal level from accuracy")
    func updatesGPSSignalLevel() {
        let metrics = WorkoutMetrics()

        let excellentAccuracyLocation = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 5
        )

        metrics.updateWithLocation(excellentAccuracyLocation)
        #expect(metrics.gpsSignalLevel == .excellent)

        let poorAccuracyLocation = CLLocation.makeTestLocation(
            latitude: 37.7759,
            longitude: -122.4194,
            horizontalAccuracy: 150
        )

        metrics.updateWithLocation(poorAccuracyLocation)
        #expect(metrics.gpsSignalLevel == .veryPoor)
    }

    @Test("updates elevation gain and loss")
    func updatesElevation() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, altitude: 100)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, altitude: 150)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, altitude: 120)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        #expect(metrics.totalElevationGain == 50) // 100 -> 150
        #expect(metrics.totalElevationLoss == 30) // 150 -> 120
        #expect(metrics.currentElevation == 120)
        #expect(metrics.maxElevation == 150)
        #expect(metrics.minElevation == 100)
    }

    @Test("updates speed with rolling average")
    func updatesSpeedWithRollingAverage() {
        let metrics = WorkoutMetrics()

        // Create locations with speed data
        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, speed: 3.0)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, speed: 4.0)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, speed: 5.0)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        // Rolling average of 3, 4, 5 = 4
        #expect(metrics.currentSpeed == 4.0)
    }

    @Test("ignores negative speed readings")
    func ignoresNegativeSpeed() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, speed: -1)

        metrics.updateWithLocation(loc1)

        // Speed should remain at 0 (default)
        #expect(metrics.currentSpeed == 0)
    }

    @Test("detects peak speed")
    func detectsPeakSpeed() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, speed: 3.0)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, speed: 4.0)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, speed: 5.0)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        // Should be at peak speed (max speed was just set)
        #expect(metrics.isAtPeakSpeed == true)
    }

    @Test("updates steps from location")
    func updatesStepsFromLocation() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        metrics.updateWithLocation(loc1, steps: 100)

        #expect(metrics.totalSteps == 100)
    }

    // MARK: - Heart Rate Updates

    @Test("updates heart rate correctly")
    func updatesHeartRate() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(120)

        #expect(metrics.currentHeartRate == 120)
        #expect(metrics.averageHeartRate == 120)
        #expect(metrics.maxHeartRate == 120)
        #expect(metrics.minHeartRate == 120)
    }

    @Test("calculates heart rate average correctly")
    func calculatesHeartRateAverage() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(100)
        metrics.updateWithHeartRate(120)
        metrics.updateWithHeartRate(140)

        #expect(metrics.averageHeartRate == 120) // (100 + 120 + 140) / 3
    }

    @Test("tracks heart rate min and max")
    func tracksHeartRateMinMax() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(100)
        metrics.updateWithHeartRate(150)
        metrics.updateWithHeartRate(80)
        metrics.updateWithHeartRate(130)

        #expect(metrics.maxHeartRate == 150)
        #expect(metrics.minHeartRate == 80)
    }

    @Test("ignores invalid heart rate values")
    func ignoresInvalidHeartRate() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(0) // Invalid
        metrics.updateWithHeartRate(-10) // Invalid
        metrics.updateWithHeartRate(300) // Too high

        #expect(metrics.currentHeartRate == 0)
        #expect(metrics.averageHeartRate == 0)
    }

    @Test("updates steps from heart rate update")
    func updatesStepsFromHeartRate() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(120, steps: 500)

        #expect(metrics.totalSteps == 500)
    }

    // MARK: - Calorie Calculation

    @Test("calculates calories with heart rate data")
    func calculatesCaloriesWithHeartRate() {
        let startTime = Date().addingTimeInterval(-1800) // 30 minutes ago
        let metrics = WorkoutMetrics(startTime: startTime, userWeight: 70.0)

        // Add some heart rate data
        metrics.updateWithHeartRate(140)
        metrics.updateWithHeartRate(150)
        metrics.updateWithHeartRate(145)

        // With moderate heart rate for 30 minutes, should burn some calories
        #expect(metrics.caloriesBurned > 0)
    }

    @Test("calculates calories based on speed when no heart rate")
    func calculatesCaloriesFromSpeed() {
        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let metrics = WorkoutMetrics(startTime: startTime, userWeight: 70.0)

        // Add location data with speed (running at ~10 km/h = 2.78 m/s)
        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, speed: 2.78)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, speed: 2.78)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, speed: 2.78)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        // Running for 1 hour should burn significant calories
        #expect(metrics.caloriesBurned > 0)
    }

    // MARK: - Reset

    @Test("reset clears all values")
    func resetClearsAllValues() {
        let metrics = WorkoutMetrics()

        // Add some data
        metrics.updateWithLocation(CLLocation(latitude: 37.7749, longitude: -122.4194))
        metrics.updateWithHeartRate(120)

        // Reset
        metrics.reset()

        // Verify all values are reset
        #expect(metrics.totalDistance == 0)
        #expect(metrics.currentSpeed == 0)
        #expect(metrics.averageSpeed == 0)
        #expect(metrics.currentHeartRate == 0)
        #expect(metrics.averageHeartRate == 0)
        #expect(metrics.totalSteps == 0)
        #expect(metrics.gpsSignalLevel == .none)
    }

    // MARK: - Snapshot

    @Test("snapshot captures current state")
    func snapshotCapturesState() {
        let metrics = WorkoutMetrics()

        metrics.updateWithLocation(CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 3.0
        ))
        metrics.updateWithHeartRate(120)

        let snapshot = metrics.snapshot()

        #expect(snapshot.currentHeartRate == 120)
        #expect(snapshot.gpsSignalLevel == .excellent)
    }

    // MARK: - Pace Calculations

    @Test("calculates pace per kilometer")
    func calculatesPacePerKilometer() {
        let metrics = WorkoutMetrics()

        // Speed of 3 m/s = 180 m/min = 0.18 km/min
        // Pace = 1 / 0.18 = ~5.56 min/km
        let loc = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, speed: 3.0)
        metrics.updateWithLocation(loc)
        metrics.updateWithLocation(loc) // Need multiple readings for rolling average
        metrics.updateWithLocation(loc)

        let pace = metrics.pacePerKilometer
        #expect(pace != nil)
        #expect(pace! > 5 && pace! < 6)
    }

    @Test("pace is nil when speed is zero")
    func paceNilWhenSpeedZero() {
        let metrics = WorkoutMetrics()

        #expect(metrics.pacePerKilometer == nil)
        #expect(metrics.pacePerMile == nil)
    }

    // MARK: - Average Step Length

    @Test("calculates average step length")
    func calculatesAverageStepLength() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let loc2 = CLLocation(latitude: 37.7759, longitude: -122.4194) // ~111m north

        metrics.updateWithLocation(loc1, steps: 0)
        metrics.updateWithLocation(loc2, steps: 100)

        // Distance ~111m with 100 steps = ~1.11m per step
        let stepLength = metrics.averageStepLength
        #expect(stepLength != nil)
        #expect(stepLength! > 1.0 && stepLength! < 1.5)
    }

    @Test("step length is nil when no steps")
    func stepLengthNilWhenNoSteps() {
        let metrics = WorkoutMetrics()

        #expect(metrics.averageStepLength == nil)
    }
}

// MARK: - WorkoutSnapshot Tests

@Suite("WorkoutSnapshot")
struct WorkoutSnapshotTests {

    @Test("empty snapshot has default values")
    func emptySnapshotDefaults() {
        let snapshot = WorkoutSnapshot.empty

        #expect(snapshot.totalDistance == 0)
        #expect(snapshot.duration == 0)
        #expect(snapshot.currentSpeed == 0)
        #expect(snapshot.averageSpeed == 0)
        #expect(snapshot.currentHeartRate == 0)
        #expect(snapshot.totalSteps == 0)
        #expect(snapshot.caloriesBurned == 0)
        #expect(snapshot.gpsSignalLevel == .none)
    }

    @Test("distanceInKilometers converts correctly")
    func distanceInKilometersConversion() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 5000, // 5000 meters
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

        #expect(snapshot.distanceInKilometers == 5.0)
    }

    @Test("distanceInMiles converts correctly")
    func distanceInMilesConversion() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 1609.34, // Approximately 1 mile
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

        #expect(abs(snapshot.distanceInMiles - 1.0) < 0.01)
    }

    @Test("formattedDuration formats correctly for minutes and seconds")
    func formattedDurationMinutesSeconds() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 0,
            duration: 125, // 2:05
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

        #expect(snapshot.formattedDuration == "2:05")
    }

    @Test("formattedDuration formats correctly for hours")
    func formattedDurationHours() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 0,
            duration: 3725, // 1:02:05
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

        #expect(snapshot.formattedDuration == "1:02:05")
    }

    @Test("currentSpeedKmh converts correctly")
    func currentSpeedKmhConversion() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 0,
            duration: 0,
            currentSpeed: 2.78, // ~10 km/h
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

        #expect(abs(snapshot.currentSpeedKmh - 10.0) < 0.1)
    }

    @Test("formattedPacePerKm formats correctly")
    func formattedPacePerKmFormat() {
        let snapshot = WorkoutSnapshot(
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
            pacePerKilometer: 5.5, // 5:30 min/km
            pacePerMile: nil,
            averageStepLength: nil
        )

        #expect(snapshot.formattedPacePerKm == "5:30")
    }

    @Test("formattedPacePerKm returns nil for invalid pace")
    func formattedPacePerKmNilForInvalid() {
        let snapshot = WorkoutSnapshot.empty

        #expect(snapshot.formattedPacePerKm == nil)
    }

    @Test("WorkoutSnapshot is equatable")
    func snapshotEquality() {
        let snapshot1 = WorkoutSnapshot.empty
        let snapshot2 = WorkoutSnapshot.empty

        #expect(snapshot1 == snapshot2)
    }

    @Test("WorkoutSnapshot is sendable")
    func snapshotIsSendable() async {
        let snapshot = WorkoutSnapshot.empty

        await Task.detached {
            // This compiles because WorkoutSnapshot is Sendable
            _ = snapshot.totalDistance
        }.value
    }
}
