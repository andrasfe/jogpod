//
//  JogPodWatchApp.swift
//  JogPodWatch
//
//  Main entry point for the JogPod watchOS app.
//  Uses modern SwiftUI app lifecycle with @Observable state management.
//

import SwiftUI
import WatchKit
import HealthKit

// MARK: - JogPodWatchApp

/// Main application entry point for the watchOS app.
///
/// ## Architecture
///
/// The app uses a centralized state container (`WatchState`) that is
/// injected into the environment using the @Observable macro. All views
/// can access this shared state for reactive UI updates.
///
/// ## watchOS 10+ Features
///
/// - Uses SwiftUI App lifecycle (no Extension Delegate needed)
/// - NavigationStack for modern navigation
/// - @Observable for efficient state management
/// - TabView with .verticalPage style for watchOS
/// - WidgetKit complications with deep link support
/// - Independent workout tracking via HKWorkoutSession
///
/// ## Independent Workout Support
///
/// The app can track workouts independently when iPhone is not reachable:
/// - Uses HKWorkoutSession for native workout tracking
/// - Collects heart rate, distance, and GPS data locally
/// - Syncs data with iPhone when connection is restored
@main
struct JogPodWatchApp: App {

    // MARK: - State

    /// The app's shared state container.
    @State private var watchState = WatchState()

    /// Deep link handler for complication taps.
    @State private var deepLinkHandler = DeepLinkHandler.shared

    /// Connection manager reference.
    private let connectivityManager = WatchConnectivityManager.shared

    /// Workout service for independent tracking.
    private let workoutService = WatchWorkoutService.shared

    /// Data sync service.
    private let dataSyncService = WorkoutDataSync.shared

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(watchState)
                .environment(deepLinkHandler)
                .onAppear {
                    setupServices()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    // MARK: - Setup

    private func setupServices() {
        // Connect state to connectivity manager
        connectivityManager.watchState = watchState

        // Activate WatchConnectivity session
        connectivityManager.activate()

        // Request HealthKit authorization for independent workouts
        Task {
            do {
                try await workoutService.requestAuthorization()
            } catch {
                // Authorization will be requested when user starts a workout
            }

            // Update pending sync count
            await MainActor.run {
                watchState.pendingSyncCount = dataSyncService.pendingItemCount
            }

            // Attempt to sync pending workouts if connected
            if connectivityManager.isReachable {
                await dataSyncService.forceSyncAll()
            }
        }

        // Observe reachability changes for sync
        Task {
            for await reachable in connectivityManager.reachabilityPublisher.values {
                await MainActor.run {
                    watchState.isReachable = reachable
                }

                if reachable {
                    // Sync pending workouts when iPhone becomes reachable
                    await dataSyncService.forceSyncAll()
                    await MainActor.run {
                        watchState.pendingSyncCount = dataSyncService.pendingItemCount
                    }
                }
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        deepLinkHandler.handleURL(url)
    }
}

// MARK: - ContentView

/// Root content view providing tab-based navigation.
///
/// Uses a vertical page TabView which is the standard watchOS
/// navigation pattern for multiple top-level destinations.
///
/// ## Deep Link Navigation
///
/// Supports navigation from complications via deep links.
/// The DeepLinkHandler tracks pending destinations and the
/// view observes changes to navigate accordingly.
struct ContentView: View {

    // MARK: - Environment

    @Environment(WatchState.self) private var watchState
    @Environment(DeepLinkHandler.self) private var deepLinkHandler

    // MARK: - State

    @State private var selectedTab: WatchTab = .dashboard
    @State private var dashboardNavigationPath = NavigationPath()

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab with NavigationStack
            NavigationStack(path: $dashboardNavigationPath) {
                DashboardView()
                    .navigationDestination(for: WatchNavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tag(WatchTab.dashboard)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tag(WatchTab.settings)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
            handlePendingNavigation(destination)
        }
        .alert("Error", isPresented: Binding(
            get: { watchState.showError },
            set: { watchState.showError = $0 }
        )) {
            Button("OK", role: .cancel) {
                watchState.clearError()
            }
        } message: {
            if let errorMessage = watchState.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for destination: WatchNavigationDestination) -> some View {
        switch destination {
        case .workout:
            WorkoutMetricsView()
        case .stats:
            StatsView()
        case .podcast:
            PodcastPlayerView()
        case .map:
            MapView()
        }
    }

    // MARK: - Deep Link Handling

    private func handlePendingNavigation(_ destination: DeepLinkDestination?) {
        guard let destination = destination else { return }

        switch destination {
        case .dashboard:
            selectedTab = .dashboard
            dashboardNavigationPath = NavigationPath()

        case .workout:
            selectedTab = .dashboard
            dashboardNavigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dashboardNavigationPath.append(WatchNavigationDestination.workout)
            }

        case .stats:
            selectedTab = .dashboard
            dashboardNavigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dashboardNavigationPath.append(WatchNavigationDestination.stats)
            }

        case .podcast:
            selectedTab = .dashboard
            dashboardNavigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dashboardNavigationPath.append(WatchNavigationDestination.podcast)
            }

        case .map:
            selectedTab = .dashboard
            dashboardNavigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dashboardNavigationPath.append(WatchNavigationDestination.map)
            }

        case .settings:
            selectedTab = .settings
            dashboardNavigationPath = NavigationPath()
        }

        deepLinkHandler.clearPendingNavigation()
    }
}

// MARK: - WatchTab

/// Enumeration of available tabs in the watch app.
enum WatchTab: Hashable {
    case dashboard
    case settings
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(WatchState())
}
