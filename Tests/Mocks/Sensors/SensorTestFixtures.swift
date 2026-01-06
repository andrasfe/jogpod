//
//  SensorTestFixtures.swift
//  JogPodTests
//
//  Provides predefined test data and fixtures for sensor testing.
//  Includes sample heart rate measurements, discovered sensors, and location data.
//

import Foundation
import CoreLocation
@testable import JogPod

// MARK: - SensorTestFixtures

/// Provides predefined test data for sensor-related tests.
///
/// Use these fixtures for consistent, reproducible test data across test suites.
///
/// ## Usage
///
/// ```swift
/// // Get sample heart rate measurements
/// let measurements = SensorTestFixtures.sampleHeartRateMeasurements
///
/// // Get predefined discovered sensors
/// let sensors = SensorTestFixtures.sampleDiscoveredSensors
///
/// // Get sample location data
/// let locations = SensorTestFixtures.sampleRunLocations
/// ```
public enum SensorTestFixtures {

    // MARK: - Heart Rate Measurements

    /// A single resting heart rate measurement.
    public static let restingHeartRate = HeartRateMeasurement(
        heartRate: 65,
        timestamp: Date(),
        sensorContactStatus: .inContact
    )

    /// A measurement during moderate exercise.
    public static let moderateExerciseHeartRate = HeartRateMeasurement(
        heartRate: 145,
        timestamp: Date(),
        sensorContactStatus: .inContact,
        rrIntervals: [0.414]  // ~145 BPM
    )

    /// A measurement during high-intensity exercise.
    public static let highIntensityHeartRate = HeartRateMeasurement(
        heartRate: 175,
        timestamp: Date(),
        sensorContactStatus: .inContact,
        energyExpended: 250,
        rrIntervals: [0.343]  // ~175 BPM
    )

    /// A measurement with no sensor contact.
    public static let noContactMeasurement = HeartRateMeasurement(
        heartRate: 0,
        timestamp: Date(),
        sensorContactStatus: .noContact
    )

    /// An invalid measurement (0 BPM but with contact).
    public static let invalidMeasurement = HeartRateMeasurement(
        heartRate: 0,
        timestamp: Date(),
        sensorContactStatus: .inContact
    )

    /// A series of heart rate measurements simulating a warmup.
    public static var warmupHeartRateSeries: [HeartRateMeasurement] {
        let startTime = Date()
        let heartRates: [UInt16] = [70, 75, 82, 90, 98, 105, 112, 118, 123, 127, 130, 133, 135, 137, 138]

        return heartRates.enumerated().map { index, hr in
            HeartRateMeasurement(
                heartRate: hr,
                timestamp: startTime.addingTimeInterval(TimeInterval(index) * 60),
                sensorContactStatus: .inContact,
                rrIntervals: [60.0 / Double(hr)]
            )
        }
    }

    /// A series simulating a complete workout (warmup, main, cooldown).
    public static var completeWorkoutHeartRateSeries: [HeartRateMeasurement] {
        let startTime = Date()
        var measurements: [HeartRateMeasurement] = []

        // Warmup: 5 minutes, HR 70->130
        for i in 0..<5 {
            let hr = UInt16(70 + (60 * i / 5))
            measurements.append(HeartRateMeasurement(
                heartRate: hr,
                timestamp: startTime.addingTimeInterval(TimeInterval(i) * 60),
                sensorContactStatus: .inContact
            ))
        }

        // Main workout: 20 minutes, HR 145-155
        for i in 5..<25 {
            let variation = Int.random(in: -5...5)
            let hr = UInt16(150 + variation)
            measurements.append(HeartRateMeasurement(
                heartRate: hr,
                timestamp: startTime.addingTimeInterval(TimeInterval(i) * 60),
                sensorContactStatus: .inContact
            ))
        }

        // Cooldown: 5 minutes, HR 150->90
        for i in 25..<30 {
            let progress = Double(i - 25) / 5.0
            let hr = UInt16(150 - Int(60 * progress))
            measurements.append(HeartRateMeasurement(
                heartRate: hr,
                timestamp: startTime.addingTimeInterval(TimeInterval(i) * 60),
                sensorContactStatus: .inContact
            ))
        }

        return measurements
    }

    /// Measurements with variable R-R intervals for HRV testing.
    public static var hrvTestMeasurements: [HeartRateMeasurement] {
        let startTime = Date()
        // R-R intervals with variation to simulate HRV
        let rrSeries: [[TimeInterval]] = [
            [0.85, 0.87],
            [0.82, 0.84],
            [0.88, 0.86],
            [0.80, 0.83],
            [0.86, 0.85],
            [0.84, 0.82],
            [0.87, 0.89],
            [0.83, 0.81],
            [0.85, 0.84],
            [0.86, 0.88]
        ]

        return rrSeries.enumerated().map { index, rrIntervals in
            let avgRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
            let hr = UInt16(60.0 / avgRR)
            return HeartRateMeasurement(
                heartRate: hr,
                timestamp: startTime.addingTimeInterval(TimeInterval(index)),
                sensorContactStatus: .inContact,
                rrIntervals: rrIntervals
            )
        }
    }

    // MARK: - Discovered Sensors

    /// A sample Polar H10 chest strap sensor.
    public static let polarH10Sensor = DiscoveredHeartRateSensor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Polar H10 12345678",
        rssi: -55,
        discoveredAt: Date(),
        lastSeenAt: Date()
    )

    /// A sample Wahoo TICKR sensor.
    public static let wahooTickrSensor = DiscoveredHeartRateSensor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "TICKR X 1234",
        rssi: -62,
        discoveredAt: Date(),
        lastSeenAt: Date()
    )

    /// A sample Garmin HRM-Dual sensor.
    public static let garminHrmSensor = DiscoveredHeartRateSensor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Garmin HRM-Dual",
        rssi: -70,
        discoveredAt: Date(),
        lastSeenAt: Date()
    )

    /// An unknown/generic heart rate sensor.
    public static let unknownSensor = DiscoveredHeartRateSensor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: nil,
        rssi: -80,
        discoveredAt: Date(),
        lastSeenAt: Date()
    )

    /// A sensor with very weak signal.
    public static let weakSignalSensor = DiscoveredHeartRateSensor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Weak Sensor",
        rssi: -95,
        discoveredAt: Date(),
        lastSeenAt: Date()
    )

    /// Collection of sample discovered sensors.
    public static let sampleDiscoveredSensors: [DiscoveredHeartRateSensor] = [
        polarH10Sensor,
        wahooTickrSensor,
        garminHrmSensor,
        unknownSensor
    ]

    /// Sensors sorted by signal strength (strongest first).
    public static var sensorsBySignalStrength: [DiscoveredHeartRateSensor] {
        sampleDiscoveredSensors.sorted()
    }

    // MARK: - Location Data

    /// A stationary location (San Francisco).
    public static let sanFranciscoLocation = CLLocation.makeTestLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 15,
        speed: 0,
        horizontalAccuracy: 10
    )

    /// A location with movement (running pace).
    public static let runningLocation = CLLocation.makeTestLocation(
        latitude: 37.7750,
        longitude: -122.4190,
        altitude: 15,
        speed: 2.8,  // ~6 min/km pace
        course: 45,
        horizontalAccuracy: 10
    )

    /// A location with poor GPS accuracy.
    public static let poorAccuracyLocation = CLLocation.makeTestLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 15,
        speed: 2.5,
        horizontalAccuracy: 100
    )

    /// A series of locations representing a short run.
    public static var sampleRunLocations: [CLLocation] {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 0,
            distance: 500,  // 500m
            pace: 6.0
        )
        return track.generateLocations()
    }

    /// Locations representing a stationary period.
    public static var stationaryLocations: [CLLocation] {
        SimulatedLocationTrack.stationaryLocations(
            at: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            duration: 30,
            interval: 1.0
        )
    }

    /// Locations representing running around a track.
    public static var trackWorkoutLocations: [CLLocation] {
        let track = SimulatedLocationTrack.standardTrack(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            laps: 2,
            pace: 5.0
        )
        return track.generateLocations()
    }

    // MARK: - Combined Workout Data

    /// Returns synchronized heart rate and location data for a simulated workout.
    ///
    /// - Parameter durationMinutes: Workout duration in minutes.
    /// - Returns: Tuple of heart rate measurements and location data.
    public static func synchronizedWorkoutData(
        durationMinutes: Int = 30
    ) -> (heartRates: [HeartRateMeasurement], locations: [CLLocation]) {
        let startTime = Date()
        var heartRates: [HeartRateMeasurement] = []
        var locations: [CLLocation] = []

        let track = SimulatedLocationTrack.centralParkLoop(pace: 6.0)
        let hrSensor = SimulatedHeartRateSensor.completeWorkout(
            warmupMinutes: 5,
            mainHR: 150,
            mainMinutes: Double(durationMinutes - 10),
            cooldownMinutes: 5
        )

        for i in 0..<(durationMinutes * 60) {
            let timestamp = startTime.addingTimeInterval(TimeInterval(i))

            // Generate heart rate
            if var measurement = hrSensor.nextMeasurement() {
                measurement = HeartRateMeasurement(
                    heartRate: measurement.heartRate,
                    timestamp: timestamp,
                    sensorContactStatus: measurement.sensorContactStatus,
                    energyExpended: measurement.energyExpended,
                    rrIntervals: measurement.rrIntervals
                )
                heartRates.append(measurement)
            }

            // Generate location
            if let location = track.nextLocation() {
                let syncedLocation = CLLocation(
                    coordinate: location.coordinate,
                    altitude: location.altitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    verticalAccuracy: location.verticalAccuracy,
                    course: location.course,
                    speed: location.speed,
                    timestamp: timestamp
                )
                locations.append(syncedLocation)
            }
        }

        return (heartRates, locations)
    }

    // MARK: - Error Scenarios

    /// Creates heart rate data with intermittent contact loss.
    public static var heartRateWithContactIssues: [HeartRateMeasurement] {
        let startTime = Date()
        var measurements: [HeartRateMeasurement] = []

        for i in 0..<60 {
            // Lose contact occasionally
            let hasContact = i % 10 != 0

            measurements.append(HeartRateMeasurement(
                heartRate: hasContact ? UInt16(140 + Int.random(in: -5...5)) : 0,
                timestamp: startTime.addingTimeInterval(TimeInterval(i)),
                sensorContactStatus: hasContact ? .inContact : .noContact
            ))
        }

        return measurements
    }

    /// Creates location data with GPS issues (dropouts and poor accuracy).
    public static var locationsWithGPSIssues: [CLLocation] {
        let track = SimulatedLocationTrack.linearTrack(
            start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            bearing: 90,
            distance: 1000,
            pace: 6.0
        )
        return SimulatedLocationTrack.withGPSIssues(baseTrack: track)
    }
}

// MARK: - Raw Bluetooth Data Fixtures

extension SensorTestFixtures {

    /// Sample raw Bluetooth heart rate measurement data packets.
    public enum RawBluetoothData {

        /// 8-bit heart rate, 75 BPM, no flags.
        /// Format: [flags, HR]
        public static let simple8BitHR = Data([0x00, 75])

        /// 16-bit heart rate, 200 BPM.
        /// Format: [flags, HR_low, HR_high]
        public static let simple16BitHR = Data([0x01, 0xC8, 0x00])

        /// 8-bit HR with sensor contact supported and detected.
        /// Flags: 0x06 (contact supported + detected)
        public static let hrWithContact = Data([0x06, 140])

        /// 8-bit HR with sensor contact supported but NOT detected.
        /// Flags: 0x04 (contact supported, not detected)
        public static let hrNoContact = Data([0x04, 0])

        /// 8-bit HR with energy expended field.
        /// Flags: 0x08 (energy present), HR: 150, Energy: 500kJ
        public static let hrWithEnergy = Data([0x08, 150, 0xF4, 0x01])

        /// 8-bit HR with single R-R interval.
        /// Flags: 0x10 (RR present), HR: 70, RR: 832 (0.8125 sec)
        public static let hrWithSingleRR = Data([0x10, 70, 0x40, 0x03])

        /// 8-bit HR with multiple R-R intervals.
        /// Flags: 0x10 (RR present), HR: 72, RR1: 832, RR2: 800
        public static let hrWithMultipleRR = Data([0x10, 72, 0x40, 0x03, 0x20, 0x03])

        /// Full packet with all fields: 16-bit HR, contact, energy, RR.
        /// Flags: 0x1F, HR: 160, Energy: 300kJ, RR: 768
        public static let fullPacket = Data([0x1F, 0xA0, 0x00, 0x2C, 0x01, 0x00, 0x03])

        /// Invalid packet - too short.
        public static let invalidTooShort = Data([0x00])

        /// Invalid packet - empty.
        public static let invalidEmpty = Data()

        /// Invalid packet - truncated energy field.
        public static let invalidTruncatedEnergy = Data([0x08, 150, 0xF4])
    }
}

// MARK: - Test Coordinate Constants

extension SensorTestFixtures {

    /// Common coordinate locations for testing.
    public enum Coordinates {
        /// San Francisco, CA
        public static let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        /// Central Park, NYC
        public static let centralPark = CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654)

        /// Golden Gate Park, SF
        public static let goldenGatePark = CLLocationCoordinate2D(latitude: 37.7694, longitude: -122.4862)

        /// Boston Common
        public static let bostonCommon = CLLocationCoordinate2D(latitude: 42.3551, longitude: -71.0657)

        /// London Hyde Park
        public static let hydePark = CLLocationCoordinate2D(latitude: 51.5073, longitude: -0.1657)

        /// Default test location (San Francisco)
        public static let defaultTest = sanFrancisco
    }
}
