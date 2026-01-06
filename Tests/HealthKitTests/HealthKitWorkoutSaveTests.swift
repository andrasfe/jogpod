//
//  HealthKitWorkoutSaveTests.swift
//  JogPodTests
//
//  Tests for HealthKit workout saving scenarios including success, failure,
//  validation, and various workout configurations.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitWorkoutSaveTests: XCTestCase {

    // MARK: - Properties

    var mockService: MockHealthKitService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockHealthKitService.successful()
    }

    override func tearDown() async throws {
        mockService = nil
        try await super.tearDown()
    }

    // MARK: - Successful Save Tests

    func testSaveValidWorkoutSucceeds() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertEqual(savedWorkouts.first?.activityType, .running)
    }

    func testSaveMultipleWorkoutsSucceeds() async throws {
        // Given
        let workout1 = HealthKitTestFixtures.validWorkoutData(duration: 1800)
        let workout2 = HealthKitTestFixtures.validWorkoutData(duration: 3600)
        let workout3 = HealthKitTestFixtures.validWorkoutData(duration: 5400)

        // When
        try await mockService.saveWorkout(workout1)
        try await mockService.saveWorkout(workout2)
        try await mockService.saveWorkout(workout3)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 3)
    }

    func testSaveWorkoutWithHeartRateSamples() async throws {
        // Given
        let workout = HealthKitTestFixtures.workoutDataWithHeartRate(
            duration: 1800,
            averageHeartRate: 150
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertFalse(savedWorkouts.first!.heartRateSamples.isEmpty)
    }

    func testSaveWorkoutWithRoutePoints() async throws {
        // Given
        let workout = HealthKitTestFixtures.workoutDataWithRoute(duration: 1800)

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertFalse(savedWorkouts.first!.routePoints.isEmpty)
    }

    func testSaveWorkoutWithMetadata() async throws {
        // Given
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            activityType: .running,
            totalEnergyBurned: 350,
            totalDistance: 5000,
            distanceUnit: .meters,
            metadata: [
                "WeatherCondition": "Sunny",
                "TemperatureFahrenheit": 72
            ]
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertNotNil(savedWorkouts.first?.metadata)
    }

    // MARK: - Different Activity Types Tests

    func testSaveRunningWorkout() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData(activityType: .running)

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let verified = await mockService.verifySavedWorkout(activityType: .running)
        XCTAssertTrue(verified)
    }

    func testSaveWalkingWorkout() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData(activityType: .walking)

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let verified = await mockService.verifySavedWorkout(activityType: .walking)
        XCTAssertTrue(verified)
    }

    func testSaveCyclingWorkout() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData(activityType: .cycling)

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let verified = await mockService.verifySavedWorkout(activityType: .cycling)
        XCTAssertTrue(verified)
    }

    func testSaveHikingWorkout() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData(activityType: .hiking)

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let verified = await mockService.verifySavedWorkout(activityType: .hiking)
        XCTAssertTrue(verified)
    }

    // MARK: - Different Distance Units Tests

    func testSaveWorkoutWithMetersUnit() async throws {
        // Given
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            totalDistance: 5000,
            distanceUnit: .meters
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.first?.distanceUnit, .meters)
    }

    func testSaveWorkoutWithMilesUnit() async throws {
        // Given
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            totalDistance: 3.1,
            distanceUnit: .miles
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.first?.distanceUnit, .miles)
    }

    func testSaveWorkoutWithKilometersUnit() async throws {
        // Given
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            totalDistance: 5.0,
            distanceUnit: .kilometers
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.first?.distanceUnit, .kilometers)
    }

    // MARK: - Validation Failure Tests

    func testSaveInvalidWorkoutEndBeforeStartFails() async {
        // Given
        let workout = HealthKitTestFixtures.invalidWorkoutDataEndBeforeStart()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Expected invalidWorkoutData error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSaveInvalidWorkoutNegativeCaloriesFails() async {
        // Given
        let workout = HealthKitTestFixtures.invalidWorkoutDataNegativeCalories()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Expected invalidWorkoutData error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSaveInvalidWorkoutNegativeDistanceFails() async {
        // Given
        let workout = HealthKitTestFixtures.invalidWorkoutDataNegativeDistance()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Expected invalidWorkoutData error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSaveInvalidWorkoutZeroDurationFails() async {
        // Given
        let workout = HealthKitTestFixtures.invalidWorkoutDataZeroDuration()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Expected invalidWorkoutData error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - HealthKit Unavailable Tests

    func testSaveWorkoutFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Save Error Tests

    func testSaveWorkoutFailsWithSaveError() async {
        // Given
        await mockService.setWorkoutSaveError(.workoutSaveFailed("Database error"))
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .workoutSaveFailed(let reason) = error {
                XCTAssertEqual(reason, "Database error")
            } else {
                XCTFail("Expected workoutSaveFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSaveWorkoutFailsWithAuthorizationDenied() async {
        // Given
        await mockService.setWorkoutSaveError(.authorizationDenied)
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Save with Delay Tests

    func testSaveWorkoutWithDelay() async throws {
        // Given
        await mockService.setOperationDelay(0.1)
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When
        let startTime = Date()
        try await mockService.saveWorkout(workout)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }

    // MARK: - Method Call Verification Tests

    func testSaveWorkoutMethodCallTracking() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When
        try await mockService.saveWorkout(workout)

        // Then
        XCTAssertEqual(await mockService.callCount(for: "saveWorkout"), 1)

        let calls = await mockService.getMethodCalls(named: "saveWorkout")
        XCTAssertEqual(calls.count, 1)
        XCTAssertNotNil(calls.first?.parameters["activityType"])
        XCTAssertNotNil(calls.first?.parameters["duration"])
        XCTAssertNotNil(calls.first?.parameters["distance"])
    }

    func testSaveWorkoutVerification() async throws {
        // Given
        let workout = HealthKitTestFixtures.validWorkoutData(
            duration: 3600,
            distance: 8000,
            activityType: .running
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let verified = await mockService.verifySavedWorkout(
            activityType: .running,
            minDuration: 3000,
            minDistance: 7000
        )
        XCTAssertTrue(verified)

        let notVerified = await mockService.verifySavedWorkout(
            activityType: .running,
            minDuration: 5000  // Workout was only 3600 seconds
        )
        XCTAssertFalse(notVerified)
    }

    // MARK: - Scenario Tests

    func testWorkoutSaveFailsScenario() async {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.workoutSaveFails.configure(service: service)
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        do {
            try await service.saveWorkout(workout)
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            if case .workoutSaveFailed = error {
                // Expected
            } else {
                XCTFail("Expected workoutSaveFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Edge Cases

    func testSaveWorkoutWithZeroCalories() async throws {
        // Given - Valid workout with zero calories
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            totalEnergyBurned: 0,
            totalDistance: 5000
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertEqual(savedWorkouts.first?.totalEnergyBurned, 0)
    }

    func testSaveWorkoutWithZeroDistance() async throws {
        // Given - Valid workout with zero distance (e.g., stationary cycling)
        let startTime = Date().addingTimeInterval(-3600)
        let workout = HealthKitWorkoutData(
            startTime: startTime,
            endTime: Date(),
            activityType: .cycling,
            totalEnergyBurned: 300,
            totalDistance: 0
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertEqual(savedWorkouts.first?.totalDistance, 0)
    }

    func testSaveVeryLongWorkout() async throws {
        // Given - 4 hour workout
        let workout = HealthKitTestFixtures.validWorkoutData(
            duration: 14400,  // 4 hours
            calories: 2000,
            distance: 42195  // Marathon distance
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertEqual(savedWorkouts.first?.duration, 14400, accuracy: 1)
    }

    func testSaveShortWorkout() async throws {
        // Given - 1 minute workout
        let workout = HealthKitTestFixtures.validWorkoutData(
            duration: 60,
            calories: 10,
            distance: 200
        )

        // When
        try await mockService.saveWorkout(workout)

        // Then
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
        XCTAssertEqual(savedWorkouts.first?.duration, 60, accuracy: 1)
    }
}
