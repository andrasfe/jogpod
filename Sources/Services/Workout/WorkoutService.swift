//
//  WorkoutService.swift
//  JogPod
//
//  Thread-safe workout orchestration using Swift actors.
//

import Foundation
import CoreLocation
import Combine
import HealthKit

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when workout status changes (start/stop).
    public static let workoutStatusChanged = Notification.Name("workoutStatusChanged")

    /// Posted when new workout data is available.
    public static let workoutUpdatesAvailable = Notification.Name("workoutUpdatesAvailable")

    /// Posted when location is updated during a workout.
    public static let locationUpdate = Notification.Name("locationUpdate")
}

// MARK: - WorkoutServiceProtocol

/// Protocol defining the workout service interface for dependency injection.
public protocol WorkoutServiceProtocol: AnyObject, Sendable {

    /// The current workout state.
    var state: WorkoutState { get async }

    /// The ID of the active workout, if any.
    var activeWorkoutID: String? { get async }

    /// Whether a workout is currently in progress.
    var isWorkoutInProgress: Bool { get async }

    /// Starts a new workout session.
    func startWorkout() async throws -> String

    /// Stops the active workout session.
    func stopWorkout() async throws

    /// Requests location authorization.
    func requestAuthorization() async throws

    /// Gets the current workout metrics snapshot.
    func currentMetrics() async -> WorkoutSnapshot?
}

// MARK: - WorkoutService

/// Thread-safe workout orchestration service using Swift actors.
///
/// This actor coordinates all workout tracking operations including:
/// - Location updates from GPS
/// - Heart rate data from external sensors
/// - Metrics computation
/// - Data persistence
///
/// ## Serial Queue Behavior
///
/// The actor naturally enforces serial execution, maintaining the same
/// behavior as the legacy `NSOperationQueue` with `maxConcurrentOperationCount = 1`.
///
/// ## Batching
///
/// Location and heart rate readings are batched every 20 readings
/// before committing to persistence, matching legacy behavior.
///
/// ## Cold Start Filter
///
/// The first GPS reading is ignored to filter out stale cached locations.
///
/// ## Usage
///
/// ```swift
/// let workoutService = try await WorkoutService.makeDefault()
///
/// // Start a workout
/// let workoutID = try await workoutService.startWorkout()
///
/// // Stop the workout
/// try await workoutService.stopWorkout()
/// ```
public actor WorkoutService: WorkoutServiceProtocol {

    // MARK: - Configuration Constants

    /// Number of location readings between persistence commits.
    public static let locationBatchSize = 20

    /// Number of heart rate readings between persistence commits.
    public static let heartRateBatchSize = 20

    /// Number of initial GPS readings to ignore (cold-start filter).
    public static let readingsToIgnore = 1

    /// Minimum workout duration (in seconds) to show summary.
    public static let minimumSummaryDuration: TimeInterval = 300

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol
    private let persistence: PersistenceManaging
    private let healthKitService: HealthKitServiceProtocol?

    // MARK: - State

    private var _state: WorkoutState = .idle
    private var _activeWorkoutID: String?
    private var metrics: WorkoutMetrics?
    private var locationTask: Task<Void, Error>?

    // MARK: - Counters

    private var locationReadingCount: Int = 0
    private var heartRateReadingCount: Int = 0
    private var pendingLocationWrites: Int = 0
    private var pendingHeartRateWrites: Int = 0

    // MARK: - Data Tracking

    private var lastLocation: CLLocation?
    private var lastHeartRate: Int = 0
    private var currentSteps: Int = 0
    private var startTime: Date?

    // MARK: - Initialization

    /// Creates a WorkoutService with the specified dependencies.
    ///
    /// - Parameters:
    ///   - locationService: Service providing location updates.
    ///   - persistence: Persistence manager for storing workout data.
    ///   - healthKitService: Optional HealthKit service for syncing workouts to Apple Health.
    public init(
        locationService: LocationServiceProtocol,
        persistence: PersistenceManaging,
        healthKitService: HealthKitServiceProtocol? = nil
    ) {
        self.locationService = locationService
        self.persistence = persistence
        self.healthKitService = healthKitService
    }

    /// Creates a WorkoutService with default dependencies.
    ///
    /// - Throws: `PersistenceError` if the persistence manager cannot be created.
    public static func makeDefault() async throws -> WorkoutService {
        let persistence = try PersistenceManager.makeDefault()
        let locationService = LocationService()
        let healthKitService = HealthKitService.shared

        return WorkoutService(
            locationService: locationService,
            persistence: persistence,
            healthKitService: healthKitService
        )
    }

    /// Creates a WorkoutService for testing with mock dependencies.
    ///
    /// - Parameters:
    ///   - persistence: Mock persistence manager.
    ///   - locationService: Mock location service.
    ///   - healthKitService: Optional mock HealthKit service.
    /// - Returns: A configured WorkoutService for testing.
    public static func makeForTesting(
        persistence: PersistenceManaging,
        locationService: LocationServiceProtocol,
        healthKitService: HealthKitServiceProtocol? = nil
    ) -> WorkoutService {
        WorkoutService(
            locationService: locationService,
            persistence: persistence,
            healthKitService: healthKitService
        )
    }

    // MARK: - Public Interface

    public var state: WorkoutState {
        _state
    }

    public var activeWorkoutID: String? {
        _activeWorkoutID
    }

    public var isWorkoutInProgress: Bool {
        _state == .active || _state == .starting
    }

    /// The last known location.
    public var currentLocation: CLLocation? {
        lastLocation
    }

    /// Requests location authorization from the user.
    ///
    /// Call this before starting a workout to ensure location permissions are granted.
    ///
    /// - Throws: `WorkoutError` if authorization cannot be obtained.
    public func requestAuthorization() async throws {
        try await locationService.requestAuthorization()
    }

    /// Starts a new workout session.
    ///
    /// This method:
    /// 1. Validates that no workout is currently in progress
    /// 2. Creates a new workout session in persistence
    /// 3. Starts location updates
    /// 4. Posts `workoutStatusChanged` notification
    ///
    /// - Returns: The UUID of the newly created workout session.
    /// - Throws: `WorkoutError.workoutAlreadyInProgress` if a workout is active.
    /// - Throws: `WorkoutError.sessionCreationFailed` if database insert fails.
    @discardableResult
    public func startWorkout() async throws -> String {
        guard _state == .idle else {
            throw WorkoutError.workoutAlreadyInProgress
        }

        _state = .starting

        do {
            // Reset counters
            resetCounters()

            // Create new workout ID
            let workoutID = UUID().uuidString
            startTime = Date()

            // Create workout session in persistence
            do {
                _ = try await persistence.createWorkoutSession(
                    workoutID: workoutID,
                    startTime: startTime
                )
            } catch {
                _state = .idle
                throw WorkoutError.sessionCreationFailed(underlyingError: error.localizedDescription)
            }

            _activeWorkoutID = workoutID

            // Initialize metrics
            await initializeMetrics()

            // Request location authorization first
            try await locationService.requestAuthorization()

            // Start location updates
            try await startLocationUpdates()

            _state = .active

            // Post notification
            await postWorkoutStatusNotification(isActive: true)

            return workoutID

        } catch {
            _state = .error
            throw error
        }
    }

    /// Stops the active workout session.
    ///
    /// This method:
    /// 1. Stops location updates
    /// 2. Commits any pending data
    /// 3. Syncs workout to Apple Health (if HealthKit is available)
    /// 4. Posts `workoutStatusChanged` notification
    /// 5. Shows summary if workout was long enough
    ///
    /// - Throws: `WorkoutError.noActiveWorkout` if no workout is in progress.
    public func stopWorkout() async throws {
        guard _state == .active || _state == .starting else {
            throw WorkoutError.noActiveWorkout
        }

        _state = .stopping

        // Capture workout data before cleanup
        let workoutID = _activeWorkoutID
        let workoutStartTime = startTime
        let workoutEndTime = Date()
        let finalSnapshot = await metrics?.snapshot()

        // Stop location updates
        locationTask?.cancel()
        locationTask = nil
        await locationService.stopLocationUpdates()

        // Commit any pending writes
        await commitPendingWrites()

        // Sync to Apple Health
        if let workoutID = workoutID,
           let startTime = workoutStartTime,
           let snapshot = finalSnapshot {
            await syncToHealthKit(
                workoutID: workoutID,
                startTime: startTime,
                endTime: workoutEndTime,
                snapshot: snapshot
            )
        }

        // Post notification
        await postWorkoutStatusNotification(isActive: false)

        // Clean up state
        _activeWorkoutID = nil
        metrics = nil
        _state = .idle
    }

    /// Gets the current workout metrics snapshot.
    ///
    /// - Returns: A snapshot of current metrics, or nil if no workout is active.
    public func currentMetrics() async -> WorkoutSnapshot? {
        await metrics?.snapshot()
    }

    /// Updates heart rate data during an active workout.
    ///
    /// - Parameters:
    ///   - heartRate: Heart rate in BPM.
    ///   - steps: Optional current step count.
    public func updateHeartRate(_ heartRate: Int, steps: Int? = nil) async {
        guard _state == .active, let workoutID = _activeWorkoutID else { return }

        lastHeartRate = heartRate
        if let steps = steps {
            currentSteps = steps
        }

        // Update metrics
        await metrics?.updateWithHeartRate(heartRate, steps: steps)

        // Only create a track point if we don't have a recent location
        // (to avoid duplicating data when location updates come with HR)
        let shouldCreateStandalonePoint = shouldCreateStandaloneHeartRatePoint()

        if shouldCreateStandalonePoint {
            heartRateReadingCount += 1
            pendingHeartRateWrites += 1

            do {
                _ = try await persistence.createTrackPoint(
                    workoutID: workoutID,
                    time: Date(),
                    location: lastLocation,
                    heartRate: Int16(clamping: heartRate),
                    steps: Int16(clamping: currentSteps)
                )

                // Batch commit every N readings
                if pendingHeartRateWrites >= Self.heartRateBatchSize {
                    try await persistence.save()
                    pendingHeartRateWrites = 0
                }
            } catch {
                // Log but don't throw - we don't want to interrupt the workout
                print("[WorkoutService] Failed to save heart rate: \(error)")
            }
        }
    }

    /// Updates step count during an active workout.
    ///
    /// - Parameter steps: Current step count.
    public func updateSteps(_ steps: Int) async {
        guard _state == .active else { return }
        currentSteps = steps
    }

    // MARK: - Private Methods

    private func resetCounters() {
        locationReadingCount = 0
        heartRateReadingCount = 0
        pendingLocationWrites = 0
        pendingHeartRateWrites = 0
        lastLocation = nil
        lastHeartRate = 0
        currentSteps = 0
    }

    private func initializeMetrics() async {
        let start = startTime ?? Date()
        metrics = await MainActor.run {
            WorkoutMetrics(
                startTime: start,
                userWeight: 70.0 // TODO: Get from user preferences
            )
        }
    }

    private func startLocationUpdates() async throws {
        let stream = try await locationService.startLocationUpdates(
            desiredAccuracy: kCLLocationAccuracyBest,
            distanceFilter: LocationService.defaultDistanceFilter
        )

        locationTask = Task { [weak self] in
            for await location in stream {
                guard let self = self else { break }

                do {
                    try Task.checkCancellation()
                    await self.handleLocationUpdate(location)
                } catch is CancellationError {
                    break
                } catch {
                    print("[WorkoutService] Location handling error: \(error)")
                }
            }
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        guard _state == .active, let workoutID = _activeWorkoutID else { return }

        locationReadingCount += 1

        // Ignore first N readings (cold-start filter)
        guard locationReadingCount > Self.readingsToIgnore else {
            return
        }

        let oldLocation = lastLocation
        lastLocation = location

        // Update metrics
        await metrics?.updateWithLocation(location, steps: currentSteps)

        // Post location notification
        await postLocationUpdateNotification(location)

        // Create track point
        pendingLocationWrites += 1

        do {
            _ = try await persistence.createTrackPoint(
                workoutID: workoutID,
                time: location.timestamp,
                location: location,
                heartRate: lastHeartRate > 0 ? Int16(clamping: lastHeartRate) : nil,
                steps: Int16(clamping: currentSteps)
            )

            // Batch commit every N readings
            if pendingLocationWrites >= Self.locationBatchSize {
                try await persistence.save()
                pendingLocationWrites = 0
            }
        } catch {
            print("[WorkoutService] Failed to save track point: \(error)")
        }

        // Post workout updates notification
        if let snapshot = await metrics?.snapshot() {
            await postWorkoutUpdatesNotification(snapshot)
        }

        // Check for peak speed and notify if needed
        if await metrics?.isAtPeakSpeed == true {
            await postPeakSpeedNotification()
        }
    }

    private func shouldCreateStandaloneHeartRatePoint() -> Bool {
        // If we have a recent location (within 10 seconds), don't create standalone HR point
        // The HR will be attached to the location update instead
        guard let lastLoc = lastLocation else { return true }
        let age = Date().timeIntervalSince(lastLoc.timestamp)
        return age > 10
    }

    private func commitPendingWrites() async {
        guard pendingLocationWrites > 0 || pendingHeartRateWrites > 0 else { return }

        do {
            try await persistence.save()
            pendingLocationWrites = 0
            pendingHeartRateWrites = 0
        } catch {
            print("[WorkoutService] Failed to commit pending writes: \(error)")
        }
    }

    // MARK: - HealthKit Integration

    /// Syncs the completed workout to Apple Health.
    ///
    /// This method:
    /// 1. Retrieves stored track points from persistence
    /// 2. Converts them to HealthKit route points and heart rate samples
    /// 3. Saves the workout with all associated data to Apple Health
    ///
    /// - Parameters:
    ///   - workoutID: The workout session ID.
    ///   - startTime: When the workout started.
    ///   - endTime: When the workout ended.
    ///   - snapshot: The final workout metrics snapshot.
    private func syncToHealthKit(
        workoutID: String,
        startTime: Date,
        endTime: Date,
        snapshot: WorkoutSnapshot
    ) async {
        guard let healthKit = healthKitService else {
            print("[WorkoutService] HealthKit service not available, skipping sync")
            return
        }

        guard healthKit.isAvailable else {
            print("[WorkoutService] HealthKit not available on this device")
            return
        }

        do {
            // Fetch track points from persistence
            let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

            // Convert track points to route points
            let routePoints = trackPoints.compactMap { trackPoint -> RoutePoint? in
                guard let latitude = trackPoint.latitude,
                      let longitude = trackPoint.longitude,
                      let timestamp = trackPoint.time else {
                    return nil
                }

                return RoutePoint(
                    latitude: latitude,
                    longitude: longitude,
                    altitude: trackPoint.altitude ?? 0,
                    horizontalAccuracy: trackPoint.horizontalAccuracy ?? 0,
                    verticalAccuracy: 0,
                    timestamp: timestamp
                )
            }

            // Convert track points to heart rate samples
            let heartRateSamples = trackPoints.compactMap { trackPoint -> HeartRateSample? in
                guard let heartRate = trackPoint.heartRate,
                      heartRate > 0,
                      let timestamp = trackPoint.time else {
                    return nil
                }

                return HeartRateSample(
                    bpm: Int(heartRate),
                    timestamp: timestamp
                )
            }

            // Create HealthKit workout data
            let workoutData = HealthKitWorkoutData(
                startTime: startTime,
                endTime: endTime,
                activityType: .running,
                totalEnergyBurned: Double(snapshot.caloriesBurned),
                totalDistance: snapshot.totalDistance,
                distanceUnit: .meters,
                metadata: [
                    HKMetadataKeyIndoorWorkout: false,
                    "JogPodWorkoutID": workoutID
                ],
                heartRateSamples: heartRateSamples,
                routePoints: routePoints
            )

            // Save to HealthKit
            try await healthKit.saveWorkout(workoutData)

            print("[WorkoutService] Successfully synced workout to HealthKit")
            print("[WorkoutService]   - Duration: \(snapshot.formattedDuration)")
            print("[WorkoutService]   - Distance: \(String(format: "%.2f", snapshot.distanceInKilometers)) km")
            print("[WorkoutService]   - Calories: \(snapshot.caloriesBurned)")
            print("[WorkoutService]   - Route points: \(routePoints.count)")
            print("[WorkoutService]   - Heart rate samples: \(heartRateSamples.count)")

        } catch {
            // Log but don't throw - HealthKit sync failure shouldn't prevent workout completion
            print("[WorkoutService] Failed to sync workout to HealthKit: \(error)")
        }
    }

    // MARK: - Notifications

    @MainActor
    private func postWorkoutStatusNotification(isActive: Bool) {
        NotificationCenter.default.post(
            name: .workoutStatusChanged,
            object: nil,
            userInfo: ["status": isActive]
        )
    }

    @MainActor
    private func postLocationUpdateNotification(_ location: CLLocation) {
        NotificationCenter.default.post(
            name: .locationUpdate,
            object: nil,
            userInfo: ["currentLocation": location]
        )
    }

    @MainActor
    private func postWorkoutUpdatesNotification(_ snapshot: WorkoutSnapshot) {
        NotificationCenter.default.post(
            name: .workoutUpdatesAvailable,
            object: nil,
            userInfo: ["stats": snapshot]
        )
    }

    private func postPeakSpeedNotification() async {
        // Only post if workout has been running for a minimum duration
        // Access metrics on self (actor-isolated), then access duration on MainActor
        guard let m = metrics else { return }
        let duration = await m.duration
        guard duration > Self.minimumSummaryDuration else { return }

        // This could trigger a haptic/audio feedback for peak speed
        // The delegate pattern from legacy code is replaced with notifications
    }
}

// MARK: - WorkoutServiceObserver

/// A convenience wrapper for observing workout service events.
///
/// This class provides a Combine-based interface for UI components
/// to observe workout state changes.
@MainActor
public final class WorkoutServiceObserver: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isWorkoutActive: Bool = false
    @Published public private(set) var currentSnapshot: WorkoutSnapshot = .empty
    @Published public private(set) var currentLocation: CLLocation?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupObservers()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .workoutStatusChanged)
            .compactMap { $0.userInfo?["status"] as? Bool }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.isWorkoutActive = isActive
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .workoutUpdatesAvailable)
            .compactMap { $0.userInfo?["stats"] as? WorkoutSnapshot }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.currentSnapshot = snapshot
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .locationUpdate)
            .compactMap { $0.userInfo?["currentLocation"] as? CLLocation }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location
            }
            .store(in: &cancellables)
    }
}

// MARK: - WorkoutSummary

/// Summary of a completed workout.
public struct WorkoutSummary: Sendable, Equatable {

    /// Workout session ID.
    public let workoutID: String

    /// Final workout metrics.
    public let metrics: WorkoutSnapshot

    /// Start time of the workout.
    public let startTime: Date

    /// End time of the workout.
    public let endTime: Date

    /// Brief text summary for display.
    public var briefSummary: String {
        let distanceKm = String(format: "%.2f", metrics.distanceInKilometers)
        let duration = metrics.formattedDuration
        let calories = metrics.caloriesBurned

        return "Distance: \(distanceKm) km | Duration: \(duration) | Calories: \(calories)"
    }
}
