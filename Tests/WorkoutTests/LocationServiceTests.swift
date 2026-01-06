//
//  LocationServiceTests.swift
//  JogPod Tests
//
//  Tests for LocationService and MockLocationService.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - MockLocationService Tests

@Suite("MockLocationService")
struct MockLocationServiceTests {

    // MARK: - Initialization

    @Test("initializes with default values")
    func initializesWithDefaults() async {
        let service = MockLocationService()

        #expect(await service.authorizationStatus == .authorizedAlways)
        #expect(service.isLocationServicesEnabled == true)
    }

    @Test("initializes with custom authorization status")
    func initializesWithCustomStatus() async {
        let service = MockLocationService(authorizationStatus: .denied)

        #expect(await service.authorizationStatus == .denied)
    }

    @Test("initializes with location services disabled")
    func initializesWithDisabledServices() {
        let service = MockLocationService(locationServicesEnabled: false)

        #expect(service.isLocationServicesEnabled == false)
    }

    @Test("initializes with mock locations")
    func initializesWithMockLocations() async throws {
        let locations = [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7759, longitude: -122.4194)
        ]

        let service = MockLocationService(locations: locations)

        let stream = try await service.startLocationUpdates(
            desiredAccuracy: kCLLocationAccuracyBest,
            distanceFilter: 10
        )

        var receivedLocations: [CLLocation] = []
        for await location in stream {
            receivedLocations.append(location)
        }

        #expect(receivedLocations.count == 2)
    }

    // MARK: - Authorization

    @Test("requestAuthorization succeeds when enabled")
    func requestAuthorizationSucceeds() async throws {
        let service = MockLocationService(authorizationStatus: .notDetermined)

        try await service.requestAuthorization()

        #expect(await service.authorizationStatus == .authorizedAlways)
    }

    @Test("requestAuthorization throws when services disabled")
    func requestAuthorizationThrowsWhenDisabled() async {
        let service = MockLocationService(locationServicesEnabled: false)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationServicesUnavailable)
        }
    }

    @Test("requestAuthorization throws when denied")
    func requestAuthorizationThrowsWhenDenied() async {
        let service = MockLocationService(authorizationStatus: .denied)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationAuthorizationDenied)
        }
    }

    @Test("requestAuthorization throws when restricted")
    func requestAuthorizationThrowsWhenRestricted() async {
        let service = MockLocationService(authorizationStatus: .restricted)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationAuthorizationRestricted)
        }
    }

    @Test("requestAuthorization throws when configured to fail")
    func requestAuthorizationThrowsWhenConfigured() async {
        let service = MockLocationService()
        service.setShouldFailAuthorization(true)

        do {
            try await service.requestAuthorization()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationAuthorizationDenied)
        }
    }

    // MARK: - Location Updates

    @Test("startLocationUpdates returns stream of locations")
    func startLocationUpdatesReturnsStream() async throws {
        let locations = [
            CLLocation(latitude: 37.7749, longitude: -122.4194),
            CLLocation(latitude: 37.7759, longitude: -122.4194),
            CLLocation(latitude: 37.7769, longitude: -122.4194)
        ]

        let service = MockLocationService(locations: locations)

        let stream = try await service.startLocationUpdates(
            desiredAccuracy: kCLLocationAccuracyBest,
            distanceFilter: 10
        )

        var receivedCount = 0
        for await _ in stream {
            receivedCount += 1
        }

        #expect(receivedCount == 3)
    }

    @Test("startLocationUpdates throws when not authorized")
    func startLocationUpdatesThrowsWhenNotAuthorized() async {
        let service = MockLocationService(authorizationStatus: .denied)

        do {
            _ = try await service.startLocationUpdates(
                desiredAccuracy: kCLLocationAccuracyBest,
                distanceFilter: 10
            )
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationAuthorizationDenied)
        }
    }

    @Test("startLocationUpdates throws when services disabled")
    func startLocationUpdatesThrowsWhenDisabled() async {
        let service = MockLocationService(locationServicesEnabled: false)

        do {
            _ = try await service.startLocationUpdates(
                desiredAccuracy: kCLLocationAccuracyBest,
                distanceFilter: 10
            )
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error as? WorkoutError == .locationServicesUnavailable)
        }
    }

    // MARK: - Configuration

    @Test("setMockLocations updates locations")
    func setMockLocationsUpdates() async throws {
        let service = MockLocationService()

        service.setMockLocations([
            CLLocation(latitude: 1.0, longitude: 1.0)
        ])

        let stream = try await service.startLocationUpdates(
            desiredAccuracy: kCLLocationAccuracyBest,
            distanceFilter: 10
        )

        var receivedLocations: [CLLocation] = []
        for await location in stream {
            receivedLocations.append(location)
        }

        #expect(receivedLocations.count == 1)
        #expect(receivedLocations[0].coordinate.latitude == 1.0)
    }

    @Test("setMockAuthorizationStatus updates status")
    func setMockAuthorizationStatusUpdates() async {
        let service = MockLocationService(authorizationStatus: .authorizedAlways)

        service.setMockAuthorizationStatus(.denied)

        #expect(await service.authorizationStatus == .denied)
    }

    // MARK: - Stop Updates

    @Test("stopLocationUpdates completes without error")
    func stopLocationUpdatesCompletes() async {
        let service = MockLocationService()

        // Should not throw
        await service.stopLocationUpdates()
    }
}

// MARK: - CLLocation Extension Tests

@Suite("CLLocation Test Extensions")
struct CLLocationExtensionTests {

    @Test("makeTestLocation creates location with specified coordinates")
    func makeTestLocationCoordinates() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )

        #expect(location.coordinate.latitude == 37.7749)
        #expect(location.coordinate.longitude == -122.4194)
    }

    @Test("makeTestLocation creates location with altitude")
    func makeTestLocationAltitude() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100
        )

        #expect(location.altitude == 100)
    }

    @Test("makeTestLocation creates location with speed")
    func makeTestLocationSpeed() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            speed: 5.0
        )

        #expect(location.speed == 5.0)
    }

    @Test("makeTestLocation creates location with course")
    func makeTestLocationCourse() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            course: 90.0
        )

        #expect(location.course == 90.0)
    }

    @Test("makeTestLocation creates location with accuracy")
    func makeTestLocationAccuracy() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            horizontalAccuracy: 5.0
        )

        #expect(location.horizontalAccuracy == 5.0)
    }

    @Test("makeTestLocation creates location with timestamp")
    func makeTestLocationTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 1000)
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: timestamp
        )

        #expect(location.timestamp == timestamp)
    }

    @Test("makeTestLocation has reasonable defaults")
    func makeTestLocationDefaults() {
        let location = CLLocation.makeTestLocation(
            latitude: 37.7749,
            longitude: -122.4194
        )

        #expect(location.altitude == 0)
        #expect(location.speed == 0)
        #expect(location.horizontalAccuracy == 10)
    }
}
