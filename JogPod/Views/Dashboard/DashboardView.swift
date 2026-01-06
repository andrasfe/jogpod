//
//  DashboardView.swift
//  JogPod
//
//  Main workout dashboard displaying metrics, media controls, and workout status.
//

import SwiftUI
import Combine

// MARK: - DashboardView

/// The main workout dashboard view.
///
/// This view corresponds to the legacy `DashboardViewController` and provides:
/// - Current workout metrics display (distance, duration, pace, calories, heart rate, steps)
/// - Workout start/stop controls
/// - GPS signal and heart rate monitor indicators
/// - Media center for podcast playback controls
/// - Voice command toggle
///
/// ## Legacy Equivalence
///
/// This view replaces:
/// - `DashboardViewController.h/.m`
/// - `SlidingMetricsViewController` (metrics carousel)
/// - `MediaCenterViewController` (media controls)
///
/// ## iOS 26 Features
///
/// - Uses Liquid Glass material for card backgrounds
/// - Employs `@Observable` pattern via `AppDependencies`
/// - Supports Dynamic Type and VoiceOver
///
/// ## View Hierarchy
///
/// ```
/// DashboardView
/// +-- ScrollView
///     +-- VStack
///         +-- StatusBarView (GPS/HR indicators)
///         +-- MetricsGridView (6 metric cards)
///         +-- MediaCenterView (now playing + controls)
///         +-- WorkoutControlButton (Start/Stop)
/// ```
///
/// ## Accessibility
///
/// - All metrics have accessibility labels with units
/// - Workout button announces state changes
/// - Supports VoiceOver navigation
/// - Supports Dynamic Type
public struct DashboardView: View {

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    /// Observed workout state from the workout observer.
    @State private var workoutObserver = WorkoutServiceObserver()

    /// Whether a workout is currently active.
    @State private var isWorkoutActive: Bool = false

    /// Current workout metrics snapshot.
    @State private var currentMetrics: WorkoutSnapshot = .empty

    /// GPS signal level for status indicator.
    @State private var gpsSignalLevel: GPSSignalLevel = .none

    /// Whether heart rate monitor is connected.
    @State private var isHeartRateMonitorConnected: Bool = false

    /// Audio player state bindings.
    @State private var isPlaying: Bool = false
    @State private var currentPodcastTitle: String?
    @State private var currentEpisodeTitle: String?
    @State private var playbackProgress: Double = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var playbackCurrentTime: TimeInterval = 0
    @State private var hasPlaylistItems: Bool = false

    /// Cancellables for Combine subscriptions.
    @State private var cancellables = Set<AnyCancellable>()

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusBar
                    .padding(.horizontal)

                metricsGrid
                    .padding(.horizontal)

                mediaCenter
                    .padding(.horizontal)

                workoutButton
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await setupObservers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutStatusChanged)) { notification in
            if let status = notification.userInfo?["status"] as? Bool {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isWorkoutActive = status
                }
                if !status {
                    // Reset metrics when workout stops
                    currentMetrics = .empty
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutUpdatesAvailable)) { notification in
            if let metrics = notification.userInfo?["stats"] as? WorkoutSnapshot {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentMetrics = metrics
                    gpsSignalLevel = metrics.gpsSignalLevel
                    isHeartRateMonitorConnected = metrics.currentHeartRate > 0
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            // GPS Status
            GPSStatusIndicator(signalLevel: gpsSignalLevel)

            Divider()
                .frame(height: 24)

            // Heart Rate Monitor Status
            HeartRateStatusIndicator(isConnected: isHeartRateMonitorConnected)

            Spacer()

            // Workout timer when active
            if isWorkoutActive {
                Text(currentMetrics.formattedDuration)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusBarAccessibilityLabel)
    }

    private var statusBarAccessibilityLabel: String {
        var parts: [String] = []

        let gpsStatus: String
        switch gpsSignalLevel {
        case .none: gpsStatus = "GPS disconnected"
        case .veryPoor: gpsStatus = "GPS signal very poor"
        case .poor: gpsStatus = "GPS signal poor"
        case .fair: gpsStatus = "GPS signal fair"
        case .good: gpsStatus = "GPS signal good"
        case .excellent: gpsStatus = "GPS signal excellent"
        }
        parts.append(gpsStatus)

        parts.append(isHeartRateMonitorConnected ? "Heart rate monitor connected" : "Heart rate monitor disconnected")

        if isWorkoutActive {
            parts.append("Workout duration: \(currentMetrics.formattedDuration)")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Distance
            MetricCardView(
                title: "Distance",
                value: formatDistance(currentMetrics.totalDistance),
                unit: "km",
                icon: "figure.run",
                iconColor: .blue,
                isHighlighted: isWorkoutActive
            )

            // Duration
            MetricCardView(
                title: "Duration",
                value: currentMetrics.formattedDuration,
                unit: "",
                icon: "timer",
                iconColor: .orange,
                isHighlighted: isWorkoutActive
            )

            // Pace
            MetricCardView(
                title: "Pace",
                value: formatPace(currentMetrics.pacePerKilometer),
                unit: "/km",
                icon: "speedometer",
                iconColor: .green,
                isHighlighted: isWorkoutActive
            )

            // Calories
            MetricCardView(
                title: "Calories",
                value: "\(currentMetrics.caloriesBurned)",
                unit: "kcal",
                icon: "flame.fill",
                iconColor: .red,
                isHighlighted: isWorkoutActive
            )

            // Heart Rate
            MetricCardView(
                title: "Heart Rate",
                value: currentMetrics.currentHeartRate > 0 ? "\(currentMetrics.currentHeartRate)" : "--",
                unit: "bpm",
                icon: "heart.fill",
                iconColor: .pink,
                isHighlighted: isWorkoutActive && currentMetrics.currentHeartRate > 0
            )

            // Steps
            MetricCardView(
                title: "Steps",
                value: "\(currentMetrics.totalSteps)",
                unit: "",
                icon: "figure.walk",
                iconColor: .purple,
                isHighlighted: isWorkoutActive
            )
        }
    }

    // MARK: - Media Center

    private var mediaCenter: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Now Playing")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if hasPlaylistItems && isPlaying {
                    Image(systemName: "waveform")
                        .foregroundStyle(.accent)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
            }

            if hasPlaylistItems {
                // Track info
                nowPlayingInfo

                // Progress bar
                playbackProgressView

                // Playback controls
                playbackControls
            } else {
                // Empty state
                emptyPlaylistView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private var nowPlayingInfo: some View {
        HStack(spacing: 12) {
            // Artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "music.mic")
                        .font(.title2)
                        .foregroundStyle(.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(currentEpisodeTitle ?? "No episode selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(currentPodcastTitle ?? "Select a podcast from Playlist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(currentEpisodeTitle ?? "No episode") from \(currentPodcastTitle ?? "Unknown podcast")")
    }

    private var playbackProgressView: some View {
        VStack(spacing: 4) {
            ProgressView(value: playbackProgress)
                .tint(.accent)

            HStack {
                Text(formatTime(playbackCurrentTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatTime(playbackDuration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playback progress: \(formatTime(playbackCurrentTime)) of \(formatTime(playbackDuration))")
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            Spacer()

            // Rewind
            Button(action: rewind) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Rewind 15 seconds")

            Spacer()

            // Previous
            Button(action: previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous track")

            Spacer()

            // Play/Pause
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint("Double tap to \(isPlaying ? "pause" : "play") the podcast")

            Spacer()

            // Next
            Button(action: nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next track")

            Spacer()

            // Fast forward
            Button(action: fastForward) {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fast forward 15 seconds")

            Spacer()
        }
        .foregroundStyle(.primary)
    }

    private var emptyPlaylistView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No podcasts in playlist")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Add podcasts in the Playlist tab")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No podcasts in playlist. Add podcasts in the Playlist tab.")
    }

    // MARK: - Workout Button

    private var workoutButton: some View {
        Button(action: toggleWorkout) {
            HStack(spacing: 12) {
                Image(systemName: isWorkoutActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .symbolEffect(.bounce, value: isWorkoutActive)

                Text(isWorkoutActive ? "Stop Workout" : "Start Workout")
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(isWorkoutActive ? .red : .green)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(isWorkoutActive ? "Stop Workout" : "Start Workout")
        .accessibilityHint(isWorkoutActive ? "Double tap to stop and save the current workout" : "Double tap to start a new workout session")
    }

    // MARK: - Actions

    private func toggleWorkout() {
        Task {
            do {
                if isWorkoutActive {
                    try await dependencies.workoutService?.stopWorkout()
                } else {
                    _ = try await dependencies.workoutService?.startWorkout()
                }
            } catch {
                print("[DashboardView] Workout toggle failed: \(error)")
            }
        }
    }

    private func togglePlayPause() {
        guard let audioPlayer = dependencies.audioPlayerService else { return }
        do {
            try audioPlayer.togglePlayPause()
        } catch {
            print("[DashboardView] Play/pause failed: \(error)")
        }
    }

    private func previousTrack() {
        guard let audioPlayer = dependencies.audioPlayerService else { return }
        Task {
            await audioPlayer.goToPreviousItem()
        }
    }

    private func nextTrack() {
        guard let audioPlayer = dependencies.audioPlayerService else { return }
        Task {
            await audioPlayer.advanceToNextItem()
        }
    }

    private func fastForward() {
        guard let audioPlayer = dependencies.audioPlayerService else { return }
        Task {
            await audioPlayer.fastForward()
        }
    }

    private func rewind() {
        guard let audioPlayer = dependencies.audioPlayerService else { return }
        Task {
            await audioPlayer.rewind()
        }
    }

    // MARK: - Setup

    private func setupObservers() async {
        guard let audioPlayer = dependencies.audioPlayerService else { return }

        // Observe audio player state
        audioPlayer.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] state in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPlaying = state == .playing
                }
            }
            .store(in: &cancellables)

        // Observe current item
        audioPlayer.currentItemPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] item in
                withAnimation {
                    currentEpisodeTitle = item?.title
                    currentPodcastTitle = item?.podcastTitle
                }
            }
            .store(in: &cancellables)

        // Observe progress
        audioPlayer.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] progress in
                playbackProgress = progress.progress
                playbackCurrentTime = progress.currentTime
                playbackDuration = progress.duration
            }
            .store(in: &cancellables)

        // Check if playlist has items
        hasPlaylistItems = !audioPlayer.isEmpty
    }

    // MARK: - Formatting Helpers

    private func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000.0
        if kilometers < 10 {
            return String(format: "%.2f", kilometers)
        } else {
            return String(format: "%.1f", kilometers)
        }
    }

    private func formatPace(_ minutesPerKm: Double?) -> String {
        guard let pace = minutesPerKm, pace > 0 && pace.isFinite else {
            return "--:--"
        }
        let totalSeconds = Int(pace * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds >= 0 && seconds.isFinite else { return "--:--" }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - GPSStatusIndicator

/// Displays the GPS signal strength with animated bars.
private struct GPSStatusIndicator: View {
    let signalLevel: GPSSignalLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, options: .repeating, value: signalLevel == .none)

            Text("GPS")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GPS signal: \(signalLevel.accessibilityDescription)")
    }

    private var iconName: String {
        switch signalLevel {
        case .none: return "location.slash"
        case .veryPoor, .poor: return "location"
        case .fair, .good: return "location.fill"
        case .excellent: return "location.fill"
        }
    }

    private var iconColor: Color {
        switch signalLevel {
        case .none: return .secondary
        case .veryPoor: return .red
        case .poor: return .orange
        case .fair: return .yellow
        case .good: return .green
        case .excellent: return .green
        }
    }
}

extension GPSSignalLevel {
    var accessibilityDescription: String {
        switch self {
        case .none: return "No signal"
        case .veryPoor: return "Very poor"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

// MARK: - HeartRateStatusIndicator

/// Displays the heart rate monitor connection status.
private struct HeartRateStatusIndicator: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isConnected ? "heart.fill" : "heart")
                .font(.subheadline)
                .foregroundStyle(isConnected ? .red : .secondary)
                .symbolEffect(.pulse, options: .repeating, value: isConnected)

            Text("HR")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate monitor: \(isConnected ? "Connected" : "Disconnected")")
    }
}

// MARK: - MetricCardView

/// A card displaying a single workout metric with icon and styling.
private struct MetricCardView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    var isHighlighted: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon and title
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Value and unit
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHighlighted ? iconColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }

    private var cardBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color(.secondarySystemBackground))
        } else {
            return AnyShapeStyle(Color.white)
        }
    }
}

// MARK: - Preview

#Preview("Dashboard - Idle") {
    NavigationStack {
        DashboardView()
    }
    .appDependencies(AppDependencies.makeForPreview())
    .modelContainer(for: JogPodSchema.models, inMemory: true)
}

#Preview("Dashboard - Active Workout") {
    NavigationStack {
        DashboardView()
    }
    .appDependencies(AppDependencies.makeForPreview())
    .modelContainer(for: JogPodSchema.models, inMemory: true)
}
