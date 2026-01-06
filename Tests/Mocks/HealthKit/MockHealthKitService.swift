//
//  MockHealthKitService.swift
//  JogPodTests
//
//  Enhanced mock implementation of HealthKitServiceProtocol for testing.
//  Provides comprehensive control over HealthKit behavior including authorization,
//  workout saving, data queries, and error simulation.
//

import Foundation
import HealthKit
@testable import JogPod

// MARK: - MockHealthKitService

/// A comprehensive mock implementation of HealthKitServiceProtocol for testing.
///
/// This mock allows complete control over HealthKit behavior including:
/// - Simulating authorization request results and status
/// - Controlling workout save success/failure
/// - Returning mock workout and user data
/// - Simulating various error conditions
/// - Tracking method calls for verification
///
/// ## Usage
///
/// ```swift
/// let mockService = MockHealthKitService()
///
/// // Configure authorization
/// await mockService.setAuthorizationStatus(.authorized)
///
/// // Configure error behavior
/// await mockService.setWorkoutSaveError(.authorizationDenied)
///
/// // Verify interactions
/// XCTAssertEqual(await mockService.callCount(for: "saveWorkout"), 1)
/// ```
public actor MockHealthKitService: HealthKitServiceProtocol {

    // MARK: - Configuration

    /// Whether HealthKit appears available.
    private var _isAvailable: Bool = true

    /// The authorization status to return.
    private var authorizationStatus: HealthKitAuthorizationStatus = .authorized

    /// Mock workouts to return from queries.
    private var mockWorkouts: [HealthKitWorkoutResult] = []

    /// Mock user data to return.
    private var mockUserData: HealthKitUserData = HealthKitUserData()

    /// Mock body mass value.
    private var mockBodyMass: Double?

    /// Mock date of birth.
    private var mockDateOfBirth: Date?

    /// Mock route points to return from route queries.
    private var mockRoutePoints: [RoutePoint] = []

    /// Error to throw on authorization request.
    private var authorizationError: HealthKitError?

    /// Error to throw on workout save.
    private var workoutSaveError: HealthKitError?

    /// Error to throw on workout fetch.
    private var workoutFetchError: HealthKitError?

    /// Error to throw on user data fetch.
    private var userDataFetchError: HealthKitError?

    /// Delay before operations complete.
    private var operationDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Tracks method call counts.
    private var methodCallCounts: [String: Int] = [:]

    /// Records method calls with parameters.
    private var methodCallLog: [MethodCall] = []

    /// Workouts that were saved.
    public private(set) var savedWorkouts: [HealthKitWorkoutData] = []

    /// Authorization requests made.
    public private(set) var authorizationRequests: [Date] = []

    // MARK: - Initialization

    public init(
        isAvailable: Bool = true,
        authorizationStatus: HealthKitAuthorizationStatus = .authorized
    ) {
        self._isAvailable = isAvailable
        self.authorizationStatus = authorizationStatus
    }

    // MARK: - HealthKitServiceProtocol Implementation

    public nonisolated var isAvailable: Bool {
        // Note: For actors, nonisolated properties must be immutable or computed
        // This is a simplified approach for testing
        true
    }

    /// Internal method to check availability (actor-isolated).
    private func checkAvailability() -> Bool {
        _isAvailable
    }

    public func requestAuthorization() async throws {
        recordMethodCall("requestAuthorization")
        authorizationRequests.append(Date())

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        if let error = authorizationError {
            throw error
        }
    }

    public func checkAuthorizationStatus() async -> HealthKitAuthorizationStatus {
        recordMethodCall("checkAuthorizationStatus")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        if !_isAvailable {
            return .unavailable
        }

        return authorizationStatus
    }

    public func saveWorkout(_ workout: HealthKitWorkoutData) async throws {
        recordMethodCall("saveWorkout", parameters: [
            "activityType": "\(workout.activityType.rawValue)",
            "duration": "\(workout.duration)",
            "distance": "\(workout.totalDistance)"
        ])

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        guard workout.isValid else {
            throw HealthKitError.invalidWorkoutData("Invalid workout data")
        }

        if let error = workoutSaveError {
            throw error
        }

        savedWorkouts.append(workout)
    }

    public func fetchWorkouts(
        activityType: HKWorkoutActivityType?,
        startDate: Date?,
        endDate: Date?,
        limit: Int
    ) async throws -> [HealthKitWorkoutResult] {
        recordMethodCall("fetchWorkouts", parameters: [
            "activityType": activityType.map { "\($0.rawValue)" } ?? "nil",
            "limit": "\(limit)"
        ])

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        if let error = workoutFetchError {
            throw error
        }

        var results = mockWorkouts

        // Apply filters
        if let activityType = activityType {
            results = results.filter { $0.activityType == activityType }
        }

        if let startDate = startDate {
            results = results.filter { $0.startTime >= startDate }
        }

        if let endDate = endDate {
            results = results.filter { $0.endTime <= endDate }
        }

        // Apply limit
        return Array(results.prefix(limit))
    }

    public func fetchUserData() async throws -> HealthKitUserData {
        recordMethodCall("fetchUserData")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        if let error = userDataFetchError {
            throw error
        }

        return mockUserData
    }

    public func fetchLatestBodyMass() async throws -> Double? {
        recordMethodCall("fetchLatestBodyMass")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        return mockBodyMass
    }

    public func fetchDateOfBirth() async throws -> Date? {
        recordMethodCall("fetchDateOfBirth")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        return mockDateOfBirth
    }

    public func fetchWorkoutRoute(for workout: HKWorkout) async throws -> [RoutePoint] {
        recordMethodCall("fetchWorkoutRoute(for:)")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        return mockRoutePoints
    }

    public func fetchWorkoutRoute(workoutID: UUID) async throws -> [RoutePoint] {
        recordMethodCall("fetchWorkoutRoute(workoutID:)")

        if operationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(operationDelay * 1_000_000_000))
        }

        guard _isAvailable else {
            throw HealthKitError.healthKitNotAvailable
        }

        return mockRoutePoints
    }

    // MARK: - Configuration Methods

    /// Sets whether HealthKit appears available.
    public func setAvailable(_ available: Bool) {
        _isAvailable = available
    }

    /// Sets the authorization status to return.
    public func setAuthorizationStatus(_ status: HealthKitAuthorizationStatus) {
        authorizationStatus = status
    }

    /// Sets the error to throw on authorization request.
    public func setAuthorizationError(_ error: HealthKitError?) {
        authorizationError = error
    }

    /// Sets the error to throw on workout save.
    public func setWorkoutSaveError(_ error: HealthKitError?) {
        workoutSaveError = error
    }

    /// Sets the error to throw on workout fetch.
    public func setWorkoutFetchError(_ error: HealthKitError?) {
        workoutFetchError = error
    }

    /// Sets the error to throw on user data fetch.
    public func setUserDataFetchError(_ error: HealthKitError?) {
        userDataFetchError = error
    }

    /// Sets mock workouts to return from queries.
    public func setMockWorkouts(_ workouts: [HealthKitWorkoutResult]) {
        mockWorkouts = workouts
    }

    /// Adds a mock workout.
    public func addMockWorkout(_ workout: HealthKitWorkoutResult) {
        mockWorkouts.append(workout)
    }

    /// Sets mock user data.
    public func setMockUserData(_ userData: HealthKitUserData) {
        mockUserData = userData
    }

    /// Sets mock body mass.
    public func setMockBodyMass(_ mass: Double?) {
        mockBodyMass = mass
    }

    /// Sets mock date of birth.
    public func setMockDateOfBirth(_ date: Date?) {
        mockDateOfBirth = date
    }

    /// Sets mock route points.
    public func setMockRoutePoints(_ routePoints: [RoutePoint]) {
        mockRoutePoints = routePoints
    }

    /// Sets the operation delay.
    public func setOperationDelay(_ delay: TimeInterval) {
        operationDelay = delay
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

    /// Returns method calls filtered by method name.
    public func getMethodCalls(named method: String) -> [MethodCall] {
        methodCallLog.filter { $0.method == method }
    }

    /// Verifies a method was called a specific number of times.
    public func verifyCallCount(for method: String, expected: Int) -> Bool {
        callCount(for: method) == expected
    }

    /// Verifies a workout was saved with specific properties.
    public func verifySavedWorkout(
        activityType: HKWorkoutActivityType? = nil,
        minDuration: TimeInterval? = nil,
        minDistance: Double? = nil
    ) -> Bool {
        savedWorkouts.contains { workout in
            var matches = true

            if let activityType = activityType {
                matches = matches && workout.activityType == activityType
            }

            if let minDuration = minDuration {
                matches = matches && workout.duration >= minDuration
            }

            if let minDistance = minDistance {
                matches = matches && workout.totalDistance >= minDistance
            }

            return matches
        }
    }

    /// Resets all tracking state.
    public func reset() {
        savedWorkouts.removeAll()
        authorizationRequests.removeAll()
        methodCallCounts.removeAll()
        methodCallLog.removeAll()
    }

    /// Resets mock data and errors.
    public func resetConfiguration() {
        mockWorkouts.removeAll()
        mockUserData = HealthKitUserData()
        mockBodyMass = nil
        mockDateOfBirth = nil
        mockRoutePoints.removeAll()
        authorizationError = nil
        workoutSaveError = nil
        workoutFetchError = nil
        userDataFetchError = nil
        operationDelay = 0
    }

    // MARK: - Private Methods

    private func recordMethodCall(_ method: String, parameters: [String: String] = [:]) {
        methodCallCounts[method, default: 0] += 1
        methodCallLog.append(MethodCall(method: method, parameters: parameters, timestamp: Date()))
    }
}

// MARK: - Supporting Types

extension MockHealthKitService {

    /// Records a method call for verification.
    public struct MethodCall: Sendable {
        public let method: String
        public let parameters: [String: String]
        public let timestamp: Date
    }
}

// MARK: - Factory Methods

extension MockHealthKitService {

    /// Creates a mock service configured for successful operations.
    public static func successful() -> MockHealthKitService {
        MockHealthKitService(isAvailable: true, authorizationStatus: .authorized)
    }

    /// Creates a mock service where HealthKit is unavailable.
    public static func unavailable() -> MockHealthKitService {
        MockHealthKitService(isAvailable: false, authorizationStatus: .unavailable)
    }

    /// Creates a mock service with denied authorization.
    public static func denied() -> MockHealthKitService {
        MockHealthKitService(isAvailable: true, authorizationStatus: .denied)
    }

    /// Creates a mock service with authorization not determined.
    public static func notDetermined() -> MockHealthKitService {
        MockHealthKitService(isAvailable: true, authorizationStatus: .notDetermined)
    }

    /// Creates a mock service with preset workout data.
    public static func withWorkouts(_ workouts: [HealthKitWorkoutResult]) async -> MockHealthKitService {
        let service = MockHealthKitService()
        await service.setMockWorkouts(workouts)
        return service
    }

    /// Creates a mock service with preset user data.
    public static func withUserData(
        dateOfBirth: Date? = nil,
        biologicalSex: HKBiologicalSex? = nil,
        bodyMassKg: Double? = nil
    ) async -> MockHealthKitService {
        let service = MockHealthKitService()
        await service.setMockUserData(HealthKitUserData(
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            bodyMassKg: bodyMassKg
        ))
        await service.setMockDateOfBirth(dateOfBirth)
        await service.setMockBodyMass(bodyMassKg)
        return service
    }

    /// Creates a mock service that fails authorization.
    public static func authorizationFailing(with error: HealthKitError) async -> MockHealthKitService {
        let service = MockHealthKitService()
        await service.setAuthorizationError(error)
        return service
    }

    /// Creates a mock service that fails workout saves.
    public static func saveFailing(with error: HealthKitError) async -> MockHealthKitService {
        let service = MockHealthKitService()
        await service.setWorkoutSaveError(error)
        return service
    }
}

// MARK: - Test Data Builders

extension MockHealthKitService {

    /// Creates sample workout results for testing.
    public static func sampleWorkoutResults(count: Int = 5) -> [HealthKitWorkoutResult] {
        (0..<count).map { index in
            let startTime = Date().addingTimeInterval(Double(-index * 86400 - 3600))
            let duration = TimeInterval(1800 + index * 300) // 30-50 minutes

            return HealthKitWorkoutResult(
                id: UUID(),
                startTime: startTime,
                endTime: startTime.addingTimeInterval(duration),
                activityType: .running,
                duration: duration,
                totalEnergyBurned: Double(200 + index * 50),
                totalDistanceMeters: Double(3000 + index * 500),
                sourceBundleIdentifier: "com.jogpod.app",
                sourceName: "JogPod"
            )
        }
    }

    /// Creates sample user data for testing.
    public static func sampleUserData() -> HealthKitUserData {
        let calendar = Calendar.current
        let dateOfBirth = calendar.date(from: DateComponents(year: 1990, month: 6, day: 15))

        return HealthKitUserData(
            dateOfBirth: dateOfBirth,
            biologicalSex: .male,
            bodyMassKg: 75.0,
            heightMeters: 1.80
        )
    }
}
