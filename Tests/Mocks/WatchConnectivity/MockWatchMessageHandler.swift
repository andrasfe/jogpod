//
//  MockWatchMessageHandler.swift
//  JogPodTests
//
//  Mock implementation of WatchMessageHandler for testing delegate callbacks.
//
//  Created for JogPod Revival project.
//

import Foundation
import CoreLocation
import Combine
@testable import JogPod

// MARK: - MockWatchMessageHandler

/// A mock implementation of WatchMessageHandlerProtocol for testing.
///
/// This mock allows tests to verify delegate interactions and control
/// the responses returned for watch requests.
@MainActor
public final class MockWatchMessageHandler: WatchMessageHandlerProtocol {

    // MARK: - Protocol Properties

    public var workoutService: WorkoutServiceProtocol?
    public var audioPlayerService: AudioPlayerService?
    public var persistenceManager: PersistenceManaging?

    // MARK: - Mock Configuration

    /// Whether the app is initialized.
    public var isAppInitialized: Bool = true

    /// Custom response to return for dashboard requests.
    public var dashboardResponse: WatchResponse?

    /// Custom response to return for metrics requests.
    public var metricsResponse: WatchResponse?

    /// Custom response to return for podcast requests.
    public var podcastResponse: WatchResponse?

    /// Custom response to return for map requests.
    public var mapResponse: WatchResponse?

    /// Custom response to return for stats requests.
    public var statsResponse: WatchResponse?

    /// Custom response to return for any request.
    public var genericResponse: WatchResponse?

    // MARK: - Tracking Properties

    /// All received requests.
    public private(set) var receivedRequests: [WatchRequest] = []

    /// View changes that were notified.
    public private(set) var viewChanges: [WatchView] = []

    /// Reachability changes that were notified.
    public private(set) var reachabilityChanges: [Bool] = []

    /// Number of times didReceiveRequest was called.
    public private(set) var requestCallCount: Int = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - WatchConnectivityDelegate

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didReceiveRequest request: WatchRequest
    ) async -> WatchResponse {
        receivedRequests.append(request)
        requestCallCount += 1

        // Check initialization
        guard isAppInitialized else {
            return .notInitialized
        }

        // Return custom response if set
        if let response = genericResponse {
            return response
        }

        // Return type-specific response
        switch request {
        case .openDashboard:
            return dashboardResponse ?? makeDefaultDashboardResponse()

        case .openMetrics:
            return metricsResponse ?? makeDefaultMetricsResponse()

        case .openPodcast:
            return podcastResponse ?? makeDefaultPodcastResponse()

        case .openMap:
            return mapResponse ?? .map

        case .openStats:
            return statsResponse ?? .stats

        case .acknowledge:
            return .dashboard(WatchConnectivityTestFixtures.dashboardIdle)
        }
    }

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeWatchView view: WatchView
    ) {
        viewChanges.append(view)
    }

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeReachability isReachable: Bool
    ) {
        reachabilityChanges.append(isReachable)
    }

    // MARK: - Default Responses

    private func makeDefaultDashboardResponse() -> WatchResponse {
        .dashboard(WatchConnectivityTestFixtures.dashboardIdle)
    }

    private func makeDefaultMetricsResponse() -> WatchResponse {
        .metrics(WatchConnectivityTestFixtures.metricsIdle)
    }

    private func makeDefaultPodcastResponse() -> WatchResponse {
        .podcast(WatchConnectivityTestFixtures.podcastEmpty)
    }

    // MARK: - Test Helpers

    /// Resets all tracking data.
    public func reset() {
        receivedRequests = []
        viewChanges = []
        reachabilityChanges = []
        requestCallCount = 0

        dashboardResponse = nil
        metricsResponse = nil
        podcastResponse = nil
        mapResponse = nil
        statsResponse = nil
        genericResponse = nil
        isAppInitialized = true
    }

    /// Returns the last received request.
    public var lastRequest: WatchRequest? {
        receivedRequests.last
    }

    /// Returns the last view change.
    public var lastViewChange: WatchView? {
        viewChanges.last
    }

    /// Returns the last reachability change.
    public var lastReachabilityChange: Bool? {
        reachabilityChanges.last
    }

    /// Checks if a specific request type was received.
    public func wasRequestReceived(_ requestType: RequestType) -> Bool {
        receivedRequests.contains { request in
            switch (request, requestType) {
            case (.openDashboard, .openDashboard):
                return true
            case (.openMetrics, .openMetrics):
                return true
            case (.openPodcast, .openPodcast):
                return true
            case (.openMap, .openMap):
                return true
            case (.openStats, .openStats):
                return true
            case (.acknowledge, .acknowledge):
                return true
            default:
                return false
            }
        }
    }

    /// Request types for verification.
    public enum RequestType {
        case openDashboard
        case openMetrics
        case openPodcast
        case openMap
        case openStats
        case acknowledge
    }

    /// Returns count of requests of a specific type.
    public func requestCount(of type: RequestType) -> Int {
        receivedRequests.filter { request in
            switch (request, type) {
            case (.openDashboard, .openDashboard):
                return true
            case (.openMetrics, .openMetrics):
                return true
            case (.openPodcast, .openPodcast):
                return true
            case (.openMap, .openMap):
                return true
            case (.openStats, .openStats):
                return true
            case (.acknowledge, .acknowledge):
                return true
            default:
                return false
            }
        }.count
    }
}

// MARK: - MockWorkoutServiceForWatch

/// A mock workout service specifically for WatchConnectivity testing.
public actor MockWorkoutServiceForWatch: WorkoutServiceProtocol {

    // MARK: - Configuration

    private var _isWorkoutInProgress: Bool = false
    private var _state: WorkoutState = .idle
    private var _workoutID: String?
    private var _metrics: WorkoutSnapshot?

    // MARK: - Protocol Properties

    public var isWorkoutInProgress: Bool {
        _isWorkoutInProgress
    }

    public var state: WorkoutState {
        _state
    }

    public var activeWorkoutID: String? {
        _workoutID
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Protocol Methods

    public func startWorkout() async throws -> String {
        let id = UUID().uuidString
        _workoutID = id
        _state = .active
        _isWorkoutInProgress = true
        return id
    }

    public func stopWorkout() async throws {
        _workoutID = nil
        _state = .idle
        _isWorkoutInProgress = false
    }

    public func requestAuthorization() async throws {}

    public func currentMetrics() async -> WorkoutSnapshot? {
        _metrics
    }

    // MARK: - Mock Configuration

    public func setWorkoutInProgress(_ inProgress: Bool) {
        _isWorkoutInProgress = inProgress
        _state = inProgress ? .active : .idle
    }

    public func setMetrics(_ metrics: WorkoutSnapshot?) {
        _metrics = metrics
    }

    public func setWorkoutID(_ id: String?) {
        _workoutID = id
    }
}

// MARK: - MockPersistenceManagerForWatch

/// A mock persistence manager specifically for WatchConnectivity testing.
public final class MockPersistenceManagerForWatch: PersistenceManaging, @unchecked Sendable {

    // MARK: - Configuration

    public var workoutCount: Int = 0
    public var shouldThrowError: Bool = false
    public var errorToThrow: Error?

    // MARK: - Initialization

    public init() {}

    // MARK: - Protocol Methods

    public func save() async throws {
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
    }

    public func rollback() async throws {}

    public func createWorkoutSession(
        workoutID: String,
        startTime: Date?
    ) async throws -> WorkoutSession {
        fatalError("Not implemented for tests")
    }

    public func createTrackPoint(
        workoutID: String,
        time: Date,
        location: CLLocation?,
        heartRate: Int16?,
        steps: Int16?
    ) async throws -> WorkoutTrackPoint {
        fatalError("Not implemented for tests")
    }

    public func fetchWorkoutSession(workoutID: String) async throws -> WorkoutSession? {
        nil
    }

    public func fetchWorkoutSessionCount() async throws -> Int {
        workoutCount
    }
}
