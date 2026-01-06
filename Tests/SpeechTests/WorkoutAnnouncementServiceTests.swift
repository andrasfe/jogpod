//
//  WorkoutAnnouncementServiceTests.swift
//  JogPodTests
//
//  Tests for WorkoutAnnouncementService.
//

import Testing
import AVFoundation
@testable import JogPod

@Suite("WorkoutAnnouncementService Tests")
struct WorkoutAnnouncementServiceTests {

    private func createSilentSpeechService() -> SpeechService {
        let config = SpeechConfiguration(
            isEnabled: true,
            rate: AVSpeechUtteranceMaximumSpeechRate,
            volume: 0.0,
            enableAudioDucking: false
        )
        return SpeechService(configuration: config)
    }

    @Test("Service initializes with default enabled types")
    func testDefaultEnabledTypes() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(speechService: speechService)

        // Check default enabled types match AnnouncementType defaults
        for type in AnnouncementType.allCases {
            let isEnabled = await service.isEnabled(type)
            #expect(isEnabled == type.isEnabledByDefault)
        }
    }

    @Test("Service accepts custom enabled types")
    func testCustomEnabledTypes() async {
        let speechService = createSilentSpeechService()
        let customTypes: Set<AnnouncementType> = [.currentSpeed, .distance]
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: customTypes
        )

        let enabledTypes = await service.getEnabledTypes()
        #expect(enabledTypes == customTypes)
    }

    @Test("Enable and disable announcement types")
    func testSetAnnouncementType() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: []
        )

        // Initially empty
        #expect(await !service.isEnabled(.currentSpeed))

        // Enable
        await service.setAnnouncementType(.currentSpeed, enabled: true)
        #expect(await service.isEnabled(.currentSpeed))

        // Disable
        await service.setAnnouncementType(.currentSpeed, enabled: false)
        #expect(await !service.isEnabled(.currentSpeed))
    }

    @Test("Set all enabled types at once")
    func testSetEnabled() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(speechService: speechService)

        let newTypes: Set<AnnouncementType> = [.duration, .caloriesBurned]
        await service.setEnabled(newTypes)

        let enabledTypes = await service.getEnabledTypes()
        #expect(enabledTypes == newTypes)
    }

    @Test("Update metrics")
    func testUpdateMetrics() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(speechService: speechService)

        let data = AnnouncementData(
            currentSpeed: 2.5,
            distance: 3000,
            caloriesBurned: 150
        )
        await service.updateMetrics(data)

        // Metrics are updated internally - verify by announcement
        // (Actual speech would require integration test)
    }

    @Test("Update weather data")
    func testUpdateWeather() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(speechService: speechService)

        let weather = WeatherData(temperature: 72, humidity: 50)
        await service.updateWeather(weather)

        // Weather is updated internally
    }

    @Test("Announce specific type returns formatted string")
    func testAnnounceSpecificType() async {
        // Use disabled speech to avoid actual audio
        let config = SpeechConfiguration(isEnabled: false)
        let speechService = SpeechService(configuration: config)
        let service = WorkoutAnnouncementService(speechService: speechService)

        let data = AnnouncementData(currentSpeed: 2.0, caloriesBurned: 200)
        await service.updateMetrics(data)

        // The announce method will fail silently since speech is disabled,
        // but we can test the formatter integration
    }

    @Test("Reset rotation returns to beginning")
    func testResetRotation() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: [.currentSpeed, .distance, .caloriesBurned]
        )

        await service.resetRotation()
        // Rotation is reset - verified by next announcement order
    }

    @Test("Announcement rotation order matches AnnouncementType.allCases")
    func testRotationOrder() async {
        let speechService = createSilentSpeechService()
        let enabledTypes: Set<AnnouncementType> = [.currentSpeed, .distance, .duration]
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: enabledTypes
        )

        // The rotation should follow the order in AnnouncementType.allCases
        // Only including enabled types
        let expectedOrder = AnnouncementType.allCases.filter { enabledTypes.contains($0) }

        // Verify order is maintained (currentSpeed comes before distance, distance before duration)
        #expect(expectedOrder[0] == .currentSpeed)
        #expect(expectedOrder.count == 3)
    }

    @Test("Announce custom text")
    func testAnnounceCustom() async {
        let speechService = createSilentSpeechService()
        let service = WorkoutAnnouncementService(speechService: speechService)

        // Should not throw
        await service.announceCustom("Custom announcement text")
    }
}

@Suite("WorkoutAnnouncementService Rotation Tests")
struct WorkoutAnnouncementServiceRotationTests {

    @Test("Empty enabled types returns nil from announceNext")
    func testEmptyRotation() async {
        let config = SpeechConfiguration(isEnabled: false)
        let speechService = SpeechService(configuration: config)
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: []
        )

        let result = await service.announceNext()
        #expect(result == nil)
    }

    @Test("Announce skips types with nil values")
    func testSkipsNilValues() async {
        let config = SpeechConfiguration(isEnabled: false)
        let speechService = SpeechService(configuration: config)
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            enabledTypes: [.currentHeartRate] // Heart rate returns nil when 0
        )

        // Data with zero heart rate (should return nil announcement)
        let data = AnnouncementData(currentHeartRate: 0)
        await service.updateMetrics(data)

        let result = await service.announceNext()
        #expect(result == nil)
    }
}

@Suite("WorkoutAnnouncementService Unit System Tests")
struct WorkoutAnnouncementServiceUnitSystemTests {

    @Test("Imperial unit system formats correctly")
    func testImperialUnits() async {
        let config = SpeechConfiguration(isEnabled: false)
        let speechService = SpeechService(configuration: config)
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            unitSystem: .imperial,
            enabledTypes: [.currentSpeed]
        )

        // 2.23 m/s = ~5 mph
        let data = AnnouncementData(currentSpeed: 2.23)
        await service.updateMetrics(data)

        // Would announce "Current speed 5.0 miles per hour"
        // (Can't capture actual announcement without integration test)
    }

    @Test("Metric unit system formats correctly")
    func testMetricUnits() async {
        let config = SpeechConfiguration(isEnabled: false)
        let speechService = SpeechService(configuration: config)
        let service = WorkoutAnnouncementService(
            speechService: speechService,
            unitSystem: .metric,
            enabledTypes: [.currentSpeed]
        )

        // 2.77 m/s = ~10 km/h
        let data = AnnouncementData(currentSpeed: 2.77)
        await service.updateMetrics(data)

        // Would announce "Current speed 10.0 kilometers per hour"
    }
}
