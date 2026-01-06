//
//  MockWCSession.swift
//  JogPodTests
//
//  Mock implementation of WCSession for testing WatchConnectivity
//  without requiring a physical Apple Watch.
//
//  Created for JogPod Revival project.
//

import Foundation
import WatchConnectivity
@testable import JogPod

// MARK: - MockWCSession

/// A mock implementation of WCSession for testing WatchConnectivity.
///
/// This mock allows tests to simulate various WatchConnectivity scenarios including:
/// - Session activation states
/// - Watch pairing and app installation status
/// - Reachability changes
/// - Message sending and receiving
/// - Application context updates
/// - File transfers
///
/// ## Usage
///
/// ```swift
/// let mockSession = MockWCSession()
/// mockSession.mockIsReachable = true
/// mockSession.mockIsPaired = true
///
/// // Simulate activation
/// mockSession.simulateActivation(state: .activated)
///
/// // Verify sent messages
/// XCTAssertEqual(mockSession.sentMessages.count, 1)
/// ```
@MainActor
public final class MockWCSession: @unchecked Sendable {

    // MARK: - Configuration Properties

    /// Whether WCSession is supported (simulated).
    public var mockIsSupported: Bool = true

    /// The current activation state.
    public var mockActivationState: WCSessionActivationState = .notActivated

    /// Whether the watch is paired.
    public var mockIsPaired: Bool = true

    /// Whether the watch app is installed.
    public var mockIsWatchAppInstalled: Bool = true

    /// Whether the watch is reachable.
    public var mockIsReachable: Bool = false

    /// Whether complication is enabled (iOS only).
    public var mockIsComplicationEnabled: Bool = false

    /// The received application context.
    public var mockReceivedApplicationContext: [String: Any] = [:]

    /// The current application context.
    public var mockApplicationContext: [String: Any] = [:]

    /// The watch directory URL.
    public var mockWatchDirectoryURL: URL?

    /// Remaining complication user info transfers.
    public var mockRemainingComplicationUserInfoTransfers: Int = 10

    // MARK: - Delegate

    /// The session delegate.
    public weak var delegate: WCSessionDelegate?

    // MARK: - Tracking Properties

    /// Sent messages for verification.
    public private(set) var sentMessages: [SentMessage] = []

    /// Sent user info transfers for verification.
    public private(set) var sentUserInfo: [[String: Any]] = []

    /// Transferred files for verification.
    public private(set) var transferredFiles: [TransferredFile] = []

    /// Updated application contexts for verification.
    public private(set) var updatedContexts: [[String: Any]] = []

    /// Whether activate was called.
    public private(set) var activateCalled: Bool = false

    /// Number of times activate was called.
    public private(set) var activateCallCount: Int = 0

    // MARK: - Simulated Errors

    /// Error to throw when sending messages.
    public var sendMessageError: Error?

    /// Error to throw when updating application context.
    public var updateContextError: Error?

    /// Error to throw when transferring files.
    public var transferFileError: Error?

    /// Error to return on activation.
    public var activationError: Error?

    // MARK: - Response Simulation

    /// Reply to return for sent messages.
    public var mockMessageReply: [String: Any]?

    /// Delay before delivering message reply (in seconds).
    public var messageReplyDelay: TimeInterval = 0

    // MARK: - Types

    /// Represents a sent message for tracking.
    public struct SentMessage: Equatable {
        public let message: [String: Any]
        public let hasReplyHandler: Bool
        public let timestamp: Date

        public init(
            message: [String: Any],
            hasReplyHandler: Bool,
            timestamp: Date = Date()
        ) {
            self.message = message
            self.hasReplyHandler = hasReplyHandler
            self.timestamp = timestamp
        }

        public static func == (lhs: SentMessage, rhs: SentMessage) -> Bool {
            lhs.hasReplyHandler == rhs.hasReplyHandler &&
            lhs.timestamp == rhs.timestamp &&
            NSDictionary(dictionary: lhs.message).isEqual(to: rhs.message)
        }
    }

    /// Represents a transferred file for tracking.
    public struct TransferredFile: Equatable {
        public let fileURL: URL
        public let metadata: [String: Any]?
        public let timestamp: Date

        public init(
            fileURL: URL,
            metadata: [String: Any]?,
            timestamp: Date = Date()
        ) {
            self.fileURL = fileURL
            self.metadata = metadata
            self.timestamp = timestamp
        }

        public static func == (lhs: TransferredFile, rhs: TransferredFile) -> Bool {
            lhs.fileURL == rhs.fileURL && lhs.timestamp == rhs.timestamp
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - WCSession-like Interface

    /// The activation state.
    public var activationState: WCSessionActivationState {
        mockActivationState
    }

    /// Whether the watch is reachable.
    public var isReachable: Bool {
        mockIsReachable
    }

    /// Whether the watch is paired (iOS only).
    public var isPaired: Bool {
        mockIsPaired
    }

    /// Whether the watch app is installed (iOS only).
    public var isWatchAppInstalled: Bool {
        mockIsWatchAppInstalled
    }

    /// Whether complication is enabled (iOS only).
    public var isComplicationEnabled: Bool {
        mockIsComplicationEnabled
    }

    /// The received application context.
    public var receivedApplicationContext: [String: Any] {
        mockReceivedApplicationContext
    }

    /// The current application context.
    public var applicationContext: [String: Any] {
        mockApplicationContext
    }

    /// The watch directory URL.
    public var watchDirectoryURL: URL? {
        mockWatchDirectoryURL
    }

    /// Remaining complication user info transfers.
    public var remainingComplicationUserInfoTransfers: Int {
        mockRemainingComplicationUserInfoTransfers
    }

    // MARK: - Activation

    /// Simulates activating the session.
    public func activate() {
        activateCalled = true
        activateCallCount += 1

        // Don't immediately call delegate - let test control timing
    }

    /// Simulates the activation completing.
    ///
    /// - Parameters:
    ///   - state: The resulting activation state.
    ///   - error: Optional error if activation failed.
    public func simulateActivation(
        state: WCSessionActivationState,
        error: Error? = nil
    ) {
        mockActivationState = state

        delegate?.session(
            WCSession.default,  // We pass the real session since delegate expects it
            activationDidCompleteWith: state,
            error: error ?? activationError
        )
    }

    // MARK: - Message Sending

    /// Simulates sending a message.
    ///
    /// - Parameters:
    ///   - message: The message dictionary.
    ///   - replyHandler: Optional handler for the reply.
    ///   - errorHandler: Optional handler for errors.
    public func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        let sentMessage = SentMessage(
            message: message,
            hasReplyHandler: replyHandler != nil
        )
        sentMessages.append(sentMessage)

        // Simulate error if configured
        if let error = sendMessageError {
            DispatchQueue.main.async {
                errorHandler?(error)
            }
            return
        }

        // Simulate reply if configured
        if let reply = mockMessageReply, let handler = replyHandler {
            if messageReplyDelay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + messageReplyDelay) {
                    handler(reply)
                }
            } else {
                DispatchQueue.main.async {
                    handler(reply)
                }
            }
        }
    }

    // MARK: - Application Context

    /// Updates the application context.
    ///
    /// - Parameter context: The context dictionary.
    /// - Throws: `updateContextError` if set.
    public func updateApplicationContext(_ context: [String: Any]) throws {
        if let error = updateContextError {
            throw error
        }

        updatedContexts.append(context)
        mockApplicationContext = context
    }

    // MARK: - User Info Transfer

    /// Transfers user info to the watch.
    ///
    /// - Parameter userInfo: The user info dictionary.
    /// - Returns: A mock transfer object (currently returns nil).
    @discardableResult
    public func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer? {
        sentUserInfo.append(userInfo)
        return nil
    }

    /// Transfers complication user info.
    ///
    /// - Parameter userInfo: The user info dictionary.
    /// - Returns: A mock transfer object (currently returns nil).
    @discardableResult
    public func transferCurrentComplicationUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer? {
        sentUserInfo.append(userInfo)
        return nil
    }

    // MARK: - File Transfer

    /// Transfers a file to the watch.
    ///
    /// - Parameters:
    ///   - fileURL: The file URL.
    ///   - metadata: Optional metadata.
    /// - Returns: A mock transfer object (currently returns nil).
    @discardableResult
    public func transferFile(_ fileURL: URL, metadata: [String: Any]?) -> WCSessionFileTransfer? {
        let transfer = TransferredFile(
            fileURL: fileURL,
            metadata: metadata
        )
        transferredFiles.append(transfer)
        return nil
    }

    // MARK: - Simulation Methods

    /// Simulates the watch becoming reachable or unreachable.
    ///
    /// - Parameter reachable: The new reachability state.
    public func simulateReachabilityChange(reachable: Bool) {
        mockIsReachable = reachable
        delegate?.sessionReachabilityDidChange(WCSession.default)
    }

    /// Simulates receiving a message from the watch.
    ///
    /// - Parameters:
    ///   - message: The received message.
    ///   - replyHandler: Optional reply handler.
    public func simulateReceivedMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        if let handler = replyHandler {
            delegate?.session?(
                WCSession.default,
                didReceiveMessage: message,
                replyHandler: handler
            )
        } else {
            delegate?.session?(WCSession.default, didReceiveMessage: message)
        }
    }

    /// Simulates receiving application context from the watch.
    ///
    /// - Parameter context: The received context.
    public func simulateReceivedApplicationContext(_ context: [String: Any]) {
        mockReceivedApplicationContext = context
        delegate?.session?(WCSession.default, didReceiveApplicationContext: context)
    }

    /// Simulates receiving user info from the watch.
    ///
    /// - Parameter userInfo: The received user info.
    public func simulateReceivedUserInfo(_ userInfo: [String: Any]) {
        delegate?.session?(WCSession.default, didReceiveUserInfo: userInfo)
    }

    /// Simulates session becoming inactive (iOS only).
    public func simulateSessionBecameInactive() {
        mockActivationState = .inactive
        delegate?.sessionDidBecomeInactive?(WCSession.default)
    }

    /// Simulates session deactivation (iOS only).
    public func simulateSessionDeactivation() {
        mockActivationState = .notActivated
        delegate?.sessionDidDeactivate?(WCSession.default)
    }

    /// Simulates watch state change (pairing, app installation).
    ///
    /// - Parameters:
    ///   - isPaired: Whether watch is paired.
    ///   - isAppInstalled: Whether watch app is installed.
    public func simulateWatchStateChange(
        isPaired: Bool? = nil,
        isAppInstalled: Bool? = nil
    ) {
        if let paired = isPaired {
            mockIsPaired = paired
        }
        if let installed = isAppInstalled {
            mockIsWatchAppInstalled = installed
        }
        delegate?.sessionWatchStateDidChange?(WCSession.default)
    }

    // MARK: - Test Helpers

    /// Resets all tracking data and mock state.
    public func reset() {
        mockActivationState = .notActivated
        mockIsPaired = true
        mockIsWatchAppInstalled = true
        mockIsReachable = false
        mockIsComplicationEnabled = false
        mockReceivedApplicationContext = [:]
        mockApplicationContext = [:]

        sentMessages = []
        sentUserInfo = []
        transferredFiles = []
        updatedContexts = []
        activateCalled = false
        activateCallCount = 0

        sendMessageError = nil
        updateContextError = nil
        transferFileError = nil
        activationError = nil
        mockMessageReply = nil
        messageReplyDelay = 0
    }

    /// Returns the last sent message.
    public var lastSentMessage: SentMessage? {
        sentMessages.last
    }

    /// Returns the last message dictionary.
    public var lastMessageDict: [String: Any]? {
        sentMessages.last?.message
    }

    /// Returns the count of sent messages.
    public var sentMessageCount: Int {
        sentMessages.count
    }

    /// Checks if a specific message key was sent.
    ///
    /// - Parameter key: The message key to check.
    /// - Returns: True if a message with that key was sent.
    public func wasMessageSent(withKey key: String) -> Bool {
        sentMessages.contains { $0.message.keys.contains(key) }
    }

    /// Returns all messages sent with a specific key.
    ///
    /// - Parameter key: The message key to filter by.
    /// - Returns: Array of matching sent messages.
    public func messages(withKey key: String) -> [SentMessage] {
        sentMessages.filter { $0.message.keys.contains(key) }
    }
}

// MARK: - WCSessionActivationState Convenience

extension WCSessionActivationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notActivated:
            return "notActivated"
        case .inactive:
            return "inactive"
        case .activated:
            return "activated"
        @unknown default:
            return "unknown"
        }
    }
}

// MARK: - MockWCSessionError

/// Errors for MockWCSession testing scenarios.
public enum MockWCSessionError: Error, LocalizedError, Equatable {
    case notReachable
    case notPaired
    case appNotInstalled
    case sessionNotActivated
    case messageSendFailed
    case contextUpdateFailed
    case fileTransferFailed
    case timeout
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .notReachable:
            return "Watch is not reachable"
        case .notPaired:
            return "No watch is paired"
        case .appNotInstalled:
            return "Watch app is not installed"
        case .sessionNotActivated:
            return "Session is not activated"
        case .messageSendFailed:
            return "Failed to send message"
        case .contextUpdateFailed:
            return "Failed to update application context"
        case .fileTransferFailed:
            return "Failed to transfer file"
        case .timeout:
            return "Operation timed out"
        case .custom(let message):
            return message
        }
    }
}
