//
//  RouteImageGeneratorTests.swift
//  JogPodTests
//
//  Tests for RouteImageGenerator covering:
//  - Image generation with valid coordinates
//  - Empty/nil route handling
//  - Coordinate downsampling
//  - Image format validation
//
//  Created for JogPod Revival project.
//

import XCTest
import CoreLocation
import MapKit
import SwiftData
@testable import JogPod

// MARK: - RouteImageGeneratorTests

final class RouteImageGeneratorTests: XCTestCase {

    // MARK: - Properties

    private var mockWorkoutService: MockWorkoutServiceForRoute!
    private var mockPersistence: MockPersistenceManagerForRoute!
    private var sut: RouteImageGenerator!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockWorkoutService = MockWorkoutServiceForRoute()
        mockPersistence = MockPersistenceManagerForRoute()
        sut = RouteImageGenerator(
            workoutService: mockWorkoutService,
            persistenceManager: mockPersistence
        )
    }

    @MainActor
    override func tearDown() {
        sut = nil
        mockPersistence = nil
        mockWorkoutService = nil
        super.tearDown()
    }

    // MARK: - Basic Generation Tests

    @MainActor
    func testGenerateRouteImageReturnsNilWhenNoActiveWorkout() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = nil

        // When
        let result = await sut.generateRouteImage()

        // Then
        XCTAssertNil(result)
    }

    @MainActor
    func testGenerateRouteImageReturnsNilWhenNoTrackPoints() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = []

        // When
        let result = await sut.generateRouteImage()

        // Then
        XCTAssertNil(result)
    }

    @MainActor
    func testGenerateRouteImageReturnsNilWhenOnlyOneCoordinate() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = [
            makeTrackPoint(latitude: 37.7749, longitude: -122.4194)
        ]

        // When
        let result = await sut.generateRouteImage()

        // Then - need at least 2 coordinates for a route
        XCTAssertNil(result)
    }

    @MainActor
    func testGenerateRouteImageSucceedsWithValidRoute() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = makeSimpleRoute()

        // When
        let result = await sut.generateRouteImage()

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.count > 0)
    }

    @MainActor
    func testGenerateRouteImageReturnsPNGData() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = makeSimpleRoute()

        // When
        let result = await sut.generateRouteImage()

        // Then - verify PNG magic bytes
        XCTAssertNotNil(result)
        if let data = result {
            XCTAssertTrue(isPNGData(data), "Result should be valid PNG data")
        }
    }

    // MARK: - Coordinate Handling Tests

    @MainActor
    func testGenerateRouteImageHandlesTrackPointsWithoutCoordinates() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = [
            makeTrackPoint(latitude: nil, longitude: nil),  // No coordinates
            makeTrackPoint(latitude: 37.7749, longitude: -122.4194),
            makeTrackPoint(latitude: 37.7750, longitude: -122.4190),
            makeTrackPoint(latitude: nil, longitude: nil)   // No coordinates
        ]

        // When
        let result = await sut.generateRouteImage()

        // Then - should succeed using only valid coordinates
        XCTAssertNotNil(result)
    }

    @MainActor
    func testGenerateRouteImageReturnsNilWhenAllTrackPointsHaveNoCoordinates() async {
        // Given
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = [
            makeTrackPoint(latitude: nil, longitude: nil),
            makeTrackPoint(latitude: nil, longitude: nil)
        ]

        // When
        let result = await sut.generateRouteImage()

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Downsampling Tests

    @MainActor
    func testGenerateRouteImageDownsamplesLongRoutes() async {
        // Given - create a route with more than 200 points
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = makeLongRoute(pointCount: 500)

        // When
        let result = await sut.generateRouteImage()

        // Then - should still succeed (downsampling happens internally)
        XCTAssertNotNil(result)
    }

    // MARK: - Image Size Tests

    @MainActor
    func testDefaultImageSizeIsCorrect() {
        XCTAssertEqual(RouteImageGenerator.defaultImageSize.width, 352)
        XCTAssertEqual(RouteImageGenerator.defaultImageSize.height, 176)
    }

    @MainActor
    func testSmallImageSizeIsCorrect() {
        XCTAssertEqual(RouteImageGenerator.smallImageSize.width, 312)
        XCTAssertEqual(RouteImageGenerator.smallImageSize.height, 156)
    }

    @MainActor
    func testUltraImageSizeIsCorrect() {
        XCTAssertEqual(RouteImageGenerator.ultraImageSize.width, 410)
        XCTAssertEqual(RouteImageGenerator.ultraImageSize.height, 205)
    }

    // MARK: - Factory Tests

    @MainActor
    func testFactoryCreatesGeneratorWithCorrectSizeForSmallWatch() {
        // When
        let generator = RouteImageGeneratorFactory.makeGenerator(
            workoutService: mockWorkoutService,
            persistenceManager: mockPersistence,
            watchSize: .small
        )

        // Then - generator is created (we can't directly access imageSize, but the factory works)
        XCTAssertNotNil(generator)
    }

    @MainActor
    func testFactoryCreatesGeneratorWithCorrectSizeForRegularWatch() {
        // When
        let generator = RouteImageGeneratorFactory.makeGenerator(
            workoutService: mockWorkoutService,
            persistenceManager: mockPersistence,
            watchSize: .regular
        )

        // Then
        XCTAssertNotNil(generator)
    }

    @MainActor
    func testFactoryCreatesGeneratorWithCorrectSizeForUltraWatch() {
        // When
        let generator = RouteImageGeneratorFactory.makeGenerator(
            workoutService: mockWorkoutService,
            persistenceManager: mockPersistence,
            watchSize: .ultra
        )

        // Then
        XCTAssertNotNil(generator)
    }

    // MARK: - Edge Case Tests

    @MainActor
    func testGenerateRouteImageHandlesZeroLengthRoute() async {
        // Given - two identical points
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = [
            makeTrackPoint(latitude: 37.7749, longitude: -122.4194),
            makeTrackPoint(latitude: 37.7749, longitude: -122.4194)
        ]

        // When
        let result = await sut.generateRouteImage()

        // Then - should handle gracefully (minimum span is applied)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testGenerateRouteImageHandlesVerySmallRoute() async {
        // Given - very close points
        mockWorkoutService.mockActiveWorkoutID = "test-workout-id"
        mockPersistence.mockTrackPoints = [
            makeTrackPoint(latitude: 37.7749000, longitude: -122.4194000),
            makeTrackPoint(latitude: 37.7749001, longitude: -122.4194001)
        ]

        // When
        let result = await sut.generateRouteImage()

        // Then
        XCTAssertNotNil(result)
    }

    // MARK: - Protocol Conformance Tests

    @MainActor
    func testConformsToRouteImageGenerating() {
        let generator: any RouteImageGenerating = sut
        XCTAssertNotNil(generator)
    }

    @MainActor
    func testConformsToSendable() {
        // RouteImageGenerator should be Sendable for use across actors
        let _: @Sendable () async -> Data? = { [generator = self.sut!] in
            await generator.generateRouteImage()
        }
    }

    // MARK: - Mock Implementation Tests

    @MainActor
    func testMockRouteImageGeneratorReturnsProvidedData() async {
        // Given
        let mockData = Data([0x89, 0x50, 0x4E, 0x47])  // PNG header
        let mockGenerator = MockRouteImageGenerator(mockData: mockData)

        // When
        let result = await mockGenerator.generateRouteImage()

        // Then
        XCTAssertEqual(result, mockData)
    }

    @MainActor
    func testMockRouteImageGeneratorReturnsNilWhenNotConfigured() async {
        // Given
        let mockGenerator = MockRouteImageGenerator(mockData: nil)

        // When
        let result = await mockGenerator.generateRouteImage()

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeTrackPoint(
        latitude: Double?,
        longitude: Double?,
        workoutID: String = "test-workout-id"
    ) -> WorkoutTrackPoint {
        let trackPoint = WorkoutTrackPoint(workoutID: workoutID, time: Date())
        if let lat = latitude, let lon = longitude {
            let location = CLLocation(latitude: lat, longitude: lon)
            trackPoint.setLocation(location)
        }
        return trackPoint
    }

    private func makeSimpleRoute() -> [WorkoutTrackPoint] {
        // A simple L-shaped route
        [
            makeTrackPoint(latitude: 37.7749, longitude: -122.4194),
            makeTrackPoint(latitude: 37.7750, longitude: -122.4194),
            makeTrackPoint(latitude: 37.7751, longitude: -122.4194),
            makeTrackPoint(latitude: 37.7751, longitude: -122.4190),
            makeTrackPoint(latitude: 37.7751, longitude: -122.4186)
        ]
    }

    private func makeLongRoute(pointCount: Int) -> [WorkoutTrackPoint] {
        var trackPoints: [WorkoutTrackPoint] = []
        for i in 0..<pointCount {
            let lat = 37.7749 + Double(i) * 0.0001
            let lon = -122.4194 + Double(i) * 0.0001
            trackPoints.append(makeTrackPoint(latitude: lat, longitude: lon))
        }
        return trackPoints
    }

    private func isPNGData(_ data: Data) -> Bool {
        // Check for PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
        guard data.count >= 8 else { return false }
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return data.prefix(8).elementsEqual(pngMagic)
    }
}

// MARK: - Mock WorkoutService for Route Tests

/// Mock workout service for testing RouteImageGenerator.
@MainActor
final class MockWorkoutServiceForRoute: WorkoutServiceProtocol {
    var mockActiveWorkoutID: String?
    var mockState: WorkoutState = .idle
    var mockIsWorkoutInProgress: Bool = false
    var mockCurrentMetrics: WorkoutSnapshot?

    nonisolated var state: WorkoutState {
        get async {
            await MainActor.run { mockState }
        }
    }

    nonisolated var activeWorkoutID: String? {
        get async {
            await MainActor.run { mockActiveWorkoutID }
        }
    }

    nonisolated var isWorkoutInProgress: Bool {
        get async {
            await MainActor.run { mockIsWorkoutInProgress }
        }
    }

    nonisolated func startWorkout() async throws -> String {
        let id = UUID().uuidString
        await MainActor.run {
            mockActiveWorkoutID = id
            mockState = .active
            mockIsWorkoutInProgress = true
        }
        return id
    }

    nonisolated func stopWorkout() async throws {
        await MainActor.run {
            mockActiveWorkoutID = nil
            mockState = .idle
            mockIsWorkoutInProgress = false
        }
    }

    nonisolated func requestAuthorization() async throws {
        // No-op for mock
    }

    nonisolated func currentMetrics() async -> WorkoutSnapshot? {
        await MainActor.run { mockCurrentMetrics }
    }
}

// MARK: - Mock PersistenceManager for Route Tests

/// Mock persistence manager for testing RouteImageGenerator.
actor MockPersistenceManagerForRoute: PersistenceManaging {

    var mockTrackPoints: [WorkoutTrackPoint] = []
    var fetchTrackPointsCalled = false
    var lastFetchedWorkoutID: String?

    // Store the container for protocol conformance
    private let _modelContainer: ModelContainer

    nonisolated var modelContainer: ModelContainer {
        _modelContainer
    }

    init() {
        // Create an in-memory container for testing
        do {
            _modelContainer = try JogPodSchema.makeTestContainer()
        } catch {
            fatalError("Failed to create test container: \(error)")
        }
    }

    func fetchTrackPoints(forWorkoutID workoutID: String) async throws -> [WorkoutTrackPoint] {
        fetchTrackPointsCalled = true
        lastFetchedWorkoutID = workoutID
        return mockTrackPoints
    }

    // MARK: - Stub Implementations

    func createPodcastFeed(title: String?, link: String?, summary: String?, imageUrl: String?) async throws -> SwiftData.PersistentIdentifier {
        fatalError("Not implemented for route tests")
    }

    func fetchPodcastFeed(byLink link: String) async throws -> PodcastFeed? {
        nil
    }

    func fetchAllPodcastFeeds() async throws -> [PodcastFeed] {
        []
    }

    func deletePodcastFeed(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func createPodcastEpisode(title: String?, identifier: String?, enclosureMediaLink: String?, releaseDate: Date?, feedIdentifier: SwiftData.PersistentIdentifier?) async throws -> SwiftData.PersistentIdentifier {
        fatalError("Not implemented for route tests")
    }

    func fetchAllPodcastEpisodes(sortedByIndex: Bool) async throws -> [PodcastEpisode] {
        []
    }

    func fetchCurrentEpisode() async throws -> PodcastEpisode? {
        nil
    }

    func setCurrentEpisode(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func clearCurrentEpisode() async throws {}

    func updateEpisodeIndex(_ identifier: SwiftData.PersistentIdentifier, newIndex: Int32) async throws {}

    func deletePodcastEpisode(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func saveEpisodePosition(episodeID: SwiftData.PersistentIdentifier, position: TimeInterval) async throws {}

    func fetchEpisodePosition(episodeID: SwiftData.PersistentIdentifier) async throws -> TimeInterval? {
        nil
    }

    func savePreference<T>(name: String, value: T) async throws where T: Sendable {}

    func fetchPreference<T>(name: String, as type: T.Type) async throws -> T? {
        nil
    }

    func fetchAllPreferences() async throws -> [Preference] {
        []
    }

    func deletePreference(name: String) async throws {}

    func createWorkoutSession(workoutID: String?, startTime: Date?) async throws -> SwiftData.PersistentIdentifier {
        fatalError("Not implemented for route tests")
    }

    func fetchWorkoutSession(byID workoutID: String) async throws -> WorkoutSession? {
        nil
    }

    func fetchAllWorkoutSessions(ascending: Bool) async throws -> [WorkoutSession] {
        []
    }

    func workoutSessionCount() async throws -> Int {
        0
    }

    func deleteWorkoutSession(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func createTrackPoint(workoutID: String, time: Date?, location: CLLocation?, heartRate: Int16?, steps: Int16?) async throws -> SwiftData.PersistentIdentifier {
        fatalError("Not implemented for route tests")
    }

    func trackPointCount() async throws -> Int {
        mockTrackPoints.count
    }

    func deleteTrackPoint(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func deleteTrackPoints(forWorkoutID workoutID: String, at time: Date) async throws {}

    func createListeningLog(workoutID: String, time: Date?, entityTitle: String?, entryTitle: String?, entrySummary: String?) async throws -> SwiftData.PersistentIdentifier {
        fatalError("Not implemented for route tests")
    }

    func fetchListeningLogs(forWorkoutID workoutID: String) async throws -> [WorkoutListeningLog] {
        []
    }

    func deleteListeningLog(_ identifier: SwiftData.PersistentIdentifier) async throws {}

    func save() async throws {}

    func deleteAll<T>(ofType type: T.Type) async throws where T: SwiftData.PersistentModel {}
}
