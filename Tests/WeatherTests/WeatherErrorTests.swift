//
//  WeatherErrorTests.swift
//  JogPod Tests
//
//  Tests for WeatherError types and localized descriptions.
//

import Testing
import Foundation
@testable import JogPod

// MARK: - WeatherError Tests

@Suite("WeatherError")
struct WeatherErrorTests {

    // MARK: - Error Cases

    @Test("invalidLocation has correct description")
    func invalidLocationDescription() {
        let error = WeatherError.invalidLocation
        #expect(error.errorDescription?.contains("Invalid location") == true)
    }

    @Test("networkError includes message")
    func networkErrorDescription() {
        let error = WeatherError.networkError("Connection refused")
        #expect(error.errorDescription?.contains("Connection refused") == true)
        #expect(error.errorDescription?.contains("Network error") == true)
    }

    @Test("invalidResponse has correct description")
    func invalidResponseDescription() {
        let error = WeatherError.invalidResponse
        #expect(error.errorDescription?.contains("invalid response") == true)
    }

    @Test("decodingError includes message")
    func decodingErrorDescription() {
        let error = WeatherError.decodingError("Missing field 'temperature'")
        #expect(error.errorDescription?.contains("Missing field") == true)
        #expect(error.errorDescription?.contains("parse") == true)
    }

    @Test("serviceUnavailable has correct description")
    func serviceUnavailableDescription() {
        let error = WeatherError.serviceUnavailable
        #expect(error.errorDescription?.contains("unavailable") == true)
    }

    @Test("rateLimitExceeded has correct description")
    func rateLimitExceededDescription() {
        let error = WeatherError.rateLimitExceeded
        #expect(error.errorDescription?.contains("rate limit") == true)
    }

    @Test("timeout has correct description")
    func timeoutDescription() {
        let error = WeatherError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("unknown includes message")
    func unknownErrorDescription() {
        let error = WeatherError.unknown("Something went wrong")
        #expect(error.errorDescription?.contains("Something went wrong") == true)
    }

    // MARK: - Equatable

    @Test("errors are equatable")
    func errorsAreEquatable() {
        #expect(WeatherError.invalidLocation == WeatherError.invalidLocation)
        #expect(WeatherError.timeout == WeatherError.timeout)
        #expect(WeatherError.networkError("test") == WeatherError.networkError("test"))
        #expect(WeatherError.networkError("a") != WeatherError.networkError("b"))
        #expect(WeatherError.invalidLocation != WeatherError.timeout)
    }

    // MARK: - Sendable

    @Test("error is Sendable")
    func errorIsSendable() async {
        let error = WeatherError.networkError("test")
        let result = await Task.detached {
            return error
        }.value
        #expect(result == error)
    }
}
