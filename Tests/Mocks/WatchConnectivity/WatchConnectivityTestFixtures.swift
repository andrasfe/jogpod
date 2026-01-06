//
//  WatchConnectivityTestFixtures.swift
//  JogPodTests
//
//  Test fixtures and factory methods for WatchConnectivity testing.
//
//  Created for JogPod Revival project.
//

import Foundation
import CoreLocation
@testable import JogPod

// MARK: - WatchConnectivityTestFixtures

/// Factory for creating test fixtures for WatchConnectivity testing.
///
/// Provides pre-configured data objects and message fixtures for comprehensive
/// testing of WatchConnectivity scenarios.
public enum WatchConnectivityTestFixtures {

    // MARK: - Dashboard Data

    /// Creates a sample DashboardData for testing.
    public static func makeDashboardData(
        workoutInProgress: Bool = false,
        podcastPlaying: Bool = false,
        podcastTitle: String = "Test Podcast Episode",
        workoutCount: Int = 5,
        isInitialized: Bool = true
    ) -> DashboardData {
        DashboardData(
            workoutInProgress: workoutInProgress,
            podcastPlaying: podcastPlaying,
            podcastTitle: podcastTitle,
            workoutCount: workoutCount,
            isInitialized: isInitialized
        )
    }

    /// Dashboard data with active workout.
    public static var dashboardWithActiveWorkout: DashboardData {
        makeDashboardData(
            workoutInProgress: true,
            podcastPlaying: true,
            podcastTitle: "Running Playlist Episode",
            workoutCount: 25
        )
    }

    /// Dashboard data when idle.
    public static var dashboardIdle: DashboardData {
        makeDashboardData(
            workoutInProgress: false,
            podcastPlaying: false,
            podcastTitle: "",
            workoutCount: 10
        )
    }

    /// Dashboard data when not initialized.
    public static var dashboardNotInitialized: DashboardData {
        makeDashboardData(isInitialized: false)
    }

    // MARK: - Metrics Data

    /// Creates sample MetricsData for testing.
    public static func makeMetricsData(
        workoutInProgress: Bool = true,
        publisherCount: Int = 4
    ) -> MetricsData {
        MetricsData(
            workoutInProgress: workoutInProgress,
            publisherCount: publisherCount
        )
    }

    /// Metrics data with active workout.
    public static var metricsActive: MetricsData {
        makeMetricsData(workoutInProgress: true)
    }

    /// Metrics data when idle.
    public static var metricsIdle: MetricsData {
        makeMetricsData(workoutInProgress: false)
    }

    // MARK: - Podcast Data

    /// Creates sample PodcastData for testing.
    public static func makePodcastData(
        currentTitle: String = "Test Episode",
        isPlaying: Bool = false
    ) -> PodcastData {
        PodcastData(
            currentTitle: currentTitle,
            isPlaying: isPlaying
        )
    }

    /// Podcast data when playing.
    public static var podcastPlaying: PodcastData {
        makePodcastData(
            currentTitle: "Running Mix Episode 42",
            isPlaying: true
        )
    }

    /// Podcast data when paused.
    public static var podcastPaused: PodcastData {
        makePodcastData(
            currentTitle: "Running Mix Episode 42",
            isPlaying: false
        )
    }

    /// Podcast data with no current episode.
    public static var podcastEmpty: PodcastData {
        makePodcastData(
            currentTitle: "",
            isPlaying: false
        )
    }

    // MARK: - Stats Data

    /// Creates sample StatsData for testing.
    public static func makeStatsData(
        distanceKm: Double = 5.5,
        durationSeconds: TimeInterval = 1800,
        averagePace: Double = 5.45,
        calories: Int = 350,
        mapImageData: Data? = nil
    ) -> StatsData {
        StatsData(
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            averagePace: averagePace,
            calories: calories,
            mapImageData: mapImageData
        )
    }

    /// Stats data for a 5K run.
    public static var stats5K: StatsData {
        makeStatsData(
            distanceKm: 5.0,
            durationSeconds: 1500,  // 25 minutes
            averagePace: 5.0,
            calories: 320
        )
    }

    /// Stats data for a 10K run.
    public static var stats10K: StatsData {
        makeStatsData(
            distanceKm: 10.0,
            durationSeconds: 3600,  // 60 minutes
            averagePace: 6.0,
            calories: 680
        )
    }

    /// Stats data with map image.
    public static var statsWithMap: StatsData {
        // PNG header bytes for a minimal valid PNG
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52
        ])
        return makeStatsData(mapImageData: pngData)
    }

    // MARK: - Location Update Data

    /// Creates sample LocationUpdateData for testing.
    public static func makeLocationUpdateData(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194,
        horizontalAccuracy: Double = 5.0,
        speed: Double = 3.5,
        course: Double = 90.0,
        timestamp: Date = Date()
    ) -> LocationUpdateData {
        LocationUpdateData(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            speed: speed,
            course: course,
            timestamp: timestamp
        )
    }

    /// Location data for San Francisco.
    public static var locationSanFrancisco: LocationUpdateData {
        makeLocationUpdateData(
            latitude: 37.7749,
            longitude: -122.4194
        )
    }

    /// Location data for New York.
    public static var locationNewYork: LocationUpdateData {
        makeLocationUpdateData(
            latitude: 40.7128,
            longitude: -74.0060
        )
    }

    /// Location data from a CLLocation.
    public static func makeLocationFromCLLocation(_ location: CLLocation) -> LocationUpdateData {
        LocationUpdateData(location: location)
    }

    // MARK: - Workout Update Data

    /// Creates sample WorkoutUpdateData for testing.
    public static func makeWorkoutUpdateData(
        distance: String = "5.50 km",
        duration: String = "30:00",
        pace: String = "5:27 /km",
        speed: String = "11.0 km/h",
        calories: String = "350 kcal",
        heartRate: String? = "145 bpm",
        podcastTitle: String? = "Running Mix"
    ) -> WorkoutUpdateData {
        var fields: [Int: String] = [
            1: distance,
            2: duration,
            3: pace,
            4: speed,
            5: calories
        ]

        if let hr = heartRate {
            fields[6] = hr
        }

        return WorkoutUpdateData(fields: fields, podcastTitle: podcastTitle)
    }

    /// Workout update with all fields.
    public static var workoutUpdateComplete: WorkoutUpdateData {
        makeWorkoutUpdateData(
            heartRate: "145 bpm",
            podcastTitle: "Marathon Training Episode"
        )
    }

    /// Workout update without heart rate.
    public static var workoutUpdateNoHeartRate: WorkoutUpdateData {
        makeWorkoutUpdateData(heartRate: nil)
    }

    // MARK: - Push Messages

    /// Creates a workout status message.
    public static func workoutStatusMessage(isActive: Bool) -> WatchPushMessage {
        .workoutStatus(isActive: isActive)
    }

    /// Creates a podcast update message.
    public static func podcastUpdateMessage(title: String) -> WatchPushMessage {
        .podcastUpdate(title: title)
    }

    /// Creates a player update message.
    public static func playerUpdateMessage(
        isPlaying: Bool,
        podcastTitle: String? = nil
    ) -> WatchPushMessage {
        .playerUpdate(isPlaying: isPlaying, podcastTitle: podcastTitle)
    }

    /// Creates a location update message.
    public static func locationUpdateMessage() -> WatchPushMessage {
        .locationUpdate(locationSanFrancisco)
    }

    /// Creates a stats message.
    public static func statsMessage() -> WatchPushMessage {
        .stats(stats5K)
    }

    // MARK: - Request Messages (Raw Dictionaries)

    /// Raw dictionary for openDashboard request.
    public static var openDashboardRequest: [String: Any] {
        ["openDashBoard": [:]]
    }

    /// Raw dictionary for openMetrics request.
    public static var openMetricsRequest: [String: Any] {
        ["openMetrics": [:]]
    }

    /// Raw dictionary for openPodcast request.
    public static var openPodcastRequest: [String: Any] {
        ["openPodcast": [:]]
    }

    /// Raw dictionary for openMap request.
    public static var openMapRequest: [String: Any] {
        ["openMap": [:]]
    }

    /// Raw dictionary for openStats request.
    public static var openStatsRequest: [String: Any] {
        ["openStats": [:]]
    }

    /// Raw dictionary for acknowledge request.
    public static func acknowledgeRequest(messageType: String) -> [String: Any] {
        ["acknowledge": messageType]
    }

    // MARK: - Application Context

    /// Sample application context for workout state.
    public static var applicationContextWorkoutActive: [String: Any] {
        [
            "workoutActive": true,
            "workoutID": UUID().uuidString,
            "startTime": Date().timeIntervalSince1970
        ]
    }

    /// Sample application context for idle state.
    public static var applicationContextIdle: [String: Any] {
        [
            "workoutActive": false,
            "lastWorkoutDate": Date().timeIntervalSince1970
        ]
    }

    /// Sample application context with podcast info.
    public static var applicationContextWithPodcast: [String: Any] {
        [
            "currentPodcastTitle": "Running Mix Episode",
            "currentPosition": 120.0,
            "totalDuration": 3600.0
        ]
    }

    // MARK: - File Transfer

    /// Creates a mock file URL for testing.
    public static func mockFileURL(named: String = "test.png") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(named)
    }

    /// Creates mock metadata for file transfer.
    public static func mockFileMetadata(
        type: String = "routeImage",
        workoutID: String? = nil
    ) -> [String: Any] {
        var metadata: [String: Any] = ["type": type]
        if let id = workoutID {
            metadata["workoutID"] = id
        }
        return metadata
    }
}

// MARK: - Test Scenario Configurations

public extension WatchConnectivityTestFixtures {

    /// Configuration for testing with an active workout scenario.
    struct ActiveWorkoutScenario {
        public let dashboardData: DashboardData
        public let metricsData: MetricsData
        public let workoutUpdate: WorkoutUpdateData
        public let expectedView: WatchView = .metrics

        public init() {
            dashboardData = WatchConnectivityTestFixtures.dashboardWithActiveWorkout
            metricsData = WatchConnectivityTestFixtures.metricsActive
            workoutUpdate = WatchConnectivityTestFixtures.workoutUpdateComplete
        }
    }

    /// Configuration for testing idle state.
    struct IdleScenario {
        public let dashboardData: DashboardData
        public let podcastData: PodcastData
        public let expectedView: WatchView = .dashboard

        public init() {
            dashboardData = WatchConnectivityTestFixtures.dashboardIdle
            podcastData = WatchConnectivityTestFixtures.podcastEmpty
        }
    }

    /// Configuration for testing podcast playback.
    struct PodcastPlaybackScenario {
        public let podcastData: PodcastData
        public let dashboardData: DashboardData
        public let expectedView: WatchView = .podcast

        public init() {
            podcastData = WatchConnectivityTestFixtures.podcastPlaying
            dashboardData = WatchConnectivityTestFixtures.makeDashboardData(
                podcastPlaying: true,
                podcastTitle: podcastData.currentTitle
            )
        }
    }
}

// MARK: - WorkoutSnapshot Test Factory

public extension WatchConnectivityTestFixtures {

    /// Creates a WorkoutSnapshot for testing workout updates.
    static func makeWorkoutSnapshot(
        duration: TimeInterval = 1800,
        distanceInMeters: Double = 5000,
        speedMetersPerSecond: Double = 2.78,
        paceSecondsPerKilometer: Double = 360,
        caloriesBurned: Int = 350,
        heartRate: Int = 145,
        steps: Int = 5000
    ) -> WorkoutSnapshot {
        WorkoutSnapshot(
            duration: duration,
            distanceInMeters: distanceInMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            paceSecondsPerKilometer: paceSecondsPerKilometer,
            caloriesBurned: caloriesBurned,
            heartRate: heartRate,
            steps: steps
        )
    }

    /// A sample 5K workout snapshot.
    static var snapshot5K: WorkoutSnapshot {
        makeWorkoutSnapshot(
            duration: 1500,
            distanceInMeters: 5000,
            speedMetersPerSecond: 3.33,
            paceSecondsPerKilometer: 300,
            caloriesBurned: 320,
            heartRate: 155,
            steps: 5500
        )
    }

    /// A sample 10K workout snapshot.
    static var snapshot10K: WorkoutSnapshot {
        makeWorkoutSnapshot(
            duration: 3600,
            distanceInMeters: 10000,
            speedMetersPerSecond: 2.78,
            paceSecondsPerKilometer: 360,
            caloriesBurned: 680,
            heartRate: 148,
            steps: 11000
        )
    }
}
