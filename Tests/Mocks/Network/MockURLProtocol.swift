//
//  MockURLProtocol.swift
//  JogPod
//
//  Mock URL protocol for intercepting network requests in tests.
//  Created for JogPod Revival project.
//

import Foundation

// MARK: - Mock URL Protocol

/// A custom URLProtocol subclass that intercepts network requests for testing.
///
/// This protocol allows tests to provide predetermined responses for network requests
/// without making actual network calls. It supports:
///
/// - Custom response data, status codes, and headers
/// - Error simulation for network failure testing
/// - Request inspection and verification
/// - Response delays for timeout testing
///
/// ## Usage
///
/// ```swift
/// // Configure mock response
/// MockURLProtocol.mockResponses[url] = MockResponse(
///     data: jsonData,
///     statusCode: 200,
///     headers: ["Content-Type": "application/json"]
/// )
///
/// // Create session with mock protocol
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
///
/// // Make request - it will use mock data
/// let (data, response) = try await session.data(from: url)
/// ```
public final class MockURLProtocol: URLProtocol {

    // MARK: - Static Properties

    /// Dictionary mapping URLs to their mock responses.
    public static var mockResponses: [URL: MockResponse] = [:]

    /// Dictionary mapping URL patterns to their mock responses.
    /// Patterns are matched using prefix matching on the URL string.
    public static var mockResponsePatterns: [String: MockResponse] = [:]

    /// Recorded requests for verification in tests.
    public private(set) static var recordedRequests: [URLRequest] = []

    /// Error to simulate for all requests (overrides specific responses).
    public static var simulatedError: Error?

    /// Global delay to add to all responses (in seconds).
    public static var globalDelay: TimeInterval = 0

    /// Lock for thread-safe access to static properties.
    private static let lock = NSLock()

    // MARK: - URLProtocol Overrides

    public override class func canInit(with request: URLRequest) -> Bool {
        // Handle all requests when registered
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        // Record the request
        Self.lock.lock()
        Self.recordedRequests.append(request)
        Self.lock.unlock()

        // Check for simulated error
        if let error = Self.simulatedError {
            deliverError(error)
            return
        }

        // Find matching response
        guard let mockResponse = findMockResponse(for: request) else {
            deliverError(MockURLProtocolError.noMockResponse(for: request.url))
            return
        }

        // Apply delay if configured
        let delay = mockResponse.delay ?? Self.globalDelay
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }

        // Check for response-specific error
        if let error = mockResponse.error {
            deliverError(error)
            return
        }

        // Deliver the mock response
        deliverResponse(mockResponse)
    }

    public override func stopLoading() {
        // No-op for mock
    }

    // MARK: - Private Methods

    private func findMockResponse(for request: URLRequest) -> MockResponse? {
        guard let url = request.url else { return nil }

        Self.lock.lock()
        defer { Self.lock.unlock() }

        // First try exact URL match
        if let response = Self.mockResponses[url] {
            return response
        }

        // Then try pattern matching
        let urlString = url.absoluteString
        for (pattern, response) in Self.mockResponsePatterns {
            if urlString.contains(pattern) {
                return response
            }
        }

        return nil
    }

    private func deliverResponse(_ mockResponse: MockResponse) {
        guard let url = request.url else {
            deliverError(MockURLProtocolError.invalidRequest)
            return
        }

        // Create HTTP response
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockResponse.headers
        )!

        // Deliver response
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)

        // Deliver data
        if let data = mockResponse.data {
            client?.urlProtocol(self, didLoad: data)
        }

        // Complete
        client?.urlProtocolDidFinishLoading(self)
    }

    private func deliverError(_ error: Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }

    // MARK: - Public Static Methods

    /// Resets all mock configuration.
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }

        mockResponses.removeAll()
        mockResponsePatterns.removeAll()
        recordedRequests.removeAll()
        simulatedError = nil
        globalDelay = 0
    }

    /// Registers a mock response for a specific URL.
    public static func register(
        response: MockResponse,
        for url: URL
    ) {
        lock.lock()
        defer { lock.unlock() }
        mockResponses[url] = response
    }

    /// Registers a mock response for URLs matching a pattern.
    public static func register(
        response: MockResponse,
        forPattern pattern: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        mockResponsePatterns[pattern] = response
    }

    /// Creates a URLSession configured with MockURLProtocol.
    public static func createMockSession(
        configuration: URLSessionConfiguration = .ephemeral
    ) -> URLSession {
        let config = configuration
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Returns the last recorded request, if any.
    public static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests.last
    }

    /// Returns the number of recorded requests.
    public static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests.count
    }
}

// MARK: - Mock Response

/// Represents a mock HTTP response for testing.
public struct MockResponse: Sendable {

    /// The response body data.
    public let data: Data?

    /// The HTTP status code.
    public let statusCode: Int

    /// Response headers.
    public let headers: [String: String]

    /// Optional delay before delivering the response (in seconds).
    public let delay: TimeInterval?

    /// Optional error to simulate instead of delivering a response.
    public let error: Error?

    /// Creates a mock response with the specified parameters.
    public init(
        data: Data? = nil,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        delay: TimeInterval? = nil,
        error: Error? = nil
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.delay = delay
        self.error = error
    }

    /// Creates a mock response from a JSON-encodable object.
    public init<T: Encodable>(
        json: T,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        delay: TimeInterval? = nil
    ) throws {
        let encoder = JSONEncoder()
        self.data = try encoder.encode(json)
        self.statusCode = statusCode

        var finalHeaders = headers
        if finalHeaders["Content-Type"] == nil {
            finalHeaders["Content-Type"] = "application/json"
        }
        self.headers = finalHeaders
        self.delay = delay
        self.error = nil
    }

    /// Creates a mock response from a JSON string.
    public init(
        jsonString: String,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        delay: TimeInterval? = nil
    ) {
        self.data = jsonString.data(using: .utf8)
        self.statusCode = statusCode

        var finalHeaders = headers
        if finalHeaders["Content-Type"] == nil {
            finalHeaders["Content-Type"] = "application/json"
        }
        self.headers = finalHeaders
        self.delay = delay
        self.error = nil
    }

    /// Creates a mock response from an XML string.
    public init(
        xmlString: String,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        delay: TimeInterval? = nil
    ) {
        self.data = xmlString.data(using: .utf8)
        self.statusCode = statusCode

        var finalHeaders = headers
        if finalHeaders["Content-Type"] == nil {
            finalHeaders["Content-Type"] = "application/xml"
        }
        self.headers = finalHeaders
        self.delay = delay
        self.error = nil
    }

    /// Creates a mock error response.
    public static func error(_ error: Error) -> MockResponse {
        MockResponse(error: error)
    }

    /// Creates a mock timeout response.
    public static func timeout(after delay: TimeInterval = 0.1) -> MockResponse {
        MockResponse(
            error: URLError(.timedOut),
            delay: delay
        )
    }

    /// Creates a mock network connection failure.
    public static var networkConnectionLost: MockResponse {
        MockResponse(error: URLError(.networkConnectionLost))
    }

    /// Creates a mock "not connected to internet" error.
    public static var notConnectedToInternet: MockResponse {
        MockResponse(error: URLError(.notConnectedToInternet))
    }

    /// Creates a mock HTTP error response.
    public static func httpError(
        statusCode: Int,
        message: String? = nil
    ) -> MockResponse {
        let data: Data?
        if let message = message {
            data = """
            {"error": "\(message)"}
            """.data(using: .utf8)
        } else {
            data = nil
        }

        return MockResponse(
            data: data,
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"]
        )
    }

    // Implement Sendable manually since Error is not Sendable
    private init(error: Error?, delay: TimeInterval? = nil) {
        self.data = nil
        self.statusCode = 0
        self.headers = [:]
        self.delay = delay
        self.error = error
    }
}

// MARK: - Mock URL Protocol Error

/// Errors specific to MockURLProtocol.
public enum MockURLProtocolError: Error, LocalizedError {
    case noMockResponse(for: URL?)
    case invalidRequest

    public var errorDescription: String? {
        switch self {
        case .noMockResponse(let url):
            return "No mock response configured for URL: \(url?.absoluteString ?? "nil")"
        case .invalidRequest:
            return "The request was invalid"
        }
    }
}

// MARK: - Convenience Extensions

extension MockResponse {

    /// Creates a successful JSON response for Fitbit profile.
    public static func fitbitProfile(
        userId: String = "ABC123",
        displayName: String = "Test User"
    ) -> MockResponse {
        MockResponse(jsonString: """
        {
            "user": {
                "encodedId": "\(userId)",
                "displayName": "\(displayName)",
                "fullName": "Test User Full Name",
                "avatar": "https://example.com/avatar.jpg",
                "memberSince": "2020-01-01",
                "timezone": "America/New_York"
            }
        }
        """)
    }

    /// Creates a successful OAuth token response.
    public static func oauthToken(
        accessToken: String = "mock_access_token",
        refreshToken: String = "mock_refresh_token",
        expiresIn: Int = 28800
    ) -> MockResponse {
        MockResponse(jsonString: """
        {
            "access_token": "\(accessToken)",
            "refresh_token": "\(refreshToken)",
            "token_type": "Bearer",
            "expires_in": \(expiresIn),
            "scope": "activity profile heartrate location",
            "user_id": "ABC123"
        }
        """)
    }

    /// Creates an OAuth error response.
    public static func oauthError(
        error: String = "invalid_grant",
        description: String = "The provided authorization grant is invalid"
    ) -> MockResponse {
        MockResponse(
            jsonString: """
            {
                "error": "\(error)",
                "error_description": "\(description)"
            }
            """,
            statusCode: 400
        )
    }

    /// Creates a rate limit exceeded response.
    public static func rateLimited(retryAfter: Int = 3600) -> MockResponse {
        MockResponse(
            jsonString: """
            {
                "error": "rate_limit_exceeded",
                "error_description": "Rate limit exceeded"
            }
            """,
            statusCode: 429,
            headers: [
                "Content-Type": "application/json",
                "Retry-After": "\(retryAfter)"
            ]
        )
    }
}
