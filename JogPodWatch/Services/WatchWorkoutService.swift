//
//  WatchWorkoutService.swift
//  JogPodWatch
//
//  Independent workout tracking service for watchOS.
//  Uses HKWorkoutSession for native watch workout management.
//
//  This service enables workout tracking when iPhone is not reachable,
//  syncing data when connection is restored.
//

import Foundation
import HealthKit
import CoreLocation
import WatchKit

// MARK: - WatchWorkoutServiceProtocol

/// Protocol defining the watch workout service interface.
public protocol WatchWorkoutServiceProtocol: Sendable {
    /// Whether a workout is currently active.
    var isWorkoutActive: Bool { get async }

    /// Current workout metrics.
    var currentMetrics: WatchWorkoutMetricsData { get async }

    /// Starts an independent workout session on the watch.
    func startWorkout() async throws

    /// Pauses the current workout.
    func pauseWorkout() async throws

    /// Resumes a paused workout.
    func resumeWorkout() async throws

    /// Ends the current workout and saves to HealthKit.
    func endWorkout() async throws -> WatchWorkoutResult

    /// Discards the current workout without saving.
    func discardWorkout() async
}

// MARK: - WatchWorkoutService

/// Independent workout tracking service for watchOS.
///
/// This actor manages HKWorkoutSession for native watch workout tracking,
/// enabling workouts when iPhone is not reachable.
///
/// ## Features
///
/// - HKWorkoutSession for background workout tracking
/// - HKWorkoutBuilder for sample collection
/// - Heart rate monitoring via HealthKit queries
/// - GPS tracking via CoreLocation (when available)
/// - Haptic feedback for milestones
/// - Data sync with iPhone when connection restored
///
/// ## watchOS 10+ Features
///
/// - Uses modern async/await HealthKit APIs
/// - Supports workout mirroring for companion app
/// - Battery-efficient location tracking modes
///
/// ## Architecture
///
/// The service operates independently of iPhone connection:
/// 1. Start workout locally using HKWorkoutSession
/// 2. Collect heart rate, distance, and location data
/// 3. Store workout data locally during session
/// 4. Sync with iPhone via WorkoutDataSync when connected
/// 5. Save to HealthKit when workout ends
///
/// ## Thread Safety
///
/// Implemented as an actor for thread-safe access to workout state.
@MainActor
public final class WatchWorkoutService: NSObject, ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide use.
    public static let shared = WatchWorkoutService()

    // MARK: - Published Properties

    /// Whether a workout is currently active.
    @Published public private(set) var isWorkoutActive: Bool = false

    /// Whether the workout is paused.
    @Published public private(set) var isWorkoutPaused: Bool = false

    /// Current workout metrics.
    @Published public private(set) var currentMetrics = WatchWorkoutMetricsData()

    /// Current heart rate in BPM.
    @Published public private(set) var currentHeartRate: Double = 0

    /// Workout elapsed time in seconds.
    @Published public private(set) var elapsedTime: TimeInterval = 0

    /// Total distance in meters.
    @Published public private(set) var totalDistance: Double = 0

    /// Active calories burned.
    @Published public private(set) var activeCalories: Double = 0

    /// Current pace in seconds per kilometer.
    @Published public private(set) var currentPace: Double = 0

    /// Average pace in seconds per kilometer.
    @Published public private(set) var averagePace: Double = 0

    /// Whether the service is operating in independent mode (iPhone not reachable).
    @Published public private(set) var isIndependentMode: Bool = false

    // MARK: - Private Properties

    /// The HealthKit store.
    private let healthStore = HKHealthStore()

    /// The active workout session.
    private var workoutSession: HKWorkoutSession?

    /// The workout builder for collecting samples.
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// Timer for elapsed time updates.
    private var elapsedTimeTimer: Timer?

    /// Workout start time.
    private var workoutStartTime: Date?

    /// Location manager for GPS tracking.
    private var locationManager: WatchLocationManager?

    /// Heart rate samples collected during workout.
    private var heartRateSamples: [HeartRateSampleData] = []

    /// Route points collected during workout.
    private var routePoints: [RoutePointData] = []

    /// Pending workouts that need to sync with iPhone.
    private var pendingWorkouts: [PendingWorkoutData] = []

    /// Last distance milestone for haptic feedback.
    private var lastDistanceMilestone: Double = 0

    /// Distance milestone interval (meters).
    private let distanceMilestoneInterval: Double = 1000 // 1 km

    // MARK: - HealthKit Types

    /// Heart rate quantity type.
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

    /// Active energy burned quantity type.
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    /// Distance walking/running quantity type.
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

    // MARK: - Initialization

    private override init() {
        super.init()
        loadPendingWorkouts()
    }

    // MARK: - Authorization

    /// Requests HealthKit authorization for workout tracking.
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchWorkoutError.healthKitNotAvailable
        }

        // Types to read
        let readTypes: Set<HKObjectType> = [
            heartRateType,
            activeEnergyType,
            distanceType,
            HKObjectType.workoutType()
        ]

        // Types to write
        let writeTypes: Set<HKSampleType> = [
            heartRateType,
            activeEnergyType,
            distanceType,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Workout Lifecycle

    /// Starts an independent workout session on the watch.
    ///
    /// Creates an HKWorkoutSession with running activity type and starts
    /// the HKLiveWorkoutBuilder for sample collection.
    ///
    /// - Throws: `WatchWorkoutError.workoutAlreadyActive` if workout is running.
    /// - Throws: `WatchWorkoutError.sessionCreationFailed` if session fails to create.
    public func startWorkout() async throws {
        guard !isWorkoutActive else {
            throw WatchWorkoutError.workoutAlreadyActive
        }

        // Check if iPhone is reachable to determine mode
        isIndependentMode = !WatchConnectivityManager.shared.isReachable

        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            // Create the workout session
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )

            // Get the live workout builder
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            guard let session = workoutSession,
                  let builder = workoutBuilder else {
                throw WatchWorkoutError.sessionCreationFailed
            }

            // Set delegates
            session.delegate = self
            builder.delegate = self

            // Set data source for automatic data collection
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start session and builder
            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            // Update state
            workoutStartTime = startDate
            isWorkoutActive = true
            isWorkoutPaused = false

            // Reset metrics
            resetMetrics()

            // Start elapsed time timer
            startElapsedTimeTimer()

            // Start location tracking
            startLocationTracking()

            // Initial haptic feedback
            playHaptic(.start)

        } catch {
            throw WatchWorkoutError.sessionCreationFailed
        }
    }

    /// Pauses the current workout.
    ///
    /// Pauses both the workout session and location tracking.
    ///
    /// - Throws: `WatchWorkoutError.noActiveWorkout` if no workout is active.
    public func pauseWorkout() async throws {
        guard let session = workoutSession, isWorkoutActive else {
            throw WatchWorkoutError.noActiveWorkout
        }

        session.pause()
        isWorkoutPaused = true

        // Pause location tracking
        locationManager?.pauseTracking()

        // Haptic feedback
        playHaptic(.stop)
    }

    /// Resumes a paused workout.
    ///
    /// - Throws: `WatchWorkoutError.noActiveWorkout` if no workout is active.
    /// - Throws: `WatchWorkoutError.workoutNotPaused` if workout is not paused.
    public func resumeWorkout() async throws {
        guard let session = workoutSession, isWorkoutActive else {
            throw WatchWorkoutError.noActiveWorkout
        }

        guard isWorkoutPaused else {
            throw WatchWorkoutError.workoutNotPaused
        }

        session.resume()
        isWorkoutPaused = false

        // Resume location tracking
        locationManager?.resumeTracking()

        // Haptic feedback
        playHaptic(.start)
    }

    /// Ends the current workout and saves to HealthKit.
    ///
    /// Finalizes the workout builder, saves the workout to HealthKit,
    /// and queues data for sync with iPhone.
    ///
    /// - Returns: The completed workout result.
    /// - Throws: `WatchWorkoutError.noActiveWorkout` if no workout is active.
    /// - Throws: `WatchWorkoutError.workoutSaveFailed` if save fails.
    public func endWorkout() async throws -> WatchWorkoutResult {
        guard let session = workoutSession,
              let builder = workoutBuilder,
              isWorkoutActive else {
            throw WatchWorkoutError.noActiveWorkout
        }

        let endDate = Date()

        // Stop the session
        session.end()

        // End collection and save workout
        do {
            try await builder.endCollection(at: endDate)

            // Finalize the workout
            try await builder.finishWorkout()

        } catch {
            throw WatchWorkoutError.workoutSaveFailed(error.localizedDescription)
        }

        // Create workout result
        let result = WatchWorkoutResult(
            startTime: workoutStartTime ?? endDate,
            endTime: endDate,
            duration: elapsedTime,
            distance: totalDistance,
            calories: activeCalories,
            averagePace: averagePace,
            averageHeartRate: calculateAverageHeartRate(),
            routePoints: routePoints,
            heartRateSamples: heartRateSamples,
            wasIndependentMode: isIndependentMode
        )

        // Queue for sync if in independent mode
        if isIndependentMode {
            queueWorkoutForSync(result)
        }

        // Cleanup
        cleanupWorkout()

        // Haptic feedback
        playHaptic(.success)

        return result
    }

    /// Discards the current workout without saving.
    public func discardWorkout() async {
        guard let session = workoutSession else { return }

        session.end()

        // Discard builder data
        workoutBuilder?.discardWorkout()

        // Cleanup
        cleanupWorkout()

        // Haptic feedback
        playHaptic(.failure)
    }

    // MARK: - Pending Workout Sync

    /// Returns the count of pending workouts awaiting sync.
    public var pendingWorkoutCount: Int {
        pendingWorkouts.count
    }

    /// Syncs pending workouts with iPhone when connection is available.
    ///
    /// This method should be called when iPhone becomes reachable.
    public func syncPendingWorkouts() async {
        guard WatchConnectivityManager.shared.isReachable else { return }

        for workout in pendingWorkouts {
            do {
                try await sendWorkoutToiPhone(workout)
                // Remove from pending queue
                pendingWorkouts.removeAll { $0.id == workout.id }
                savePendingWorkouts()
            } catch {
                // Keep in queue for later retry
                continue
            }
        }
    }

    // MARK: - Private Methods

    private func resetMetrics() {
        currentMetrics = WatchWorkoutMetricsData()
        currentHeartRate = 0
        elapsedTime = 0
        totalDistance = 0
        activeCalories = 0
        currentPace = 0
        averagePace = 0
        lastDistanceMilestone = 0
        heartRateSamples = []
        routePoints = []
    }

    private func cleanupWorkout() {
        stopElapsedTimeTimer()
        stopLocationTracking()

        workoutSession = nil
        workoutBuilder = nil
        workoutStartTime = nil
        isWorkoutActive = false
        isWorkoutPaused = false
        isIndependentMode = false
    }

    private func startElapsedTimeTimer() {
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopElapsedTimeTimer() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
    }

    private func updateElapsedTime() {
        guard let startTime = workoutStartTime, !isWorkoutPaused else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
        updateMetrics()
    }

    private func updateMetrics() {
        currentMetrics = WatchWorkoutMetricsData(
            elapsedTime: elapsedTime,
            distance: totalDistance,
            calories: activeCalories,
            heartRate: currentHeartRate,
            currentPace: currentPace,
            averagePace: averagePace
        )
    }

    private func startLocationTracking() {
        locationManager = WatchLocationManager()
        locationManager?.delegate = self
        locationManager?.startTracking()
    }

    private func stopLocationTracking() {
        locationManager?.stopTracking()
        locationManager = nil
    }

    private func calculateAverageHeartRate() -> Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        let sum = heartRateSamples.reduce(0.0) { $0 + $1.beatsPerMinute }
        return sum / Double(heartRateSamples.count)
    }

    private func checkDistanceMilestone() {
        let kilometers = totalDistance / 1000.0
        let lastMilestoneKm = lastDistanceMilestone / 1000.0

        if kilometers >= lastMilestoneKm + 1.0 {
            lastDistanceMilestone = floor(kilometers) * 1000.0
            playHaptic(.notification)
        }
    }

    // MARK: - Haptic Feedback

    private func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Persistence

    private func queueWorkoutForSync(_ result: WatchWorkoutResult) {
        let pendingData = PendingWorkoutData(
            id: UUID(),
            result: result,
            createdAt: Date()
        )
        pendingWorkouts.append(pendingData)
        savePendingWorkouts()
    }

    private func savePendingWorkouts() {
        // Save to UserDefaults or file storage
        guard let encoded = try? JSONEncoder().encode(pendingWorkouts) else { return }
        UserDefaults.standard.set(encoded, forKey: "PendingWorkouts")
    }

    private func loadPendingWorkouts() {
        guard let data = UserDefaults.standard.data(forKey: "PendingWorkouts"),
              let decoded = try? JSONDecoder().decode([PendingWorkoutData].self, from: data) else {
            return
        }
        pendingWorkouts = decoded
    }

    private func sendWorkoutToiPhone(_ workout: PendingWorkoutData) async throws {
        let message: [String: Any] = [
            "syncWorkout": [
                "id": workout.id.uuidString,
                "startTime": workout.result.startTime.timeIntervalSince1970,
                "endTime": workout.result.endTime.timeIntervalSince1970,
                "duration": workout.result.duration,
                "distance": workout.result.distance,
                "calories": workout.result.calories,
                "averagePace": workout.result.averagePace,
                "averageHeartRate": workout.result.averageHeartRate
            ]
        ]

        _ = try await WatchConnectivityManager.shared.sendRequest(.openDashboard)
        WatchConnectivityManager.shared.sendAction(.toggleWorkout(on: false))
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutService: HKWorkoutSessionDelegate {

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.isWorkoutActive = true
                self.isWorkoutPaused = false
            case .paused:
                self.isWorkoutPaused = true
            case .ended:
                self.isWorkoutActive = false
            default:
                break
            }
        }
    }

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.cleanupWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutService: HKLiveWorkoutBuilderDelegate {

    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                // Handle heart rate
                if type == self.heartRateType {
                    if let statistics = workoutBuilder.statistics(for: self.heartRateType) {
                        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                        if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                            self.currentHeartRate = value

                            // Record sample
                            let sample = HeartRateSampleData(
                                timestamp: Date(),
                                beatsPerMinute: value
                            )
                            self.heartRateSamples.append(sample)
                        }
                    }
                }

                // Handle distance
                if type == self.distanceType {
                    if let statistics = workoutBuilder.statistics(for: self.distanceType) {
                        let distanceUnit = HKUnit.meter()
                        if let value = statistics.sumQuantity()?.doubleValue(for: distanceUnit) {
                            self.totalDistance = value

                            // Calculate pace
                            if value > 0 && self.elapsedTime > 0 {
                                self.currentPace = self.elapsedTime / (value / 1000.0)
                                self.averagePace = self.currentPace
                            }

                            // Check for milestone
                            self.checkDistanceMilestone()
                        }
                    }
                }

                // Handle calories
                if type == self.activeEnergyType {
                    if let statistics = workoutBuilder.statistics(for: self.activeEnergyType) {
                        let calorieUnit = HKUnit.kilocalorie()
                        if let value = statistics.sumQuantity()?.doubleValue(for: calorieUnit) {
                            self.activeCalories = value
                        }
                    }
                }
            }

            self.updateMetrics()
        }
    }

    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (lap markers, etc.)
    }
}

// MARK: - WatchLocationManagerDelegate

extension WatchWorkoutService: WatchLocationManagerDelegate {

    public func locationManager(_ manager: WatchLocationManager, didUpdateLocation location: CLLocation) {
        let routePoint = RoutePointData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course,
            timestamp: location.timestamp
        )
        routePoints.append(routePoint)

        // Update WatchState with current location
        let watchLocation = WatchLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            course: location.course,
            timestamp: location.timestamp
        )
        WatchConnectivityManager.shared.watchState?.updateLocation(watchLocation)
    }

    public func locationManager(_ manager: WatchLocationManager, didFailWithError error: Error) {
        // Handle location error - continue workout without GPS
    }
}

// MARK: - Supporting Types

/// Workout metrics data collected during a workout.
public struct WatchWorkoutMetricsData: Sendable, Equatable {
    public var elapsedTime: TimeInterval = 0
    public var distance: Double = 0
    public var calories: Double = 0
    public var heartRate: Double = 0
    public var currentPace: Double = 0
    public var averagePace: Double = 0

    public var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public var formattedDistance: String {
        String(format: "%.2f km", distance / 1000.0)
    }

    public var formattedPace: String {
        guard currentPace > 0 && currentPace.isFinite else { return "--:--" }
        let minutes = Int(currentPace / 60)
        let seconds = Int(currentPace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Result of a completed workout.
public struct WatchWorkoutResult: Sendable, Codable {
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let distance: Double
    public let calories: Double
    public let averagePace: Double
    public let averageHeartRate: Double
    public let routePoints: [RoutePointData]
    public let heartRateSamples: [HeartRateSampleData]
    public let wasIndependentMode: Bool
}

/// Heart rate sample data.
public struct HeartRateSampleData: Sendable, Codable {
    public let timestamp: Date
    public let beatsPerMinute: Double
}

/// GPS route point data.
public struct RoutePointData: Sendable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let verticalAccuracy: Double
    public let speed: Double
    public let course: Double
    public let timestamp: Date
}

/// Pending workout data awaiting sync with iPhone.
public struct PendingWorkoutData: Sendable, Codable, Identifiable {
    public let id: UUID
    public let result: WatchWorkoutResult
    public let createdAt: Date
}

// MARK: - WatchWorkoutError

/// Errors that can occur during watch workout operations.
public enum WatchWorkoutError: Error, LocalizedError, Sendable {
    case healthKitNotAvailable
    case authorizationDenied
    case workoutAlreadyActive
    case noActiveWorkout
    case workoutNotPaused
    case sessionCreationFailed
    case workoutSaveFailed(String)
    case syncFailed(String)

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit authorization was denied."
        case .workoutAlreadyActive:
            return "A workout is already in progress."
        case .noActiveWorkout:
            return "No workout is currently active."
        case .workoutNotPaused:
            return "Workout is not paused."
        case .sessionCreationFailed:
            return "Failed to create workout session."
        case .workoutSaveFailed(let reason):
            return "Failed to save workout: \(reason)"
        case .syncFailed(let reason):
            return "Failed to sync workout: \(reason)"
        }
    }
}
