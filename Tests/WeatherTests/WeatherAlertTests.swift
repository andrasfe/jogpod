//
//  WeatherAlertTests.swift
//  JogPod Tests
//
//  Tests for WeatherAlert data model.
//

import Testing
import Foundation
import CoreLocation
@testable import JogPod

// MARK: - WeatherAlert Tests

@Suite("WeatherAlert")
struct WeatherAlertTests {

    // MARK: - Test Data

    static func makeTestAlert(
        effectiveDate: Date = Date().addingTimeInterval(-3600),
        expirationDate: Date = Date().addingTimeInterval(3600),
        severity: WeatherAlertSeverity = .moderate
    ) -> WeatherAlert {
        WeatherAlert(
            id: "test-alert-123",
            alertType: "Heat Advisory",
            description: "Dangerously hot conditions expected.",
            headline: "Heat Advisory in effect",
            effectiveDate: effectiveDate,
            expirationDate: expirationDate,
            severity: severity,
            affectedArea: "San Francisco Bay Area",
            instruction: "Drink plenty of fluids and stay cool.",
            source: "National Weather Service",
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
    }

    // MARK: - Initialization

    @Test("initializes with all values")
    func initializesWithAllValues() {
        let alert = Self.makeTestAlert()

        #expect(alert.id == "test-alert-123")
        #expect(alert.alertType == "Heat Advisory")
        #expect(alert.description == "Dangerously hot conditions expected.")
        #expect(alert.headline == "Heat Advisory in effect")
        #expect(alert.severity == .moderate)
        #expect(alert.affectedArea == "San Francisco Bay Area")
        #expect(alert.instruction == "Drink plenty of fluids and stay cool.")
        #expect(alert.source == "National Weather Service")
        #expect(alert.location?.latitude == 37.7749)
    }

    @Test("generates UUID when not provided")
    func generatesUUID() {
        let alert = WeatherAlert(
            alertType: "Test",
            description: "Test description",
            effectiveDate: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )

        #expect(!alert.id.isEmpty)
        #expect(UUID(uuidString: alert.id) != nil)
    }

    // MARK: - Active Status

    @Test("isActive returns true for current alerts")
    func isActiveForCurrentAlerts() {
        let alert = Self.makeTestAlert(
            effectiveDate: Date().addingTimeInterval(-3600),
            expirationDate: Date().addingTimeInterval(3600)
        )

        #expect(alert.isActive == true)
        #expect(alert.isExpired == false)
    }

    @Test("isActive returns false for future alerts")
    func isNotActiveForFutureAlerts() {
        let alert = Self.makeTestAlert(
            effectiveDate: Date().addingTimeInterval(3600),
            expirationDate: Date().addingTimeInterval(7200)
        )

        #expect(alert.isActive == false)
    }

    @Test("isExpired returns true for past alerts")
    func isExpiredForPastAlerts() {
        let alert = Self.makeTestAlert(
            effectiveDate: Date().addingTimeInterval(-7200),
            expirationDate: Date().addingTimeInterval(-3600)
        )

        #expect(alert.isExpired == true)
        #expect(alert.isActive == false)
    }

    // MARK: - Time Until Expiration

    @Test("timeUntilExpiration returns positive value for active alerts")
    func timeUntilExpirationForActiveAlerts() {
        let alert = Self.makeTestAlert(
            effectiveDate: Date().addingTimeInterval(-3600),
            expirationDate: Date().addingTimeInterval(3600)
        )

        let time = alert.timeUntilExpiration
        #expect(time != nil)
        #expect(time! > 0)
        #expect(time! <= 3600)
    }

    @Test("timeUntilExpiration returns nil for expired alerts")
    func timeUntilExpirationForExpiredAlerts() {
        let alert = Self.makeTestAlert(
            effectiveDate: Date().addingTimeInterval(-7200),
            expirationDate: Date().addingTimeInterval(-3600)
        )

        #expect(alert.timeUntilExpiration == nil)
    }

    // MARK: - Severity

    @Test("severity levels have correct SF symbols")
    func severityHasCorrectSFSymbols() {
        #expect(WeatherAlertSeverity.minor.sfSymbolName == "exclamationmark.circle")
        #expect(WeatherAlertSeverity.moderate.sfSymbolName == "exclamationmark.triangle")
        #expect(WeatherAlertSeverity.severe.sfSymbolName == "exclamationmark.triangle.fill")
        #expect(WeatherAlertSeverity.extreme.sfSymbolName == "exclamationmark.octagon.fill")
        #expect(WeatherAlertSeverity.unknown.sfSymbolName == "questionmark.circle")
    }

    @Test("all severity cases are covered")
    func allSeverityCasesCovered() {
        let allCases = WeatherAlertSeverity.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.minor))
        #expect(allCases.contains(.moderate))
        #expect(allCases.contains(.severe))
        #expect(allCases.contains(.extreme))
        #expect(allCases.contains(.unknown))
    }

    // MARK: - Equatable

    @Test("alerts are equatable")
    func alertsAreEquatable() {
        let alert1 = Self.makeTestAlert()
        let alert2 = Self.makeTestAlert()  // Same ID
        let alert3 = WeatherAlert(
            id: "different-id",
            alertType: "Heat Advisory",
            description: "Dangerously hot conditions expected.",
            effectiveDate: Date(),
            expirationDate: Date().addingTimeInterval(3600)
        )

        #expect(alert1 == alert2)
        #expect(alert1 != alert3)
    }

    // MARK: - Hashable

    @Test("alerts are hashable")
    func alertsAreHashable() {
        let alert1 = Self.makeTestAlert()
        let alert2 = Self.makeTestAlert()

        var set: Set<WeatherAlert> = []
        set.insert(alert1)
        set.insert(alert2)

        // Same ID, so only one should be in set
        #expect(set.count == 1)
    }

    // MARK: - Codable

    @Test("alerts are codable")
    func alertsAreCodable() throws {
        let original = Self.makeTestAlert()

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WeatherAlert.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.alertType == original.alertType)
        #expect(decoded.description == original.description)
        #expect(decoded.severity == original.severity)
    }

    // MARK: - Identifiable

    @Test("alerts are identifiable")
    func alertsAreIdentifiable() {
        let alert = Self.makeTestAlert()
        #expect(alert.id == "test-alert-123")
    }

    // MARK: - Sendable

    @Test("alerts are Sendable")
    func alertsAreSendable() async {
        let alert = Self.makeTestAlert()

        let result = await Task.detached {
            return alert
        }.value

        #expect(result == alert)
    }
}
