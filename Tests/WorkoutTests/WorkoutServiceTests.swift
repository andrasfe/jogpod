//
//  WorkoutServiceTests.swift
//  JogPod Tests
//
//  Tests for WorkoutService actor.
//

import Testing
import Foundation
import CoreLocation
import HealthKit
@testable import JogPod

// MARK: - WorkoutService Tests

@Suite("WorkoutService")
struct WorkoutServiceTests {

    // MARK: - Helper Methods

    private func makeMockPersistence() throws -> PersistenceManager {
        try PersistenceManager.makeForTesting()
    }

    private func makeMockLocationService(
        locations: [CLLocation] = [],
        authorizationStatus: CLAuthorizationStatus = .authorizedAlways
    ) -> MockLocationService {
        MockLocationService(
            authorizationStatus: authorizationStatus,
            locationServicesEnabled: true,
            locations: locations
        )
    }

    private func makeWorkoutService(
        locations: [CLLocation] = [],
        authorizationStatus: CLAuthorizationStatus = .authorizedAlways,
        healthKitService: HealthKitServiceProtocol? = nil
    ) async throws -> WorkoutService {
        let persistence = try makeMockPersistence()
        let locationService = makeMockLocationService(
            locations: locations,
            authorizationStatus: authorizationStatus
        )

        return WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService,
            healthKitService: healthKitService
        )
    }

    // MARK: - Initialization State

    @Test("initializes in idle state")
    func initializesInIdleState() async throws {
        let service = try await makeWorkoutService()

        #expect(await service.state == .idle)
        #expect(await service.activeWorkoutID == nil)
        #expect(await service.isWorkoutInProgress == false)
    }

    // MARK: - Start Workout

    @Test("startWorkout returns workout ID")
    func startWorkoutReturnsID() async throws {
        let service = try await makeWorkoutService()

        let workoutID = try await service.startWorkout()

        #expect(!workoutID.isEmpty)
        #expect(UUID(uuidString: workoutID) != nil)
    }

    @Test("startWorkout changes state to active")
    func startWorkoutChangesState() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        #expect(await service.state == .active)
        #expect(await service.isWorkoutInProgress == true)
    }

    @Test("startWorkout sets activeWorkoutID")
    func startWorkoutSetsActiveID() async throws {
        let service = try await makeWorkoutService()

        let workoutID = try await service.startWorkout()

        #expect(await service.activeWorkoutID == workoutID)
    }

    @Test("startWorkout throws when workout already in progress")
    func startWorkoutThrowsWhenInProgress() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        do {
            _ = try await service.startWorkout()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .workoutAlreadyInProgress)
        }
    }

    @Test("startWorkout creates workout session in persistence")
    func startWorkoutCreatesSession() async throws {
        let persistence = try makeMockPersistence()
        let locationService = makeMockLocationService()

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService
        )

        let workoutID = try await service.startWorkout()

        // Verify session was created
        let session = try await persistence.fetchWorkoutSession(byID: workoutID)
        #expect(session != nil)
        #expect(session?.workoutID == workoutID)
        #expect(session?.startTime != nil)
    }

    // MARK: - Stop Workout

    @Test("stopWorkout changes state to idle")
    func stopWorkoutChangesState() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()
        try await service.stopWorkout()

        #expect(await service.state == .idle)
        #expect(await service.isWorkoutInProgress == false)
    }

    @Test("stopWorkout clears activeWorkoutID")
    func stopWorkoutClearsActiveID() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()
        try await service.stopWorkout()

        #expect(await service.activeWorkoutID == nil)
    }

    @Test("stopWorkout throws when no workout in progress")
    func stopWorkoutThrowsWhenNoWorkout() async throws {
        let service = try await makeWorkoutService()

        do {
            try await service.stopWorkout()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .noActiveWorkout)
        }
    }

    // MARK: - Location Updates

    @Test("workout receives location updates")
    func workoutReceivesLocationUpdates() async throws {
        let locations = [
            CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194),
            CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4194)
        ]

        let service = try await makeWorkoutService(locations: locations)

        _ = try await service.startWorkout()

        // Wait for location updates to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let location = await service.currentLocation
        #expect(location != nil)
    }

    @Test("workout ignores first location reading (cold-start filter)")
    func workoutIgnoresFirstLocation() async throws {
        let persistence = try makeMockPersistence()

        // Create locations - first should be ignored
        let locations = [
            CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194), // Ignored
            CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4194), // Recorded
        ]

        let locationService = makeMockLocationService(locations: locations)

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService
        )

        let workoutID = try await service.startWorkout()

        // Wait for location updates to be processed
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        try await service.stopWorkout()

        // Should only have 1 track point (first was ignored)
        let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)
        #expect(trackPoints.count == 1)
    }

    // MARK: - Heart Rate Updates

    @Test("updateHeartRate records heart rate")
    func updateHeartRateRecords() async throws {
        let persistence = try makeMockPersistence()
        let locationService = makeMockLocationService()

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService
        )

        _ = try await service.startWorkout()

        await service.updateHeartRate(120)

        // Wait for processing
        try await Task.sleep(nanoseconds: 50_000_000)

        let metrics = await service.currentMetrics()
        #expect(metrics?.currentHeartRate == 120)
    }

    @Test("updateHeartRate is ignored when no workout active")
    func updateHeartRateIgnoredWhenNoWorkout() async throws {
        let service = try await makeWorkoutService()

        // Should not throw, just be ignored
        await service.updateHeartRate(120)

        let metrics = await service.currentMetrics()
        #expect(metrics == nil)
    }

    // MARK: - Steps Updates

    @Test("updateSteps records step count")
    func updateStepsRecords() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        await service.updateSteps(1000)

        // Wait for processing
        try await Task.sleep(nanoseconds: 50_000_000)

        let metrics = await service.currentMetrics()
        #expect(metrics?.totalSteps == 1000)
    }

    @Test("updateSteps is ignored when no workout active")
    func updateStepsIgnoredWhenNoWorkout() async throws {
        let service = try await makeWorkoutService()

        // Should not throw, just be ignored
        await service.updateSteps(1000)

        let metrics = await service.currentMetrics()
        #expect(metrics == nil)
    }

    // MARK: - Metrics

    @Test("currentMetrics returns nil when no workout")
    func currentMetricsNilWhenNoWorkout() async throws {
        let service = try await makeWorkoutService()

        let metrics = await service.currentMetrics()

        #expect(metrics == nil)
    }

    @Test("currentMetrics returns snapshot during workout")
    func currentMetricsReturnsSnapshotDuringWorkout() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        let metrics = await service.currentMetrics()

        #expect(metrics != nil)
    }

    // MARK: - Authorization

    @Test("requestAuthorization delegates to location service")
    func requestAuthorizationDelegates() async throws {
        let service = try await makeWorkoutService(authorizationStatus: .notDetermined)

        // Should not throw for notDetermined -> authorizedAlways transition
        try await service.requestAuthorization()
    }

    @Test("requestAuthorization throws when denied")
    func requestAuthorizationThrowsWhenDenied() async throws {
        let service = try await makeWorkoutService(authorizationStatus: .denied)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationAuthorizationDenied)
        }
    }

    // MARK: - Batch Size Constants

    @Test("batch sizes match legacy behavior")
    func batchSizesMatchLegacy() {
        // Legacy code used batch size of 20 for both location and HR
        #expect(WorkoutService.locationBatchSize == 20)
        #expect(WorkoutService.heartRateBatchSize == 20)
    }

    @Test("readings to ignore matches legacy cold-start filter")
    func readingsToIgnoreMatchesLegacy() {
        // Legacy code ignored first 1 reading
        #expect(WorkoutService.readingsToIgnore == 1)
    }

    // MARK: - Thread Safety

    @Test("concurrent state access is safe")
    func concurrentStateAccessIsSafe() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        // Access state from multiple concurrent tasks
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await service.isWorkoutInProgress
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            #expect(results.allSatisfy { $0 == true })
        }
    }

    @Test("concurrent updates are serialized")
    func concurrentUpdatesAreSerialized() async throws {
        let service = try await makeWorkoutService()

        _ = try await service.startWorkout()

        // Send multiple updates concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await service.updateHeartRate(100 + i)
                }
                group.addTask {
                    await service.updateSteps(i * 100)
                }
            }
        }

        // Service should not crash and metrics should be available
        let metrics = await service.currentMetrics()
        #expect(metrics != nil)
    }

    // MARK: - HealthKit Integration

    @Test("stopWorkout syncs to HealthKit when service is available")
    func stopWorkoutSyncsToHealthKit() async throws {
        let mockHealthKit = MockHealthKitService()
        let persistence = try makeMockPersistence()
        let locations = [
            CLLocation.makeTestLocation(latitude: 37.7749, longitude: -122.4194, timestamp: Date().addingTimeInterval(-60)),
            CLLocation.makeTestLocation(latitude: 37.7759, longitude: -122.4184, timestamp: Date().addingTimeInterval(-30)),
            CLLocation.makeTestLocation(latitude: 37.7769, longitude: -122.4174, timestamp: Date())
        ]
        let locationService = makeMockLocationService(locations: locations)

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService,
            healthKitService: mockHealthKit
        )

        _ = try await service.startWorkout()

        // Wait for location updates to be processed
        try await Task.sleep(nanoseconds: 200_000_000)

        try await service.stopWorkout()

        // Verify HealthKit sync was attempted
        let savedWorkouts = await mockHealthKit.savedWorkouts
        #expect(savedWorkouts.count == 1)
        #expect(savedWorkouts.first?.activityType == .running)
    }

    @Test("stopWorkout does not fail when HealthKit sync fails")
    func stopWorkoutHandlesHealthKitError() async throws {
        let mockHealthKit = MockHealthKitService()
        await mockHealthKit.setWorkoutSaveError(.workoutSaveFailed("Test error"))

        let service = try await makeWorkoutService(healthKitService: mockHealthKit)

        _ = try await service.startWorkout()

        // Should not throw even though HealthKit will fail
        try await service.stopWorkout()

        // Workout should still be stopped successfully
        #expect(await service.state == .idle)
    }

    @Test("stopWorkout skips HealthKit sync when service is nil")
    func stopWorkoutSkipsHealthKitWhenNil() async throws {
        let service = try await makeWorkoutService(healthKitService: nil)

        _ = try await service.startWorkout()

        // Should complete without error
        try await service.stopWorkout()

        #expect(await service.state == .idle)
    }

    @Test("stopWorkout includes route data in HealthKit sync")
    func stopWorkoutIncludesRouteData() async throws {
        let mockHealthKit = MockHealthKitService()
        let persistence = try makeMockPersistence()

        // Create locations with timestamps
        let baseTime = Date()
        let locations = [
            CLLocation.makeTestLocation(
                latitude: 37.7749,
                longitude: -122.4194,
                altitude: 10,
                speed: 3.0,
                horizontalAccuracy: 5,
                timestamp: baseTime.addingTimeInterval(-120)
            ),
            CLLocation.makeTestLocation(
                latitude: 37.7759,
                longitude: -122.4184,
                altitude: 15,
                speed: 3.5,
                horizontalAccuracy: 5,
                timestamp: baseTime.addingTimeInterval(-60)
            ),
            CLLocation.makeTestLocation(
                latitude: 37.7769,
                longitude: -122.4174,
                altitude: 20,
                speed: 3.0,
                horizontalAccuracy: 5,
                timestamp: baseTime
            )
        ]
        let locationService = makeMockLocationService(locations: locations)

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService,
            healthKitService: mockHealthKit
        )

        _ = try await service.startWorkout()

        // Wait for location updates to be processed
        try await Task.sleep(nanoseconds: 300_000_000)

        try await service.stopWorkout()

        // Verify route points were included (minus cold-start filtered locations)
        let savedWorkouts = await mockHealthKit.savedWorkouts
        #expect(savedWorkouts.count == 1)

        // Route should have at least 1 point (after cold-start filter removes first)
        let routePoints = savedWorkouts.first?.routePoints ?? []
        #expect(routePoints.count >= 1)
    }

    @Test("stopWorkout includes heart rate samples in HealthKit sync")
    func stopWorkoutIncludesHeartRateSamples() async throws {
        let mockHealthKit = MockHealthKitService()
        let persistence = try makeMockPersistence()
        let locationService = makeMockLocationService()

        let service = WorkoutService.makeForTesting(
            persistence: persistence,
            locationService: locationService,
            healthKitService: mockHealthKit
        )

        _ = try await service.startWorkout()

        // Add heart rate updates
        await service.updateHeartRate(120)
        try await Task.sleep(nanoseconds: 50_000_000)
        await service.updateHeartRate(130)
        try await Task.sleep(nanoseconds: 50_000_000)
        await service.updateHeartRate(125)

        try await service.stopWorkout()

        // Verify heart rate samples were included
        let savedWorkouts = await mockHealthKit.savedWorkouts
        #expect(savedWorkouts.count == 1)

        let heartRateSamples = savedWorkouts.first?.heartRateSamples ?? []
        #expect(heartRateSamples.count >= 1)
    }
}

// MARK: - WorkoutServiceObserver Tests

@Suite("WorkoutServiceObserver")
@MainActor
struct WorkoutServiceObserverTests {

    @Test("initializes with default state")
    func initializesWithDefaultState() {
        let observer = WorkoutServiceObserver()

        #expect(observer.isWorkoutActive == false)
        #expect(observer.currentSnapshot == .empty)
        #expect(observer.currentLocation == nil)
    }
}

// MARK: - WorkoutSummary Tests

@Suite("WorkoutSummary")
struct WorkoutSummaryTests {

    @Test("briefSummary formats correctly")
    func briefSummaryFormats() {
        let snapshot = WorkoutSnapshot(
            totalDistance: 5000, // 5 km
            duration: 1800, // 30 minutes
            currentSpeed: 2.78,
            averageSpeed: 2.78,
            maxSpeed: 3.5,
            minSpeed: 2.0,
            totalElevationGain: 50,
            totalElevationLoss: 30,
            currentElevation: 100,
            currentHeartRate: 140,
            averageHeartRate: 135,
            maxHeartRate: 160,
            minHeartRate: 90,
            totalSteps: 6000,
            caloriesBurned: 350,
            isAtPeakSpeed: false,
            gpsSignalLevel: .excellent,
            pacePerKilometer: 6.0,
            pacePerMile: 9.66,
            averageStepLength: 0.83
        )

        let summary = WorkoutSummary(
            workoutID: "test-id",
            metrics: snapshot,
            startTime: Date(),
            endTime: Date()
        )

        #expect(summary.briefSummary.contains("5.00"))
        #expect(summary.briefSummary.contains("km"))
        #expect(summary.briefSummary.contains("350"))
    }

    @Test("WorkoutSummary is equatable")
    func summaryEquality() {
        let snapshot = WorkoutSnapshot.empty
        let now = Date()

        let summary1 = WorkoutSummary(
            workoutID: "id",
            metrics: snapshot,
            startTime: now,
            endTime: now
        )

        let summary2 = WorkoutSummary(
            workoutID: "id",
            metrics: snapshot,
            startTime: now,
            endTime: now
        )

        #expect(summary1 == summary2)
    }
}

// MARK: - Notification Tests

@Suite("Workout Notifications")
struct WorkoutNotificationTests {

    @Test("notification names are defined correctly")
    func notificationNamesDefinedCorrectly() {
        #expect(Notification.Name.workoutStatusChanged.rawValue == "workoutStatusChanged")
        #expect(Notification.Name.workoutUpdatesAvailable.rawValue == "workoutUpdatesAvailable")
        #expect(Notification.Name.locationUpdate.rawValue == "locationUpdate")
    }
}
