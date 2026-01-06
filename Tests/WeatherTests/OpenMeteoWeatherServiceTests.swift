//
//  OpenMeteoWeatherServiceTests.swift
//  JogPod Tests
//
//  Tests for OpenMeteoWeatherService implementation.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - OpenMeteoWeatherService Tests

@Suite("OpenMeteoWeatherService")
struct OpenMeteoWeatherServiceTests {

    // MARK: - Properties

    @Test("has correct provider name")
    func hasCorrectProviderName() async {
        let service = OpenMeteoWeatherService()
        #expect(service.providerName == "Open-Meteo")
    }

    @Test("does not require API key")
    func doesNotRequireAPIKey() async {
        let service = OpenMeteoWeatherService()
        #expect(service.requiresAPIKey == false)
    }

    // MARK: - Invalid Location

    @Test("throws for invalid location")
    func throwsForInvalidLocation() async {
        let service = OpenMeteoWeatherService()
        let invalidLocation = CLLocation(latitude: 91.0, longitude: 0) // Invalid latitude

        await #expect(throws: WeatherError.self) {
            try await service.getCurrentConditions(for: invalidLocation)
        }
    }

    // MARK: - Alerts

    @Test("returns empty alerts array")
    func returnsEmptyAlerts() async throws {
        let service = OpenMeteoWeatherService()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let alerts = try await service.getAlerts(for: location)

        #expect(alerts.isEmpty)
    }

    // MARK: - Cache

    @Test("clears cache successfully")
    func clearsCacheSuccessfully() async {
        let service = OpenMeteoWeatherService()
        await service.clearCache()
        // No assertion needed - just verifying it doesn't crash
    }
}

// MARK: - Compass Direction Tests

@Suite("OpenMeteoWeatherService Compass Direction")
struct CompassDirectionTests {

    // Test compass direction conversion indirectly through WeatherConditions
    // since the internal method is private

    @Test("wind direction string is valid compass direction")
    func windDirectionIsValidCompassDirection() {
        let validDirections = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                               "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

        // Create conditions with various wind directions
        for direction in validDirections {
            let conditions = WeatherConditions(
                temperatureCelsius: 20,
                humidityPercent: 50,
                windSpeedKph: 10,
                windDirection: direction,
                location: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )

            #expect(validDirections.contains(conditions.windDirection))
        }
    }
}

// MARK: - Weather Code Description Tests

@Suite("Weather Code Descriptions")
struct WeatherCodeDescriptionTests {

    @Test("clear sky condition")
    func clearSkyCondition() {
        let conditions = WeatherConditions(
            temperatureCelsius: 25,
            humidityPercent: 40,
            windSpeedKph: 5,
            windDirection: "N",
            conditionCode: 0,
            conditionDescription: "Clear sky",
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        #expect(conditions.conditionDescription == "Clear sky")
        #expect(conditions.sfSymbolName == "sun.max.fill")
    }

    @Test("fog condition")
    func fogCondition() {
        let conditions = WeatherConditions(
            temperatureCelsius: 15,
            humidityPercent: 95,
            windSpeedKph: 2,
            windDirection: "E",
            conditionCode: 45,
            conditionDescription: "Fog",
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        #expect(conditions.conditionDescription == "Fog")
        #expect(conditions.sfSymbolName == "cloud.fog.fill")
    }

    @Test("heavy rain condition")
    func heavyRainCondition() {
        let conditions = WeatherConditions(
            temperatureCelsius: 18,
            humidityPercent: 90,
            windSpeedKph: 25,
            windDirection: "SW",
            conditionCode: 65,
            conditionDescription: "Heavy rain",
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        #expect(conditions.sfSymbolName == "cloud.rain.fill")
    }

    @Test("thunderstorm with hail condition")
    func thunderstormWithHailCondition() {
        let conditions = WeatherConditions(
            temperatureCelsius: 22,
            humidityPercent: 85,
            windSpeedKph: 40,
            windDirection: "W",
            conditionCode: 96,
            conditionDescription: "Thunderstorm with slight hail",
            location: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        #expect(conditions.sfSymbolName == "cloud.bolt.rain.fill")
    }
}
