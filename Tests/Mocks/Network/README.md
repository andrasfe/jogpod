# Network Mocking Infrastructure

This directory contains mock implementations and test utilities for external API dependencies in the JogPod application.

## Overview

The mocking infrastructure enables testing of network-dependent code without making actual network requests. It provides:

- **MockURLProtocol**: Intercepts URLSession requests with configurable responses
- **MockFitbitOAuthProvider**: Simulates Fitbit OAuth authentication flows
- **MockFeedService**: Provides predetermined RSS/Atom feed responses
- **MockCredentialsProvider**: In-memory credential storage for testing
- **NetworkErrorSimulator**: Pre-configured error scenarios
- **ResponseFixtures**: Sample JSON/XML responses for common API endpoints

## Quick Start

### Basic URL Mocking

```swift
import XCTest
@testable import JogPod

class MyNetworkTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchProfile() async throws {
        // Configure mock response
        let url = URL(string: "https://api.fitbit.com/1/user/-/profile.json")!
        MockURLProtocol.register(
            response: .fitbitProfile(userId: "TEST123"),
            for: url
        )

        // Create session with mock protocol
        let session = MockURLProtocol.createMockSession()

        // Make request - will use mock data
        let (data, response) = try await session.data(from: url)

        // Verify
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }
}
```

### OAuth Flow Testing

```swift
@MainActor
func testSuccessfulAuth() async throws {
    let mockProvider = MockFitbitOAuthProvider()
    mockProvider.simulateSuccessfulAuth()

    let context = MockPresentationContextProvider()
    let profile = try await mockProvider.authenticate(presentationContext: context)

    XCTAssertEqual(profile.userId, "MOCK123")
    XCTAssertEqual(mockProvider.authenticateCallCount, 1)
}

@MainActor
func testUserCancellation() async {
    let mockProvider = MockFitbitOAuthProvider()
    mockProvider.simulateAuthFailure(error: .userCancelled)

    let context = MockPresentationContextProvider()

    do {
        _ = try await mockProvider.authenticate(presentationContext: context)
        XCTFail("Should have thrown")
    } catch let error as OAuthError {
        XCTAssertEqual(error, .userCancelled)
    }
}
```

### Feed Service Testing

```swift
func testFetchPodcastFeed() async throws {
    let mockService = MockFeedService()
    mockService.mockFeed = MockFeedFixtures.samplePodcastFeed

    let url = URL(string: "https://example.com/feed.xml")!
    let feed = try await mockService.fetchFeed(from: url)

    XCTAssertEqual(feed.info.title, "Running with Tech")
    XCTAssertEqual(feed.items.count, 3)
}

func testFeedNetworkError() async {
    let mockService = MockFeedService()
    mockService.simulateNetworkError()

    let url = URL(string: "https://example.com/feed.xml")!

    do {
        _ = try await mockService.fetchFeed(from: url)
        XCTFail("Should have thrown")
    } catch let error as FeedParsingError {
        XCTAssertTrue(error.isNetworkError)
    }
}
```

### Credentials Testing

```swift
func testCredentialsStorage() throws {
    let mockCredentials = MockCredentialsProvider()
    mockCredentials.configureFitbitAppCredentials()

    let clientId = try mockCredentials.credential(for: .fitbitConsumerKey)
    XCTAssertEqual(clientId, "test_client_id")
    XCTAssertEqual(mockCredentials.getCallCount, 1)
}
```

### Error Simulation

```swift
func testTimeoutHandling() async {
    NetworkErrorSimulator.simulateTimeout(for: apiURL, after: 0.1)

    // Your code under test should handle the timeout appropriately
}

func testRateLimiting() async {
    NetworkErrorSimulator.simulateRateLimiting(for: apiURL, retryAfter: 3600)

    // Your code should detect rate limiting and handle accordingly
}

// Using ErrorScenarioBuilder for complex scenarios
func testComplexScenario() async {
    ErrorScenarioBuilder.offline.apply()

    // All requests will fail with "not connected to internet"
}
```

## File Reference

| File | Purpose |
|------|---------|
| `MockURLProtocol.swift` | Custom URLProtocol for intercepting network requests |
| `MockFitbitOAuthProvider.swift` | Mock OAuth provider, presentation context, and OAuth service |
| `MockFeedService.swift` | Mock RSS/Atom feed service with sample fixtures |
| `MockCredentialsProvider.swift` | In-memory credentials storage |
| `NetworkErrorSimulator.swift` | Pre-configured error scenarios |
| `ResponseFixtures.swift` | Sample JSON/XML response data |

## Best Practices

1. **Always reset mocks** in `setUp()` and `tearDown()` to prevent test pollution
2. **Use specific URLs** when possible to avoid catching unintended requests
3. **Verify call counts** to ensure your code is making expected network calls
4. **Test error paths** using the various error simulation methods
5. **Use fixtures** for consistent, reproducible test data

## Adding New Mocks

When adding new external API dependencies:

1. Create a mock implementation that conforms to the service protocol
2. Add call tracking properties for verification
3. Add configuration properties for success/failure scenarios
4. Add helper methods for common test scenarios
5. Add sample response fixtures if needed
6. Update this README with usage examples
