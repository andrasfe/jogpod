//
//  HeartRateSensorErrorTests.swift
//  JogPodTests
//
//  Tests for HeartRateSensorError localization and behavior.
//

import XCTest
@testable import JogPod

final class HeartRateSensorErrorTests: XCTestCase {

    // MARK: - Bluetooth State Errors

    func testBluetoothUnavailableError() {
        let error = HeartRateSensorError.bluetoothUnavailable

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not available"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testBluetoothPoweredOffError() {
        let error = HeartRateSensorError.bluetoothPoweredOff

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("powered off"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("Settings"))
    }

    func testBluetoothUnauthorizedError() {
        let error = HeartRateSensorError.bluetoothUnauthorized

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not authorized"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testBluetoothNotReadyError() {
        let error = HeartRateSensorError.bluetoothNotReady

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not ready"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Scanning Errors

    func testScanAlreadyInProgressError() {
        let error = HeartRateSensorError.scanAlreadyInProgress

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("already in progress"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testScanTimeoutError() {
        let error = HeartRateSensorError.scanTimeout

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("No heart rate sensors found"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("turned on"))
    }

    // MARK: - Connection Errors

    func testConnectionFailedError() {
        let peripheralId = UUID()
        let underlyingMessage = "Connection refused"
        let error = HeartRateSensorError.connectionFailed(
            peripheralIdentifier: peripheralId,
            underlyingError: underlyingMessage
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Failed to connect"))
        XCTAssertTrue(error.errorDescription!.contains(underlyingMessage))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testConnectionFailedErrorWithoutUnderlyingError() {
        let peripheralId = UUID()
        let error = HeartRateSensorError.connectionFailed(
            peripheralIdentifier: peripheralId,
            underlyingError: nil
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Failed to connect"))
    }

    func testConnectionTimeoutError() {
        let peripheralId = UUID()
        let error = HeartRateSensorError.connectionTimeout(peripheralIdentifier: peripheralId)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timed out"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testUnexpectedDisconnectionError() {
        let peripheralId = UUID()
        let reason = "Signal lost"
        let error = HeartRateSensorError.unexpectedDisconnection(
            peripheralIdentifier: peripheralId,
            reason: reason
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("disconnected unexpectedly"))
        XCTAssertTrue(error.errorDescription!.contains(reason))
    }

    func testAlreadyConnectedError() {
        let peripheralId = UUID()
        let error = HeartRateSensorError.alreadyConnected(peripheralIdentifier: peripheralId)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Already connected"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testNotConnectedError() {
        let error = HeartRateSensorError.notConnected

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Not connected"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - Service Discovery Errors

    func testHeartRateServiceNotFoundError() {
        let peripheralId = UUID()
        let error = HeartRateSensorError.heartRateServiceNotFound(peripheralIdentifier: peripheralId)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("does not appear to be a heart rate sensor"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testHeartRateMeasurementCharacteristicNotFoundError() {
        let peripheralId = UUID()
        let error = HeartRateSensorError.heartRateMeasurementCharacteristicNotFound(
            peripheralIdentifier: peripheralId
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("does not support heart rate measurements"))
    }

    func testNotificationEnableFailedError() {
        let peripheralId = UUID()
        let underlyingError = "Characteristic not found"
        let error = HeartRateSensorError.notificationEnableFailed(
            peripheralIdentifier: peripheralId,
            underlyingError: underlyingError
        )

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Failed to start receiving"))
        XCTAssertTrue(error.errorDescription!.contains(underlyingError))
    }

    // MARK: - Data Errors

    func testInvalidHeartRateDataError() {
        let error = HeartRateSensorError.invalidHeartRateData

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("invalid"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testSensorContactLostError() {
        let error = HeartRateSensorError.sensorContactLost

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("lost contact"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("skin contact"))
    }

    // MARK: - Equatable

    func testErrorEquality() {
        let id1 = UUID()
        let id2 = UUID()

        XCTAssertEqual(
            HeartRateSensorError.bluetoothUnavailable,
            HeartRateSensorError.bluetoothUnavailable
        )

        XCTAssertEqual(
            HeartRateSensorError.connectionTimeout(peripheralIdentifier: id1),
            HeartRateSensorError.connectionTimeout(peripheralIdentifier: id1)
        )

        XCTAssertNotEqual(
            HeartRateSensorError.connectionTimeout(peripheralIdentifier: id1),
            HeartRateSensorError.connectionTimeout(peripheralIdentifier: id2)
        )

        XCTAssertNotEqual(
            HeartRateSensorError.bluetoothUnavailable,
            HeartRateSensorError.bluetoothPoweredOff
        )
    }

    // MARK: - Sendable

    func testErrorIsSendable() async {
        let error = HeartRateSensorError.bluetoothUnavailable

        // This should compile without warnings
        let task = Task {
            return error.errorDescription
        }

        let result = await task.value
        XCTAssertNotNil(result)
    }
}
