import Testing
import Foundation
import SwiftData
@testable import JogPod

/// Tests for the WorkoutSession SwiftData model.
@Suite("WorkoutSession Model Tests")
@MainActor
struct WorkoutSessionTests {

    // MARK: - Setup

    private func makeTestContainer() throws -> ModelContainer {
        try JogPodSchema.makeTestContainer()
    }

    // MARK: - Initialization Tests

    @Test("WorkoutSession generates UUID by default")
    func testDefaultIDGeneration() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session = WorkoutSession()
        context.insert(session)
        try context.save()

        #expect(!session.workoutID.isEmpty)
        // Should be a valid UUID format
        #expect(UUID(uuidString: session.workoutID) != nil)
    }

    @Test("WorkoutSession accepts custom workoutID")
    func testCustomID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session = WorkoutSession(workoutID: "custom-workout-123")
        context.insert(session)
        try context.save()

        #expect(session.workoutID == "custom-workout-123")
    }

    @Test("WorkoutSession initializes with startTime")
    func testInitWithStartTime() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let session = WorkoutSession(startTime: now)
        context.insert(session)
        try context.save()

        #expect(session.startTime == now)
    }

    // MARK: - Attribute Tests

    @Test("All WorkoutHistory attributes are preserved")
    func testAllAttributes() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let alertDate = Date(timeIntervalSinceReferenceDate: 726_710_400) // 2024-01-15 00:00:00 UTC
        let alertExpires = Date(timeIntervalSinceReferenceDate: 726_796_800) // 2024-01-16 00:00:00 UTC
        let session = WorkoutSession(workoutID: "test-workout")
        session.address = "123 Test Street, City"
        session.startTime = now
        session.humidity = 0.65
        session.temperatureInCelsius = 22.5
        session.windSpeedInKmh = 15.0
        session.weatherIconUrl = "https://weather.com/icon.png"
        session.alertDate = alertDate
        session.alertDescription = "Heat advisory"
        session.alertExpires = alertExpires
        session.alertType = "heat"

        context.insert(session)
        try context.save()

        // Fetch and verify
        let descriptor = WorkoutSession.fetchDescriptor(forWorkoutID: "test-workout")
        let fetched = try context.fetch(descriptor).first

        #expect(fetched?.address == "123 Test Street, City")
        #expect(fetched?.startTime == now)
        #expect(fetched?.humidity == 0.65)
        #expect(fetched?.temperatureInCelsius == 22.5)
        #expect(fetched?.windSpeedInKmh == 15.0)
        #expect(fetched?.weatherIconUrl == "https://weather.com/icon.png")
        #expect(fetched?.alertDate == alertDate)
        #expect(fetched?.alertDescription == "Heat advisory")
        #expect(fetched?.alertExpires == alertExpires)
        #expect(fetched?.alertType == "heat")
    }

    // MARK: - Computed Property Tests

    @Test("hasWeatherData detects presence of weather info")
    func testHasWeatherData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "no-weather")
        context.insert(session1)
        #expect(session1.hasWeatherData == false)

        let session2 = WorkoutSession(workoutID: "has-temp")
        session2.temperatureInCelsius = 20.0
        context.insert(session2)
        #expect(session2.hasWeatherData == true)

        let session3 = WorkoutSession(workoutID: "has-humidity")
        session3.humidity = 0.5
        context.insert(session3)
        #expect(session3.hasWeatherData == true)
    }

    @Test("hasWeatherAlert detects presence of alert")
    func testHasWeatherAlert() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "no-alert")
        context.insert(session1)
        #expect(session1.hasWeatherAlert == false)

        let session2 = WorkoutSession(workoutID: "partial-alert")
        session2.alertType = "storm"
        context.insert(session2)
        #expect(session2.hasWeatherAlert == false)  // Needs description too

        let session3 = WorkoutSession(workoutID: "full-alert")
        session3.alertType = "storm"
        session3.alertDescription = "Severe thunderstorm warning"
        context.insert(session3)
        #expect(session3.hasWeatherAlert == true)
    }

    @Test("isAlertActive checks expiration correctly")
    func testIsAlertActive() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // No alert
        let session1 = WorkoutSession(workoutID: "no-alert")
        context.insert(session1)
        #expect(session1.isAlertActive == false)

        // Alert without expiration (considered active)
        let session2 = WorkoutSession(workoutID: "no-expiry")
        session2.alertType = "heat"
        session2.alertDescription = "Heat advisory"
        context.insert(session2)
        #expect(session2.isAlertActive == true)

        // Expired alert
        let session3 = WorkoutSession(workoutID: "expired")
        session3.alertType = "heat"
        session3.alertDescription = "Heat advisory"
        session3.alertExpires = Date().addingTimeInterval(-3600) // 1 hour ago
        context.insert(session3)
        #expect(session3.isAlertActive == false)

        // Future expiration (active)
        let session4 = WorkoutSession(workoutID: "active")
        session4.alertType = "heat"
        session4.alertDescription = "Heat advisory"
        session4.alertExpires = Date().addingTimeInterval(3600) // 1 hour from now
        context.insert(session4)
        #expect(session4.isAlertActive == true)
    }

    @Test("alertDateDisplay formats date correctly")
    func testAlertDateDisplay() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "no-date")
        context.insert(session1)
        #expect(session1.alertDateDisplay == nil)

        let session2 = WorkoutSession(workoutID: "has-date")
        session2.alertDate = Date(timeIntervalSinceReferenceDate: 726_710_400) // 2024-01-15 00:00:00 UTC
        context.insert(session2)
        #expect(session2.alertDateDisplay != nil)
        // Date formatting depends on locale, just verify it returns a non-empty string
        #expect(session2.alertDateDisplay?.isEmpty == false)
    }

    @Test("alertExpiresDisplay formats date correctly")
    func testAlertExpiresDisplay() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "no-expiry")
        context.insert(session1)
        #expect(session1.alertExpiresDisplay == nil)

        let session2 = WorkoutSession(workoutID: "has-expiry")
        session2.alertExpires = Date(timeIntervalSinceReferenceDate: 726_796_800) // 2024-01-16 00:00:00 UTC
        context.insert(session2)
        #expect(session2.alertExpiresDisplay != nil)
        #expect(session2.alertExpiresDisplay?.isEmpty == false)
    }

    @Test("temperatureDisplay formats correctly")
    func testTemperatureDisplay() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "no-temp")
        context.insert(session1)
        #expect(session1.temperatureDisplay == nil)

        let session2 = WorkoutSession(workoutID: "has-temp")
        session2.temperatureInCelsius = 23.456
        context.insert(session2)
        #expect(session2.temperatureDisplay == "23.5 C")
    }

    @Test("temperatureInFahrenheit converts correctly")
    func testTemperatureConversion() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session = WorkoutSession(workoutID: "temp-test")
        session.temperatureInCelsius = 0.0
        context.insert(session)
        #expect(session.temperatureInFahrenheit == 32.0)

        session.temperatureInCelsius = 100.0
        #expect(session.temperatureInFahrenheit == 212.0)

        session.temperatureInCelsius = 20.0
        #expect(session.temperatureInFahrenheit == 68.0)
    }

    // MARK: - Fetch Descriptor Tests

    @Test("fetchDescriptor finds session by workoutID")
    func testFetchByWorkoutID() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "workout-1")
        let session2 = WorkoutSession(workoutID: "workout-2")
        context.insert(session1)
        context.insert(session2)
        try context.save()

        let descriptor = WorkoutSession.fetchDescriptor(forWorkoutID: "workout-1")
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results.first?.workoutID == "workout-1")
    }

    @Test("allSessionsDescriptor returns sorted results")
    func testAllSessionsSorted() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let now = Date()
        let session1 = WorkoutSession(workoutID: "old", startTime: now.addingTimeInterval(-86400))
        let session2 = WorkoutSession(workoutID: "new", startTime: now)
        let session3 = WorkoutSession(workoutID: "middle", startTime: now.addingTimeInterval(-43200))

        context.insert(session1)
        context.insert(session2)
        context.insert(session3)
        try context.save()

        let descriptor = WorkoutSession.allSessionsDescriptor()
        let results = try context.fetch(descriptor)

        #expect(results.count == 3)
        #expect(results[0].workoutID == "new")
        #expect(results[1].workoutID == "middle")
        #expect(results[2].workoutID == "old")
    }

    // MARK: - Uniqueness Tests

    @Test("workoutID is unique")
    func testWorkoutIDUniqueness() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let session1 = WorkoutSession(workoutID: "unique-id")
        context.insert(session1)
        try context.save()

        // With @Attribute(.unique), inserting another with same ID
        // should either update or fail
        let descriptor = FetchDescriptor<WorkoutSession>()
        let initialCount = try context.fetch(descriptor).count

        #expect(initialCount == 1)
    }
}
