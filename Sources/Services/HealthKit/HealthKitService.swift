//
//  HealthKitService.swift
//  JogPod
//
//  Modern HealthKit integration using Swift concurrency.
//
//  This service replaces the legacy HKStoreHelper class with a modern
//  actor-based implementation that uses async/await patterns.
//

import Foundation
import HealthKit
import CoreLocation

// MARK: - HealthKitServiceProtocol

/// Protocol defining the HealthKit service interface for dependency injection.
public protocol HealthKitServiceProtocol: Sendable {

    /// Whether HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Requests authorization to read and write health data.
    func requestAuthorization() async throws

    /// Checks the current authorization status for HealthKit.
    func checkAuthorizationStatus() async -> HealthKitAuthorizationStatus

    /// Saves a workout to HealthKit.
    func saveWorkout(_ workout: HealthKitWorkoutData) async throws

    /// Fetches workouts from HealthKit.
    func fetchWorkouts(
        activityType: HKWorkoutActivityType?,
        startDate: Date?,
        endDate: Date?,
        limit: Int
    ) async throws -> [HealthKitWorkoutResult]

    /// Fetches user profile data from HealthKit.
    func fetchUserData() async throws -> HealthKitUserData

    /// Reads the latest body mass value from HealthKit.
    func fetchLatestBodyMass() async throws -> Double?

    /// Reads the user's date of birth from HealthKit.
    func fetchDateOfBirth() async throws -> Date?

    /// Fetches the GPS route data associated with a workout.
    func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [RoutePoint]

    /// Fetches the GPS route data for a workout identified by UUID.
    func fetchWorkoutRoute(workoutID: UUID) async throws -> [RoutePoint]
}

// MARK: - HealthKitAuthorizationStatus

/// The current authorization status for HealthKit access.
public enum HealthKitAuthorizationStatus: Sendable, Equatable {
    /// Authorization has not been requested yet.
    case notDetermined

    /// User has authorized access.
    case authorized

    /// User has denied access.
    case denied

    /// HealthKit is not available on this device.
    case unavailable
}

// MARK: - HealthKitService

/// Modern HealthKit integration service using Swift actors.
///
/// This actor provides thread-safe access to HealthKit, replacing the legacy
/// `HKStoreHelper` class with a modern async/await-based implementation.
///
/// ## Features
///
/// - Request HealthKit permissions
/// - Read and write workout data
/// - Sync with Apple Health
/// - Read user profile data (age, weight, etc.)
///
/// ## Data Types
///
/// The service requests access to read and write:
/// - Active energy burned (calories)
/// - Distance (walking/running)
/// - Heart rate
/// - Workouts
///
/// And read-only access to:
/// - Date of birth
/// - Body mass (weight)
///
/// ## Usage
///
/// ```swift
/// let healthKit = HealthKitService.shared
///
/// // Request authorization
/// try await healthKit.requestAuthorization()
///
/// // Save a workout
/// let workout = HealthKitWorkoutData(
///     startTime: startDate,
///     endTime: endDate,
///     activityType: .running,
///     totalEnergyBurned: 350,
///     totalDistance: 5000,
///     distanceUnit: .meters
/// )
/// try await healthKit.saveWorkout(workout)
/// ```
///
/// ## Thread Safety
///
/// This service is implemented as an actor, ensuring all operations are
/// thread-safe and can be called from any context.
public actor HealthKitService: HealthKitServiceProtocol {

    // MARK: - Shared Instance

    /// The shared HealthKit service instance.
    public static let shared = HealthKitService()

    // MARK: - Private Properties

    /// The underlying HealthKit store.
    private let healthStore: HKHealthStore

    /// Whether HealthKit initialization succeeded.
    private let _isAvailable: Bool

    // MARK: - HealthKit Types

    /// Types we want to read from HealthKit.
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Quantity types
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }

        // Characteristic types
        if let dateOfBirth = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dateOfBirth)
        }

        // Workout type
        types.insert(HKObjectType.workoutType())

        // Workout route type for reading GPS data
        types.insert(HKSeriesType.workoutRoute())

        return types
    }

    /// Types we want to write to HealthKit.
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()

        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        types.insert(HKObjectType.workoutType())

        // Workout route type for saving GPS data
        types.insert(HKSeriesType.workoutRoute())

        return types
    }

    // MARK: - Initialization

    /// Creates a new HealthKit service.
    ///
    /// - Parameter healthStore: Optional custom HKHealthStore for testing.
    public init(healthStore: HKHealthStore? = nil) {
        self._isAvailable = HKHealthStore.isHealthDataAvailable()

        if let store = healthStore {
            self.healthStore = store
        } else if self._isAvailable {
            self.healthStore = HKHealthStore()
        } else {
            // Create a dummy store for unavailable platforms
            // This won't be used but satisfies initialization requirements
            self.healthStore = HKHealthStore()
        }
    }

    // MARK: - Public Properties

    /// Whether HealthKit is available on this device.
    nonisolated public var isAvailable: Bool {
        _isAvailable
    }

    // MARK: - Authorization

    /// Requests authorization to read and write health data.
    ///
    /// This method presents the HealthKit authorization sheet to the user.
    /// The user can choose which data types to allow access to.
    ///
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    /// - Throws: `HealthKitError.authorizationFailed` if the request fails.
    public func requestAuthorization() async throws {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: writeTypes,
                read: readTypes
            )
        } catch {
            throw HealthKitError.authorizationFailed(error.localizedDescription)
        }
    }

    /// Checks the current authorization status for HealthKit.
    ///
    /// - Returns: The current authorization status.
    public func checkAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        guard _isAvailable else {
            return .unavailable
        }

        // Check authorization for workout type as a representative sample
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)

        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }

    // MARK: - Saving Workouts

    /// Saves a workout to HealthKit.
    ///
    /// This method creates an HKWorkout with the provided data and saves it
    /// to HealthKit. Optionally, it can also save associated heart rate samples
    /// and workout route data.
    ///
    /// - Parameter workout: The workout data to save.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    /// - Throws: `HealthKitError.invalidWorkoutData` if the workout data is invalid.
    /// - Throws: `HealthKitError.workoutSaveFailed` if saving fails.
    public func saveWorkout(_ workout: HealthKitWorkoutData) async throws {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        guard workout.isValid else {
            throw HealthKitError.invalidWorkoutData(
                "End time must be after start time and values must be non-negative"
            )
        }

        // Create energy and distance quantities
        let energyBurned = HKQuantity(
            unit: .kilocalorie(),
            doubleValue: workout.totalEnergyBurned
        )

        let distance = HKQuantity(
            unit: workout.distanceUnit.hkUnit,
            doubleValue: workout.totalDistance
        )

        // Create the workout
        let hkWorkout = HKWorkout(
            activityType: workout.activityType,
            start: workout.startTime,
            end: workout.endTime,
            duration: workout.duration,
            totalEnergyBurned: energyBurned,
            totalDistance: distance,
            metadata: workout.metadata
        )

        // Save the workout
        do {
            try await healthStore.save(hkWorkout)
        } catch {
            throw HealthKitError.workoutSaveFailed(error.localizedDescription)
        }

        // Save heart rate samples if provided
        if !workout.heartRateSamples.isEmpty {
            try await saveHeartRateSamples(
                workout.heartRateSamples,
                associatedWith: hkWorkout
            )
        }

        // Save route data if provided
        if !workout.routePoints.isEmpty {
            try await saveWorkoutRoute(
                workout.routePoints,
                associatedWith: hkWorkout
            )
        }
    }

    /// Saves heart rate samples associated with a workout.
    ///
    /// - Parameters:
    ///   - samples: The heart rate samples to save.
    ///   - workout: The workout to associate the samples with.
    private func saveHeartRateSamples(
        _ samples: [HeartRateSample],
        associatedWith workout: HKWorkout
    ) async throws {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.dataTypeNotAvailable("heartRate")
        }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())

        let hkSamples: [HKQuantitySample] = samples.map { sample in
            let quantity = HKQuantity(unit: heartRateUnit, doubleValue: sample.beatsPerMinute)
            return HKQuantitySample(
                type: heartRateType,
                quantity: quantity,
                start: sample.timestamp,
                end: sample.timestamp
            )
        }

        do {
            try await healthStore.save(hkSamples)

            // Add samples to the workout
            try await healthStore.addSamples(hkSamples, to: workout)
        } catch {
            throw HealthKitError.sampleSaveFailed(error.localizedDescription)
        }
    }

    // MARK: - Saving Workout Routes

    /// Saves GPS route data associated with a workout using HKWorkoutRouteBuilder.
    ///
    /// This method creates an HKWorkoutRoute from the provided route points and
    /// associates it with the workout. The route will be visible in Apple Health
    /// and on the workout map.
    ///
    /// - Parameters:
    ///   - routePoints: Array of GPS coordinates with timestamps.
    ///   - workout: The workout to associate the route with.
    /// - Throws: `HealthKitError.insufficientRouteData` if fewer than 2 points.
    /// - Throws: `HealthKitError.routeSaveFailed` if saving fails.
    private func saveWorkoutRoute(
        _ routePoints: [RoutePoint],
        associatedWith workout: HKWorkout
    ) async throws {
        // Route needs at least 2 points to be meaningful
        guard routePoints.count >= 2 else {
            throw HealthKitError.insufficientRouteData
        }

        // Create CLLocations from RoutePoints
        let locations = routePoints.map { point -> CLLocation in
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: point.latitude,
                    longitude: point.longitude
                ),
                altitude: point.altitude,
                horizontalAccuracy: point.horizontalAccuracy,
                verticalAccuracy: point.verticalAccuracy,
                timestamp: point.timestamp
            )
        }

        // Create route builder
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

        do {
            // Insert all location data
            try await routeBuilder.insertRouteData(locations)

            // Finalize the route and associate with workout
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        } catch {
            throw HealthKitError.routeSaveFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetching Workouts

    /// Fetches workouts from HealthKit.
    ///
    /// - Parameters:
    ///   - activityType: Optional filter for workout activity type.
    ///   - startDate: Optional start date filter.
    ///   - endDate: Optional end date filter.
    ///   - limit: Maximum number of workouts to return (default: 100).
    /// - Returns: An array of workout results.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    /// - Throws: `HealthKitError.workoutReadFailed` if the query fails.
    public func fetchWorkouts(
        activityType: HKWorkoutActivityType? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [HealthKitWorkoutResult] {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        // Build predicate
        var predicates: [NSPredicate] = []

        if let activityType = activityType {
            predicates.append(
                HKQuery.predicateForWorkouts(with: activityType)
            )
        }

        if let startDate = startDate, let endDate = endDate {
            predicates.append(
                HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: endDate,
                    options: .strictStartDate
                )
            )
        } else if let startDate = startDate {
            predicates.append(
                HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: nil,
                    options: .strictStartDate
                )
            )
        } else if let endDate = endDate {
            predicates.append(
                HKQuery.predicateForSamples(
                    withStart: nil,
                    end: endDate,
                    options: .strictEndDate
                )
            )
        }

        let predicate: NSPredicate?
        if predicates.isEmpty {
            predicate = nil
        } else if predicates.count == 1 {
            predicate = predicates.first
        } else {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // Sort by start date descending (most recent first)
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        // Execute query using async/await
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.workoutReadFailed(error.localizedDescription))
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                let results = workouts.map { HealthKitWorkoutResult.from($0) }
                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches the most recent workout from HealthKit.
    ///
    /// - Parameter activityType: Optional filter for workout type.
    /// - Returns: The most recent workout, or nil if none found.
    public func fetchMostRecentWorkout(
        activityType: HKWorkoutActivityType? = nil
    ) async throws -> HealthKitWorkoutResult? {
        let workouts = try await fetchWorkouts(
            activityType: activityType,
            startDate: nil,
            endDate: nil,
            limit: 1
        )
        return workouts.first
    }

    // MARK: - User Data

    /// Fetches user profile data from HealthKit.
    ///
    /// This includes date of birth, biological sex, and the latest body mass reading.
    ///
    /// - Returns: User health data from HealthKit.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    public func fetchUserData() async throws -> HealthKitUserData {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        let dateOfBirth = try? await fetchDateOfBirth()
        let biologicalSex = try? fetchBiologicalSex()
        let bodyMass = try? await fetchLatestBodyMass()

        return HealthKitUserData(
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            bodyMassKg: bodyMass,
            heightMeters: nil // Height reading would require additional query
        )
    }

    /// Reads the user's date of birth from HealthKit.
    ///
    /// - Returns: The user's date of birth, or nil if not available.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    public func fetchDateOfBirth() async throws -> Date? {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        do {
            let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: dateOfBirthComponents)
        } catch {
            // Date of birth not available - this is not an error condition
            return nil
        }
    }

    /// Reads the user's biological sex from HealthKit.
    ///
    /// - Returns: The user's biological sex, or nil if not available.
    private func fetchBiologicalSex() throws -> HKBiologicalSex? {
        do {
            let biologicalSex = try healthStore.biologicalSex()
            return biologicalSex.biologicalSex
        } catch {
            return nil
        }
    }

    /// Reads the latest body mass value from HealthKit.
    ///
    /// - Returns: The body mass in kilograms, or nil if not available.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    public func fetchLatestBodyMass() async throws -> Double? {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataReadFailed(
                        dataType: "bodyMass",
                        reason: error.localizedDescription
                    ))
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let massInKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: massInKg)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Fetching Workout Routes

    /// Fetches the GPS route data associated with a workout.
    ///
    /// This method queries HealthKit for HKWorkoutRoute objects associated with
    /// the specified workout and returns the GPS coordinates as RoutePoint array.
    ///
    /// - Parameter workout: The HKWorkout to fetch routes for.
    /// - Returns: An array of RoutePoint coordinates, or empty array if no route exists.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    /// - Throws: `HealthKitError.routeReadFailed` if reading fails.
    public func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [RoutePoint] {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        // Query for routes associated with this workout
        let routes = try await fetchRoutes(for: workout)

        guard let route = routes.first else {
            return []
        }

        // Extract location data from the route
        return try await fetchRouteLocations(from: route)
    }

    /// Fetches the GPS route data for a workout identified by UUID.
    ///
    /// This is a convenience method that first fetches the workout by UUID,
    /// then retrieves its associated route data.
    ///
    /// - Parameter workoutID: The UUID of the workout.
    /// - Returns: An array of RoutePoint coordinates, or empty array if no route exists.
    /// - Throws: `HealthKitError.healthKitNotAvailable` if HealthKit is unavailable.
    /// - Throws: `HealthKitError.workoutReadFailed` if workout not found.
    /// - Throws: `HealthKitError.routeReadFailed` if reading route fails.
    public func fetchWorkoutRoute(workoutID: UUID) async throws -> [RoutePoint] {
        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        // Fetch the workout by UUID
        let predicate = HKQuery.predicateForObject(with: workoutID)

        let workout: HKWorkout = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.workoutReadFailed(error.localizedDescription)
                    )
                    return
                }

                guard let hkWorkout = samples?.first as? HKWorkout else {
                    continuation.resume(
                        throwing: HealthKitError.workoutReadFailed("Workout not found")
                    )
                    return
                }

                continuation.resume(returning: hkWorkout)
            }

            healthStore.execute(query)
        }

        return try await fetchWorkoutRoute(for: workout)
    }

    /// Fetches HKWorkoutRoute samples associated with a workout.
    ///
    /// - Parameter workout: The workout to query routes for.
    /// - Returns: Array of HKWorkoutRoute samples.
    private func fetchRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.routeReadFailed(error.localizedDescription)
                    )
                    return
                }

                let routes = (samples as? [HKWorkoutRoute]) ?? []
                continuation.resume(returning: routes)
            }

            healthStore.execute(query)
        }
    }

    /// Extracts GPS location data from an HKWorkoutRoute.
    ///
    /// - Parameter route: The HKWorkoutRoute to extract locations from.
    /// - Returns: Array of RoutePoint coordinates.
    private func fetchRouteLocations(from route: HKWorkoutRoute) async throws -> [RoutePoint] {
        var allLocations: [RoutePoint] = []

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.routeReadFailed(error.localizedDescription)
                    )
                    return
                }

                if let locations = locations {
                    let routePoints = locations.map { location -> RoutePoint in
                        RoutePoint(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            altitude: location.altitude,
                            horizontalAccuracy: location.horizontalAccuracy,
                            verticalAccuracy: location.verticalAccuracy,
                            timestamp: location.timestamp
                        )
                    }
                    allLocations.append(contentsOf: routePoints)
                }

                if done {
                    continuation.resume(returning: allLocations)
                }
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Convenience Extensions

extension HealthKitService {

    /// Saves workout data from a WorkoutSnapshot and session info.
    ///
    /// This is a convenience method that creates HealthKitWorkoutData from
    /// the app's workout data model.
    ///
    /// - Parameters:
    ///   - snapshot: The workout metrics snapshot.
    ///   - startTime: When the workout started.
    ///   - endTime: When the workout ended.
    ///   - isMetric: Whether to use metric units.
    /// - Throws: HealthKitError if saving fails.
    public func saveWorkoutFromSnapshot(
        _ snapshot: WorkoutSnapshot,
        startTime: Date,
        endTime: Date,
        isMetric: Bool = true
    ) async throws {
        let workoutData = HealthKitWorkoutData(
            startTime: startTime,
            endTime: endTime,
            activityType: .running,
            totalEnergyBurned: Double(snapshot.caloriesBurned),
            totalDistance: snapshot.totalDistance,
            distanceUnit: .meters
        )

        try await saveWorkout(workoutData)
    }
}
