//
//  HealthKitErrorHandlingTests.swift
//  JogPodTests
//
//  Comprehensive tests for HealthKit error handling scenarios.
//  Tests all error types, error propagation, and recovery suggestions.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitErrorHandlingTests: XCTestCase {

    // MARK: - Properties

    var mockService: MockHealthKitService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockHealthKitService()
    }

    override func tearDown() async throws {
        mockService = nil
        try await super.tearDown()
    }

    // MARK: - Availability Error Tests

    func testHealthKitNotAvailableErrorOnAuthorization() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            try await mockService.requestAuthorization()
        }
    }

    func testHealthKitNotAvailableErrorOnSave() async {
        // Given
        await mockService.setAvailable(false)
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            try await mockService.saveWorkout(workout)
        }
    }

    func testHealthKitNotAvailableErrorOnFetch() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            _ = try await mockService.fetchWorkouts(
                activityType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100
            )
        }
    }

    func testHealthKitNotAvailableErrorOnUserData() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            _ = try await mockService.fetchUserData()
        }
    }

    func testHealthKitNotAvailableErrorOnBodyMass() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            _ = try await mockService.fetchLatestBodyMass()
        }
    }

    func testHealthKitNotAvailableErrorOnDateOfBirth() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        await assertThrows(HealthKitError.healthKitNotAvailable) {
            _ = try await mockService.fetchDateOfBirth()
        }
    }

    // MARK: - Authorization Error Tests

    func testAuthorizationNotGrantedError() async {
        // Given
        await mockService.setAuthorizationError(.authorizationNotGranted)

        // When/Then
        await assertThrows(HealthKitError.authorizationNotGranted) {
            try await mockService.requestAuthorization()
        }
    }

    func testAuthorizationDeniedError() async {
        // Given
        await mockService.setAuthorizationError(.authorizationDenied)

        // When/Then
        await assertThrows(HealthKitError.authorizationDenied) {
            try await mockService.requestAuthorization()
        }
    }

    func testAuthorizationFailedErrorWithMessage() async {
        // Given
        let reason = "User cancelled the authorization flow"
        await mockService.setAuthorizationError(.authorizationFailed(reason))

        // When/Then
        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .authorizationFailed(let actualReason) = error {
                XCTAssertEqual(actualReason, reason)
            } else {
                XCTFail("Expected authorizationFailed error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Save Error Tests

    func testWorkoutSaveFailedError() async {
        // Given
        let reason = "Database write error"
        await mockService.setWorkoutSaveError(.workoutSaveFailed(reason))
        let workout = HealthKitTestFixtures.validWorkoutData()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .workoutSaveFailed(let actualReason) = error {
                XCTAssertEqual(actualReason, reason)
            } else {
                XCTFail("Expected workoutSaveFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testSampleSaveFailedError() async {
        // Given
        await mockService.setWorkoutSaveError(.sampleSaveFailed("Invalid heart rate data"))
        let workout = HealthKitTestFixtures.workoutDataWithHeartRate()

        // When/Then
        do {
            try await mockService.saveWorkout(workout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .sampleSaveFailed = error {
                // Expected
            } else {
                XCTFail("Expected sampleSaveFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testInvalidWorkoutDataError() async {
        // Given
        let invalidWorkout = HealthKitTestFixtures.invalidWorkoutDataEndBeforeStart()

        // When/Then
        do {
            try await mockService.saveWorkout(invalidWorkout)
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .invalidWorkoutData = error {
                // Expected
            } else {
                XCTFail("Expected invalidWorkoutData error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Read Error Tests

    func testWorkoutReadFailedError() async {
        // Given
        let reason = "Query timeout"
        await mockService.setWorkoutFetchError(.workoutReadFailed(reason))

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
            if case .workoutReadFailed(let actualReason) = error {
                XCTAssertEqual(actualReason, reason)
            } else {
                XCTFail("Expected workoutReadFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testDataReadFailedError() async {
        // Given
        await mockService.setUserDataFetchError(.dataReadFailed(
            dataType: "bodyMass",
            reason: "Access denied"
        ))

        // When/Then
        do {
            _ = try await mockService.fetchUserData()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .dataReadFailed(let dataType, let reason) = error {
                XCTAssertEqual(dataType, "bodyMass")
                XCTAssertEqual(reason, "Access denied")
            } else {
                XCTFail("Expected dataReadFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testQueryCancelledError() async {
        // Given
        await mockService.setWorkoutFetchError(.queryCancelled)

        // When/Then
        await assertThrows(HealthKitError.queryCancelled) {
            _ = try await mockService.fetchWorkouts(
                activityType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100
            )
        }
    }

    // MARK: - Error Description Tests

    func testAllErrorsHaveDescriptions() {
        let errors: [HealthKitError] = [
            .healthKitNotAvailable,
            .dataTypeNotAvailable("heartRate"),
            .authorizationNotGranted,
            .authorizationDenied,
            .authorizationFailed("Test reason"),
            .workoutReadFailed("Test reason"),
            .dataReadFailed(dataType: "test", reason: "Test reason"),
            .queryCancelled,
            .workoutSaveFailed("Test reason"),
            .sampleSaveFailed("Test reason"),
            .invalidWorkoutData("Test reason"),
            .unknown("Test reason")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func testErrorsHaveCorrectErrorCodes() {
        XCTAssertEqual(HealthKitError.healthKitNotAvailable.errorCode, 1001)
        XCTAssertEqual(HealthKitError.dataTypeNotAvailable("test").errorCode, 1002)
        XCTAssertEqual(HealthKitError.authorizationNotGranted.errorCode, 2001)
        XCTAssertEqual(HealthKitError.authorizationDenied.errorCode, 2002)
        XCTAssertEqual(HealthKitError.authorizationFailed("test").errorCode, 2003)
        XCTAssertEqual(HealthKitError.workoutReadFailed("test").errorCode, 3001)
        XCTAssertEqual(HealthKitError.dataReadFailed(dataType: "test", reason: "test").errorCode, 3002)
        XCTAssertEqual(HealthKitError.queryCancelled.errorCode, 3003)
        XCTAssertEqual(HealthKitError.workoutSaveFailed("test").errorCode, 4001)
        XCTAssertEqual(HealthKitError.sampleSaveFailed("test").errorCode, 4002)
        XCTAssertEqual(HealthKitError.invalidWorkoutData("test").errorCode, 4003)
        XCTAssertEqual(HealthKitError.unknown("test").errorCode, 9999)
    }

    func testErrorDomain() {
        XCTAssertEqual(HealthKitError.errorDomain, "com.jogpod.healthkit")
    }

    func testAuthorizationErrorsHaveRecoverySuggestions() {
        let authErrors: [HealthKitError] = [
            .authorizationNotGranted,
            .authorizationDenied,
            .authorizationFailed("test")
        ]

        for error in authErrors {
            XCTAssertNotNil(
                error.recoverySuggestion,
                "Auth error \(error) should have recovery suggestion"
            )
        }
    }

    func testUnavailabilityErrorsHaveFailureReasons() {
        let unavailableErrors: [HealthKitError] = [
            .healthKitNotAvailable,
            .authorizationDenied,
            .authorizationNotGranted
        ]

        for error in unavailableErrors {
            XCTAssertNotNil(
                error.failureReason,
                "Error \(error) should have failure reason"
            )
        }
    }

    // MARK: - Error Equatable Tests

    func testErrorEquality() {
        // Same errors should be equal
        XCTAssertEqual(
            HealthKitError.healthKitNotAvailable,
            HealthKitError.healthKitNotAvailable
        )

        XCTAssertEqual(
            HealthKitError.authorizationFailed("reason"),
            HealthKitError.authorizationFailed("reason")
        )

        XCTAssertEqual(
            HealthKitError.dataReadFailed(dataType: "test", reason: "reason"),
            HealthKitError.dataReadFailed(dataType: "test", reason: "reason")
        )

        // Different errors should not be equal
        XCTAssertNotEqual(
            HealthKitError.healthKitNotAvailable,
            HealthKitError.authorizationDenied
        )

        XCTAssertNotEqual(
            HealthKitError.authorizationFailed("reason1"),
            HealthKitError.authorizationFailed("reason2")
        )

        XCTAssertNotEqual(
            HealthKitError.dataReadFailed(dataType: "type1", reason: "reason"),
            HealthKitError.dataReadFailed(dataType: "type2", reason: "reason")
        )
    }

    // MARK: - Error User Info Tests

    func testErrorUserInfo() {
        let error = HealthKitError.authorizationNotGranted
        let userInfo = error.errorUserInfo

        XCTAssertNotNil(userInfo[NSLocalizedDescriptionKey])
        XCTAssertNotNil(userInfo[NSLocalizedFailureReasonErrorKey])
        XCTAssertNotNil(userInfo[NSLocalizedRecoverySuggestionErrorKey])
    }

    func testErrorUserInfoForErrorWithoutOptionalFields() {
        let error = HealthKitError.queryCancelled
        let userInfo = error.errorUserInfo

        XCTAssertNotNil(userInfo[NSLocalizedDescriptionKey])
        XCTAssertNil(userInfo[NSLocalizedFailureReasonErrorKey])
        XCTAssertNil(userInfo[NSLocalizedRecoverySuggestionErrorKey])
    }

    // MARK: - Error Simulator Tests

    func testAllAuthorizationErrorsCanBeSimulated() async {
        for error in HealthKitErrorSimulator.authorizationErrors {
            let service = MockHealthKitService()
            await service.setAuthorizationError(error)

            do {
                try await service.requestAuthorization()
                XCTFail("Expected error to be thrown for \(error)")
            } catch let caughtError as HealthKitError {
                XCTAssertEqual(caughtError, error)
            } catch {
                XCTFail("Unexpected error type for \(error)")
            }
        }
    }

    func testAllSaveErrorsCanBeSimulated() async {
        for error in HealthKitErrorSimulator.saveErrors {
            let service = MockHealthKitService()
            await service.setWorkoutSaveError(error)

            let workout = HealthKitTestFixtures.validWorkoutData()

            do {
                try await service.saveWorkout(workout)
                XCTFail("Expected error to be thrown for \(error)")
            } catch let caughtError as HealthKitError {
                XCTAssertEqual(caughtError, error)
            } catch {
                XCTFail("Unexpected error type for \(error)")
            }
        }
    }

    func testAllReadErrorsCanBeSimulated() async {
        for error in HealthKitErrorSimulator.readErrors {
            let service = MockHealthKitService()
            await service.setWorkoutFetchError(error)

            do {
                _ = try await service.fetchWorkouts(
                    activityType: nil,
                    startDate: nil,
                    endDate: nil,
                    limit: 100
                )
                XCTFail("Expected error to be thrown for \(error)")
            } catch let caughtError as HealthKitError {
                XCTAssertEqual(caughtError, error)
            } catch {
                XCTFail("Unexpected error type for \(error)")
            }
        }
    }

    // MARK: - Error Recovery Tests

    func testErrorRecoveryAfterAuthorizationFailure() async throws {
        // Given - Initial failure
        await mockService.setAuthorizationError(.authorizationFailed("Network error"))

        do {
            try await mockService.requestAuthorization()
        } catch {
            // Expected
        }

        // When - Error is cleared and retry
        await mockService.setAuthorizationError(nil)
        try await mockService.requestAuthorization()

        // Then - Should succeed
        XCTAssertEqual(await mockService.callCount(for: "requestAuthorization"), 2)
    }

    func testErrorRecoveryAfterSaveFailure() async throws {
        // Given - Initial failure
        await mockService.setWorkoutSaveError(.workoutSaveFailed("Disk full"))
        let workout = HealthKitTestFixtures.validWorkoutData()

        do {
            try await mockService.saveWorkout(workout)
        } catch {
            // Expected
        }

        // When - Error is cleared and retry
        await mockService.setWorkoutSaveError(nil)
        try await mockService.saveWorkout(workout)

        // Then - Should succeed
        let savedWorkouts = await mockService.savedWorkouts
        XCTAssertEqual(savedWorkouts.count, 1)
    }

    // MARK: - Concurrent Error Handling Tests

    func testConcurrentOperationsWithErrors() async {
        // Given
        await mockService.setWorkoutFetchError(.workoutReadFailed("Concurrent access"))

        // When
        await withTaskGroup(of: Result<[HealthKitWorkoutResult], Error>.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        let workouts = try await self.mockService.fetchWorkouts(
                            activityType: nil,
                            startDate: nil,
                            endDate: nil,
                            limit: 100
                        )
                        return .success(workouts)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            // Then - All tasks should fail with the same error
            var failureCount = 0
            for await result in group {
                if case .failure(let error) = result {
                    if let healthKitError = error as? HealthKitError,
                       case .workoutReadFailed = healthKitError {
                        failureCount += 1
                    }
                }
            }

            XCTAssertEqual(failureCount, 5)
        }
    }

    // MARK: - Helper Methods

    private func assertThrows<T>(
        _ expectedError: HealthKitError,
        file: StaticString = #file,
        line: UInt = #line,
        _ expression: () async throws -> T
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch let error as HealthKitError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Unexpected error type: \(error)", file: file, line: line)
        }
    }
}

// MARK: - Mock Service Error Reset Tests

final class MockServiceErrorResetTests: XCTestCase {

    func testResetClearsErrors() async throws {
        // Given
        let service = MockHealthKitService()
        await service.setAuthorizationError(.authorizationDenied)
        await service.setWorkoutSaveError(.workoutSaveFailed("test"))
        await service.setWorkoutFetchError(.workoutReadFailed("test"))

        // When
        await service.resetConfiguration()

        // Then - All operations should succeed
        try await service.requestAuthorization()
        try await service.saveWorkout(HealthKitTestFixtures.validWorkoutData())
        _ = try await service.fetchWorkouts(
            activityType: nil,
            startDate: nil,
            endDate: nil,
            limit: 100
        )

        // All should complete without error
    }

    func testResetClearsTrackingData() async throws {
        // Given
        let service = MockHealthKitService()
        try await service.requestAuthorization()
        try await service.saveWorkout(HealthKitTestFixtures.validWorkoutData())

        // When
        await service.reset()

        // Then
        XCTAssertEqual(await service.callCount(for: "requestAuthorization"), 0)
        XCTAssertEqual(await service.callCount(for: "saveWorkout"), 0)
        let savedWorkouts = await service.savedWorkouts
        XCTAssertTrue(savedWorkouts.isEmpty)
    }
}
