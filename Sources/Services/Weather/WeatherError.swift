//
//  WeatherError.swift
//  JogPod
//
//  Error types for weather service operations.
//

import Foundation

// MARK: - WeatherError

/// Errors that can occur during weather data operations.
///
/// This enum provides specific error cases for weather service failures,
/// enabling precise error handling and user-friendly error messages.
public enum WeatherError: Error, Sendable, Equatable {

    /// The location provided is invalid or missing coordinates.
    case invalidLocation

    /// The network request failed.
    case networkError(String)

    /// The API returned an invalid or unexpected response.
    case invalidResponse

    /// Failed to decode the weather data from the API response.
    case decodingError(String)

    /// The weather service is unavailable.
    case serviceUnavailable

    /// Rate limit exceeded for the weather API.
    case rateLimitExceeded

    /// The request timed out.
    case timeout

    /// An unknown error occurred.
    case unknown(String)
}

// MARK: - LocalizedError

extension WeatherError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Invalid location provided for weather lookup."

        case .networkError(let message):
            return "Network error: \(message)"

        case .invalidResponse:
            return "The weather service returned an invalid response."

        case .decodingError(let message):
            return "Failed to parse weather data: \(message)"

        case .serviceUnavailable:
            return "The weather service is currently unavailable."

        case .rateLimitExceeded:
            return "Weather API rate limit exceeded. Please try again later."

        case .timeout:
            return "The weather request timed out."

        case .unknown(let message):
            return "Weather error: \(message)"
        }
    }
}
