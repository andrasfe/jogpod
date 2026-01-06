//
//  WeatherAlert.swift
//  JogPod
//
//  Models for weather alert data.
//

import Foundation
import CoreLocation

// MARK: - WeatherAlertSeverity

/// Severity level of a weather alert.
public enum WeatherAlertSeverity: String, Sendable, Codable, CaseIterable {
    case minor
    case moderate
    case severe
    case extreme
    case unknown

    /// Returns an appropriate SF Symbol for the severity level.
    public var sfSymbolName: String {
        switch self {
        case .minor:
            return "exclamationmark.circle"
        case .moderate:
            return "exclamationmark.triangle"
        case .severe:
            return "exclamationmark.triangle.fill"
        case .extreme:
            return "exclamationmark.octagon.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - WeatherAlert

/// A weather alert or warning for a location.
///
/// This struct replaces the alert data from the legacy Weather Underground API,
/// providing similar functionality with a modernized interface.
///
/// ## Legacy Equivalence
///
/// Replaces data from `LocalWeatherDelegate.localAlertAvailable`:
/// - `alertType` -> `alertType`
/// - `alertDescription` -> `description`
/// - `date` -> `effectiveDate`
/// - `expires` -> `expirationDate`
public struct WeatherAlert: Sendable, Equatable, Codable, Identifiable {

    /// Unique identifier for the alert.
    public let id: String

    /// Type of weather alert (e.g., "Tornado Warning", "Heat Advisory").
    public let alertType: String

    /// Detailed description of the alert.
    public let description: String

    /// Headline or short summary of the alert.
    public let headline: String?

    /// When the alert becomes effective.
    public let effectiveDate: Date

    /// When the alert expires.
    public let expirationDate: Date

    /// Severity level of the alert.
    public let severity: WeatherAlertSeverity

    /// The geographic area affected by the alert.
    public let affectedArea: String?

    /// Instructions or recommended actions.
    public let instruction: String?

    /// The source/issuer of the alert.
    public let source: String?

    /// The location this alert applies to.
    public let location: CLLocationCoordinate2D?

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        alertType: String,
        description: String,
        headline: String? = nil,
        effectiveDate: Date,
        expirationDate: Date,
        severity: WeatherAlertSeverity = .unknown,
        affectedArea: String? = nil,
        instruction: String? = nil,
        source: String? = nil,
        location: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.alertType = alertType
        self.description = description
        self.headline = headline
        self.effectiveDate = effectiveDate
        self.expirationDate = expirationDate
        self.severity = severity
        self.affectedArea = affectedArea
        self.instruction = instruction
        self.source = source
        self.location = location
    }

    // MARK: - Computed Properties

    /// Whether the alert is currently active.
    public var isActive: Bool {
        let now = Date()
        return now >= effectiveDate && now <= expirationDate
    }

    /// Whether the alert has expired.
    public var isExpired: Bool {
        Date() > expirationDate
    }

    /// Time remaining until the alert expires, or nil if expired.
    public var timeUntilExpiration: TimeInterval? {
        guard !isExpired else { return nil }
        return expirationDate.timeIntervalSinceNow
    }
}

// MARK: - Hashable

extension WeatherAlert: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
