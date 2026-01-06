//
//  SensorMockInfrastructureTests.swift
//  JogPodTests
//
//  Tests for the sensor mocking infrastructure.
//  Verifies that mocks behave correctly and can be used for testing sensor-dependent code.
//

import Testing
import Foundation
import CoreLocation
import Combine
@testable import JogPod

// MARK: - MockHeartRateService Tests

@Suite("MockHeartRateService")
struct MockHeartRateServiceTests {

    // MARK: - Initialization

    @Test("initializes with default values")
    func initializesWithDefaults() async {
        let service = MockHeartRateService()

        let state = await service.connectionState
        #expect(state == .disconnected)

        let isReady = await service.isBluetoothReady
        #expect(isReady == true)

        let measurement = await service.lastMeasurement
        #expect(measurement == nil)
    }

    @Test("initializes with custom Bluetooth state")
    func initializesWithCustomBluetoothState() async {
        let service = MockHeartRateService(isBluetoothReady: false)

        let isReady = await service.isBluetoothReady
        #expect(isReady == false)
    }

    @Test("initializes with discovered sensors")
    func initializesWithDiscoveredSensors() async {
        let sensors = [
            DiscoveredHeartRateSensor(id: UUID(), name: "Sensor 1", rssi: -60),
            DiscoveredHeartRateSensor(id: UUID(), name: "Sensor 2", rssi: -70)
        ]

        let service = MockHeartRateService(discoveredSensors: sensors)

        // Verify sensors are returned during scanning
        do {
            let stream = try await service.startScanning()
            var foundSensors: [DiscoveredHeartRateSensor] = []

            for await sensor in stream {
                foundSensors.append(sensor)
            }

            #expect(foundSensors.count == 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Scanning

    @Test("scanning fails when Bluetooth is not ready")
    func scanningFailsWhenBluetoothNotReady() async {
        let service = MockHeartRateService(isBluetoothReady: false)

        do {
            _ = try await service.startScanning()
            Issue.record("Expected error to be thrown")
        } catch let error as HeartRateSensorError {
            #expect(error == .bluetoothNotReady)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("scanning returns configured sensors")
    func scanningReturnsConfiguredSensors() async throws {
        let service = MockHeartRateService()
        await service.setDiscoveredSensors(SensorTestFixtures.sampleDiscoveredSensors)

        let stream = try await service.startScanning()
        var foundSensors: [DiscoveredHeartRateSensor] = []

        for await sensor in stream {
            foundSensors.append(sensor)
        }

        #expect(foundSensors.count == 4)
    }

    @Test("stop scanning updates state")
    func stopScanningUpdatesState() async throws {
        let service = MockHeartRateService()
        _ = try await service.startScanning()

        let scanningState = await service.connectionState
        #expect(scanningState == .scanning)

        await service.stopScanning()

        let stoppedState = await service.connectionState
        #expect(stoppedState == .disconnected)
    }

    // MARK: - Connection

    @Test("connection succeeds by default")
    func connectionSucceedsByDefault() async throws {
        let service = MockHeartRateService()
        let sensorId = UUID()

        try await service.connect(to: sensorId)

        let state = await service.connectionState
        #expect(state == .connected(sensorId: sensorId))
    }

    @Test("connection fails with configured error")
    func connectionFailsWithConfiguredError() async {
        let service = MockHeartRateService()
        let sensorId = UUID()
        let expectedError = HeartRateSensorError.connectionFailed(
            peripheralIdentifier: sensorId,
            underlyingError: "Test failure"
        )

        await service.setConnectionBehavior(.failWith(expectedError))

        do {
            try await service.connect(to: sensorId)
            Issue.record("Expected error to be thrown")
        } catch let error as HeartRateSensorError {
            if case .connectionFailed = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("connection times out when configured")
    func connectionTimesOutWhenConfigured() async {
        let service = MockHeartRateService()
        let sensorId = UUID()

        await service.setConnectionBehavior(.timeout)

        do {
            try await service.connect(to: sensorId)
            Issue.record("Expected error to be thrown")
        } catch let error as HeartRateSensorError {
            if case .connectionTimeout = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("disconnect updates state")
    func disconnectUpdatesState() async throws {
        let service = MockHeartRateService()
        let sensorId = UUID()

        try await service.connect(to: sensorId)
        await service.disconnect()

        let state = await service.connectionState
        #expect(state == .disconnected)
    }

    // MARK: - Measurement Simulation

    @Test("simulateMeasurement updates lastMeasurement")
    func simulateMeasurementUpdatesLastMeasurement() async {
        let service = MockHeartRateService()
        let measurement = HeartRateMeasurement(heartRate: 145)

        await service.simulateMeasurement(measurement)

        let lastMeasurement = await service.lastMeasurement
        #expect(lastMeasurement?.heartRate == 145)
    }

    // MARK: - Call Tracking

    @Test("tracks method calls")
    func tracksMethodCalls() async throws {
        let service = MockHeartRateService()
        let sensorId = UUID()

        _ = try? await service.startScanning()
        await service.stopScanning()
        try await service.connect(to: sensorId)
        await service.disconnect()

        #expect(await service.callCount(for: "startScanning") == 1)
        #expect(await service.callCount(for: "stopScanning") == 2)  // Also called during connect
        #expect(await service.callCount(for: "connect") == 1)
        #expect(await service.callCount(for: "disconnect") == 1)
    }

    @Test("reset clears call tracking")
    func resetClearsCallTracking() async throws {
        let service = MockHeartRateService()

        _ = try await service.startScanning()
        #expect(await service.callCount(for: "startScanning") == 1)

        await service.resetCallTracking()
        #expect(await service.callCount(for: "startScanning") == 0)
    }
}

// MARK: - SimulatedHeartRateSensor Tests

@Suite("SimulatedHeartRateSensor")
struct SimulatedHeartRateSensorTests {

    // MARK: - Basic Generation

    @Test("generates valid measurements")
    func generatesValidMeasurements() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 120)
        )

        let measurement = await sensor.nextMeasurement()

        #expect(measurement != nil)
        #expect(measurement!.heartRate > 0)
        #expect(measurement!.sensorContactStatus == .inContact)
    }

    @Test("generates measurements within expected range")
    func generatesMeasurementsWithinExpectedRange() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 150),
            variationFactor: 0.05
        )

        // Generate multiple measurements and check they're in range
        for _ in 0..<100 {
            if let measurement = await sensor.nextMeasurement() {
                #expect(measurement.heartRate >= 140)
                #expect(measurement.heartRate <= 160)
            }
        }
    }

    // MARK: - Profile Tests

    @Test("constant profile maintains target HR")
    func constantProfileMaintainsTargetHR() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 130),
            variationFactor: 0.0  // No variation for precise testing
        )

        // Skip a few measurements for the value to stabilize
        for _ in 0..<10 {
            _ = await sensor.nextMeasurement()
        }

        let measurement = await sensor.nextMeasurement()
        #expect(measurement?.heartRate == 130)
    }

    @Test("warmup profile increases HR over time")
    func warmupProfileIncreasesHR() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .warmup(targetHR: 150, duration: 300),
            baseHeartRate: 70,
            variationFactor: 0.0
        )

        var firstHR: UInt16 = 0
        var lastHR: UInt16 = 0

        // First measurement
        if let measurement = await sensor.nextMeasurement() {
            firstHR = measurement.heartRate
        }

        // Skip ahead 100 seconds (100 measurements)
        for _ in 0..<100 {
            if let measurement = await sensor.nextMeasurement() {
                lastHR = measurement.heartRate
            }
        }

        #expect(lastHR > firstHR)
    }

    @Test("interval profile alternates between high and low HR")
    func intervalProfileAlternates() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .intervals(
                highHR: 170,
                lowHR: 120,
                highDuration: 30,
                lowDuration: 30
            ),
            variationFactor: 0.0
        )

        var seenHigh = false
        var seenLow = false

        // Generate enough measurements to cover a full cycle
        for _ in 0..<70 {
            if let measurement = await sensor.nextMeasurement() {
                if measurement.heartRate >= 160 {
                    seenHigh = true
                }
                if measurement.heartRate <= 130 {
                    seenLow = true
                }
            }
        }

        #expect(seenHigh)
        #expect(seenLow)
    }

    // MARK: - R-R Intervals

    @Test("generates R-R intervals when enabled")
    func generatesRRIntervalsWhenEnabled() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 120),
            includeRRIntervals: true
        )

        var hasRRIntervals = false
        for _ in 0..<10 {
            if let measurement = await sensor.nextMeasurement() {
                if !measurement.rrIntervals.isEmpty {
                    hasRRIntervals = true
                    break
                }
            }
        }

        #expect(hasRRIntervals)
    }

    @Test("R-R intervals match heart rate")
    func rrIntervalsMatchHeartRate() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 60),  // 60 BPM = 1.0 second R-R
            includeRRIntervals: true,
            variationFactor: 0.0
        )

        // Wait for sensor to stabilize
        for _ in 0..<20 {
            _ = await sensor.nextMeasurement()
        }

        if let measurement = await sensor.nextMeasurement(),
           let rrInterval = measurement.rrIntervals.first {
            // At 60 BPM, R-R should be close to 1.0 second
            #expect(rrInterval > 0.9)
            #expect(rrInterval < 1.1)
        }
    }

    // MARK: - Contact Status

    @Test("reports no contact when configured")
    func reportsNoContactWhenConfigured() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 120),
            contactStatus: .noContact
        )

        let measurement = await sensor.nextMeasurement()

        #expect(measurement?.sensorContactStatus == .noContact)
        #expect(measurement?.heartRate == 0)
    }

    // MARK: - Batch Generation

    @Test("generateMeasurements returns requested count")
    func generateMeasurementsReturnsRequestedCount() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .constant(heartRate: 140)
        )

        let measurements = await sensor.generateMeasurements(count: 100)

        #expect(measurements.count == 100)
    }

    // MARK: - Preset Factory Methods

    @Test("steadyStateRun factory creates valid sensor")
    func steadyStateRunFactoryCreatesValidSensor() async {
        let sensor = SimulatedHeartRateSensor.steadyStateRun(targetHR: 155)

        let measurements = await sensor.generateMeasurements(count: 30)

        // Verify measurements are around target
        let avgHR = measurements.map { Int($0.heartRate) }.reduce(0, +) / measurements.count
        #expect(avgHR > 145)
        #expect(avgHR < 165)
    }

    @Test("hiitWorkout factory creates interval pattern")
    func hiitWorkoutFactoryCreatesIntervalPattern() async {
        let sensor = SimulatedHeartRateSensor.hiitWorkout(
            workInterval: 10,
            restInterval: 10
        )

        // Generate measurements covering multiple intervals
        let measurements = await sensor.generateMeasurements(count: 50)

        // Should have both high and low values
        let hrValues = measurements.map { $0.heartRate }
        let maxHR = hrValues.max() ?? 0
        let minHR = hrValues.min() ?? 0

        #expect(maxHR - minHR > 30)  // Should have significant variation
    }

    // MARK: - Reset

    @Test("reset starts simulation over")
    func resetStartsSimulationOver() async {
        let sensor = SimulatedHeartRateSensor(
            profile: .warmup(targetHR: 170, duration: 600),
            baseHeartRate: 60,
            variationFactor: 0.0
        )

        // Advance to middle of warmup
        for _ in 0..<300 {
            _ = await sensor.nextMeasurement()
        }

        let midWarmupHR = await sensor.nextMeasurement()?.heartRate ?? 0

        // Reset
        await sensor.reset()

        // First measurement after reset should be near base HR
        let afterResetHR = await sensor.nextMeasurement()?.heartRate ?? 0

        #expect(afterResetHR < midWarmupHR)
    }
}

// MARK: - SimulatedLocationTrack Tests

@Suite("SimulatedLocationTrack")
struct SimulatedLocationTrackTests {

    // MARK: - Basic Generation

    @Test("generates locations from waypoints")
    func generatesLocationsFromWaypoints() {
        let waypoints = [
            SimulatedLocationTrack.TrackWaypoint(latitude: 37.7749, longitude: -122.4194),
            SimulatedLocationTrack.TrackWaypoint(latitude: 37.7759, longitude: -122.4194),
            SimulatedLocationTrack.TrackWaypoint(latitude: 37.7769, longitude: -122.4194)
        ]

        let track = SimulatedLocationTrack(waypoints: waypoints)
        let locations = track.generateLocations()

        #expect(locations.count > 0)
    }

    @Test("locations have valid coordinates")
    func locationsHaveValidCoordinates() {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 0,
            distance: 500,
            pace: 6.0
        )

        let locations = track.generateLocations()

        for location in locations {
            #expect(location.coordinate.latitude >= -90)
            #expect(location.coordinate.latitude <= 90)
            #expect(location.coordinate.longitude >= -180)
            #expect(location.coordinate.longitude <= 180)
        }
    }

    @Test("locations have valid speed values")
    func locationsHaveValidSpeedValues() {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 90,
            distance: 500,
            pace: 6.0  // 6 min/km = ~2.78 m/s
        )

        let locations = track.generateLocations()

        for location in locations {
            // Speed should be roughly around target pace with some variation
            #expect(location.speed >= 0)
            #expect(location.speed < 10)  // Reasonable max for running
        }
    }

    // MARK: - Factory Methods

    @Test("linearTrack creates expected distance")
    func linearTrackCreatesExpectedDistance() {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 0,
            distance: 1000,
            pace: 6.0
        )

        let totalDistance = track.calculateTotalDistance()

        // Allow 10% tolerance for rounding
        #expect(totalDistance > 900)
        #expect(totalDistance < 1100)
    }

    @Test("rectangularLoop is closed")
    func rectangularLoopIsClosed() {
        let track = SimulatedLocationTrack.rectangularLoop(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            width: 200,
            height: 100,
            pace: 6.0
        )

        let locations = track.generateLocations()

        guard let first = locations.first, let last = locations.last else {
            Issue.record("No locations generated")
            return
        }

        // First and last should be close (within GPS accuracy)
        let distance = first.distance(from: last)
        #expect(distance < 50)
    }

    @Test("circularLoop creates expected number of points")
    func circularLoopCreatesExpectedNumberOfPoints() {
        let track = SimulatedLocationTrack.circularLoop(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 100,
            pace: 6.0,
            pointCount: 24
        )

        // Should have generated many location updates
        let locations = track.generateLocations()
        #expect(locations.count > 0)
    }

    // MARK: - Predefined Routes

    @Test("centralParkLoop has waypoints")
    func centralParkLoopHasWaypoints() {
        let track = SimulatedLocationTrack.centralParkLoop()
        let locations = track.generateLocations()

        // Central Park loop is about 6 miles, should generate many points
        #expect(locations.count > 100)
    }

    @Test("standardTrack generates correct number of laps")
    func standardTrackGeneratesCorrectNumberOfLaps() {
        let track = SimulatedLocationTrack.standardTrack(
            laps: 4,
            pace: 5.0
        )

        // 400m track, 4 laps = 1600m total
        let totalDistance = track.calculateTotalDistance()
        #expect(totalDistance > 1400)
        #expect(totalDistance < 1800)
    }

    // MARK: - GPS Issues Simulation

    @Test("withGPSIssues drops some locations")
    func withGPSIssuesDropsSomeLocations() {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 0,
            distance: 500,
            pace: 6.0
        )

        let normalLocations = track.generateLocations()
        track.reset()
        let issueLocations = SimulatedLocationTrack.withGPSIssues(
            baseTrack: track,
            dropoutProbability: 0.1
        )

        // With 10% dropout, we should have fewer locations
        #expect(issueLocations.count <= normalLocations.count)
    }

    @Test("stationaryLocations have zero speed")
    func stationaryLocationsHaveZeroSpeed() {
        let locations = SimulatedLocationTrack.stationaryLocations(
            at: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            duration: 10,
            interval: 1.0
        )

        #expect(locations.count == 10)

        for location in locations {
            #expect(location.speed == 0)
        }
    }

    // MARK: - Reset

    @Test("reset allows regenerating track")
    func resetAllowsRegeneratingTrack() {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 0,
            distance: 500,
            pace: 6.0
        )

        let firstRun = track.generateLocations()
        let secondRun = track.generateLocations()

        // Both runs should have same count
        #expect(firstRun.count == secondRun.count)
    }
}

// MARK: - SensorTestFixtures Tests

@Suite("SensorTestFixtures")
struct SensorTestFixturesTests {

    // MARK: - Heart Rate Fixtures

    @Test("sample heart rate measurements are valid")
    func sampleHeartRateMeasurementsAreValid() {
        #expect(SensorTestFixtures.restingHeartRate.heartRate == 65)
        #expect(SensorTestFixtures.moderateExerciseHeartRate.heartRate == 145)
        #expect(SensorTestFixtures.highIntensityHeartRate.heartRate == 175)
    }

    @Test("warmup series has increasing heart rates")
    func warmupSeriesHasIncreasingHeartRates() {
        let series = SensorTestFixtures.warmupHeartRateSeries

        #expect(series.count > 0)

        for i in 1..<series.count {
            #expect(series[i].heartRate >= series[i-1].heartRate)
        }
    }

    @Test("complete workout series has all phases")
    func completeWorkoutSeriesHasAllPhases() {
        let series = SensorTestFixtures.completeWorkoutHeartRateSeries

        // Should have 30 measurements (30 minutes)
        #expect(series.count == 30)

        // First should be near resting
        #expect(series.first!.heartRate < 100)

        // Middle should be elevated
        #expect(series[15].heartRate > 140)
    }

    // MARK: - Discovered Sensor Fixtures

    @Test("sample sensors have expected types")
    func sampleSensorsHaveExpectedTypes() {
        #expect(SensorTestFixtures.polarH10Sensor.sensorType == .chestStrap)
        #expect(SensorTestFixtures.wahooTickrSensor.sensorType == .chestStrap)
        #expect(SensorTestFixtures.garminHrmSensor.sensorType == .chestStrap)
        #expect(SensorTestFixtures.unknownSensor.sensorType == .unknown)
    }

    @Test("sensors sorted by signal strength")
    func sensorsSortedBySignalStrength() {
        let sorted = SensorTestFixtures.sensorsBySignalStrength

        for i in 1..<sorted.count {
            // Higher RSSI = stronger signal, should come first
            #expect(sorted[i-1].rssi >= sorted[i].rssi)
        }
    }

    // MARK: - Location Fixtures

    @Test("sample run locations have valid count")
    func sampleRunLocationsHaveValidCount() {
        let locations = SensorTestFixtures.sampleRunLocations
        #expect(locations.count > 0)
    }

    @Test("track workout locations cover expected distance")
    func trackWorkoutLocationsCoverExpectedDistance() {
        let locations = SensorTestFixtures.trackWorkoutLocations

        // Calculate total distance
        var totalDistance: Double = 0
        for i in 1..<locations.count {
            totalDistance += locations[i].distance(from: locations[i-1])
        }

        // 2 laps around 400m track = ~800m
        #expect(totalDistance > 700)
        #expect(totalDistance < 1000)
    }

    // MARK: - Synchronized Data

    @Test("synchronized workout data has matching timestamps")
    func synchronizedWorkoutDataHasMatchingTimestamps() {
        let (heartRates, locations) = SensorTestFixtures.synchronizedWorkoutData(durationMinutes: 5)

        // Should have data for roughly the same duration
        #expect(heartRates.count > 200)
        #expect(locations.count > 200)

        // Timestamps should start at same time
        if let hrStart = heartRates.first?.timestamp,
           let locStart = locations.first?.timestamp {
            let timeDiff = abs(hrStart.timeIntervalSince(locStart))
            #expect(timeDiff < 1.0)
        }
    }

    // MARK: - Raw Bluetooth Data

    @Test("raw bluetooth data fixtures are valid")
    func rawBluetoothDataFixturesAreValid() {
        #expect(SensorTestFixtures.RawBluetoothData.simple8BitHR.count == 2)
        #expect(SensorTestFixtures.RawBluetoothData.simple16BitHR.count == 3)
        #expect(SensorTestFixtures.RawBluetoothData.fullPacket.count == 7)
        #expect(SensorTestFixtures.RawBluetoothData.invalidEmpty.count == 0)
    }
}
