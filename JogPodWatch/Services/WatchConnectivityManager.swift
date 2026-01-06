//
//  WatchConnectivityManager.swift
//  JogPodWatch
//
//  watchOS-side WatchConnectivity manager for communicating with the iOS app.
//  Uses modern Swift concurrency patterns and replaces legacy MMWormhole.
//

import Foundation
import WatchConnectivity
import SwiftUI
import Combine

// MARK: - WatchConnectivityManager

/// Manages WatchConnectivity communication from the watchOS side.
///
/// This class handles all communication with the paired iPhone, including:
/// - Requesting initial data when views appear
/// - Receiving push updates from the iPhone
/// - Sending user actions (workout toggle, playback controls)
/// - Receiving file transfers and user info from iPhone
///
/// ## Architecture
///
/// The manager follows a request-response pattern:
/// 1. Watch sends a request when a view appears
/// 2. iPhone responds with initial data
/// 3. iPhone may push updates as state changes
///
/// ## Counterpart to iOS WatchConnectivityService
///
/// This class is the watchOS counterpart to the iOS `WatchConnectivityService`.
/// It handles all the message types that the iOS app sends:
/// - `workoutStatus` - Workout started/stopped
/// - `podcastUpdate` - Podcast track changed
/// - `playerUpdate` - Play/pause state changed
/// - `workoutUpdate` - Real-time workout metrics
/// - `locationUpdate` - GPS location for map view
/// - `stats` - Workout statistics with route image
///
/// ## Thread Safety
///
/// Uses `@MainActor` to ensure all state updates happen on the main thread.
@MainActor
public final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide use.
    public static let shared = WatchConnectivityManager()

    // MARK: - Constants

    /// Default timeout for requests in seconds.
    public static nonisolated let defaultRequestTimeout: TimeInterval = 10

    /// Maximum retry attempts for failed requests.
    public static nonisolated let maxRetryAttempts = 3

    // MARK: - Published Properties

    /// Current connection state.
    @Published public private(set) var connectionState: ConnectionState = .notActivated

    /// Whether the iPhone is reachable.
    @Published public private(set) var isReachable: Bool = false

    /// Last error that occurred, if any.
    @Published public private(set) var lastError: WatchConnectivityError?

    // MARK: - Combine Publishers

    /// Subject for connection state changes.
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.notActivated)

    /// Subject for reachability changes.
    private let reachabilitySubject = CurrentValueSubject<Bool, Never>(false)

    /// Subject for workout status updates.
    private let workoutStatusSubject = PassthroughSubject<Bool, Never>()

    /// Subject for podcast updates.
    private let podcastUpdateSubject = PassthroughSubject<String, Never>()

    /// Subject for player status updates.
    private let playerUpdateSubject = PassthroughSubject<(isPlaying: Bool, title: String?), Never>()

    /// Subject for location updates.
    private let locationUpdateSubject = PassthroughSubject<WatchLocation, Never>()

    /// Publisher for connection state changes.
    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// Publisher for reachability changes.
    public var reachabilityPublisher: AnyPublisher<Bool, Never> {
        reachabilitySubject.eraseToAnyPublisher()
    }

    /// Publisher for workout status updates.
    public var workoutStatusPublisher: AnyPublisher<Bool, Never> {
        workoutStatusSubject.eraseToAnyPublisher()
    }

    /// Publisher for podcast title updates.
    public var podcastUpdatePublisher: AnyPublisher<String, Never> {
        podcastUpdateSubject.eraseToAnyPublisher()
    }

    /// Publisher for player status updates.
    public var playerUpdatePublisher: AnyPublisher<(isPlaying: Bool, title: String?), Never> {
        playerUpdateSubject.eraseToAnyPublisher()
    }

    /// Publisher for location updates.
    public var locationUpdatePublisher: AnyPublisher<WatchLocation, Never> {
        locationUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    /// The WatchConnectivity session.
    private var session: WCSession?

    /// Reference to the app's state container.
    public weak var watchState: WatchState?

    /// Pending request continuation for async/await support.
    private var pendingRequestContinuation: CheckedContinuation<[String: Any], Error>?

    /// Storage for received files.
    private var receivedFiles: [URL] = []

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }

        setupInternalSubscriptions()
    }

    // MARK: - Internal Setup

    /// Sets up internal Combine subscriptions to sync Published properties with subjects.
    private func setupInternalSubscriptions() {
        connectionStateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        reachabilitySubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reachable in
                self?.isReachable = reachable
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Lifecycle

    /// Activates the WatchConnectivity session.
    ///
    /// Call this method during app launch to establish connection with the iPhone.
    public func activate() {
        guard let session = session else {
            connectionState = .failed("WatchConnectivity not supported")
            return
        }

        connectionState = .activating
        session.activate()
    }

    // MARK: - Sending Requests

    /// Sends a request to the iPhone and awaits a response.
    ///
    /// - Parameters:
    ///   - request: The request type to send.
    ///   - timeout: Optional timeout in seconds. Defaults to `defaultRequestTimeout`.
    /// - Returns: The response dictionary from the iPhone.
    /// - Throws: `WatchConnectivityError` if the request fails.
    public func sendRequest(
        _ request: WatchRequestType,
        timeout: TimeInterval = WatchConnectivityManager.defaultRequestTimeout
    ) async throws -> [String: Any] {
        guard let session = session else {
            throw WatchConnectivityError.notSupported
        }

        guard session.activationState == .activated else {
            throw WatchConnectivityError.sessionNotActivated
        }

        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }

        let message = request.toDictionary()

        return try await withThrowingTaskGroup(of: [String: Any].self) { group in
            // Add the message sending task
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    session.sendMessage(message, replyHandler: { reply in
                        continuation.resume(returning: reply)
                    }, errorHandler: { error in
                        continuation.resume(throwing: WatchConnectivityError.sendFailed(error.localizedDescription))
                    })
                }
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw WatchConnectivityError.timeout
            }

            // Wait for first result
            do {
                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                }
                throw WatchConnectivityError.sendFailed("No response received")
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    /// Sends a request with automatic retry on failure.
    ///
    /// - Parameters:
    ///   - request: The request type to send.
    ///   - retries: Number of retry attempts. Defaults to `maxRetryAttempts`.
    /// - Returns: The response dictionary from the iPhone.
    /// - Throws: `WatchConnectivityError` if all attempts fail.
    public func sendRequestWithRetry(
        _ request: WatchRequestType,
        retries: Int = WatchConnectivityManager.maxRetryAttempts
    ) async throws -> [String: Any] {
        var lastError: Error?

        for attempt in 0..<retries {
            do {
                return try await sendRequest(request)
            } catch {
                lastError = error
                // Wait before retry with exponential backoff
                if attempt < retries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 500_000_000) // 0.5s, 1s, 2s...
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? WatchConnectivityError.sendFailed("All retry attempts failed")
    }

    /// Sends a message without waiting for a reply.
    ///
    /// - Parameter action: The action to send.
    public func sendAction(_ action: WatchAction) {
        guard let session = session,
              session.activationState == .activated,
              session.isReachable else {
            return
        }

        let message = action.toDictionary()
        session.sendMessage(message, replyHandler: nil) { error in
            print("[WatchConnectivity] Action send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Data Request Helpers

    /// Requests dashboard data from the iPhone.
    public func requestDashboardData() async {
        do {
            let response = try await sendRequest(.openDashboard)
            handleDashboardResponse(response)
        } catch {
            watchState?.showError("Failed to connect to iPhone")
        }
    }

    /// Requests metrics data from the iPhone.
    public func requestMetricsData() async {
        do {
            let response = try await sendRequest(.openMetrics)
            handleMetricsResponse(response)
        } catch {
            watchState?.showError("Failed to get metrics")
        }
    }

    /// Requests podcast data from the iPhone.
    public func requestPodcastData() async {
        do {
            let response = try await sendRequest(.openPodcast)
            handlePodcastResponse(response)
        } catch {
            watchState?.showError("Failed to get podcast info")
        }
    }

    /// Notifies the iPhone that the map view opened.
    public func notifyMapOpened() async {
        _ = try? await sendRequest(.openMap)
    }

    /// Notifies the iPhone that the map view closed.
    public func notifyMapClosed() {
        sendAction(.mapClosed)
    }

    /// Requests stats data from the iPhone.
    public func requestStatsData() async {
        _ = try? await sendRequest(.openStats)
    }

    // MARK: - Response Handlers

    private func handleDashboardResponse(_ response: [String: Any]) {
        guard let state = watchState else { return }

        // Check initialization
        if let initialized = response["initialized"] as? Bool, !initialized {
            state.isInitialized = false
            return
        }

        state.isInitialized = true

        let workoutInProgress = (response["workoutInProgress"] as? Int) == 1
        let podcastPlaying = (response["podcastPlaying"] as? Int) == 1
        let podcastTitle = response["podcastTitle"] as? String ?? "No podcast"
        let workoutCount = response["noOfWorkouts"] as? Int ?? 0

        state.updateDashboard(
            workoutInProgress: workoutInProgress,
            podcastPlaying: podcastPlaying,
            podcastTitle: podcastTitle,
            workoutCount: workoutCount,
            isInitialized: true
        )
    }

    private func handleMetricsResponse(_ response: [String: Any]) {
        guard let state = watchState else { return }

        let workoutInProgress = (response["workoutInProgress"] as? Int) == 1
        let publisherCount = response["publisherCount"] as? Int ?? 6

        state.workoutInProgress = workoutInProgress
        state.workoutMetrics.metricCount = publisherCount
    }

    private func handlePodcastResponse(_ response: [String: Any]) {
        guard let state = watchState else { return }

        let currentTitle = response["currentTitle"] as? String ?? "No podcast"
        let isPlaying = (response["isPlaying"] as? Int) == 1

        state.updatePodcast(isPlaying: isPlaying, title: currentTitle)
    }

    // MARK: - Push Message Handlers

    private func handlePushMessage(_ message: [String: Any]) {
        // Determine message type from first key
        guard let key = message.keys.first else { return }

        switch key {
        case "workoutStatus":
            handleWorkoutStatusMessage(message[key])

        case "podcastUpdate":
            handlePodcastUpdateMessage(message[key])

        case "playerUpdate":
            handlePlayerUpdateMessage(message[key])

        case "workoutUpdate":
            handleWorkoutUpdateMessage(message[key])

        case "locationUpdate":
            handleLocationUpdateMessage(message[key])

        case "stats":
            handleStatsMessage(message[key])

        default:
            // Log unknown message type for debugging
            print("[WatchConnectivity] Unknown message type: \(key)")
        }
    }

    private func handleWorkoutStatusMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any],
              let status = data["status"] as? Bool else {
            return
        }

        watchState?.workoutInProgress = status
        workoutStatusSubject.send(status)

        // Update complications
        ComplicationUpdateService.shared.workoutStateChanged(isActive: status)
    }

    private func handlePodcastUpdateMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any] else { return }

        // Handle both "title" (new format) and "currentTitle" (legacy format)
        let title = data["title"] as? String ?? data["currentTitle"] as? String

        if let title = title {
            watchState?.podcastTitle = title
            podcastUpdateSubject.send(title)
        }
    }

    private func handlePlayerUpdateMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any] else { return }

        // Handle both Bool and Int formats for isPlaying
        let isPlaying: Bool
        if let boolValue = data["isPlaying"] as? Bool {
            isPlaying = boolValue
        } else if let intValue = data["isPlaying"] as? Int {
            isPlaying = intValue != 0
        } else if let boolValue = data["playing"] as? Bool {
            // Legacy format
            isPlaying = boolValue
        } else {
            isPlaying = false
        }

        let title = data["podcastTitle"] as? String

        watchState?.updatePodcast(isPlaying: isPlaying, title: title)
        playerUpdateSubject.send((isPlaying: isPlaying, title: title))
    }

    private func handleWorkoutUpdateMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any] else { return }

        var fields: [Int: String] = [:]
        for (k, v) in data {
            if let intKey = Int(k), let strValue = v as? String {
                fields[intKey] = strValue
            }
        }

        watchState?.updateMetrics(from: fields)
    }

    private func handleLocationUpdateMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any],
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double else {
            return
        }

        let accuracy = data["horizontalAccuracy"] as? Double ?? 0
        let speed = data["speed"] as? Double ?? 0
        let course = data["course"] as? Double ?? 0
        let timestamp = (data["timestamp"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()

        let location = WatchLocation(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: accuracy,
            speed: speed,
            course: course,
            timestamp: timestamp
        )

        watchState?.updateLocation(location)
        locationUpdateSubject.send(location)
    }

    private func handleStatsMessage(_ payload: Any?) {
        guard let data = payload as? [String: Any] else { return }

        // Support both legacy string format and modern numeric format
        let distance: String
        let avgSpeed: String
        let calories: String
        let duration: String

        // Legacy format uses capitalized keys with string values
        if let legacyDistance = data["Distance"] as? String {
            distance = legacyDistance
            avgSpeed = data["AvgSpeed"] as? String ?? "N/A"
            calories = data["Calories"] as? String ?? "N/A"
            duration = data["Duration"] as? String ?? "N/A"
        }
        // Modern format uses lowercase keys with numeric values
        else {
            if let distanceKm = data["distanceKm"] as? Double {
                distance = String(format: "%.2f km", distanceKm)
            } else {
                distance = "N/A"
            }

            if let avgPace = data["averagePace"] as? Double {
                let minutes = Int(avgPace)
                let seconds = Int((avgPace - Double(minutes)) * 60)
                avgSpeed = String(format: "%d:%02d min/km", minutes, seconds)
            } else {
                avgSpeed = "N/A"
            }

            if let caloriesInt = data["calories"] as? Int {
                calories = "\(caloriesInt) cal"
            } else {
                calories = "N/A"
            }

            if let durationSeconds = data["durationSeconds"] as? TimeInterval {
                let hours = Int(durationSeconds) / 3600
                let minutes = (Int(durationSeconds) % 3600) / 60
                let seconds = Int(durationSeconds) % 60
                if hours > 0 {
                    duration = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    duration = String(format: "%d:%02d", minutes, seconds)
                }
            } else {
                duration = "N/A"
            }
        }

        let mapImageData = data["mapImage"] as? Data

        let stats = WatchWorkoutStats(
            distance: distance,
            avgSpeed: avgSpeed,
            calories: calories,
            duration: duration,
            mapImageData: mapImageData
        )

        watchState?.updateStats(stats)

        // Update complications with workout summary
        // Parse numeric values for complication display
        let distanceValue = data["distanceKm"] as? Double ?? 0
        let durationValue = data["durationSeconds"] as? TimeInterval ?? 0
        let caloriesValue = data["calories"] as? Int

        // Format pace for complication
        var paceString = "--:--"
        if let avgPace = data["averagePace"] as? Double {
            let minutes = Int(avgPace)
            let seconds = Int((avgPace - Double(minutes)) * 60)
            paceString = String(format: "%d:%02d", minutes, seconds)
        }

        ComplicationUpdateService.shared.workoutCompleted(
            distance: distanceValue,
            averagePace: paceString,
            duration: durationValue,
            calories: caloriesValue
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    // MARK: Session Activation

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.connectionStateSubject.send(.failed(error.localizedDescription))
                self.lastError = .sendFailed(error.localizedDescription)
            } else {
                switch activationState {
                case .activated:
                    self.connectionStateSubject.send(.activated)
                    self.reachabilitySubject.send(session.isReachable)
                    self.watchState?.isConnected = true
                case .inactive, .notActivated:
                    self.connectionStateSubject.send(.notActivated)
                @unknown default:
                    self.connectionStateSubject.send(.failed("Unknown state"))
                }
            }
        }
    }

    // MARK: Reachability

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.reachabilitySubject.send(session.isReachable)
            self.watchState?.isReachable = session.isReachable

            if !session.isReachable {
                self.watchState?.isConnected = false
            } else {
                self.watchState?.isConnected = true
            }
        }
    }

    // MARK: Message Reception

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handlePushMessage(message)
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            // Handle the message
            self.handlePushMessage(message)

            // Send acknowledgment reply
            replyHandler(["status": "received"])
        }
    }

    // MARK: Application Context

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            // Application context is used for persistent state that should
            // be delivered even when the watch app is not running.
            self.handlePushMessage(applicationContext)
        }
    }

    // MARK: User Info Transfer

    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            // User info transfers are queued (FIFO) and delivered in order.
            // Use for data that must be delivered reliably.
            self.handlePushMessage(userInfo)
        }
    }

    // MARK: File Transfer

    nonisolated public func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        Task { @MainActor in
            // Handle received file (e.g., route map image)
            self.handleReceivedFile(file)
        }
    }

    /// Handles a received file transfer from the iPhone.
    private func handleReceivedFile(_ file: WCSessionFile) {
        let fileManager = FileManager.default

        // Move file to a permanent location in the documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[WatchConnectivity] Could not access documents directory")
            return
        }

        let destinationURL = documentsURL.appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Move the received file
            try fileManager.moveItem(at: file.fileURL, to: destinationURL)
            receivedFiles.append(destinationURL)

            // If metadata indicates this is a map image, process it
            if let metadata = file.metadata,
               let isMapImage = metadata["isMapImage"] as? Bool,
               isMapImage {
                handleReceivedMapImage(at: destinationURL)
            }

            print("[WatchConnectivity] File received: \(destinationURL.lastPathComponent)")
        } catch {
            print("[WatchConnectivity] Failed to save received file: \(error.localizedDescription)")
        }
    }

    /// Handles a received map image file.
    private func handleReceivedMapImage(at url: URL) {
        guard let imageData = try? Data(contentsOf: url) else {
            return
        }

        // Update stats with the map image
        if let stats = watchState?.workoutStats {
            let newStats = WatchWorkoutStats(
                distance: stats.distance,
                avgSpeed: stats.avgSpeed,
                calories: stats.calories,
                duration: stats.duration,
                mapImageData: imageData
            )
            watchState?.updateStats(newStats)
        } else {
            // Create new stats with just the map image
            let stats = WatchWorkoutStats(mapImageData: imageData)
            watchState?.updateStats(stats)
        }
    }
}

// MARK: - Connection State

/// Represents the current WatchConnectivity connection state.
public enum ConnectionState: Equatable, Sendable {
    case notActivated
    case activating
    case activated
    case failed(String)

    public var isActive: Bool {
        if case .activated = self {
            return true
        }
        return false
    }
}

// MARK: - Watch Request Type

/// Types of requests the watch can send to the iPhone.
public enum WatchRequestType: Sendable {
    case openDashboard
    case openMetrics
    case openPodcast
    case openMap
    case openStats

    func toDictionary() -> [String: Any] {
        switch self {
        case .openDashboard:
            return ["0": "openDashBoard"]
        case .openMetrics:
            return ["0": "openMetrics"]
        case .openPodcast:
            return ["0": "openPodcast"]
        case .openMap:
            return ["0": "openMap"]
        case .openStats:
            return ["0": "openStats"]
        }
    }
}

// MARK: - Watch Action

/// Actions the watch can send to the iPhone (no reply expected).
public enum WatchAction: Sendable {
    case toggleWorkout(on: Bool)
    case changeMetric(index: Int)
    case playPause
    case fastForward
    case rewind
    case nextTrack
    case mapClosed

    func toDictionary() -> [String: Any] {
        switch self {
        case .toggleWorkout(let on):
            return ["workoutButtonTouched": on ? 1 : 0]
        case .changeMetric(let index):
            return ["metricsButtonTouched": index]
        case .playPause:
            return ["playButtonTouched": "playButtonTouched"]
        case .fastForward:
            return ["fastForwardButtonTouched": "fastForwardButtonTouched"]
        case .rewind:
            return ["rewindButtonTouched": "rewindButtonTouched"]
        case .nextTrack:
            return ["nextButtonTouched": "nextButtonTouched"]
        case .mapClosed:
            return ["mapWillClose": "mapWillClose"]
        }
    }
}

// MARK: - Watch Connectivity Error

/// Errors that can occur during WatchConnectivity operations.
public enum WatchConnectivityError: Error, LocalizedError, Sendable {
    case notSupported
    case sessionNotActivated
    case notReachable
    case sendFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "WatchConnectivity is not supported."
        case .sessionNotActivated:
            return "Session has not been activated."
        case .notReachable:
            return "iPhone is not reachable."
        case .sendFailed(let reason):
            return "Failed to send message: \(reason)"
        case .timeout:
            return "Request timed out."
        }
    }
}
