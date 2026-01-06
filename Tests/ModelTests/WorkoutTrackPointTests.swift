import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import JogPod

/// Tests for the WorkoutTrackPoint SwiftData model.
@Suite("WorkoutTrackPoint Model Tests")
@MainActor
struct WorkoutTrackPointTests {

    // MARK: - Setup

    private func makeTestContainer() throws -> ModelContainer {
        try JogPodSchema.makeTestContainer()
    }

    // MARK: - Initialization Tests

    @Test("WorkoutTrackPoint initializes with workoutID")
    func testBasicInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)
        try context.save()

        #expect(point.workoutID == "workout-123")
        #expect(point.time == nil)
        #expect(point.heartRate == nil)
        #expect(point.steps == nil)
        #expect(point.latitude == nil)
        #expect(point.longitude == nil)
    }

    @Test("WorkoutTrackPoint initializes with CLLocation")
    func testInitWithLocation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),
            altitude: 105.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            course: 90.0,
            speed: 3.5,
            timestamp: now
        )

        let point = WorkoutTrackPoint(
            workoutID: "workout-123",
            time: now,
            location: location,
            heartRate: 145,
            steps: 1000
        )
        context.insert(point)
        try context.save()

        #expect(point.latitude == 47.4979)
        #expect(point.longitude == 19.0402)
        #expect(point.altitude == 105.0)
        #expect(point.horizontalAccuracy == 5.0)
        #expect(point.course == 90.0)
        #expect(point.speed == 3.5)
        #expect(point.heartRate == 145)
        #expect(point.steps == 1000)
    }

    // MARK: - Location Handling Tests

    @Test("setLocation extracts all CLLocation properties")
    func testSetLocation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 10.0,
            horizontalAccuracy: 3.0,
            verticalAccuracy: 5.0,
            course: 180.0,
            speed: 5.0,
            timestamp: Date()
        )

        point.setLocation(location)

        #expect(point.latitude == 40.7128)
        #expect(point.longitude == -74.0060)
        #expect(point.altitude == 10.0)
        #expect(point.horizontalAccuracy == 3.0)
        #expect(point.speed == 5.0)
        #expect(point.course == 180.0)
    }

    @Test("setLocation handles invalid speed and course")
    func testSetLocationInvalidValues() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)

        // CLLocation uses -1 for invalid speed/course
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            altitude: 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: Date()
        )

        point.setLocation(location)

        #expect(point.speed == nil)
        #expect(point.course == nil)
    }

    @Test("clLocation reconstructs CLLocation from stored values")
    func testCLLocationReconstruction() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let point = WorkoutTrackPoint(workoutID: "workout-123", time: now)
        point.latitude = 51.5074
        point.longitude = -0.1278
        point.altitude = 20.0
        point.horizontalAccuracy = 5.0
        point.speed = 4.0
        point.course = 45.0
        context.insert(point)

        let reconstructed = point.clLocation

        #expect(reconstructed != nil)
        #expect(reconstructed?.coordinate.latitude == 51.5074)
        #expect(reconstructed?.coordinate.longitude == -0.1278)
        #expect(reconstructed?.altitude == 20.0)
        #expect(reconstructed?.horizontalAccuracy == 5.0)
        #expect(reconstructed?.speed == 4.0)
        #expect(reconstructed?.course == 45.0)
    }

    @Test("clLocation returns nil when coordinates missing")
    func testCLLocationNil() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)

        #expect(point.clLocation == nil)

        point.latitude = 51.5074
        #expect(point.clLocation == nil)  // Still nil, need both
    }

    @Test("coordinate returns CLLocationCoordinate2D")
    func testCoordinateProperty() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        point.latitude = 47.4979
        point.longitude = 19.0402
        context.insert(point)

        let coord = point.coordinate
        #expect(coord?.latitude == 47.4979)
        #expect(coord?.longitude == 19.0402)
    }

    @Test("hasValidLocation checks for both coordinates")
    func testHasValidLocation() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)
        #expect(point.hasValidLocation == false)

        point.latitude = 47.0
        #expect(point.hasValidLocation == false)

        point.longitude = 19.0
        #expect(point.hasValidLocation == true)
    }

    // MARK: - Speed Conversion Tests

    @Test("speedInKmh converts correctly")
    func testSpeedInKmh() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)

        #expect(point.speedInKmh == nil)

        point.speed = 1.0  // 1 m/s
        #expect(point.speedInKmh == 3.6)

        point.speed = 10.0  // 10 m/s
        #expect(point.speedInKmh == 36.0)
    }

    @Test("speedInMph converts correctly")
    func testSpeedInMph() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point = WorkoutTrackPoint(workoutID: "workout-123")
        context.insert(point)

        #expect(point.speedInMph == nil)

        point.speed = 1.0  // 1 m/s
        let mph = point.speedInMph ?? 0
        #expect(abs(mph - 2.23694) < 0.0001)
    }

    // MARK: - Fetch Descriptor Tests

    @Test("fetchDescriptor returns chronologically sorted points")
    func testChronologicalFetch() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let workoutID = "workout-123"

        let point1 = WorkoutTrackPoint(workoutID: workoutID, time: now)
        let point2 = WorkoutTrackPoint(workoutID: workoutID, time: now.addingTimeInterval(-60))
        let point3 = WorkoutTrackPoint(workoutID: workoutID, time: now.addingTimeInterval(-30))

        context.insert(point1)
        context.insert(point2)
        context.insert(point3)
        try context.save()

        let descriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: workoutID)
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].time == now.addingTimeInterval(-60))
        #expect(results[1].time == now.addingTimeInterval(-30))
        #expect(results[2].time == now)
    }

    @Test("fetchDescriptor filters by workoutID")
    func testFilterByWorkoutID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let point1 = WorkoutTrackPoint(workoutID: "workout-1", time: Date())
        let point2 = WorkoutTrackPoint(workoutID: "workout-2", time: Date())
        let point3 = WorkoutTrackPoint(workoutID: "workout-1", time: Date())

        context.insert(point1)
        context.insert(point2)
        context.insert(point3)
        try context.save()

        let descriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: "workout-1")
        let results = try context.fetch(descriptor)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.workoutID == "workout-1" })
    }

    // MARK: - All Attributes Test

    @Test("All WorkoutLocation attributes are preserved")
    func testAllAttributes() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let point = WorkoutTrackPoint(workoutID: "test-workout", time: now)
        point.heartRate = 160
        point.steps = 5000
        point.latitude = 47.4979
        point.longitude = 19.0402
        point.altitude = 100.0
        point.horizontalAccuracy = 5.0
        point.speed = 3.0
        point.course = 270.0

        context.insert(point)
        try context.save()

        let descriptor = WorkoutTrackPoint.fetchDescriptor(forWorkoutID: "test-workout")
        let fetched = try context.fetch(descriptor).first

        #expect(fetched?.workoutID == "test-workout")
        #expect(fetched?.time == now)
        #expect(fetched?.heartRate == 160)
        #expect(fetched?.steps == 5000)
        #expect(fetched?.latitude == 47.4979)
        #expect(fetched?.longitude == 19.0402)
        #expect(fetched?.altitude == 100.0)
        #expect(fetched?.horizontalAccuracy == 5.0)
        #expect(fetched?.speed == 3.0)
        #expect(fetched?.course == 270.0)
    }
}
