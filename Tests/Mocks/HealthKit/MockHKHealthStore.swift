//
//  MockHKHealthStore.swift
//  JogPodTests
//
//  Mock implementation of HKHealthStore for testing HealthKit operations.
//  Provides configurable behavior for simulating authorization, workout saving,
//  data queries, and error conditions.
//

import Foundation
import HealthKit
@testable import JogPod

// MARK: - HKHealthStoreProtocol

/// Protocol abstracting HKHealthStore for dependency injection and testing.
///
/// This protocol extracts the key methods from HKHealthStore that are used
/// by HealthKitService, allowing for mock implementations in tests.
public protocol HKHealthStoreProtocol: Sendable {

    /// Whether HealthKit is available on this device.
    static func isHealthDataAvailable() -> Bool

    /// Requests authorization to share and read the specified data types.
    func requestAuthorization(
        toShare typesToShare: Set<HKSampleType>?,
        read typesToRead: Set<HKObjectType>?
    ) async throws

    /// Returns the authorization status for the specified object type.
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus

    /// Saves an object to the HealthKit store.
    func save(_ object: HKObject) async throws

    /// Saves multiple objects to the HealthKit store.
    func save(_ objects: [HKObject]) async throws

    /// Adds samples to a workout.
    func addSamples(_ samples: [HKSample], to workout: HKWorkout) async throws

    /// Executes a query against the HealthKit store.
    func execute(_ query: HKQuery)

    /// Stops a running query.
    func stop(_ query: HKQuery)

    /// Returns the user's date of birth components.
    func dateOfBirthComponents() throws -> DateComponents

    /// Returns the user's biological sex.
    func biologicalSex() throws -> HKBiologicalSexObject
}

// MARK: - MockHKHealthStore

/// A comprehensive mock implementation of HKHealthStore for testing.
///
/// This mock allows complete control over HealthKit behavior including:
/// - Simulating authorization request results
/// - Controlling save operation success/failure
/// - Returning mock query results
/// - Simulating various error conditions
///
/// ## Usage
///
/// ```swift
/// let mockStore = MockHKHealthStore()
///
/// // Configure authorization behavior
/// await mockStore.setAuthorizationBehavior(.succeed)
///
/// // Configure workout query results
/// await mockStore.setMockWorkouts([mockWorkout1, mockWorkout2])
///
/// // Test error handling
/// await mockStore.setSaveBehavior(.failWith(HKError(.errorAuthorizationNotDetermined)))
/// ```
public actor MockHKHealthStore {

    // MARK: - Configuration

    /// Whether to report HealthKit as available.
    public private(set) static var mockIsHealthDataAvailable: Bool = true

    /// Current authorization status for each type.
    private var authorizationStatuses: [HKObjectType: HKAuthorizationStatus] = [:]

    /// Behavior for authorization requests.
    private var authorizationBehavior: AuthorizationBehavior = .succeed

    /// Behavior for save operations.
    private var saveBehavior: SaveBehavior = .succeed

    /// Mock workouts to return from queries.
    private var mockWorkouts: [HKWorkout] = []

    /// Mock body mass samples to return from queries.
    private var mockBodyMassSamples: [HKQuantitySample] = []

    /// Mock heart rate samples to return from queries.
    private var mockHeartRateSamples: [HKQuantitySample] = []

    /// Mock date of birth.
    private var mockDateOfBirth: DateComponents?

    /// Mock biological sex.
    private var mockBiologicalSex: HKBiologicalSex = .notSet

    /// Delay before operations complete (simulates async behavior).
    private var operationDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Saved objects for verification.
    public private(set) var savedObjects: [HKObject] = []

    /// Saved workouts for verification.
    public private(set) var savedWorkouts: [HKWorkout] = []

    /// Samples added to workouts.
    public private(set) var samplesAddedToWorkouts: [(samples: [HKSample], workout: HKWorkout)] = []

    /// Tracks method call counts.
    private var methodCallCounts: [String: Int] = [:]

    /// Records of method calls with parameters.
    private var methodCallLog: [MethodCall] = []

    /// Executed queries for verification.
    public private(set) var executedQueries: [HKQuery] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Static Configuration

    /// Sets whether HealthKit appears available.
    public static func setHealthDataAvailable(_ available: Bool) {
        mockIsHealthDataAvailable = available
    }

    // MARK: - Configuration Methods

    /// Sets the authorization behavior for requests.
    public func setAuthorizationBehavior(_ behavior: AuthorizationBehavior) {
        authorizationBehavior = behavior
    }

    /// Sets the authorization status for a specific type.
    public func setAuthorizationStatus(_ status: HKAuthorizationStatus, for type: HKObjectType) {
        authorizationStatuses[type] = status
    }

    /// Sets the save operation behavior.
    public func setSaveBehavior(_ behavior: SaveBehavior) {
        saveBehavior = behavior
    }

    /// Sets mock workouts to return from queries.
    public func setMockWorkouts(_ workouts: [HKWorkout]) {
        mockWorkouts = workouts
    }

    /// Sets mock body mass samples to return from queries.
    public func setMockBodyMassSamples(_ samples: [HKQuantitySample]) {
        mockBodyMassSamples = samples
    }

    /// Sets mock heart rate samples to return from queries.
    public func setMockHeartRateSamples(_ samples: [HKQuantitySample]) {
        mockHeartRateSamples = samples
    }

    /// Sets the mock date of birth.
    public func setMockDateOfBirth(_ components: DateComponents?) {
        mockDateOfBirth = components
    }

    /// Sets the mock biological sex.
    public func setMockBiologicalSex(_ sex: HKBiologicalSex) {
        mockBiologicalSex = sex
    }

    /// Sets the operation delay.
    public func setOperationDelay(_ delay: TimeInterval) {
        operationDelay = delay
    }

    // MARK: - Mock Protocol Implementation

    /// Simulates checking HealthKit availability.
    public nonisolated static func isHealthDataAvailable() -> Bool {
        mockIsHealthDataAvailable
    }

    /// Simulates requesting authorization.
    public func requestAuthorization(
        toShare typesToShare: Set<HKSampleType>?,
        read typesToRead: Set<HKObjectType>?
    ) async throws {
        recordMethodCall("requestAuthorization")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        switch authorizationBehavior {
        case .succeed:
            // Set all types to authorized
            if let typesToShare = typesToShare {
                for type in typesToShare {
                    authorizationStatuses[type] = .sharingAuthorized
                }
            }
            if let typesToRead = typesToRead {
                for type in typesToRead {
                    authorizationStatuses[type] = .sharingAuthorized
                }
            }

        case .deny:
            // Set all types to denied
            if let typesToShare = typesToShare {
                for type in typesToShare {
                    authorizationStatuses[type] = .sharingDenied
                }
            }
            if let typesToRead = typesToRead {
                for type in typesToRead {
                    authorizationStatuses[type] = .sharingDenied
                }
            }

        case .failWith(let error):
            throw error

        case .partialAuthorization(let authorizedTypes):
            if let typesToShare = typesToShare {
                for type in typesToShare {
                    if authorizedTypes.contains(type) {
                        authorizationStatuses[type] = .sharingAuthorized
                    } else {
                        authorizationStatuses[type] = .sharingDenied
                    }
                }
            }
        }
    }

    /// Returns the authorization status for a type.
    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        recordMethodCall("authorizationStatus", parameters: ["type": type.identifier])
        return authorizationStatuses[type] ?? .notDetermined
    }

    /// Simulates saving an object.
    public func save(_ object: HKObject) async throws {
        recordMethodCall("save")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        switch saveBehavior {
        case .succeed:
            savedObjects.append(object)
            if let workout = object as? HKWorkout {
                savedWorkouts.append(workout)
            }

        case .failWith(let error):
            throw error

        case .failForTypes(let types):
            if let sample = object as? HKSample, types.contains(sample.sampleType) {
                throw NSError(
                    domain: HKErrorDomain,
                    code: HKError.errorAuthorizationDenied.rawValue,
                    userInfo: nil
                )
            }
            savedObjects.append(object)
            if let workout = object as? HKWorkout {
                savedWorkouts.append(workout)
            }
        }
    }

    /// Simulates saving multiple objects.
    public func save(_ objects: [HKObject]) async throws {
        recordMethodCall("saveMultiple", parameters: ["count": "\(objects.count)"])

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        switch saveBehavior {
        case .succeed:
            savedObjects.append(contentsOf: objects)
            let workouts = objects.compactMap { $0 as? HKWorkout }
            savedWorkouts.append(contentsOf: workouts)

        case .failWith(let error):
            throw error

        case .failForTypes(let types):
            for object in objects {
                if let sample = object as? HKSample, types.contains(sample.sampleType) {
                    throw NSError(
                        domain: HKErrorDomain,
                        code: HKError.errorAuthorizationDenied.rawValue,
                        userInfo: nil
                    )
                }
            }
            savedObjects.append(contentsOf: objects)
            let workouts = objects.compactMap { $0 as? HKWorkout }
            savedWorkouts.append(contentsOf: workouts)
        }
    }

    /// Simulates adding samples to a workout.
    public func addSamples(_ samples: [HKSample], to workout: HKWorkout) async throws {
        recordMethodCall("addSamples", parameters: ["sampleCount": "\(samples.count)"])

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        switch saveBehavior {
        case .succeed:
            samplesAddedToWorkouts.append((samples: samples, workout: workout))

        case .failWith(let error):
            throw error

        case .failForTypes:
            samplesAddedToWorkouts.append((samples: samples, workout: workout))
        }
    }

    /// Simulates executing a query.
    ///
    /// This method handles different query types and returns appropriate mock data.
    public func execute(_ query: HKQuery) {
        recordMethodCall("execute")
        executedQueries.append(query)

        // Handle different query types
        Task {
            if operationDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
            }

            await handleQuery(query)
        }
    }

    /// Simulates stopping a query.
    public func stop(_ query: HKQuery) {
        recordMethodCall("stop")
    }

    /// Returns the mock date of birth.
    public func dateOfBirthComponents() throws -> DateComponents {
        recordMethodCall("dateOfBirthComponents")

        guard let dob = mockDateOfBirth else {
            throw NSError(
                domain: HKErrorDomain,
                code: HKError.errorNoData.rawValue,
                userInfo: nil
            )
        }
        return dob
    }

    /// Returns the mock biological sex.
    public func biologicalSex() throws -> MockBiologicalSexObject {
        recordMethodCall("biologicalSex")
        return MockBiologicalSexObject(biologicalSex: mockBiologicalSex)
    }

    // MARK: - Query Handling

    private func handleQuery(_ query: HKQuery) async {
        // Use reflection to access the query's completion handler
        // This is a simplified approach - in real testing you might need
        // a more sophisticated query handling mechanism

        if let sampleQuery = query as? HKSampleQuery {
            await handleSampleQuery(sampleQuery)
        }
    }

    private func handleSampleQuery(_ query: HKSampleQuery) async {
        // Get the sample type from the query
        let sampleType = query.objectType

        var results: [HKSample] = []

        if sampleType == HKObjectType.workoutType() {
            results = mockWorkouts
        } else if let quantityType = sampleType as? HKQuantityType {
            if quantityType.identifier == HKQuantityTypeIdentifier.bodyMass.rawValue {
                results = mockBodyMassSamples
            } else if quantityType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                results = mockHeartRateSamples
            }
        }

        // Apply limit if specified
        // Note: The actual limit is stored privately in HKSampleQuery
        // This mock doesn't have direct access to it

        // The completion handler would be called here in a real scenario
        // For testing, the service uses withCheckedThrowingContinuation
        // which we can't directly invoke from here
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

    /// Resets all tracking state.
    public func reset() {
        savedObjects.removeAll()
        savedWorkouts.removeAll()
        samplesAddedToWorkouts.removeAll()
        executedQueries.removeAll()
        methodCallCounts.removeAll()
        methodCallLog.removeAll()
    }

    /// Resets mock data.
    public func resetMockData() {
        mockWorkouts.removeAll()
        mockBodyMassSamples.removeAll()
        mockHeartRateSamples.removeAll()
        mockDateOfBirth = nil
        mockBiologicalSex = .notSet
    }

    // MARK: - Private Methods

    private func recordMethodCall(_ method: String, parameters: [String: String] = [:]) {
        methodCallCounts[method, default: 0] += 1
        methodCallLog.append(MethodCall(method: method, parameters: parameters, timestamp: Date()))
    }
}

// MARK: - Supporting Types

extension MockHKHealthStore {

    /// Defines how authorization requests should behave.
    public enum AuthorizationBehavior: Sendable {
        /// Authorization succeeds for all types.
        case succeed

        /// Authorization is denied for all types.
        case deny

        /// Authorization request fails with an error.
        case failWith(Error)

        /// Some types are authorized, others denied.
        case partialAuthorization(authorized: Set<HKObjectType>)
    }

    /// Defines how save operations should behave.
    public enum SaveBehavior: Sendable {
        /// Save operations succeed.
        case succeed

        /// Save operations fail with an error.
        case failWith(Error)

        /// Save operations fail for specific sample types.
        case failForTypes(Set<HKSampleType>)
    }

    /// Records a method call for verification.
    public struct MethodCall: Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date
    }
}

// MARK: - Mock Biological Sex Object

/// Mock implementation of HKBiologicalSexObject for testing.
public struct MockBiologicalSexObject: Sendable {
    public let biologicalSex: HKBiologicalSex

    public init(biologicalSex: HKBiologicalSex) {
        self.biologicalSex = biologicalSex
    }
}

// MARK: - Factory Methods

extension MockHKHealthStore {

    /// Creates a mock store configured for successful operations.
    public static func successfulStore() async -> MockHKHealthStore {
        let store = MockHKHealthStore()
        await store.setAuthorizationBehavior(.succeed)
        await store.setSaveBehavior(.succeed)
        return store
    }

    /// Creates a mock store that denies all authorization.
    public static func deniedAuthorizationStore() async -> MockHKHealthStore {
        let store = MockHKHealthStore()
        await store.setAuthorizationBehavior(.deny)
        return store
    }

    /// Creates a mock store that fails save operations.
    public static func failingSaveStore(error: Error) async -> MockHKHealthStore {
        let store = MockHKHealthStore()
        await store.setAuthorizationBehavior(.succeed)
        await store.setSaveBehavior(.failWith(error))
        return store
    }

    /// Creates a mock store with preconfigured workout data.
    public static func withWorkouts(_ workouts: [HKWorkout]) async -> MockHKHealthStore {
        let store = MockHKHealthStore()
        await store.setMockWorkouts(workouts)
        return store
    }

    /// Creates a mock store with preconfigured user data.
    public static func withUserData(
        dateOfBirth: DateComponents?,
        biologicalSex: HKBiologicalSex,
        bodyMassKg: Double?
    ) async -> MockHKHealthStore {
        let store = MockHKHealthStore()
        await store.setMockDateOfBirth(dateOfBirth)
        await store.setMockBiologicalSex(biologicalSex)

        if let mass = bodyMassKg,
           let massType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: mass)
            let sample = HKQuantitySample(
                type: massType,
                quantity: quantity,
                start: Date(),
                end: Date()
            )
            await store.setMockBodyMassSamples([sample])
        }

        return store
    }
}

// MARK: - Test Helpers

extension MockHKHealthStore {

    /// Verifies that a workout was saved with expected properties.
    public func verifySavedWorkout(
        activityType: HKWorkoutActivityType,
        minDuration: TimeInterval? = nil,
        maxDuration: TimeInterval? = nil
    ) -> Bool {
        savedWorkouts.contains { workout in
            var matches = workout.workoutActivityType == activityType

            if let minDuration = minDuration {
                matches = matches && workout.duration >= minDuration
            }

            if let maxDuration = maxDuration {
                matches = matches && workout.duration <= maxDuration
            }

            return matches
        }
    }

    /// Verifies that samples were added to a workout.
    public func verifySamplesAddedToWorkout(
        sampleType: HKSampleType,
        count: Int
    ) -> Bool {
        samplesAddedToWorkouts.contains { entry in
            let matchingCount = entry.samples.filter { $0.sampleType == sampleType }.count
            return matchingCount == count
        }
    }
}
