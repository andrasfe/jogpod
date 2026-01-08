//
//  DiscoveredHeartRateSensor.swift
//  JogPod
//
//  Created by JogPod Migration on 2025.
//  Represents a discovered BLE heart rate sensor during scanning.
//

import Foundation

/// Represents a heart rate sensor discovered during Bluetooth scanning.
///
/// This struct contains information about a peripheral that advertises
/// the Heart Rate Service UUID, suitable for display in a device picker UI.
public struct DiscoveredHeartRateSensor: Sendable, Equatable, Hashable, Identifiable {
    // MARK: - Identification

    /// The unique identifier for this peripheral.
    ///
    /// This UUID is assigned by Core Bluetooth and persists across app launches,
    /// allowing reconnection to known devices.
    public let id: UUID

    /// The advertised local name of the sensor, if available.
    ///
    /// Common examples: "Polar H10 12345678", "TICKR X 1234", "Wahoo HRM"
    public let name: String?

    // MARK: - Signal Strength

    /// The received signal strength indicator (RSSI) in dBm.
    ///
    /// Typical values:
    /// - Excellent: -30 to -50 dBm
    /// - Good: -50 to -70 dBm
    /// - Fair: -70 to -80 dBm
    /// - Weak: -80 to -90 dBm
    /// - Very Weak: < -90 dBm
    public let rssi: Int

    // MARK: - Discovery Time

    /// When this sensor was first discovered.
    public let discoveredAt: Date

    /// When the RSSI was last updated.
    public let lastSeenAt: Date

    // MARK: - Sensor Type Hints

    /// The type of heart rate sensor, inferred from the device name.
    public let sensorType: SensorType

    // MARK: - Initialization

    /// Creates a discovered sensor record.
    ///
    /// - Parameters:
    ///   - id: The Core Bluetooth peripheral UUID.
    ///   - name: The advertised device name.
    ///   - rssi: Signal strength in dBm.
    ///   - discoveredAt: When first discovered.
    ///   - lastSeenAt: When last seen (for RSSI updates).
    public init(
        id: UUID,
        name: String?,
        rssi: Int,
        discoveredAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.discoveredAt = discoveredAt
        self.lastSeenAt = lastSeenAt
        self.sensorType = SensorType.infer(from: name)
    }

    /// Creates an updated copy with new RSSI and timestamp.
    ///
    /// - Parameter rssi: The new signal strength.
    /// - Returns: A new instance with updated RSSI and lastSeenAt.
    public func withUpdatedRSSI(_ rssi: Int) -> DiscoveredHeartRateSensor {
        DiscoveredHeartRateSensor(
            id: id,
            name: name,
            rssi: rssi,
            discoveredAt: discoveredAt,
            lastSeenAt: Date()
        )
    }
}

// MARK: - Sensor Type

extension DiscoveredHeartRateSensor {
    /// Categorizes the type of heart rate sensor.
    public enum SensorType: Sendable, Equatable, Hashable {
        /// Chest strap monitors (most accurate for exercise).
        case chestStrap

        /// Arm band sensors.
        case armBand

        /// Wrist-based sensors (typically less accurate during exercise).
        case wristSensor

        /// Sensor type could not be determined.
        case unknown

        /// Infers the sensor type from the device name.
        static func infer(from name: String?) -> SensorType {
            guard let name = name?.lowercased() else {
                return .unknown
            }

            // Chest straps
            let chestStrapKeywords = [
                "polar h", "h7", "h9", "h10",
                "tickr", "wahoo",
                "garmin hrm", "hrm-dual", "hrm-pro", "hrm-run",
                "coospo", "magene",
                "scosche rhythm",
                "suunto",
                "cardio", "chest", "strap"
            ]
            if chestStrapKeywords.contains(where: { name.contains($0) }) {
                return .chestStrap
            }

            // Arm bands
            let armBandKeywords = [
                "oh1", "verity", "arm",
                "scosche rhythm+", "rhythm 24"
            ]
            if armBandKeywords.contains(where: { name.contains($0) }) {
                return .armBand
            }

            // Wrist sensors (typically smartwatches)
            let wristKeywords = [
                "watch", "band", "wrist", "fitbit"
            ]
            if wristKeywords.contains(where: { name.contains($0) }) {
                return .wristSensor
            }

            return .unknown
        }

        /// Human-readable description of the sensor type.
        public var displayName: String {
            switch self {
            case .chestStrap:
                return "Chest Strap"
            case .armBand:
                return "Arm Band"
            case .wristSensor:
                return "Wrist Sensor"
            case .unknown:
                return "Heart Rate Monitor"
            }
        }
    }
}

// MARK: - Signal Strength

extension DiscoveredHeartRateSensor {
    /// Qualitative description of the signal strength.
    public enum SignalStrength: Sendable, Equatable {
        case excellent
        case good
        case fair
        case weak
        case veryWeak

        init(rssi: Int) {
            switch rssi {
            case (-50)...:
                self = .excellent
            case (-70) ..< (-50):
                self = .good
            case (-80) ..< (-70):
                self = .fair
            case (-90) ..< (-80):
                self = .weak
            default:
                self = .veryWeak
            }
        }

        /// Number of bars to display (0-4).
        public var bars: Int {
            switch self {
            case .excellent: return 4
            case .good: return 3
            case .fair: return 2
            case .weak: return 1
            case .veryWeak: return 0
            }
        }
    }

    /// The qualitative signal strength.
    public var signalStrength: SignalStrength {
        SignalStrength(rssi: rssi)
    }
}

// MARK: - Display Helpers

extension DiscoveredHeartRateSensor {
    /// The display name for the sensor.
    ///
    /// Returns the advertised name if available, otherwise a generic
    /// description based on the inferred sensor type.
    public var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return "\(sensorType.displayName) (\(id.uuidString.prefix(8)))"
    }
}

// MARK: - Comparable

extension DiscoveredHeartRateSensor: Comparable {
    /// Sorts by signal strength (strongest first).
    public static func < (lhs: DiscoveredHeartRateSensor, rhs: DiscoveredHeartRateSensor) -> Bool {
        lhs.rssi > rhs.rssi
    }
}
