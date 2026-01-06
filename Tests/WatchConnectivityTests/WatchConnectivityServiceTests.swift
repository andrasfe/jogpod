//
//  WatchConnectivityServiceTests.swift
//  JogPodTests
//
//  Comprehensive tests for WatchConnectivityService covering:
//  - Session activation
//  - Message sending/receiving
//  - Reachability changes
//  - Application context updates
//  - File transfers
//
//  Created for JogPod Revival project.
//

import XCTest
import Combine
import CoreLocation
@testable import JogPod

// MARK: - WatchConnectivityServiceTests

final class WatchConnectivityServiceTests: XCTestCase {

    // MARK: - Properties

    private var mockService: MockWatchConnectivityService!
    private var mockHandler: MockWatchMessageHandler!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockWatchConnectivityService()
        mockHandler = MockWatchMessageHandler()
        mockService.delegate = mockHandler
        cancellables = []
    }

    @MainActor
    override func tearDown() {
        mockService = nil
        mockHandler = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Session Activation Tests

    @MainActor
    func testActivationSucceeds() async throws {
        // Given
        mockService.mockIsSupported = true
        mockService.activationError = nil

        // When
        try await mockService.activate()

        // Then
        XCTAssertTrue(mockService.activateCalled)
        XCTAssertEqual(mockService.activateCallCount, 1)
        XCTAssertTrue(mockService.isActivated)
    }

    @MainActor
    func testActivationFailsWhenNotSupported() async {
        // Given
        mockService.mockIsSupported = false

        // When/Then
        do {
            try await mockService.activate()
            XCTFail("Expected activation to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .notSupported)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testActivationFailsWithError() async {
        // Given
        mockService.mockIsSupported = true
        mockService.activationError = .activationFailed(reason: "Test failure")

        // When/Then
        do {
            try await mockService.activate()
            XCTFail("Expected activation to throw")
        } catch let error as WatchConnectivityError {
            if case .activationFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testActivationCanBeCalledMultipleTimes() async throws {
        // Given
        mockService.mockIsSupported = true

        // When
        try await mockService.activate()
        try await mockService.activate()

        // Then
        XCTAssertEqual(mockService.activateCallCount, 2)
    }

    @MainActor
    func testSessionStatePublisher() async throws {
        // Given
        var receivedStates: [WatchSessionState] = []
        let expectation = expectation(description: "Receive states")
        expectation.expectedFulfillmentCount = 2

        mockService.sessionStatePublisher
            .sink { state in
                receivedStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        mockService.simulateSessionStateChange(.activating)
        mockService.simulateSessionStateChange(.activated)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedStates.contains(.activating))
        XCTAssertTrue(receivedStates.contains(.activated))
    }

    // MARK: - Message Sending Tests

    @MainActor
    func testSendMessageSucceeds() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then
        XCTAssertEqual(mockService.sentMessages.count, 1)
        XCTAssertTrue(mockService.wasMessageSent(.workoutStatus))
    }

    @MainActor
    func testSendMessageFailsWhenNotActivated() async {
        // Given
        mockService.mockIsSupported = true
        mockService.mockIsActivated = false

        // When/Then
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Expected send to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .sessionNotActivated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testSendMessageFailsWhenNotReachable() async {
        // Given
        mockService.mockIsSupported = true
        mockService.mockIsActivated = true
        mockService.mockIsReachable = false

        // When/Then
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Expected send to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotReachable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testSendMessageWithError() async {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard
        mockService.sendMessageError = .messageSendFailed(reason: "Test error")

        // When/Then
        do {
            try await mockService.sendMessage(.workoutStatus(isActive: true))
            XCTFail("Expected send to throw")
        } catch let error as WatchConnectivityError {
            if case .messageSendFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testSendMessageWithoutReply() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When
        try await mockService.sendMessageWithoutReply(.podcastUpdate(title: "Test"))

        // Then
        XCTAssertEqual(mockService.sentMessagesWithoutReply.count, 1)
        XCTAssertTrue(mockService.wasMessageSent(.podcastUpdate))
    }

    // MARK: - View-Based Message Filtering Tests

    @MainActor
    func testMessageSentWhenTargetViewMatches() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard

        // When - workout status targets dashboard and metrics
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then
        XCTAssertEqual(mockService.sentMessages.count, 1)
    }

    @MainActor
    func testMessageNotSentWhenTargetViewDoesNotMatch() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .podcast  // Not in workout status targets

        // When - workout status targets dashboard and metrics, not podcast
        try await mockService.sendMessage(.workoutStatus(isActive: true))

        // Then - message should be silently skipped
        XCTAssertEqual(mockService.sentMessages.count, 0)
    }

    @MainActor
    func testLocationUpdateOnlySentToMapView() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let locationData = WatchConnectivityTestFixtures.locationSanFrancisco

        // When - map view
        mockService.mockCurrentWatchView = .map
        try await mockService.sendMessage(.locationUpdate(locationData))

        // Then
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // Reset
        mockService.sentMessages = []

        // When - dashboard view
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.sendMessage(.locationUpdate(locationData))

        // Then - should not send
        XCTAssertEqual(mockService.sentMessages.count, 0)
    }

    @MainActor
    func testStatsOnlySentToStatsView() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let statsData = WatchConnectivityTestFixtures.stats5K

        // When - stats view
        mockService.mockCurrentWatchView = .stats
        try await mockService.sendMessage(.stats(statsData))

        // Then
        XCTAssertEqual(mockService.sentMessages.count, 1)

        // Reset
        mockService.sentMessages = []

        // When - metrics view
        mockService.mockCurrentWatchView = .metrics
        try await mockService.sendMessage(.stats(statsData))

        // Then - should not send
        XCTAssertEqual(mockService.sentMessages.count, 0)
    }

    // MARK: - Reachability Tests

    @MainActor
    func testReachabilityPublisher() async {
        // Given
        var receivedValues: [Bool] = []
        let expectation = expectation(description: "Receive reachability")
        expectation.expectedFulfillmentCount = 2

        mockService.reachabilityPublisher
            .dropFirst()  // Skip initial value
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
        XCTAssertEqual(receivedValues, [true, false])
    }

    @MainActor
    func testReachabilityChangeClearsCurrentView() async {
        // Given
        mockService.mockCurrentWatchView = .dashboard

        // When
        mockService.simulateReachabilityChange(false)

        // Then
        XCTAssertEqual(mockService.currentWatchView, .none)
    }

    @MainActor
    func testReachabilityChangeToTrueDoesNotAffectView() async {
        // Given
        mockService.mockCurrentWatchView = .dashboard

        // When
        mockService.simulateReachabilityChange(true)

        // Then - view should remain unchanged
        XCTAssertEqual(mockService.currentWatchView, .dashboard)
    }

    // MARK: - Application Context Tests

    @MainActor
    func testUpdateApplicationContext() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let context = WatchConnectivityTestFixtures.applicationContextWorkoutActive

        // When
        try await mockService.updateApplicationContext(context)

        // Then
        XCTAssertEqual(mockService.updatedContexts.count, 1)
    }

    @MainActor
    func testUpdateContextFailsWhenNotActivated() async {
        // Given
        mockService.mockIsSupported = true
        mockService.mockIsActivated = false

        // When/Then
        do {
            try await mockService.updateApplicationContext([:])
            XCTFail("Expected to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .sessionNotActivated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testUpdateContextWithError() async {
        // Given
        mockService.setupForSuccessfulSending()
        mockService.updateContextError = .messageSendFailed(reason: "Context update failed")

        // When/Then
        do {
            try await mockService.updateApplicationContext([:])
            XCTFail("Expected to throw")
        } catch let error as WatchConnectivityError {
            if case .messageSendFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testMultipleContextUpdates() async throws {
        // Given
        mockService.setupForSuccessfulSending()

        // When
        try await mockService.updateApplicationContext(["key1": "value1"])
        try await mockService.updateApplicationContext(["key2": "value2"])
        try await mockService.updateApplicationContext(["key3": "value3"])

        // Then
        XCTAssertEqual(mockService.updatedContexts.count, 3)
    }

    // MARK: - File Transfer Tests

    @MainActor
    func testTransferFile() async throws {
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
    func testTransferFileWithoutMetadata() async throws {
        // Given
        mockService.setupForSuccessfulSending()
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()

        // When
        try await mockService.transferFile(fileURL, metadata: nil)

        // Then
        XCTAssertEqual(mockService.transferredFiles.count, 1)
        XCTAssertNil(mockService.transferredFiles[0].metadata)
    }

    @MainActor
    func testTransferFileFailsWhenNotPaired() async {
        // Given
        mockService.mockIsSupported = true
        mockService.mockIsActivated = true
        mockService.mockIsPaired = false
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()

        // When/Then
        do {
            try await mockService.transferFile(fileURL, metadata: nil)
            XCTFail("Expected to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchNotPaired)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testTransferFileFailsWhenAppNotInstalled() async {
        // Given
        mockService.mockIsSupported = true
        mockService.mockIsActivated = true
        mockService.mockIsPaired = true
        mockService.mockIsWatchAppInstalled = false
        let fileURL = WatchConnectivityTestFixtures.mockFileURL()

        // When/Then
        do {
            try await mockService.transferFile(fileURL, metadata: nil)
            XCTFail("Expected to throw")
        } catch let error as WatchConnectivityError {
            XCTAssertEqual(error, .watchAppNotInstalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Watch State Tests

    @MainActor
    func testWatchAvailability() {
        // Given paired and installed
        mockService.mockIsPaired = true
        mockService.mockIsWatchAppInstalled = true

        // Then
        XCTAssertTrue(mockService.isWatchAvailable)

        // Given not paired
        mockService.mockIsPaired = false
        XCTAssertFalse(mockService.isWatchAvailable)

        // Given paired but not installed
        mockService.mockIsPaired = true
        mockService.mockIsWatchAppInstalled = false
        XCTAssertFalse(mockService.isWatchAvailable)
    }

    @MainActor
    func testSimulateWatchStateChange() {
        // Given
        mockService.mockIsPaired = true
        mockService.mockIsWatchAppInstalled = true

        // When
        mockService.simulateWatchStateChange(isPaired: false)

        // Then
        XCTAssertFalse(mockService.mockIsPaired)
        XCTAssertEqual(mockService.mockSessionState, .notPaired)

        // When
        mockService.mockIsPaired = true
        mockService.simulateWatchStateChange(isAppInstalled: false)

        // Then
        XCTAssertFalse(mockService.mockIsWatchAppInstalled)
        XCTAssertEqual(mockService.mockSessionState, .appNotInstalled)
    }

    // MARK: - Reset Tests

    @MainActor
    func testReset() async throws {
        // Given - setup some state
        mockService.setupForSuccessfulSending()
        mockService.mockCurrentWatchView = .dashboard
        try await mockService.activate()
        try await mockService.sendMessage(.workoutStatus(isActive: true))
        try await mockService.updateApplicationContext(["test": true])

        // When
        mockService.reset()

        // Then
        XCTAssertFalse(mockService.isActivated)
        XCTAssertFalse(mockService.isReachable)
        XCTAssertEqual(mockService.currentWatchView, .none)
        XCTAssertEqual(mockService.sentMessages.count, 0)
        XCTAssertEqual(mockService.updatedContexts.count, 0)
        XCTAssertFalse(mockService.activateCalled)
    }
}

// MARK: - Message Type Tests

final class WatchMessageTypeTests: XCTestCase {

    @MainActor
    func testWorkoutStatusTargetViews() {
        let message = WatchPushMessage.workoutStatus(isActive: true)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.metrics))
        XCTAssertFalse(message.targetViews.contains(.podcast))
        XCTAssertFalse(message.targetViews.contains(.map))
        XCTAssertFalse(message.targetViews.contains(.stats))
    }

    @MainActor
    func testPodcastUpdateTargetViews() {
        let message = WatchPushMessage.podcastUpdate(title: "Test")
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.podcast))
        XCTAssertFalse(message.targetViews.contains(.metrics))
    }

    @MainActor
    func testPlayerUpdateTargetViews() {
        let message = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: nil)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.podcast))
    }

    @MainActor
    func testWorkoutUpdateTargetViews() {
        let data = WatchConnectivityTestFixtures.workoutUpdateComplete
        let message = WatchPushMessage.workoutUpdate(data)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.metrics))
    }

    @MainActor
    func testLocationUpdateTargetViews() {
        let data = WatchConnectivityTestFixtures.locationSanFrancisco
        let message = WatchPushMessage.locationUpdate(data)
        XCTAssertEqual(message.targetViews.count, 1)
        XCTAssertTrue(message.targetViews.contains(.map))
    }

    @MainActor
    func testStatsTargetViews() {
        let data = WatchConnectivityTestFixtures.stats5K
        let message = WatchPushMessage.stats(data)
        XCTAssertEqual(message.targetViews.count, 1)
        XCTAssertTrue(message.targetViews.contains(.stats))
    }
}
