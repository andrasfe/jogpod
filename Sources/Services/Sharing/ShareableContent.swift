//
//  ShareableContent.swift
//  JogPod
//
//  Created during migration from legacy SocialIntegration.
//  Replaces deprecated Social.framework with modern ShareLink/UIActivityViewController.
//

import Foundation
import CoreLocation
import CoreTransferable
import UIKit

// MARK: - Shareable Content Protocol

/// Protocol for content that can be shared via the system share sheet.
/// Replaces the legacy SocialIntegration direct posting to Twitter/Facebook.
protocol ShareableContent: Transferable {
    /// Plain text representation for sharing
    var shareText: String { get }

    /// Optional URL to include in the share
    var shareURL: URL? { get }

    /// Optional image to include in the share
    var shareImage: UIImage? { get }
}

// MARK: - Workout Summary Share Content

/// Shareable workout summary for posting to social media.
/// Replaces legacy SocialIntegration.sendTweetToPreferredAccount and postToFacebookWall.
struct WorkoutShareContent: ShareableContent, Sendable {
    let duration: TimeInterval
    let distance: Double // in meters
    let averagePace: TimeInterval? // seconds per kilometer
    let calories: Double?
    let workoutDate: Date
    let customMessage: String?

    // MARK: - ShareableContent Protocol

    var shareText: String {
        var components: [String] = []

        // Add custom message if provided
        if let message = customMessage, !message.isEmpty {
            components.append(message)
        }

        // Format workout summary
        let durationString = Self.formatDuration(duration)
        let distanceString = Self.formatDistance(distance)

        var summaryLine = "Completed a \(distanceString) run in \(durationString)"

        if let pace = averagePace {
            let paceString = Self.formatPace(pace)
            summaryLine += " at \(paceString) pace"
        }

        components.append(summaryLine)

        if let cal = calories, cal > 0 {
            components.append("Burned \(Int(cal)) calories")
        }

        // Add app attribution
        components.append("#JogPod")

        return components.joined(separator: " | ")
    }

    var shareURL: URL? {
        // Could link to App Store or a workout detail page in the future
        nil
    }

    var shareImage: UIImage? {
        // Could generate a workout summary card image in the future
        nil
    }

    // MARK: - Transferable Conformance

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }

    // MARK: - Formatting Helpers

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private static func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000.0
        if kilometers >= 1.0 {
            return String(format: "%.2f km", kilometers)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private static func formatPace(_ secondsPerKilometer: TimeInterval) -> String {
        let minutes = Int(secondsPerKilometer) / 60
        let seconds = Int(secondsPerKilometer) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

// MARK: - Route Share Content

/// Shareable route information with optional map image.
struct RouteShareContent: ShareableContent, Sendable {
    let routeName: String?
    let distance: Double // in meters
    let routePoints: [CLLocationCoordinate2D]
    let mapSnapshotImage: UIImage?

    var shareText: String {
        var text = ""

        if let name = routeName {
            text = "Check out my \(name) route"
        } else {
            text = "Check out my running route"
        }

        let distanceKm = distance / 1000.0
        text += " (\(String(format: "%.2f", distanceKm)) km) #JogPod"

        return text
    }

    var shareURL: URL? {
        nil
    }

    var shareImage: UIImage? {
        mapSnapshotImage
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}

// MARK: - Achievement Share Content

/// Shareable achievement or milestone content.
struct AchievementShareContent: ShareableContent, Sendable {
    let achievementTitle: String
    let achievementDescription: String
    let earnedDate: Date
    let badgeImage: UIImage?

    var shareText: String {
        "I just earned the \"\(achievementTitle)\" achievement in JogPod! \(achievementDescription) #JogPod #Running"
    }

    var shareURL: URL? {
        nil
    }

    var shareImage: UIImage? {
        badgeImage
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}

// MARK: - Generic Text Share Content

/// Simple text-only share content for general sharing.
struct TextShareContent: ShareableContent, Sendable {
    let text: String
    let url: URL?

    init(text: String, url: URL? = nil) {
        self.text = text
        self.url = url
    }

    var shareText: String { text }
    var shareURL: URL? { url }
    var shareImage: UIImage? { nil }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}
