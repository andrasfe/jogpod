//
//  OpenMeteoWeatherService.swift
//  JogPod
//
//  Weather service implementation using Open-Meteo API.
//

import Foundation
import CoreLocation

// MARK: - OpenMeteoWeatherService

/// Weather service implementation using the Open-Meteo API.
///
/// Open-Meteo is a free, open-source weather API that provides:
/// - Current weather conditions
/// - Hourly and daily forecasts
/// - Historical weather data
/// - No API key required for non-commercial use
///
/// ## API Documentation
///
/// - Base URL: https://api.open-meteo.com/v1/
/// - Docs: https://open-meteo.com/en/docs
///
/// ## Legacy Replacement
///
/// This service replaces the deprecated Weather Underground API that was
/// used in the original JogPod implementation. It provides equivalent data:
/// - Temperature (Celsius)
/// - Humidity
/// - Wind speed and direction
/// - Weather condition codes for icon mapping
///
/// ## Thread Safety
///
/// This service is designed to be used from any actor context. All methods
/// are async and use `URLSession` for network operations.
public actor OpenMeteoWeatherService: WeatherServiceProtocol {

    // MARK: - Constants

    private static let baseURL = "https://api.open-meteo.com/v1/forecast"

    /// Parameters requested from the Open-Meteo current weather endpoint.
    private static let currentWeatherParams = [
        "temperature_2m",
        "relative_humidity_2m",
        "apparent_temperature",
        "weather_code",
        "wind_speed_10m",
        "wind_direction_10m",
        "surface_pressure"
    ].joined(separator: ",")

    // MARK: - Properties

    private let urlSession: URLSession
    private let decoder: JSONDecoder

    /// Cache for weather conditions to avoid excessive API calls.
    private var conditionsCache: (conditions: WeatherConditions, expiry: Date)?

    /// Cache duration in seconds (5 minutes).
    private let cacheDuration: TimeInterval = 300

    // MARK: - WeatherServiceProtocol

    public nonisolated var providerName: String { "Open-Meteo" }

    public nonisolated var requiresAPIKey: Bool { false }

    // MARK: - Initialization

    /// Creates a new Open-Meteo weather service.
    ///
    /// - Parameter urlSession: The URL session to use for requests. Defaults to `.shared`.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Public Methods

    public func getCurrentConditions(for location: CLLocation) async throws -> WeatherConditions {
        // Check cache first
        if let cached = conditionsCache,
           Date() < cached.expiry,
           isNearby(cached.conditions.location, to: location.coordinate) {
            return cached.conditions
        }

        // Build URL
        let url = try buildCurrentWeatherURL(for: location)

        // Fetch data
        let (data, response) = try await performRequest(url: url)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw WeatherError.rateLimitExceeded
            }
            throw WeatherError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        let apiResponse: OpenMeteoCurrentResponse
        do {
            apiResponse = try decoder.decode(OpenMeteoCurrentResponse.self, from: data)
        } catch {
            throw WeatherError.decodingError(error.localizedDescription)
        }

        // Convert to WeatherConditions
        let conditions = try mapToWeatherConditions(apiResponse, location: location)

        // Cache the result
        conditionsCache = (conditions, Date().addingTimeInterval(cacheDuration))

        return conditions
    }

    public func getAlerts(for location: CLLocation) async throws -> [WeatherAlert] {
        // Open-Meteo free tier does not include alerts.
        // Return empty array - alerts would require a different API or premium tier.
        return []
    }

    /// Clears the weather conditions cache.
    public func clearCache() {
        conditionsCache = nil
    }

    // MARK: - Private Methods

    private func buildCurrentWeatherURL(for location: CLLocation) throws -> URL {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            throw WeatherError.invalidLocation
        }

        var components = URLComponents(string: Self.baseURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.coordinate.longitude)),
            URLQueryItem(name: "current", value: Self.currentWeatherParams),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherError.invalidLocation
        }

        return url
    }

    private func performRequest(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("JogPod iOS App", forHTTPHeaderField: "User-Agent")

        do {
            return try await urlSession.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw WeatherError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw WeatherError.networkError("No internet connection")
            default:
                throw WeatherError.networkError(error.localizedDescription)
            }
        } catch {
            throw WeatherError.networkError(error.localizedDescription)
        }
    }

    private func mapToWeatherConditions(
        _ response: OpenMeteoCurrentResponse,
        location: CLLocation
    ) throws -> WeatherConditions {
        guard let current = response.current else {
            throw WeatherError.invalidResponse
        }

        // Convert wind direction degrees to compass direction
        let windDirection = compassDirection(from: current.windDirection10m ?? 0)

        // Map WMO code to description
        let conditionDescription = weatherDescription(for: current.weatherCode)

        return WeatherConditions(
            temperatureCelsius: current.temperature2m ?? 0,
            humidityPercent: current.relativeHumidity2m ?? 0,
            windSpeedKph: current.windSpeed10m ?? 0,
            windDirection: windDirection,
            windDirectionDegrees: current.windDirection10m,
            conditionCode: current.weatherCode,
            conditionDescription: conditionDescription,
            apparentTemperatureCelsius: current.apparentTemperature,
            uvIndex: nil,  // Not available in current weather params
            visibilityKm: nil,  // Not available in current weather params
            pressureHpa: current.surfacePressure,
            location: location.coordinate,
            timestamp: Date()
        )
    }

    /// Converts degrees to compass direction string.
    private func compassDirection(from degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)
        return directions[index % 16]
    }

    /// Maps WMO weather code to human-readable description.
    private func weatherDescription(for code: Int?) -> String? {
        guard let code = code else { return nil }

        switch code {
        case 0:
            return "Clear sky"
        case 1:
            return "Mainly clear"
        case 2:
            return "Partly cloudy"
        case 3:
            return "Overcast"
        case 45:
            return "Fog"
        case 48:
            return "Depositing rime fog"
        case 51:
            return "Light drizzle"
        case 53:
            return "Moderate drizzle"
        case 55:
            return "Dense drizzle"
        case 56:
            return "Light freezing drizzle"
        case 57:
            return "Dense freezing drizzle"
        case 61:
            return "Slight rain"
        case 63:
            return "Moderate rain"
        case 65:
            return "Heavy rain"
        case 66:
            return "Light freezing rain"
        case 67:
            return "Heavy freezing rain"
        case 71:
            return "Slight snow fall"
        case 73:
            return "Moderate snow fall"
        case 75:
            return "Heavy snow fall"
        case 77:
            return "Snow grains"
        case 80:
            return "Slight rain showers"
        case 81:
            return "Moderate rain showers"
        case 82:
            return "Violent rain showers"
        case 85:
            return "Slight snow showers"
        case 86:
            return "Heavy snow showers"
        case 95:
            return "Thunderstorm"
        case 96:
            return "Thunderstorm with slight hail"
        case 99:
            return "Thunderstorm with heavy hail"
        default:
            return nil
        }
    }

    /// Checks if two coordinates are within approximately 1km of each other.
    private func isNearby(_ coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Bool {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2) < 1000  // 1km threshold
    }
}

// MARK: - Open-Meteo API Response Models

/// Response from Open-Meteo current weather endpoint.
private struct OpenMeteoCurrentResponse: Decodable {
    let latitude: Double?
    let longitude: Double?
    let timezone: String?
    let current: CurrentWeather?

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone, current
    }
}

/// Current weather data from Open-Meteo.
private struct CurrentWeather: Decodable {
    let time: String?
    let temperature2m: Double?
    let relativeHumidity2m: Double?
    let apparentTemperature: Double?
    let weatherCode: Int?
    let windSpeed10m: Double?
    let windDirection10m: Double?
    let surfacePressure: Double?

    private enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case surfacePressure = "surface_pressure"
    }
}
