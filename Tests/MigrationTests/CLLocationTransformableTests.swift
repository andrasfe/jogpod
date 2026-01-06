import XCTest
import CoreData
import CoreLocation
@testable import JogPod

/// Tests for CLLocation Transformable type handling during Core Data to SwiftData migration.
///
/// These tests verify that the migration correctly handles:
/// - Legacy archived CLLocation data (iOS 7-11 era)
/// - Securely archived CLLocation data (iOS 12+)
/// - Edge cases like nil locations and corrupted data
final class CLLocationTransformableTests: XCTestCase {

    // MARK: - Properties

    private var tempDirectory: URL!
    private var testStoreURL: URL!

    // MARK: - Setup/Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CLLocationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        testStoreURL = tempDirectory.appendingPathComponent("CLLocationTest.sqlite")

        // Register the custom transformer
        CLLocationValueTransformer.register()
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    // MARK: - Value Transformer Tests

    func testCLLocationValueTransformerRegistration() {
        CLLocationValueTransformer.register()

        let transformer = ValueTransformer(forName: CLLocationValueTransformer.transformerName)
        XCTAssertNotNil(transformer)
        XCTAssertTrue(transformer is CLLocationValueTransformer)
    }

    func testCLLocationValueTransformerRoundTrip() {
        let transformer = CLLocationValueTransformer()

        let originalLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 10.0,
            course: 90.0,
            speed: 2.5,
            timestamp: Date()
        )

        // Transform to data
        let data = transformer.transformedValue(originalLocation)
        XCTAssertNotNil(data)
        XCTAssertTrue(data is Data)

        // Reverse transform back to location
        let recoveredLocation = transformer.reverseTransformedValue(data)
        XCTAssertNotNil(recoveredLocation)

        guard let location = recoveredLocation as? CLLocation else {
            XCTFail("Expected CLLocation type")
            return
        }

        XCTAssertEqual(location.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(location.altitude, 10.0, accuracy: 0.1)
        XCTAssertEqual(location.horizontalAccuracy, 5.0, accuracy: 0.1)
        XCTAssertEqual(location.course, 90.0, accuracy: 0.1)
        XCTAssertEqual(location.speed, 2.5, accuracy: 0.1)
    }

    func testCLLocationValueTransformerHandlesNil() {
        let transformer = CLLocationValueTransformer()

        let transformedNil = transformer.transformedValue(nil)
        XCTAssertNil(transformedNil)

        let reversedNil = transformer.reverseTransformedValue(nil)
        XCTAssertNil(reversedNil)
    }

    func testCLLocationValueTransformerHandlesInvalidData() {
        let transformer = CLLocationValueTransformer()

        // Random garbage data
        let invalidData = "This is not a valid archive".data(using: .utf8)!
        let result = transformer.reverseTransformedValue(invalidData)
        XCTAssertNil(result)

        // Empty data
        let emptyData = Data()
        let emptyResult = transformer.reverseTransformedValue(emptyData)
        XCTAssertNil(emptyResult)
    }

    func testCLLocationValueTransformerHandlesLegacySecureArchive() throws {
        let transformer = CLLocationValueTransformer()

        let location = CLLocation(latitude: 51.5074, longitude: -0.1278)

        // Create data using secure archiving (iOS 12+ format)
        let secureData = try NSKeyedArchiver.archivedData(
            withRootObject: location,
            requiringSecureCoding: true
        )

        let recovered = transformer.reverseTransformedValue(secureData)
        XCTAssertNotNil(recovered)

        guard let recoveredLocation = recovered as? CLLocation else {
            XCTFail("Expected CLLocation")
            return
        }

        XCTAssertEqual(recoveredLocation.coordinate.latitude, 51.5074, accuracy: 0.0001)
        XCTAssertEqual(recoveredLocation.coordinate.longitude, -0.1278, accuracy: 0.0001)
    }

    func testCLLocationValueTransformerHandlesNonSecureArchive() throws {
        let transformer = CLLocationValueTransformer()

        let location = CLLocation(latitude: 48.8566, longitude: 2.3522)

        // Create data using non-secure archiving (legacy format)
        let nonSecureData = try NSKeyedArchiver.archivedData(
            withRootObject: location,
            requiringSecureCoding: false
        )

        let recovered = transformer.reverseTransformedValue(nonSecureData)
        XCTAssertNotNil(recovered)

        guard let recoveredLocation = recovered as? CLLocation else {
            XCTFail("Expected CLLocation")
            return
        }

        XCTAssertEqual(recoveredLocation.coordinate.latitude, 48.8566, accuracy: 0.0001)
        XCTAssertEqual(recoveredLocation.coordinate.longitude, 2.3522, accuracy: 0.0001)
    }

    // MARK: - Core Data Integration Tests

    func testImportTrackPointsWithCLLocation() async throws {
        // Create test store with CLLocation data
        let context = try createTestCoreDataStore()

        let workoutID = "workout-location-test"

        // Create workout session
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(workoutID, forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        // Create track points with CLLocation
        let locations: [(Double, Double)] = [
            (37.7749, -122.4194),  // San Francisco
            (37.7750, -122.4180),
            (37.7752, -122.4165),
            (37.7755, -122.4150),
            (37.7758, -122.4135)
        ]

        for (index, coords) in locations.enumerated() {
            let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
            trackPoint.setValue(workoutID, forKey: "workoutID")
            trackPoint.setValue(Date().addingTimeInterval(Double(index) * 60), forKey: "time")
            trackPoint.setValue(Int16(120 + index), forKey: "heartRate")
            trackPoint.setValue(Int16(100 + index * 10), forKey: "steps")

            // Store CLLocation in transformable
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: coords.0, longitude: coords.1),
                altitude: 10.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                course: Double(index * 10),
                speed: 2.5 + Double(index) * 0.1,
                timestamp: Date()
            )
            trackPoint.setValue(location, forKey: "location")
        }

        try context.save()

        // Import using CoreDataImporter
        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        // Verify track points were imported with location data
        XCTAssertEqual(data.trackPoints.count, 5)

        for (index, trackPoint) in data.trackPoints.enumerated() {
            XCTAssertEqual(trackPoint.workoutID, workoutID)
            XCTAssertEqual(trackPoint.heartRate, Int16(120 + index))
            XCTAssertEqual(trackPoint.steps, Int16(100 + index * 10))

            // Verify coordinates were extracted
            XCTAssertNotNil(trackPoint.latitude)
            XCTAssertNotNil(trackPoint.longitude)

            if let lat = trackPoint.latitude, let long = trackPoint.longitude {
                XCTAssertEqual(lat, locations[index].0, accuracy: 0.0001)
                XCTAssertEqual(long, locations[index].1, accuracy: 0.0001)
            }

            // Verify additional location properties
            XCTAssertNotNil(trackPoint.altitude)
            XCTAssertNotNil(trackPoint.horizontalAccuracy)
            XCTAssertNotNil(trackPoint.speed)
            XCTAssertNotNil(trackPoint.course)
        }
    }

    func testImportTrackPointsWithNilLocation() async throws {
        let context = try createTestCoreDataStore()

        let workoutID = "workout-nil-location"

        // Create workout session
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(workoutID, forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        // Create track point without location
        let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        trackPoint.setValue(workoutID, forKey: "workoutID")
        trackPoint.setValue(Date(), forKey: "time")
        trackPoint.setValue(Int16(130), forKey: "heartRate")
        // Note: location is nil

        try context.save()

        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        XCTAssertEqual(data.trackPoints.count, 1)

        let importedPoint = data.trackPoints.first!
        XCTAssertEqual(importedPoint.workoutID, workoutID)
        XCTAssertEqual(importedPoint.heartRate, 130)
        XCTAssertNil(importedPoint.latitude)
        XCTAssertNil(importedPoint.longitude)
    }

    func testImportTrackPointsWithMixedLocationData() async throws {
        let context = try createTestCoreDataStore()

        let workoutID = "workout-mixed-locations"

        // Create workout session
        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(workoutID, forKey: "workoutID")
        session.setValue(Date(), forKey: "startTime")

        // Track point with location
        let point1 = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        point1.setValue(workoutID, forKey: "workoutID")
        point1.setValue(Date(), forKey: "time")
        point1.setValue(CLLocation(latitude: 40.7128, longitude: -74.0060), forKey: "location")

        // Track point without location (indoor/GPS dropout)
        let point2 = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        point2.setValue(workoutID, forKey: "workoutID")
        point2.setValue(Date().addingTimeInterval(60), forKey: "time")
        point2.setValue(Int16(140), forKey: "heartRate")

        // Another track point with location
        let point3 = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        point3.setValue(workoutID, forKey: "workoutID")
        point3.setValue(Date().addingTimeInterval(120), forKey: "time")
        point3.setValue(CLLocation(latitude: 40.7130, longitude: -74.0055), forKey: "location")

        try context.save()

        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        XCTAssertEqual(data.trackPoints.count, 3)

        // First point should have location
        XCTAssertNotNil(data.trackPoints[0].latitude)
        XCTAssertNotNil(data.trackPoints[0].longitude)

        // Second point should not have location
        XCTAssertNil(data.trackPoints[1].latitude)
        XCTAssertNil(data.trackPoints[1].longitude)
        XCTAssertEqual(data.trackPoints[1].heartRate, 140)

        // Third point should have location
        XCTAssertNotNil(data.trackPoints[2].latitude)
        XCTAssertNotNil(data.trackPoints[2].longitude)
    }

    // MARK: - Edge Case Tests

    func testCLLocationWithNegativeSpeedAndCourse() async throws {
        let context = try createTestCoreDataStore()

        let workoutID = "workout-negative-values"

        let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
        session.setValue(workoutID, forKey: "workoutID")

        let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
        trackPoint.setValue(workoutID, forKey: "workoutID")
        trackPoint.setValue(Date(), forKey: "time")

        // CLLocation uses -1 for invalid speed/course
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            altitude: 40.0,
            horizontalAccuracy: 10.0,
            verticalAccuracy: 15.0,
            course: -1,  // Invalid course
            speed: -1,   // Invalid speed
            timestamp: Date()
        )
        trackPoint.setValue(location, forKey: "location")

        try context.save()

        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        XCTAssertEqual(data.trackPoints.count, 1)
        let importedPoint = data.trackPoints.first!

        // Coordinates should be valid
        XCTAssertNotNil(importedPoint.latitude)
        XCTAssertEqual(importedPoint.latitude!, 35.6762, accuracy: 0.0001)
        XCTAssertEqual(importedPoint.longitude!, 139.6503, accuracy: 0.0001)

        // Speed and course should be nil (invalid values filtered)
        XCTAssertNil(importedPoint.speed)
        XCTAssertNil(importedPoint.course)
    }

    func testCLLocationAtExtremeCoordinates() async throws {
        let context = try createTestCoreDataStore()

        // Test locations at coordinate extremes
        let extremeLocations: [(String, Double, Double)] = [
            ("north-pole", 89.9999, 0.0),
            ("south-pole", -89.9999, 0.0),
            ("date-line-east", 0.0, 179.9999),
            ("date-line-west", 0.0, -179.9999),
            ("equator-prime", 0.0, 0.0)
        ]

        for (workoutID, lat, long) in extremeLocations {
            let session = NSEntityDescription.insertNewObject(forEntityName: "WorkoutHistory", into: context)
            session.setValue(workoutID, forKey: "workoutID")

            let trackPoint = NSEntityDescription.insertNewObject(forEntityName: "WorkoutLocation", into: context)
            trackPoint.setValue(workoutID, forKey: "workoutID")
            trackPoint.setValue(CLLocation(latitude: lat, longitude: long), forKey: "location")
        }

        try context.save()

        let importer = CoreDataImporter(storeURL: testStoreURL)
        let data = try await importer.importAllData()

        XCTAssertEqual(data.trackPoints.count, 5)

        for (index, expected) in extremeLocations.enumerated() {
            let point = data.trackPoints[index]
            XCTAssertEqual(point.workoutID, expected.0)
            XCTAssertNotNil(point.latitude)
            XCTAssertNotNil(point.longitude)
            XCTAssertEqual(point.latitude!, expected.1, accuracy: 0.0001)
            XCTAssertEqual(point.longitude!, expected.2, accuracy: 0.0001)
        }
    }

    // MARK: - Helper Methods

    private func createTestCoreDataStore() throws -> NSManagedObjectContext {
        let model = createTestModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: testStoreURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    private func createTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // WorkoutHistory
        let workoutHistory = NSEntityDescription()
        workoutHistory.name = "WorkoutHistory"
        workoutHistory.managedObjectClassName = "NSManagedObject"
        workoutHistory.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: true),
            createAttribute("address", .stringAttributeType, optional: true),
            createAttribute("startTime", .dateAttributeType, optional: true)
        ]

        // WorkoutLocation with CLLocation transformable
        let workoutLocation = NSEntityDescription()
        workoutLocation.name = "WorkoutLocation"
        workoutLocation.managedObjectClassName = "NSManagedObject"

        let locationAttr = NSAttributeDescription()
        locationAttr.name = "location"
        locationAttr.attributeType = .transformableAttributeType
        locationAttr.isOptional = true
        locationAttr.valueTransformerName = CLLocationValueTransformer.transformerName.rawValue
        locationAttr.attributeValueClassName = "CLLocation"

        workoutLocation.properties = [
            createAttribute("workoutID", .stringAttributeType, optional: false),
            createAttribute("time", .dateAttributeType, optional: true),
            createAttribute("heartRate", .integer16AttributeType, optional: true),
            createAttribute("steps", .integer16AttributeType, optional: true),
            locationAttr
        ]

        model.entities = [workoutHistory, workoutLocation]
        return model
    }

    private func createAttribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        return attr
    }
}
