//
//  WatchMessageHandler.swift
//  JogPod
//
//  Handles incoming watch requests and generates responses.
//  Replaces legacy WatchKitRequestHandler.m.
//

import Foundation
import CoreLocation
import Combine

// MARK: - WatchMessageHandlerProtocol

/// Protocol for the message handler to enable dependency injection.
public protocol WatchMessageHandlerProtocol: WatchConnectivityDelegate {
    /// The workout service for workout state queries.
    var workoutService: WorkoutServiceProtocol? { get set }

    /// The audio player service for podcast state queries.
    var audioPlayerService: AudioPlayerService? { get set }

    /// The persistence manager for workout history queries.
    var persistenceManager: PersistenceManaging? { get set }
}

// MARK: - WatchMessageHandler

/// Handles incoming requests from the Apple Watch and generates responses.
///
/// This class replaces the legacy `WatchKitRequestHandler` from Objective-C,
/// providing the same functionality with modern Swift patterns:
///
/// - Type-safe message handling
/// - Async/await for data fetching
/// - Proper dependency injection
/// - No more MMWormhole dependency
///
/// ## Message Flow
///
/// 1. Watch opens a view (e.g., Dashboard)
/// 2. Watch sends `openDashboard` request via WCSession
/// 3. `WatchConnectivityService` receives and parses the request
/// 4. `WatchMessageHandler.didReceiveRequest` is called
/// 5. Handler queries services for current state
/// 6. Response is returned to the watch
///
/// ## Push Notifications
///
/// The handler also observes app state changes and pushes updates
/// to the watch when relevant. Updates are filtered by the current
/// watch view to avoid unnecessary communication.
///
/// ## Usage
///
/// ```swift
/// let handler = WatchMessageHandler()
/// handler.workoutService = workoutService
/// handler.audioPlayerService = audioPlayerService
/// handler.persistenceManager = persistenceManager
///
/// // Connect to WatchConnectivityService
/// watchConnectivityService.delegate = handler
/// ```
@MainActor
public final class WatchMessageHandler: WatchMessageHandlerProtocol {

    // MARK: - Configuration

    /// Number of workout metric publishers available.
    ///
    /// This corresponds to the number of metric display pages on the watch.
    public static let publisherCount = 4

    // MARK: - Dependencies

    /// The workout service for querying workout state.
    public weak var workoutService: WorkoutServiceProtocol?

    /// The audio player service for querying podcast state.
    public weak var audioPlayerService: AudioPlayerService?

    /// The persistence manager for database queries.
    public weak var persistenceManager: PersistenceManaging?

    /// Route image generator for stats view.
    public var routeImageGenerator: RouteImageGenerating?

    // MARK: - State

    /// Whether the app has been initialized (disclaimer accepted).
    ///
    /// If false, watch views will receive a "not initialized" response.
    public var isAppInitialized: Bool = true

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {}

    /// Creates a handler with all dependencies.
    ///
    /// - Parameters:
    ///   - workoutService: Service for workout state.
    ///   - audioPlayerService: Service for audio playback state.
    ///   - persistenceManager: Manager for database queries.
    public init(
        workoutService: WorkoutServiceProtocol?,
        audioPlayerService: AudioPlayerService?,
        persistenceManager: PersistenceManaging?
    ) {
        self.workoutService = workoutService
        self.audioPlayerService = audioPlayerService
        self.persistenceManager = persistenceManager
    }

    // MARK: - WatchConnectivityDelegate

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didReceiveRequest request: WatchRequest
    ) async -> WatchResponse {
        // Check initialization first
        guard isAppInitialized else {
            return .notInitialized
        }

        switch request {
        case .openDashboard:
            return await handleOpenDashboard()

        case .openMetrics:
            return await handleOpenMetrics()

        case .openPodcast:
            return await handleOpenPodcast()

        case .openMap:
            return await handleOpenMap(service: service)

        case .openStats:
            return await handleOpenStats(service: service)

        case .acknowledge:
            // Acknowledgment received, no response needed
            return .dashboard(DashboardData(
                workoutInProgress: false,
                podcastPlaying: false,
                podcastTitle: "",
                workoutCount: 0
            ))
        }
    }

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeWatchView view: WatchView
    ) {
        // View changed, could trigger additional setup if needed
    }

    public func watchConnectivityService(
        _ service: WatchConnectivityService,
        didChangeReachability isReachable: Bool
    ) {
        // Handle reachability change if needed
    }

    // MARK: - Request Handlers

    /// Handles the dashboard open request.
    ///
    /// Returns current workout status, podcast status, and workout count.
    private func handleOpenDashboard() async -> WatchResponse {
        // Get workout status
        let workoutInProgress: Bool
        if let service = workoutService {
            workoutInProgress = await service.isWorkoutInProgress
        } else {
            workoutInProgress = false
        }

        // Get podcast status
        let podcastPlaying = audioPlayerService?.isPlaying ?? false
        let podcastTitle = audioPlayerService?.currentItem?.title ?? ""

        // Get workout count
        let workoutCount: Int
        if let persistence = persistenceManager {
            workoutCount = await (try? persistence.fetchWorkoutSessionCount()) ?? 0
        } else {
            workoutCount = 0
        }

        let data = DashboardData(
            workoutInProgress: workoutInProgress,
            podcastPlaying: podcastPlaying,
            podcastTitle: podcastTitle,
            workoutCount: workoutCount,
            isInitialized: true
        )

        return .dashboard(data)
    }

    /// Handles the metrics view open request.
    ///
    /// Returns workout status and publisher count.
    private func handleOpenMetrics() async -> WatchResponse {
        let workoutInProgress: Bool
        if let service = workoutService {
            workoutInProgress = await service.isWorkoutInProgress
        } else {
            workoutInProgress = false
        }

        let data = MetricsData(
            workoutInProgress: workoutInProgress,
            publisherCount: Self.publisherCount
        )

        return .metrics(data)
    }

    /// Handles the podcast view open request.
    ///
    /// Returns current episode title and playing status.
    private func handleOpenPodcast() async -> WatchResponse {
        let currentTitle = audioPlayerService?.currentItem?.title ?? ""
        let isPlaying = audioPlayerService?.isPlaying ?? false

        let data = PodcastData(
            currentTitle: currentTitle,
            isPlaying: isPlaying
        )

        return .podcast(data)
    }

    /// Handles the map view open request.
    ///
    /// Starts location monitoring and returns acknowledgment.
    /// Actual location updates are sent via push notifications.
    private func handleOpenMap(service: WatchConnectivityService) async -> WatchResponse {
        // Location updates will be sent via notification forwarding
        // which is set up in WatchConnectivityService.setupNotificationForwarding()

        return .map
    }

    /// Handles the stats view open request.
    ///
    /// Triggers route image generation and sends stats via push.
    private func handleOpenStats(service: WatchConnectivityService) async -> WatchResponse {
        // Generate route image asynchronously
        Task {
            await generateAndSendStats(to: service)
        }

        return .stats
    }

    /// Generates workout statistics and sends them to the watch.
    private func generateAndSendStats(to service: WatchConnectivityService) async {
        // Get current workout metrics
        var distanceKm: Double = 0
        var durationSeconds: TimeInterval = 0
        var averagePace: Double = 0
        var calories: Int = 0

        if let workoutService = workoutService,
           let snapshot = await workoutService.currentMetrics() {
            distanceKm = snapshot.distanceInKilometers
            durationSeconds = snapshot.duration
            averagePace = snapshot.pacePerKilometer ?? 0
            calories = snapshot.caloriesBurned
        }

        // Generate route image
        var mapImageData: Data?
        if let generator = routeImageGenerator {
            mapImageData = await generator.generateRouteImage()
        }

        let statsData = StatsData(
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            averagePace: averagePace,
            calories: calories,
            mapImageData: mapImageData
        )

        // Send stats to watch
        try? await service.sendMessage(.stats(statsData))
    }
}

// MARK: - RouteImageGenerating Protocol

/// Protocol for generating route images.
///
/// Implement this protocol to provide route visualization for the stats view.
public protocol RouteImageGenerating: Sendable {
    /// Generates a PNG image of the current workout route.
    ///
    /// - Returns: PNG image data, or nil if generation fails.
    func generateRouteImage() async -> Data?
}

// MARK: - Mock Route Image Generator

/// Mock implementation for testing.
public final class MockRouteImageGenerator: RouteImageGenerating, Sendable {

    private let mockData: Data?

    public init(mockData: Data? = nil) {
        self.mockData = mockData
    }

    public func generateRouteImage() async -> Data? {
        mockData
    }
}

// MARK: - WorkoutMetricsFormatter

/// Formats workout metrics for display on the watch.
///
/// This replaces the legacy WorkoutMetricsPublisher formatting logic.
public struct WorkoutMetricsFormatter: Sendable {

    /// Metric field tags matching the watch UI labels.
    public enum FieldTag: Int, Sendable {
        case distance = 1
        case duration = 2
        case pace = 3
        case speed = 4
        case calories = 5
        case heartRate = 6
        case podcastTitle = 7
    }

    /// Formats a workout snapshot into field values for the watch.
    ///
    /// - Parameters:
    ///   - snapshot: The current workout metrics.
    ///   - podcastTitle: Optional current podcast title.
    /// - Returns: Dictionary mapping field tags to formatted strings.
    public static func format(
        snapshot: WorkoutSnapshot,
        podcastTitle: String? = nil
    ) -> [Int: String] {
        var fields: [Int: String] = [:]

        // Distance (km with 2 decimal places)
        fields[FieldTag.distance.rawValue] = String(format: "%.2f km", snapshot.distanceInKilometers)

        // Duration (formatted as HH:MM:SS)
        fields[FieldTag.duration.rawValue] = snapshot.formattedDuration

        // Pace (min/km)
        fields[FieldTag.pace.rawValue] = formatPace(snapshot.pacePerKilometer ?? 0)

        // Speed (km/h with 1 decimal)
        fields[FieldTag.speed.rawValue] = String(format: "%.1f km/h", snapshot.currentSpeedKmh)

        // Calories
        fields[FieldTag.calories.rawValue] = "\(snapshot.caloriesBurned) kcal"

        // Heart rate
        if snapshot.currentHeartRate > 0 {
            fields[FieldTag.heartRate.rawValue] = "\(snapshot.currentHeartRate) bpm"
        }

        // Podcast title
        if let title = podcastTitle {
            fields[FieldTag.podcastTitle.rawValue] = title
        }

        return fields
    }

    /// Formats pace as MM:SS per km.
    private static func formatPace(_ minutesPerKm: Double) -> String {
        guard minutesPerKm.isFinite && minutesPerKm > 0 else {
            return "--:--"
        }

        let totalSeconds = Int(minutesPerKm * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - Convenience Extension for WorkoutUpdateData

public extension WatchPushMessage {

    /// Creates a workout update message from a snapshot.
    ///
    /// - Parameters:
    ///   - snapshot: The current workout metrics.
    ///   - podcastTitle: Optional current podcast title.
    /// - Returns: A workout update push message.
    static func workoutUpdate(
        from snapshot: WorkoutSnapshot,
        podcastTitle: String? = nil
    ) -> WatchPushMessage {
        let fields = WorkoutMetricsFormatter.format(
            snapshot: snapshot,
            podcastTitle: podcastTitle
        )

        let data = WorkoutUpdateData(
            fields: fields,
            podcastTitle: podcastTitle
        )

        return .workoutUpdate(data)
    }
}

// MARK: - Extend PersistenceManaging for Workout Count

public extension PersistenceManaging {

    /// Fetches the count of workout sessions.
    ///
    /// Default implementation that can be overridden.
    func fetchWorkoutSessionCount() async throws -> Int {
        // This should be implemented in PersistenceManager
        // For now, return a placeholder
        return 0
    }
}
