//
//  HealthKitQueryTests.swift
//  JogPodTests
//
//  Tests for HealthKit data query scenarios including workout fetching,
//  user data retrieval, and filtering.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitQueryTests: XCTestCase {

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

    // MARK: - Fetch Workouts Success Tests

    func testFetchWorkoutsReturnsEmptyArrayWhenNoData() async throws {
        // Given
        await mockService.setMockWorkouts([])

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertTrue(workouts.isEmpty)
    }

    func testFetchWorkoutsReturnsMockData() async throws {
        // Given
        let mockWorkouts = MockHealthKitService.sampleWorkoutResults(count: 5)
        await mockService.setMockWorkouts(mockWorkouts)

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertEqual(workouts.count, 5)
    }

    func testFetchWorkoutsRespectsLimit() async throws {
        // Given
        let mockWorkouts = MockHealthKitService.sampleWorkoutResults(count: 10)
        await mockService.setMockWorkouts(mockWorkouts)

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 3
        )

        // Then
        XCTAssertEqual(workouts.count, 3)
    }

    // MARK: - Activity Type Filter Tests

    func testFetchWorkoutsFiltersByActivityType() async throws {
        // Given
        let runningWorkout = HealthKitTestFixtures.workoutResult(activityType: .running)
        let walkingWorkout = HealthKitTestFixtures.workoutResult(activityType: .walking)
        let cyclingWorkout = HealthKitTestFixtures.workoutResult(activityType: .cycling)
        await mockService.setMockWorkouts([runningWorkout, walkingWorkout, cyclingWorkout])

        // When
        let runningWorkouts = try await mockService.fetchWorkouts(
            activityType: .running,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertEqual(runningWorkouts.count, 1)
        XCTAssertEqual(runningWorkouts.first?.activityType, .running)
    }

    func testFetchWorkoutsFiltersByActivityTypeReturnsEmpty() async throws {
        // Given
        let runningWorkout = HealthKitTestFixtures.workoutResult(activityType: .running)
        await mockService.setMockWorkouts([runningWorkout])

        // When
        let hikingWorkouts = try await mockService.fetchWorkouts(
            activityType: .hiking,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertTrue(hikingWorkouts.isEmpty)
    }

    // MARK: - Date Filter Tests

    func testFetchWorkoutsFiltersByStartDate() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)

        let recentWorkout = HealthKitWorkoutResult(
            startTime: yesterday.addingTimeInterval(3600),
            endTime: yesterday.addingTimeInterval(7200),
            duration: 3600
        )
        let oldWorkout = HealthKitWorkoutResult(
            startTime: twoDaysAgo,
            endTime: twoDaysAgo.addingTimeInterval(3600),
            duration: 3600
        )
        await mockService.setMockWorkouts([recentWorkout, oldWorkout])

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: yesterday,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts.first!.startTime >= yesterday)
    }

    func testFetchWorkoutsFiltersByEndDate() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let threeDaysAgo = now.addingTimeInterval(-259200)

        let recentWorkout = HealthKitWorkoutResult(
            startTime: now.addingTimeInterval(-7200),
            endTime: now.addingTimeInterval(-3600),
            duration: 3600
        )
        let oldWorkout = HealthKitWorkoutResult(
            startTime: threeDaysAgo,
            endTime: threeDaysAgo.addingTimeInterval(3600),
            duration: 3600
        )
        await mockService.setMockWorkouts([recentWorkout, oldWorkout])

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: yesterday,
            limit: 100
        )

        // Then
        XCTAssertEqual(workouts.count, 1)
        XCTAssertTrue(workouts.first!.endTime <= yesterday)
    }

    func testFetchWorkoutsFiltersByDateRange() async throws {
        // Given
        let workouts = HealthKitTestFixtures.workoutResultsForWeek()
        await mockService.setMockWorkouts(workouts)

        let threeDaysAgo = Date().addingTimeInterval(-259200)
        let oneDayAgo = Date().addingTimeInterval(-86400)

        // When
        let filteredWorkouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: threeDaysAgo,
            endDate: oneDayAgo,
            limit: 100
        )

        // Then
        for workout in filteredWorkouts {
            XCTAssertTrue(workout.startTime >= threeDaysAgo)
            XCTAssertTrue(workout.endTime <= oneDayAgo)
        }
    }

    // MARK: - Combined Filter Tests

    func testFetchWorkoutsWithMultipleFilters() async throws {
        // Given
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)

        let recentRun = HealthKitWorkoutResult(
            startTime: yesterday.addingTimeInterval(3600),
            endTime: yesterday.addingTimeInterval(7200),
            activityType: .running,
            duration: 3600
        )
        let recentWalk = HealthKitWorkoutResult(
            startTime: yesterday.addingTimeInterval(10800),
            endTime: yesterday.addingTimeInterval(14400),
            activityType: .walking,
            duration: 3600
        )
        let oldRun = HealthKitWorkoutResult(
            startTime: now.addingTimeInterval(-172800),
            endTime: now.addingTimeInterval(-172800 + 3600),
            activityType: .running,
            duration: 3600
        )

        await mockService.setMockWorkouts([recentRun, recentWalk, oldRun])

        // When
        let workouts = try await mockService.fetchWorkouts(
            activityType: .running,
            startDate: yesterday,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.activityType, .running)
        XCTAssertTrue(workouts.first!.startTime >= yesterday)
    }

    // MARK: - Fetch Workouts Failure Tests

    func testFetchWorkoutsFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        do {
            _ = try await mockService.fetchWorkouts(
                activityType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100
            )
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testFetchWorkoutsFailsWithFetchError() async {
        // Given
        await mockService.setWorkoutFetchError(.workoutReadFailed("Query timeout"))

        // When/Then
        do {
            _ = try await mockService.fetchWorkouts(
                activityType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100
            )
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .workoutReadFailed(let reason) = error {
                XCTAssertEqual(reason, "Query timeout")
            } else {
                XCTFail("Expected workoutReadFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Fetch User Data Tests

    func testFetchUserDataReturnsConfiguredData() async throws {
        // Given
        let userData = HealthKitTestFixtures.typicalRunnerUserData()
        await mockService.setMockUserData(userData)

        // When
        let fetchedData = try await mockService.fetchUserData()

        // Then
        XCTAssertEqual(fetchedData.dateOfBirth, userData.dateOfBirth)
        XCTAssertEqual(fetchedData.biologicalSex, userData.biologicalSex)
        XCTAssertEqual(fetchedData.bodyMassKg, userData.bodyMassKg)
    }

    func testFetchUserDataReturnsEmptyData() async throws {
        // Given
        await mockService.setMockUserData(HealthKitUserData())

        // When
        let fetchedData = try await mockService.fetchUserData()

        // Then
        XCTAssertNil(fetchedData.dateOfBirth)
        XCTAssertNil(fetchedData.biologicalSex)
        XCTAssertNil(fetchedData.bodyMassKg)
    }

    func testFetchUserDataFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        do {
            _ = try await mockService.fetchUserData()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Fetch Body Mass Tests

    func testFetchLatestBodyMassReturnsConfiguredValue() async throws {
        // Given
        await mockService.setMockBodyMass(75.5)

        // When
        let bodyMass = try await mockService.fetchLatestBodyMass()

        // Then
        XCTAssertEqual(bodyMass, 75.5)
    }

    func testFetchLatestBodyMassReturnsNilWhenNotSet() async throws {
        // Given
        await mockService.setMockBodyMass(nil)

        // When
        let bodyMass = try await mockService.fetchLatestBodyMass()

        // Then
        XCTAssertNil(bodyMass)
    }

    func testFetchLatestBodyMassFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        do {
            _ = try await mockService.fetchLatestBodyMass()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Fetch Date of Birth Tests

    func testFetchDateOfBirthReturnsConfiguredValue() async throws {
        // Given
        let dob = HealthKitTestFixtures.date(year: 1990, month: 6, day: 15)
        await mockService.setMockDateOfBirth(dob)

        // When
        let fetchedDob = try await mockService.fetchDateOfBirth()

        // Then
        XCTAssertEqual(fetchedDob, dob)
    }

    func testFetchDateOfBirthReturnsNilWhenNotSet() async throws {
        // Given
        await mockService.setMockDateOfBirth(nil)

        // When
        let fetchedDob = try await mockService.fetchDateOfBirth()

        // Then
        XCTAssertNil(fetchedDob)
    }

    func testFetchDateOfBirthFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        do {
            _ = try await mockService.fetchDateOfBirth()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Operation Delay Tests

    func testFetchWorkoutsWithDelay() async throws {
        // Given
        await mockService.setOperationDelay(0.1)
        await mockService.setMockWorkouts(MockHealthKitService.sampleWorkoutResults())

        // When
        let startTime = Date()
        _ = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }

    // MARK: - Method Call Verification Tests

    func testFetchWorkoutsMethodCallTracking() async throws {
        // Given
        await mockService.setMockWorkouts([])

        // When
        _ = try await mockService.fetchWorkouts(
            activityType: .running,
            startDate: nil,
            endDate: nil,
            limit: 50
        )

        // Then
        XCTAssertEqual(await mockService.callCount(for: "fetchWorkouts"), 1)

        let calls = await mockService.getMethodCalls(named: "fetchWorkouts")
        XCTAssertEqual(calls.count, 1)
        XCTAssertNotNil(calls.first?.parameters["activityType"])
        XCTAssertEqual(calls.first?.parameters["limit"], "50")
    }

    // MARK: - Scenario Tests

    func testNoDataScenario() async throws {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.noData.configure(service: service)

        // When
        let workouts = try await service.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )
        let userData = try await service.fetchUserData()

        // Then
        XCTAssertTrue(workouts.isEmpty)
        XCTAssertNil(userData.dateOfBirth)
        XCTAssertNil(userData.bodyMassKg)
    }

    func testWorkoutFetchFailsScenario() async {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.workoutFetchFails.configure(service: service)

        // When/Then
        do {
            _ = try await service.fetchWorkouts(
                activityType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100
            )
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            if case .workoutReadFailed = error {
                // Expected
            } else {
                XCTFail("Expected workoutReadFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Factory Method Tests

    func testWithWorkoutsFactory() async throws {
        // Given
        let workouts = [
            HealthKitTestFixtures.workoutResult(activityType: .running),
            HealthKitTestFixtures.workoutResult(activityType: .walking)
        ]
        let service = await MockHealthKitService.withWorkouts(workouts)

        // When
        let fetchedWorkouts = try await service.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // Then
        XCTAssertEqual(fetchedWorkouts.count, 2)
    }

    func testWithUserDataFactory() async throws {
        // Given
        let dob = HealthKitTestFixtures.date(year: 1985, month: 3, day: 20)
        let service = await MockHealthKitService.withUserData(
            dateOfBirth: dob,
            biologicalSex: .female,
            bodyMassKg: 65.0
        )

        // When
        let userData = try await service.fetchUserData()
        let bodyMass = try await service.fetchLatestBodyMass()
        let fetchedDob = try await service.fetchDateOfBirth()

        // Then
        XCTAssertEqual(userData.dateOfBirth, dob)
        XCTAssertEqual(userData.biologicalSex, .female)
        XCTAssertEqual(bodyMass, 65.0)
        XCTAssertEqual(fetchedDob, dob)
    }
}

// MARK: - Workout Result Tests

final class HealthKitWorkoutResultQueryTests: XCTestCase {

    func testWorkoutResultFormattedDuration() {
        // Given
        let workout = HealthKitTestFixtures.workoutResult(duration: 5445)

        // Then
        XCTAssertEqual(workout.formattedDuration, "1:30:45")
    }

    func testWorkoutResultDistanceConversion() {
        // Given
        let workout = HealthKitTestFixtures.workoutResult(distanceMeters: 5000)

        // Then
        XCTAssertEqual(workout.distanceKilometers, 5.0, accuracy: 0.001)
        XCTAssertEqual(workout.distanceMiles ?? 0, 3.107, accuracy: 0.001)
    }

    func testWorkoutResultIdentifiable() {
        // Given
        let workout1 = HealthKitTestFixtures.workoutResult()
        let workout2 = HealthKitTestFixtures.workoutResult()

        // Then
        XCTAssertNotEqual(workout1.id, workout2.id)
    }

    func testWorkoutResultEquatable() {
        // Given
        let id = UUID()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)

        let workout1 = HealthKitWorkoutResult(
            id: id,
            startTime: startTime,
            endTime: endTime,
            duration: 3600
        )

        let workout2 = HealthKitWorkoutResult(
            id: id,
            startTime: startTime,
            endTime: endTime,
            duration: 3600
        )

        // Then
        XCTAssertEqual(workout1, workout2)
    }
}
