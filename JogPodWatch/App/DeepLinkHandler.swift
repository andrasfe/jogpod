//
//  DeepLinkHandler.swift
//  JogPodWatch
//
//  Handles deep links from complications to navigate to specific views.
//  Supports URL scheme: jogpod://
//

import Foundation
import SwiftUI

// MARK: - DeepLinkDestination

/// Destinations that can be navigated to via deep link.
public enum DeepLinkDestination: String, CaseIterable {
    case dashboard = "dashboard"
    case workout = "workout"
    case stats = "stats"
    case podcast = "podcast"
    case map = "map"
    case settings = "settings"

    /// Parses a URL into a destination.
    ///
    /// - Parameter url: The deep link URL to parse.
    /// - Returns: The destination, or nil if URL is invalid.
    public static func from(url: URL) -> DeepLinkDestination? {
        guard url.scheme == "jogpod" else { return nil }

        // Handle both host-based (jogpod://workout) and path-based (jogpod:///workout)
        let pathOrHost = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return DeepLinkDestination(rawValue: pathOrHost)
    }
}

// MARK: - DeepLinkHandler

/// Observable handler for deep link navigation.
///
/// This class tracks the current navigation destination requested
/// via deep link and coordinates with the main navigation system.
@Observable
@MainActor
public final class DeepLinkHandler {

    // MARK: - Singleton

    public static let shared = DeepLinkHandler()

    // MARK: - Properties

    /// The destination requested by the most recent deep link.
    public var pendingDestination: DeepLinkDestination?

    /// Whether there is a pending navigation request.
    public var hasPendingNavigation: Bool {
        pendingDestination != nil
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - URL Handling

    /// Handles an incoming deep link URL.
    ///
    /// - Parameter url: The URL to handle.
    /// - Returns: True if the URL was handled, false otherwise.
    @discardableResult
    public func handleURL(_ url: URL) -> Bool {
        guard let destination = DeepLinkDestination.from(url: url) else {
            return false
        }

        pendingDestination = destination
        return true
    }

    /// Clears the pending navigation after it has been handled.
    public func clearPendingNavigation() {
        pendingDestination = nil
    }
}

// MARK: - View Modifier for Deep Link Handling

/// View modifier that handles deep links and navigates to the appropriate view.
struct DeepLinkNavigationModifier: ViewModifier {

    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @Binding var selectedTab: WatchTab
    @Binding var navigationPath: NavigationPath

    func body(content: Content) -> some View {
        content
            .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
                handleNavigation(to: destination)
            }
    }

    private func handleNavigation(to destination: DeepLinkDestination?) {
        guard let destination = destination else { return }

        switch destination {
        case .dashboard:
            selectedTab = .dashboard
            navigationPath = NavigationPath()

        case .workout:
            selectedTab = .dashboard
            navigationPath = NavigationPath()
            // Navigate to workout view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(WatchNavigationDestination.workout)
            }

        case .stats:
            selectedTab = .dashboard
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(WatchNavigationDestination.stats)
            }

        case .podcast:
            selectedTab = .dashboard
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(WatchNavigationDestination.podcast)
            }

        case .map:
            selectedTab = .dashboard
            navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationPath.append(WatchNavigationDestination.map)
            }

        case .settings:
            selectedTab = .settings
            navigationPath = NavigationPath()
        }

        // Clear the pending navigation
        deepLinkHandler.clearPendingNavigation()
    }
}

// MARK: - Watch Navigation Destination

/// Navigation destinations within the watch app.
public enum WatchNavigationDestination: Hashable {
    case workout
    case stats
    case podcast
    case map
}

// MARK: - View Extension

extension View {
    /// Adds deep link navigation handling to the view.
    func handleDeepLinks(
        selectedTab: Binding<WatchTab>,
        navigationPath: Binding<NavigationPath>
    ) -> some View {
        modifier(DeepLinkNavigationModifier(
            selectedTab: selectedTab,
            navigationPath: navigationPath
        ))
    }
}
