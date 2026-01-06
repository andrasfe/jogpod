//
//  DiscoveredHeartRateSensorTests.swift
//  JogPodTests
//
//  Tests for DiscoveredHeartRateSensor data model.
//

import XCTest
@testable import JogPod

final class DiscoveredHeartRateSensorTests: XCTestCase {

    // MARK: - Initialization

    func testBasicInitialization() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: "Test Sensor",
            rssi: -60
        )

        XCTAssertEqual(sensor.id, id)
        XCTAssertEqual(sensor.name, "Test Sensor")
        XCTAssertEqual(sensor.rssi, -60)
    }

    func testInitializationWithNilName() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: nil,
            rssi: -70
        )

        XCTAssertNil(sensor.name)
        XCTAssertEqual(sensor.sensorType, .unknown)
    }

    func testTimestampInitialization() {
        let discoveredAt = Date()
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -50,
            discoveredAt: discoveredAt,
            lastSeenAt: discoveredAt
        )

        XCTAssertEqual(sensor.discoveredAt, discoveredAt)
        XCTAssertEqual(sensor.lastSeenAt, discoveredAt)
    }

    // MARK: - Sensor Type Inference

    func testSensorTypeChestStrap_PolarH10() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Polar H10 12345678",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .chestStrap)
        XCTAssertEqual(sensor.sensorType.displayName, "Chest Strap")
    }

    func testSensorTypeChestStrap_WahooTICKR() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "TICKR X 1234",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .chestStrap)
    }

    func testSensorTypeChestStrap_GarminHRM() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Garmin HRM-Dual 123456",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .chestStrap)
    }

    func testSensorTypeChestStrap_CaseInsensitive() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "POLAR H7 12345678",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .chestStrap)
    }

    func testSensorTypeArmBand_PolarOH1() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Polar OH1 12345678",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .armBand)
        XCTAssertEqual(sensor.sensorType.displayName, "Arm Band")
    }

    func testSensorTypeArmBand_PolarVerity() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Polar Verity Sense 12345678",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .armBand)
    }

    func testSensorTypeWristSensor() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Apple Watch HRM",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .wristSensor)
        XCTAssertEqual(sensor.sensorType.displayName, "Wrist Sensor")
    }

    func testSensorTypeUnknown() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Generic HRM",
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .unknown)
        XCTAssertEqual(sensor.sensorType.displayName, "Heart Rate Monitor")
    }

    func testSensorTypeWithNilName() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: nil,
            rssi: -60
        )

        XCTAssertEqual(sensor.sensorType, .unknown)
    }

    // MARK: - Signal Strength

    func testSignalStrengthExcellent() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -40
        )

        XCTAssertEqual(sensor.signalStrength, .excellent)
        XCTAssertEqual(sensor.signalStrength.bars, 4)
    }

    func testSignalStrengthGood() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -60
        )

        XCTAssertEqual(sensor.signalStrength, .good)
        XCTAssertEqual(sensor.signalStrength.bars, 3)
    }

    func testSignalStrengthFair() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -75
        )

        XCTAssertEqual(sensor.signalStrength, .fair)
        XCTAssertEqual(sensor.signalStrength.bars, 2)
    }

    func testSignalStrengthWeak() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -85
        )

        XCTAssertEqual(sensor.signalStrength, .weak)
        XCTAssertEqual(sensor.signalStrength.bars, 1)
    }

    func testSignalStrengthVeryWeak() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -95
        )

        XCTAssertEqual(sensor.signalStrength, .veryWeak)
        XCTAssertEqual(sensor.signalStrength.bars, 0)
    }

    // MARK: - Display Name

    func testDisplayNameWithName() {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "My Heart Rate Sensor",
            rssi: -60
        )

        XCTAssertEqual(sensor.displayName, "My Heart Rate Sensor")
    }

    func testDisplayNameWithEmptyName() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: "",
            rssi: -60
        )

        XCTAssertTrue(sensor.displayName.contains("Heart Rate Monitor"))
        XCTAssertTrue(sensor.displayName.contains(String(id.uuidString.prefix(8))))
    }

    func testDisplayNameWithNilName() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: nil,
            rssi: -60
        )

        XCTAssertTrue(sensor.displayName.contains("Heart Rate Monitor"))
    }

    // MARK: - RSSI Update

    func testWithUpdatedRSSI() {
        let id = UUID()
        let originalTime = Date()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: "Test",
            rssi: -60,
            discoveredAt: originalTime,
            lastSeenAt: originalTime
        )

        let updated = sensor.withUpdatedRSSI(-50)

        XCTAssertEqual(updated.id, id)
        XCTAssertEqual(updated.name, "Test")
        XCTAssertEqual(updated.rssi, -50)
        XCTAssertEqual(updated.discoveredAt, originalTime)
        XCTAssertTrue(updated.lastSeenAt >= originalTime)
    }

    // MARK: - Equatable

    func testEquality() {
        let id = UUID()
        let time = Date()
        let s1 = DiscoveredHeartRateSensor(
            id: id,
            name: "Test",
            rssi: -60,
            discoveredAt: time,
            lastSeenAt: time
        )
        let s2 = DiscoveredHeartRateSensor(
            id: id,
            name: "Test",
            rssi: -60,
            discoveredAt: time,
            lastSeenAt: time
        )

        XCTAssertEqual(s1, s2)
    }

    func testInequalityDifferentID() {
        let time = Date()
        let s1 = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -60,
            discoveredAt: time,
            lastSeenAt: time
        )
        let s2 = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -60,
            discoveredAt: time,
            lastSeenAt: time
        )

        XCTAssertNotEqual(s1, s2)
    }

    // MARK: - Hashable

    func testHashable() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: "Test",
            rssi: -60
        )

        var set: Set<DiscoveredHeartRateSensor> = []
        set.insert(sensor)

        XCTAssertTrue(set.contains(sensor))
    }

    // MARK: - Comparable

    func testComparable_SortsbySignalStrength() {
        let strong = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Strong",
            rssi: -40
        )
        let weak = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Weak",
            rssi: -80
        )

        // Strong signal should sort first
        XCTAssertTrue(strong < weak)
        XCTAssertFalse(weak < strong)
    }

    func testSortArray() {
        let sensors = [
            DiscoveredHeartRateSensor(id: UUID(), name: "Weak", rssi: -80),
            DiscoveredHeartRateSensor(id: UUID(), name: "Strong", rssi: -40),
            DiscoveredHeartRateSensor(id: UUID(), name: "Medium", rssi: -60),
        ]

        let sorted = sensors.sorted()

        XCTAssertEqual(sorted[0].name, "Strong")
        XCTAssertEqual(sorted[1].name, "Medium")
        XCTAssertEqual(sorted[2].name, "Weak")
    }

    // MARK: - Identifiable

    func testIdentifiable() {
        let id = UUID()
        let sensor = DiscoveredHeartRateSensor(
            id: id,
            name: "Test",
            rssi: -60
        )

        XCTAssertEqual(sensor.id, id)
    }

    // MARK: - Sendable

    func testSendable() async {
        let sensor = DiscoveredHeartRateSensor(
            id: UUID(),
            name: "Test",
            rssi: -60
        )

        let task = Task {
            return sensor.displayName
        }

        let result = await task.value
        XCTAssertEqual(result, "Test")
    }
}
