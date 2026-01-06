//
//  NetworkErrorSimulator.swift
//  JogPod
//
//  Utility for simulating various network error conditions in tests.
//  Created for JogPod Revival project.
//

import Foundation
@testable import JogPod

// MARK: - Network Error Simulator

/// Utility for simulating various network error conditions in tests.
///
/// This simulator provides pre-configured error scenarios that commonly occur
/// in network operations, making it easy to test error handling code.
///
/// ## Usage
///
/// ```swift
/// // Register a timeout error for a URL
/// NetworkErrorSimulator.simulateTimeout(for: url)
///
/// // Create a session and make a request - it will fail with timeout
/// let session = MockURLProtocol.createMockSession()
/// // request will fail...
///
/// // Clean up
/// NetworkErrorSimulator.reset()
/// ```
public enum NetworkErrorSimulator {

    // MARK: - Connection Errors

    /// Simulates a network timeout for a URL.
    public static func simulateTimeout(
        for url: URL,
        after delay: TimeInterval = 0.1
    ) {
        MockURLProtocol.register(
            response: .timeout(after: delay),
            for: url
        )
    }

    /// Simulates timeout for URLs matching a pattern.
    public static func simulateTimeout(
        forPattern pattern: String,
        after delay: TimeInterval = 0.1
    ) {
        MockURLProtocol.register(
            response: .timeout(after: delay),
            forPattern: pattern
        )
    }

    /// Simulates network connection lost.
    public static func simulateConnectionLost(for url: URL) {
        MockURLProtocol.register(
            response: .networkConnectionLost,
            for: url
        )
    }

    /// Simulates connection lost for URLs matching a pattern.
    public static func simulateConnectionLost(forPattern pattern: String) {
        MockURLProtocol.register(
            response: .networkConnectionLost,
            forPattern: pattern
        )
    }

    /// Simulates not connected to internet.
    public static func simulateNoInternet(for url: URL) {
        MockURLProtocol.register(
            response: .notConnectedToInternet,
            for: url
        )
    }

    /// Simulates no internet for all requests.
    public static func simulateNoInternetGlobally() {
        MockURLProtocol.simulatedError = URLError(.notConnectedToInternet)
    }

    /// Simulates DNS lookup failure.
    public static func simulateDNSFailure(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(error: URLError(.cannotFindHost)),
            for: url
        )
    }

    /// Simulates cannot connect to host.
    public static func simulateHostUnreachable(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(error: URLError(.cannotConnectToHost)),
            for: url
        )
    }

    // MARK: - SSL/TLS Errors

    /// Simulates SSL certificate error.
    public static func simulateCertificateError(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(error: URLError(.serverCertificateUntrusted)),
            for: url
        )
    }

    /// Simulates expired SSL certificate.
    public static func simulateExpiredCertificate(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(error: URLError(.serverCertificateHasBadDate)),
            for: url
        )
    }

    /// Simulates untrusted root certificate.
    public static func simulateUntrustedRoot(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(error: URLError(.serverCertificateHasUnknownRoot)),
            for: url
        )
    }

    // MARK: - HTTP Errors

    /// Simulates HTTP 400 Bad Request.
    public static func simulateBadRequest(
        for url: URL,
        message: String = "Bad Request"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 400, message: message),
            for: url
        )
    }

    /// Simulates HTTP 401 Unauthorized.
    public static func simulateUnauthorized(
        for url: URL,
        message: String = "Unauthorized"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 401, message: message),
            for: url
        )
    }

    /// Simulates HTTP 403 Forbidden.
    public static func simulateForbidden(
        for url: URL,
        message: String = "Forbidden"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 403, message: message),
            for: url
        )
    }

    /// Simulates HTTP 404 Not Found.
    public static func simulateNotFound(
        for url: URL,
        message: String = "Not Found"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 404, message: message),
            for: url
        )
    }

    /// Simulates HTTP 429 Too Many Requests (Rate Limiting).
    public static func simulateRateLimiting(
        for url: URL,
        retryAfter: Int = 3600
    ) {
        MockURLProtocol.register(
            response: .rateLimited(retryAfter: retryAfter),
            for: url
        )
    }

    /// Simulates HTTP 500 Internal Server Error.
    public static func simulateServerError(
        for url: URL,
        message: String = "Internal Server Error"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 500, message: message),
            for: url
        )
    }

    /// Simulates HTTP 502 Bad Gateway.
    public static func simulateBadGateway(
        for url: URL,
        message: String = "Bad Gateway"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 502, message: message),
            for: url
        )
    }

    /// Simulates HTTP 503 Service Unavailable.
    public static func simulateServiceUnavailable(
        for url: URL,
        message: String = "Service Unavailable"
    ) {
        MockURLProtocol.register(
            response: .httpError(statusCode: 503, message: message),
            for: url
        )
    }

    // MARK: - Data Errors

    /// Simulates an empty response.
    public static func simulateEmptyResponse(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(data: nil, statusCode: 200),
            for: url
        )
    }

    /// Simulates invalid JSON response.
    public static func simulateInvalidJSON(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                data: "{ invalid json }".data(using: .utf8),
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            ),
            for: url
        )
    }

    /// Simulates truncated response.
    public static func simulateTruncatedResponse(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                data: "{ \"partial\": ".data(using: .utf8),
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            ),
            for: url
        )
    }

    /// Simulates wrong content type.
    public static func simulateWrongContentType(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                data: "<html><body>Not JSON</body></html>".data(using: .utf8),
                statusCode: 200,
                headers: ["Content-Type": "text/html"]
            ),
            for: url
        )
    }

    // MARK: - Intermittent/Flaky Errors

    /// Creates a response that alternates between success and failure.
    public static func createIntermittentResponse(
        successResponse: MockResponse,
        failureResponse: MockResponse,
        failureRate: Double = 0.5
    ) -> MockResponse {
        // Note: For true intermittent behavior, you would need state tracking.
        // This simplified version randomly chooses based on rate.
        if Double.random(in: 0...1) < failureRate {
            return failureResponse
        }
        return successResponse
    }

    // MARK: - Slow Network Simulation

    /// Simulates slow network with delayed response.
    public static func simulateSlowNetwork(
        for url: URL,
        data: Data,
        delay: TimeInterval = 5.0
    ) {
        MockURLProtocol.register(
            response: MockResponse(
                data: data,
                statusCode: 200,
                delay: delay
            ),
            for: url
        )
    }

    /// Sets global response delay for all requests.
    public static func setGlobalDelay(_ delay: TimeInterval) {
        MockURLProtocol.globalDelay = delay
    }

    // MARK: - OAuth-Specific Errors

    /// Simulates OAuth invalid grant error.
    public static func simulateOAuthInvalidGrant(for url: URL) {
        MockURLProtocol.register(
            response: .oauthError(
                error: "invalid_grant",
                description: "The provided authorization grant is invalid, expired, revoked, or does not match the redirect URI"
            ),
            for: url
        )
    }

    /// Simulates OAuth invalid client error.
    public static func simulateOAuthInvalidClient(for url: URL) {
        MockURLProtocol.register(
            response: .oauthError(
                error: "invalid_client",
                description: "Client authentication failed"
            ),
            for: url
        )
    }

    /// Simulates OAuth invalid scope error.
    public static func simulateOAuthInvalidScope(for url: URL) {
        MockURLProtocol.register(
            response: .oauthError(
                error: "invalid_scope",
                description: "The requested scope is invalid, unknown, or malformed"
            ),
            for: url
        )
    }

    /// Simulates OAuth access denied error.
    public static func simulateOAuthAccessDenied(for url: URL) {
        MockURLProtocol.register(
            response: .oauthError(
                error: "access_denied",
                description: "The resource owner or authorization server denied the request"
            ),
            for: url
        )
    }

    // MARK: - Fitbit-Specific Errors

    /// Simulates Fitbit API rate limit exceeded.
    public static func simulateFitbitRateLimit(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                jsonString: """
                {
                    "errors": [{
                        "errorType": "request",
                        "message": "Too many requests. You have exceeded your rate limit."
                    }],
                    "success": false
                }
                """,
                statusCode: 429,
                headers: [
                    "Content-Type": "application/json",
                    "Retry-After": "3600"
                ]
            ),
            for: url
        )
    }

    /// Simulates Fitbit insufficient permissions error.
    public static func simulateFitbitInsufficientPermissions(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                jsonString: """
                {
                    "errors": [{
                        "errorType": "insufficient_permissions",
                        "message": "This application does not have permission to access the requested data."
                    }],
                    "success": false
                }
                """,
                statusCode: 403
            ),
            for: url
        )
    }

    // MARK: - Feed Parsing Errors

    /// Simulates invalid RSS feed.
    public static func simulateInvalidFeed(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                xmlString: XMLFeedFixtures.invalidXML,
                statusCode: 200
            ),
            for: url
        )
    }

    /// Simulates non-feed XML response.
    public static func simulateNonFeedXML(for url: URL) {
        MockURLProtocol.register(
            response: MockResponse(
                xmlString: XMLFeedFixtures.nonFeedXML,
                statusCode: 200
            ),
            for: url
        )
    }

    // MARK: - Reset

    /// Resets all simulated errors.
    public static func reset() {
        MockURLProtocol.reset()
    }
}

// MARK: - Error Scenario Builder

/// Builder for creating complex error scenarios.
public final class ErrorScenarioBuilder {

    private var urlResponses: [URL: MockResponse] = [:]
    private var patternResponses: [String: MockResponse] = [:]
    private var globalError: Error?
    private var globalDelay: TimeInterval = 0

    public init() {}

    /// Adds a response for a specific URL.
    @discardableResult
    public func when(url: URL, returns response: MockResponse) -> Self {
        urlResponses[url] = response
        return self
    }

    /// Adds a response for URLs matching a pattern.
    @discardableResult
    public func when(pattern: String, returns response: MockResponse) -> Self {
        patternResponses[pattern] = response
        return self
    }

    /// Sets a global error for all requests.
    @discardableResult
    public func withGlobalError(_ error: Error) -> Self {
        globalError = error
        return self
    }

    /// Sets a global delay for all requests.
    @discardableResult
    public func withGlobalDelay(_ delay: TimeInterval) -> Self {
        globalDelay = delay
        return self
    }

    /// Applies the configured scenario to MockURLProtocol.
    public func apply() {
        MockURLProtocol.reset()

        for (url, response) in urlResponses {
            MockURLProtocol.register(response: response, for: url)
        }

        for (pattern, response) in patternResponses {
            MockURLProtocol.register(response: response, forPattern: pattern)
        }

        MockURLProtocol.simulatedError = globalError
        MockURLProtocol.globalDelay = globalDelay
    }

    /// Resets the builder.
    public func reset() {
        urlResponses.removeAll()
        patternResponses.removeAll()
        globalError = nil
        globalDelay = 0
    }
}

// MARK: - Predefined Scenarios

extension ErrorScenarioBuilder {

    /// Creates a scenario simulating offline state.
    public static var offline: ErrorScenarioBuilder {
        let builder = ErrorScenarioBuilder()
        builder.globalError = URLError(.notConnectedToInternet)
        return builder
    }

    /// Creates a scenario simulating server maintenance.
    public static var serverMaintenance: ErrorScenarioBuilder {
        let builder = ErrorScenarioBuilder()
        builder.patternResponses[""] = .httpError(statusCode: 503, message: "Service Temporarily Unavailable")
        return builder
    }

    /// Creates a scenario simulating slow network.
    public static func slowNetwork(delay: TimeInterval = 5.0) -> ErrorScenarioBuilder {
        let builder = ErrorScenarioBuilder()
        builder.globalDelay = delay
        return builder
    }

    /// Creates a scenario simulating expired OAuth session.
    public static var expiredSession: ErrorScenarioBuilder {
        let builder = ErrorScenarioBuilder()
        builder.patternResponses["api.fitbit.com"] = .httpError(statusCode: 401, message: "Unauthorized")
        return builder
    }
}
