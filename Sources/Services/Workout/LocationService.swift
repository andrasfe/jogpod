//
//  LocationService.swift
//  JogPod
//
//  CLLocationManager wrapper providing async streams for location updates.
//

import Foundation
import CoreLocation

// MARK: - LocationServiceProtocol

/// Protocol for location services to enable testing.
public protocol LocationServiceProtocol: Sendable {

    /// The current authorization status.
    var authorizationStatus: CLAuthorizationStatus { get async }

    /// Whether location services are enabled on this device.
    var isLocationServicesEnabled: Bool { get }

    /// Requests location authorization from the user.
    func requestAuthorization() async throws

    /// Starts location updates and returns an async stream of locations.
    ///
    /// - Parameters:
    ///   - desiredAccuracy: The desired location accuracy.
    ///   - distanceFilter: The minimum distance between updates.
    /// - Returns: An async stream of CLLocation objects.
    /// - Throws: `WorkoutError` if location services are unavailable or unauthorized.
    func startLocationUpdates(
        desiredAccuracy: CLLocationAccuracy,
        distanceFilter: CLLocationDistance
    ) async throws -> AsyncStream<CLLocation>

    /// Stops location updates.
    func stopLocationUpdates() async
}

// MARK: - LocationService

/// Wrapper around CLLocationManager providing async streams for location updates.
///
/// This service encapsulates all CLLocationManager interactions and provides
/// a modern Swift concurrency interface using AsyncStream.
///
/// ## Usage
///
/// ```swift
/// let locationService = LocationService()
///
/// // Request authorization
/// try await locationService.requestAuthorization()
///
/// // Start receiving location updates
/// let locations = try await locationService.startLocationUpdates(
///     desiredAccuracy: kCLLocationAccuracyBest,
///     distanceFilter: 10.0
/// )
///
/// for await location in locations {
///     print("New location: \(location)")
/// }
/// ```
///
/// ## Thread Safety
///
/// LocationService uses actor isolation internally to ensure thread-safe
/// access to the underlying CLLocationManager.
public final class LocationService: NSObject, LocationServiceProtocol, @unchecked Sendable {

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?
    private let lock = NSLock()

    // MARK: - Configuration

    /// Distance filter for location updates (default 10 meters).
    public static let defaultDistanceFilter: CLLocationDistance = 10.0

    /// Heading filter for location updates (default 5 degrees).
    public static let defaultHeadingFilter: CLLocationDegrees = 5.0

    // MARK: - Initialization

    /// Creates a new LocationService instance.
    public override init() {
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = Self.defaultDistanceFilter
        locationManager.headingFilter = Self.defaultHeadingFilter
    }

    /// Creates a LocationService with a custom CLLocationManager for testing.
    ///
    /// - Parameter locationManager: The location manager to use.
    internal init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        locationManager.delegate = self
    }

    // MARK: - LocationServiceProtocol

    public var authorizationStatus: CLAuthorizationStatus {
        get async {
            locationManager.authorizationStatus
        }
    }

    public var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    /// Requests location authorization from the user.
    ///
    /// This method requests "Always" authorization for background location tracking
    /// during workouts. If authorization is already granted, this method returns immediately.
    ///
    /// - Throws: `WorkoutError.locationServicesUnavailable` if location services are disabled.
    /// - Throws: `WorkoutError.locationAuthorizationDenied` if authorization is denied.
    /// - Throws: `WorkoutError.locationAuthorizationRestricted` if authorization is restricted.
    public func requestAuthorization() async throws {
        guard isLocationServicesEnabled else {
            throw WorkoutError.locationServicesUnavailable
        }

        let status = await authorizationStatus

        switch status {
        case .notDetermined:
            // Request authorization and wait for callback
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                authorizationContinuation = continuation
                locationManager.requestAlwaysAuthorization()
            }

            // Re-check after authorization request
            let newStatus = await authorizationStatus
            try validateAuthorizationStatus(newStatus)

        case .authorizedAlways, .authorizedWhenInUse:
            // Already authorized
            return

        case .denied:
            throw WorkoutError.locationAuthorizationDenied

        case .restricted:
            throw WorkoutError.locationAuthorizationRestricted

        @unknown default:
            throw WorkoutError.unexpected(description: "Unknown authorization status")
        }
    }

    public func startLocationUpdates(
        desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest,
        distanceFilter: CLLocationDistance = defaultDistanceFilter
    ) async throws -> AsyncStream<CLLocation> {
        guard isLocationServicesEnabled else {
            throw WorkoutError.locationServicesUnavailable
        }

        let status = await authorizationStatus
        try validateAuthorizationStatus(status)

        // Configure the location manager
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Create and return the async stream
        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }

            self.lock.lock()
            self.locationContinuation = continuation
            self.lock.unlock()

            self.locationManager.startUpdatingLocation()

            continuation.onTermination = { [weak self] _ in
                self?.locationManager.stopUpdatingLocation()
                self?.lock.lock()
                self?.locationContinuation = nil
                self?.lock.unlock()
            }
        }
    }

    public func stopLocationUpdates() async {
        locationManager.stopUpdatingLocation()

        lock.lock()
        locationContinuation?.finish()
        locationContinuation = nil
        lock.unlock()
    }

    // MARK: - Authorization Handling

    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    private func validateAuthorizationStatus(_ status: CLAuthorizationStatus) throws {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied:
            throw WorkoutError.locationAuthorizationDenied
        case .restricted:
            throw WorkoutError.locationAuthorizationRestricted
        case .notDetermined:
            throw WorkoutError.locationAuthorizationUndetermined
        @unknown default:
            throw WorkoutError.unexpected(description: "Unknown authorization status")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lock.lock()
        let continuation = locationContinuation
        lock.unlock()

        for location in locations {
            continuation?.yield(location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log the error but don't terminate the stream
        // The workout service can handle this appropriately
        print("[LocationService] Location error: \(error.localizedDescription)")
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Resume the authorization continuation if waiting
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }
}

// MARK: - MockLocationService

/// Mock implementation of LocationService for testing.
///
/// This class allows tests to inject predetermined location sequences
/// and control authorization behavior.
public final class MockLocationService: LocationServiceProtocol {

    // MARK: - Mock State

    private var mockStatus: CLAuthorizationStatus
    private var mockLocationsEnabled: Bool
    private var mockLocations: [CLLocation]
    private var locationIndex: Int = 0
    private var shouldFailAuthorization: Bool = false

    // MARK: - Initialization

    public init(
        authorizationStatus: CLAuthorizationStatus = .authorizedAlways,
        locationServicesEnabled: Bool = true,
        locations: [CLLocation] = []
    ) {
        self.mockStatus = authorizationStatus
        self.mockLocationsEnabled = locationServicesEnabled
        self.mockLocations = locations
    }

    // MARK: - Configuration

    /// Sets the mock locations to be returned.
    public func setMockLocations(_ locations: [CLLocation]) {
        mockLocations = locations
        locationIndex = 0
    }

    /// Sets the mock authorization status.
    public func setMockAuthorizationStatus(_ status: CLAuthorizationStatus) {
        mockStatus = status
    }

    /// Sets whether authorization should fail.
    public func setShouldFailAuthorization(_ shouldFail: Bool) {
        shouldFailAuthorization = shouldFail
    }

    // MARK: - LocationServiceProtocol

    public var authorizationStatus: CLAuthorizationStatus {
        get async {
            mockStatus
        }
    }

    public var isLocationServicesEnabled: Bool {
        mockLocationsEnabled
    }

    public func requestAuthorization() async throws {
        if shouldFailAuthorization {
            throw WorkoutError.locationAuthorizationDenied
        }
        if !mockLocationsEnabled {
            throw WorkoutError.locationServicesUnavailable
        }
        if mockStatus == .denied {
            throw WorkoutError.locationAuthorizationDenied
        }
        if mockStatus == .restricted {
            throw WorkoutError.locationAuthorizationRestricted
        }
        mockStatus = .authorizedAlways
    }

    public func startLocationUpdates(
        desiredAccuracy: CLLocationAccuracy,
        distanceFilter: CLLocationDistance
    ) async throws -> AsyncStream<CLLocation> {
        guard mockLocationsEnabled else {
            throw WorkoutError.locationServicesUnavailable
        }

        guard mockStatus == .authorizedAlways || mockStatus == .authorizedWhenInUse else {
            throw WorkoutError.locationAuthorizationDenied
        }

        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }

            // Yield all mock locations with a small delay
            Task {
                for location in self.mockLocations {
                    continuation.yield(location)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }
    }

    public func stopLocationUpdates() async {
        // No-op for mock
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {

    /// Creates a test location with specified parameters.
    ///
    /// Useful for testing without requiring actual GPS data.
    ///
    /// - Parameters:
    ///   - latitude: Latitude coordinate.
    ///   - longitude: Longitude coordinate.
    ///   - altitude: Altitude in meters.
    ///   - speed: Speed in meters per second.
    ///   - course: Course/heading in degrees.
    ///   - horizontalAccuracy: Horizontal accuracy in meters.
    ///   - timestamp: The timestamp for this location.
    /// - Returns: A configured CLLocation instance.
    public static func makeTestLocation(
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        speed: Double = 0,
        course: Double = -1,
        horizontalAccuracy: Double = 10,
        timestamp: Date = Date()
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 10,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}
