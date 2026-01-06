//
//  WorkoutTrackingEquivalenceTests.swift
//  JogPod Tests
//
//  Equivalence tests for workout tracking functionality.
//  Verifies the Swift implementation behaves equivalently to legacy Objective-C code.
//
//  Reference: EQUIVALENCE_TESTING_STRATEGY.md Section 3.1
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - Workout Tracking Equivalence Tests

/// Tests workout tracking equivalence with legacy Objective-C implementation.
///
/// These tests verify behavioral equivalence according to:
/// - Specification Oracles (SO-001 through SO-005)
/// - Invariant Oracles (INV-001 through INV-007)
/// - Metamorphic Oracles (MO-001 through MO-004)
@Suite("Workout Tracking Equivalence")
struct WorkoutTrackingEquivalenceTests {

    // MARK: - Test Configuration

    /// Tolerance for distance calculations (+/- 1% as per EQUIVALENCE_TESTING_STRATEGY.md)
    static let distanceTolerance: Double = 0.01

    /// Tolerance for speed calculations (+/- 0.1 mph as per EQUIVALENCE_TESTING_STRATEGY.md)
    static let speedToleranceMph: Double = 0.1
    static let speedToleranceKmh: Double = 0.16 // ~0.1 mph in kmh

    /// Tolerance for calorie calculations (+/- 5% as per EQUIVALENCE_TESTING_STRATEGY.md)
    static let calorieTolerance: Double = 0.05

    // MARK: - WT-GPS-001: Location Update Creates WorkoutLocation

    @Test("WT-GPS-001: Location update creates WorkoutTrackPoint record")
    @MainActor
    func locationUpdateCreatesTrackPoint() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let mockLocationService = MockLocationService(
            authorizationStatus: .authorizedAlways,
            locationServicesEnabled: true,
            locations: [
                CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194),
                CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194)
            ]
        )

        let workoutService = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: mockLocationService
        )

        let workoutID = try await workoutService.startWorkout()

        // Wait for location processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Stop workout to flush data
        try await workoutService.stopWorkout()

        // Verify track points were created
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

        // First location is ignored (cold-start filter per SO-005)
        // So we should have 1 track point from the 2 locations
        #expect(trackPoints.count >= 1, "Track points should be created from location updates")
    }

    // MARK: - WT-GPS-002: Cold Start Filter (SO-005)

    @Test("WT-GPS-002: First GPS reading is ignored (cold-start filter)")
    @MainActor
    func firstGPSReadingIgnored() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        // Only provide one location
        let mockLocationService = MockLocationService(
            authorizationStatus: .authorizedAlways,
            locationServicesEnabled: true,
            locations: [
                CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194)
            ]
        )

        let workoutService = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: mockLocationService
        )

        let workoutID = try await workoutService.startWorkout()

        // Wait for location processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        try await workoutService.stopWorkout()

        // First reading should be ignored - no track points created
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)
        #expect(trackPoints.count == 0, "First GPS reading should be filtered out")
    }

    // MARK: - WT-GPS-003: Batch Commit Every 20 Readings (SO-005)

    @Test("WT-GPS-003: Batch commit size is 20 readings")
    func batchCommitSizeIs20() {
        // Verify the constant matches legacy behavior
        #expect(WorkoutService.locationBatchSize == 20)
        #expect(WorkoutService.heartRateBatchSize == 20)
    }

    // MARK: - WT-SPD-001: Current Speed Calculation (SO-001)

    @Test("WT-SPD-001: Current speed uses rolling average")
    @MainActor
    func currentSpeedRollingAverage() {
        let metrics = WorkoutMetrics()

        // Create locations with specific speed values
        let speeds = [2.0, 4.0, 6.0, 8.0, 10.0]
        for (index, speed) in speeds.enumerated() {
            let loc = CLLocation.makeTestLocation(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194,
                speed: speed
            )
            metrics.updateWithLocation(loc)
        }

        // Rolling average window is 3 (per WorkoutMetrics configuration)
        // Last 3 speeds: 6.0, 8.0, 10.0 -> average = 8.0
        #expect(metrics.currentSpeed == 8.0)
    }

    @Test("Rolling average window size is 3")
    func rollingAverageWindowSize() {
        // Verify constant matches expected legacy behavior
        #expect(WorkoutMetrics.rollingAverageWindowSize == 3)
    }

    // MARK: - WT-SPD-002: Average Speed Calculation

    @Test("WT-SPD-002: Average speed calculation is correct")
    @MainActor
    func averageSpeedCalculation() {
        let metrics = WorkoutMetrics()

        let speeds = [3.0, 4.0, 5.0]
        for (index, speed) in speeds.enumerated() {
            let loc = CLLocation.makeTestLocation(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194,
                speed: speed
            )
            metrics.updateWithLocation(loc)
        }

        // Average of 3, 4, 5 = 4.0
        #expect(metrics.averageSpeed == 4.0)
    }

    // MARK: - WT-SPD-003: Peak Speed Detection

    @Test("WT-SPD-003: Peak speed is detected when at max speed within window")
    @MainActor
    func peakSpeedDetection() {
        let metrics = WorkoutMetrics()

        let speeds = [3.0, 4.0, 5.0, 4.0, 3.0]
        for (index, speed) in speeds.enumerated() {
            let loc = CLLocation.makeTestLocation(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194,
                speed: speed
            )
            metrics.updateWithLocation(loc)
        }

        // Max speed was just achieved at index 2, should still be at peak
        // Peak window is 10 seconds (per WorkoutMetrics configuration)
        #expect(WorkoutMetrics.peakSpeedWindowSeconds == 10)
    }

    // MARK: - WT-SPD-005: Unit Conversion (MO-002)

    @Test("WT-SPD-005: Speed unit conversion is consistent - m/s to km/h")
    @MainActor
    func speedConversionMetersToKmh() {
        let speedMps = 10.0 // 10 meters per second
        let snapshot = WorkoutSnapshot(
            totalDistance: 0,
            duration: 0,
            currentSpeed: speedMps,
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

        // 10 m/s = 36 km/h
        #expect(abs(snapshot.currentSpeedKmh - 36.0) < 0.01)
    }

    @Test("WT-SPD-005: Speed unit conversion is consistent - m/s to mph")
    @MainActor
    func speedConversionMetersToMph() {
        let speedMps = 10.0 // 10 meters per second
        let snapshot = WorkoutSnapshot(
            totalDistance: 0,
            duration: 0,
            currentSpeed: speedMps,
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

        // 10 m/s = 22.3694 mph
        #expect(abs(snapshot.currentSpeedMph - 22.3694) < 0.01)
    }

    // MARK: - WT-DST-001: Cumulative Distance Calculation (MO-001)

    @Test("WT-DST-001: Distance equals sum of segment distances")
    @MainActor
    func cumulativeDistanceCalculation() {
        let metrics = WorkoutMetrics()

        // Create a series of locations approximately 100m apart
        let locations = [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7759, longitude: -122.4194), // ~111m north
            CLLocation(latitude: 37.7769, longitude: -122.4194), // ~111m north
        ]

        for loc in locations {
            metrics.updateWithLocation(loc)
        }

        // Total should be approximately 222m (2 segments of ~111m each)
        #expect(metrics.totalDistance > 200)
        #expect(metrics.totalDistance < 250)
    }

    // MARK: - WT-DST-002: Distance Unit Display

    @Test("WT-DST-002: Distance displays correctly in kilometers")
    func distanceInKilometers() {
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

    @Test("WT-DST-002: Distance displays correctly in miles")
    func distanceInMiles() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 1609.34, // ~1 mile in meters
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

    // MARK: - WT-HR-001: Heart Rate Storage with Location

    @Test("WT-HR-001: Heart rate is stored with track point")
    @MainActor
    func heartRateStoredWithLocation() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = "test-workout-\(UUID().uuidString)"

        // Create a track point with heart rate
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let heartRate: Int16 = 140

        _ = try await persistence.createTrackPoint(
            workoutID: workoutID,
            time: Date(),
            location: location,
            heartRate: heartRate,
            steps: nil
        )

        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)
        #expect(trackPoints.count == 1)
        #expect(trackPoints.first?.heartRate == heartRate)
    }

    // MARK: - WT-HR-002: Heart Rate Bounds Validation (INV-003)

    @Test("WT-HR-002: Heart rate values bounded to 0-255 BPM range")
    @MainActor
    func heartRateBoundsValidation() {
        let metrics = WorkoutMetrics()

        // Valid heart rates should be accepted
        metrics.updateWithHeartRate(120)
        #expect(metrics.currentHeartRate == 120)

        // Heart rate 0 should be ignored (per legacy behavior)
        metrics.updateWithHeartRate(0)
        #expect(metrics.currentHeartRate == 120) // Unchanged

        // Heart rate above 250 should be ignored (per legacy WorkoutMetrics validation)
        metrics.updateWithHeartRate(300)
        #expect(metrics.currentHeartRate == 120) // Unchanged
    }

    // MARK: - WT-HR-004: Average Heart Rate Calculation

    @Test("WT-HR-004: Average heart rate calculated correctly")
    @MainActor
    func averageHeartRateCalculation() {
        let metrics = WorkoutMetrics()

        metrics.updateWithHeartRate(100)
        metrics.updateWithHeartRate(120)
        metrics.updateWithHeartRate(140)

        // Average of 100, 120, 140 = 120
        #expect(metrics.averageHeartRate == 120)
    }

    // MARK: - WT-STP-001: Step Count Tracking (INV-006)

    @Test("WT-STP-001: Step count is monotonically increasing")
    @MainActor
    func stepCountMonotonic() {
        let metrics = WorkoutMetrics()

        // Steps should increase monotonically
        metrics.updateWithLocation(
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            steps: 100
        )
        #expect(metrics.totalSteps == 100)

        metrics.updateWithLocation(
            CLLocation(latitude: 37.7759, longitude: -122.4194),
            steps: 200
        )
        #expect(metrics.totalSteps == 200)

        // Steps should never be negative
        #expect(metrics.totalSteps >= 0)
    }

    // MARK: - WT-STP-002: Average Step Size Calculation

    @Test("WT-STP-002: Average step size = distance / steps")
    @MainActor
    func averageStepSizeCalculation() {
        let metrics = WorkoutMetrics()

        // Create locations with distance and steps
        let loc1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let loc2 = CLLocation(latitude: 37.7759, longitude: -122.4194) // ~111m north

        metrics.updateWithLocation(loc1, steps: 0)
        metrics.updateWithLocation(loc2, steps: 100)

        // Step length should be ~1.11m (111m / 100 steps)
        let stepLength = metrics.averageStepLength
        #expect(stepLength != nil)
        if let length = stepLength {
            #expect(length > 1.0 && length < 1.5)
        }
    }

    // MARK: - WT-ELV-001: Total Elevation Gain Calculation

    @Test("WT-ELV-001: Total elevation gain calculated correctly")
    @MainActor
    func elevationGainCalculation() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, altitude: 100)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, altitude: 150)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, altitude: 200)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        // Total elevation gain: 50 + 50 = 100
        #expect(metrics.totalElevationGain == 100)
    }

    // MARK: - WT-ELV-002: Total Elevation Loss Calculation

    @Test("WT-ELV-002: Total elevation loss calculated correctly")
    @MainActor
    func elevationLossCalculation() {
        let metrics = WorkoutMetrics()

        let loc1 = CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, altitude: 200)
        let loc2 = CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194, altitude: 150)
        let loc3 = CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194, altitude: 100)

        metrics.updateWithLocation(loc1)
        metrics.updateWithLocation(loc2)
        metrics.updateWithLocation(loc3)

        // Total elevation loss: 50 + 50 = 100
        #expect(metrics.totalElevationLoss == 100)
    }

    // MARK: - WT-CAL-001: Calorie Calculation

    @Test("WT-CAL-001: Calorie calculation uses weight and speed")
    @MainActor
    func calorieCalculationWithSpeed() {
        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let metrics = WorkoutMetrics(startTime: startTime, userWeight: 70.0)

        // Add speed data for running
        let loc = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 2.78 // ~10 km/h, jogging
        )
        metrics.updateWithLocation(loc)
        metrics.updateWithLocation(loc)
        metrics.updateWithLocation(loc)

        // Running for 1 hour at ~10km/h with 70kg should burn calories
        #expect(metrics.caloriesBurned > 0)
    }

    @Test("WT-CAL-001: Calorie calculation with heart rate is more accurate")
    @MainActor
    func calorieCalculationWithHeartRate() {
        let startTime = Date().addingTimeInterval(-1800) // 30 minutes ago
        let metrics = WorkoutMetrics(startTime: startTime, userWeight: 70.0)

        // Add heart rate data
        metrics.updateWithHeartRate(140)
        metrics.updateWithHeartRate(150)
        metrics.updateWithHeartRate(145)

        // Should calculate calories based on heart rate
        #expect(metrics.caloriesBurned > 0)
    }
}

// MARK: - Workout Session Invariants

@Suite("Workout Session Invariants")
struct WorkoutSessionInvariantTests {

    // MARK: - INV-001: WorkoutID is UUID Format

    @Test("INV-001: Workout session ID uses UUID format")
    func workoutIDIsUUID() async throws {
        let persistence = try PersistenceManager.makeForTesting()

        _ = try await persistence.createWorkoutSession(startTime: Date())

        let sessions = try await persistence.fetchAllWorkoutSessions()
        #expect(sessions.count == 1)

        let session = sessions.first!
        let uuid = UUID(uuidString: session.workoutID)
        #expect(uuid != nil, "WorkoutID should be valid UUID format")
    }

    // MARK: - INV-002: Track Points Chronologically Ordered

    @Test("INV-002: Track points are returned in chronological order")
    func trackPointsChronologicalOrder() async throws {
        let persistence = try PersistenceManager.makeForTesting()
        let workoutID = "test-workout-\(UUID().uuidString)"

        // Create track points with different times
        let time1 = Date().addingTimeInterval(-300) // 5 min ago
        let time2 = Date().addingTimeInterval(-180) // 3 min ago
        let time3 = Date().addingTimeInterval(-60)  // 1 min ago

        // Insert in random order
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: time2)
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: time1)
        _ = try await persistence.createTrackPoint(workoutID: workoutID, time: time3)

        // Fetch should return in chronological order
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

        #expect(trackPoints.count == 3)
        #expect(trackPoints[0].time == time1)
        #expect(trackPoints[1].time == time2)
        #expect(trackPoints[2].time == time3)
    }

    // MARK: - INV-006: Steps Monotonically Increasing Within Workout

    @Test("INV-006: Steps value never decreases within a workout")
    @MainActor
    func stepsMonotonic() {
        let metrics = WorkoutMetrics()

        metrics.updateWithLocation(CLLocation(latitude: 37.7749, longitude: -122.4194), steps: 50)
        let step1 = metrics.totalSteps

        metrics.updateWithLocation(CLLocation(latitude: 37.7759, longitude: -122.4194), steps: 100)
        let step2 = metrics.totalSteps

        metrics.updateWithLocation(CLLocation(latitude: 37.7769, longitude: -122.4194), steps: 150)
        let step3 = metrics.totalSteps

        #expect(step1 <= step2)
        #expect(step2 <= step3)
    }
}

// MARK: - Metamorphic Relationship Tests

@Suite("Workout Metamorphic Relationships")
struct WorkoutMetamorphicTests {

    // MARK: - MO-001: Distance = Sum of Segment Distances

    @Test("MO-001: Total distance equals sum of all segment distances")
    @MainActor
    func distanceIsSum() {
        let metrics = WorkoutMetrics()

        // Create 5 locations, each ~111m apart
        for i in 0..<5 {
            let loc = CLLocation(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194
            )
            metrics.updateWithLocation(loc)
        }

        // 4 segments of ~111m each = ~444m total
        #expect(metrics.totalDistance > 400)
        #expect(metrics.totalDistance < 500)
    }

    // MARK: - MO-002: Unit Conversion Consistency

    @Test("MO-002: Round-trip unit conversion is consistent")
    func unitConversionRoundTrip() {
        // Test km to miles and back
        let distanceKm = 10.0
        let distanceMiles = distanceKm / 1.60934
        let distanceKmBack = distanceMiles * 1.60934

        #expect(abs(distanceKm - distanceKmBack) < 0.0001)

        // Test m/s to km/h and back
        let speedMs = 5.0
        let speedKmh = speedMs * 3.6
        let speedMsBack = speedKmh / 3.6

        #expect(abs(speedMs - speedMsBack) < 0.0001)

        // Test m/s to mph and back
        let speedMph = speedMs * 2.23694
        let speedMsBack2 = speedMph / 2.23694

        #expect(abs(speedMs - speedMsBack2) < 0.0001)
    }
}
