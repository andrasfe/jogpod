//
//  WorkoutErrorTests.swift
//  JogPod Tests
//
//  Tests for WorkoutError types and GPSSignalLevel.
//

import Testing
import Foundation
@testable import JogPod

// MARK: - WorkoutError Tests

@Suite("WorkoutError")
struct WorkoutErrorTests {

    // MARK: - State Errors

    @Test("workoutAlreadyInProgress has correct description")
    func workoutAlreadyInProgressDescription() {
        let error = WorkoutError.workoutAlreadyInProgress

        #expect(error.errorDescription?.contains("already in progress") == true)
        #expect(error.recoverySuggestion?.contains("Stop") == true)
    }

    @Test("noActiveWorkout has correct description")
    func noActiveWorkoutDescription() {
        let error = WorkoutError.noActiveWorkout

        #expect(error.errorDescription?.contains("No workout") == true)
    }

    @Test("invalidWorkoutState has correct description")
    func invalidWorkoutStateDescription() {
        let error = WorkoutError.invalidWorkoutState(expected: .active, actual: .idle)

        #expect(error.errorDescription?.contains("active") == true)
        #expect(error.errorDescription?.contains("idle") == true)
    }

    // MARK: - Location Errors

    @Test("locationServicesUnavailable has correct description")
    func locationServicesUnavailableDescription() {
        let error = WorkoutError.locationServicesUnavailable

        #expect(error.errorDescription?.contains("not available") == true)
    }

    @Test("locationAuthorizationDenied has correct description and recovery")
    func locationAuthorizationDeniedDescription() {
        let error = WorkoutError.locationAuthorizationDenied

        #expect(error.errorDescription?.contains("denied") == true)
        #expect(error.failureReason?.contains("denied") == true)
        #expect(error.recoverySuggestion?.contains("Settings") == true)
    }

    @Test("locationAuthorizationRestricted has correct description")
    func locationAuthorizationRestrictedDescription() {
        let error = WorkoutError.locationAuthorizationRestricted

        #expect(error.errorDescription?.contains("restricted") == true)
        #expect(error.failureReason?.contains("policy") == true)
    }

    @Test("locationTimeout has correct description")
    func locationTimeoutDescription() {
        let error = WorkoutError.locationTimeout

        #expect(error.errorDescription?.contains("Failed to receive") == true)
    }

    @Test("invalidLocationData has correct description")
    func invalidLocationDataDescription() {
        let error = WorkoutError.invalidLocationData(reason: "accuracy too low")

        #expect(error.errorDescription?.contains("accuracy too low") == true)
    }

    // MARK: - Heart Rate Errors

    @Test("heartRateMonitoringUnavailable has correct description")
    func heartRateMonitoringUnavailableDescription() {
        let error = WorkoutError.heartRateMonitoringUnavailable

        #expect(error.errorDescription?.contains("not available") == true)
    }

    @Test("heartRateSensorConnectionFailed has correct description and recovery")
    func heartRateSensorConnectionFailedDescription() {
        let error = WorkoutError.heartRateSensorConnectionFailed

        #expect(error.errorDescription?.contains("connect") == true)
        #expect(error.recoverySuggestion?.contains("powered on") == true)
    }

    @Test("invalidHeartRateData has correct description")
    func invalidHeartRateDataDescription() {
        let error = WorkoutError.invalidHeartRateData(value: 300)

        #expect(error.errorDescription?.contains("300") == true)
    }

    // MARK: - Persistence Errors

    @Test("sessionCreationFailed has correct description")
    func sessionCreationFailedDescription() {
        let error = WorkoutError.sessionCreationFailed(underlyingError: "disk full")

        #expect(error.errorDescription?.contains("disk full") == true)
    }

    @Test("persistenceFailed has correct description")
    func persistenceFailedDescription() {
        let error = WorkoutError.persistenceFailed(underlyingError: "save error")

        #expect(error.errorDescription?.contains("save error") == true)
    }

    @Test("workoutNotFound has correct description")
    func workoutNotFoundDescription() {
        let error = WorkoutError.workoutNotFound(workoutID: "abc-123")

        #expect(error.errorDescription?.contains("abc-123") == true)
    }

    // MARK: - General Errors

    @Test("permissionsNotGranted has correct description")
    func permissionsNotGrantedDescription() {
        let error = WorkoutError.permissionsNotGranted(missing: ["location", "health"])

        #expect(error.errorDescription?.contains("location") == true)
        #expect(error.errorDescription?.contains("health") == true)
    }

    @Test("unexpected has correct description")
    func unexpectedDescription() {
        let error = WorkoutError.unexpected(description: "something went wrong")

        #expect(error.errorDescription?.contains("something went wrong") == true)
    }

    @Test("cancelled has correct description")
    func cancelledDescription() {
        let error = WorkoutError.cancelled

        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    // MARK: - Equatable

    @Test("WorkoutError is equatable for same errors")
    func errorEquality() {
        #expect(WorkoutError.workoutAlreadyInProgress == WorkoutError.workoutAlreadyInProgress)
        #expect(WorkoutError.noActiveWorkout == WorkoutError.noActiveWorkout)
        #expect(WorkoutError.cancelled == WorkoutError.cancelled)
    }

    @Test("WorkoutError is equatable for errors with associated values")
    func errorEqualityWithValues() {
        let error1 = WorkoutError.invalidWorkoutState(expected: .active, actual: .idle)
        let error2 = WorkoutError.invalidWorkoutState(expected: .active, actual: .idle)
        let error3 = WorkoutError.invalidWorkoutState(expected: .idle, actual: .active)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

// MARK: - WorkoutState Tests

@Suite("WorkoutState")
struct WorkoutStateTests {

    @Test("WorkoutState has all expected cases")
    func allCases() {
        let cases = WorkoutState.allCases

        #expect(cases.contains(.idle))
        #expect(cases.contains(.starting))
        #expect(cases.contains(.active))
        #expect(cases.contains(.paused))
        #expect(cases.contains(.stopping))
        #expect(cases.contains(.completed))
        #expect(cases.contains(.error))
        #expect(cases.count == 7)
    }

    @Test("WorkoutState raw values are strings")
    func rawValues() {
        #expect(WorkoutState.idle.rawValue == "idle")
        #expect(WorkoutState.active.rawValue == "active")
        #expect(WorkoutState.paused.rawValue == "paused")
    }

    @Test("WorkoutState is equatable")
    func stateEquality() {
        #expect(WorkoutState.idle == WorkoutState.idle)
        #expect(WorkoutState.active != WorkoutState.idle)
    }
}

// MARK: - GPSSignalLevel Tests

@Suite("GPSSignalLevel")
struct GPSSignalLevelTests {

    @Test("GPSSignalLevel has all expected cases")
    func allCases() {
        let cases = GPSSignalLevel.allCases

        #expect(cases.contains(.none))
        #expect(cases.contains(.veryPoor))
        #expect(cases.contains(.poor))
        #expect(cases.contains(.fair))
        #expect(cases.contains(.good))
        #expect(cases.contains(.excellent))
        #expect(cases.count == 6)
    }

    @Test("GPSSignalLevel raw values are ordered")
    func rawValuesOrdering() {
        #expect(GPSSignalLevel.none.rawValue == 0)
        #expect(GPSSignalLevel.veryPoor.rawValue == 1)
        #expect(GPSSignalLevel.poor.rawValue == 2)
        #expect(GPSSignalLevel.fair.rawValue == 3)
        #expect(GPSSignalLevel.good.rawValue == 4)
        #expect(GPSSignalLevel.excellent.rawValue == 5)
    }

    @Test("GPSSignalLevel initializes correctly from negative accuracy")
    func initFromNegativeAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: -1)
        #expect(level == .none)
    }

    @Test("GPSSignalLevel initializes correctly from very poor accuracy")
    func initFromVeryPoorAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: 200)
        #expect(level == .veryPoor)
    }

    @Test("GPSSignalLevel initializes correctly from poor accuracy")
    func initFromPoorAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: 130)
        #expect(level == .poor)
    }

    @Test("GPSSignalLevel initializes correctly from fair accuracy")
    func initFromFairAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: 100)
        #expect(level == .fair)
    }

    @Test("GPSSignalLevel initializes correctly from good accuracy")
    func initFromGoodAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: 60)
        #expect(level == .good)
    }

    @Test("GPSSignalLevel initializes correctly from excellent accuracy")
    func initFromExcellentAccuracy() {
        let level = GPSSignalLevel(horizontalAccuracy: 10)
        #expect(level == .excellent)
    }

    @Test("GPSSignalLevel initializes correctly at boundary values")
    func initAtBoundaries() {
        #expect(GPSSignalLevel(horizontalAccuracy: 163.1) == .veryPoor)
        #expect(GPSSignalLevel(horizontalAccuracy: 163) == .veryPoor)
        #expect(GPSSignalLevel(horizontalAccuracy: 120.1) == .poor)
        #expect(GPSSignalLevel(horizontalAccuracy: 120) == .poor)
        #expect(GPSSignalLevel(horizontalAccuracy: 95.1) == .fair)
        #expect(GPSSignalLevel(horizontalAccuracy: 95) == .fair)
        #expect(GPSSignalLevel(horizontalAccuracy: 48.1) == .good)
        #expect(GPSSignalLevel(horizontalAccuracy: 48) == .excellent)
    }

    @Test("GPSSignalLevel is comparable")
    func levelComparison() {
        #expect(GPSSignalLevel.none < GPSSignalLevel.veryPoor)
        #expect(GPSSignalLevel.veryPoor < GPSSignalLevel.poor)
        #expect(GPSSignalLevel.poor < GPSSignalLevel.fair)
        #expect(GPSSignalLevel.fair < GPSSignalLevel.good)
        #expect(GPSSignalLevel.good < GPSSignalLevel.excellent)

        #expect(GPSSignalLevel.excellent > GPSSignalLevel.none)
    }
}
