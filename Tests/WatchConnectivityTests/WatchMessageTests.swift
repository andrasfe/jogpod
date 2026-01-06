//
//  WatchMessageTests.swift
//  JogPod
//
//  Tests for WatchMessage types and serialization.
//

import XCTest
import CoreLocation
@testable import JogPod

final class WatchMessageTests: XCTestCase {

    // MARK: - WatchRequest Parsing Tests

    func testParseOpenDashboardRequest() {
        let message: [String: Any] = ["openDashBoard": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .openDashboard = request {
            // Success
        } else {
            XCTFail("Expected openDashboard request")
        }
    }

    func testParseOpenMetricsRequest() {
        let message: [String: Any] = ["openMetrics": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .openMetrics = request {
            // Success
        } else {
            XCTFail("Expected openMetrics request")
        }
    }

    func testParseOpenPodcastRequest() {
        let message: [String: Any] = ["openPodcast": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .openPodcast = request {
            // Success
        } else {
            XCTFail("Expected openPodcast request")
        }
    }

    func testParseOpenMapRequest() {
        let message: [String: Any] = ["openMap": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .openMap = request {
            // Success
        } else {
            XCTFail("Expected openMap request")
        }
    }

    func testParseOpenStatsRequest() {
        let message: [String: Any] = ["openStats": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .openStats = request {
            // Success
        } else {
            XCTFail("Expected openStats request")
        }
    }

    func testParseAcknowledgeRequest() {
        let message: [String: Any] = ["acknowledge": "workoutStatus"]
        let request = WatchRequest.from(message)

        XCTAssertNotNil(request)
        if case .acknowledge(let messageType) = request {
            XCTAssertEqual(messageType, "workoutStatus")
        } else {
            XCTFail("Expected acknowledge request")
        }
    }

    func testParseUnknownRequest() {
        let message: [String: Any] = ["unknownCommand": [:]]
        let request = WatchRequest.from(message)

        XCTAssertNil(request)
    }

    func testParseEmptyMessage() {
        let message: [String: Any] = [:]
        let request = WatchRequest.from(message)

        XCTAssertNil(request)
    }

    // MARK: - WatchRequest Associated View Tests

    func testOpenDashboardAssociatedView() {
        XCTAssertEqual(WatchRequest.openDashboard.associatedView, .dashboard)
    }

    func testOpenMetricsAssociatedView() {
        XCTAssertEqual(WatchRequest.openMetrics.associatedView, .metrics)
    }

    func testOpenPodcastAssociatedView() {
        XCTAssertEqual(WatchRequest.openPodcast.associatedView, .podcast)
    }

    func testOpenMapAssociatedView() {
        XCTAssertEqual(WatchRequest.openMap.associatedView, .map)
    }

    func testOpenStatsAssociatedView() {
        XCTAssertEqual(WatchRequest.openStats.associatedView, .stats)
    }

    func testAcknowledgeAssociatedView() {
        XCTAssertEqual(WatchRequest.acknowledge(messageType: "test").associatedView, .none)
    }

    // MARK: - DashboardData Tests

    func testDashboardDataToDictionary() {
        let data = DashboardData(
            workoutInProgress: true,
            podcastPlaying: true,
            podcastTitle: "Test Episode",
            workoutCount: 42,
            isInitialized: true
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["workoutInProgress"] as? Int, 1)
        XCTAssertEqual(dict["podcastPlaying"] as? Int, 1)
        XCTAssertEqual(dict["podcastTitle"] as? String, "Test Episode")
        XCTAssertEqual(dict["noOfWorkouts"] as? Int, 42)
        XCTAssertEqual(dict["initialized"] as? Bool, true)
    }

    func testDashboardDataToDictionaryFalseValues() {
        let data = DashboardData(
            workoutInProgress: false,
            podcastPlaying: false,
            podcastTitle: "",
            workoutCount: 0,
            isInitialized: false
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["workoutInProgress"] as? Int, 0)
        XCTAssertEqual(dict["podcastPlaying"] as? Int, 0)
        XCTAssertEqual(dict["initialized"] as? Bool, false)
    }

    // MARK: - MetricsData Tests

    func testMetricsDataToDictionary() {
        let data = MetricsData(
            workoutInProgress: true,
            publisherCount: 4
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["workoutInProgress"] as? Int, 1)
        XCTAssertEqual(dict["publisherCount"] as? Int, 4)
    }

    // MARK: - PodcastData Tests

    func testPodcastDataToDictionary() {
        let data = PodcastData(
            currentTitle: "My Podcast Episode",
            isPlaying: true
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["currentTitle"] as? String, "My Podcast Episode")
        XCTAssertEqual(dict["isPlaying"] as? Int, 1)
    }

    // MARK: - WatchPushMessage Tests

    func testWorkoutStatusMessageToDictionary() {
        let message = WatchPushMessage.workoutStatus(isActive: true)
        let dict = message.toDictionary()

        let statusDict = dict["workoutStatus"] as? [String: Any]
        XCTAssertNotNil(statusDict)
        XCTAssertEqual(statusDict?["status"] as? Bool, true)
    }

    func testPodcastUpdateMessageToDictionary() {
        let message = WatchPushMessage.podcastUpdate(title: "Episode Title")
        let dict = message.toDictionary()

        let updateDict = dict["podcastUpdate"] as? [String: Any]
        XCTAssertNotNil(updateDict)
        XCTAssertEqual(updateDict?["title"] as? String, "Episode Title")
    }

    func testPlayerUpdateMessageToDictionary() {
        let message = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: "Title")
        let dict = message.toDictionary()

        let updateDict = dict["playerUpdate"] as? [String: Any]
        XCTAssertNotNil(updateDict)
        XCTAssertEqual(updateDict?["isPlaying"] as? Bool, true)
        XCTAssertEqual(updateDict?["podcastTitle"] as? String, "Title")
    }

    func testPlayerUpdateMessageWithoutTitle() {
        let message = WatchPushMessage.playerUpdate(isPlaying: false, podcastTitle: nil)
        let dict = message.toDictionary()

        let updateDict = dict["playerUpdate"] as? [String: Any]
        XCTAssertNotNil(updateDict)
        XCTAssertNil(updateDict?["podcastTitle"])
    }

    // MARK: - WatchPushMessage Target Views Tests

    func testWorkoutStatusTargetViews() {
        let message = WatchPushMessage.workoutStatus(isActive: true)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.metrics))
        XCTAssertFalse(message.targetViews.contains(.podcast))
    }

    func testPodcastUpdateTargetViews() {
        let message = WatchPushMessage.podcastUpdate(title: "")
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.podcast))
        XCTAssertFalse(message.targetViews.contains(.metrics))
    }

    func testLocationUpdateTargetViews() {
        let data = LocationUpdateData(
            latitude: 0,
            longitude: 0
        )
        let message = WatchPushMessage.locationUpdate(data)
        XCTAssertTrue(message.targetViews.contains(.map))
        XCTAssertEqual(message.targetViews.count, 1)
    }

    func testStatsTargetViews() {
        let data = StatsData(
            distanceKm: 0,
            durationSeconds: 0,
            averagePace: 0,
            calories: 0
        )
        let message = WatchPushMessage.stats(data)
        XCTAssertTrue(message.targetViews.contains(.stats))
        XCTAssertEqual(message.targetViews.count, 1)
    }

    // MARK: - LocationUpdateData Tests

    func testLocationUpdateDataFromCLLocation() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10,
            horizontalAccuracy: 5,
            verticalAccuracy: 10,
            course: 90,
            speed: 3.5,
            timestamp: Date()
        )

        let data = LocationUpdateData(location: location)

        XCTAssertEqual(data.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(data.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(data.horizontalAccuracy, 5, accuracy: 0.01)
        XCTAssertEqual(data.speed, 3.5, accuracy: 0.01)
        XCTAssertEqual(data.course, 90, accuracy: 0.01)
    }

    func testLocationUpdateDataToDictionary() {
        let timestamp = Date()
        let data = LocationUpdateData(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 5,
            speed: 3.5,
            course: 90,
            timestamp: timestamp
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["latitude"] as? Double, 37.7749)
        XCTAssertEqual(dict["longitude"] as? Double, -122.4194)
        XCTAssertEqual(dict["horizontalAccuracy"] as? Double, 5)
        XCTAssertEqual(dict["speed"] as? Double, 3.5)
        XCTAssertEqual(dict["course"] as? Double, 90)
        XCTAssertEqual(dict["timestamp"] as? TimeInterval, timestamp.timeIntervalSince1970)
    }

    // MARK: - StatsData Tests

    func testStatsDataToDictionary() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let data = StatsData(
            distanceKm: 5.5,
            durationSeconds: 1800,
            averagePace: 5.45,
            calories: 350,
            mapImageData: imageData
        )

        let dict = data.toDictionary()

        XCTAssertEqual(dict["distanceKm"] as? Double, 5.5)
        XCTAssertEqual(dict["durationSeconds"] as? TimeInterval, 1800)
        XCTAssertEqual(dict["averagePace"] as? Double, 5.45)
        XCTAssertEqual(dict["calories"] as? Int, 350)
        XCTAssertEqual(dict["mapImage"] as? Data, imageData)
    }

    func testStatsDataWithoutImage() {
        let data = StatsData(
            distanceKm: 5.5,
            durationSeconds: 1800,
            averagePace: 5.45,
            calories: 350,
            mapImageData: nil
        )

        let dict = data.toDictionary()

        XCTAssertNil(dict["mapImage"])
    }

    // MARK: - WorkoutUpdateData Tests

    func testWorkoutUpdateDataToDictionary() {
        let fields: [Int: String] = [
            1: "5.50 km",
            2: "30:00",
            3: "5:27 /km"
        ]

        let data = WorkoutUpdateData(fields: fields, podcastTitle: "Podcast Episode")

        let dict = data.toDictionary()

        XCTAssertEqual(dict["1"] as? String, "5.50 km")
        XCTAssertEqual(dict["2"] as? String, "30:00")
        XCTAssertEqual(dict["3"] as? String, "5:27 /km")
        XCTAssertEqual(dict["7"] as? String, "Podcast Episode")
    }

    // MARK: - WatchResponse Tests

    func testDashboardResponseToDictionary() {
        let data = DashboardData(
            workoutInProgress: true,
            podcastPlaying: false,
            podcastTitle: "Test",
            workoutCount: 10
        )
        let response = WatchResponse.dashboard(data)

        let dict = response.toDictionary()

        XCTAssertEqual(dict["workoutInProgress"] as? Int, 1)
        XCTAssertEqual(dict["podcastPlaying"] as? Int, 0)
    }

    func testNotInitializedResponseToDictionary() {
        let response = WatchResponse.notInitialized
        let dict = response.toDictionary()

        XCTAssertEqual(dict["initialized"] as? Bool, false)
    }

    func testMapResponseToDictionary() {
        let response = WatchResponse.map
        let dict = response.toDictionary()

        XCTAssertEqual(dict["status"] as? String, "ok")
    }

    // MARK: - WatchConnectivityError Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(WatchConnectivityError.notSupported.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.sessionNotActivated.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.watchAppNotInstalled.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.watchNotPaired.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.watchNotReachable.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.replyTimeout.errorDescription)
        XCTAssertNotNil(WatchConnectivityError.invalidMessageFormat.errorDescription)

        let sendError = WatchConnectivityError.messageSendFailed(reason: "Test reason")
        XCTAssertTrue(sendError.errorDescription?.contains("Test reason") == true)

        let activationError = WatchConnectivityError.activationFailed(reason: "Activation reason")
        XCTAssertTrue(activationError.errorDescription?.contains("Activation reason") == true)
    }

    func testErrorEquality() {
        XCTAssertEqual(WatchConnectivityError.notSupported, WatchConnectivityError.notSupported)
        XCTAssertEqual(WatchConnectivityError.replyTimeout, WatchConnectivityError.replyTimeout)
        XCTAssertNotEqual(WatchConnectivityError.notSupported, WatchConnectivityError.replyTimeout)

        XCTAssertEqual(
            WatchConnectivityError.messageSendFailed(reason: "test"),
            WatchConnectivityError.messageSendFailed(reason: "test")
        )
        XCTAssertNotEqual(
            WatchConnectivityError.messageSendFailed(reason: "test1"),
            WatchConnectivityError.messageSendFailed(reason: "test2")
        )
    }
}
