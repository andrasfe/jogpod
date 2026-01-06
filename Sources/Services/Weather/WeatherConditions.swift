//
//  WeatherConditions.swift
//  JogPod
//
//  Models for weather condition data.
//

import Foundation
import CoreLocation

// MARK: - WeatherConditions

/// Current weather conditions at a location.
///
/// This struct contains all weather data needed for workout announcements,
/// mirroring the data previously obtained from the Weather Underground API.
///
/// ## Legacy Equivalence
///
/// This struct replaces the data passed through `LocalWeatherDelegate`:
/// - `tempC` -> `temperatureCelsius`
/// - `humidity` -> `humidityPercent`
/// - `wind_kph` -> `windSpeedKph`
/// - `wind_dir` -> `windDirection`
/// - `icon_url` -> `conditionCode` (modernized to system symbol names)
///
/// ## Thread Safety
///
/// This struct is `Sendable` and can be safely passed across actor boundaries.
public struct WeatherConditions: Sendable, Equatable, Codable {

    // MARK: - Temperature

    /// Temperature in Celsius.
    public let temperatureCelsius: Double

    /// Temperature in Fahrenheit (computed).
    public var temperatureFahrenheit: Double {
        (temperatureCelsius * 9.0 / 5.0) + 32.0
    }

    // MARK: - Humidity

    /// Relative humidity as a percentage (0-100).
    public let humidityPercent: Double

    // MARK: - Wind

    /// Wind speed in kilometers per hour.
    public let windSpeedKph: Double

    /// Wind speed in miles per hour (computed).
    public var windSpeedMph: Double {
        windSpeedKph * 0.621371
    }

    /// Wind direction as a compass string (e.g., "N", "NE", "SW").
    public let windDirection: String

    /// Wind direction in degrees (0-360, where 0 is North).
    public let windDirectionDegrees: Double?

    // MARK: - Conditions

    /// Weather condition code for icon mapping.
    ///
    /// Uses WMO Weather interpretation codes when available:
    /// - 0: Clear sky
    /// - 1-3: Mainly clear, partly cloudy, overcast
    /// - 45, 48: Fog
    /// - 51-57: Drizzle
    /// - 61-67: Rain
    /// - 71-77: Snow
    /// - 80-82: Rain showers
    /// - 85-86: Snow showers
    /// - 95-99: Thunderstorm
    public let conditionCode: Int?

    /// Human-readable condition description.
    public let conditionDescription: String?

    // MARK: - Additional Data

    /// Apparent (feels like) temperature in Celsius.
    public let apparentTemperatureCelsius: Double?

    /// UV index (0-11+).
    public let uvIndex: Double?

    /// Visibility in kilometers.
    public let visibilityKm: Double?

    /// Atmospheric pressure in hectopascals (hPa).
    public let pressureHpa: Double?

    // MARK: - Metadata

    /// The location these conditions are for.
    public let location: CLLocationCoordinate2D

    /// When these conditions were observed/fetched.
    public let timestamp: Date

    // MARK: - Initialization

    public init(
        temperatureCelsius: Double,
        humidityPercent: Double,
        windSpeedKph: Double,
        windDirection: String,
        windDirectionDegrees: Double? = nil,
        conditionCode: Int? = nil,
        conditionDescription: String? = nil,
        apparentTemperatureCelsius: Double? = nil,
        uvIndex: Double? = nil,
        visibilityKm: Double? = nil,
        pressureHpa: Double? = nil,
        location: CLLocationCoordinate2D,
        timestamp: Date = Date()
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = humidityPercent
        self.windSpeedKph = windSpeedKph
        self.windDirection = windDirection
        self.windDirectionDegrees = windDirectionDegrees
        self.conditionCode = conditionCode
        self.conditionDescription = conditionDescription
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.uvIndex = uvIndex
        self.visibilityKm = visibilityKm
        self.pressureHpa = pressureHpa
        self.location = location
        self.timestamp = timestamp
    }
}

// MARK: - CLLocationCoordinate2D Codable

extension CLLocationCoordinate2D: @retroactive Codable {

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

// MARK: - SF Symbol Mapping

extension WeatherConditions {

    /// Returns the appropriate SF Symbol name for the current weather condition.
    ///
    /// This provides a modern replacement for the legacy Weather Underground icon URLs.
    public var sfSymbolName: String {
        guard let code = conditionCode else {
            return "cloud.fill"
        }

        switch code {
        case 0:
            return "sun.max.fill"
        case 1:
            return "sun.min.fill"
        case 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75:
            return "cloud.snow.fill"
        case 77:
            return "cloud.hail.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }
}

// MARK: - WeatherData Conversion

extension WeatherConditions {

    /// Converts to `WeatherData` for use with `AnnouncementFormatter`.
    ///
    /// - Parameter useMetric: Whether to use metric units. Defaults to false (imperial).
    /// - Returns: A `WeatherData` instance suitable for announcements.
    public func toWeatherData(useMetric: Bool = false) -> WeatherData {
        WeatherData(
            temperature: useMetric ? temperatureCelsius : temperatureFahrenheit,
            humidity: humidityPercent,
            windSpeed: useMetric ? windSpeedKph : windSpeedMph,
            windDirection: windDirection
        )
    }
}

// MARK: - WeatherData Import

// Import WeatherData from AnnouncementFormatter for the conversion extension
// This creates a dependency on the Speech module, which is acceptable since
// weather data is primarily used for announcements.
