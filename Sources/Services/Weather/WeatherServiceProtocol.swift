//
//  WeatherServiceProtocol.swift
//  JogPod
//
//  Protocol definition for weather service providers.
//

import Foundation
import CoreLocation

// MARK: - WeatherServiceProtocol

/// Protocol defining the interface for weather service providers.
///
/// This protocol allows for multiple weather service implementations
/// (e.g., Open-Meteo, Apple WeatherKit) to be used interchangeably.
///
/// ## Implementation Notes
///
/// Conforming types should:
/// - Use async/await for all network operations
/// - Handle caching appropriately to minimize API calls
/// - Gracefully degrade when network is unavailable
/// - Provide meaningful errors via `WeatherError`
///
/// ## Example Usage
///
/// ```swift
/// let service: WeatherServiceProtocol = OpenMeteoWeatherService()
/// let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
///
/// do {
///     let conditions = try await service.getCurrentConditions(for: location)
///     print("Temperature: \(conditions.temperatureCelsius)C")
/// } catch {
///     print("Weather fetch failed: \(error)")
/// }
/// ```
public protocol WeatherServiceProtocol: Sendable {

    /// Fetches current weather conditions for a location.
    ///
    /// - Parameter location: The location to get weather for.
    /// - Returns: Current weather conditions.
    /// - Throws: `WeatherError` if the fetch fails.
    func getCurrentConditions(for location: CLLocation) async throws -> WeatherConditions

    /// Fetches active weather alerts for a location.
    ///
    /// - Parameter location: The location to get alerts for.
    /// - Returns: An array of active weather alerts, which may be empty.
    /// - Throws: `WeatherError` if the fetch fails.
    func getAlerts(for location: CLLocation) async throws -> [WeatherAlert]

    /// The name of the weather service provider.
    var providerName: String { get }

    /// Whether this service requires an API key.
    var requiresAPIKey: Bool { get }
}

// MARK: - Default Implementations

extension WeatherServiceProtocol {

    /// Default implementation that returns an empty array.
    ///
    /// Override in implementations that support alerts.
    public func getAlerts(for location: CLLocation) async throws -> [WeatherAlert] {
        []
    }
}
