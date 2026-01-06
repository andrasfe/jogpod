//
//  WeatherConditionsTests.swift
//  JogPod Tests
//
//  Tests for WeatherConditions data model.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - WeatherConditions Tests

@Suite("WeatherConditions")
struct WeatherConditionsTests {

    // MARK: - Test Data

    static func makeTestConditions(
        temperatureCelsius: Double = 20.0,
        humidityPercent: Double = 65.0,
        windSpeedKph: Double = 15.0,
        windDirection: String = "NW",
        windDirectionDegrees: Double? = 315.0,
        conditionCode: Int? = 2
    ) -> WeatherConditions {
        WeatherConditions(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent,
            windSpeedKph: windSpeedKph,
            windDirection: windDirection,
            windDirectionDegrees: windDirectionDegrees,
            conditionCode: conditionCode,
            conditionDescription: "Partly cloudy",
            apparentTemperatureCelsius: 18.5,
            uvIndex: 5.0,
            visibilityKm: 10.0,
            pressureHpa: 1013.25,
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            timestamp: Date()
        )
    }

    // MARK: - Initialization

    @Test("initializes with all values")
    func initializesWithAllValues() {
        let conditions = Self.makeTestConditions()

        #expect(conditions.temperatureCelsius == 20.0)
        #expect(conditions.humidityPercent == 65.0)
        #expect(conditions.windSpeedKph == 15.0)
        #expect(conditions.windDirection == "NW")
        #expect(conditions.windDirectionDegrees == 315.0)
        #expect(conditions.conditionCode == 2)
        #expect(conditions.conditionDescription == "Partly cloudy")
        #expect(conditions.apparentTemperatureCelsius == 18.5)
        #expect(conditions.uvIndex == 5.0)
        #expect(conditions.visibilityKm == 10.0)
        #expect(conditions.pressureHpa == 1013.25)
        #expect(conditions.location.latitude == 37.7749)
        #expect(conditions.location.longitude == -122.4194)
    }

    // MARK: - Temperature Conversion

    @Test("converts Celsius to Fahrenheit correctly")
    func convertsToFahrenheit() {
        // 0C = 32F
        let freezing = Self.makeTestConditions(temperatureCelsius: 0)
        #expect(freezing.temperatureFahrenheit == 32.0)

        // 100C = 212F
        let boiling = Self.makeTestConditions(temperatureCelsius: 100)
        #expect(boiling.temperatureFahrenheit == 212.0)

        // 20C = 68F
        let room = Self.makeTestConditions(temperatureCelsius: 20)
        #expect(room.temperatureFahrenheit == 68.0)

        // -40C = -40F (same in both scales)
        let same = Self.makeTestConditions(temperatureCelsius: -40)
        #expect(same.temperatureFahrenheit == -40.0)
    }

    // MARK: - Wind Speed Conversion

    @Test("converts km/h to mph correctly")
    func convertsWindSpeedToMph() {
        let conditions = Self.makeTestConditions(windSpeedKph: 100.0)
        // 100 km/h = 62.1371 mph
        #expect(abs(conditions.windSpeedMph - 62.1371) < 0.001)
    }

    // MARK: - SF Symbol Mapping

    @Test("returns correct SF Symbol for clear sky")
    func sfSymbolForClearSky() {
        let conditions = Self.makeTestConditions(conditionCode: 0)
        #expect(conditions.sfSymbolName == "sun.max.fill")
    }

    @Test("returns correct SF Symbol for partly cloudy")
    func sfSymbolForPartlyCloudy() {
        let conditions = Self.makeTestConditions(conditionCode: 2)
        #expect(conditions.sfSymbolName == "cloud.sun.fill")
    }

    @Test("returns correct SF Symbol for rain")
    func sfSymbolForRain() {
        let conditions = Self.makeTestConditions(conditionCode: 63)
        #expect(conditions.sfSymbolName == "cloud.rain.fill")
    }

    @Test("returns correct SF Symbol for snow")
    func sfSymbolForSnow() {
        let conditions = Self.makeTestConditions(conditionCode: 73)
        #expect(conditions.sfSymbolName == "cloud.snow.fill")
    }

    @Test("returns correct SF Symbol for thunderstorm")
    func sfSymbolForThunderstorm() {
        let conditions = Self.makeTestConditions(conditionCode: 95)
        #expect(conditions.sfSymbolName == "cloud.bolt.fill")
    }

    @Test("returns default SF Symbol for unknown code")
    func sfSymbolForUnknownCode() {
        let conditions = Self.makeTestConditions(conditionCode: 999)
        #expect(conditions.sfSymbolName == "cloud.fill")
    }

    @Test("returns default SF Symbol for nil code")
    func sfSymbolForNilCode() {
        let conditions = Self.makeTestConditions(conditionCode: nil)
        #expect(conditions.sfSymbolName == "cloud.fill")
    }

    // MARK: - WeatherData Conversion

    @Test("converts to WeatherData in metric units")
    func convertsToWeatherDataMetric() {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 20.0,
            humidityPercent: 65.0,
            windSpeedKph: 15.0,
            windDirection: "NW"
        )

        let weatherData = conditions.toWeatherData(useMetric: true)

        #expect(weatherData.temperature == 20.0)
        #expect(weatherData.humidity == 65.0)
        #expect(weatherData.windSpeed == 15.0)
        #expect(weatherData.windDirection == "NW")
    }

    @Test("converts to WeatherData in imperial units")
    func convertsToWeatherDataImperial() {
        let conditions = Self.makeTestConditions(
            temperatureCelsius: 20.0,
            humidityPercent: 65.0,
            windSpeedKph: 15.0,
            windDirection: "NW"
        )

        let weatherData = conditions.toWeatherData(useMetric: false)

        #expect(weatherData.temperature == 68.0) // 20C = 68F
        #expect(weatherData.humidity == 65.0)
        #expect(abs((weatherData.windSpeed ?? 0) - 9.32) < 0.01) // 15 kph ~= 9.32 mph
        #expect(weatherData.windDirection == "NW")
    }

    // MARK: - Equatable

    @Test("conditions are equatable")
    func conditionsAreEquatable() {
        let conditions1 = Self.makeTestConditions()
        let conditions2 = Self.makeTestConditions()
        let conditions3 = Self.makeTestConditions(temperatureCelsius: 25.0)

        #expect(conditions1 == conditions2)
        #expect(conditions1 != conditions3)
    }

    // MARK: - Codable

    @Test("conditions are codable")
    func conditionsAreCodable() throws {
        let original = Self.makeTestConditions()

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WeatherConditions.self, from: data)

        #expect(decoded.temperatureCelsius == original.temperatureCelsius)
        #expect(decoded.humidityPercent == original.humidityPercent)
        #expect(decoded.windSpeedKph == original.windSpeedKph)
        #expect(decoded.windDirection == original.windDirection)
        #expect(decoded.conditionCode == original.conditionCode)
        #expect(decoded.location.latitude == original.location.latitude)
        #expect(decoded.location.longitude == original.location.longitude)
    }

    // MARK: - Sendable

    @Test("conditions are Sendable")
    func conditionsAreSendable() async {
        let conditions = Self.makeTestConditions()

        let result = await Task.detached {
            return conditions
        }.value

        #expect(result == conditions)
    }
}
