//
//  HeartRateSensorError.swift
//  JogPod
//
//  Created by JogPod Migration on 2025.
//  Replaces WFConnector framework heart rate functionality with Core Bluetooth.
//

import Foundation

/// Errors that can occur during heart rate sensor operations.
///
/// This error type covers the full range of failures from Bluetooth availability
/// through connection lifecycle and data retrieval.
public enum HeartRateSensorError: Error, Equatable, Sendable {
    // MARK: - Bluetooth State Errors

    /// Bluetooth is not available on this device.
    case bluetoothUnavailable

    /// Bluetooth is powered off.
    case bluetoothPoweredOff

    /// The app is not authorized to use Bluetooth.
    case bluetoothUnauthorized

    /// Bluetooth state is unknown or resetting.
    case bluetoothNotReady

    // MARK: - Scanning Errors

    /// A scan is already in progress.
    case scanAlreadyInProgress

    /// The scan timed out without finding any devices.
    case scanTimeout

    // MARK: - Connection Errors

    /// Failed to connect to the specified peripheral.
    case connectionFailed(peripheralIdentifier: UUID, underlyingError: String?)

    /// Connection attempt timed out.
    case connectionTimeout(peripheralIdentifier: UUID)

    /// The peripheral disconnected unexpectedly.
    case unexpectedDisconnection(peripheralIdentifier: UUID, reason: String?)

    /// Already connected to this peripheral.
    case alreadyConnected(peripheralIdentifier: UUID)

    /// Not currently connected to any sensor.
    case notConnected

    // MARK: - Service Discovery Errors

    /// Heart Rate Service not found on the peripheral.
    case heartRateServiceNotFound(peripheralIdentifier: UUID)

    /// Heart Rate Measurement characteristic not found.
    case heartRateMeasurementCharacteristicNotFound(peripheralIdentifier: UUID)

    /// Failed to enable notifications for heart rate measurements.
    case notificationEnableFailed(peripheralIdentifier: UUID, underlyingError: String?)

    // MARK: - Data Errors

    /// Received invalid or malformed heart rate data.
    case invalidHeartRateData

    /// The sensor reported no contact with skin.
    case sensorContactLost
}

// MARK: - LocalizedError

extension HeartRateSensorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device."
        case .bluetoothPoweredOff:
            return "Bluetooth is powered off. Please enable Bluetooth in Settings."
        case .bluetoothUnauthorized:
            return "JogPod is not authorized to use Bluetooth. Please grant permission in Settings."
        case .bluetoothNotReady:
            return "Bluetooth is not ready. Please wait and try again."
        case .scanAlreadyInProgress:
            return "A scan for heart rate sensors is already in progress."
        case .scanTimeout:
            return "No heart rate sensors found. Make sure your sensor is turned on and in range."
        case .connectionFailed(let id, let underlying):
            let base = "Failed to connect to heart rate sensor (\(id.uuidString.prefix(8)))."
            if let underlying {
                return "\(base) \(underlying)"
            }
            return base
        case .connectionTimeout(let id):
            return "Connection to heart rate sensor (\(id.uuidString.prefix(8))) timed out."
        case .unexpectedDisconnection(let id, let reason):
            let base = "Heart rate sensor (\(id.uuidString.prefix(8))) disconnected unexpectedly."
            if let reason {
                return "\(base) \(reason)"
            }
            return base
        case .alreadyConnected(let id):
            return "Already connected to heart rate sensor (\(id.uuidString.prefix(8)))."
        case .notConnected:
            return "Not connected to any heart rate sensor."
        case .heartRateServiceNotFound(let id):
            return "The device (\(id.uuidString.prefix(8))) does not appear to be a heart rate sensor."
        case .heartRateMeasurementCharacteristicNotFound(let id):
            return "Heart rate sensor (\(id.uuidString.prefix(8))) does not support heart rate measurements."
        case .notificationEnableFailed(let id, let underlying):
            let base = "Failed to start receiving heart rate data from sensor (\(id.uuidString.prefix(8)))."
            if let underlying {
                return "\(base) \(underlying)"
            }
            return base
        case .invalidHeartRateData:
            return "Received invalid heart rate data from sensor."
        case .sensorContactLost:
            return "Heart rate sensor has lost contact with skin."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .bluetoothUnavailable:
            return "This device does not support Bluetooth Low Energy."
        case .bluetoothPoweredOff:
            return "Open Settings and turn on Bluetooth."
        case .bluetoothUnauthorized:
            return "Open Settings > JogPod and enable Bluetooth access."
        case .bluetoothNotReady:
            return "Wait a moment for Bluetooth to initialize."
        case .scanAlreadyInProgress:
            return "Wait for the current scan to complete or cancel it first."
        case .scanTimeout:
            return "Ensure your heart rate sensor is turned on, charged, and within range."
        case .connectionFailed, .connectionTimeout:
            return "Try moving closer to the sensor and attempt to connect again."
        case .unexpectedDisconnection:
            return "Check that the sensor is charged and try reconnecting."
        case .alreadyConnected:
            return "Disconnect from the current sensor before connecting to another."
        case .notConnected:
            return "Connect to a heart rate sensor first."
        case .heartRateServiceNotFound, .heartRateMeasurementCharacteristicNotFound:
            return "Ensure the device is a compatible BLE heart rate monitor."
        case .notificationEnableFailed:
            return "Try disconnecting and reconnecting to the sensor."
        case .invalidHeartRateData:
            return "The sensor may need to be reset or replaced."
        case .sensorContactLost:
            return "Adjust the position of your heart rate sensor to ensure good skin contact."
        }
    }
}
