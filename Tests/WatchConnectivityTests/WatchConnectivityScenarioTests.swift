//
//  WatchConnectivityScenarioTests.swift
//  JogPodTests
//
//  Scenario-based integration tests for iOS to watchOS communication.
//  These tests simulate real-world usage patterns and verify correct
//  behavior across the full communication stack.
//
//  Scenarios covered:
//  - User workout session flow
//  - Podcast playback control flow
//  - Watch app lifecycle events
//  - Connection state transitions
//  - Error handling and recovery scenarios
//  - Multi-view state management
//
//  Created for JogPod Revival project.
//

import XCTest
import Combine
import CoreLocation
@testable import JogPod

// MARK: - WatchConnectivityScenarioTests

final class WatchConnectivityScenarioTests: XCTestCase {

    // MARK: - Properties

    private var mockService: MockWatchConnectivityService!
    private var messageHandler: MockWatchMessageHandler!
    private var workoutService: MockWorkoutServiceForWatch!
    private var persistenceManager: MockPersistenceManagerForWatch!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()

        mockService = MockWatchConnectivityService()
        messageHandler = MockWatchMessageHandler()
        workoutService = MockWorkoutServiceForWatch()
        persistenceManager = MockPersistenceManagerForWatch()

        messageHandler.workoutService = workoutService
        messageHandler.persistenceManager = persistenceManager
        mockService.delegate = messageHandler

        cancellables = []
    }

    @MainActor
    override func tearDown() {
        mockService?.reset()
        messageHandler?.reset()
        mockService = nil
        messageHandler = nil
        workoutService = nil
        persistenceManager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Scenario: User Opens Watch App for First Time

    /// Tests the scenario where a user opens the watch app for the first time
    /// after pairing and installing the app.
    @MainActor
    func testScenario_FirstLaunchExperience() async throws {
        // GIVEN: Fresh app installation, no workouts saved
        persistenceManager.workoutCount = 0
        await workoutService.setWorkoutInProgress(false)
        mockService.setupForSuccessfulSending()

        let mockWCService = createMockWatchConnectivityService()

        // WHEN: Watch app opens and requests dashboard
        let response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )

        // THEN: Dashboard shows clean slate
        if case .dashboard(let data) = response {
            XCTAssertFalse(data.workoutInProgress, "No workout should be in progress on first launch")
            XCTAssertFalse(data.podcastPlaying, "No podcast should be playing")
            XCTAssertEqual(data.workoutCount, 0, "No workouts should be saved")
            XCTAssertTrue(data.isInitialized, "App should be initialized")
        } else {
            XCTFail("Expected dashboard response")
        }
    }

    /// Tests scenario where app hasn't completed initialization (disclaimer not accepted)
    @MainActor
    func testScenario_AppNotInitialized() async throws {
        // GIVEN: App not initialized (disclaimer not accepted)
        messageHandler.isAppInitialized = false
        mockService.setupForSuccessfulSending()

        let mockWCService = createMockWatchConnectivityService()

        // WHEN: Watch requests any view
        let dashboardResponse = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )

        let metricsResponse = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openMetrics
        )

        // THEN: All views return not initialized
        if case .notInitialized = dashboardResponse {
            // Expected
        } else {
            XCTFail("Expected notInitialized for dashboard")
        }

        if case .notInitialized = metricsResponse {
            // Expected
        } else {
            XCTFail("Expected notInitialized for metrics")
        }
    }

    // MARK: - Scenario: Complete Workout Session

    /// Tests the complete flow of a workout session from start to finish.
    @MainActor
    func testScenario_CompleteWorkoutSession() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        await workoutService.setWorkoutInProgress(false)
        persistenceManager.workoutCount = 5
        let mockWCService = createMockWatchConnectivityService()

        // --- PHASE 1: Pre-workout ---

        // User opens watch app to dashboard
        var response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )

        if case .dashboard(let data) = response {
            XCTAssertFalse(data.workoutInProgress)
            XCTAssertEqual(data.workoutCount, 5)
        }

        // --- PHASE 2: Workout starts on phone ---

        // User starts workout from iPhone
        await workoutService.setWorkoutInProgress(true)

        // Push notification sent to watch (on dashboard view)
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        XCTAssertEqual(mockService.sentMessages.count, 1, "Workout start notification should be sent")

        // --- PHASE 3: User navigates to metrics view ---

        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openMetrics
        )

        if case .metrics(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
            XCTAssertEqual(data.publisherCount, 4)
        }

        mockService.mockCurrentWatchView = .metrics

        // Workout updates sent to metrics view
        let workout1 = WatchConnectivityTestFixtures.makeWorkoutUpdateData(
            distance: "1.00 km",
            duration: "5:30",
            pace: "5:30 /km"
        )
        try await mockService.sendMessage(.workoutUpdate(workout1))

        let workout2 = WatchConnectivityTestFixtures.makeWorkoutUpdateData(
            distance: "2.50 km",
            duration: "13:45",
            pace: "5:30 /km"
        )
        try await mockService.sendMessage(.workoutUpdate(workout2))

        XCTAssertEqual(mockService.messages(ofType: .workoutUpdate).count, 2)

        // --- PHASE 4: User checks podcast during workout ---

        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openPodcast
        )

        if case .podcast(let data) = response {
            // Podcast data returned
            XCTAssertNotNil(data)
        }

        // --- PHASE 5: User checks map ---

        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openMap
        )

        mockService.mockCurrentWatchView = .map

        // Location updates sent
        try await mockService.sendMessage(.locationUpdate(WatchConnectivityTestFixtures.locationSanFrancisco))

        XCTAssertEqual(mockService.messages(ofType: .locationUpdate).count, 1)

        // --- PHASE 6: Workout ends ---

        await workoutService.setWorkoutInProgress(false)
        persistenceManager.workoutCount = 6  // New workout saved

        // User returns to dashboard
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.workoutStatus(isActive: false))

        // --- PHASE 7: User views stats ---

        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openStats
        )

        if case .stats = response {
            // Stats view ready for data
        }

        mockService.mockCurrentWatchView = .stats
        try await mockService.sendMessage(.stats(WatchConnectivityTestFixtures.stats5K))

        XCTAssertEqual(mockService.messages(ofType: .stats).count, 1)

        // --- FINAL VERIFICATION ---

        XCTAssertEqual(messageHandler.requestCallCount, 6, "All view requests should be processed")
        XCTAssertEqual(mockService.messages(ofType: .workoutStatus).count, 2, "Start and stop notifications")
        XCTAssertEqual(mockService.messages(ofType: .workoutUpdate).count, 2, "Workout updates during session")
        XCTAssertEqual(mockService.messages(ofType: .locationUpdate).count, 1, "Location updates during map view")
        XCTAssertEqual(mockService.messages(ofType: .stats).count, 1, "Stats at end of workout")
    }

    // MARK: - Scenario: Podcast Playback Control

    /// Tests podcast playback control via watch.
    @MainActor
    func testScenario_PodcastPlaybackControl() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        let mockWCService = createMockWatchConnectivityService()

        // Configure podcast response
        messageHandler.podcastResponse = .podcast(PodcastData(
            currentTitle: "Running Mix Episode 42",
            isPlaying: false
        ))

        // User opens podcast view
        let response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openPodcast
        )

        if case .podcast(let data) = response {
            XCTAssertEqual(data.currentTitle, "Running Mix Episode 42")
            XCTAssertFalse(data.isPlaying)
        }

        mockService.mockCurrentWatchView = .podcast

        // User presses play (simulated via iPhone notification)
        try await mockService.sendMessage(.playerUpdate(isPlaying: true, podcastTitle: "Running Mix Episode 42"))

        XCTAssertEqual(mockService.sentMessages.count, 1)

        // Track changes during playback
        try await mockService.sendMessage(.podcastUpdate(title: "Running Mix Episode 43"))

        XCTAssertEqual(mockService.sentMessages.count, 2)

        // User pauses
        try await mockService.sendMessage(.playerUpdate(isPlaying: false, podcastTitle: nil))

        XCTAssertEqual(mockService.sentMessages.count, 3)
    }

    // MARK: - Scenario: Connection State Transitions

    /// Tests behavior when watch goes from connected to disconnected and back.
    @MainActor
    func testScenario_ConnectionStateCycle() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        var reachabilityChanges: [Bool] = []
        mockService.reachabilityPublisher
            .dropFirst()  // Skip initial value
            .sink { reachabilityChanges.append($0) }
            .store(in: &cancellables)

        // --- PHASE 1: Connected state ---

        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // --- PHASE 2: Watch goes out of range ---

        mockService.simulateReachabilityChange(false)

        XCTAssertEqual(mockService.currentWatchView, .none, "View should reset when unreachable")

        // Try to send message - should fail
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Should throw when not reachable")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotReachable)
        }

        // --- PHASE 3: Watch comes back in range ---

        mockService.simulateReachabilityChange(true)
        mockService.mockCurrentWatchView = .dashboard  // User reopens dashboard

        // Messaging works again
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 2)

        // Verify reachability changes were tracked
        XCTAssertEqual(reachabilityChanges, [false, true])
    }

    /// Tests behavior when session becomes inactive and reactivates.
    @MainActor
    func testScenario_SessionReactivation() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        var sessionStates: [WatchSessionState] = []
        mockService.sessionStatePublisher
            .dropFirst()  // Skip initial
            .sink { sessionStates.append($0) }
            .store(in: &cancellables)

        // --- PHASE 1: Normal operation ---

        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // --- PHASE 2: Session becomes inactive ---

        mockService.simulateSessionStateChange(.notActivated)
        mockService.mockIsActivated = false

        do {
            try await mockService.sendMessage(.workoutStatus(isActive: false))
            XCTFail("Should fail when not activated")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .sessionNotActivated)
        }

        // --- PHASE 3: Session reactivates ---

        try await mockService.activate()
        mockService.mockIsReachable = true
        mockService.mockCurrentWatchView = .dashboard

        try await mockService.sendMessage(.workoutStatus(isActive: false))
        XCTAssertEqual(mockService.sentMessages.count, 2)

        // Verify state transitions
        XCTAssertTrue(sessionStates.contains(.notActivated))
        XCTAssertTrue(sessionStates.contains(.activated))
    }

    // MARK: - Scenario: Watch Pairing Changes

    /// Tests behavior when watch becomes unpaired.
    @MainActor
    func testScenario_WatchBecomesUnpaired() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()

        // Normal file transfer works
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()
        try await mockService.transferFile(fileURL, metadata: nil)
        XCTAssertEqual(mockService.transferredFiles.count, 1)

        // Watch becomes unpaired
        mockService.simulateWatchStateChange(isPaired: false)

        // File transfer fails
        do {
            try await mockService.transferFile(fileURL, metadata: nil)
            XCTFail("Should fail when unpaired")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotPaired)
        }
    }

    /// Tests behavior when watch app is uninstalled.
    @MainActor
    func testScenario_WatchAppUninstalled() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()

        // Normal file transfer works
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()
        try await mockService.transferFile(fileURL, metadata: nil)

        // Watch app is uninstalled
        mockService.simulateWatchStateChange(isAppInstalled: false)

        // File transfer fails
        do {
            try await mockService.transferFile(fileURL, metadata: nil)
            XCTFail("Should fail when app not installed")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchAppNotInstalled)
        }
    }

    // MARK: - Scenario: Multi-View State Management

    /// Tests that the correct view receives messages when user navigates quickly.
    @MainActor
    func testScenario_RapidViewNavigation() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        let mockWCService = createMockWatchConnectivityService()

        // User rapidly swipes through views
        let navigationSequence: [WatchRequest] = [
            .openDashboard, .openMetrics, .openPodcast,
            .openMap, .openStats, .openDashboard
        ]

        for request in navigationSequence {
            _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: request)
        }

        // Verify all requests handled
        XCTAssertEqual(messageHandler.requestCallCount, 6)
        XCTAssertEqual(messageHandler.requestCount(of: .openDashboard), 2)
    }

    /// Tests message delivery to transitioning views.
    @MainActor
    func testScenario_MessageDuringViewTransition() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        let mockWCService = createMockWatchConnectivityService()

        // User is on dashboard
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openDashboard)
        mockService.mockCurrentWatchView = .dashboard

        // Workout status messages should go through
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // User navigates to podcast
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openPodcast)
        mockService.mockCurrentWatchView = .podcast

        // Workout status should NOT go through on podcast view
        try await mockService.sendMessage(.workoutStatus(isActive: false))
        XCTAssertEqual(mockService.sentMessages.count, 1, "Message should be filtered out")

        // But podcast updates should work
        try await mockService.sendMessage(.podcastUpdate(title: "New Episode"))
        XCTAssertEqual(mockService.sentMessages.count, 2)
    }

    // MARK: - Scenario: Error Recovery Patterns

    /// Tests recovery from transient network errors.
    @MainActor
    func testScenario_TransientErrorRecovery() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // First send succeeds
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // Network error occurs
        mockService.sendMessageError = .messageSendFailed(reason: "Temporary network issue")

        do {
            try await mockService.sendMessage(.workoutStatus(isActive: false))
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Network recovers
        mockService.sendMessageError = nil

        // Retry succeeds
        try await mockService.sendMessage(.workoutStatus(isActive: false))
        XCTAssertEqual(mockService.sentMessages.count, 2)
    }

    /// Tests handling of multiple consecutive errors.
    @MainActor
    func testScenario_MultipleErrorsBeforeRecovery() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard
        mockService.sendMessageError = .watchNotReachable

        // Multiple failed attempts
        var errorCount = 0
        for _ in 0..<3 {
            do {
                try await mockService.sendMessage(.workoutStatus(isActive: true))
            } catch {
                errorCount += 1
            }
        }

        XCTAssertEqual(errorCount, 3)
        XCTAssertEqual(mockService.sentMessages.count, 0)

        // Recovery
        mockService.sendMessageError = nil
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    // MARK: - Scenario: Application Context Sync

    /// Tests application context synchronization across session states.
    @MainActor
    func testScenario_ApplicationContextSync() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()

        // Update context when connected
        try await mockService.updateApplicationContext([
            "lastWorkoutID": "workout-123",
            "preferences": ["metric": true]
        ])

        XCTAssertEqual(mockService.updatedContexts.count, 1)

        // Context updates when workout state changes
        try await mockService.updateApplicationContext([
            "workoutActive": true,
            "workoutID": "workout-456"
        ])

        try await mockService.updateApplicationContext([
            "workoutActive": false,
            "lastWorkoutID": "workout-456"
        ])

        XCTAssertEqual(mockService.updatedContexts.count, 3)
    }

    // MARK: - Scenario: Long Running Workout

    /// Tests extended workout session with many updates.
    @MainActor
    func testScenario_LongRunningWorkout() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .metrics
        await workoutService.setWorkoutInProgress(true)

        // Simulate 30 minutes of updates (one per minute)
        for i in 0..<30 {
            let distance = String(format: "%.2f km", Double(i + 1) * 0.2)
            let duration = String(format: "%d:%02d", (i + 1), 0)
            let update = WatchConnectivityTestFixtures.makeWorkoutUpdateData(
                distance: distance,
                duration: duration
            )
            try await mockService.sendMessage(.workoutUpdate(update))
        }

        // All updates should be sent
        XCTAssertEqual(mockService.messages(ofType: .workoutUpdate).count, 30)
    }

    // MARK: - Scenario: Watch-Initiated Actions

    /// Tests acknowledge requests from watch.
    @MainActor
    func testScenario_WatchAcknowledgement() async throws {
        // SETUP
        mockService.setupForSuccessfulSending()
        let mockWCService = createMockWatchConnectivityService()

        // Watch sends acknowledgment
        let response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .acknowledge(messageType: "workoutStatus")
        )

        // Handler processes acknowledgment
        if case .dashboard = response {
            // Acknowledgment returns dashboard data by default
        }

        XCTAssertTrue(messageHandler.wasRequestReceived(.acknowledge))
    }

    // MARK: - Helper Methods

    @MainActor
    private func createMockWatchConnectivityService() -> WatchConnectivityService {
        return WatchConnectivityService(mockSession: nil)
    }
}

// MARK: - Edge Case Scenario Tests

final class WatchConnectivityEdgeCaseScenarioTests: XCTestCase {

    // MARK: - Properties

    private var mockService: MockWatchConnectivityService!
    private var messageHandler: MockWatchMessageHandler!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockWatchConnectivityService()
        messageHandler = MockWatchMessageHandler()
        mockService.delegate = messageHandler
        cancellables = []
    }

    @MainActor
    override func tearDown() {
        mockService = nil
        messageHandler = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Edge Cases

    /// Tests handling of empty message content.
    @MainActor
    func testEdgeCase_EmptyPodcastTitle() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .podcast

        // Send podcast update with empty title
        try await mockService.sendMessage(.podcastUpdate(title: ""))

        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    /// Tests handling of very long podcast titles.
    @MainActor
    func testEdgeCase_VeryLongPodcastTitle() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .podcast

        let longTitle = String(repeating: "A", count: 1000)
        try await mockService.sendMessage(.podcastUpdate(title: longTitle))

        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    /// Tests handling of extreme coordinate values.
    @MainActor
    func testEdgeCase_ExtremeCoordinates() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .map

        // Test with edge coordinates
        let extremeLocation = LocationUpdateData(
            latitude: 89.999999,
            longitude: -179.999999
        )
        try await mockService.sendMessage(.locationUpdate(extremeLocation))

        let zeroLocation = LocationUpdateData(
            latitude: 0,
            longitude: 0
        )
        try await mockService.sendMessage(.locationUpdate(zeroLocation))

        XCTAssertEqual(mockService.messages(ofType: .locationUpdate).count, 2)
    }

    /// Tests handling of zero workout metrics.
    @MainActor
    func testEdgeCase_ZeroWorkoutMetrics() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .stats

        let zeroStats = StatsData(
            distanceKm: 0,
            durationSeconds: 0,
            averagePace: 0,
            calories: 0
        )
        try await mockService.sendMessage(.stats(zeroStats))

        XCTAssertEqual(mockService.messages(ofType: .stats).count, 1)
    }

    /// Tests handling of negative speed values.
    @MainActor
    func testEdgeCase_NegativeSpeedValue() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .map

        // CLLocation can report -1 for invalid speed
        let locationWithNegativeSpeed = LocationUpdateData(
            latitude: 37.7749,
            longitude: -122.4194,
            speed: -1
        )
        try await mockService.sendMessage(.locationUpdate(locationWithNegativeSpeed))

        XCTAssertEqual(mockService.messages(ofType: .locationUpdate).count, 1)
    }

    /// Tests same request sent multiple times in sequence.
    @MainActor
    func testEdgeCase_DuplicateRequests() async throws {
        mockService.setupForSuccessfulSending()
        let mockWCService = WatchConnectivityService(mockSession: nil)

        // Same request 5 times
        for _ in 0..<5 {
            _ = await messageHandler.watchConnectivityService(
                mockWCService,
                didReceiveRequest: .openDashboard
            )
        }

        XCTAssertEqual(messageHandler.requestCount(of: .openDashboard), 5)
    }

    /// Tests WatchConnectivity support check on unsupported device.
    @MainActor
    func testEdgeCase_UnsupportedDevice() async throws {
        mockService.mockIsSupported = false

        do {
            try await mockService.activate()
            XCTFail("Should throw on unsupported device")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .notSupported)
        }
    }

    /// Tests sending to .none view (no active view).
    @MainActor
    func testEdgeCase_SendToNoView() async throws {
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .none

        // All messages should be filtered out when view is .none
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        try await mockService.sendMessage(.podcastUpdate(title: "Test"))
        try await mockService.sendMessage(.locationUpdate(WatchConnectivityTestFixtures.locationSanFrancisco))
        try await mockService.sendMessage(.stats(WatchConnectivityTestFixtures.stats5K))

        XCTAssertEqual(mockService.sentMessages.count, 0, "No messages should be sent to .none view")
    }

    /// Tests large file metadata.
    @MainActor
    func testEdgeCase_LargeFileMetadata() async throws {
        mockService.setupForSuccessfulSending()

        let largeMetadata: [String: Any] = [
            "type": "routeImage",
            "workoutID": UUID().uuidString,
            "timestamp": Date().timeIntervalSince1970,
            "additionalData": String(repeating: "X", count: 500)
        ]

        let fileURL = WatchConnectivityTestFixtures.mockFileURL()
        try await mockService.transferFile(fileURL, metadata: largeMetadata)

        XCTAssertEqual(mockService.transferredFiles.count, 1)
    }
}
