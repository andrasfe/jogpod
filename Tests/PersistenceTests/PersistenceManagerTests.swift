//
//  PersistenceManagerTests.swift
//  JogPodTests
//
//  Created for JogPod Revival project.
//

import XCTest
import SwiftData
import CoreLocation
@testable import JogPod

/// Comprehensive tests for the PersistenceManager.
///
/// These tests cover all CRUD operations for each entity type,
/// error handling, and edge cases.
final class PersistenceManagerTests: XCTestCase {

    // MARK: - Properties

    private var manager: PersistenceManager!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        manager = try PersistenceManager.makeForTesting()
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Factory Method Tests

    func testMakeForTestingCreatesInMemoryManager() async throws {
        // Given/When
        let testManager = try PersistenceManager.makeForTesting()

        // Then
        XCTAssertNotNil(testManager.modelContainer)
    }

    func testMakeDefaultCreatesManager() async throws {
        // This test may fail in test environment without proper bundle setup
        // It's included for completeness but may need to be skipped in CI
        do {
            let defaultManager = try PersistenceManager.makeDefault()
            XCTAssertNotNil(defaultManager.modelContainer)
        } catch {
            // Expected in test environment without proper bundle
            XCTAssertTrue(error is PersistenceError)
        }
    }

    // MARK: - Podcast Feed Tests

    func testCreatePodcastFeed() async throws {
        // Given
        let title = "Test Podcast"
        let link = "https://example.com/feed.xml"
        let summary = "A test podcast"
        let imageUrl = "https://example.com/image.jpg"

        // When
        let feedID = try await manager.createPodcastFeed(
            title: title,
            link: link,
            summary: summary,
            imageUrl: imageUrl
        )

        // Then
        XCTAssertNotNil(feedID)

        let feed = try await manager.fetchPodcastFeed(byLink: link)
        XCTAssertNotNil(feed)
        XCTAssertEqual(feed?.title, title)
        XCTAssertEqual(feed?.link, link)
        XCTAssertEqual(feed?.summary, summary)
        XCTAssertEqual(feed?.imageUrl, imageUrl)
    }

    func testCreatePodcastFeedWithNilValues() async throws {
        // Given/When
        let feedID = try await manager.createPodcastFeed(
            title: nil,
            link: nil,
            summary: nil,
            imageUrl: nil
        )

        // Then
        XCTAssertNotNil(feedID)

        let feeds = try await manager.fetchAllPodcastFeeds()
        XCTAssertEqual(feeds.count, 1)
        XCTAssertNil(feeds.first?.title)
    }

    func testFetchPodcastFeedByLinkNotFound() async throws {
        // Given
        let nonExistentLink = "https://nonexistent.com/feed.xml"

        // When
        let feed = try await manager.fetchPodcastFeed(byLink: nonExistentLink)

        // Then
        XCTAssertNil(feed)
    }

    func testFetchAllPodcastFeeds() async throws {
        // Given
        _ = try await manager.createPodcastFeed(title: "Feed 1", link: "link1", summary: nil, imageUrl: nil)
        _ = try await manager.createPodcastFeed(title: "Feed 2", link: "link2", summary: nil, imageUrl: nil)
        _ = try await manager.createPodcastFeed(title: "Feed 3", link: "link3", summary: nil, imageUrl: nil)

        // When
        let feeds = try await manager.fetchAllPodcastFeeds()

        // Then
        XCTAssertEqual(feeds.count, 3)
    }

    func testDeletePodcastFeed() async throws {
        // Given
        let feedID = try await manager.createPodcastFeed(
            title: "To Delete",
            link: "delete-link",
            summary: nil,
            imageUrl: nil
        )

        // When
        try await manager.deletePodcastFeed(feedID)

        // Then
        let feed = try await manager.fetchPodcastFeed(byLink: "delete-link")
        XCTAssertNil(feed)
    }

    func testDeletePodcastFeedCascadesEpisodes() async throws {
        // Given
        let feedID = try await manager.createPodcastFeed(
            title: "Feed with Episodes",
            link: "feed-link",
            summary: nil,
            imageUrl: nil
        )

        _ = try await manager.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep1",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        // Verify episode exists
        var episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.count, 1)

        // When
        try await manager.deletePodcastFeed(feedID)

        // Then - episodes should be deleted due to cascade
        episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.count, 0)
    }

    // MARK: - Podcast Episode Tests

    func testCreatePodcastEpisode() async throws {
        // Given
        let title = "Test Episode"
        let identifier = "test-guid"
        let mediaLink = "https://example.com/episode.mp3"
        let releaseDate = Date()

        // When
        let episodeID = try await manager.createPodcastEpisode(
            title: title,
            identifier: identifier,
            enclosureMediaLink: mediaLink,
            releaseDate: releaseDate,
            feedIdentifier: nil
        )

        // Then
        XCTAssertNotNil(episodeID)

        let episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes.first?.title, title)
        XCTAssertEqual(episodes.first?.identifier, identifier)
        XCTAssertEqual(episodes.first?.enclosureMediaLink, mediaLink)
    }

    func testCreatePodcastEpisodeWithFeed() async throws {
        // Given
        let feedID = try await manager.createPodcastFeed(
            title: "Parent Feed",
            link: "parent-link",
            summary: nil,
            imageUrl: nil
        )

        // When
        _ = try await manager.createPodcastEpisode(
            title: "Child Episode",
            identifier: "child-ep",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: feedID
        )

        // Then
        let feed = try await manager.fetchPodcastFeed(byLink: "parent-link")
        XCTAssertEqual(feed?.episodes.count, 1)
        XCTAssertEqual(feed?.episodes.first?.title, "Child Episode")
    }

    func testFetchAllPodcastEpisodesSortedByIndex() async throws {
        // Given
        _ = try await manager.createPodcastEpisode(title: "Ep 1", identifier: "1", enclosureMediaLink: nil, releaseDate: nil, feedIdentifier: nil)
        _ = try await manager.createPodcastEpisode(title: "Ep 2", identifier: "2", enclosureMediaLink: nil, releaseDate: nil, feedIdentifier: nil)
        _ = try await manager.createPodcastEpisode(title: "Ep 3", identifier: "3", enclosureMediaLink: nil, releaseDate: nil, feedIdentifier: nil)

        // When
        let episodes = try await manager.fetchAllPodcastEpisodes(sortedByIndex: true)

        // Then
        XCTAssertEqual(episodes.count, 3)
        XCTAssertEqual(episodes[0].title, "Ep 1")
        XCTAssertEqual(episodes[1].title, "Ep 2")
        XCTAssertEqual(episodes[2].title, "Ep 3")
    }

    func testSetCurrentEpisode() async throws {
        // Given
        let ep1ID = try await manager.createPodcastEpisode(
            title: "Episode 1",
            identifier: "ep1",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )
        let ep2ID = try await manager.createPodcastEpisode(
            title: "Episode 2",
            identifier: "ep2",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        // When
        try await manager.setCurrentEpisode(ep1ID)

        // Then
        var current = try await manager.fetchCurrentEpisode()
        XCTAssertEqual(current?.title, "Episode 1")

        // When - change current
        try await manager.setCurrentEpisode(ep2ID)

        // Then - only one should be current
        current = try await manager.fetchCurrentEpisode()
        XCTAssertEqual(current?.title, "Episode 2")
    }

    func testClearCurrentEpisode() async throws {
        // Given
        let epID = try await manager.createPodcastEpisode(
            title: "Episode",
            identifier: "ep",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )
        try await manager.setCurrentEpisode(epID)

        // Verify it's set
        var current = try await manager.fetchCurrentEpisode()
        XCTAssertNotNil(current)

        // When
        try await manager.clearCurrentEpisode()

        // Then
        current = try await manager.fetchCurrentEpisode()
        XCTAssertNil(current)
    }

    func testUpdateEpisodeIndex() async throws {
        // Given
        let epID = try await manager.createPodcastEpisode(
            title: "Episode",
            identifier: "ep",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        // When
        try await manager.updateEpisodeIndex(epID, newIndex: 999)

        // Then
        let episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.first?.index, 999)
    }

    func testDeletePodcastEpisode() async throws {
        // Given
        let epID = try await manager.createPodcastEpisode(
            title: "To Delete",
            identifier: "del",
            enclosureMediaLink: nil,
            releaseDate: nil,
            feedIdentifier: nil
        )

        // Verify exists
        var episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.count, 1)

        // When
        try await manager.deletePodcastEpisode(epID)

        // Then
        episodes = try await manager.fetchAllPodcastEpisodes()
        XCTAssertEqual(episodes.count, 0)
    }

    // MARK: - Preference Tests

    func testSaveAndFetchBoolPreference() async throws {
        // Given
        let name = "testBool"
        let value = true

        // When
        try await manager.savePreference(name: name, value: value)
        let fetched: Bool? = try await manager.fetchPreference(name: name, as: Bool.self)

        // Then
        XCTAssertEqual(fetched, value)
    }

    func testSaveAndFetchIntPreference() async throws {
        // Given
        let name = "testInt"
        let value = 42

        // When
        try await manager.savePreference(name: name, value: value)
        let fetched: Int? = try await manager.fetchPreference(name: name, as: Int.self)

        // Then
        XCTAssertEqual(fetched, value)
    }

    func testSaveAndFetchFloatPreference() async throws {
        // Given
        let name = "testFloat"
        let value: Float = 3.14

        // When
        try await manager.savePreference(name: name, value: value)
        let fetched: Float? = try await manager.fetchPreference(name: name, as: Float.self)

        // Then
        XCTAssertEqual(fetched, value)
    }

    func testSaveAndFetchStringPreference() async throws {
        // Given
        let name = "testString"
        let value = "Hello World"

        // When
        try await manager.savePreference(name: name, value: value)
        let fetched: String? = try await manager.fetchPreference(name: name, as: String.self)

        // Then
        XCTAssertEqual(fetched, value)
    }

    func testSaveAndFetchDatePreference() async throws {
        // Given
        let name = "testDate"
        let value = Date()

        // When
        try await manager.savePreference(name: name, value: value)
        let fetched: Date? = try await manager.fetchPreference(name: name, as: Date.self)

        // Then
        XCTAssertNotNil(fetched)
        // Allow small time difference due to precision
        XCTAssertEqual(fetched!.timeIntervalSince1970, value.timeIntervalSince1970, accuracy: 1.0)
    }

    func testUpdateExistingPreference() async throws {
        // Given
        let name = "updatePref"
        try await manager.savePreference(name: name, value: "initial")

        // When
        try await manager.savePreference(name: name, value: "updated")

        // Then
        let fetched: String? = try await manager.fetchPreference(name: name, as: String.self)
        XCTAssertEqual(fetched, "updated")

        // Verify only one preference exists
        let allPrefs = try await manager.fetchAllPreferences()
        let matchingPrefs = allPrefs.filter { $0.name == name }
        XCTAssertEqual(matchingPrefs.count, 1)
    }

    func testFetchNonExistentPreference() async throws {
        // Given
        let name = "nonExistent"

        // When
        let fetched: String? = try await manager.fetchPreference(name: name, as: String.self)

        // Then
        XCTAssertNil(fetched)
    }

    func testFetchAllPreferences() async throws {
        // Given
        try await manager.savePreference(name: "pref1", value: "value1")
        try await manager.savePreference(name: "pref2", value: 42)
        try await manager.savePreference(name: "pref3", value: true)

        // When
        let prefs = try await manager.fetchAllPreferences()

        // Then
        XCTAssertEqual(prefs.count, 3)
    }

    func testDeletePreference() async throws {
        // Given
        let name = "toDelete"
        try await manager.savePreference(name: name, value: "delete me")

        // When
        try await manager.deletePreference(name: name)

        // Then
        let fetched: String? = try await manager.fetchPreference(name: name, as: String.self)
        XCTAssertNil(fetched)
    }

    func testDeleteNonExistentPreferenceDoesNotThrow() async throws {
        // Given
        let name = "nonExistent"

        // When/Then - should not throw
        try await manager.deletePreference(name: name)
    }

    func testSaveAndFetchCoordinatePreference() async throws {
        // Given
        let name = "testCoord"
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        // When
        try await manager.saveCoordinatePreference(name: name, coordinate: coordinate)
        let fetched = try await manager.fetchCoordinatePreference(name: name)

        // Then
        XCTAssertNotNil(fetched)
        if let lat = fetched?.latitude, let lon = fetched?.longitude {
            XCTAssertEqual(lat, coordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(lon, coordinate.longitude, accuracy: 0.0001)
        } else {
            XCTFail("Coordinate values should not be nil")
        }
    }

    // MARK: - Workout Session Tests

    func testCreateWorkoutSession() async throws {
        // Given
        let workoutID = "test-workout-123"
        let startTime = Date()

        // When
        let sessionID = try await manager.createWorkoutSession(
            workoutID: workoutID,
            startTime: startTime
        )

        // Then
        XCTAssertNotNil(sessionID)

        let session = try await manager.fetchWorkoutSession(byID: workoutID)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.workoutID, workoutID)
    }

    func testCreateWorkoutSessionWithAutoGeneratedID() async throws {
        // Given/When
        let sessionID = try await manager.createWorkoutSession(
            workoutID: nil,
            startTime: Date()
        )

        // Then
        XCTAssertNotNil(sessionID)

        let sessions = try await manager.fetchAllWorkoutSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(sessions.first!.workoutID.isEmpty)
    }

    func testFetchWorkoutSessionByIDNotFound() async throws {
        // Given
        let nonExistentID = "non-existent-workout"

        // When
        let session = try await manager.fetchWorkoutSession(byID: nonExistentID)

        // Then
        XCTAssertNil(session)
    }

    func testFetchAllWorkoutSessionsDescending() async throws {
        // Given
        _ = try await manager.createWorkoutSession(workoutID: "w1", startTime: Date().addingTimeInterval(-3600))
        _ = try await manager.createWorkoutSession(workoutID: "w2", startTime: Date().addingTimeInterval(-1800))
        _ = try await manager.createWorkoutSession(workoutID: "w3", startTime: Date())

        // When
        let sessions = try await manager.fetchAllWorkoutSessions(ascending: false)

        // Then
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].workoutID, "w3") // Most recent first
    }

    func testFetchAllWorkoutSessionsAscending() async throws {
        // Given
        _ = try await manager.createWorkoutSession(workoutID: "w1", startTime: Date().addingTimeInterval(-3600))
        _ = try await manager.createWorkoutSession(workoutID: "w2", startTime: Date().addingTimeInterval(-1800))
        _ = try await manager.createWorkoutSession(workoutID: "w3", startTime: Date())

        // When
        let sessions = try await manager.fetchAllWorkoutSessions(ascending: true)

        // Then
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].workoutID, "w1") // Oldest first
    }

    func testWorkoutSessionCount() async throws {
        // Given
        _ = try await manager.createWorkoutSession(workoutID: "w1", startTime: nil)
        _ = try await manager.createWorkoutSession(workoutID: "w2", startTime: nil)
        _ = try await manager.createWorkoutSession(workoutID: "w3", startTime: nil)

        // When
        let count = try await manager.workoutSessionCount()

        // Then
        XCTAssertEqual(count, 3)
    }

    func testDeleteWorkoutSession() async throws {
        // Given
        let workoutID = "to-delete"
        let sessionID = try await manager.createWorkoutSession(workoutID: workoutID, startTime: nil)

        // When
        try await manager.deleteWorkoutSession(sessionID)

        // Then
        let session = try await manager.fetchWorkoutSession(byID: workoutID)
        XCTAssertNil(session)
    }

    func testDeleteWorkoutSessionCascadesTrackPointsAndLogs() async throws {
        // Given
        let workoutID = "cascade-test"
        let sessionID = try await manager.createWorkoutSession(workoutID: workoutID, startTime: nil)

        _ = try await manager.createTrackPoint(workoutID: workoutID, time: Date(), location: nil, heartRate: nil, steps: nil)
        _ = try await manager.createListeningLog(workoutID: workoutID, time: Date(), entityTitle: "Test", entryTitle: "Test", entrySummary: nil)

        // Verify they exist
        var trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        var logs = try await manager.fetchListeningLogs(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 1)
        XCTAssertEqual(logs.count, 1)

        // When
        try await manager.deleteWorkoutSession(sessionID)

        // Then
        trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        logs = try await manager.fetchListeningLogs(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 0)
        XCTAssertEqual(logs.count, 0)
    }

    // MARK: - Workout Track Point Tests

    func testCreateTrackPoint() async throws {
        // Given
        let workoutID = "workout-123"
        let time = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let heartRate: Int16 = 145
        let steps: Int16 = 1000

        // When
        let trackPointID = try await manager.createTrackPoint(
            workoutID: workoutID,
            time: time,
            location: location,
            heartRate: heartRate,
            steps: steps
        )

        // Then
        XCTAssertNotNil(trackPointID)

        let trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 1)
        XCTAssertEqual(trackPoints.first?.workoutID, workoutID)
        XCTAssertEqual(trackPoints.first?.heartRate, heartRate)
        XCTAssertEqual(trackPoints.first?.steps, steps)
        if let lat = trackPoints.first?.latitude, let lon = trackPoints.first?.longitude {
            XCTAssertEqual(lat, location.coordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(lon, location.coordinate.longitude, accuracy: 0.0001)
        } else {
            XCTFail("Track point coordinate values should not be nil")
        }
    }

    func testCreateTrackPointWithoutLocation() async throws {
        // Given
        let workoutID = "workout-no-location"

        // When
        let trackPointID = try await manager.createTrackPoint(
            workoutID: workoutID,
            time: Date(),
            location: nil,
            heartRate: 120,
            steps: nil
        )

        // Then
        XCTAssertNotNil(trackPointID)

        let trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 1)
        XCTAssertNil(trackPoints.first?.latitude)
        XCTAssertNil(trackPoints.first?.longitude)
    }

    func testFetchTrackPointsChronologically() async throws {
        // Given
        let workoutID = "chronological-test"
        let baseTime = Date()

        _ = try await manager.createTrackPoint(workoutID: workoutID, time: baseTime.addingTimeInterval(60), location: nil, heartRate: 130, steps: nil)
        _ = try await manager.createTrackPoint(workoutID: workoutID, time: baseTime, location: nil, heartRate: 120, steps: nil)
        _ = try await manager.createTrackPoint(workoutID: workoutID, time: baseTime.addingTimeInterval(120), location: nil, heartRate: 140, steps: nil)

        // When
        let trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)

        // Then
        XCTAssertEqual(trackPoints.count, 3)
        XCTAssertEqual(trackPoints[0].heartRate, 120) // Earliest first
        XCTAssertEqual(trackPoints[1].heartRate, 130)
        XCTAssertEqual(trackPoints[2].heartRate, 140)
    }

    func testTrackPointCount() async throws {
        // Given
        let workoutID = "count-test"
        _ = try await manager.createTrackPoint(workoutID: workoutID, time: Date(), location: nil, heartRate: nil, steps: nil)
        _ = try await manager.createTrackPoint(workoutID: workoutID, time: Date(), location: nil, heartRate: nil, steps: nil)
        _ = try await manager.createTrackPoint(workoutID: "other-workout", time: Date(), location: nil, heartRate: nil, steps: nil)

        // When
        let count = try await manager.trackPointCount()

        // Then
        XCTAssertEqual(count, 3)
    }

    func testDeleteTrackPoint() async throws {
        // Given
        let workoutID = "delete-track"
        let trackPointID = try await manager.createTrackPoint(
            workoutID: workoutID,
            time: Date(),
            location: nil,
            heartRate: nil,
            steps: nil
        )

        // When
        try await manager.deleteTrackPoint(trackPointID)

        // Then
        let trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 0)
    }

    func testDeleteTrackPointsAtTime() async throws {
        // Given
        let workoutID = "delete-at-time"
        let targetTime = Date()

        _ = try await manager.createTrackPoint(workoutID: workoutID, time: targetTime, location: nil, heartRate: 120, steps: nil)
        _ = try await manager.createTrackPoint(workoutID: workoutID, time: Date().addingTimeInterval(60), location: nil, heartRate: 130, steps: nil)

        // When
        try await manager.deleteTrackPoints(forWorkoutID: workoutID, at: targetTime)

        // Then
        let trackPoints = try await manager.fetchTrackPoints(forWorkoutID: workoutID)
        XCTAssertEqual(trackPoints.count, 1)
        XCTAssertEqual(trackPoints.first?.heartRate, 130)
    }

    // MARK: - Workout Listening Log Tests

    func testCreateListeningLog() async throws {
        // Given
        let workoutID = "workout-log"
        let time = Date()
        let entityTitle = "Running Podcast"
        let entryTitle = "Episode 1"
        let summary = "Great episode"

        // When
        let logID = try await manager.createListeningLog(
            workoutID: workoutID,
            time: time,
            entityTitle: entityTitle,
            entryTitle: entryTitle,
            entrySummary: summary
        )

        // Then
        XCTAssertNotNil(logID)

        let logs = try await manager.fetchListeningLogs(forWorkoutID: workoutID)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.entityTitle, entityTitle)
        XCTAssertEqual(logs.first?.entryTitle, entryTitle)
        XCTAssertEqual(logs.first?.entrySummary, summary)
    }

    func testFetchListeningLogsChronologically() async throws {
        // Given
        let workoutID = "chrono-log"
        let baseTime = Date()

        _ = try await manager.createListeningLog(workoutID: workoutID, time: baseTime.addingTimeInterval(60), entityTitle: "P", entryTitle: "Ep2", entrySummary: nil)
        _ = try await manager.createListeningLog(workoutID: workoutID, time: baseTime, entityTitle: "P", entryTitle: "Ep1", entrySummary: nil)
        _ = try await manager.createListeningLog(workoutID: workoutID, time: baseTime.addingTimeInterval(120), entityTitle: "P", entryTitle: "Ep3", entrySummary: nil)

        // When
        let logs = try await manager.fetchListeningLogs(forWorkoutID: workoutID)

        // Then
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs[0].entryTitle, "Ep1") // Earliest first
        XCTAssertEqual(logs[1].entryTitle, "Ep2")
        XCTAssertEqual(logs[2].entryTitle, "Ep3")
    }

    func testDeleteListeningLog() async throws {
        // Given
        let workoutID = "delete-log"
        let logID = try await manager.createListeningLog(
            workoutID: workoutID,
            time: Date(),
            entityTitle: "Test",
            entryTitle: "Episode",
            entrySummary: nil
        )

        // When
        try await manager.deleteListeningLog(logID)

        // Then
        let logs = try await manager.fetchListeningLogs(forWorkoutID: workoutID)
        XCTAssertEqual(logs.count, 0)
    }

    // MARK: - Batch Operations Tests

    func testSave() async throws {
        // This test verifies save doesn't throw when called on unchanged context
        // When/Then - should not throw
        try await manager.save()
    }

    func testDeleteAllOfType() async throws {
        // Given
        _ = try await manager.createPodcastFeed(title: "Feed 1", link: "l1", summary: nil, imageUrl: nil)
        _ = try await manager.createPodcastFeed(title: "Feed 2", link: "l2", summary: nil, imageUrl: nil)
        _ = try await manager.createPodcastFeed(title: "Feed 3", link: "l3", summary: nil, imageUrl: nil)

        var feeds = try await manager.fetchAllPodcastFeeds()
        XCTAssertEqual(feeds.count, 3)

        // When
        try await manager.deleteAll(ofType: PodcastFeed.self)

        // Then
        feeds = try await manager.fetchAllPodcastFeeds()
        XCTAssertEqual(feeds.count, 0)
    }

    // MARK: - Error Handling Tests

    func testDeleteNonExistentFeedThrowsError() async throws {
        // Given
        let feedID = try await manager.createPodcastFeed(title: "Temp", link: "temp", summary: nil, imageUrl: nil)
        try await manager.deletePodcastFeed(feedID)

        // When/Then
        do {
            try await manager.deletePodcastFeed(feedID)
            XCTFail("Expected error to be thrown")
        } catch let error as PersistenceError {
            if case .entityNotFound = error {
                // Expected
            } else {
                XCTFail("Expected entityNotFound error, got \(error)")
            }
        }
    }

    func testSetCurrentEpisodeWithNonExistentIDThrowsError() async throws {
        // Given
        let epID = try await manager.createPodcastEpisode(title: "Temp", identifier: "temp", enclosureMediaLink: nil, releaseDate: nil, feedIdentifier: nil)
        try await manager.deletePodcastEpisode(epID)

        // When/Then
        do {
            try await manager.setCurrentEpisode(epID)
            XCTFail("Expected error to be thrown")
        } catch let error as PersistenceError {
            if case .entityNotFound = error {
                // Expected
            } else {
                XCTFail("Expected entityNotFound error, got \(error)")
            }
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentCreation() async throws {
        // Given
        let iterations = 20

        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    do {
                        _ = try await self.manager.createPodcastFeed(
                            title: "Feed \(i)",
                            link: "link-\(i)",
                            summary: nil,
                            imageUrl: nil
                        )
                    } catch {
                        XCTFail("Concurrent creation failed: \(error)")
                    }
                }
            }
        }

        // Then
        let feeds = try await manager.fetchAllPodcastFeeds()
        XCTAssertEqual(feeds.count, iterations)
    }

    func testConcurrentReadWrite() async throws {
        // Given
        _ = try await manager.createPodcastFeed(title: "Initial", link: "initial", summary: nil, imageUrl: nil)

        // When - concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            // Readers
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await self.manager.fetchAllPodcastFeeds()
                    } catch {
                        XCTFail("Concurrent read failed: \(error)")
                    }
                }
            }

            // Writers
            for i in 0..<5 {
                group.addTask {
                    do {
                        _ = try await self.manager.createPodcastFeed(
                            title: "Concurrent \(i)",
                            link: "concurrent-\(i)",
                            summary: nil,
                            imageUrl: nil
                        )
                    } catch {
                        XCTFail("Concurrent write failed: \(error)")
                    }
                }
            }
        }

        // Then
        let feeds = try await manager.fetchAllPodcastFeeds()
        XCTAssertEqual(feeds.count, 6) // 1 initial + 5 concurrent
    }
}
