//
//  HealthKitServiceTests.swift
//  JogPodTests
//
//  Unit tests for HealthKitService.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: HealthKitService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = HealthKitService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Availability Tests

    func testIsAvailableReturnsCorrectValue() {
        // This test verifies the service reports the correct availability
        // On simulators and iPads, HealthKit is not available
        let expectedAvailability = HKHealthStore.isHealthDataAvailable()
        XCTAssertEqual(sut.isAvailable, expectedAvailability)
    }

    func testSharedInstanceExists() async {
        let shared = HealthKitService.shared
        XCTAssertNotNil(shared)
    }

    // MARK: - Authorization Status Tests

    func testCheckAuthorizationStatusReturnsUnavailableWhenHealthKitNotAvailable() async {
        // On platforms where HealthKit is unavailable, should return .unavailable
        if !HKHealthStore.isHealthDataAvailable() {
            let status = await sut.checkAuthorizationStatus()
            XCTAssertEqual(status, .unavailable)
        }
    }

    // MARK: - Workout Data Validation Tests

    func testSaveWorkoutThrowsWhenHealthKitNotAvailable() async {
        guard !HKHealthStore.isHealthDataAvailable() else {
            // Skip test on devices where HealthKit is available
            return
        }

        let workout = HealthKitWorkoutData(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            totalEnergyBurned: 350,
            totalDistance: 5000
        )

        do {
            try await sut.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSaveWorkoutThrowsForInvalidData() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Skip test on devices where HealthKit is not available
            return
        }

        // Invalid workout: end time before start time
        let invalidWorkout = HealthKitWorkoutData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600)
        )

        do {
            try await sut.saveWorkout(invalidWorkout)
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

    // MARK: - Fetch Workouts Tests

    func testFetchWorkoutsThrowsWhenHealthKitNotAvailable() async {
        guard !HKHealthStore.isHealthDataAvailable() else {
            return
        }

        do {
            _ = try await sut.fetchWorkouts()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchUserDataThrowsWhenHealthKitNotAvailable() async {
        guard !HKHealthStore.isHealthDataAvailable() else {
            return
        }

        do {
            _ = try await sut.fetchUserData()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchLatestBodyMassThrowsWhenHealthKitNotAvailable() async {
        guard !HKHealthStore.isHealthDataAvailable() else {
            return
        }

        do {
            _ = try await sut.fetchLatestBodyMass()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchDateOfBirthThrowsWhenHealthKitNotAvailable() async {
        guard !HKHealthStore.isHealthDataAvailable() else {
            return
        }

        do {
            _ = try await sut.fetchDateOfBirth()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Authorization Status Enum Tests

    func testAuthorizationStatusEquality() {
        XCTAssertEqual(HealthKitAuthorizationStatus.notDetermined, .notDetermined)
        XCTAssertEqual(HealthKitAuthorizationStatus.authorized, .authorized)
        XCTAssertEqual(HealthKitAuthorizationStatus.denied, .denied)
        XCTAssertEqual(HealthKitAuthorizationStatus.unavailable, .unavailable)

        XCTAssertNotEqual(HealthKitAuthorizationStatus.authorized, .denied)
    }
}

// MARK: - Mock HealthKit Service for Testing

/// A mock implementation of HealthKitServiceProtocol for unit testing.
///
/// This mock allows tests to simulate various HealthKit scenarios without
/// requiring actual HealthKit access.
final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    var mockIsAvailable: Bool = true
    var mockAuthorizationStatus: HealthKitAuthorizationStatus = .authorized
    var mockWorkouts: [HealthKitWorkoutResult] = []
    var mockUserData: HealthKitUserData = HealthKitUserData()
    var mockBodyMass: Double? = nil
    var mockDateOfBirth: Date? = nil

    var shouldThrowOnAuthorization: HealthKitError? = nil
    var shouldThrowOnSaveWorkout: HealthKitError? = nil
    var shouldThrowOnFetchWorkouts: HealthKitError? = nil

    var authorizationRequestedCount = 0
    var savedWorkouts: [HealthKitWorkoutData] = []

    // MARK: - HealthKitServiceProtocol

    var isAvailable: Bool { mockIsAvailable }

    func requestAuthorization() async throws {
        authorizationRequestedCount += 1

        if let error = shouldThrowOnAuthorization {
            throw error
        }
    }

    func checkAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        if !mockIsAvailable {
            return .unavailable
        }
        return mockAuthorizationStatus
    }

    func saveWorkout(_ workout: HealthKitWorkoutData) async throws {
        if !mockIsAvailable {
            throw HealthKitError.healthKitNotAvailable
        }

        if let error = shouldThrowOnSaveWorkout {
            throw error
        }

        if !workout.isValid {
            throw HealthKitError.invalidWorkoutData("Invalid workout data")
        }

        savedWorkouts.append(workout)
    }

    func fetchWorkouts(
        activityType: HKWorkoutActivityType?,
        startDate: Date?,
        endDate: Date?,
        limit: Int
    ) async throws -> [HealthKitWorkoutResult] {
        if !mockIsAvailable {
            throw HealthKitError.healthKitNotAvailable
        }

        if let error = shouldThrowOnFetchWorkouts {
            throw error
        }

        var results = mockWorkouts

        if let activityType = activityType {
            results = results.filter { $0.activityType == activityType }
        }

        if let startDate = startDate {
            results = results.filter { $0.startTime >= startDate }
        }

        if let endDate = endDate {
            results = results.filter { $0.endTime <= endDate }
        }

        return Array(results.prefix(limit))
    }

    func fetchUserData() async throws -> HealthKitUserData {
        if !mockIsAvailable {
            throw HealthKitError.healthKitNotAvailable
        }
        return mockUserData
    }

    func fetchLatestBodyMass() async throws -> Double? {
        if !mockIsAvailable {
            throw HealthKitError.healthKitNotAvailable
        }
        return mockBodyMass
    }

    func fetchDateOfBirth() async throws -> Date? {
        if !mockIsAvailable {
            throw HealthKitError.healthKitNotAvailable
        }
        return mockDateOfBirth
    }
}

// MARK: - Mock Service Tests

final class MockHealthKitServiceTests: XCTestCase {

    var mockService: MockHealthKitService!

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockHealthKitService()
    }

    override func tearDown() async throws {
        mockService = nil
        try await super.tearDown()
    }

    func testMockServiceSaveWorkout() async throws {
        let workout = HealthKitWorkoutData(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            totalEnergyBurned: 350,
            totalDistance: 5000
        )

        try await mockService.saveWorkout(workout)

        XCTAssertEqual(mockService.savedWorkouts.count, 1)
        XCTAssertEqual(mockService.savedWorkouts.first?.totalDistance, 5000)
    }

    func testMockServiceSaveInvalidWorkout() async {
        let invalidWorkout = HealthKitWorkoutData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600)
        )

        do {
            try await mockService.saveWorkout(invalidWorkout)
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error")
        }
    }

    func testMockServiceFetchWorkouts() async throws {
        let startTime = Date().addingTimeInterval(-7200)

        mockService.mockWorkouts = [
            HealthKitWorkoutResult(
                startTime: startTime,
                endTime: startTime.addingTimeInterval(3600),
                activityType: .running,
                duration: 3600,
                totalDistanceMeters: 5000
            ),
            HealthKitWorkoutResult(
                startTime: startTime.addingTimeInterval(7200),
                endTime: startTime.addingTimeInterval(10800),
                activityType: .walking,
                duration: 3600,
                totalDistanceMeters: 3000
            )
        ]

        let allWorkouts = try await mockService.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )
        XCTAssertEqual(allWorkouts.count, 2)

        let runningWorkouts = try await mockService.fetchWorkouts(
            activityType: .running,
            startDate: nil,
            endDate: nil,
            limit: 100
        )
        XCTAssertEqual(runningWorkouts.count, 1)
        XCTAssertEqual(runningWorkouts.first?.activityType, .running)
    }

    func testMockServiceAuthorizationTracking() async throws {
        XCTAssertEqual(mockService.authorizationRequestedCount, 0)

        try await mockService.requestAuthorization()
        XCTAssertEqual(mockService.authorizationRequestedCount, 1)

        try await mockService.requestAuthorization()
        XCTAssertEqual(mockService.authorizationRequestedCount, 2)
    }

    func testMockServiceThrowsConfiguredErrors() async {
        mockService.shouldThrowOnAuthorization = .authorizationDenied

        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testMockServiceUnavailable() async {
        mockService.mockIsAvailable = false

        let status = await mockService.checkAuthorizationStatus()
        XCTAssertEqual(status, .unavailable)

        do {
            try await mockService.saveWorkout(
                HealthKitWorkoutData(
                    startTime: Date().addingTimeInterval(-3600),
                    endTime: Date()
                )
            )
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testMockServiceUserData() async throws {
        let dob = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1))!
        mockService.mockUserData = HealthKitUserData(
            dateOfBirth: dob,
            biologicalSex: .female,
            bodyMassKg: 60
        )
        mockService.mockDateOfBirth = dob
        mockService.mockBodyMass = 60

        let userData = try await mockService.fetchUserData()
        XCTAssertEqual(userData.dateOfBirth, dob)
        XCTAssertEqual(userData.biologicalSex, .female)
        XCTAssertEqual(userData.bodyMassKg, 60)

        let bodyMass = try await mockService.fetchLatestBodyMass()
        XCTAssertEqual(bodyMass, 60)

        let dateOfBirth = try await mockService.fetchDateOfBirth()
        XCTAssertEqual(dateOfBirth, dob)
    }
}
