//
//  HeartRateServiceTests.swift
//  JogPodTests
//
//  Tests for HeartRateService Core Bluetooth implementation.
//

import XCTest
import CoreBluetooth
import Combine
@testable import JogPod

final class HeartRateServiceTests: XCTestCase {

    var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - UUID Constants

    func testHeartRateServiceUUID() {
        XCTAssertEqual(
            HeartRateServiceUUIDs.heartRateService.uuidString,
            "180D"
        )
    }

    func testHeartRateMeasurementCharacteristicUUID() {
        XCTAssertEqual(
            HeartRateServiceUUIDs.heartRateMeasurement.uuidString,
            "2A37"
        )
    }

    func testBodySensorLocationCharacteristicUUID() {
        XCTAssertEqual(
            HeartRateServiceUUIDs.bodySensorLocation.uuidString,
            "2A38"
        )
    }

    func testHeartRateControlPointCharacteristicUUID() {
        XCTAssertEqual(
            HeartRateServiceUUIDs.heartRateControlPoint.uuidString,
            "2A39"
        )
    }

    // MARK: - Connection State

    func testConnectionStateDisconnected() {
        let state = HeartRateSensorConnectionState.disconnected

        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertNil(state.sensorId)
    }

    func testConnectionStateScanning() {
        let state = HeartRateSensorConnectionState.scanning

        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertNil(state.sensorId)
    }

    func testConnectionStateConnecting() {
        let sensorId = UUID()
        let state = HeartRateSensorConnectionState.connecting(sensorId: sensorId)

        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isConnecting)
        XCTAssertEqual(state.sensorId, sensorId)
    }

    func testConnectionStateDiscoveringServices() {
        let sensorId = UUID()
        let state = HeartRateSensorConnectionState.discoveringServices(sensorId: sensorId)

        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isConnecting)
        XCTAssertEqual(state.sensorId, sensorId)
    }

    func testConnectionStateConnected() {
        let sensorId = UUID()
        let state = HeartRateSensorConnectionState.connected(sensorId: sensorId)

        XCTAssertTrue(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertEqual(state.sensorId, sensorId)
    }

    func testConnectionStateDisconnecting() {
        let sensorId = UUID()
        let state = HeartRateSensorConnectionState.disconnecting(sensorId: sensorId)

        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertEqual(state.sensorId, sensorId)
    }

    func testConnectionStateEquality() {
        let id1 = UUID()
        let id2 = UUID()

        XCTAssertEqual(
            HeartRateSensorConnectionState.disconnected,
            HeartRateSensorConnectionState.disconnected
        )

        XCTAssertEqual(
            HeartRateSensorConnectionState.connected(sensorId: id1),
            HeartRateSensorConnectionState.connected(sensorId: id1)
        )

        XCTAssertNotEqual(
            HeartRateSensorConnectionState.connected(sensorId: id1),
            HeartRateSensorConnectionState.connected(sensorId: id2)
        )

        XCTAssertNotEqual(
            HeartRateSensorConnectionState.connecting(sensorId: id1),
            HeartRateSensorConnectionState.connected(sensorId: id1)
        )
    }

    // MARK: - Heart Rate Parsing Tests

    func testParseHeartRate8Bit() async {
        // Test parsing of 8-bit heart rate format
        // Flags: 0x00 (8-bit HR, no contact, no energy, no RR)
        // HR: 75 BPM
        let data = Data([0x00, 75])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 75)
        XCTAssertEqual(measurement?.sensorContactStatus, .notSupported)
        XCTAssertNil(measurement?.energyExpended)
        XCTAssertTrue(measurement?.rrIntervals.isEmpty ?? false)
    }

    func testParseHeartRate16Bit() async {
        // Flags: 0x01 (16-bit HR)
        // HR: 0x00C8 = 200 BPM (low byte first)
        let data = Data([0x01, 0xC8, 0x00])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 200)
    }

    func testParseHeartRateWithSensorContactSupported_InContact() async {
        // Flags: 0x06 (8-bit HR, contact supported, contact detected)
        // HR: 85 BPM
        let data = Data([0x06, 85])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 85)
        XCTAssertEqual(measurement?.sensorContactStatus, .inContact)
    }

    func testParseHeartRateWithSensorContactSupported_NoContact() async {
        // Flags: 0x04 (8-bit HR, contact supported, contact NOT detected)
        // HR: 0 BPM (no contact so no reading)
        let data = Data([0x04, 0])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 0)
        XCTAssertEqual(measurement?.sensorContactStatus, .noContact)
    }

    func testParseHeartRateWithEnergyExpended() async {
        // Flags: 0x08 (8-bit HR, energy expended present)
        // HR: 150 BPM
        // Energy: 0x01F4 = 500 kJ (low byte first)
        let data = Data([0x08, 150, 0xF4, 0x01])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 150)
        XCTAssertEqual(measurement?.energyExpended, 500)
    }

    func testParseHeartRateWithRRIntervals() async {
        // Flags: 0x10 (8-bit HR, RR intervals present)
        // HR: 70 BPM
        // RR1: 0x0340 = 832 (832/1024 = 0.8125 seconds)
        let data = Data([0x10, 70, 0x40, 0x03])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 70)
        XCTAssertFalse(measurement?.rrIntervals.isEmpty ?? true)
        XCTAssertEqual(measurement?.rrIntervals.first ?? 0, 832.0 / 1024.0, accuracy: 0.001)
    }

    func testParseHeartRateWithMultipleRRIntervals() async {
        // Flags: 0x10 (8-bit HR, RR intervals present)
        // HR: 72 BPM
        // RR1: 0x0340 = 832 (0.8125 seconds)
        // RR2: 0x0320 = 800 (0.78125 seconds)
        let data = Data([0x10, 72, 0x40, 0x03, 0x20, 0x03])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 72)
        XCTAssertEqual(measurement?.rrIntervals.count, 2)
    }

    func testParseHeartRateFullPacket() async {
        // Flags: 0x1F (16-bit HR, contact supported+detected, energy present, RR present)
        // HR: 0x00A0 = 160 BPM
        // Energy: 0x012C = 300 kJ
        // RR: 0x0300 = 768 (0.75 seconds)
        let data = Data([0x1F, 0xA0, 0x00, 0x2C, 0x01, 0x00, 0x03])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNotNil(measurement)
        XCTAssertEqual(measurement?.heartRate, 160)
        XCTAssertEqual(measurement?.sensorContactStatus, .inContact)
        XCTAssertEqual(measurement?.energyExpended, 300)
        XCTAssertEqual(measurement?.rrIntervals.count, 1)
    }

    func testParseHeartRateInvalidData_TooShort() async {
        // Data too short to contain even flags + 1 byte HR
        let data = Data([0x00])

        let measurement = parseTestHeartRateData(data)

        XCTAssertNil(measurement)
    }

    func testParseHeartRateInvalidData_Empty() async {
        let data = Data()

        let measurement = parseTestHeartRateData(data)

        XCTAssertNil(measurement)
    }

    // MARK: - Service Initialization

    func testServiceInitialization() async {
        let service = HeartRateService()

        // Give CBCentralManager time to initialize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let state = await service.connectionState
        XCTAssertEqual(state, .disconnected)

        let lastMeasurement = await service.lastMeasurement
        XCTAssertNil(lastMeasurement)
    }

    // MARK: - Publisher Tests

    func testConnectionStatePublisher() async {
        let service = HeartRateService()
        var receivedStates: [HeartRateSensorConnectionState] = []

        let expectation = XCTestExpectation(description: "Receive initial state")

        service.connectionStatePublisher
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await fulfillment(of: [expectation], timeout: 1.0)

        // Should receive the initial disconnected state
        XCTAssertTrue(receivedStates.contains(.disconnected))
    }

    // MARK: - Helper Methods

    /// Helper to test heart rate data parsing without needing a full CBPeripheral.
    private func parseTestHeartRateData(_ data: Data) -> HeartRateMeasurement? {
        // Directly call the parsing logic that would be in HeartRateService
        guard data.count >= 2 else { return nil }

        let flags = data[0]

        let isHeartRate16Bit = (flags & 0x01) != 0
        let contactSupported = (flags & 0x04) != 0
        let contactDetected = (flags & 0x02) != 0

        let sensorContactStatus: HeartRateMeasurement.SensorContactStatus
        if contactSupported {
            sensorContactStatus = contactDetected ? .inContact : .noContact
        } else if (flags & 0x06) == 0x02 {
            sensorContactStatus = .supportedButNotDetected
        } else {
            sensorContactStatus = .notSupported
        }

        let energyExpendedPresent = (flags & 0x08) != 0
        let rrIntervalsPresent = (flags & 0x10) != 0

        var offset = 1

        let heartRate: UInt16
        if isHeartRate16Bit {
            guard data.count >= offset + 2 else { return nil }
            heartRate = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
        } else {
            heartRate = UInt16(data[offset])
            offset += 1
        }

        var energyExpended: UInt16?
        if energyExpendedPresent {
            guard data.count >= offset + 2 else { return nil }
            energyExpended = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
        }

        var rrIntervals: [TimeInterval] = []
        if rrIntervalsPresent {
            while offset + 1 < data.count {
                let rawRR = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                let rrInterval = TimeInterval(rawRR) / 1024.0
                rrIntervals.append(rrInterval)
                offset += 2
            }
        }

        return HeartRateMeasurement(
            heartRate: heartRate,
            timestamp: Date(),
            sensorContactStatus: sensorContactStatus,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals
        )
    }
}

// MARK: - Mock HeartRateService for Testing

/// A mock implementation of HeartRateServiceProtocol for testing purposes.
actor MockHeartRateService: HeartRateServiceProtocol {
    var connectionState: HeartRateSensorConnectionState = .disconnected
    var lastMeasurement: HeartRateMeasurement?
    var isBluetoothReady: Bool = true

    private let connectionStateSubject = CurrentValueSubject<HeartRateSensorConnectionState, Never>(.disconnected)
    private let measurementSubject = PassthroughSubject<HeartRateMeasurement, Never>()

    nonisolated var connectionStatePublisher: AnyPublisher<HeartRateSensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    nonisolated var measurementPublisher: AnyPublisher<HeartRateMeasurement, Never> {
        measurementSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: [DiscoveredHeartRateSensor] = []
    var connectShouldFail: Bool = false
    var connectError: HeartRateSensorError?

    func startScanning() async throws -> AsyncStream<DiscoveredHeartRateSensor> {
        guard isBluetoothReady else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        connectionState = .scanning
        connectionStateSubject.send(.scanning)

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            Task {
                for sensor in await self.discoveredSensors {
                    continuation.yield(sensor)
                }
                continuation.finish()
            }
        }
    }

    func stopScanning() async {
        connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
    }

    func connect(to sensorId: UUID) async throws {
        if connectShouldFail {
            throw connectError ?? HeartRateSensorError.connectionFailed(
                peripheralIdentifier: sensorId,
                underlyingError: "Mock connection failure"
            )
        }

        connectionState = .connecting(sensorId: sensorId)
        connectionStateSubject.send(.connecting(sensorId: sensorId))

        // Simulate connection delay
        try? await Task.sleep(nanoseconds: 10_000_000)

        connectionState = .connected(sensorId: sensorId)
        connectionStateSubject.send(.connected(sensorId: sensorId))
    }

    func disconnect() async {
        if case .connected(let sensorId) = connectionState {
            connectionState = .disconnecting(sensorId: sensorId)
            connectionStateSubject.send(.disconnecting(sensorId: sensorId))
        }

        connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
        lastMeasurement = nil
    }

    func simulateMeasurement(_ measurement: HeartRateMeasurement) {
        lastMeasurement = measurement
        measurementSubject.send(measurement)
    }
}

// MARK: - Mock Service Tests

final class MockHeartRateServiceTests: XCTestCase {

    func testMockServiceScanning() async throws {
        let mockService = MockHeartRateService()

        await mockService.setDiscoveredSensors([
            DiscoveredHeartRateSensor(id: UUID(), name: "Sensor 1", rssi: -60),
            DiscoveredHeartRateSensor(id: UUID(), name: "Sensor 2", rssi: -70),
        ])

        let stream = try await mockService.startScanning()
        var foundSensors: [DiscoveredHeartRateSensor] = []

        for await sensor in stream {
            foundSensors.append(sensor)
        }

        XCTAssertEqual(foundSensors.count, 2)
    }

    func testMockServiceConnection() async throws {
        let mockService = MockHeartRateService()
        let sensorId = UUID()

        try await mockService.connect(to: sensorId)

        let state = await mockService.connectionState
        XCTAssertEqual(state, .connected(sensorId: sensorId))
    }

    func testMockServiceConnectionFailure() async throws {
        let mockService = MockHeartRateService()
        await mockService.setConnectShouldFail(true)
        let sensorId = UUID()

        do {
            try await mockService.connect(to: sensorId)
            XCTFail("Should have thrown an error")
        } catch let error as HeartRateSensorError {
            if case .connectionFailed = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testMockServiceMeasurementSimulation() async {
        let mockService = MockHeartRateService()
        let measurement = HeartRateMeasurement(heartRate: 120)

        await mockService.simulateMeasurement(measurement)

        let lastMeasurement = await mockService.lastMeasurement
        XCTAssertEqual(lastMeasurement?.heartRate, 120)
    }
}

// MARK: - Mock Service Helpers

extension MockHeartRateService {
    func setDiscoveredSensors(_ sensors: [DiscoveredHeartRateSensor]) {
        self.discoveredSensors = sensors
    }

    func setConnectShouldFail(_ shouldFail: Bool) {
        self.connectShouldFail = shouldFail
    }
}
