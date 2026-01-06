//
//  HealthKitWorkoutDataTests.swift
//  JogPodTests
//
//  Unit tests for HealthKit workout data models.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitWorkoutDataTests: XCTestCase {

    // MARK: - HealthKitWorkoutData Tests

    func testWorkoutDataInitialization() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: endTime,
            activityType: .running,
            totalEnergyBurned: 350,
            totalDistance: 5000,
            distanceUnit: .meters
        )

        XCTAssertEqual(workout.startTime, startTime)
        XCTAssertEqual(workout.endTime, endTime)
        XCTAssertEqual(workout.activityType, .running)
        XCTAssertEqual(workout.totalEnergyBurned, 350)
        XCTAssertEqual(workout.totalDistance, 5000)
        XCTAssertEqual(workout.distanceUnit, .meters)
        XCTAssertEqual(workout.duration, 3600, accuracy: 0.001)
    }

    func testWorkoutDataDefaultValues() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1800)

        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: endTime
        )

        XCTAssertEqual(workout.activityType, .running)
        XCTAssertEqual(workout.totalEnergyBurned, 0)
        XCTAssertEqual(workout.totalDistance, 0)
        XCTAssertEqual(workout.distanceUnit, .meters)
        XCTAssertTrue(workout.heartRateSamples.isEmpty)
        XCTAssertTrue(workout.routePoints.isEmpty)
    }

    func testWorkoutDataValidation() {
        let now = Date()

        // Valid workout
        let validWorkout = HealthKitWorkoutData(
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            totalEnergyBurned: 350,
            totalDistance: 5000
        )
        XCTAssertTrue(validWorkout.isValid)

        // Invalid: end before start
        let invalidEndTime = HealthKitWorkoutData(
            startTime: now,
            endTime: now.addingTimeInterval(-3600)
        )
        XCTAssertFalse(invalidEndTime.isValid)

        // Invalid: negative energy
        let negativeEnergy = HealthKitWorkoutData(
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            totalEnergyBurned: -100
        )
        XCTAssertFalse(negativeEnergy.isValid)

        // Invalid: negative distance
        let negativeDistance = HealthKitWorkoutData(
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            totalDistance: -1000
        )
        XCTAssertFalse(negativeDistance.isValid)

        // Invalid: zero duration
        let zeroDuration = HealthKitWorkoutData(
            startTime: now,
            endTime: now
        )
        XCTAssertFalse(zeroDuration.isValid)
    }

    func testWorkoutDataEquality() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let workout1 = HealthKitWorkoutData(
            startTime: startTime,
            endTime: endTime,
            totalEnergyBurned: 350,
            totalDistance: 5000
        )

        let workout2 = HealthKitWorkoutData(
            startTime: startTime,
            endTime: endTime,
            totalEnergyBurned: 350,
            totalDistance: 5000
        )

        XCTAssertEqual(workout1, workout2)
    }

    func testWorkoutDataWithHeartRateSamples() {
        let startTime = Date()
        let samples = [
            HeartRateSample(bpm: 120, timestamp: startTime),
            HeartRateSample(bpm: 140, timestamp: startTime.addingTimeInterval(60)),
            HeartRateSample(bpm: 150, timestamp: startTime.addingTimeInterval(120))
        ]

        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(300),
            heartRateSamples: samples
        )

        XCTAssertEqual(workout.heartRateSamples.count, 3)
        XCTAssertEqual(workout.heartRateSamples[0].beatsPerMinute, 120)
        XCTAssertEqual(workout.heartRateSamples[1].beatsPerMinute, 140)
        XCTAssertEqual(workout.heartRateSamples[2].beatsPerMinute, 150)
    }

    // MARK: - DistanceUnit Tests

    func testDistanceUnitHKUnits() {
        XCTAssertEqual(DistanceUnit.meters.hkUnit, HKUnit.meter())
        XCTAssertEqual(DistanceUnit.miles.hkUnit, HKUnit.mile())
        XCTAssertEqual(DistanceUnit.kilometers.hkUnit, HKUnit.meterUnit(with: .kilo))
    }

    func testDistanceUnitConversion() {
        // Meters to meters
        XCTAssertEqual(DistanceUnit.meters.toMeters(1000), 1000, accuracy: 0.01)

        // Miles to meters
        XCTAssertEqual(DistanceUnit.miles.toMeters(1), 1609.34, accuracy: 0.01)

        // Kilometers to meters
        XCTAssertEqual(DistanceUnit.kilometers.toMeters(1), 1000, accuracy: 0.01)
    }

    func testDistanceUnitCaseIterable() {
        let allCases = DistanceUnit.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.meters))
        XCTAssertTrue(allCases.contains(.miles))
        XCTAssertTrue(allCases.contains(.kilometers))
    }

    // MARK: - HeartRateSample Tests

    func testHeartRateSampleInitialization() {
        let timestamp = Date()

        let sample1 = HeartRateSample(beatsPerMinute: 120.5, timestamp: timestamp)
        XCTAssertEqual(sample1.beatsPerMinute, 120.5)
        XCTAssertEqual(sample1.timestamp, timestamp)

        let sample2 = HeartRateSample(bpm: 140, timestamp: timestamp)
        XCTAssertEqual(sample2.beatsPerMinute, 140.0)
    }

    func testHeartRateSampleEquality() {
        let timestamp = Date()

        let sample1 = HeartRateSample(bpm: 120, timestamp: timestamp)
        let sample2 = HeartRateSample(bpm: 120, timestamp: timestamp)

        XCTAssertEqual(sample1, sample2)
    }

    // MARK: - RoutePoint Tests

    func testRoutePointInitialization() {
        let timestamp = Date()

        let point = RoutePoint(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10,
            horizontalAccuracy: 5,
            verticalAccuracy: 3,
            timestamp: timestamp
        )

        XCTAssertEqual(point.latitude, 37.7749)
        XCTAssertEqual(point.longitude, -122.4194)
        XCTAssertEqual(point.altitude, 10)
        XCTAssertEqual(point.horizontalAccuracy, 5)
        XCTAssertEqual(point.verticalAccuracy, 3)
        XCTAssertEqual(point.timestamp, timestamp)
    }

    func testRoutePointDefaultValues() {
        let timestamp = Date()

        let point = RoutePoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: timestamp
        )

        XCTAssertEqual(point.altitude, 0)
        XCTAssertEqual(point.horizontalAccuracy, 0)
        XCTAssertEqual(point.verticalAccuracy, 0)
    }

    func testRoutePointEquality() {
        let timestamp = Date()

        let point1 = RoutePoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: timestamp
        )

        let point2 = RoutePoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: timestamp
        )

        XCTAssertEqual(point1, point2)
    }

    // MARK: - HealthKitWorkoutResult Tests

    func testWorkoutResultInitialization() {
        let id = UUID()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let result = HealthKitWorkoutResult(
            id: id,
            startTime: startTime,
            endTime: endTime,
            activityType: .running,
            duration: 3600,
            totalEnergyBurned: 350,
            totalDistanceMeters: 5000,
            sourceBundleIdentifier: "com.example.app",
            sourceName: "Example App"
        )

        XCTAssertEqual(result.id, id)
        XCTAssertEqual(result.startTime, startTime)
        XCTAssertEqual(result.endTime, endTime)
        XCTAssertEqual(result.activityType, .running)
        XCTAssertEqual(result.duration, 3600)
        XCTAssertEqual(result.totalEnergyBurned, 350)
        XCTAssertEqual(result.totalDistanceMeters, 5000)
        XCTAssertEqual(result.sourceBundleIdentifier, "com.example.app")
        XCTAssertEqual(result.sourceName, "Example App")
    }

    func testWorkoutResultFormattedDuration() {
        let startTime = Date()

        // 45 minutes
        let result1 = HealthKitWorkoutResult(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(2700),
            duration: 2700
        )
        XCTAssertEqual(result1.formattedDuration, "45:00")

        // 1 hour 30 minutes 45 seconds
        let result2 = HealthKitWorkoutResult(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(5445),
            duration: 5445
        )
        XCTAssertEqual(result2.formattedDuration, "1:30:45")

        // 5 minutes 30 seconds
        let result3 = HealthKitWorkoutResult(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(330),
            duration: 330
        )
        XCTAssertEqual(result3.formattedDuration, "5:30")
    }

    func testWorkoutResultDistanceConversion() {
        let startTime = Date()

        let result = HealthKitWorkoutResult(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600),
            duration: 3600,
            totalDistanceMeters: 5000
        )

        XCTAssertEqual(result.distanceKilometers, 5.0, accuracy: 0.001)
        XCTAssertEqual(result.distanceMiles ?? 0, 3.107, accuracy: 0.001)
    }

    func testWorkoutResultNilDistance() {
        let startTime = Date()

        let result = HealthKitWorkoutResult(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600),
            duration: 3600,
            totalDistanceMeters: nil
        )

        XCTAssertNil(result.distanceKilometers)
        XCTAssertNil(result.distanceMiles)
    }

    // MARK: - HealthKitUserData Tests

    func testUserDataInitialization() {
        let dateOfBirth = Calendar.current.date(
            from: DateComponents(year: 1990, month: 6, day: 15)
        )!

        let userData = HealthKitUserData(
            dateOfBirth: dateOfBirth,
            biologicalSex: .male,
            bodyMassKg: 75,
            heightMeters: 1.80
        )

        XCTAssertEqual(userData.dateOfBirth, dateOfBirth)
        XCTAssertEqual(userData.biologicalSex, .male)
        XCTAssertEqual(userData.bodyMassKg, 75)
        XCTAssertEqual(userData.heightMeters, 1.80)
    }

    func testUserDataAgeCalculation() {
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(
            byAdding: .year,
            value: -30,
            to: Date()
        )!

        let userData = HealthKitUserData(dateOfBirth: thirtyYearsAgo)

        XCTAssertEqual(userData.age, 30)
    }

    func testUserDataAgeCalculationNil() {
        let userData = HealthKitUserData(dateOfBirth: nil)
        XCTAssertNil(userData.age)
    }

    func testUserDataBodyMassConversion() {
        let userData = HealthKitUserData(bodyMassKg: 75)

        XCTAssertEqual(userData.bodyMassLbs ?? 0, 165.35, accuracy: 0.01)
    }

    func testUserDataHeightConversion() {
        let userData = HealthKitUserData(heightMeters: 1.80)

        XCTAssertEqual(userData.heightFeet ?? 0, 5.91, accuracy: 0.01)
    }

    func testUserDataNilConversions() {
        let userData = HealthKitUserData()

        XCTAssertNil(userData.bodyMassLbs)
        XCTAssertNil(userData.heightFeet)
    }
}
