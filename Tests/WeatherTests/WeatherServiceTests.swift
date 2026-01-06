//
//  WeatherServiceTests.swift
//  JogPod Tests
//
//  Tests for WeatherService facade.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - WeatherService Tests

@Suite("WeatherService")
struct WeatherServiceTests {

    // MARK: - Test Data

    static func makeTestConditions(
        temperatureCelsius: Double = 22.0,
        windSpeedKph: Double = 10.0,
        conditionCode: Int = 2
    ) -> WeatherConditions {
        WeatherConditions(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: 55.0,
            windSpeedKph: windSpeedKph,
            windDirection: "NW",
            windDirectionDegrees: 315.0,
            conditionCode: conditionCode,
            conditionDescription: "Partly cloudy",
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            timestamp: Date()
        )
    }

    // MARK: - Initialization

    @Test("shared instance exists")
    func sharedInstanceExists() async {
        let service = WeatherService.shared
        let providerName = await service.currentProviderName
        #expect(providerName == "Open-Meteo")
    }

    @Test("can initialize with custom provider")
    func initializesWithCustomProvider() async {
        let conditions = Self.makeTestConditions()
        let service = WeatherService.forTesting(returning: conditions)

        let providerName = await service.currentProviderName
        #expect(providerName == "Mock")
    }

    // MARK: - Fetching Conditions

    #if DEBUG
    @Test("returns conditions from mock provider")
    func returnsConditionsFromMockProvider() async throws {
        let expectedConditions = Self.makeTestConditions(temperatureCelsius: 25.0)
        let service = WeatherService.forTesting(returning: expectedConditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let conditions = try await service.getCurrentConditions(for: location)

        #expect(conditions.temperatureCelsius == 25.0)
    }

    @Test("caches conditions after successful fetch")
    func cachesConditionsAfterFetch() async throws {
        let expectedConditions = Self.makeTestConditions()
        let service = WeatherService.forTesting(returning: expectedConditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        _ = try await service.getCurrentConditions(for: location)

        let cached = await service.cachedConditions
        #expect(cached != nil)
        #expect(cached?.temperatureCelsius == expectedConditions.temperatureCelsius)
    }

    @Test("clears cache successfully")
    func clearsCacheSuccessfully() async throws {
        let expectedConditions = Self.makeTestConditions()
        let service = WeatherService.forTesting(returning: expectedConditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        _ = try await service.getCurrentConditions(for: location)
        #expect(await service.cachedConditions != nil)

        await service.clearCache()
        #expect(await service.cachedConditions == nil)
    }
    #endif

    // MARK: - Weather for Announcements

    #if DEBUG
    @Test("returns WeatherData for announcements in metric")
    func returnsWeatherDataForAnnouncementsMetric() async throws {
        let conditions = Self.makeTestConditions(temperatureCelsius: 20.0)
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let weatherData = try await service.getWeatherForAnnouncement(
            for: location,
            useMetric: true
        )

        #expect(weatherData.temperature == 20.0)
    }

    @Test("returns WeatherData for announcements in imperial")
    func returnsWeatherDataForAnnouncementsImperial() async throws {
        let conditions = Self.makeTestConditions(temperatureCelsius: 20.0)
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let weatherData = try await service.getWeatherForAnnouncement(
            for: location,
            useMetric: false
        )

        #expect(weatherData.temperature == 68.0) // 20C = 68F
    }
    #endif

    // MARK: - Workout Conditions Check

    #if DEBUG
    @Test("workout conditions are suitable for normal weather")
    func workoutConditionsSuitableForNormalWeather() async throws {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 22.0,
            windSpeedKph: 15.0,
            conditionCode: 2  // Partly cloudy
        )
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let (suitable, advisory) = try await service.checkWorkoutConditions(for: location)

        #expect(suitable == true)
        #expect(advisory == nil)
    }

    @Test("workout conditions warn for extreme heat")
    func workoutConditionsWarnForExtremeHeat() async throws {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 40.0,  // Extreme heat
            windSpeedKph: 10.0,
            conditionCode: 0
        )
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let (suitable, advisory) = try await service.checkWorkoutConditions(for: location)

        #expect(suitable == false)
        #expect(advisory?.contains("heat") == true)
    }

    @Test("workout conditions warn for extreme cold")
    func workoutConditionsWarnForExtremeCold() async throws {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: -15.0,  // Extreme cold
            windSpeedKph: 20.0,
            conditionCode: 73  // Snow
        )
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let (suitable, advisory) = try await service.checkWorkoutConditions(for: location)

        #expect(suitable == false)
        #expect(advisory?.contains("cold") == true)
    }

    @Test("workout conditions warn for high wind")
    func workoutConditionsWarnForHighWind() async throws {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 20.0,
            windSpeedKph: 60.0,  // High wind
            conditionCode: 2
        )
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let (suitable, advisory) = try await service.checkWorkoutConditions(for: location)

        #expect(suitable == false)
        #expect(advisory?.contains("wind") == true)
    }

    @Test("workout conditions warn for thunderstorm")
    func workoutConditionsWarnForThunderstorm() async throws {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 25.0,
            windSpeedKph: 30.0,
            conditionCode: 95  // Thunderstorm
        )
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let (suitable, advisory) = try await service.checkWorkoutConditions(for: location)

        #expect(suitable == false)
        #expect(advisory?.contains("Thunderstorm") == true)
    }
    #endif

    // MARK: - Alerts

    #if DEBUG
    @Test("returns alerts from provider")
    func returnsAlertsFromProvider() async throws {
        let conditions = Self.makeTestConditions()
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let alerts = try await service.getAlerts(for: location)

        // Mock provider returns empty alerts
        #expect(alerts.isEmpty)
    }
    #endif

    // MARK: - Provider Change

    #if DEBUG
    @Test("changing provider clears cache")
    func changingProviderClearsCache() async throws {
        let conditions = Self.makeTestConditions()
        let service = WeatherService.forTesting(returning: conditions)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        // Fetch to populate cache
        _ = try await service.getCurrentConditions(for: location)
        #expect(await service.cachedConditions != nil)

        // Change provider
        await service.setProvider(OpenMeteoWeatherService())

        // Cache should be cleared
        #expect(await service.cachedConditions == nil)
        #expect(await service.currentProviderName == "Open-Meteo")
    }
    #endif
}
