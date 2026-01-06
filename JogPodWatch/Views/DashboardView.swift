//
//  DashboardView.swift
//  JogPodWatch
//
//  Main dashboard view showing workout and podcast status.
//  Entry point for navigating to other watch app features.
//

import SwiftUI

// MARK: - DashboardView

/// Main dashboard view for the watchOS app.
///
/// Displays:
/// - Connection status indicator
/// - Workout status with navigation to metrics view
/// - Podcast status with navigation to player view
/// - Navigation to map and stats views
/// - Pending sync indicator
///
/// ## watchOS 10+ Design
///
/// Uses NavigationStack for modern navigation patterns and
/// supports the vertical page-based layout expected on watchOS.
///
/// ## Independent Workout Support
///
/// When iPhone is not reachable, the dashboard indicates that
/// workouts will be tracked independently on the watch.
struct DashboardView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState
    @State private var showNotInitializedAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // Connection Status
                    connectionStatusIndicator

                    // Workout Button
                    workoutButton

                    // Podcast Button
                    podcastButton

                    // Map Button
                    mapButton

                    // Stats Button (hidden if no workouts)
                    if watchState.workoutCount > 0 || watchState.pendingSyncCount > 0 {
                        statsButton
                    }

                    // Pending Sync Indicator
                    if watchState.pendingSyncCount > 0 {
                        pendingSyncIndicator
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("JogPod")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDashboardData()
            }
            .alert("Setup Required", isPresented: $showNotInitializedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please open the JogPod app on your iPhone, accept the terms, and enable location tracking.")
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var connectionStatusIndicator: some View {
        if !watchState.isReachable {
            HStack(spacing: 4) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 10))
                Text("iPhone not connected")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.2))
            )
            .padding(.bottom, 4)
        }
    }

    private var workoutButton: some View {
        NavigationLink(destination: WorkoutMetricsView()) {
            DashboardRow(
                icon: watchState.workoutInProgress ? "figure.run" : "figure.stand",
                iconColor: workoutIconColor,
                title: workoutTitle,
                subtitle: workoutSubtitle,
                badge: workoutBadge
            )
        }
        .buttonStyle(.plain)
    }

    private var workoutIconColor: Color {
        if watchState.workoutInProgress {
            return watchState.isIndependentWorkout ? .orange : .green
        }
        return .gray
    }

    private var workoutTitle: String {
        if watchState.workoutInProgress {
            return watchState.isIndependentWorkout ? "Independent Workout" : "Workout Active"
        }
        return "Start Workout"
    }

    private var workoutSubtitle: String {
        if watchState.workoutInProgress {
            if watchState.isIndependentWorkout {
                return "Tracking on Apple Watch"
            }
            return "Tap to view metrics"
        }
        if !watchState.isReachable {
            return "Will track locally on watch"
        }
        return "Tap to start workout"
    }

    private var workoutBadge: String? {
        if watchState.pendingSyncCount > 0 && !watchState.workoutInProgress {
            return "\(watchState.pendingSyncCount)"
        }
        return nil
    }

    private var podcastButton: some View {
        NavigationLink(destination: PodcastPlayerView()) {
            DashboardRow(
                icon: watchState.podcastPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill",
                iconColor: watchState.podcastPlaying ? .blue : .gray,
                title: watchState.podcastPlaying ? "Now Playing" : "Podcast",
                subtitle: watchState.podcastTitle
            )
        }
        .buttonStyle(.plain)
    }

    private var mapButton: some View {
        NavigationLink(destination: MapView()) {
            DashboardRow(
                icon: "map.fill",
                iconColor: .orange,
                title: "Map",
                subtitle: mapSubtitle
            )
        }
        .buttonStyle(.plain)
    }

    private var mapSubtitle: String {
        if watchState.isIndependentWorkout {
            return "Tracking GPS on watch"
        }
        return "Track your location"
    }

    private var statsButton: some View {
        NavigationLink(destination: StatsView()) {
            DashboardRow(
                icon: "chart.bar.fill",
                iconColor: .purple,
                title: "Stats",
                subtitle: statsSubtitle
            )
        }
        .buttonStyle(.plain)
    }

    private var statsSubtitle: String {
        let workoutText = "\(watchState.workoutCount) workout\(watchState.workoutCount == 1 ? "" : "s")"
        if watchState.pendingSyncCount > 0 {
            return "\(workoutText) (\(watchState.pendingSyncCount) pending sync)"
        }
        return workoutText
    }

    private var pendingSyncIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(watchState.pendingSyncCount) workout\(watchState.pendingSyncCount == 1 ? "" : "s") pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Text("Will sync when iPhone connects")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Data Loading

    private func loadDashboardData() async {
        // Update pending sync count
        watchState.pendingSyncCount = WorkoutDataSync.shared.pendingItemCount

        // Try to sync pending data if connected
        if watchState.isReachable {
            await WorkoutDataSync.shared.forceSyncAll()
        }

        // Load dashboard data from iPhone if reachable
        if watchState.isReachable {
            await WatchConnectivityManager.shared.requestDashboardData()

            if !watchState.isInitialized && !watchState.isIndependentWorkout {
                showNotInitializedAlert = true
            }
        }
    }
}

// MARK: - DashboardRow

/// A styled row for the dashboard navigation buttons.
struct DashboardRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(Color.red))
                        .offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.7))
        )
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(WatchState())
}
