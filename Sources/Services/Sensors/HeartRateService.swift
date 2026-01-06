//
//  HeartRateService.swift
//  JogPod
//
//  Created by JogPod Migration on 2025.
//  Modern Core Bluetooth replacement for WFConnector heart rate functionality.
//

import CoreBluetooth
import Foundation
import Combine

// MARK: - Bluetooth UUIDs

/// Standard Bluetooth GATT UUIDs for Heart Rate Service.
public enum HeartRateServiceUUIDs {
    /// Heart Rate Service UUID (0x180D)
    public static let heartRateService = CBUUID(string: "180D")

    /// Heart Rate Measurement Characteristic UUID (0x2A37)
    public static let heartRateMeasurement = CBUUID(string: "2A37")

    /// Body Sensor Location Characteristic UUID (0x2A38)
    public static let bodySensorLocation = CBUUID(string: "2A38")

    /// Heart Rate Control Point Characteristic UUID (0x2A39)
    public static let heartRateControlPoint = CBUUID(string: "2A39")
}

// MARK: - Connection State

/// Represents the current state of a heart rate sensor connection.
public enum HeartRateSensorConnectionState: Sendable, Equatable {
    /// No sensor is connected or being connected to.
    case disconnected

    /// Scanning for available sensors.
    case scanning

    /// Attempting to connect to a specific sensor.
    case connecting(sensorId: UUID)

    /// Connected and discovering services.
    case discoveringServices(sensorId: UUID)

    /// Fully connected and receiving heart rate data.
    case connected(sensorId: UUID)

    /// Disconnecting from the current sensor.
    case disconnecting(sensorId: UUID)

    /// Whether we are in a connected state (receiving data).
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// Whether a connection attempt is in progress.
    public var isConnecting: Bool {
        switch self {
        case .connecting, .discoveringServices:
            return true
        default:
            return false
        }
    }

    /// The sensor ID if connected or connecting.
    public var sensorId: UUID? {
        switch self {
        case .disconnected, .scanning:
            return nil
        case .connecting(let id), .discoveringServices(let id),
             .connected(let id), .disconnecting(let id):
            return id
        }
    }
}

// MARK: - HeartRateService Protocol

/// Protocol defining the interface for heart rate sensor services.
///
/// This abstraction allows for mock implementations during testing.
public protocol HeartRateServiceProtocol: Actor {
    /// The current connection state.
    var connectionState: HeartRateSensorConnectionState { get }

    /// Publisher for connection state changes.
    var connectionStatePublisher: AnyPublisher<HeartRateSensorConnectionState, Never> { get }

    /// Publisher for heart rate measurements.
    var measurementPublisher: AnyPublisher<HeartRateMeasurement, Never> { get }

    /// The most recent heart rate measurement, if available.
    var lastMeasurement: HeartRateMeasurement? { get }

    /// Starts scanning for nearby heart rate sensors.
    func startScanning() async throws -> AsyncStream<DiscoveredHeartRateSensor>

    /// Stops the current scan.
    func stopScanning() async

    /// Connects to a specific heart rate sensor.
    func connect(to sensorId: UUID) async throws

    /// Disconnects from the currently connected sensor.
    func disconnect() async

    /// Whether Bluetooth is currently available and ready.
    var isBluetoothReady: Bool { get }
}

// MARK: - HeartRateService Implementation

/// Service for discovering and connecting to BLE heart rate sensors.
///
/// This actor-isolated service provides safe concurrent access to Core Bluetooth
/// functionality, replacing the legacy WFConnector framework.
///
/// ## Usage
///
/// ```swift
/// let service = HeartRateService()
///
/// // Wait for Bluetooth to be ready
/// for await state in service.connectionStatePublisher.values {
///     if service.isBluetoothReady {
///         break
///     }
/// }
///
/// // Scan for sensors
/// let sensors = try await service.startScanning()
/// for await sensor in sensors {
///     print("Found: \(sensor.displayName)")
/// }
///
/// // Connect to a sensor
/// try await service.connect(to: selectedSensor.id)
///
/// // Receive heart rate data
/// for await measurement in service.measurementPublisher.values {
///     print("Heart Rate: \(measurement.heartRate) BPM")
/// }
/// ```
public actor HeartRateService: NSObject, HeartRateServiceProtocol {
    // MARK: - Published State

    /// The current connection state.
    public private(set) var connectionState: HeartRateSensorConnectionState = .disconnected

    /// Publisher for connection state changes.
    public nonisolated var connectionStatePublisher: AnyPublisher<HeartRateSensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// Publisher for heart rate measurements.
    public nonisolated var measurementPublisher: AnyPublisher<HeartRateMeasurement, Never> {
        measurementSubject.eraseToAnyPublisher()
    }

    /// The most recent heart rate measurement.
    public private(set) var lastMeasurement: HeartRateMeasurement?

    /// Whether Bluetooth is ready for use.
    public var isBluetoothReady: Bool {
        centralManager?.state == .poweredOn
    }

    // MARK: - Private Properties

    private var centralManager: CBCentralManager?
    private var centralManagerDelegate: CentralManagerDelegate?

    private let connectionStateSubject = CurrentValueSubject<HeartRateSensorConnectionState, Never>(.disconnected)
    private let measurementSubject = PassthroughSubject<HeartRateMeasurement, Never>()

    private var discoveredSensors: [UUID: DiscoveredHeartRateSensor] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var peripheralDelegate: PeripheralDelegate?

    private var scanContinuation: AsyncStream<DiscoveredHeartRateSensor>.Continuation?
    private var connectContinuation: CheckedContinuation<Void, Error>?

    private var connectionTimeoutTask: Task<Void, Never>?
    private var scanTimeoutTask: Task<Void, Never>?

    // MARK: - Configuration

    /// Default timeout for connection attempts.
    private let connectionTimeout: TimeInterval = 15.0

    /// Default timeout for scanning.
    private let scanTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    public override init() {
        super.init()
        Task { await setupCentralManager() }
    }

    private func setupCentralManager() {
        let delegate = CentralManagerDelegate(service: self)
        self.centralManagerDelegate = delegate
        self.centralManager = CBCentralManager(
            delegate: delegate,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    // MARK: - Scanning

    /// Starts scanning for nearby heart rate sensors.
    ///
    /// - Returns: An async stream of discovered sensors.
    /// - Throws: `HeartRateSensorError` if Bluetooth is not ready or scanning is already in progress.
    public func startScanning() async throws -> AsyncStream<DiscoveredHeartRateSensor> {
        guard let centralManager else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        // Check Bluetooth state
        try checkBluetoothState()

        // Check if already scanning
        if case .scanning = connectionState {
            throw HeartRateSensorError.scanAlreadyInProgress
        }

        // Clear previous discoveries
        discoveredSensors.removeAll()
        updateConnectionState(.scanning)

        // Create the async stream
        let stream = AsyncStream<DiscoveredHeartRateSensor> { continuation in
            self.scanContinuation = continuation

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.handleScanTermination()
                }
            }
        }

        // Start scanning for Heart Rate Service
        centralManager.scanForPeripherals(
            withServices: [HeartRateServiceUUIDs.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        // Set up scan timeout
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(scanTimeout * 1_000_000_000))
            await self?.handleScanTimeout()
        }

        return stream
    }

    /// Stops the current scan.
    public func stopScanning() async {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil

        centralManager?.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil

        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }
    }

    private func handleScanTermination() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        centralManager?.stopScan()
        scanContinuation = nil

        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }
    }

    private func handleScanTimeout() {
        if case .scanning = connectionState {
            stopScanningSync()
        }
    }

    private func stopScanningSync() {
        centralManager?.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil

        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }
    }

    // MARK: - Connection

    /// Connects to a specific heart rate sensor.
    ///
    /// - Parameter sensorId: The UUID of the sensor to connect to.
    /// - Throws: `HeartRateSensorError` if connection fails.
    public func connect(to sensorId: UUID) async throws {
        guard let centralManager else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        try checkBluetoothState()

        // Check if already connected
        if case .connected(let connectedId) = connectionState, connectedId == sensorId {
            throw HeartRateSensorError.alreadyConnected(peripheralIdentifier: sensorId)
        }

        // Disconnect from any current sensor
        if connectedPeripheral != nil {
            await disconnect()
        }

        // Stop scanning if in progress
        await stopScanning()

        // Retrieve the peripheral
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [sensorId])
        guard let peripheral = peripherals.first else {
            // Try to find in discovered sensors - need to re-scan
            throw HeartRateSensorError.connectionFailed(
                peripheralIdentifier: sensorId,
                underlyingError: "Peripheral not found. Please scan again."
            )
        }

        // Set up peripheral delegate
        let delegate = PeripheralDelegate(service: self)
        self.peripheralDelegate = delegate
        peripheral.delegate = delegate

        connectedPeripheral = peripheral
        updateConnectionState(.connecting(sensorId: sensorId))

        // Perform connection with timeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation

            // Start timeout
            self.connectionTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.connectionTimeout ?? 15.0) * 1_000_000_000)
                await self?.handleConnectionTimeout(sensorId: sensorId)
            }

            centralManager.connect(peripheral, options: nil)
        }
    }

    /// Disconnects from the currently connected sensor.
    public func disconnect() async {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil

        guard let peripheral = connectedPeripheral, let centralManager else {
            updateConnectionState(.disconnected)
            return
        }

        updateConnectionState(.disconnecting(sensorId: peripheral.identifier))
        centralManager.cancelPeripheralConnection(peripheral)

        // Clean up
        connectedPeripheral = nil
        peripheralDelegate = nil
        lastMeasurement = nil

        updateConnectionState(.disconnected)
    }

    private func handleConnectionTimeout(sensorId: UUID) {
        guard case .connecting = connectionState else { return }

        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }

        connectedPeripheral = nil
        peripheralDelegate = nil

        let error = HeartRateSensorError.connectionTimeout(peripheralIdentifier: sensorId)
        connectContinuation?.resume(throwing: error)
        connectContinuation = nil

        updateConnectionState(.disconnected)
    }

    // MARK: - Bluetooth State

    private func checkBluetoothState() throws {
        guard let state = centralManager?.state else {
            throw HeartRateSensorError.bluetoothNotReady
        }

        switch state {
        case .poweredOn:
            return
        case .poweredOff:
            throw HeartRateSensorError.bluetoothPoweredOff
        case .unauthorized:
            throw HeartRateSensorError.bluetoothUnauthorized
        case .unsupported:
            throw HeartRateSensorError.bluetoothUnavailable
        case .unknown, .resetting:
            throw HeartRateSensorError.bluetoothNotReady
        @unknown default:
            throw HeartRateSensorError.bluetoothNotReady
        }
    }

    // MARK: - State Updates

    private func updateConnectionState(_ newState: HeartRateSensorConnectionState) {
        connectionState = newState
        connectionStateSubject.send(newState)
    }

    // MARK: - Internal Callbacks

    func handleCentralManagerStateUpdate(_ state: CBManagerState) {
        // If Bluetooth turns off while connected, clean up
        if state != .poweredOn {
            if connectedPeripheral != nil {
                Task { await disconnect() }
            }
            if case .scanning = connectionState {
                Task { await stopScanning() }
            }
        }
    }

    func handleDiscoveredPeripheral(_ peripheral: CBPeripheral, rssi: NSNumber) {
        let sensor = DiscoveredHeartRateSensor(
            id: peripheral.identifier,
            name: peripheral.name,
            rssi: rssi.intValue
        )

        discoveredSensors[sensor.id] = sensor
        scanContinuation?.yield(sensor)
    }

    func handlePeripheralConnected(_ peripheral: CBPeripheral) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil

        updateConnectionState(.discoveringServices(sensorId: peripheral.identifier))
        peripheral.discoverServices([HeartRateServiceUUIDs.heartRateService])
    }

    func handlePeripheralDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil

        let wasConnecting = connectContinuation != nil

        if wasConnecting {
            let sensorError = HeartRateSensorError.connectionFailed(
                peripheralIdentifier: peripheral.identifier,
                underlyingError: error?.localizedDescription
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
        }

        connectedPeripheral = nil
        peripheralDelegate = nil
        lastMeasurement = nil

        updateConnectionState(.disconnected)
    }

    func handleServicesDiscovered(_ peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            let sensorError = HeartRateSensorError.heartRateServiceNotFound(
                peripheralIdentifier: peripheral.identifier
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
            Task { await disconnect() }
            return
        }

        guard let services = peripheral.services,
              let hrService = services.first(where: { $0.uuid == HeartRateServiceUUIDs.heartRateService }) else {
            let sensorError = HeartRateSensorError.heartRateServiceNotFound(
                peripheralIdentifier: peripheral.identifier
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
            Task { await disconnect() }
            return
        }

        peripheral.discoverCharacteristics(
            [HeartRateServiceUUIDs.heartRateMeasurement, HeartRateServiceUUIDs.bodySensorLocation],
            for: hrService
        )
    }

    func handleCharacteristicsDiscovered(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        guard error == nil else {
            let sensorError = HeartRateSensorError.heartRateMeasurementCharacteristicNotFound(
                peripheralIdentifier: peripheral.identifier
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
            Task { await disconnect() }
            return
        }

        guard let characteristics = service.characteristics,
              let hrMeasurement = characteristics.first(where: { $0.uuid == HeartRateServiceUUIDs.heartRateMeasurement }) else {
            let sensorError = HeartRateSensorError.heartRateMeasurementCharacteristicNotFound(
                peripheralIdentifier: peripheral.identifier
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
            Task { await disconnect() }
            return
        }

        // Enable notifications
        peripheral.setNotifyValue(true, for: hrMeasurement)
    }

    func handleNotificationStateChanged(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == HeartRateServiceUUIDs.heartRateMeasurement else { return }

        if let error {
            let sensorError = HeartRateSensorError.notificationEnableFailed(
                peripheralIdentifier: peripheral.identifier,
                underlyingError: error.localizedDescription
            )
            connectContinuation?.resume(throwing: sensorError)
            connectContinuation = nil
            Task { await disconnect() }
            return
        }

        // Successfully subscribed to notifications
        updateConnectionState(.connected(sensorId: peripheral.identifier))
        connectContinuation?.resume()
        connectContinuation = nil
    }

    func handleHeartRateData(_ data: Data) {
        guard let measurement = parseHeartRateMeasurement(data) else {
            return
        }

        lastMeasurement = measurement
        measurementSubject.send(measurement)
    }

    // MARK: - Data Parsing

    /// Parses raw heart rate measurement data according to Bluetooth HRS specification.
    private func parseHeartRateMeasurement(_ data: Data) -> HeartRateMeasurement? {
        guard data.count >= 2 else { return nil }

        let flags = data[0]

        // Bit 0: Heart Rate Value Format
        // 0 = UINT8, 1 = UINT16
        let isHeartRate16Bit = (flags & 0x01) != 0

        // Bits 1-2: Sensor Contact Status
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

        // Bit 3: Energy Expended Present
        let energyExpendedPresent = (flags & 0x08) != 0

        // Bit 4: RR-Interval Present
        let rrIntervalsPresent = (flags & 0x10) != 0

        var offset = 1

        // Parse heart rate value
        let heartRate: UInt16
        if isHeartRate16Bit {
            guard data.count >= offset + 2 else { return nil }
            heartRate = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
        } else {
            heartRate = UInt16(data[offset])
            offset += 1
        }

        // Parse energy expended
        var energyExpended: UInt16?
        if energyExpendedPresent {
            guard data.count >= offset + 2 else { return nil }
            energyExpended = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            offset += 2
        }

        // Parse R-R intervals
        var rrIntervals: [TimeInterval] = []
        if rrIntervalsPresent {
            while offset + 1 < data.count {
                let rawRR = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                // R-R interval is in 1/1024 second units
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

// MARK: - Central Manager Delegate

private final class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    weak var service: HeartRateService?

    init(service: HeartRateService) {
        self.service = service
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { [weak service] in
            await service?.handleCentralManagerStateUpdate(central.state)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { [weak service] in
            await service?.handleDiscoveredPeripheral(peripheral, rssi: RSSI)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { [weak service] in
            await service?.handlePeripheralConnected(peripheral)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { [weak service] in
            await service?.handlePeripheralDisconnected(peripheral, error: error)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { [weak service] in
            await service?.handlePeripheralDisconnected(peripheral, error: error)
        }
    }
}

// MARK: - Peripheral Delegate

private final class PeripheralDelegate: NSObject, CBPeripheralDelegate, @unchecked Sendable {
    weak var service: HeartRateService?

    init(service: HeartRateService) {
        self.service = service
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { [weak service] in
            await service?.handleServicesDiscovered(peripheral, error: error)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { [weak self] in
            await self?.service?.handleCharacteristicsDiscovered(peripheral, service: service, error: error)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { [weak service] in
            await service?.handleNotificationStateChanged(peripheral, characteristic: characteristic, error: error)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == HeartRateServiceUUIDs.heartRateMeasurement,
              let data = characteristic.value else {
            return
        }

        Task { [weak service] in
            await service?.handleHeartRateData(data)
        }
    }
}
