//
//  MockHeartRateService.swift
//  JogPodTests
//
//  Mock implementation of HeartRateServiceProtocol for testing BLE heart rate functionality.
//  Provides configurable behavior for simulating sensor discovery, connection, and data streaming.
//

import Foundation
import Combine
import CoreBluetooth
@testable import JogPod

// MARK: - MockHeartRateService

/// A comprehensive mock implementation of HeartRateServiceProtocol for testing.
///
/// This mock allows complete control over heart rate sensor behavior including:
/// - Simulating sensor discovery during scanning
/// - Controlling connection success/failure scenarios
/// - Streaming heart rate measurements with configurable patterns
/// - Simulating various error conditions
///
/// ## Usage
///
/// ```swift
/// let mockService = MockHeartRateService()
///
/// // Configure discovered sensors
/// await mockService.setDiscoveredSensors([
///     DiscoveredHeartRateSensor(id: UUID(), name: "Polar H10", rssi: -60)
/// ])
///
/// // Simulate heart rate data
/// await mockService.simulateMeasurement(HeartRateMeasurement(heartRate: 145))
///
/// // Test error handling
/// await mockService.setConnectionBehavior(.failWith(.connectionTimeout(peripheralIdentifier: sensorId)))
/// ```
public actor MockHeartRateService: HeartRateServiceProtocol {

    // MARK: - Published State

    public private(set) var connectionState: HeartRateSensorConnectionState = .disconnected
    public private(set) var lastMeasurement: HeartRateMeasurement?
    public var isBluetoothReady: Bool = true

    // MARK: - Publishers

    private let connectionStateSubject = CurrentValueSubject<HeartRateSensorConnectionState, Never>(.disconnected)
    private let measurementSubject = PassthroughSubject<HeartRateMeasurement, Never>()

    public nonisolated var connectionStatePublisher: AnyPublisher<HeartRateSensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public nonisolated var measurementPublisher: AnyPublisher<HeartRateMeasurement, Never> {
        measurementSubject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    /// Sensors that will be "discovered" during scanning.
    private var discoveredSensors: [DiscoveredHeartRateSensor] = []

    /// Controls how connection attempts behave.
    private var connectionBehavior: ConnectionBehavior = .succeed

    /// Delay before scan results are returned (simulates real-world scanning).
    private var scanDelay: TimeInterval = 0.01

    /// Delay before connection completes (simulates BLE connection time).
    private var connectionDelay: TimeInterval = 0.01

    /// Whether to automatically emit measurements when connected.
    private var autoEmitMeasurements: Bool = false

    /// The simulated heart rate data provider.
    private var heartRateProvider: SimulatedHeartRateSensor?

    /// Task for automatic measurement emission.
    private var measurementTask: Task<Void, Never>?

    // MARK: - Call Tracking

    /// Tracks how many times each method was called for verification.
    private var methodCallCounts: [String: Int] = [:]

    /// Records of method calls with parameters for detailed assertions.
    private var methodCallLog: [MethodCall] = []

    // MARK: - Initialization

    public init(
        isBluetoothReady: Bool = true,
        discoveredSensors: [DiscoveredHeartRateSensor] = []
    ) {
        self.isBluetoothReady = isBluetoothReady
        self.discoveredSensors = discoveredSensors
    }

    // MARK: - HeartRateServiceProtocol Implementation

    public func startScanning() async throws -> AsyncStream<DiscoveredHeartRateSensor> {
        recordMethodCall("startScanning")

        guard isBluetoothReady else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        if case .scanning = connectionState {
            throw HeartRateSensorError.scanAlreadyInProgress
        }

        updateConnectionState(.scanning)

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            Task {
                // Simulate scan delay
                let delay = await self.scanDelay
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Yield discovered sensors
                for sensor in await self.discoveredSensors {
                    continuation.yield(sensor)
                    try? await Task.sleep(nanoseconds: 5_000_000) // Small delay between discoveries
                }

                continuation.finish()
            }
        }
    }

    public func stopScanning() async {
        recordMethodCall("stopScanning")
        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }
    }

    public func connect(to sensorId: UUID) async throws {
        recordMethodCall("connect", parameters: ["sensorId": sensorId.uuidString])

        guard isBluetoothReady else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        // Check if already connected
        if case .connected(let connectedId) = connectionState, connectedId == sensorId {
            throw HeartRateSensorError.alreadyConnected(peripheralIdentifier: sensorId)
        }

        // Stop scanning if in progress
        if case .scanning = connectionState {
            await stopScanning()
        }

        // Update state to connecting
        updateConnectionState(.connecting(sensorId: sensorId))

        // Simulate connection delay
        try? await Task.sleep(nanoseconds: UInt64(connectionDelay * 1_000_000_000))

        // Handle connection behavior
        switch connectionBehavior {
        case .succeed:
            updateConnectionState(.discoveringServices(sensorId: sensorId))
            try? await Task.sleep(nanoseconds: 5_000_000)
            updateConnectionState(.connected(sensorId: sensorId))

            // Start automatic measurements if configured
            if autoEmitMeasurements, let provider = heartRateProvider {
                startAutomaticMeasurements(provider: provider)
            }

        case .failWith(let error):
            updateConnectionState(.disconnected)
            throw error

        case .timeout:
            updateConnectionState(.disconnected)
            throw HeartRateSensorError.connectionTimeout(peripheralIdentifier: sensorId)

        case .failAfterDelay(let delay, let error):
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            updateConnectionState(.disconnected)
            throw error

        case .disconnectAfterConnecting(let delay):
            updateConnectionState(.connected(sensorId: sensorId))
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await self?.simulateUnexpectedDisconnection(sensorId: sensorId)
            }
        }
    }

    public func disconnect() async {
        recordMethodCall("disconnect")

        measurementTask?.cancel()
        measurementTask = nil

        if case .connected(let sensorId) = connectionState {
            updateConnectionState(.disconnecting(sensorId: sensorId))
            try? await Task.sleep(nanoseconds: 5_000_000)
        }

        updateConnectionState(.disconnected)
        lastMeasurement = nil
    }

    // MARK: - Configuration Methods

    /// Sets the sensors that will be discovered during scanning.
    public func setDiscoveredSensors(_ sensors: [DiscoveredHeartRateSensor]) {
        discoveredSensors = sensors
    }

    /// Adds a sensor to the discovery list.
    public func addDiscoveredSensor(_ sensor: DiscoveredHeartRateSensor) {
        discoveredSensors.append(sensor)
    }

    /// Sets how connection attempts should behave.
    public func setConnectionBehavior(_ behavior: ConnectionBehavior) {
        connectionBehavior = behavior
    }

    /// Sets the delay before scan results are returned.
    public func setScanDelay(_ delay: TimeInterval) {
        scanDelay = delay
    }

    /// Sets the delay before connection completes.
    public func setConnectionDelay(_ delay: TimeInterval) {
        connectionDelay = delay
    }

    /// Configures whether Bluetooth appears ready.
    public func setBluetoothReady(_ ready: Bool) {
        isBluetoothReady = ready
    }

    /// Enables automatic measurement emission using a simulated sensor.
    public func enableAutomaticMeasurements(provider: SimulatedHeartRateSensor) {
        autoEmitMeasurements = true
        heartRateProvider = provider
    }

    /// Disables automatic measurement emission.
    public func disableAutomaticMeasurements() {
        autoEmitMeasurements = false
        measurementTask?.cancel()
        measurementTask = nil
    }

    // MARK: - Simulation Methods

    /// Simulates receiving a heart rate measurement.
    ///
    /// Updates lastMeasurement and emits through the publisher.
    public func simulateMeasurement(_ measurement: HeartRateMeasurement) {
        lastMeasurement = measurement
        measurementSubject.send(measurement)
    }

    /// Simulates a series of measurements at a specified interval.
    public func simulateMeasurementSequence(
        _ measurements: [HeartRateMeasurement],
        interval: TimeInterval = 1.0
    ) {
        measurementTask?.cancel()
        measurementTask = Task { [weak self] in
            for measurement in measurements {
                guard !Task.isCancelled else { break }
                await self?.simulateMeasurement(measurement)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Simulates an unexpected disconnection.
    public func simulateUnexpectedDisconnection(sensorId: UUID) {
        measurementTask?.cancel()
        measurementTask = nil
        updateConnectionState(.disconnected)
        lastMeasurement = nil
    }

    /// Simulates Bluetooth becoming unavailable.
    public func simulateBluetoothPoweredOff() {
        isBluetoothReady = false
        Task { await disconnect() }
    }

    // MARK: - Verification Methods

    /// Returns the number of times a method was called.
    public func callCount(for method: String) -> Int {
        methodCallCounts[method] ?? 0
    }

    /// Returns all recorded method calls.
    public func getMethodCallLog() -> [MethodCall] {
        methodCallLog
    }

    /// Resets all call tracking.
    public func resetCallTracking() {
        methodCallCounts.removeAll()
        methodCallLog.removeAll()
    }

    /// Verifies that a method was called a specific number of times.
    public func verifyCallCount(for method: String, expected: Int) -> Bool {
        callCount(for: method) == expected
    }

    // MARK: - Private Methods

    private func updateConnectionState(_ newState: HeartRateSensorConnectionState) {
        connectionState = newState
        connectionStateSubject.send(newState)
    }

    private func recordMethodCall(_ method: String, parameters: [String: String] = [:]) {
        methodCallCounts[method, default: 0] += 1
        methodCallLog.append(MethodCall(method: method, parameters: parameters, timestamp: Date()))
    }

    private func startAutomaticMeasurements(provider: SimulatedHeartRateSensor) {
        measurementTask?.cancel()
        measurementTask = Task { [weak self] in
            while !Task.isCancelled {
                if let measurement = await provider.nextMeasurement() {
                    await self?.simulateMeasurement(measurement)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second interval
            }
        }
    }
}

// MARK: - Supporting Types

extension MockHeartRateService {

    /// Defines how connection attempts should behave.
    public enum ConnectionBehavior: Sendable {
        /// Connection succeeds normally.
        case succeed

        /// Connection fails immediately with the specified error.
        case failWith(HeartRateSensorError)

        /// Connection times out.
        case timeout

        /// Connection fails after a delay.
        case failAfterDelay(TimeInterval, HeartRateSensorError)

        /// Connection succeeds but disconnects unexpectedly after a delay.
        case disconnectAfterConnecting(TimeInterval)
    }

    /// Records a method call for verification.
    public struct MethodCall: Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date
    }
}

// MARK: - Factory Methods

extension MockHeartRateService {

    /// Creates a mock service configured for successful sensor discovery.
    public static func withDiscoveredSensors(_ count: Int = 3) -> MockHeartRateService {
        let sensors = (0..<count).map { index in
            DiscoveredHeartRateSensor(
                id: UUID(),
                name: "Test Sensor \(index + 1)",
                rssi: -50 - (index * 10)
            )
        }
        return MockHeartRateService(discoveredSensors: sensors)
    }

    /// Creates a mock service that simulates Bluetooth being unavailable.
    public static func withBluetoothUnavailable() -> MockHeartRateService {
        MockHeartRateService(isBluetoothReady: false)
    }

    /// Creates a mock service configured to fail connections.
    public static func withConnectionFailure(_ error: HeartRateSensorError) async -> MockHeartRateService {
        let service = MockHeartRateService()
        await service.setConnectionBehavior(.failWith(error))
        return service
    }
}
