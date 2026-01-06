//
//  WeatherService.swift
//  JogPod
//
//  Main weather service facade for the application.
//

import Foundation
import CoreLocation

// MARK: - WeatherService

/// Main weather service for the JogPod application.
///
/// This actor provides a high-level interface for fetching weather data,
/// abstracting away the underlying weather API provider. It handles:
/// - Provider selection and fallback
/// - Caching and rate limiting
/// - Location-based weather queries
/// - Integration with workout announcements
///
/// ## Legacy Equivalence
///
/// This service replaces the legacy `WeatherInfo` class from the Objective-C
/// codebase, which used the now-deprecated Weather Underground API.
///
/// **Legacy pattern:**
/// ```objc
/// WeatherInfo *weather = [WeatherInfo new];
/// [weather fetchLocalWeather:location callBack:self];
/// ```
///
/// **Modern pattern:**
/// ```swift
/// let weather = WeatherService.shared
/// let conditions = try await weather.getCurrentConditions(for: location)
/// ```
///
/// ## Thread Safety
///
/// This service is implemented as an actor and can be safely accessed from
/// any context. All state mutations are serialized.
///
/// ## Usage Example
///
/// ```swift
/// // Get weather for current location
/// let conditions = try await WeatherService.shared.getCurrentConditions(
///     for: currentLocation
/// )
///
/// // Convert to announcement format
/// let weatherData = conditions.toWeatherData(useMetric: false)
/// ```
public actor WeatherService {

    // MARK: - Shared Instance

    /// Shared instance of the weather service.
    public static let shared = WeatherService()

    // MARK: - Properties

    /// The underlying weather service provider.
    private var provider: any WeatherServiceProtocol

    /// Last fetched weather conditions.
    private var lastConditions: WeatherConditions?

    /// Last fetch error for debugging.
    private var lastError: WeatherError?

    /// Whether a fetch is currently in progress.
    private var isFetching = false

    // MARK: - Configuration

    /// Minimum interval between weather fetches in seconds.
    /// Prevents excessive API calls during rapid location updates.
    private let minimumFetchInterval: TimeInterval = 60

    /// Last successful fetch timestamp.
    private var lastFetchTime: Date?

    // MARK: - Initialization

    /// Creates a new weather service with the default provider.
    public init() {
        self.provider = OpenMeteoWeatherService()
    }

    /// Creates a new weather service with a custom provider.
    ///
    /// - Parameter provider: The weather service provider to use.
    public init(provider: any WeatherServiceProtocol) {
        self.provider = provider
    }

    // MARK: - Public API

    /// Fetches current weather conditions for a location.
    ///
    /// This method respects rate limiting and may return cached data
    /// if a recent fetch was successful.
    ///
    /// - Parameter location: The location to get weather for.
    /// - Returns: Current weather conditions.
    /// - Throws: `WeatherError` if the fetch fails.
    public func getCurrentConditions(for location: CLLocation) async throws -> WeatherConditions {
        // Check if we should throttle the request
        if let lastFetch = lastFetchTime,
           let cached = lastConditions,
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            return cached
        }

        // Prevent concurrent fetches
        guard !isFetching else {
            if let cached = lastConditions {
                return cached
            }
            throw WeatherError.serviceUnavailable
        }

        isFetching = true
        defer { isFetching = false }

        do {
            let conditions = try await provider.getCurrentConditions(for: location)
            lastConditions = conditions
            lastFetchTime = Date()
            lastError = nil
            return conditions
        } catch let error as WeatherError {
            lastError = error
            throw error
        } catch {
            let weatherError = WeatherError.unknown(error.localizedDescription)
            lastError = weatherError
            throw weatherError
        }
    }

    /// Fetches weather alerts for a location.
    ///
    /// - Parameter location: The location to get alerts for.
    /// - Returns: An array of active weather alerts.
    /// - Throws: `WeatherError` if the fetch fails.
    public func getAlerts(for location: CLLocation) async throws -> [WeatherAlert] {
        try await provider.getAlerts(for: location)
    }

    /// Returns the last successfully fetched weather conditions, if any.
    ///
    /// This is useful for displaying cached weather data when a fresh
    /// fetch is not required or when offline.
    public var cachedConditions: WeatherConditions? {
        lastConditions
    }

    /// Returns the last weather fetch error, if any.
    ///
    /// Useful for debugging or displaying error states.
    public var lastFetchError: WeatherError? {
        lastError
    }

    /// The name of the current weather provider.
    public var currentProviderName: String {
        provider.providerName
    }

    /// Clears any cached weather data.
    public func clearCache() {
        lastConditions = nil
        lastFetchTime = nil
        lastError = nil
    }

    /// Changes the weather service provider.
    ///
    /// - Parameter newProvider: The new provider to use.
    public func setProvider(_ newProvider: any WeatherServiceProtocol) {
        provider = newProvider
        clearCache()
    }

    // MARK: - Convenience Methods for Workouts

    /// Fetches weather data formatted for workout announcements.
    ///
    /// This convenience method combines fetching weather and converting
    /// to the format expected by `AnnouncementFormatter`.
    ///
    /// - Parameters:
    ///   - location: The location to get weather for.
    ///   - useMetric: Whether to use metric units. Defaults to system preference.
    /// - Returns: Weather data for announcements.
    /// - Throws: `WeatherError` if the fetch fails.
    public func getWeatherForAnnouncement(
        for location: CLLocation,
        useMetric: Bool = Locale.current.measurementSystem == .metric
    ) async throws -> WeatherData {
        let conditions = try await getCurrentConditions(for: location)
        return conditions.toWeatherData(useMetric: useMetric)
    }

    /// Checks if outdoor conditions are suitable for running.
    ///
    /// Returns advisory information based on current weather conditions
    /// that may affect workout safety or comfort.
    ///
    /// - Parameter location: The location to check.
    /// - Returns: A tuple of (isSuitable, advisoryMessage).
    public func checkWorkoutConditions(
        for location: CLLocation
    ) async throws -> (suitable: Bool, advisory: String?) {
        let conditions = try await getCurrentConditions(for: location)

        var advisories: [String] = []

        // Check temperature extremes
        if conditions.temperatureCelsius > 35 {
            advisories.append("Extreme heat warning: \(Int(conditions.temperatureFahrenheit))F")
        } else if conditions.temperatureCelsius < -10 {
            advisories.append("Extreme cold warning: \(Int(conditions.temperatureFahrenheit))F")
        }

        // Check wind
        if conditions.windSpeedKph > 50 {
            advisories.append("High wind advisory: \(Int(conditions.windSpeedKph)) km/h")
        }

        // Check weather code for severe conditions
        if let code = conditions.conditionCode {
            switch code {
            case 95, 96, 99:
                advisories.append("Thunderstorm warning")
            case 65, 67, 82:
                advisories.append("Heavy precipitation expected")
            case 75, 86:
                advisories.append("Heavy snow warning")
            default:
                break
            }
        }

        let suitable = advisories.isEmpty
        let advisory = advisories.isEmpty ? nil : advisories.joined(separator: ". ")

        return (suitable, advisory)
    }
}

// MARK: - Testing Support

#if DEBUG
extension WeatherService {

    /// Creates a weather service with a mock provider for testing.
    ///
    /// - Parameter mockConditions: The conditions the mock should return.
    /// - Returns: A weather service configured for testing.
    public static func forTesting(
        returning mockConditions: WeatherConditions
    ) -> WeatherService {
        WeatherService(provider: MockWeatherProvider(conditions: mockConditions))
    }
}

/// Mock weather provider for testing.
private actor MockWeatherProvider: WeatherServiceProtocol {
    let conditions: WeatherConditions

    init(conditions: WeatherConditions) {
        self.conditions = conditions
    }

    nonisolated var providerName: String { "Mock" }
    nonisolated var requiresAPIKey: Bool { false }

    func getCurrentConditions(for location: CLLocation) async throws -> WeatherConditions {
        conditions
    }

    func getAlerts(for location: CLLocation) async throws -> [WeatherAlert] {
        []
    }
}
#endif
