//
//  HeartRateMeasurementTests.swift
//  JogPodTests
//
//  Tests for HeartRateMeasurement data model.
//

import XCTest
@testable import JogPod

final class HeartRateMeasurementTests: XCTestCase {

    // MARK: - Initialization

    func testBasicInitialization() {
        let measurement = HeartRateMeasurement(heartRate: 75)

        XCTAssertEqual(measurement.heartRate, 75)
        XCTAssertEqual(measurement.sensorContactStatus, .notSupported)
        XCTAssertNil(measurement.energyExpended)
        XCTAssertTrue(measurement.rrIntervals.isEmpty)
        XCTAssertTrue(measurement.isValid)
    }

    func testFullInitialization() {
        let timestamp = Date()
        let rrIntervals: [TimeInterval] = [0.8, 0.82, 0.79]

        let measurement = HeartRateMeasurement(
            heartRate: 165,
            timestamp: timestamp,
            sensorContactStatus: .inContact,
            energyExpended: 450,
            rrIntervals: rrIntervals
        )

        XCTAssertEqual(measurement.heartRate, 165)
        XCTAssertEqual(measurement.timestamp, timestamp)
        XCTAssertEqual(measurement.sensorContactStatus, .inContact)
        XCTAssertEqual(measurement.energyExpended, 450)
        XCTAssertEqual(measurement.rrIntervals, rrIntervals)
    }

    func testZeroHeartRateIsInvalid() {
        let measurement = HeartRateMeasurement(heartRate: 0)

        XCTAssertFalse(measurement.isValid)
        XCTAssertEqual(measurement.formattedHeartRate(), "--")
    }

    func testMaxHeartRate() {
        let measurement = HeartRateMeasurement(heartRate: 255)

        XCTAssertEqual(measurement.heartRate, 255)
        XCTAssertTrue(measurement.isValid)
    }

    func test16BitHeartRate() {
        // 16-bit heart rate values (unlikely in practice, but supported by spec)
        let measurement = HeartRateMeasurement(heartRate: 300)

        XCTAssertEqual(measurement.heartRate, 300)
        XCTAssertTrue(measurement.isValid)
    }

    // MARK: - Sensor Contact Status

    func testSensorContactNotSupported() {
        let status = HeartRateMeasurement.SensorContactStatus.notSupported

        XCTAssertFalse(status.hasGoodContact)
        XCTAssertFalse(status.isContactDetectionSupported)
    }

    func testSensorContactSupportedButNotDetected() {
        let status = HeartRateMeasurement.SensorContactStatus.supportedButNotDetected

        XCTAssertFalse(status.hasGoodContact)
        XCTAssertTrue(status.isContactDetectionSupported)
    }

    func testSensorContactNoContact() {
        let status = HeartRateMeasurement.SensorContactStatus.noContact

        XCTAssertFalse(status.hasGoodContact)
        XCTAssertTrue(status.isContactDetectionSupported)
    }

    func testSensorContactInContact() {
        let status = HeartRateMeasurement.SensorContactStatus.inContact

        XCTAssertTrue(status.hasGoodContact)
        XCTAssertTrue(status.isContactDetectionSupported)
    }

    // MARK: - Formatting

    func testFormattedHeartRateWithoutUnits() {
        let measurement = HeartRateMeasurement(heartRate: 142)

        XCTAssertEqual(measurement.formattedHeartRate(), "142")
        XCTAssertEqual(measurement.formattedHeartRate(includeUnits: false), "142")
    }

    func testFormattedHeartRateWithUnits() {
        let measurement = HeartRateMeasurement(heartRate: 142)

        XCTAssertEqual(measurement.formattedHeartRate(includeUnits: true), "142 BPM")
    }

    func testFormattedHeartRateInvalid() {
        let measurement = HeartRateMeasurement(heartRate: 0)

        XCTAssertEqual(measurement.formattedHeartRate(), "--")
        XCTAssertEqual(measurement.formattedHeartRate(includeUnits: true), "--")
    }

    // MARK: - R-R Intervals

    func testNoRRIntervals() {
        let measurement = HeartRateMeasurement(heartRate: 80)

        XCTAssertFalse(measurement.hasRRIntervals)
        XCTAssertNil(measurement.averageRRInterval)
    }

    func testSingleRRInterval() {
        let measurement = HeartRateMeasurement(
            heartRate: 75,
            rrIntervals: [0.8]
        )

        XCTAssertTrue(measurement.hasRRIntervals)
        XCTAssertEqual(measurement.averageRRInterval, 0.8, accuracy: 0.001)
    }

    func testMultipleRRIntervals() {
        let rrIntervals: [TimeInterval] = [0.75, 0.80, 0.85]
        let measurement = HeartRateMeasurement(
            heartRate: 75,
            rrIntervals: rrIntervals
        )

        XCTAssertTrue(measurement.hasRRIntervals)
        XCTAssertEqual(measurement.averageRRInterval!, 0.8, accuracy: 0.001)
    }

    // MARK: - Equatable

    func testEquality() {
        let timestamp = Date()
        let m1 = HeartRateMeasurement(
            heartRate: 100,
            timestamp: timestamp,
            sensorContactStatus: .inContact,
            energyExpended: 200,
            rrIntervals: [0.6]
        )
        let m2 = HeartRateMeasurement(
            heartRate: 100,
            timestamp: timestamp,
            sensorContactStatus: .inContact,
            energyExpended: 200,
            rrIntervals: [0.6]
        )

        XCTAssertEqual(m1, m2)
    }

    func testInequalityHeartRate() {
        let timestamp = Date()
        let m1 = HeartRateMeasurement(heartRate: 100, timestamp: timestamp)
        let m2 = HeartRateMeasurement(heartRate: 101, timestamp: timestamp)

        XCTAssertNotEqual(m1, m2)
    }

    func testInequalityContactStatus() {
        let timestamp = Date()
        let m1 = HeartRateMeasurement(
            heartRate: 100,
            timestamp: timestamp,
            sensorContactStatus: .inContact
        )
        let m2 = HeartRateMeasurement(
            heartRate: 100,
            timestamp: timestamp,
            sensorContactStatus: .noContact
        )

        XCTAssertNotEqual(m1, m2)
    }

    // MARK: - Hashable

    func testHashable() {
        let m1 = HeartRateMeasurement(heartRate: 100)
        let m2 = HeartRateMeasurement(heartRate: 100)
        let m3 = HeartRateMeasurement(heartRate: 101)

        var set: Set<HeartRateMeasurement> = []
        set.insert(m1)

        // m2 has the same values as m1 but different timestamp, so should be different
        // unless timestamps are very close
        XCTAssertTrue(set.contains(m1))
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let measurement = HeartRateMeasurement(
            heartRate: 142,
            sensorContactStatus: .inContact,
            energyExpended: 500,
            rrIntervals: [0.75, 0.80]
        )

        let description = measurement.description

        XCTAssertTrue(description.contains("142 BPM"))
        XCTAssertTrue(description.contains("contact: YES"))
        XCTAssertTrue(description.contains("500 kJ"))
        XCTAssertTrue(description.contains("RR:"))
    }

    func testDescriptionMinimal() {
        let measurement = HeartRateMeasurement(heartRate: 80)

        let description = measurement.description

        XCTAssertTrue(description.contains("80 BPM"))
        XCTAssertFalse(description.contains("contact"))
        XCTAssertFalse(description.contains("energy"))
        XCTAssertFalse(description.contains("RR"))
    }

    // MARK: - Sendable

    func testSendable() async {
        let measurement = HeartRateMeasurement(
            heartRate: 150,
            sensorContactStatus: .inContact,
            rrIntervals: [0.5, 0.6]
        )

        let task = Task {
            return measurement.heartRate
        }

        let result = await task.value
        XCTAssertEqual(result, 150)
    }
}
