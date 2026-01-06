//
//  MockWCSessionTests.swift
//  JogPodTests
//
//  Tests for MockWCSession implementation to verify the mock behaves correctly.
//
//  Created for JogPod Revival project.
//

import XCTest
import WatchConnectivity
@testable import JogPod

// MARK: - MockWCSessionTests

final class MockWCSessionTests: XCTestCase {

    // MARK: - Properties

    private var mockSession: MockWCSession!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockSession = MockWCSession()
    }

    @MainActor
    override func tearDown() {
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    @MainActor
    func testDefaultState() {
        // Given a fresh mock session
        // Then default values should be set
        XCTAssertTrue(mockSession.mockIsSupported)
        XCTAssertEqual(mockSession.mockActivationState, .notActivated)
        XCTAssertTrue(mockSession.mockIsPaired)
        XCTAssertTrue(mockSession.mockIsWatchAppInstalled)
        XCTAssertFalse(mockSession.mockIsReachable)
        XCTAssertFalse(mockSession.activateCalled)
        XCTAssertEqual(mockSession.activateCallCount, 0)
    }

    // MARK: - Activation Tests

    @MainActor
    func testActivate() {
        // When
        mockSession.activate()

        // Then
        XCTAssertTrue(mockSession.activateCalled)
        XCTAssertEqual(mockSession.activateCallCount, 1)
    }

    @MainActor
    func testMultipleActivateCalls() {
        // When
        mockSession.activate()
        mockSession.activate()
        mockSession.activate()

        // Then
        XCTAssertEqual(mockSession.activateCallCount, 3)
    }

    @MainActor
    func testSimulateActivationSuccess() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate

        // When
        mockSession.simulateActivation(state: .activated)

        // Then
        XCTAssertEqual(mockSession.mockActivationState, .activated)
        XCTAssertTrue(delegate.activationDidCompleteCalled)
        XCTAssertEqual(delegate.lastActivationState, .activated)
        XCTAssertNil(delegate.lastActivationError)
    }

    @MainActor
    func testSimulateActivationWithError() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        let expectedError = MockWCSessionError.sessionNotActivated

        // When
        mockSession.simulateActivation(state: .notActivated, error: expectedError)

        // Then
        XCTAssertEqual(mockSession.mockActivationState, .notActivated)
        XCTAssertTrue(delegate.activationDidCompleteCalled)
        XCTAssertNotNil(delegate.lastActivationError)
    }

    // MARK: - Message Sending Tests

    @MainActor
    func testSendMessageWithReplyHandler() {
        // Given
        let message: [String: Any] = ["test": "value"]
        var receivedReply: [String: Any]?
        mockSession.mockMessageReply = ["reply": "data"]

        let expectation = expectation(description: "Reply received")

        // When
        mockSession.sendMessage(
            message,
            replyHandler: { reply in
                receivedReply = reply
                expectation.fulfill()
            },
            errorHandler: nil
        )

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.sentMessages.count, 1)
        XCTAssertTrue(mockSession.sentMessages[0].hasReplyHandler)
        XCTAssertNotNil(receivedReply)
        XCTAssertEqual(receivedReply?["reply"] as? String, "data")
    }

    @MainActor
    func testSendMessageWithoutReplyHandler() {
        // Given
        let message: [String: Any] = ["test": "value"]

        // When
        mockSession.sendMessage(message, replyHandler: nil, errorHandler: nil)

        // Then
        XCTAssertEqual(mockSession.sentMessages.count, 1)
        XCTAssertFalse(mockSession.sentMessages[0].hasReplyHandler)
    }

    @MainActor
    func testSendMessageWithError() {
        // Given
        let message: [String: Any] = ["test": "value"]
        var receivedError: Error?
        mockSession.sendMessageError = MockWCSessionError.messageSendFailed

        let expectation = expectation(description: "Error received")

        // When
        mockSession.sendMessage(
            message,
            replyHandler: nil,
            errorHandler: { error in
                receivedError = error
                expectation.fulfill()
            }
        )

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(mockSession.sentMessages.count, 1)
        XCTAssertNotNil(receivedError)
    }

    @MainActor
    func testSendMessageTracking() {
        // When
        mockSession.sendMessage(["key1": "value1"], replyHandler: nil, errorHandler: nil)
        mockSession.sendMessage(["key2": "value2"], replyHandler: nil, errorHandler: nil)

        // Then
        XCTAssertEqual(mockSession.sentMessageCount, 2)
        XCTAssertTrue(mockSession.wasMessageSent(withKey: "key1"))
        XCTAssertTrue(mockSession.wasMessageSent(withKey: "key2"))
        XCTAssertFalse(mockSession.wasMessageSent(withKey: "key3"))
    }

    // MARK: - Application Context Tests

    @MainActor
    func testUpdateApplicationContext() throws {
        // Given
        let context: [String: Any] = ["workout": true]

        // When
        try mockSession.updateApplicationContext(context)

        // Then
        XCTAssertEqual(mockSession.updatedContexts.count, 1)
        XCTAssertEqual(mockSession.mockApplicationContext["workout"] as? Bool, true)
    }

    @MainActor
    func testUpdateApplicationContextWithError() {
        // Given
        mockSession.updateContextError = MockWCSessionError.contextUpdateFailed

        // When/Then
        XCTAssertThrowsError(try mockSession.updateApplicationContext([:])) { error in
            XCTAssertEqual(error as? MockWCSessionError, .contextUpdateFailed)
        }
    }

    // MARK: - User Info Transfer Tests

    @MainActor
    func testTransferUserInfo() {
        // Given
        let userInfo: [String: Any] = ["key": "value"]

        // When
        mockSession.transferUserInfo(userInfo)

        // Then
        XCTAssertEqual(mockSession.sentUserInfo.count, 1)
    }

    // MARK: - File Transfer Tests

    @MainActor
    func testTransferFile() {
        // Given
        let fileURL = URL(fileURLWithPath: "/tmp/test.png")
        let metadata: [String: Any] = ["type": "image"]

        // When
        mockSession.transferFile(fileURL, metadata: metadata)

        // Then
        XCTAssertEqual(mockSession.transferredFiles.count, 1)
        XCTAssertEqual(mockSession.transferredFiles[0].fileURL, fileURL)
    }

    // MARK: - Reachability Simulation Tests

    @MainActor
    func testSimulateReachabilityChange() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        mockSession.mockIsReachable = false

        // When
        mockSession.simulateReachabilityChange(reachable: true)

        // Then
        XCTAssertTrue(mockSession.mockIsReachable)
        XCTAssertTrue(delegate.reachabilityDidChangeCalled)

        // When
        mockSession.simulateReachabilityChange(reachable: false)

        // Then
        XCTAssertFalse(mockSession.mockIsReachable)
    }

    // MARK: - Received Message Simulation Tests

    @MainActor
    func testSimulateReceivedMessage() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        let message: [String: Any] = ["request": "dashboard"]

        // When
        mockSession.simulateReceivedMessage(message)

        // Then
        XCTAssertTrue(delegate.didReceiveMessageCalled)
        XCTAssertEqual(delegate.lastReceivedMessage?["request"] as? String, "dashboard")
    }

    @MainActor
    func testSimulateReceivedMessageWithReplyHandler() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        let message: [String: Any] = ["request": "dashboard"]

        var replySent = false
        let replyHandler: ([String: Any]) -> Void = { _ in
            replySent = true
        }

        // When
        mockSession.simulateReceivedMessage(message, replyHandler: replyHandler)

        // Then
        XCTAssertTrue(delegate.didReceiveMessageWithReplyHandlerCalled)
    }

    // MARK: - Application Context Simulation Tests

    @MainActor
    func testSimulateReceivedApplicationContext() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        let context: [String: Any] = ["key": "value"]

        // When
        mockSession.simulateReceivedApplicationContext(context)

        // Then
        XCTAssertEqual(mockSession.mockReceivedApplicationContext["key"] as? String, "value")
        XCTAssertTrue(delegate.didReceiveApplicationContextCalled)
    }

    // MARK: - Watch State Simulation Tests

    @MainActor
    func testSimulateWatchStateChange() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate

        // When
        mockSession.simulateWatchStateChange(isPaired: false, isAppInstalled: true)

        // Then
        XCTAssertFalse(mockSession.mockIsPaired)
        XCTAssertTrue(mockSession.mockIsWatchAppInstalled)
        XCTAssertTrue(delegate.watchStateDidChangeCalled)
    }

    // MARK: - Session Lifecycle Simulation Tests

    @MainActor
    func testSimulateSessionBecameInactive() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        mockSession.mockActivationState = .activated

        // When
        mockSession.simulateSessionBecameInactive()

        // Then
        XCTAssertEqual(mockSession.mockActivationState, .inactive)
        XCTAssertTrue(delegate.sessionDidBecomeInactiveCalled)
    }

    @MainActor
    func testSimulateSessionDeactivation() {
        // Given
        let delegate = MockWCSessionDelegate()
        mockSession.delegate = delegate
        mockSession.mockActivationState = .inactive

        // When
        mockSession.simulateSessionDeactivation()

        // Then
        XCTAssertEqual(mockSession.mockActivationState, .notActivated)
        XCTAssertTrue(delegate.sessionDidDeactivateCalled)
    }

    // MARK: - Reset Tests

    @MainActor
    func testReset() {
        // Given - setup some state
        mockSession.mockActivationState = .activated
        mockSession.mockIsReachable = true
        mockSession.sendMessage(["test": 1], replyHandler: nil, errorHandler: nil)
        try? mockSession.updateApplicationContext(["key": "value"])
        mockSession.activate()

        // When
        mockSession.reset()

        // Then
        XCTAssertEqual(mockSession.mockActivationState, .notActivated)
        XCTAssertFalse(mockSession.mockIsReachable)
        XCTAssertEqual(mockSession.sentMessages.count, 0)
        XCTAssertEqual(mockSession.updatedContexts.count, 0)
        XCTAssertFalse(mockSession.activateCalled)
        XCTAssertEqual(mockSession.activateCallCount, 0)
    }
}

// MARK: - MockWCSessionDelegate

/// Mock delegate for testing WCSession delegate callbacks.
private class MockWCSessionDelegate: NSObject, WCSessionDelegate {

    var activationDidCompleteCalled = false
    var lastActivationState: WCSessionActivationState?
    var lastActivationError: Error?

    var reachabilityDidChangeCalled = false
    var didReceiveMessageCalled = false
    var didReceiveMessageWithReplyHandlerCalled = false
    var lastReceivedMessage: [String: Any]?

    var didReceiveApplicationContextCalled = false
    var didReceiveUserInfoCalled = false
    var watchStateDidChangeCalled = false
    var sessionDidBecomeInactiveCalled = false
    var sessionDidDeactivateCalled = false

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        activationDidCompleteCalled = true
        lastActivationState = activationState
        lastActivationError = error
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        reachabilityDidChangeCalled = true
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        didReceiveMessageCalled = true
        lastReceivedMessage = message
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        didReceiveMessageWithReplyHandlerCalled = true
        lastReceivedMessage = message
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        didReceiveApplicationContextCalled = true
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        didReceiveUserInfoCalled = true
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        watchStateDidChangeCalled = true
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        sessionDidBecomeInactiveCalled = true
    }

    func sessionDidDeactivate(_ session: WCSession) {
        sessionDidDeactivateCalled = true
    }
}

// MARK: - MockWCSessionError Tests

final class MockWCSessionErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(MockWCSessionError.notReachable.errorDescription)
        XCTAssertNotNil(MockWCSessionError.notPaired.errorDescription)
        XCTAssertNotNil(MockWCSessionError.appNotInstalled.errorDescription)
        XCTAssertNotNil(MockWCSessionError.sessionNotActivated.errorDescription)
        XCTAssertNotNil(MockWCSessionError.messageSendFailed.errorDescription)
        XCTAssertNotNil(MockWCSessionError.contextUpdateFailed.errorDescription)
        XCTAssertNotNil(MockWCSessionError.fileTransferFailed.errorDescription)
        XCTAssertNotNil(MockWCSessionError.timeout.errorDescription)
        XCTAssertNotNil(MockWCSessionError.custom("Test").errorDescription)
    }

    func testErrorEquality() {
        XCTAssertEqual(MockWCSessionError.notReachable, MockWCSessionError.notReachable)
        XCTAssertNotEqual(MockWCSessionError.notReachable, MockWCSessionError.notPaired)
        XCTAssertEqual(MockWCSessionError.custom("a"), MockWCSessionError.custom("a"))
        XCTAssertNotEqual(MockWCSessionError.custom("a"), MockWCSessionError.custom("b"))
    }
}
