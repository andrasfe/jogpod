//
//  HealthKitErrorTests.swift
//  JogPodTests
//
//  Unit tests for HealthKitError.
//

import XCTest
@testable import JogPod

final class HealthKitErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func testHealthKitNotAvailableErrorDescription() {
        let error = HealthKitError.healthKitNotAvailable

        XCTAssertEqual(
            error.errorDescription,
            "HealthKit is not available on this device."
        )
        XCTAssertEqual(
            error.failureReason,
            "HealthKit requires an iPhone or Apple Watch."
        )
    }

    func testDataTypeNotAvailableErrorDescription() {
        let error = HealthKitError.dataTypeNotAvailable("heartRate")

        XCTAssertEqual(
            error.errorDescription,
            "The HealthKit data type 'heartRate' is not available."
        )
    }

    func testAuthorizationNotGrantedErrorDescription() {
        let error = HealthKitError.authorizationNotGranted

        XCTAssertEqual(
            error.errorDescription,
            "HealthKit authorization has not been granted."
        )
        XCTAssertEqual(
            error.failureReason,
            "Please enable HealthKit access in Settings > Privacy > Health."
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Go to Settings > Privacy & Security > Health > JogPod to enable access."
        )
    }

    func testAuthorizationDeniedErrorDescription() {
        let error = HealthKitError.authorizationDenied

        XCTAssertEqual(
            error.errorDescription,
            "HealthKit authorization was denied."
        )
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testAuthorizationFailedErrorDescription() {
        let error = HealthKitError.authorizationFailed("Network error")

        XCTAssertEqual(
            error.errorDescription,
            "HealthKit authorization failed: Network error"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Try restarting the app and requesting permissions again."
        )
    }

    func testWorkoutReadFailedErrorDescription() {
        let error = HealthKitError.workoutReadFailed("Query timeout")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to read workouts: Query timeout"
        )
    }

    func testDataReadFailedErrorDescription() {
        let error = HealthKitError.dataReadFailed(
            dataType: "bodyMass",
            reason: "Access denied"
        )

        XCTAssertEqual(
            error.errorDescription,
            "Failed to read bodyMass: Access denied"
        )
    }

    func testQueryCancelledErrorDescription() {
        let error = HealthKitError.queryCancelled

        XCTAssertEqual(
            error.errorDescription,
            "The HealthKit query was cancelled."
        )
    }

    func testWorkoutSaveFailedErrorDescription() {
        let error = HealthKitError.workoutSaveFailed("Disk full")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to save workout: Disk full"
        )
    }

    func testSampleSaveFailedErrorDescription() {
        let error = HealthKitError.sampleSaveFailed("Invalid data")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to save samples: Invalid data"
        )
    }

    func testInvalidWorkoutDataErrorDescription() {
        let error = HealthKitError.invalidWorkoutData("End time before start time")

        XCTAssertEqual(
            error.errorDescription,
            "Invalid workout data: End time before start time"
        )
    }

    func testUnknownErrorDescription() {
        let error = HealthKitError.unknown("Something went wrong")

        XCTAssertEqual(
            error.errorDescription,
            "An unknown HealthKit error occurred: Something went wrong"
        )
    }

    // MARK: - Error Code Tests

    func testErrorCodes() {
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

    // MARK: - Equatable Tests

    func testErrorEquality() {
        XCTAssertEqual(
            HealthKitError.healthKitNotAvailable,
            HealthKitError.healthKitNotAvailable
        )

        XCTAssertEqual(
            HealthKitError.dataTypeNotAvailable("heartRate"),
            HealthKitError.dataTypeNotAvailable("heartRate")
        )

        XCTAssertNotEqual(
            HealthKitError.dataTypeNotAvailable("heartRate"),
            HealthKitError.dataTypeNotAvailable("bodyMass")
        )

        XCTAssertNotEqual(
            HealthKitError.healthKitNotAvailable,
            HealthKitError.authorizationDenied
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

    func testErrorUserInfoWithoutOptionalFields() {
        let error = HealthKitError.queryCancelled
        let userInfo = error.errorUserInfo

        XCTAssertNotNil(userInfo[NSLocalizedDescriptionKey])
        XCTAssertNil(userInfo[NSLocalizedFailureReasonErrorKey])
        XCTAssertNil(userInfo[NSLocalizedRecoverySuggestionErrorKey])
    }
}
