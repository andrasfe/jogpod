//
//  SimulatedLocationTrack.swift
//  JogPodTests
//
//  Generates realistic GPS location data for testing workout tracking scenarios.
//  Provides predefined routes and utilities for creating custom location sequences.
//

import Foundation
import CoreLocation
@testable import JogPod

// MARK: - SimulatedLocationTrack

/// Generates realistic GPS location data for testing workout tracking.
///
/// This class provides methods for creating location sequences that simulate
/// real-world running routes, including realistic speed variations, GPS drift,
/// and accuracy fluctuations.
///
/// ## Usage
///
/// ```swift
/// // Create a simple linear track
/// let track = SimulatedLocationTrack.linearTrack(
///     start: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
///     bearing: 45,
///     distance: 5000,  // 5km
///     pace: 6.0  // 6 min/km
/// )
///
/// // Generate locations
/// let locations = track.generateLocations()
///
/// // Use predefined routes
/// let centralParkLoop = SimulatedLocationTrack.centralParkLoop()
/// ```
public final class SimulatedLocationTrack: @unchecked Sendable {

    // MARK: - Configuration

    /// The waypoints defining the route.
    private let waypoints: [TrackWaypoint]

    /// Target pace in minutes per kilometer.
    private let targetPace: Double

    /// GPS accuracy to simulate (in meters).
    private let horizontalAccuracy: Double

    /// Amount of random variation to add (0.0 = none, 1.0 = high).
    private let variationFactor: Double

    /// Update interval between locations (in seconds).
    private let updateInterval: TimeInterval

    /// Whether to loop back to the start.
    private let isLoop: Bool

    // MARK: - State

    private var currentIndex: Int = 0
    private var currentProgress: Double = 0  // Progress between waypoints (0-1)
    private var elapsedTime: TimeInterval = 0
    private var totalDistance: Double = 0

    // MARK: - Initialization

    /// Creates a simulated location track with specified waypoints.
    ///
    /// - Parameters:
    ///   - waypoints: The waypoints defining the route.
    ///   - targetPace: Target pace in minutes per kilometer.
    ///   - horizontalAccuracy: Simulated GPS accuracy in meters.
    ///   - variationFactor: Random variation amount (0.0-1.0).
    ///   - updateInterval: Time between location updates.
    ///   - isLoop: Whether the track loops back to the start.
    public init(
        waypoints: [TrackWaypoint],
        targetPace: Double = 6.0,
        horizontalAccuracy: Double = 10.0,
        variationFactor: Double = 0.02,
        updateInterval: TimeInterval = 1.0,
        isLoop: Bool = false
    ) {
        self.waypoints = waypoints
        self.targetPace = targetPace
        self.horizontalAccuracy = horizontalAccuracy
        self.variationFactor = variationFactor
        self.updateInterval = updateInterval
        self.isLoop = isLoop
    }

    /// Creates a track from simple coordinate pairs.
    public convenience init(
        coordinates: [CLLocationCoordinate2D],
        targetPace: Double = 6.0,
        horizontalAccuracy: Double = 10.0
    ) {
        let waypoints = coordinates.enumerated().map { index, coord in
            TrackWaypoint(
                coordinate: coord,
                name: "Point \(index + 1)"
            )
        }
        self.init(waypoints: waypoints, targetPace: targetPace, horizontalAccuracy: horizontalAccuracy)
    }

    // MARK: - Location Generation

    /// Generates the next location in the track.
    ///
    /// - Returns: The next CLLocation, or nil if the track is complete.
    public func nextLocation() -> CLLocation? {
        guard !waypoints.isEmpty else { return nil }
        guard currentIndex < waypoints.count - 1 || isLoop else { return nil }

        let currentWaypoint = waypoints[currentIndex]
        let nextIndex = (currentIndex + 1) % waypoints.count
        let nextWaypoint = waypoints[nextIndex]

        // Calculate base position by interpolating between waypoints
        let coordinate = interpolateCoordinate(
            from: currentWaypoint.coordinate,
            to: nextWaypoint.coordinate,
            progress: currentProgress
        )

        // Add GPS variation
        let variedCoordinate = addVariation(to: coordinate)

        // Calculate current speed (m/s)
        // pace (min/km) -> speed (m/s) = 1000 / (pace * 60)
        let baseSpeed = 1000.0 / (targetPace * 60.0)
        let speedVariation = baseSpeed * 0.1 * Double.random(in: -1...1)
        let currentSpeed = max(0, baseSpeed + speedVariation)

        // Calculate bearing
        let bearing = calculateBearing(
            from: currentWaypoint.coordinate,
            to: nextWaypoint.coordinate
        )

        // Calculate distance traveled in this step
        let distanceThisStep = currentSpeed * updateInterval
        totalDistance += distanceThisStep

        // Calculate altitude (simple interpolation + variation)
        let baseAltitude = interpolate(
            from: currentWaypoint.altitude,
            to: nextWaypoint.altitude,
            progress: currentProgress
        )
        let altitude = baseAltitude + Double.random(in: -2...2)

        // Vary accuracy slightly
        let accuracy = horizontalAccuracy + Double.random(in: -3...3)

        // Create the location
        let location = CLLocation(
            coordinate: variedCoordinate,
            altitude: altitude,
            horizontalAccuracy: max(5, accuracy),
            verticalAccuracy: 10,
            course: bearing,
            speed: currentSpeed,
            timestamp: Date().addingTimeInterval(elapsedTime)
        )

        // Advance position
        advancePosition()

        return location
    }

    /// Generates all locations for the complete track.
    ///
    /// - Returns: Array of CLLocation objects representing the full route.
    public func generateLocations() -> [CLLocation] {
        reset()
        var locations: [CLLocation] = []

        while let location = nextLocation() {
            locations.append(location)
        }

        return locations
    }

    /// Generates locations for a specified duration.
    ///
    /// - Parameter duration: Duration in seconds.
    /// - Returns: Array of locations covering the specified duration.
    public func generateLocations(forDuration duration: TimeInterval) -> [CLLocation] {
        reset()
        var locations: [CLLocation] = []
        var time: TimeInterval = 0

        while time < duration {
            if let location = nextLocation() {
                locations.append(location)
            } else if isLoop {
                // Reset if we're in a loop
                reset()
            } else {
                break
            }
            time += updateInterval
        }

        return locations
    }

    /// Resets the track to the beginning.
    public func reset() {
        currentIndex = 0
        currentProgress = 0
        elapsedTime = 0
        totalDistance = 0
    }

    /// Returns the total distance of the track in meters.
    public func calculateTotalDistance() -> Double {
        guard waypoints.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(waypoints.count - 1) {
            total += distance(from: waypoints[i].coordinate, to: waypoints[i + 1].coordinate)
        }

        if isLoop {
            total += distance(from: waypoints.last!.coordinate, to: waypoints.first!.coordinate)
        }

        return total
    }

    // MARK: - Private Methods

    private func advancePosition() {
        elapsedTime += updateInterval

        // Calculate how much progress to make based on speed and distance to next waypoint
        let baseSpeed = 1000.0 / (targetPace * 60.0)  // m/s
        let distanceToNext = distance(
            from: waypoints[currentIndex].coordinate,
            to: waypoints[(currentIndex + 1) % waypoints.count].coordinate
        )

        // Progress per update
        let progressPerUpdate = (baseSpeed * updateInterval) / distanceToNext
        currentProgress += progressPerUpdate

        // Move to next segment if we've completed this one
        while currentProgress >= 1.0 {
            currentProgress -= 1.0
            currentIndex += 1

            if currentIndex >= waypoints.count - 1 {
                if isLoop {
                    currentIndex = 0
                } else {
                    currentIndex = waypoints.count - 1
                    currentProgress = 1.0
                    break
                }
            }
        }
    }

    private func interpolateCoordinate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        progress: Double
    ) -> CLLocationCoordinate2D {
        let lat = from.latitude + (to.latitude - from.latitude) * progress
        let lon = from.longitude + (to.longitude - from.longitude) * progress
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + (to - from) * progress
    }

    private func addVariation(to coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // GPS drift: typically a few meters
        // 1 degree of latitude ~ 111km
        // So 1 meter ~ 0.000009 degrees
        let metersVariation = horizontalAccuracy * variationFactor
        let degreesVariation = metersVariation * 0.000009

        let latVariation = Double.random(in: -degreesVariation...degreesVariation)
        let lonVariation = Double.random(in: -degreesVariation...degreesVariation)

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latVariation,
            longitude: coordinate.longitude + lonVariation
        )
    }

    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}

// MARK: - TrackWaypoint

extension SimulatedLocationTrack {

    /// Represents a waypoint in a simulated track.
    public struct TrackWaypoint: Sendable {
        /// The coordinate of this waypoint.
        public let coordinate: CLLocationCoordinate2D

        /// Optional name for this waypoint (e.g., "Mile 1").
        public let name: String?

        /// Altitude at this waypoint in meters.
        public let altitude: Double

        /// Optional target pace at this waypoint (for variable-pace routes).
        public let targetPace: Double?

        public init(
            coordinate: CLLocationCoordinate2D,
            name: String? = nil,
            altitude: Double = 0,
            targetPace: Double? = nil
        ) {
            self.coordinate = coordinate
            self.name = name
            self.altitude = altitude
            self.targetPace = targetPace
        }

        public init(
            latitude: Double,
            longitude: Double,
            name: String? = nil,
            altitude: Double = 0
        ) {
            self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.name = name
            self.altitude = altitude
            self.targetPace = nil
        }
    }
}

// MARK: - Factory Methods - Simple Shapes

extension SimulatedLocationTrack {

    /// Creates a linear track from a starting point.
    ///
    /// - Parameters:
    ///   - start: Starting coordinate.
    ///   - bearing: Direction in degrees (0 = North, 90 = East).
    ///   - distance: Total distance in meters.
    ///   - pace: Target pace in minutes per kilometer.
    ///   - waypointInterval: Distance between waypoints in meters.
    /// - Returns: A SimulatedLocationTrack representing the linear route.
    public static func linearTrack(
        start: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double,
        pace: Double = 6.0,
        waypointInterval: Double = 100.0
    ) -> SimulatedLocationTrack {
        var waypoints: [TrackWaypoint] = []

        let bearingRadians = bearing * .pi / 180
        let earthRadius = 6371000.0  // meters

        let waypointCount = Int(distance / waypointInterval) + 1

        for i in 0..<waypointCount {
            let dist = Double(i) * waypointInterval
            let angularDistance = dist / earthRadius

            let lat1 = start.latitude * .pi / 180
            let lon1 = start.longitude * .pi / 180

            let lat2 = asin(sin(lat1) * cos(angularDistance) +
                          cos(lat1) * sin(angularDistance) * cos(bearingRadians))

            let lon2 = lon1 + atan2(
                sin(bearingRadians) * sin(angularDistance) * cos(lat1),
                cos(angularDistance) - sin(lat1) * sin(lat2)
            )

            let coordinate = CLLocationCoordinate2D(
                latitude: lat2 * 180 / .pi,
                longitude: lon2 * 180 / .pi
            )

            waypoints.append(TrackWaypoint(
                coordinate: coordinate,
                name: i == 0 ? "Start" : "Point \(i)"
            ))
        }

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace)
    }

    /// Creates a rectangular loop track.
    ///
    /// - Parameters:
    ///   - center: Center point of the rectangle.
    ///   - width: Width in meters (east-west).
    ///   - height: Height in meters (north-south).
    ///   - pace: Target pace in minutes per kilometer.
    /// - Returns: A looping rectangular track.
    public static func rectangularLoop(
        center: CLLocationCoordinate2D,
        width: Double,
        height: Double,
        pace: Double = 6.0
    ) -> SimulatedLocationTrack {
        let halfWidth = width / 2.0
        let halfHeight = height / 2.0

        // Convert to degrees (approximate)
        let latDelta = halfHeight / 111000.0
        let lonDelta = halfWidth / (111000.0 * cos(center.latitude * .pi / 180))

        let waypoints = [
            TrackWaypoint(latitude: center.latitude + latDelta, longitude: center.longitude - lonDelta, name: "NW Corner"),
            TrackWaypoint(latitude: center.latitude + latDelta, longitude: center.longitude + lonDelta, name: "NE Corner"),
            TrackWaypoint(latitude: center.latitude - latDelta, longitude: center.longitude + lonDelta, name: "SE Corner"),
            TrackWaypoint(latitude: center.latitude - latDelta, longitude: center.longitude - lonDelta, name: "SW Corner"),
            TrackWaypoint(latitude: center.latitude + latDelta, longitude: center.longitude - lonDelta, name: "NW Corner (End)")
        ]

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace, isLoop: true)
    }

    /// Creates a circular loop track.
    ///
    /// - Parameters:
    ///   - center: Center point of the circle.
    ///   - radius: Radius in meters.
    ///   - pace: Target pace in minutes per kilometer.
    ///   - pointCount: Number of points around the circle.
    /// - Returns: A circular track.
    public static func circularLoop(
        center: CLLocationCoordinate2D,
        radius: Double,
        pace: Double = 6.0,
        pointCount: Int = 36
    ) -> SimulatedLocationTrack {
        var waypoints: [TrackWaypoint] = []

        for i in 0...pointCount {
            let angle = (Double(i) / Double(pointCount)) * 2 * .pi
            let latDelta = (radius * cos(angle)) / 111000.0
            let lonDelta = (radius * sin(angle)) / (111000.0 * cos(center.latitude * .pi / 180))

            waypoints.append(TrackWaypoint(
                latitude: center.latitude + latDelta,
                longitude: center.longitude + lonDelta,
                name: i == 0 ? "Start" : nil
            ))
        }

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace, isLoop: true)
    }
}

// MARK: - Factory Methods - Real Routes

extension SimulatedLocationTrack {

    /// Creates a simulated Central Park (NYC) outer loop route.
    /// Approximately 6 miles (9.7 km).
    public static func centralParkLoop(pace: Double = 6.0) -> SimulatedLocationTrack {
        // Simplified Central Park outer loop waypoints
        let waypoints = [
            TrackWaypoint(latitude: 40.7829, longitude: -73.9654, name: "Columbus Circle", altitude: 18),
            TrackWaypoint(latitude: 40.7897, longitude: -73.9581, name: "Cat Hill", altitude: 35),
            TrackWaypoint(latitude: 40.7968, longitude: -73.9552, name: "Engineer's Gate", altitude: 25),
            TrackWaypoint(latitude: 40.8014, longitude: -73.9584, name: "Harlem Hill Base", altitude: 20),
            TrackWaypoint(latitude: 40.8038, longitude: -73.9576, name: "Harlem Hill Top", altitude: 42),
            TrackWaypoint(latitude: 40.8022, longitude: -73.9628, name: "North End", altitude: 30),
            TrackWaypoint(latitude: 40.7973, longitude: -73.9681, name: "West Side North", altitude: 28),
            TrackWaypoint(latitude: 40.7905, longitude: -73.9712, name: "Great Hill", altitude: 35),
            TrackWaypoint(latitude: 40.7843, longitude: -73.9705, name: "West Side South", altitude: 22),
            TrackWaypoint(latitude: 40.7829, longitude: -73.9654, name: "Columbus Circle (End)", altitude: 18)
        ]

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace, isLoop: true)
    }

    /// Creates a simulated San Francisco Embarcadero route.
    /// Approximately 3 miles (4.8 km).
    public static func sfEmbarcadero(pace: Double = 6.0) -> SimulatedLocationTrack {
        let waypoints = [
            TrackWaypoint(latitude: 37.7956, longitude: -122.3935, name: "Ferry Building", altitude: 5),
            TrackWaypoint(latitude: 37.7978, longitude: -122.3985, name: "Pier 7", altitude: 3),
            TrackWaypoint(latitude: 37.8024, longitude: -122.4012, name: "Pier 15", altitude: 3),
            TrackWaypoint(latitude: 37.8062, longitude: -122.4035, name: "Pier 23", altitude: 3),
            TrackWaypoint(latitude: 37.8087, longitude: -122.4078, name: "Pier 31", altitude: 4),
            TrackWaypoint(latitude: 37.8062, longitude: -122.4035, name: "Pier 23 Return", altitude: 3),
            TrackWaypoint(latitude: 37.8024, longitude: -122.4012, name: "Pier 15 Return", altitude: 3),
            TrackWaypoint(latitude: 37.7978, longitude: -122.3985, name: "Pier 7 Return", altitude: 3),
            TrackWaypoint(latitude: 37.7956, longitude: -122.3935, name: "Ferry Building (End)", altitude: 5)
        ]

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace)
    }

    /// Creates a simulated track around a standard 400m track.
    /// Configurable number of laps.
    public static func standardTrack(
        center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        laps: Int = 4,
        pace: Double = 5.0
    ) -> SimulatedLocationTrack {
        // A standard 400m track is roughly 85m x 73m
        var waypoints: [TrackWaypoint] = []

        // Track dimensions (approximate)
        let straightLength = 84.39  // meters
        let curveRadius = 36.5      // meters

        let latMeterScale = 1.0 / 111000.0
        let lonMeterScale = 1.0 / (111000.0 * cos(center.latitude * .pi / 180))

        // Generate multiple laps
        for lap in 0..<laps {
            // Start line (bottom of the track)
            if lap == 0 {
                waypoints.append(TrackWaypoint(
                    latitude: center.latitude - (curveRadius * latMeterScale),
                    longitude: center.longitude - (straightLength / 2 * lonMeterScale),
                    name: "Start Line"
                ))
            }

            // First straight
            waypoints.append(TrackWaypoint(
                latitude: center.latitude - (curveRadius * latMeterScale),
                longitude: center.longitude + (straightLength / 2 * lonMeterScale),
                name: lap == 0 ? "100m" : nil
            ))

            // First curve (top right quadrant - 8 points)
            for i in 1...8 {
                let angle = .pi * Double(i) / 8.0
                let lat = center.latitude + (curveRadius * sin(angle) - curveRadius) * latMeterScale
                let lon = center.longitude + (straightLength / 2 + curveRadius * (1 - cos(angle))) * lonMeterScale
                waypoints.append(TrackWaypoint(latitude: lat, longitude: lon))
            }

            // 200m mark
            waypoints.append(TrackWaypoint(
                latitude: center.latitude + (curveRadius * latMeterScale),
                longitude: center.longitude + (straightLength / 2 * lonMeterScale),
                name: lap == 0 ? "200m" : nil
            ))

            // Back straight
            waypoints.append(TrackWaypoint(
                latitude: center.latitude + (curveRadius * latMeterScale),
                longitude: center.longitude - (straightLength / 2 * lonMeterScale),
                name: lap == 0 ? "300m" : nil
            ))

            // Second curve (bottom left quadrant - 8 points)
            for i in 1...8 {
                let angle = .pi + .pi * Double(i) / 8.0
                let lat = center.latitude + (curveRadius * sin(angle) + curveRadius) * latMeterScale
                let lon = center.longitude + (-straightLength / 2 - curveRadius * (1 + cos(angle))) * lonMeterScale
                waypoints.append(TrackWaypoint(latitude: lat, longitude: lon))
            }

            // Finish line position
            waypoints.append(TrackWaypoint(
                latitude: center.latitude - (curveRadius * latMeterScale),
                longitude: center.longitude - (straightLength / 2 * lonMeterScale),
                name: "Lap \(lap + 1) Complete"
            ))
        }

        return SimulatedLocationTrack(waypoints: waypoints, targetPace: pace)
    }

    /// Creates a simple out-and-back route.
    public static func outAndBack(
        start: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double,
        pace: Double = 6.0
    ) -> SimulatedLocationTrack {
        let outTrack = linearTrack(start: start, bearing: bearing, distance: distance / 2, pace: pace)
        let locations = outTrack.generateLocations()

        // Reverse for return journey
        var waypoints = locations.map { TrackWaypoint(coordinate: $0.coordinate) }
        let returnWaypoints = waypoints.reversed().dropFirst()
        waypoints.append(contentsOf: returnWaypoints)

        return SimulatedLocationTrack(
            waypoints: waypoints,
            targetPace: pace
        )
    }
}

// MARK: - Testing Utilities

extension SimulatedLocationTrack {

    /// Generates locations with intentional GPS issues for testing error handling.
    public static func withGPSIssues(
        baseTrack: SimulatedLocationTrack,
        dropoutProbability: Double = 0.05,
        poorAccuracyProbability: Double = 0.1
    ) -> [CLLocation] {
        var locations: [CLLocation] = []

        for location in baseTrack.generateLocations() {
            // Simulate GPS dropout
            if Double.random(in: 0...1) < dropoutProbability {
                continue
            }

            // Simulate poor accuracy
            var accuracy = location.horizontalAccuracy
            if Double.random(in: 0...1) < poorAccuracyProbability {
                accuracy = 50 + Double.random(in: 0...100)
            }

            let adjustedLocation = CLLocation(
                coordinate: location.coordinate,
                altitude: location.altitude,
                horizontalAccuracy: accuracy,
                verticalAccuracy: location.verticalAccuracy,
                course: location.course,
                speed: location.speed,
                timestamp: location.timestamp
            )

            locations.append(adjustedLocation)
        }

        return locations
    }

    /// Creates a series of stationary locations (for testing pause detection).
    public static func stationaryLocations(
        at coordinate: CLLocationCoordinate2D,
        duration: TimeInterval,
        interval: TimeInterval = 1.0
    ) -> [CLLocation] {
        let count = Int(duration / interval)
        var locations: [CLLocation] = []

        let startTime = Date()
        for i in 0..<count {
            // Add small GPS drift
            let drift = 0.00001 * Double.random(in: -1...1)
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinate.latitude + drift,
                    longitude: coordinate.longitude + drift
                ),
                altitude: 0,
                horizontalAccuracy: 10,
                verticalAccuracy: 10,
                course: -1,
                speed: 0,
                timestamp: startTime.addingTimeInterval(TimeInterval(i) * interval)
            )
            locations.append(location)
        }

        return locations
    }
}
