//
//  HealthKitAuthorizationTests.swift
//  JogPodTests
//
//  Tests for HealthKit authorization request and status checking scenarios.
//

import XCTest
import HealthKit
@testable import JogPod

final class HealthKitAuthorizationTests: XCTestCase {

    // MARK: - Properties

    var mockService: MockHealthKitService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockService = MockHealthKitService()
    }

    override func tearDown() async throws {
        mockService = nil
        try await super.tearDown()
    }

    // MARK: - Authorization Status Tests

    func testAuthorizationStatusNotDetermined() async {
        // Given
        await mockService.setAuthorizationStatus(.notDetermined)

        // When
        let status = await mockService.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .notDetermined)
        XCTAssertEqual(await mockService.callCount(for: "checkAuthorizationStatus"), 1)
    }

    func testAuthorizationStatusAuthorized() async {
        // Given
        await mockService.setAuthorizationStatus(.authorized)

        // When
        let status = await mockService.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .authorized)
    }

    func testAuthorizationStatusDenied() async {
        // Given
        await mockService.setAuthorizationStatus(.denied)

        // When
        let status = await mockService.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .denied)
    }

    func testAuthorizationStatusUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When
        let status = await mockService.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .unavailable)
    }

    // MARK: - Authorization Request Success Tests

    func testRequestAuthorizationSuccess() async throws {
        // Given
        await mockService.setAuthorizationStatus(.notDetermined)

        // When
        try await mockService.requestAuthorization()

        // Then
        XCTAssertEqual(await mockService.callCount(for: "requestAuthorization"), 1)
        let requests = await mockService.authorizationRequests
        XCTAssertEqual(requests.count, 1)
    }

    func testMultipleAuthorizationRequests() async throws {
        // Given
        await mockService.setAuthorizationStatus(.notDetermined)

        // When
        try await mockService.requestAuthorization()
        try await mockService.requestAuthorization()
        try await mockService.requestAuthorization()

        // Then
        XCTAssertEqual(await mockService.callCount(for: "requestAuthorization"), 3)
        let requests = await mockService.authorizationRequests
        XCTAssertEqual(requests.count, 3)
    }

    // MARK: - Authorization Request Failure Tests

    func testRequestAuthorizationFailsWhenHealthKitUnavailable() async {
        // Given
        await mockService.setAvailable(false)

        // When/Then
        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .healthKitNotAvailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequestAuthorizationFailsWithAuthorizationDeniedError() async {
        // Given
        await mockService.setAuthorizationError(.authorizationDenied)

        // When/Then
        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequestAuthorizationFailsWithAuthorizationFailedError() async {
        // Given
        let expectedReason = "Network connection lost"
        await mockService.setAuthorizationError(.authorizationFailed(expectedReason))

        // When/Then
        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            if case .authorizationFailed(let reason) = error {
                XCTAssertEqual(reason, expectedReason)
            } else {
                XCTFail("Expected authorizationFailed error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRequestAuthorizationFailsWithNotGrantedError() async {
        // Given
        await mockService.setAuthorizationError(.authorizationNotGranted)

        // When/Then
        do {
            try await mockService.requestAuthorization()
            XCTFail("Expected error to be thrown")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .authorizationNotGranted)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Authorization State Transition Tests

    func testAuthorizationStateTransitionFromNotDeterminedToAuthorized() async throws {
        // Given
        await mockService.setAuthorizationStatus(.notDetermined)
        let initialStatus = await mockService.checkAuthorizationStatus()
        XCTAssertEqual(initialStatus, .notDetermined)

        // When
        try await mockService.requestAuthorization()
        await mockService.setAuthorizationStatus(.authorized)

        // Then
        let finalStatus = await mockService.checkAuthorizationStatus()
        XCTAssertEqual(finalStatus, .authorized)
    }

    func testAuthorizationStateTransitionFromNotDeterminedToDenied() async throws {
        // Given
        await mockService.setAuthorizationStatus(.notDetermined)

        // When
        await mockService.setAuthorizationStatus(.denied)

        // Then
        let status = await mockService.checkAuthorizationStatus()
        XCTAssertEqual(status, .denied)
    }

    // MARK: - Authorization with Delay Tests

    func testAuthorizationRequestWithDelay() async throws {
        // Given
        await mockService.setOperationDelay(0.1)

        // When
        let startTime = Date()
        try await mockService.requestAuthorization()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }

    func testAuthorizationStatusCheckWithDelay() async {
        // Given
        await mockService.setOperationDelay(0.1)
        await mockService.setAuthorizationStatus(.authorized)

        // When
        let startTime = Date()
        _ = await mockService.checkAuthorizationStatus()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }

    // MARK: - Method Call Verification Tests

    func testAuthorizationMethodCallTracking() async throws {
        // Given
        await mockService.reset()

        // When
        _ = await mockService.checkAuthorizationStatus()
        try await mockService.requestAuthorization()
        _ = await mockService.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(await mockService.callCount(for: "checkAuthorizationStatus"), 2)
        XCTAssertEqual(await mockService.callCount(for: "requestAuthorization"), 1)

        let callLog = await mockService.getMethodCallLog()
        XCTAssertEqual(callLog.count, 3)
        XCTAssertEqual(callLog[0].method, "checkAuthorizationStatus")
        XCTAssertEqual(callLog[1].method, "requestAuthorization")
        XCTAssertEqual(callLog[2].method, "checkAuthorizationStatus")
    }

    // MARK: - Factory Method Tests

    func testSuccessfulServiceFactory() async {
        // Given/When
        let service = MockHealthKitService.successful()

        // Then
        let status = await service.checkAuthorizationStatus()
        XCTAssertEqual(status, .authorized)
    }

    func testUnavailableServiceFactory() async {
        // Given/When
        let service = MockHealthKitService.unavailable()

        // Then
        let status = await service.checkAuthorizationStatus()
        XCTAssertEqual(status, .unavailable)
    }

    func testDeniedServiceFactory() async {
        // Given/When
        let service = MockHealthKitService.denied()

        // Then
        let status = await service.checkAuthorizationStatus()
        XCTAssertEqual(status, .denied)
    }

    func testNotDeterminedServiceFactory() async {
        // Given/When
        let service = MockHealthKitService.notDetermined()

        // Then
        let status = await service.checkAuthorizationStatus()
        XCTAssertEqual(status, .notDetermined)
    }

    func testAuthorizationFailingServiceFactory() async {
        // Given/When
        let service = await MockHealthKitService.authorizationFailing(with: .authorizationDenied)

        // Then
        do {
            try await service.requestAuthorization()
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Scenario Configuration Tests

    func testHappyPathScenario() async throws {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.happyPath.configure(service: service)

        // When
        let status = await service.checkAuthorizationStatus()
        try await service.requestAuthorization()

        // Then
        XCTAssertEqual(status, .authorized)
    }

    func testAuthorizationDeniedScenario() async {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.authorizationDenied.configure(service: service)

        // When
        let status = await service.checkAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .denied)
    }

    func testAuthorizationRequestFailsScenario() async {
        // Given
        let service = MockHealthKitService()
        await HealthKitTestScenario.authorizationRequestFails.configure(service: service)

        // When/Then
        do {
            try await service.requestAuthorization()
            XCTFail("Expected error")
        } catch let error as HealthKitError {
            if case .authorizationFailed = error {
                // Expected
            } else {
                XCTFail("Expected authorizationFailed error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
}

// MARK: - Authorization Status Enum Tests

final class HealthKitAuthorizationStatusTests: XCTestCase {

    func testAuthorizationStatusEquality() {
        XCTAssertEqual(HealthKitAuthorizationStatus.notDetermined, .notDetermined)
        XCTAssertEqual(HealthKitAuthorizationStatus.authorized, .authorized)
        XCTAssertEqual(HealthKitAuthorizationStatus.denied, .denied)
        XCTAssertEqual(HealthKitAuthorizationStatus.unavailable, .unavailable)

        XCTAssertNotEqual(HealthKitAuthorizationStatus.authorized, .denied)
        XCTAssertNotEqual(HealthKitAuthorizationStatus.notDetermined, .unavailable)
    }

    func testAuthorizationStatusAllCases() {
        // Verify all cases can be created and compared
        let allStatuses: [HealthKitAuthorizationStatus] = [
            .notDetermined,
            .authorized,
            .denied,
            .unavailable
        ]

        XCTAssertEqual(allStatuses.count, 4)

        // Verify each is unique
        for (index, status) in allStatuses.enumerated() {
            for (otherIndex, otherStatus) in allStatuses.enumerated() {
                if index == otherIndex {
                    XCTAssertEqual(status, otherStatus)
                } else {
                    XCTAssertNotEqual(status, otherStatus)
                }
            }
        }
    }
}
