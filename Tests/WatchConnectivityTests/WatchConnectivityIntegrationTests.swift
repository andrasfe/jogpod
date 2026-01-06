//
//  WatchConnectivityIntegrationTests.swift
//  JogPodTests
//
//  Integration tests for WatchConnectivity that test the full message flow
//  between iOS and watchOS components. These tests verify end-to-end
//  communication scenarios using mocks for the actual WCSession.
//
//  Test coverage:
//  - Full request/response cycle
//  - State synchronization between service and handler
//  - Multiple sequential message flows
//  - Error propagation and recovery
//  - View-based message filtering in real scenarios
//  - Session lifecycle integration
//
//  Created for JogPod Revival project.
//

import XCTest
import Combine
import CoreLocation
@testable import JogPod

// MARK: - WatchConnectivityIntegrationTests

final class WatchConnectivityIntegrationTests: XCTestCase {

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
        mockService = nil
        messageHandler = nil
        workoutService = nil
        persistenceManager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Full Request/Response Cycle Tests

    @MainActor
    func testFullDashboardRequestCycle() async throws {
        // Given - Configure state
        await workoutService.setWorkoutInProgress(true)
        persistenceManager.workoutCount = 25
        mockService.setupForSuccessfulSending()

        // When - Watch opens dashboard
        let request = WatchRequest.openDashboard
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: request
        )

        // Then - Verify response contains correct data
        if case .dashboard(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
            XCTAssertEqual(data.workoutCount, 25)
            XCTAssertTrue(data.isInitialized)
        } else {
            XCTFail("Expected dashboard response")
        }

        // And - Verify handler tracked the request
        XCTAssertEqual(messageHandler.requestCallCount, 1)
        XCTAssertTrue(messageHandler.wasRequestReceived(.openDashboard))
    }

    @MainActor
    func testFullMetricsRequestCycle() async throws {
        // Given
        await workoutService.setWorkoutInProgress(true)
        mockService.setupForSuccessfulSending()

        // When
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openMetrics
        )

        // Then
        if case .metrics(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
            XCTAssertEqual(data.publisherCount, WatchMessageHandler.publisherCount)
        } else {
            XCTFail("Expected metrics response")
        }

        XCTAssertTrue(messageHandler.wasRequestReceived(.openMetrics))
    }

    @MainActor
    func testFullPodcastRequestCycle() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        messageHandler.podcastResponse = .podcast(PodcastData(
            currentTitle: "Test Episode",
            isPlaying: true
        ))

        // When
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openPodcast
        )

        // Then
        if case .podcast(let data) = response {
            XCTAssertEqual(data.currentTitle, "Test Episode")
            XCTAssertTrue(data.isPlaying)
        } else {
            XCTFail("Expected podcast response")
        }

        XCTAssertTrue(messageHandler.wasRequestReceived(.openPodcast))
    }

    @MainActor
    func testFullMapRequestCycle() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openMap
        )

        // Then
        if case .map = response {
            // Success - map request returns acknowledgment
        } else {
            XCTFail("Expected map response")
        }

        XCTAssertTrue(messageHandler.wasRequestReceived(.openMap))
    }

    @MainActor
    func testFullStatsRequestCycle() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openStats
        )

        // Then
        if case .stats = response {
            // Success - stats request returns acknowledgment
        } else {
            XCTFail("Expected stats response")
        }

        XCTAssertTrue(messageHandler.wasRequestReceived(.openStats))
    }

    // MARK: - State Synchronization Tests

    @MainActor
    func testWorkoutStateChangeSynchronization() async throws {
        // Given - Start with no workout
        await workoutService.setWorkoutInProgress(false)
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Query initial state
        var response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openDashboard
        )

        // Then - Initial state is no workout
        if case .dashboard(let data) = response {
            XCTAssertFalse(data.workoutInProgress)
        }

        // When - Start a workout and query again
        await workoutService.setWorkoutInProgress(true)
        response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openDashboard
        )

        // Then - State reflects workout in progress
        if case .dashboard(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
        }
    }

    @MainActor
    func testPushMessageSentOnStateChange() async throws {
        // Given - Service ready, watch on dashboard
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Send workout status update
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then - Message was sent
        XCTAssertEqual(mockService.sentMessages.count, 1)
        XCTAssertTrue(mockService.wasMessageSent(.workoutStatus))
    }

    @MainActor
    func testMultiplePushMessagesInSequence() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Send multiple status updates
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        try await mockService.sendMessage(.workoutStatus(isActive: false))
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then - All messages sent
        XCTAssertEqual(mockService.messages(ofType: .workoutStatus).count, 3)
    }

    // MARK: - Multiple Sequential Request Tests

    @MainActor
    func testNavigationBetweenViews() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        await workoutService.setWorkoutInProgress(true)

        let mockWCService = createMockWatchConnectivityService()

        // When - User navigates through views
        // Start at dashboard
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openDashboard)

        // Go to metrics
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openMetrics)

        // Go to podcast
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openPodcast)

        // Go to map
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openMap)

        // Go to stats
        _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openStats)

        // Then - All requests were processed
        XCTAssertEqual(messageHandler.requestCallCount, 5)
        XCTAssertTrue(messageHandler.wasRequestReceived(.openDashboard))
        XCTAssertTrue(messageHandler.wasRequestReceived(.openMetrics))
        XCTAssertTrue(messageHandler.wasRequestReceived(.openPodcast))
        XCTAssertTrue(messageHandler.wasRequestReceived(.openMap))
        XCTAssertTrue(messageHandler.wasRequestReceived(.openStats))
    }

    @MainActor
    func testRapidViewChanges() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let mockWCService = createMockWatchConnectivityService()

        // When - Rapid navigation (simulates quick swipes)
        for _ in 0..<10 {
            _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openDashboard)
            _ = await messageHandler.watchConnectivityService(mockWCService, didReceiveRequest: .openMetrics)
        }

        // Then - All requests processed correctly
        XCTAssertEqual(messageHandler.requestCallCount, 20)
        XCTAssertEqual(messageHandler.requestCount(of: .openDashboard), 10)
        XCTAssertEqual(messageHandler.requestCount(of: .openMetrics), 10)
    }

    // MARK: - View-Based Message Filtering Integration Tests

    @MainActor
    func testViewBasedFilteringPreventsSendToWrongView() async throws {
        // Given - Watch is on dashboard
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Try to send location update (only for map view)
        let locationData = WatchConnectivityTestFixtures.locationSanFrancisco
        try await mockService.sendMessage(.locationUpdate(locationData))

        // Then - Message was NOT sent (filtered out)
        XCTAssertEqual(mockService.sentMessages.count, 0)
        XCTAssertFalse(mockService.wasMessageSent(.locationUpdate))
    }

    @MainActor
    func testViewBasedFilteringAllowsSendToCorrectView() async throws {
        // Given - Watch is on map view
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .map

        // When - Send location update (targeted at map)
        let locationData = WatchConnectivityTestFixtures.locationSanFrancisco
        try await mockService.sendMessage(.locationUpdate(locationData))

        // Then - Message was sent
        XCTAssertEqual(mockService.sentMessages.count, 1)
        XCTAssertTrue(mockService.wasMessageSent(.locationUpdate))
    }

    @MainActor
    func testViewChangeEnablesMessageDelivery() async throws {
        // Given - Start on dashboard
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Try sending stats (only for stats view) - should fail
        let statsData = WatchConnectivityTestFixtures.stats5K
        try await mockService.sendMessage(.stats(statsData))
        XCTAssertEqual(mockService.sentMessages.count, 0)

        // When - Change to stats view and try again
        mockService.simulateWatchViewChange(.stats)
        try await mockService.sendMessage(.stats(statsData))

        // Then - Now message is sent
        XCTAssertEqual(mockService.sentMessages.count, 1)
        XCTAssertTrue(mockService.wasMessageSent(.stats))
    }

    @MainActor
    func testMultiTargetMessagesSentToValidViews() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When - Test podcastUpdate which targets both dashboard and podcast
        // On dashboard
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.podcastUpdate(title: "Episode 1"))
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // On podcast view
        mockService.mockCurrentWatchView = .podcast
        try await mockService.sendMessage(.podcastUpdate(title: "Episode 2"))
        XCTAssertEqual(mockService.sentMessages.count, 2)

        // On metrics (not a target)
        mockService.mockCurrentWatchView = .metrics
        try await mockService.sendMessage(.podcastUpdate(title: "Episode 3"))
        XCTAssertEqual(mockService.sentMessages.count, 2)  // Still 2, not sent
    }

    // MARK: - Session Lifecycle Integration Tests

    @MainActor
    func testActivationEnablesMessaging() async throws {
        // Given - Reset service
        mockService.reset()
        mockService.mockIsSupported = true

        // When - Try to send before activation
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Should throw when not activated")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .sessionNotActivated)
        }

        // When - Activate
        try await mockService.activate()

        // Then - Service is activated
        XCTAssertTrue(mockService.isActivated)

        // And - Messaging now works (after setting reachable)
        mockService.mockIsReachable = true
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    @MainActor
    func testReachabilityAffectsMessaging() async throws {
        // Given - Activated but not reachable
        mockService.mockIsSupported = true
        mockService.mockIsActivated = true
        mockService.mockIsReachable = false

        // When - Try to send
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Should throw when not reachable")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotReachable)
        }

        // When - Become reachable
        mockService.simulateReachabilityChange(true)

        // Then - Messaging works
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    @MainActor
    func testReachabilityChangeClearsView() async throws {
        // Given - Connected and viewing dashboard
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Become unreachable
        mockService.simulateReachabilityChange(false)

        // Then - View is cleared
        XCTAssertEqual(mockService.currentWatchView, .none)
    }

    // MARK: - Error Propagation and Recovery Tests

    @MainActor
    func testHandlerReturnsNotInitializedWhenAppNotReady() async throws {
        // Given - App not initialized
        messageHandler.isAppInitialized = false

        // When - Any request
        let response = await messageHandler.watchConnectivityService(
            createMockWatchConnectivityService(),
            didReceiveRequest: .openDashboard
        )

        // Then - Returns not initialized
        if case .notInitialized = response {
            // Success
        } else {
            XCTFail("Expected notInitialized response")
        }
    }

    @MainActor
    func testRecoveryAfterInitialization() async throws {
        // Given - App not initialized
        messageHandler.isAppInitialized = false
        let mockWCService = createMockWatchConnectivityService()

        // When - First request fails
        var response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )

        guard case .notInitialized = response else {
            XCTFail("Should be not initialized")
            return
        }

        // When - App becomes initialized and retry
        messageHandler.isAppInitialized = true
        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )

        // Then - Success
        if case .dashboard = response {
            // Success
        } else {
            XCTFail("Expected dashboard response after initialization")
        }
    }

    @MainActor
    func testServiceErrorRecovery() async throws {
        // Given - Service with send error configured
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard
        mockService.sendMessageError = .messageSendFailed(reason: "Network error")

        // When - First send fails
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // When - Clear error and retry
        mockService.sendMessageError = nil
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then - Success
        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    // MARK: - Application Context Integration Tests

    @MainActor
    func testApplicationContextUpdate() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When - Update context
        let context = WatchConnectivityTestFixtures.applicationContextWorkoutActive
        try await mockService.updateApplicationContext(context)

        // Then - Context was updated
        XCTAssertEqual(mockService.updatedContexts.count, 1)
    }

    @MainActor
    func testMultipleContextUpdatesOverwrite() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When - Multiple updates
        try await mockService.updateApplicationContext(["state": "idle"])
        try await mockService.updateApplicationContext(["state": "active"])
        try await mockService.updateApplicationContext(["state": "completed"])

        // Then - All updates tracked
        XCTAssertEqual(mockService.updatedContexts.count, 3)
    }

    // MARK: - File Transfer Integration Tests

    @MainActor
    func testFileTransferWhenWatchAvailable() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()
        let metadata = WatchConnectivityTestFixtures.mockFileMetadata()

        // When
        try await mockService.transferFile(fileURL, metadata: metadata)

        // Then
        XCTAssertEqual(mockService.transferredFiles.count, 1)
        XCTAssertEqual(mockService.transferredFiles[0].fileURL, fileURL)
    }

    @MainActor
    func testFileTransferFailsWhenWatchNotPaired() async throws {
        // Given - Watch not paired
        mockService.setupForSuccessfulSending()
        mockService.mockIsPaired = false
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()

        // When/Then
        do {
            try await mockService.transferFile(fileURL, metadata: nil)
            XCTFail("Should throw when watch not paired")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotPaired)
        }
    }

    // MARK: - Combine Publisher Integration Tests

    @MainActor
    func testSessionStatePublisherEmitsOnChange() async throws {
        // Given
        var receivedStates: [WatchSessionState] = []
        let expectation = expectation(description: "Receive state changes")
        expectation.expectedFulfillmentCount = 3

        mockService.sessionStatePublisher
            .sink { state in
                receivedStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When - Simulate state changes
        mockService.simulateSessionStateChange(.activating)
        mockService.simulateSessionStateChange(.activated)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedStates.contains(.notActivated))  // Initial
        XCTAssertTrue(receivedStates.contains(.activating))
        XCTAssertTrue(receivedStates.contains(.activated))
    }

    @MainActor
    func testReachabilityPublisherEmitsOnChange() async throws {
        // Given
        var receivedValues: [Bool] = []
        let expectation = expectation(description: "Receive reachability changes")
        expectation.expectedFulfillmentCount = 3

        mockService.reachabilityPublisher
            .sink { isReachable in
                receivedValues.append(isReachable)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        mockService.simulateReachabilityChange(true)
        mockService.simulateReachabilityChange(false)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [false, true, false])
    }

    // MARK: - Workout Flow Integration Tests

    @MainActor
    func testCompleteWorkoutFlow() async throws {
        // Given - Setup all components
        mockService.setupForSuccessfulSending()
        await workoutService.setWorkoutInProgress(false)
        let mockWCService = createMockWatchConnectivityService()

        // Simulate: User opens watch app to dashboard
        var response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openDashboard
        )
        if case .dashboard(let data) = response {
            XCTAssertFalse(data.workoutInProgress)
        }

        // User starts workout (via phone)
        await workoutService.setWorkoutInProgress(true)
        mockService.mockCurrentWatchView = .dashboard

        // Watch receives push notification about workout start
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // User navigates to metrics
        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openMetrics
        )
        if case .metrics(let data) = response {
            XCTAssertTrue(data.workoutInProgress)
        }

        // Watch receives workout updates on metrics view
        mockService.mockCurrentWatchView = .metrics
        let workoutUpdate = WatchConnectivityTestFixtures.workoutUpdateComplete
        try await mockService.sendMessage(.workoutUpdate(workoutUpdate))
        XCTAssertEqual(mockService.sentMessages.count, 2)

        // User ends workout
        await workoutService.setWorkoutInProgress(false)
        try await mockService.sendMessage(.workoutStatus(isActive: false))

        // User views stats
        response = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openStats
        )
        if case .stats = response {
            // Stats view acknowledged
        }

        // Verify all expected messages sent
        XCTAssertEqual(mockService.messages(ofType: .workoutStatus).count, 2)
        XCTAssertEqual(mockService.messages(ofType: .workoutUpdate).count, 1)
    }

    @MainActor
    func testWorkoutWithLocationTracking() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        await workoutService.setWorkoutInProgress(true)
        let mockWCService = createMockWatchConnectivityService()

        // User opens map view
        _ = await messageHandler.watchConnectivityService(
            mockWCService,
            didReceiveRequest: .openMap
        )
        mockService.mockCurrentWatchView = .map

        // Location updates are sent
        let locations = [
            WatchConnectivityTestFixtures.locationSanFrancisco,
            WatchConnectivityTestFixtures.locationNewYork
        ]

        for location in locations {
            try await mockService.sendMessage(.locationUpdate(location))
        }

        // Then - All location updates were sent
        XCTAssertEqual(mockService.messages(ofType: .locationUpdate).count, 2)
    }

    // MARK: - Helper Methods

    @MainActor
    private func createMockWatchConnectivityService() -> WatchConnectivityService {
        return WatchConnectivityService(mockSession: nil)
    }
}

// MARK: - Concurrent Access Integration Tests

final class WatchConnectivityConcurrencyIntegrationTests: XCTestCase {

    @MainActor
    func testConcurrentMessageSending() async throws {
        // Given
        let mockService = MockWatchConnectivityService()
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - Send multiple messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    try? await mockService.sendMessage(.workoutStatus(isActive: i % 2 == 0))
                }
            }
        }

        // Then - All messages sent
        XCTAssertEqual(mockService.sentMessages.count, 10)
    }

    @MainActor
    func testConcurrentRequestHandling() async throws {
        // Given
        let handler = MockWatchMessageHandler()
        handler.isAppInitialized = true
        let mockWCService = WatchConnectivityService(mockSession: nil)

        // When - Handle multiple requests concurrently
        await withTaskGroup(of: WatchResponse.self) { group in
            let requests: [WatchRequest] = [
                .openDashboard, .openMetrics, .openPodcast,
                .openMap, .openStats
            ]

            for request in requests {
                group.addTask { @MainActor in
                    await handler.watchConnectivityService(mockWCService, didReceiveRequest: request)
                }
            }
        }

        // Then - All requests handled
        XCTAssertEqual(handler.requestCallCount, 5)
    }
}
