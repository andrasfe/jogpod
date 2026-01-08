//
//  WatchConnectivityService.swift
//  JogPod
//
//  Modern WatchConnectivity service using Swift concurrency.
//  Replaces legacy WatchSessionManager and removes MMWormhole dependency.
//

import Foundation
import WatchConnectivity
import Combine
import UIKit

// MARK: - WatchConnectivityServiceProtocol

/// Protocol defining the WatchConnectivity service interface.
///
/// This protocol enables dependency injection and testing of watch
/// connectivity without requiring a physical watch.
public protocol WatchConnectivityServiceProtocol: AnyObject, Sendable {

    /// Whether WatchConnectivity is supported on this device.
    var isSupported: Bool { get }

    /// Whether the session is currently activated.
    var isActivated: Bool { get async }

    /// Whether the watch is reachable for live messaging.
    var isReachable: Bool { get async }

    /// Whether a watch is paired and has the app installed.
    var isWatchAvailable: Bool { get async }

    /// The currently active view on the watch.
    var currentWatchView: WatchView { get async }

    /// Activates the WatchConnectivity session.
    func activate() async throws

    /// Sends a message to the watch and waits for a reply.
    func sendMessage(_ message: WatchPushMessage) async throws

    /// Sends a message without waiting for a reply.
    func sendMessageWithoutReply(_ message: WatchPushMessage) async throws

    /// Updates the application context (persisted data).
    func updateApplicationContext(_ context: [String: Any]) async throws

    /// Transfers a file to the watch.
    func transferFile(_ fileURL: URL, metadata: [String: Any]?) async throws

    /// Publisher for session state changes.
    var sessionStatePublisher: AnyPublisher<WatchSessionState, Never> { get }

    /// Publisher for reachability changes.
    var reachabilityPublisher: AnyPublisher<Bool, Never> { get }
}

// MARK: - WatchSessionState

/// Represents the current state of the WatchConnectivity session.
public enum WatchSessionState: Sendable, Equatable {
    /// Session not yet activated.
    case notActivated

    /// Session is activating.
    case activating

    /// Session is active and ready.
    case activated

    /// Session activation failed.
    case failed(String)

    /// Watch is not paired.
    case notPaired

    /// Watch app is not installed.
    case appNotInstalled
}

// MARK: - WatchConnectivityDelegate

/// Delegate protocol for receiving watch messages.
///
/// Implement this protocol to handle incoming requests from the watch
/// and provide responses.
@MainActor
public protocol WatchConnectivityDelegate: AnyObject {

    /// Called when a request is received from the watch.
    ///
    /// - Parameters:
    ///   - service: The connectivity service.
    ///   - request: The parsed request.
    /// - Returns: The response to send back to the watch.
    func watchConnectivityService(
        _ service: WatchConnectivityService,
        didReceiveRequest request: WatchRequest
    ) async -> WatchResponse

    /// Called when the watch view changes.
    ///
    /// - Parameters:
    ///   - service: The connectivity service.
    ///   - view: The new active view on the watch.
    func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeWatchView view: WatchView
    )

    /// Called when reachability changes.
    ///
    /// - Parameters:
    ///   - service: The connectivity service.
    ///   - isReachable: Whether the watch is now reachable.
    func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeReachability isReachable: Bool
    )
}

// MARK: - Default Delegate Implementation

public extension WatchConnectivityDelegate {
    func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeWatchView view: WatchView
    ) {}

    func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeReachability isReachable: Bool
    ) {}
}

// MARK: - WatchConnectivityService

/// Modern WatchConnectivity service using Swift concurrency.
///
/// This service replaces the legacy `WatchSessionManager` and completely
/// removes the MMWormhole dependency. It provides:
///
/// - Type-safe message sending and receiving
/// - Swift async/await APIs
/// - Combine publishers for reactive UI updates
/// - Proper session lifecycle management
/// - View-based message filtering
///
/// ## Architecture
///
/// The service acts as a bridge between the iOS app and watchOS app.
/// It handles:
///
/// 1. **Incoming requests**: Watch opens a view -> requests data -> gets response
/// 2. **Push notifications**: App state changes -> filtered message sent to watch
///
/// ## Message Filtering
///
/// Push messages are only sent if the watch is displaying a relevant view.
/// This prevents unnecessary communication and battery drain.
///
/// ## Usage
///
/// ```swift
/// let service = WatchConnectivityService()
/// service.delegate = myHandler
///
/// // Activate on app launch
/// try await service.activate()
///
/// // Send updates when state changes
/// try await service.sendMessage(.workoutStatus(isActive: true))
/// ```
///
/// ## Thread Safety
///
/// The service uses `@MainActor` for UI-related callbacks and internal
/// synchronization for state management.
@MainActor
public final class WatchConnectivityService: NSObject, WatchConnectivityServiceProtocol {

    // MARK: - Constants

    /// Default message timeout in seconds.
    public static let defaultMessageTimeout: TimeInterval = 10

    /// Maximum retry attempts for failed messages.
    public static let maxRetryAttempts = 3

    // MARK: - Properties

    /// Delegate for handling incoming messages.
    public weak var delegate: WatchConnectivityDelegate?

    /// The underlying WCSession.
    private var session: WCSession?

    /// Current session state.
    private var _sessionState: WatchSessionState = .notActivated

    /// Current view on the watch.
    private var _currentWatchView: WatchView = .none

    /// Session state subject for Combine publisher.
    private let sessionStateSubject = CurrentValueSubject<WatchSessionState, Never>(.notActivated)

    /// Reachability subject for Combine publisher.
    private let reachabilitySubject = CurrentValueSubject<Bool, Never>(false)

    /// Pending reply handlers keyed by message ID.
    private var pendingReplies: [UUID: CheckedContinuation<[String: Any], Error>] = [:]

    /// Background task identifier for long operations.
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - WatchConnectivityServiceProtocol

    public nonisolated var isSupported: Bool {
        WCSession.isSupported()
    }

    public var isActivated: Bool {
        session?.activationState == .activated
    }

    public var isReachable: Bool {
        guard let session = session else { return false }
        return session.isReachable
    }

    public var isWatchAvailable: Bool {
        guard let session = session else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    public var currentWatchView: WatchView {
        _currentWatchView
    }

    public var sessionStatePublisher: AnyPublisher<WatchSessionState, Never> {
        sessionStateSubject.eraseToAnyPublisher()
    }

    public var reachabilityPublisher: AnyPublisher<Bool, Never> {
        reachabilitySubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
        }
    }

    /// Creates a service with a mock session for testing.
    ///
    /// - Parameter mockSession: A mock WCSession for testing.
    internal init(mockSession: WCSession?) {
        super.init()
        self.session = mockSession
    }

    // MARK: - Session Lifecycle

    /// Activates the WatchConnectivity session.
    ///
    /// Call this method during app launch to establish the connection
    /// with the paired Apple Watch.
    ///
    /// - Throws: `WatchConnectivityError` if activation fails.
    public func activate() async throws {
        guard isSupported else {
            throw WatchConnectivityError.notSupported
        }

        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        // Set delegate before activation
        session.delegate = self
        _sessionState = .activating
        sessionStateSubject.send(.activating)

        // Activate session
        session.activate()

        // Wait for activation to complete
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                // Create a timeout task
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    if self._sessionState == .activating {
                        self._sessionState = .failed("Activation timeout")
                        self.sessionStateSubject.send(.failed("Activation timeout"))
                        continuation.resume(throwing: WatchConnectivityError.activationFailed(reason: "Timeout"))
                    }
                }

                // Store continuation to be resumed by delegate callback
                self.activationContinuation = continuation
                self.activationTimeoutTask = timeoutTask
            }
        }
    }

    /// Continuation for activation completion.
    private var activationContinuation: CheckedContinuation<Void, Error>?

    /// Timeout task for activation.
    private var activationTimeoutTask: Task<Void, Error>?

    // MARK: - Message Sending

    /// Sends a push message to the watch.
    ///
    /// The message is only sent if:
    /// 1. The session is activated
    /// 2. The watch is reachable
    /// 3. The current watch view matches the message's target views
    ///
    /// - Parameter message: The message to send.
    /// - Throws: `WatchConnectivityError` if sending fails.
    public func sendMessage(_ message: WatchPushMessage) async throws {
        // Check if we should send based on current view
        guard message.targetViews.contains(_currentWatchView) else {
            // Silently skip - watch is on a different view
            return
        }

        try await sendMessageInternal(message.toDictionary())
    }

    /// Sends a push message without waiting for a reply.
    ///
    /// Use this for fire-and-forget updates where confirmation is not needed.
    ///
    /// - Parameter message: The message to send.
    /// - Throws: `WatchConnectivityError` if sending fails.
    public func sendMessageWithoutReply(_ message: WatchPushMessage) async throws {
        guard message.targetViews.contains(_currentWatchView) else {
            return
        }

        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard session.isReachable else {
            throw WatchConnectivityError.watchNotReachable
        }

        // Send without reply handler
        session.sendMessage(message.toDictionary(), replyHandler: nil) { error in
            // Log error but don't throw - this is fire-and-forget
            print("[WatchConnectivity] Send failed: \(error.localizedDescription)")
        }
    }

    /// Internal message sending with reply handling.
    private func sendMessageInternal(_ messageDict: [String: Any]) async throws {
        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard session.isReachable else {
            throw WatchConnectivityError.watchNotReachable
        }

        // Begin background task for reliability
        beginBackgroundTask()

        defer {
            endBackgroundTask()
        }

        // Send message with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    session.sendMessage(
                        messageDict,
                        replyHandler: { _ in
                            continuation.resume()
                        },
                        errorHandler: { error in
                            continuation.resume(throwing: WatchConnectivityError.messageSendFailed(reason: error.localizedDescription))
                        }
                    )
                }
            }

            // Add timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(Self.defaultMessageTimeout * 1_000_000_000))
                throw WatchConnectivityError.replyTimeout
            }

            // Wait for first completion
            do {
                try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    /// Updates the application context.
    ///
    /// Application context is persisted and delivered when the watch
    /// app becomes active, even if it wasn't reachable when sent.
    ///
    /// - Parameter context: The context dictionary to send.
    /// - Throws: `WatchConnectivityError` if update fails.
    public func updateApplicationContext(_ context: [String: Any]) async throws {
        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        try session.updateApplicationContext(context)
    }

    /// Transfers a file to the watch.
    ///
    /// Use this for large data like route images that shouldn't be
    /// sent via interactive messaging.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the file to transfer.
    ///   - metadata: Optional metadata dictionary.
    /// - Throws: `WatchConnectivityError` if transfer fails.
    public func transferFile(_ fileURL: URL, metadata: [String: Any]? = nil) async throws {
        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        #if os(iOS)
        guard session.isPaired else {
            throw WatchConnectivityError.watchNotPaired
        }

        guard session.isWatchAppInstalled else {
            throw WatchConnectivityError.watchAppNotInstalled
        }
        #endif

        session.transferFile(fileURL, metadata: metadata)
    }

    /// Transfers user info to the watch (FIFO queue).
    ///
    /// User info transfers are queued and delivered in order, even
    /// when the watch is not reachable.
    ///
    /// - Parameter userInfo: The user info dictionary to transfer.
    /// - Returns: The transfer object for monitoring.
    @discardableResult
    public func transferUserInfo(_ userInfo: [String: Any]) async throws -> WCSessionUserInfoTransfer? {
        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        return session.transferUserInfo(userInfo)
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        guard backgroundTaskID == UIBackgroundTaskIdentifier.invalid else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WatchConnectivity") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != UIBackgroundTaskIdentifier.invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = UIBackgroundTaskIdentifier.invalid
    }

    // MARK: - View State Management

    /// Updates the current watch view.
    ///
    /// Called internally when a request is received, indicating which
    /// view the watch is displaying.
    private func setCurrentWatchView(_ view: WatchView) {
        guard _currentWatchView != view else { return }

        _currentWatchView = view
        delegate?.watchConnectivityService(self, didChangeWatchView: view)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    // MARK: Activation

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            // Cancel timeout
            self.activationTimeoutTask?.cancel()
            self.activationTimeoutTask = nil

            if let error = error {
                self._sessionState = .failed(error.localizedDescription)
                self.sessionStateSubject.send(.failed(error.localizedDescription))
                self.activationContinuation?.resume(throwing: WatchConnectivityError.activationFailed(reason: error.localizedDescription))
            } else {
                switch activationState {
                case .activated:
                    self._sessionState = .activated
                    self.sessionStateSubject.send(.activated)
                    self.activationContinuation?.resume()

                case .inactive, .notActivated:
                    self._sessionState = .notActivated
                    self.sessionStateSubject.send(.notActivated)
                    self.activationContinuation?.resume(throwing: WatchConnectivityError.activationFailed(reason: "Session not activated"))

                @unknown default:
                    self._sessionState = .failed("Unknown activation state")
                    self.sessionStateSubject.send(.failed("Unknown activation state"))
                    self.activationContinuation?.resume(throwing: WatchConnectivityError.activationFailed(reason: "Unknown state"))
                }
            }

            self.activationContinuation = nil
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self._sessionState = .notActivated
            self.sessionStateSubject.send(.notActivated)
        }
    }

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self._sessionState = .notActivated
            self.sessionStateSubject.send(.notActivated)

            // Reactivate session
            session.activate()
        }
    }

    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            if !session.isPaired {
                self._sessionState = .notPaired
                self.sessionStateSubject.send(.notPaired)
            } else if !session.isWatchAppInstalled {
                self._sessionState = .appNotInstalled
                self.sessionStateSubject.send(.appNotInstalled)
            } else if session.activationState == .activated {
                self._sessionState = .activated
                self.sessionStateSubject.send(.activated)
            }
        }
    }
    #endif

    // MARK: Reachability

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.reachabilitySubject.send(session.isReachable)
            self.delegate?.watchConnectivityService(self, didChangeReachability: session.isReachable)

            if !session.isReachable {
                // Reset view when watch becomes unreachable
                self.setCurrentWatchView(.none)
            }
        }
    }

    // MARK: Message Reception

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            await self.handleIncomingMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            await self.handleIncomingMessage(message, replyHandler: nil)
        }
    }

    /// Handles incoming messages from the watch.
    private func handleIncomingMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) async {
        guard let request = WatchRequest.from(message) else {
            // Unknown message format
            replyHandler?(["error": "Unknown message format"])
            return
        }

        // Update current view
        setCurrentWatchView(request.associatedView)

        // Get response from delegate
        guard let delegate = delegate else {
            replyHandler?(["error": "No handler configured"])
            return
        }

        let response = await delegate.watchConnectivityService(self, didReceiveRequest: request)
        replyHandler?(response.toDictionary())
    }

    // MARK: Application Context

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            // Handle application context if needed
            // Currently not used in the legacy implementation
        }
    }

    // MARK: User Info Transfer

    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            // Handle user info if needed
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        if let error = error {
            print("[WatchConnectivity] User info transfer failed: \(error.localizedDescription)")
        }
    }

    // MARK: File Transfer

    nonisolated public func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        Task { @MainActor in
            // Handle received file if needed
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        if let error = error {
            print("[WatchConnectivity] File transfer failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Integration

public extension WatchConnectivityService {

    /// Sets up automatic notification forwarding to the watch.
    ///
    /// Call this method after activation to automatically forward
    /// relevant notifications to the watch.
    func setupNotificationForwarding() {
        // Workout status changes
        NotificationCenter.default.addObserver(
            forName: .workoutStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let isActive = notification.userInfo?["status"] as? Bool {
                Task {
                    try? await self.sendMessage(.workoutStatus(isActive: isActive))
                }
            }
        }

        // Player status changes
        NotificationCenter.default.addObserver(
            forName: .playerStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            let isPlaying = notification.userInfo?["playing"] as? Bool ?? false
            let title = notification.userInfo?["podcastTitle"] as? String

            Task {
                try? await self.sendMessage(.playerUpdate(isPlaying: isPlaying, podcastTitle: title))
            }
        }

        // Podcast item changes
        NotificationCenter.default.addObserver(
            forName: .podcastItemChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let item = notification.userInfo?["item"] as? PlayableItem,
               let title = item.title {
                Task {
                    try? await self.sendMessage(.podcastUpdate(title: title))
                }
            }
        }

        // Location updates
        NotificationCenter.default.addObserver(
            forName: .locationUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let location = notification.userInfo?["currentLocation"] as? CLLocation {
                let data = LocationUpdateData(location: location)
                Task {
                    try? await self.sendMessage(.locationUpdate(data))
                }
            }
        }
    }

    /// Removes notification observers.
    func removeNotificationForwarding() {
        NotificationCenter.default.removeObserver(self, name: .workoutStatusChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .playerStatusChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .podcastItemChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .locationUpdate, object: nil)
    }
}

// MARK: - CLLocation Import for LocationUpdateData

import CoreLocation
