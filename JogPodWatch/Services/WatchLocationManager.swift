//
//  WatchLocationManager.swift
//  JogPodWatch
//
//  CoreLocation manager for GPS tracking on Apple Watch.
//  Provides battery-efficient location tracking during workouts.
//

import Foundation
import CoreLocation

// MARK: - WatchLocationManagerDelegate

/// Delegate protocol for receiving location updates from WatchLocationManager.
@MainActor
public protocol WatchLocationManagerDelegate: AnyObject {
    /// Called when a new location is available.
    func locationManager(_ manager: WatchLocationManager, didUpdateLocation location: CLLocation)

    /// Called when a location error occurs.
    func locationManager(_ manager: WatchLocationManager, didFailWithError error: Error)
}

// MARK: - WatchLocationManager

/// Location manager for GPS tracking on Apple Watch.
///
/// This class provides battery-efficient location tracking suitable for
/// workout sessions on watchOS. It uses appropriate accuracy settings
/// based on the device capabilities and workout requirements.
///
/// ## Features
///
/// - Battery-efficient location tracking
/// - Automatic pause/resume support
/// - Accuracy filtering for GPS noise reduction
/// - Background location updates during workouts
///
/// ## watchOS Considerations
///
/// On watchOS, location services operate differently than iOS:
/// - GPS is available on cellular and GPS-enabled Watch models
/// - Battery life is critical - uses best accuracy for activity only
/// - Location is shared with paired iPhone when available
///
/// ## Usage
///
/// ```swift
/// let locationManager = WatchLocationManager()
/// locationManager.delegate = self
/// locationManager.startTracking()
/// ```
@MainActor
public final class WatchLocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Current location, if available.
    @Published public private(set) var currentLocation: CLLocation?

    /// Whether location tracking is active.
    @Published public private(set) var isTracking: Bool = false

    /// Whether location services are authorized.
    @Published public private(set) var isAuthorized: Bool = false

    /// Current authorization status.
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Last error that occurred.
    @Published public private(set) var lastError: Error?

    // MARK: - Properties

    /// Delegate for receiving location updates.
    public weak var delegate: WatchLocationManagerDelegate?

    /// The underlying CLLocationManager.
    private let locationManager = CLLocationManager()

    /// Whether tracking is paused.
    private var isPaused: Bool = false

    /// Minimum horizontal accuracy to accept (meters).
    private let minimumAccuracy: CLLocationAccuracy = 50.0

    /// Minimum distance filter (meters).
    private let distanceFilter: CLLocationDistance = 5.0

    /// Minimum time interval between updates (seconds).
    private let minimumUpdateInterval: TimeInterval = 1.0

    /// Last accepted location timestamp.
    private var lastUpdateTime: Date?

    // MARK: - Initialization

    public override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true

        // Check initial authorization
        updateAuthorizationStatus(locationManager.authorizationStatus)
    }

    // MARK: - Authorization

    /// Requests authorization for location services.
    ///
    /// On watchOS, this requests "when in use" authorization which is
    /// sufficient for workout tracking.
    public func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        authorizationStatus = status

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
        case .denied, .restricted:
            isAuthorized = false
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    // MARK: - Tracking Control

    /// Starts location tracking.
    ///
    /// Location updates will be delivered to the delegate. If authorization
    /// has not been granted, this will request it first.
    public func startTracking() {
        guard !isTracking else { return }

        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }

        guard isAuthorized else {
            lastError = LocationError.notAuthorized
            return
        }

        locationManager.startUpdatingLocation()
        isTracking = true
        isPaused = false
        lastUpdateTime = nil
    }

    /// Stops location tracking.
    public func stopTracking() {
        guard isTracking else { return }

        locationManager.stopUpdatingLocation()
        isTracking = false
        isPaused = false
        currentLocation = nil
    }

    /// Pauses location tracking.
    ///
    /// Location updates are temporarily stopped but tracking state is preserved.
    public func pauseTracking() {
        guard isTracking && !isPaused else { return }

        locationManager.stopUpdatingLocation()
        isPaused = true
    }

    /// Resumes location tracking after a pause.
    public func resumeTracking() {
        guard isTracking && isPaused else { return }

        locationManager.startUpdatingLocation()
        isPaused = false
    }

    // MARK: - Location Filtering

    /// Determines whether a location update should be accepted.
    ///
    /// Filters out:
    /// - Invalid locations
    /// - Locations with poor accuracy
    /// - Locations that are too old
    /// - Updates that are too frequent
    private func shouldAcceptLocation(_ location: CLLocation) -> Bool {
        // Reject invalid coordinates
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            return false
        }

        // Reject if accuracy is too poor
        guard location.horizontalAccuracy >= 0 &&
              location.horizontalAccuracy <= minimumAccuracy else {
            return false
        }

        // Reject old locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        guard locationAge < 10.0 else {
            return false
        }

        // Rate limit updates
        if let lastTime = lastUpdateTime {
            let timeSinceLastUpdate = -lastTime.timeIntervalSinceNow
            guard timeSinceLastUpdate >= minimumUpdateInterval else {
                return false
            }
        }

        return true
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchLocationManager: CLLocationManagerDelegate {

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // Filter location
            guard self.shouldAcceptLocation(location) else { return }

            // Update state
            self.currentLocation = location
            self.lastUpdateTime = Date()
            self.lastError = nil

            // Notify delegate
            self.delegate?.locationManager(self, didUpdateLocation: location)
        }
    }

    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.lastError = error

            // Don't treat certain errors as failures
            if let clError = error as? CLError {
                switch clError.code {
                case .locationUnknown:
                    // Temporary condition - GPS is still acquiring
                    return
                case .denied:
                    self.isAuthorized = false
                    self.stopTracking()
                default:
                    break
                }
            }

            self.delegate?.locationManager(self, didFailWithError: error)
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateAuthorizationStatus(manager.authorizationStatus)

            // Auto-start if tracking was requested and we just got authorized
            if self.isAuthorized && !self.isTracking {
                // Check if we should start
            }
        }
    }
}

// MARK: - LocationError

/// Errors that can occur during location tracking.
public enum LocationError: Error, LocalizedError, Sendable {
    case notAuthorized
    case servicesDisabled
    case locationUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location authorization not granted."
        case .servicesDisabled:
            return "Location services are disabled."
        case .locationUnavailable:
            return "Unable to determine location."
        }
    }
}
