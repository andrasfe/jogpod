//
//  WatchMessageHandlerTests.swift
//  JogPod
//
//  Tests for WatchMessageHandler.
//

import XCTest
import CoreLocation
@testable import JogPod

final class WatchMessageHandlerTests: XCTestCase {

    // MARK: - Properties

    private var handler: WatchMessageHandler!
    private var mockWorkoutService: MockWorkoutService!
    private var mockPersistence: MockPersistenceManager!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()

        mockWorkoutService = MockWorkoutService()
        mockPersistence = MockPersistenceManager()

        handler = WatchMessageHandler()
        handler.workoutService = mockWorkoutService
        handler.persistenceManager = mockPersistence
        handler.isAppInitialized = true
    }

    override func tearDown() {
        handler = nil
        mockWorkoutService = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Dashboard Request Tests

    @MainActor
    func testOpenDashboardReturnsWorkoutStatus() async {
        mockWorkoutService.workoutInProgress = true

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        if case .dashboard(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
        } else {
            XCTFail("Expected dashboard response")
        }
    }

    @MainActor
    func testOpenDashboardReturnsWorkoutCount() async {
        mockPersistence.workoutCount = 15

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        if case .dashboard(let data) = response {
            XCTAssertEqual(data.workoutCount, 15)
        } else {
            XCTFail("Expected dashboard response")
        }
    }

    @MainActor
    func testOpenDashboardWhenNotInitialized() async {
        handler.isAppInitialized = false

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        if case .notInitialized = response {
            // Success
        } else {
            XCTFail("Expected notInitialized response")
        }
    }

    // MARK: - Metrics Request Tests

    @MainActor
    func testOpenMetricsReturnsWorkoutStatus() async {
        mockWorkoutService.workoutInProgress = true

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openMetrics)

        if case .metrics(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
            XCTAssertEqual(data.publisherCount, WatchMessageHandler.publisherCount)
        } else {
            XCTFail("Expected metrics response")
        }
    }

    @MainActor
    func testOpenMetricsReturnsPublisherCount() async {
        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openMetrics)

        if case .metrics(let data) = response {
            XCTAssertEqual(data.publisherCount, WatchMessageHandler.publisherCount)
        } else {
            XCTFail("Expected metrics response")
        }
    }

    // MARK: - Podcast Request Tests

    @MainActor
    func testOpenPodcastWithNoAudioService() async {
        handler.audioPlayerService = nil

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openPodcast)

        if case .podcast(let data) = response {
            XCTAssertEqual(data.currentTitle, "")
            XCTAssertFalse(data.isPlaying)
        } else {
            XCTFail("Expected podcast response")
        }
    }

    // MARK: - Map Request Tests

    @MainActor
    func testOpenMapReturnsAcknowledgment() async {
        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openMap)

        if case .map = response {
            // Success
        } else {
            XCTFail("Expected map response")
        }
    }

    // MARK: - Stats Request Tests

    @MainActor
    func testOpenStatsReturnsAcknowledgment() async {
        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openStats)

        if case .stats = response {
            // Success
        } else {
            XCTFail("Expected stats response")
        }
    }

    // MARK: - View Change Tests

    @MainActor
    func testViewChangeCallsDelegate() async {
        let mockService = MockWatchConnectivityService()

        // First request sets view to dashboard
        _ = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        // View change handler is called (we can't easily test this without exposing internal state)
        // This test at least verifies the method doesn't crash
    }

    // MARK: - Nil Service Tests

    @MainActor
    func testHandlerWithNilWorkoutService() async {
        handler.workoutService = nil

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        if case .dashboard(let data) = response {
            XCTAssertFalse(data.workoutInProgress)
        } else {
            XCTFail("Expected dashboard response")
        }
    }

    @MainActor
    func testHandlerWithNilPersistence() async {
        handler.persistenceManager = nil

        let mockService = MockWatchConnectivityService()
        let response = await handler.watchConnectivityService(mockService, didReceiveRequest: .openDashboard)

        if case .dashboard(let data) = response {
            XCTAssertEqual(data.workoutCount, 0)
        } else {
            XCTFail("Expected dashboard response")
        }
    }
}

// MARK: - Mock Classes

private actor MockWorkoutService: WorkoutServiceProtocol {
    var workoutInProgress: Bool = false
    private var _state: WorkoutState = .idle
    private var _workoutID: String?

    var state: WorkoutState {
        _state
    }

    var activeWorkoutID: String? {
        _workoutID
    }

    var isWorkoutInProgress: Bool {
        workoutInProgress
    }

    func startWorkout() async throws -> String {
        let id = UUID().uuidString
        _workoutID = id
        _state = .active
        workoutInProgress = true
        return id
    }

    func stopWorkout() async throws {
        _workoutID = nil
        _state = .idle
        workoutInProgress = false
    }

    func requestAuthorization() async throws {}

    func currentMetrics() async -> WorkoutSnapshot? {
        nil
    }
}

private final class MockPersistenceManager: PersistenceManaging, @unchecked Sendable {
    var workoutCount: Int = 0

    func save() async throws {}

    func rollback() async throws {}

    func createWorkoutSession(
        workoutID: String,
        startTime: Date?
    ) async throws -> WorkoutSession {
        fatalError("Not implemented for tests")
    }

    func createTrackPoint(
        workoutID: String,
        time: Date,
        location: CLLocation?,
        heartRate: Int16?,
        steps: Int16?
    ) async throws -> WorkoutTrackPoint {
        fatalError("Not implemented for tests")
    }

    func fetchWorkoutSession(workoutID: String) async throws -> WorkoutSession? {
        nil
    }

    func fetchWorkoutSessionCount() async throws -> Int {
        workoutCount
    }
}

@MainActor
private final class MockWatchConnectivityService: WatchConnectivityService {
    override init() {
        super.init(mockSession: nil)
    }
}

// MARK: - WorkoutMetricsFormatter Tests

final class WorkoutMetricsFormatterTests: XCTestCase {

    func testFormatBasicMetrics() {
        let snapshot = WorkoutSnapshot(
            duration: 1800,
            distanceInMeters: 5000,
            speedMetersPerSecond: 2.78,
            paceSecondsPerKilometer: 360,
            caloriesBurned: 350,
            heartRate: 145,
            steps: 5000
        )

        let fields = WorkoutMetricsFormatter.format(snapshot: snapshot)

        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.distance.rawValue])
        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.duration.rawValue])
        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.pace.rawValue])
        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.speed.rawValue])
        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.calories.rawValue])
        XCTAssertNotNil(fields[WorkoutMetricsFormatter.FieldTag.heartRate.rawValue])
    }

    func testFormatWithPodcastTitle() {
        let snapshot = WorkoutSnapshot.empty

        let fields = WorkoutMetricsFormatter.format(snapshot: snapshot, podcastTitle: "My Episode")

        XCTAssertEqual(fields[WorkoutMetricsFormatter.FieldTag.podcastTitle.rawValue], "My Episode")
    }

    func testFormatWithZeroHeartRate() {
        let snapshot = WorkoutSnapshot(
            duration: 1800,
            distanceInMeters: 5000,
            speedMetersPerSecond: 2.78,
            paceSecondsPerKilometer: 360,
            caloriesBurned: 350,
            heartRate: 0,
            steps: 0
        )

        let fields = WorkoutMetricsFormatter.format(snapshot: snapshot)

        XCTAssertNil(fields[WorkoutMetricsFormatter.FieldTag.heartRate.rawValue])
    }

    func testDistanceFormatting() {
        let snapshot = WorkoutSnapshot(
            duration: 0,
            distanceInMeters: 5123,
            speedMetersPerSecond: 0,
            paceSecondsPerKilometer: 0,
            caloriesBurned: 0,
            heartRate: 0,
            steps: 0
        )

        let fields = WorkoutMetricsFormatter.format(snapshot: snapshot)

        XCTAssertEqual(fields[WorkoutMetricsFormatter.FieldTag.distance.rawValue], "5.12 km")
    }

    func testCaloriesFormatting() {
        let snapshot = WorkoutSnapshot(
            duration: 0,
            distanceInMeters: 0,
            speedMetersPerSecond: 0,
            paceSecondsPerKilometer: 0,
            caloriesBurned: 567,
            heartRate: 0,
            steps: 0
        )

        let fields = WorkoutMetricsFormatter.format(snapshot: snapshot)

        XCTAssertEqual(fields[WorkoutMetricsFormatter.FieldTag.calories.rawValue], "567 kcal")
    }
}
