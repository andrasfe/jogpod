//
//  WatchConnectivityEquivalenceTests.swift
//  JogPod
//
//  Equivalence tests verifying behavioral parity with legacy WatchKitRequestHandler.
//
//  These tests ensure the new WatchConnectivityService and WatchMessageHandler
//  produce the same outputs as the original Objective-C implementation.
//

import XCTest
import CoreLocation
@testable import JogPod

/// Equivalence tests for WatchConnectivity migration.
///
/// Test ID prefix: WC-* (Watch Connectivity)
///
/// These tests verify that the new Swift implementation produces
/// equivalent behavior to the legacy Objective-C code.
final class WatchConnectivityEquivalenceTests: XCTestCase {

    // MARK: - WC-001: Dashboard Response Format

    /// WC-001: Verify dashboard response matches legacy format.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m lines 146-151):
    /// ```objc
    /// NSDictionary *dict = @{@"workoutInProgress" : [NSNumber numberWithInt:workoutInProgress ? 1 : 0],
    ///                        @"podcastPlaying" : [NSNumber numberWithInt:podcastPlaying ? 1 : 0],
    ///                        @"podcastTitle" : itemTitle,
    ///                        @"initialized" : [NSNumber numberWithBool:YES],
    ///                        @"noOfWorkouts" : [NSNumber numberWithInt:noOfWorkouts]};
    /// ```
    func testWC001_DashboardResponseMatchesLegacyFormat() {
        // Given
        let data = DashboardData(
            workoutInProgress: true,
            podcastPlaying: true,
            podcastTitle: "Test Episode",
            workoutCount: 42,
            isInitialized: true
        )

        // When
        let dict = data.toDictionary()

        // Then - verify legacy keys and value types
        XCTAssertEqual(dict["workoutInProgress"] as? Int, 1, "workoutInProgress should be Int 1 for true")
        XCTAssertEqual(dict["podcastPlaying"] as? Int, 1, "podcastPlaying should be Int 1 for true")
        XCTAssertEqual(dict["podcastTitle"] as? String, "Test Episode")
        XCTAssertEqual(dict["initialized"] as? Bool, true)
        XCTAssertEqual(dict["noOfWorkouts"] as? Int, 42, "Key should be 'noOfWorkouts' not 'workoutCount'")
    }

    /// WC-001b: Verify dashboard response with false values.
    func testWC001b_DashboardResponseFalseValues() {
        // Given
        let data = DashboardData(
            workoutInProgress: false,
            podcastPlaying: false,
            podcastTitle: "",
            workoutCount: 0,
            isInitialized: true
        )

        // When
        let dict = data.toDictionary()

        // Then - legacy used 0 for false
        XCTAssertEqual(dict["workoutInProgress"] as? Int, 0, "workoutInProgress should be Int 0 for false")
        XCTAssertEqual(dict["podcastPlaying"] as? Int, 0, "podcastPlaying should be Int 0 for false")
    }

    // MARK: - WC-002: Metrics Response Format

    /// WC-002: Verify metrics response matches legacy format.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m lines 170-171):
    /// ```objc
    /// return @{@"workoutInProgress" : [NSNumber numberWithInt:workoutInProgress ? 1 : 0],
    ///          @"publisherCount" : [NSNumber numberWithInt: (int)publishers.count]};
    /// ```
    func testWC002_MetricsResponseMatchesLegacyFormat() {
        // Given
        let data = MetricsData(
            workoutInProgress: true,
            publisherCount: 4
        )

        // When
        let dict = data.toDictionary()

        // Then
        XCTAssertEqual(dict["workoutInProgress"] as? Int, 1)
        XCTAssertEqual(dict["publisherCount"] as? Int, 4)
    }

    // MARK: - WC-003: Podcast Response Format

    /// WC-003: Verify podcast response matches legacy format.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m line 188):
    /// ```objc
    /// return @{@"currentTitle" : currentTitle, @"isPlaying" : [NSNumber numberWithInt:isPlaying ? 1 : 0]};
    /// ```
    func testWC003_PodcastResponseMatchesLegacyFormat() {
        // Given
        let data = PodcastData(
            currentTitle: "My Podcast Episode",
            isPlaying: true
        )

        // When
        let dict = data.toDictionary()

        // Then
        XCTAssertEqual(dict["currentTitle"] as? String, "My Podcast Episode")
        XCTAssertEqual(dict["isPlaying"] as? Int, 1, "isPlaying should be Int 1 for true")
    }

    // MARK: - WC-004: Request Message Keys

    /// WC-004: Verify request parsing uses legacy message keys.
    ///
    /// Legacy keys (WatchKitRequestHandler.m lines 298-317):
    /// - "openDashBoard" (note capital B)
    /// - "openMetrics"
    /// - "openPodcast"
    /// - "openMap"
    /// - "openStats"
    func testWC004_RequestParsingUsesLegacyKeys() {
        // Legacy used "openDashBoard" with capital B
        let dashboardRequest = WatchRequest.from(["openDashBoard": [:]])
        XCTAssertNotNil(dashboardRequest, "Should parse 'openDashBoard' with capital B")

        let metricsRequest = WatchRequest.from(["openMetrics": [:]])
        XCTAssertNotNil(metricsRequest)

        let podcastRequest = WatchRequest.from(["openPodcast": [:]])
        XCTAssertNotNil(podcastRequest)

        let mapRequest = WatchRequest.from(["openMap": [:]])
        XCTAssertNotNil(mapRequest)

        let statsRequest = WatchRequest.from(["openStats": [:]])
        XCTAssertNotNil(statsRequest)
    }

    // MARK: - WC-005: Push Message Keys

    /// WC-005: Verify push message keys match legacy identifiers.
    ///
    /// Legacy identifiers (WatchKitRequestHandler.m):
    /// - "workoutStatus" (line 105)
    /// - "podcastUpdate" (line 114)
    /// - "playerUpdate" (line 129)
    /// - "workoutUpdate" (line 253)
    /// - "locationUpdate" (line 201)
    /// - "stats" (line 232)
    func testWC005_PushMessageKeysMatchLegacy() {
        // workoutStatus
        let workoutMessage = WatchPushMessage.workoutStatus(isActive: true).toDictionary()
        XCTAssertNotNil(workoutMessage["workoutStatus"], "Key should be 'workoutStatus'")

        // podcastUpdate
        let podcastMessage = WatchPushMessage.podcastUpdate(title: "Test").toDictionary()
        XCTAssertNotNil(podcastMessage["podcastUpdate"], "Key should be 'podcastUpdate'")

        // playerUpdate
        let playerMessage = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: nil).toDictionary()
        XCTAssertNotNil(playerMessage["playerUpdate"], "Key should be 'playerUpdate'")

        // workoutUpdate
        let workoutUpdateMessage = WatchPushMessage.workoutUpdate(WorkoutUpdateData(fields: [:], podcastTitle: nil)).toDictionary()
        XCTAssertNotNil(workoutUpdateMessage["workoutUpdate"], "Key should be 'workoutUpdate'")

        // locationUpdate
        let locationMessage = WatchPushMessage.locationUpdate(LocationUpdateData(latitude: 0, longitude: 0)).toDictionary()
        XCTAssertNotNil(locationMessage["locationUpdate"], "Key should be 'locationUpdate'")

        // stats
        let statsMessage = WatchPushMessage.stats(StatsData(distanceKm: 0, durationSeconds: 0, averagePace: 0, calories: 0)).toDictionary()
        XCTAssertNotNil(statsMessage["stats"], "Key should be 'stats'")
    }

    // MARK: - WC-006: View-Based Message Filtering

    /// WC-006: Verify message filtering matches legacy currentView logic.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m):
    /// - workoutStatus only sent to DASHBOARD or METRICS (lines 100-102)
    /// - podcastUpdate only sent to DASHBOARD or PODCAST (lines 110-112)
    /// - playerUpdate only sent to DASHBOARD or PODCAST (lines 120-122)
    /// - workoutUpdate only sent to DASHBOARD or METRICS (lines 243-245)
    /// - locationUpdate only sent to MAPS (lines 197-199)
    /// - stats only sent to STATS (lines 220-222)
    func testWC006_WorkoutStatusMessageFilter() {
        let message = WatchPushMessage.workoutStatus(isActive: true)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.metrics))
        XCTAssertFalse(message.targetViews.contains(.podcast))
        XCTAssertFalse(message.targetViews.contains(.map))
        XCTAssertFalse(message.targetViews.contains(.stats))
    }

    func testWC006_PodcastUpdateMessageFilter() {
        let message = WatchPushMessage.podcastUpdate(title: "Test")
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.podcast))
        XCTAssertFalse(message.targetViews.contains(.metrics))
    }

    func testWC006_PlayerUpdateMessageFilter() {
        let message = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: nil)
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.podcast))
    }

    func testWC006_WorkoutUpdateMessageFilter() {
        let message = WatchPushMessage.workoutUpdate(WorkoutUpdateData(fields: [:], podcastTitle: nil))
        XCTAssertTrue(message.targetViews.contains(.dashboard))
        XCTAssertTrue(message.targetViews.contains(.metrics))
    }

    func testWC006_LocationUpdateMessageFilter() {
        let message = WatchPushMessage.locationUpdate(LocationUpdateData(latitude: 0, longitude: 0))
        XCTAssertTrue(message.targetViews.contains(.map))
        XCTAssertEqual(message.targetViews.count, 1, "Location updates should only go to map view")
    }

    func testWC006_StatsMessageFilter() {
        let message = WatchPushMessage.stats(StatsData(distanceKm: 0, durationSeconds: 0, averagePace: 0, calories: 0))
        XCTAssertTrue(message.targetViews.contains(.stats))
        XCTAssertEqual(message.targetViews.count, 1, "Stats should only go to stats view")
    }

    // MARK: - WC-007: Not Initialized Response

    /// WC-007: Verify not initialized response matches legacy.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m lines 93-95):
    /// ```objc
    /// if (![[PersistenceManager sharedInstance] boolPreference:kDisclaimerAccepted]) {
    ///     return @{@"initialized" : [NSNumber numberWithBool:NO]};
    /// }
    /// ```
    func testWC007_NotInitializedResponseMatchesLegacy() {
        let response = WatchResponse.notInitialized
        let dict = response.toDictionary()

        XCTAssertEqual(dict["initialized"] as? Bool, false)
    }

    // MARK: - WC-008: Workout Update Field Tags

    /// WC-008: Verify workout update field tags match legacy numbering.
    ///
    /// Legacy tags (ViewDataSetter protocol, various view controllers):
    /// - 1: Distance
    /// - 2: Duration
    /// - 3: Pace
    /// - 4: Speed
    /// - 5: Calories
    /// - 6: Heart rate
    /// - 7: Podcast title
    func testWC008_WorkoutUpdateFieldTagsMatchLegacy() {
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.distance.rawValue, 1)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.duration.rawValue, 2)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.pace.rawValue, 3)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.speed.rawValue, 4)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.calories.rawValue, 5)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.heartRate.rawValue, 6)
        XCTAssertEqual(WorkoutMetricsFormatter.FieldTag.podcastTitle.rawValue, 7)
    }

    // MARK: - WC-009: Podcast Title in Player Update

    /// WC-009: Verify podcastTitle is included in playerUpdate when available.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m lines 124-133):
    /// ```objc
    /// if (podcastTitle) {
    ///     NSMutableDictionary *wormholeDict = note.userInfo.mutableCopy;
    ///     [wormholeDict setObject:podcastTitle forKey:@"podcastTitle"];
    ///     [self passMessageObject:wormholeDict identifier:@"playerUpdate"];
    /// }
    /// ```
    func testWC009_PlayerUpdateIncludesPodcastTitle() {
        let messageWithTitle = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: "Episode Title")
        let dictWithTitle = messageWithTitle.toDictionary()
        let updateDict = dictWithTitle["playerUpdate"] as? [String: Any]
        XCTAssertEqual(updateDict?["podcastTitle"] as? String, "Episode Title")

        let messageWithoutTitle = WatchPushMessage.playerUpdate(isPlaying: true, podcastTitle: nil)
        let dictWithoutTitle = messageWithoutTitle.toDictionary()
        let updateDictNoTitle = dictWithoutTitle["playerUpdate"] as? [String: Any]
        XCTAssertNil(updateDictNoTitle?["podcastTitle"], "podcastTitle should be omitted when nil")
    }

    // MARK: - WC-010: Stats Map Image Key

    /// WC-010: Verify stats response uses correct key for map image.
    ///
    /// Legacy behavior (WatchKitRequestHandler.m line 229):
    /// ```objc
    /// [mutableDict setObject:png forKey:@"mapImage"];
    /// ```
    func testWC010_StatsMapImageKeyMatchesLegacy() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let statsData = StatsData(
            distanceKm: 5.0,
            durationSeconds: 1800,
            averagePace: 6.0,
            calories: 300,
            mapImageData: imageData
        )

        let dict = statsData.toDictionary()
        XCTAssertNotNil(dict["mapImage"], "Key should be 'mapImage'")
        XCTAssertEqual(dict["mapImage"] as? Data, imageData)
    }

    // MARK: - WC-011: Publisher Count

    /// WC-011: Verify publisher count matches legacy implementation.
    ///
    /// Legacy had 4 publishers configured in PublisherFactory.
    func testWC011_PublisherCountMatchesLegacy() {
        XCTAssertEqual(WatchMessageHandler.publisherCount, 4, "Publisher count should match legacy")
    }
}
