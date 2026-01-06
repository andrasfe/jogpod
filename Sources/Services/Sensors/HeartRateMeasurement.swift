//
//  HeartRateMeasurement.swift
//  JogPod
//
//  Created by JogPod Migration on 2025.
//  Modern Swift replacement for WFHeartrateData and WFBTLEHeartrateData.
//

import Foundation

/// Represents a single heart rate measurement from a BLE heart rate sensor.
///
/// This struct captures all data available from the standard Bluetooth Heart Rate
/// Measurement characteristic (0x2A37), including optional fields like R-R intervals
/// and sensor contact status.
///
/// The data format follows the Bluetooth Heart Rate Profile specification.
public struct HeartRateMeasurement: Sendable, Equatable, Hashable {
    // MARK: - Primary Data

    /// The instantaneous heart rate in beats per minute (BPM).
    ///
    /// Valid range is 0-255 for 8-bit format or 0-65535 for 16-bit format.
    /// A value of 0 typically indicates invalid or unavailable data.
    public let heartRate: UInt16

    /// The timestamp when this measurement was received.
    public let timestamp: Date

    // MARK: - Sensor Contact

    /// Status of skin contact detection, if supported by the sensor.
    public let sensorContactStatus: SensorContactStatus

    // MARK: - Energy Expenditure

    /// Cumulative energy expended in kilojoules, if reported by the sensor.
    ///
    /// This value accumulates over time and resets when the sensor is reset.
    /// Not all sensors support this feature.
    public let energyExpended: UInt16?

    // MARK: - R-R Intervals

    /// R-R intervals (time between heartbeats) in seconds.
    ///
    /// Each R-R interval represents the time between successive R-waves in the
    /// cardiac cycle. Multiple intervals may be reported in a single measurement
    /// if the update rate is slower than the heart rate.
    ///
    /// Values are in seconds with resolution of 1/1024 second.
    /// Useful for heart rate variability (HRV) analysis.
    public let rrIntervals: [TimeInterval]

    // MARK: - Initialization

    /// Creates a new heart rate measurement.
    ///
    /// - Parameters:
    ///   - heartRate: The instantaneous heart rate in BPM.
    ///   - timestamp: When the measurement was received. Defaults to now.
    ///   - sensorContactStatus: Contact status with skin.
    ///   - energyExpended: Cumulative energy in kilojoules, if available.
    ///   - rrIntervals: R-R intervals in seconds, if available.
    public init(
        heartRate: UInt16,
        timestamp: Date = Date(),
        sensorContactStatus: SensorContactStatus = .notSupported,
        energyExpended: UInt16? = nil,
        rrIntervals: [TimeInterval] = []
    ) {
        self.heartRate = heartRate
        self.timestamp = timestamp
        self.sensorContactStatus = sensorContactStatus
        self.energyExpended = energyExpended
        self.rrIntervals = rrIntervals
    }
}

// MARK: - Sensor Contact Status

extension HeartRateMeasurement {
    /// Indicates whether the sensor is in contact with the user's skin.
    ///
    /// This maps to the Sensor Contact Feature and Status bits in the
    /// Heart Rate Measurement characteristic flags.
    public enum SensorContactStatus: Sendable, Equatable, Hashable {
        /// Sensor contact feature is not supported by this device.
        case notSupported

        /// Sensor contact feature is supported but status is not available
        /// in the current connection.
        case supportedButNotDetected

        /// Sensor is not in contact with skin.
        case noContact

        /// Sensor is in good contact with skin.
        case inContact

        /// Whether the sensor is currently detecting valid contact.
        public var hasGoodContact: Bool {
            self == .inContact
        }

        /// Whether the sensor supports contact detection.
        public var isContactDetectionSupported: Bool {
            switch self {
            case .notSupported:
                return false
            case .supportedButNotDetected, .noContact, .inContact:
                return true
            }
        }
    }
}

// MARK: - Convenience Properties

extension HeartRateMeasurement {
    /// Whether this measurement contains a valid heart rate value.
    ///
    /// A heart rate of 0 typically indicates the sensor hasn't detected
    /// a valid reading yet.
    public var isValid: Bool {
        heartRate > 0
    }

    /// The heart rate formatted as a display string.
    ///
    /// - Parameter includeUnits: Whether to append " BPM" to the value.
    /// - Returns: A formatted string representation of the heart rate.
    public func formattedHeartRate(includeUnits: Bool = false) -> String {
        guard isValid else {
            return "--"
        }
        if includeUnits {
            return "\(heartRate) BPM"
        }
        return "\(heartRate)"
    }

    /// Whether R-R interval data is available for HRV analysis.
    public var hasRRIntervals: Bool {
        !rrIntervals.isEmpty
    }

    /// The average R-R interval, if R-R data is available.
    public var averageRRInterval: TimeInterval? {
        guard !rrIntervals.isEmpty else { return nil }
        return rrIntervals.reduce(0, +) / Double(rrIntervals.count)
    }
}

// MARK: - CustomStringConvertible

extension HeartRateMeasurement: CustomStringConvertible {
    public var description: String {
        var parts = ["HeartRateMeasurement(\(heartRate) BPM"]

        switch sensorContactStatus {
        case .notSupported:
            break
        case .supportedButNotDetected:
            parts.append("contact: unknown")
        case .noContact:
            parts.append("contact: NO")
        case .inContact:
            parts.append("contact: YES")
        }

        if let energy = energyExpended {
            parts.append("energy: \(energy) kJ")
        }

        if !rrIntervals.isEmpty {
            let formatted = rrIntervals.map { String(format: "%.3f", $0) }.joined(separator: ", ")
            parts.append("RR: [\(formatted)]")
        }

        return parts.joined(separator: ", ") + ")"
    }
}
