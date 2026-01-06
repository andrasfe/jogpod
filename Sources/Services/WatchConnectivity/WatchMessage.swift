//
//  WatchMessage.swift
//  JogPod
//
//  Type-safe message definitions for WatchConnectivity communication.
//

import Foundation
import CoreLocation

// MARK: - Watch View Identifier

/// Identifies the currently active view on the Apple Watch.
///
/// Used to filter push notifications - messages are only sent
/// if the watch is displaying a relevant view.
public enum WatchView: String, Codable, Sendable {
    /// No view active (watch app not in foreground).
    case none

    /// Dashboard showing workout and podcast status.
    case dashboard

    /// Workout metrics display.
    case metrics

    /// Podcast playback controls.
    case podcast

    /// Map view showing current location.
    case map

    /// Workout statistics and route image.
    case stats
}

// MARK: - Watch Request

/// Requests sent from the Apple Watch to the iPhone.
///
/// These correspond to view lifecycle events on the watch,
/// requesting initial data when a view appears.
public enum WatchRequest: Sendable {
    /// Watch requests dashboard data (workout status, podcast status).
    case openDashboard

    /// Watch requests workout metrics data.
    case openMetrics

    /// Watch requests podcast player data.
    case openPodcast

    /// Watch requests map/location data.
    case openMap

    /// Watch requests workout statistics.
    case openStats

    /// Watch acknowledges a push notification.
    case acknowledge(messageType: String)

    // MARK: - Serialization Keys

    private enum Keys {
        static let openDashboard = "openDashBoard"
        static let openMetrics = "openMetrics"
        static let openPodcast = "openPodcast"
        static let openMap = "openMap"
        static let openStats = "openStats"
        static let acknowledge = "acknowledge"
    }

    /// Creates a WatchRequest from a raw message dictionary.
    ///
    /// - Parameter message: The raw dictionary from WCSession.
    /// - Returns: The parsed request, or nil if the message is not recognized.
    public static func from(_ message: [String: Any]) -> WatchRequest? {
        guard let key = message.keys.first else { return nil }

        switch key {
        case Keys.openDashboard:
            return .openDashboard
        case Keys.openMetrics:
            return .openMetrics
        case Keys.openPodcast:
            return .openPodcast
        case Keys.openMap:
            return .openMap
        case Keys.openStats:
            return .openStats
        case Keys.acknowledge:
            if let messageType = message[key] as? String {
                return .acknowledge(messageType: messageType)
            }
            return nil
        default:
            return nil
        }
    }

    /// The view that should be marked as current when this request is received.
    public var associatedView: WatchView {
        switch self {
        case .openDashboard:
            return .dashboard
        case .openMetrics:
            return .metrics
        case .openPodcast:
            return .podcast
        case .openMap:
            return .map
        case .openStats:
            return .stats
        case .acknowledge:
            return .none
        }
    }
}

// MARK: - Watch Response

/// Responses sent from the iPhone to the Apple Watch.
///
/// These provide initial data when the watch opens a view.
public enum WatchResponse: Sendable {
    /// Dashboard data with workout and podcast status.
    case dashboard(DashboardData)

    /// Metrics view data.
    case metrics(MetricsData)

    /// Podcast player data.
    case podcast(PodcastData)

    /// Map data acknowledgment (actual location sent via push).
    case map

    /// Stats data acknowledgment (actual stats sent via push).
    case stats

    /// Error response when initialization required.
    case notInitialized

    /// Converts the response to a dictionary for WCSession.
    public func toDictionary() -> [String: Any] {
        switch self {
        case .dashboard(let data):
            return data.toDictionary()

        case .metrics(let data):
            return data.toDictionary()

        case .podcast(let data):
            return data.toDictionary()

        case .map:
            return ["status": "ok"]

        case .stats:
            return ["status": "ok"]

        case .notInitialized:
            return ["initialized": false]
        }
    }
}

// MARK: - Dashboard Data

/// Data for the watch dashboard view.
public struct DashboardData: Sendable {
    /// Whether a workout is currently in progress.
    public let workoutInProgress: Bool

    /// Whether a podcast is currently playing.
    public let podcastPlaying: Bool

    /// Title of the current podcast episode.
    public let podcastTitle: String

    /// Number of saved workouts.
    public let workoutCount: Int

    /// Whether the app is initialized (disclaimer accepted).
    public let isInitialized: Bool

    public init(
        workoutInProgress: Bool,
        podcastPlaying: Bool,
        podcastTitle: String,
        workoutCount: Int,
        isInitialized: Bool = true
    ) {
        self.workoutInProgress = workoutInProgress
        self.podcastPlaying = podcastPlaying
        self.podcastTitle = podcastTitle
        self.workoutCount = workoutCount
        self.isInitialized = isInitialized
    }

    func toDictionary() -> [String: Any] {
        [
            "workoutInProgress": workoutInProgress ? 1 : 0,
            "podcastPlaying": podcastPlaying ? 1 : 0,
            "podcastTitle": podcastTitle,
            "noOfWorkouts": workoutCount,
            "initialized": isInitialized
        ]
    }
}

// MARK: - Metrics Data

/// Data for the workout metrics view.
public struct MetricsData: Sendable {
    /// Whether a workout is currently in progress.
    public let workoutInProgress: Bool

    /// Number of available metric publishers (display pages).
    public let publisherCount: Int

    public init(workoutInProgress: Bool, publisherCount: Int) {
        self.workoutInProgress = workoutInProgress
        self.publisherCount = publisherCount
    }

    func toDictionary() -> [String: Any] {
        [
            "workoutInProgress": workoutInProgress ? 1 : 0,
            "publisherCount": publisherCount
        ]
    }
}

// MARK: - Podcast Data

/// Data for the podcast player view.
public struct PodcastData: Sendable {
    /// Title of the current episode.
    public let currentTitle: String

    /// Whether the podcast is currently playing.
    public let isPlaying: Bool

    public init(currentTitle: String, isPlaying: Bool) {
        self.currentTitle = currentTitle
        self.isPlaying = isPlaying
    }

    func toDictionary() -> [String: Any] {
        [
            "currentTitle": currentTitle,
            "isPlaying": isPlaying ? 1 : 0
        ]
    }
}

// MARK: - Watch Push Message

/// Push messages sent from the iPhone to the Apple Watch.
///
/// These are unsolicited updates pushed when state changes on the phone.
public enum WatchPushMessage: Sendable {
    /// Workout status changed (started/stopped).
    case workoutStatus(isActive: Bool)

    /// Podcast track changed.
    case podcastUpdate(title: String)

    /// Player status changed (play/pause).
    case playerUpdate(isPlaying: Bool, podcastTitle: String?)

    /// Workout metrics update.
    case workoutUpdate(WorkoutUpdateData)

    /// Location update for map view.
    case locationUpdate(LocationUpdateData)

    /// Stats data with route image.
    case stats(StatsData)

    // MARK: - Message Keys

    private enum Keys {
        static let workoutStatus = "workoutStatus"
        static let podcastUpdate = "podcastUpdate"
        static let playerUpdate = "playerUpdate"
        static let workoutUpdate = "workoutUpdate"
        static let locationUpdate = "locationUpdate"
        static let stats = "stats"
    }

    /// The views that should receive this message.
    ///
    /// Messages are only sent if the watch is displaying one of these views.
    public var targetViews: Set<WatchView> {
        switch self {
        case .workoutStatus:
            return [.dashboard, .metrics]
        case .podcastUpdate:
            return [.dashboard, .podcast]
        case .playerUpdate:
            return [.dashboard, .podcast]
        case .workoutUpdate:
            return [.dashboard, .metrics]
        case .locationUpdate:
            return [.map]
        case .stats:
            return [.stats]
        }
    }

    /// Converts the message to a dictionary for WCSession.
    public func toDictionary() -> [String: Any] {
        switch self {
        case .workoutStatus(let isActive):
            return [Keys.workoutStatus: ["status": isActive]]

        case .podcastUpdate(let title):
            return [Keys.podcastUpdate: ["title": title]]

        case .playerUpdate(let isPlaying, let podcastTitle):
            var data: [String: Any] = ["isPlaying": isPlaying]
            if let title = podcastTitle {
                data["podcastTitle"] = title
            }
            return [Keys.playerUpdate: data]

        case .workoutUpdate(let data):
            return [Keys.workoutUpdate: data.toDictionary()]

        case .locationUpdate(let data):
            return [Keys.locationUpdate: data.toDictionary()]

        case .stats(let data):
            return [Keys.stats: data.toDictionary()]
        }
    }
}

// MARK: - Workout Update Data

/// Real-time workout metrics update.
public struct WorkoutUpdateData: Sendable {
    /// Formatted metric fields by tag number.
    ///
    /// Tags correspond to UI labels on the watch:
    /// - 1: Distance
    /// - 2: Duration
    /// - 3: Pace
    /// - 4: Speed
    /// - 5: Calories
    /// - 6: Heart rate
    /// - 7: Podcast title
    public let fields: [Int: String]

    /// Current podcast title (optional).
    public let podcastTitle: String?

    public init(fields: [Int: String], podcastTitle: String? = nil) {
        self.fields = fields
        self.podcastTitle = podcastTitle
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for (tag, value) in fields {
            dict[String(tag)] = value
        }
        if let title = podcastTitle {
            dict["7"] = title
        }
        return dict
    }
}

// MARK: - Location Update Data

/// Location data for the map view.
public struct LocationUpdateData: Sendable {
    /// Latitude in degrees.
    public let latitude: Double

    /// Longitude in degrees.
    public let longitude: Double

    /// Horizontal accuracy in meters.
    public let horizontalAccuracy: Double

    /// Speed in meters per second.
    public let speed: Double

    /// Course/heading in degrees.
    public let course: Double

    /// Timestamp of the location reading.
    public let timestamp: Date

    public init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = location.speed
        self.course = location.course
        self.timestamp = location.timestamp
    }

    public init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double = 0,
        speed: Double = 0,
        course: Double = 0,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }

    func toDictionary() -> [String: Any] {
        [
            "latitude": latitude,
            "longitude": longitude,
            "horizontalAccuracy": horizontalAccuracy,
            "speed": speed,
            "course": course,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

// MARK: - Stats Data

/// Workout statistics and route image.
public struct StatsData: Sendable {
    /// Total distance in kilometers.
    public let distanceKm: Double

    /// Total duration in seconds.
    public let durationSeconds: TimeInterval

    /// Average pace (minutes per km).
    public let averagePace: Double

    /// Calories burned.
    public let calories: Int

    /// Route map image as PNG data.
    public let mapImageData: Data?

    public init(
        distanceKm: Double,
        durationSeconds: TimeInterval,
        averagePace: Double,
        calories: Int,
        mapImageData: Data? = nil
    ) {
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.averagePace = averagePace
        self.calories = calories
        self.mapImageData = mapImageData
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "distanceKm": distanceKm,
            "durationSeconds": durationSeconds,
            "averagePace": averagePace,
            "calories": calories
        ]
        if let imageData = mapImageData {
            dict["mapImage"] = imageData
        }
        return dict
    }
}

// MARK: - WatchConnectivityError

/// Errors that can occur during WatchConnectivity operations.
public enum WatchConnectivityError: Error, LocalizedError, Equatable, Sendable {
    /// WatchConnectivity is not supported on this device.
    case notSupported

    /// The WCSession has not been activated.
    case sessionNotActivated

    /// The watch app is not installed.
    case watchAppNotInstalled

    /// The watch is not paired.
    case watchNotPaired

    /// The watch is not reachable for live messaging.
    case watchNotReachable

    /// Message send failed.
    case messageSendFailed(reason: String)

    /// Reply timeout expired.
    case replyTimeout

    /// Invalid message format.
    case invalidMessageFormat

    /// Session activation failed.
    case activationFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "WatchConnectivity is not supported on this device."
        case .sessionNotActivated:
            return "The watch session has not been activated."
        case .watchAppNotInstalled:
            return "The watch app is not installed."
        case .watchNotPaired:
            return "No Apple Watch is paired with this device."
        case .watchNotReachable:
            return "The Apple Watch is not reachable."
        case .messageSendFailed(let reason):
            return "Failed to send message: \(reason)"
        case .replyTimeout:
            return "Watch did not respond within the timeout period."
        case .invalidMessageFormat:
            return "The message format is invalid."
        case .activationFailed(let reason):
            return "Session activation failed: \(reason)"
        }
    }
}
