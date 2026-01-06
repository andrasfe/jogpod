//
//  MockWatchConnectivityService.swift
//  JogPodTests
//
//  Mock implementation of WatchConnectivityService for testing
//  without requiring actual WatchConnectivity infrastructure.
//
//  Created for JogPod Revival project.
//

import Foundation
import Combine
import CoreLocation
@testable import JogPod

// MARK: - MockWatchConnectivityService

/// A mock implementation of WatchConnectivityServiceProtocol for testing.
///
/// This mock provides full control over WatchConnectivity behavior without
/// requiring actual WatchConnectivity framework or physical Apple Watch.
///
/// ## Features
///
/// - Configurable session state and reachability
/// - Message sending/receiving simulation
/// - Application context tracking
/// - File transfer tracking
/// - Delegate callback simulation
/// - Full publisher support
///
/// ## Usage
///
/// ```swift
/// let mockService = MockWatchConnectivityService()
/// mockService.mockIsSupported = true
/// mockService.mockIsReachable = true
/// mockService.mockCurrentWatchView = .dashboard
///
/// // Test message sending
/// try await mockService.sendMessage(.workoutStatus(isActive: true))
/// XCTAssertEqual(mockService.sentMessages.count, 1)
///
/// // Simulate incoming message
/// let response = await mockService.simulateIncomingRequest(.openDashboard)
/// ```
@MainActor
public final class MockWatchConnectivityService: WatchConnectivityServiceProtocol {

    // MARK: - Protocol Properties

    /// Whether WatchConnectivity is supported.
    public nonisolated var isSupported: Bool {
        _mockIsSupported
    }

    /// Whether the session is activated.
    public var isActivated: Bool {
        _mockIsActivated
    }

    /// Whether the watch is reachable.
    public var isReachable: Bool {
        _mockIsReachable
    }

    /// Whether a watch is paired and has the app installed.
    public var isWatchAvailable: Bool {
        _mockIsPaired && _mockIsWatchAppInstalled
    }

    /// The current view on the watch.
    public var currentWatchView: WatchView {
        _mockCurrentWatchView
    }

    /// Publisher for session state changes.
    public var sessionStatePublisher: AnyPublisher<WatchSessionState, Never> {
        sessionStateSubject.eraseToAnyPublisher()
    }

    /// Publisher for reachability changes.
    public var reachabilityPublisher: AnyPublisher<Bool, Never> {
        reachabilitySubject.eraseToAnyPublisher()
    }

    // MARK: - Mock Configuration

    /// Whether WatchConnectivity is supported (mock).
    private var _mockIsSupported: Bool = true
    public var mockIsSupported: Bool {
        get { _mockIsSupported }
        set { _mockIsSupported = newValue }
    }

    /// Whether the session is activated (mock).
    private var _mockIsActivated: Bool = false
    public var mockIsActivated: Bool {
        get { _mockIsActivated }
        set { _mockIsActivated = newValue }
    }

    /// Whether the watch is reachable (mock).
    private var _mockIsReachable: Bool = false
    public var mockIsReachable: Bool {
        get { _mockIsReachable }
        set {
            _mockIsReachable = newValue
            reachabilitySubject.send(newValue)
        }
    }

    /// Whether a watch is paired (mock).
    private var _mockIsPaired: Bool = true
    public var mockIsPaired: Bool {
        get { _mockIsPaired }
        set { _mockIsPaired = newValue }
    }

    /// Whether the watch app is installed (mock).
    private var _mockIsWatchAppInstalled: Bool = true
    public var mockIsWatchAppInstalled: Bool {
        get { _mockIsWatchAppInstalled }
        set { _mockIsWatchAppInstalled = newValue }
    }

    /// The current watch view (mock).
    private var _mockCurrentWatchView: WatchView = .none
    public var mockCurrentWatchView: WatchView {
        get { _mockCurrentWatchView }
        set { _mockCurrentWatchView = newValue }
    }

    /// The current session state (mock).
    private var _mockSessionState: WatchSessionState = .notActivated
    public var mockSessionState: WatchSessionState {
        get { _mockSessionState }
        set {
            _mockSessionState = newValue
            sessionStateSubject.send(newValue)
        }
    }

    // MARK: - Error Simulation

    /// Error to throw on activation.
    public var activationError: WatchConnectivityError?

    /// Error to throw on message send.
    public var sendMessageError: WatchConnectivityError?

    /// Error to throw on context update.
    public var updateContextError: WatchConnectivityError?

    /// Error to throw on file transfer.
    public var transferFileError: WatchConnectivityError?

    // MARK: - Tracking Properties

    /// Sent messages for verification.
    public private(set) var sentMessages: [WatchPushMessage] = []

    /// Sent messages without reply for verification.
    public private(set) var sentMessagesWithoutReply: [WatchPushMessage] = []

    /// Updated application contexts for verification.
    public private(set) var updatedContexts: [[String: Any]] = []

    /// Transferred files for verification.
    public private(set) var transferredFiles: [TransferredFileRecord] = []

    /// Whether activate was called.
    public private(set) var activateCalled: Bool = false

    /// Number of times activate was called.
    public private(set) var activateCallCount: Int = 0

    // MARK: - Delegate

    /// The delegate for handling messages.
    public weak var delegate: WatchConnectivityDelegate?

    // MARK: - Publishers

    private let sessionStateSubject = CurrentValueSubject<WatchSessionState, Never>(.notActivated)
    private let reachabilitySubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - Types

    /// Record of a transferred file.
    public struct TransferredFileRecord: Equatable {
        public let fileURL: URL
        public let metadata: [String: Any]?
        public let timestamp: Date

        public static func == (lhs: TransferredFileRecord, rhs: TransferredFileRecord) -> Bool {
            lhs.fileURL == rhs.fileURL && lhs.timestamp == rhs.timestamp
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - WatchConnectivityServiceProtocol Methods

    /// Activates the session.
    public func activate() async throws {
        activateCalled = true
        activateCallCount += 1

        guard _mockIsSupported else {
            throw WatchConnectivityError.notSupported
        }

        if let error = activationError {
            mockSessionState = .failed(error.localizedDescription ?? "Activation failed")
            throw error
        }

        _mockIsActivated = true
        mockSessionState = .activated
    }

    /// Sends a message to the watch.
    public func sendMessage(_ message: WatchPushMessage) async throws {
        guard _mockIsSupported else {
            throw WatchConnectivityError.notSupported
        }

        guard _mockIsActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard _mockIsReachable else {
            throw WatchConnectivityError.watchNotReachable
        }

        // Check view-based filtering
        guard message.targetViews.contains(_mockCurrentWatchView) else {
            // Silently skip - watch is on different view
            return
        }

        if let error = sendMessageError {
            throw error
        }

        sentMessages.append(message)
    }

    /// Sends a message without waiting for a reply.
    public func sendMessageWithoutReply(_ message: WatchPushMessage) async throws {
        guard _mockIsSupported else {
            throw WatchConnectivityError.notSupported
        }

        guard _mockIsActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard _mockIsReachable else {
            throw WatchConnectivityError.watchNotReachable
        }

        // Check view-based filtering
        guard message.targetViews.contains(_mockCurrentWatchView) else {
            return
        }

        if let error = sendMessageError {
            throw error
        }

        sentMessagesWithoutReply.append(message)
    }

    /// Updates the application context.
    public func updateApplicationContext(_ context: [String: Any]) async throws {
        guard _mockIsSupported else {
            throw WatchConnectivityError.notSupported
        }

        guard _mockIsActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        if let error = updateContextError {
            throw error
        }

        updatedContexts.append(context)
    }

    /// Transfers a file to the watch.
    public func transferFile(_ fileURL: URL, metadata: [String: Any]?) async throws {
        guard _mockIsSupported else {
            throw WatchConnectivityError.notSupported
        }

        guard _mockIsActivated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard _mockIsPaired else {
            throw WatchConnectivityError.watchNotPaired
        }

        guard _mockIsWatchAppInstalled else {
            throw WatchConnectivityError.watchAppNotInstalled
        }

        if let error = transferFileError {
            throw error
        }

        let record = TransferredFileRecord(
            fileURL: fileURL,
            metadata: metadata,
            timestamp: Date()
        )
        transferredFiles.append(record)
    }

    // MARK: - Simulation Methods

    /// Simulates receiving a request from the watch.
    ///
    /// - Parameter request: The request to simulate.
    /// - Returns: The response from the delegate, if any.
    public func simulateIncomingRequest(_ request: WatchRequest) async -> WatchResponse? {
        // Update current view based on request
        _mockCurrentWatchView = request.associatedView

        guard let delegate = delegate else {
            return nil
        }

        // Create a mock service to pass to delegate
        // (delegate expects WatchConnectivityService, not protocol)
        // For testing we can use self since we're testing the handler
        return nil // Would need casting to work with real delegate
    }

    /// Simulates reachability changing.
    ///
    /// - Parameter reachable: The new reachability state.
    public func simulateReachabilityChange(_ reachable: Bool) {
        _mockIsReachable = reachable
        reachabilitySubject.send(reachable)

        if !reachable {
            _mockCurrentWatchView = .none
        }
    }

    /// Simulates session state changing.
    ///
    /// - Parameter state: The new session state.
    public func simulateSessionStateChange(_ state: WatchSessionState) {
        _mockSessionState = state
        sessionStateSubject.send(state)

        switch state {
        case .activated:
            _mockIsActivated = true
        case .notActivated, .notPaired, .appNotInstalled, .activating, .failed:
            _mockIsActivated = false
        }
    }

    /// Simulates watch view changing.
    ///
    /// - Parameter view: The new watch view.
    public func simulateWatchViewChange(_ view: WatchView) {
        _mockCurrentWatchView = view
    }

    /// Simulates watch pairing state changing.
    ///
    /// - Parameters:
    ///   - isPaired: Whether watch is paired.
    ///   - isAppInstalled: Whether app is installed.
    public func simulateWatchStateChange(
        isPaired: Bool? = nil,
        isAppInstalled: Bool? = nil
    ) {
        if let paired = isPaired {
            _mockIsPaired = paired
            if !paired {
                mockSessionState = .notPaired
            }
        }
        if let installed = isAppInstalled {
            _mockIsWatchAppInstalled = installed
            if !installed {
                mockSessionState = .appNotInstalled
            }
        }
    }

    // MARK: - Test Helpers

    /// Resets all mock state and tracking data.
    public func reset() {
        _mockIsSupported = true
        _mockIsActivated = false
        _mockIsReachable = false
        _mockIsPaired = true
        _mockIsWatchAppInstalled = true
        _mockCurrentWatchView = .none
        _mockSessionState = .notActivated

        activationError = nil
        sendMessageError = nil
        updateContextError = nil
        transferFileError = nil

        sentMessages = []
        sentMessagesWithoutReply = []
        updatedContexts = []
        transferredFiles = []
        activateCalled = false
        activateCallCount = 0

        sessionStateSubject.send(.notActivated)
        reachabilitySubject.send(false)
    }

    /// Returns the count of sent messages (both types).
    public var totalSentMessageCount: Int {
        sentMessages.count + sentMessagesWithoutReply.count
    }

    /// Returns the last sent message.
    public var lastSentMessage: WatchPushMessage? {
        sentMessages.last ?? sentMessagesWithoutReply.last
    }

    /// Checks if a specific message type was sent.
    ///
    /// - Parameter messageType: The message type to check for.
    /// - Returns: True if such a message was sent.
    public func wasMessageSent(_ messageType: MessageType) -> Bool {
        let allMessages = sentMessages + sentMessagesWithoutReply

        return allMessages.contains { message in
            switch (message, messageType) {
            case (.workoutStatus, .workoutStatus):
                return true
            case (.podcastUpdate, .podcastUpdate):
                return true
            case (.playerUpdate, .playerUpdate):
                return true
            case (.workoutUpdate, .workoutUpdate):
                return true
            case (.locationUpdate, .locationUpdate):
                return true
            case (.stats, .stats):
                return true
            default:
                return false
            }
        }
    }

    /// Message types for easier verification.
    public enum MessageType {
        case workoutStatus
        case podcastUpdate
        case playerUpdate
        case workoutUpdate
        case locationUpdate
        case stats
    }

    /// Returns all messages of a specific type.
    public func messages(ofType type: MessageType) -> [WatchPushMessage] {
        let allMessages = sentMessages + sentMessagesWithoutReply

        return allMessages.filter { message in
            switch (message, type) {
            case (.workoutStatus, .workoutStatus):
                return true
            case (.podcastUpdate, .podcastUpdate):
                return true
            case (.playerUpdate, .playerUpdate):
                return true
            case (.workoutUpdate, .workoutUpdate):
                return true
            case (.locationUpdate, .locationUpdate):
                return true
            case (.stats, .stats):
                return true
            default:
                return false
            }
        }
    }

    /// Sets up the mock for a successful sending scenario.
    public func setupForSuccessfulSending() {
        _mockIsSupported = true
        _mockIsActivated = true
        _mockIsReachable = true
        _mockIsPaired = true
        _mockIsWatchAppInstalled = true
        mockSessionState = .activated
    }
}
