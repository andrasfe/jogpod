//
//  MainTabView.swift
//  JogPod
//
//  Main tab-based navigation structure for the JogPod application.
//

import SwiftUI

// MARK: - Tab Enum

/// Represents the main tabs in the JogPod application.
///
/// The tab order matches the legacy app's storyboard structure:
/// 1. Dashboard - Main workout dashboard with metrics and media controls
/// 2. Playlist - Podcast management and episode list
/// 3. Stats - Workout statistics, maps, and charts
/// 4. Settings - App configuration and preferences
public enum MainTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case playlist = 1
    case stats = 2
    case settings = 3

    public var id: Int { rawValue }

    /// The display title for the tab.
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .playlist: return "Playlist"
        case .stats: return "Stats"
        case .settings: return "Settings"
        }
    }

    /// The SF Symbol name for the tab icon.
    var iconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .playlist: return "music.note.list"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }

    /// The SF Symbol name for the selected tab icon.
    var selectedIconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .playlist: return "music.note.list"
        case .stats: return "chart.line.uptrend.xyaxis.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    /// Accessibility label for the tab.
    var accessibilityLabel: String {
        switch self {
        case .dashboard: return "Dashboard tab. View workout metrics and controls."
        case .playlist: return "Playlist tab. Manage your podcast episodes."
        case .stats: return "Statistics tab. View workout history and charts."
        case .settings: return "Settings tab. Configure app preferences."
        }
    }
}

// MARK: - MainTabView

/// The root tab view containing all main navigation destinations.
///
/// This view serves as the primary navigation structure, replacing the
/// legacy storyboard-based `UITabBarController`. Each tab contains a
/// `NavigationStack` for managing hierarchical navigation within that section.
///
/// ## Navigation Architecture
///
/// ```
/// MainTabView
/// +-- Dashboard Tab
/// |   +-- NavigationStack
/// |       +-- DashboardView (root)
/// |       +-- WorkoutDetailView (pushed)
/// |       +-- ...
/// +-- Playlist Tab
/// |   +-- NavigationStack
/// |       +-- PlaylistView (root)
/// |       +-- PodcastDetailView (pushed)
/// |       +-- EpisodeDetailView (pushed)
/// |       +-- ...
/// +-- Stats Tab
/// |   +-- NavigationStack
/// |       +-- StatsView (root)
/// |       +-- WorkoutHistoryView (pushed)
/// |       +-- MapView (pushed)
/// |       +-- ChartView (pushed)
/// |       +-- ...
/// +-- Settings Tab
///     +-- NavigationStack
///         +-- SettingsView (root)
///         +-- GoalsSettingsView (pushed)
///         +-- AnnouncementsSettingsView (pushed)
///         +-- ...
/// ```
///
/// ## Accessibility
///
/// - Each tab has a descriptive accessibility label
/// - Tab selection is announced to VoiceOver users
/// - Dynamic Type is supported throughout
///
/// ## Usage
///
/// ```swift
/// @main
/// struct JogPodApp: App {
///     @State private var dependencies = AppDependencies()
///
///     var body: some Scene {
///         WindowGroup {
///             MainTabView()
///                 .environment(dependencies)
///                 .modelContainer(dependencies.modelContainer)
///         }
///     }
/// }
/// ```
public struct MainTabView: View {

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies

    // MARK: - State

    /// The currently selected tab.
    @State private var selectedTab: MainTab = .dashboard

    /// Navigation path for the Dashboard tab.
    @State private var dashboardPath = NavigationPath()

    /// Navigation path for the Playlist tab.
    @State private var playlistPath = NavigationPath()

    /// Navigation path for the Stats tab.
    @State private var statsPath = NavigationPath()

    /// Navigation path for the Settings tab.
    @State private var settingsPath = NavigationPath()

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
            playlistTab
            statsTab
            settingsTab
        }
        .task {
            await dependencies.initializeServices()
        }
    }

    // MARK: - Tab Views

    private var dashboardTab: some View {
        NavigationStack(path: $dashboardPath) {
            DashboardView()
        }
        .tabItem {
            Label(MainTab.dashboard.title, systemImage: MainTab.dashboard.iconName)
        }
        .tag(MainTab.dashboard)
        .accessibilityLabel(MainTab.dashboard.accessibilityLabel)
    }

    private var playlistTab: some View {
        NavigationStack(path: $playlistPath) {
            PlaylistView()
        }
        .tabItem {
            Label(MainTab.playlist.title, systemImage: MainTab.playlist.iconName)
        }
        .tag(MainTab.playlist)
        .accessibilityLabel(MainTab.playlist.accessibilityLabel)
    }

    private var statsTab: some View {
        NavigationStack(path: $statsPath) {
            StatsView()
        }
        .tabItem {
            Label(MainTab.stats.title, systemImage: MainTab.stats.iconName)
        }
        .tag(MainTab.stats)
        .accessibilityLabel(MainTab.stats.accessibilityLabel)
    }

    private var settingsTab: some View {
        NavigationStack(path: $settingsPath) {
            SettingsView()
        }
        .tabItem {
            Label(MainTab.settings.title, systemImage: MainTab.settings.iconName)
        }
        .tag(MainTab.settings)
        .accessibilityLabel(MainTab.settings.accessibilityLabel)
    }

    // MARK: - Navigation Helpers

    /// Navigates to a specific tab.
    ///
    /// - Parameter tab: The tab to navigate to.
    public func navigateToTab(_ tab: MainTab) {
        selectedTab = tab
    }

    /// Resets the navigation stack for the current tab.
    public func popToRoot() {
        switch selectedTab {
        case .dashboard:
            dashboardPath = NavigationPath()
        case .playlist:
            playlistPath = NavigationPath()
        case .stats:
            statsPath = NavigationPath()
        case .settings:
            settingsPath = NavigationPath()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .appDependencies(AppDependencies.makeForPreview())
        .modelContainer(for: JogPodSchema.models, inMemory: true)
}
