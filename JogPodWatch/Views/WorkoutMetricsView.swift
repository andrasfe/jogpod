//
//  WorkoutMetricsView.swift
//  JogPodWatch
//
//  Displays real-time workout metrics with carousel navigation.
//  Supports both iPhone-connected and independent workout modes.
//

import SwiftUI

// MARK: - WorkoutMetricsView

/// View displaying real-time workout metrics.
///
/// Features:
/// - Toggle to start/stop workout
/// - Carousel navigation through different metrics
/// - Real-time metric updates from iPhone or local watch sensors
/// - Independent workout mode when iPhone is not reachable
///
/// ## watchOS 10+ Features
///
/// - HKWorkoutSession for independent workout tracking
/// - Heart rate monitoring via watch sensors
/// - GPS tracking on cellular/GPS-enabled watches
/// - Haptic feedback for workout milestones
///
/// ## Legacy Equivalence
///
/// Replaces `InterfaceController` from the legacy WatchKit implementation.
/// Maintains the same metric carousel behavior with up/down buttons.
struct WorkoutMetricsView: View {

    // MARK: - Environment & State

    @Environment(WatchState.self) private var watchState
    @Environment(\.dismiss) private var dismiss

    @State private var isWorkoutOn: Bool = false
    @State private var showLoadingIndicator: Bool = false
    @State private var selectedMetricIndex: Int = 0
    @State private var showEndWorkoutConfirmation: Bool = false

    /// Reference to the workout service for independent mode.
    @StateObject private var workoutService = WatchWorkoutService.shared

    // MARK: - Computed Properties

    /// Whether we're in independent workout mode.
    private var isIndependentMode: Bool {
        watchState.isIndependentWorkout || !watchState.isReachable
    }

    /// The metrics to display (from iPhone or local sensors).
    private var currentMetrics: WatchWorkoutMetricsData? {
        isIndependentMode ? workoutService.currentMetrics : watchState.independentMetrics
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Connection Status Indicator
                if isIndependentMode && isWorkoutOn {
                    independentModeIndicator
                }

                // Workout Toggle
                workoutToggle

                Divider()
                    .padding(.horizontal)

                if isWorkoutOn {
                    if showLoadingIndicator {
                        loadingView
                    } else if isIndependentMode {
                        independentMetricsView
                    } else {
                        metricsCarouselView
                    }
                } else {
                    workoutOffView
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMetricsData()
        }
        .onChange(of: watchState.workoutInProgress) { _, newValue in
            if !isIndependentMode {
                isWorkoutOn = newValue
                if newValue {
                    showLoadingIndicator = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if showLoadingIndicator {
                            showLoadingIndicator = false
                        }
                    }
                }
            }
        }
        .onChange(of: workoutService.isWorkoutActive) { _, newValue in
            if isIndependentMode {
                isWorkoutOn = newValue
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showEndWorkoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("End & Save", role: .destructive) {
                Task {
                    await endIndependentWorkout()
                }
            }
            Button("Discard", role: .destructive) {
                Task {
                    await discardIndependentWorkout()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this workout to your activity history?")
        }
    }

    // MARK: - Subviews

    private var independentModeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "applewatch")
                .font(.system(size: 10))
            Text("Independent Mode")
                .font(.system(size: 10))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.2))
        )
    }

    private var workoutToggle: some View {
        Toggle(isOn: $isWorkoutOn) {
            HStack {
                Text("Metrics")
                    .font(.system(size: 14, weight: .medium))
                if workoutService.isWorkoutPaused {
                    Text("(Paused)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.green)
        .padding(.horizontal, 16)
        .onChange(of: isWorkoutOn) { _, newValue in
            handleWorkoutToggle(newValue)
        }
    }

    private var workoutOffView: some View {
        VStack(spacing: 16) {
            if !watchState.isReachable {
                VStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text("iPhone not connected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Workout will be tracked on your Apple Watch")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Text("Turn on metrics to measure your workout progress")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
                .padding()

            // Pending sync indicator
            if watchState.pendingSyncCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("\(watchState.pendingSyncCount) workout\(watchState.pendingSyncCount == 1 ? "" : "s") pending sync")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)

            Text(isIndependentMode ? "Starting workout..." : "Waiting for GPS...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private var independentMetricsView: some View {
        VStack(spacing: 8) {
            // Heart Rate
            metricRow(
                icon: "heart.fill",
                iconColor: .red,
                value: String(format: "%.0f", workoutService.currentHeartRate),
                unit: "BPM",
                label: "Heart Rate"
            )

            // Duration
            metricRow(
                icon: "clock.fill",
                iconColor: .blue,
                value: workoutService.currentMetrics.formattedElapsedTime,
                unit: "",
                label: "Duration"
            )

            // Distance
            metricRow(
                icon: "figure.run",
                iconColor: .green,
                value: workoutService.currentMetrics.formattedDistance,
                unit: "",
                label: "Distance"
            )

            // Pace
            metricRow(
                icon: "speedometer",
                iconColor: .orange,
                value: workoutService.currentMetrics.formattedPace,
                unit: "/km",
                label: "Pace"
            )

            // Calories
            metricRow(
                icon: "flame.fill",
                iconColor: .red,
                value: String(format: "%.0f", workoutService.activeCalories),
                unit: "cal",
                label: "Active Calories"
            )

            // Pause/Resume Button
            if workoutService.isWorkoutPaused {
                Button(action: resumeWorkout) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 8)
            } else {
                Button(action: pauseWorkout) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 8)
    }

    private func metricRow(
        icon: String,
        iconColor: Color,
        value: String,
        unit: String,
        label: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
        )
    }

    private var metricsCarouselView: some View {
        VStack(spacing: 8) {
            // Up Button (Previous Metric)
            Button(action: previousMetric) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 32)
            }
            .buttonStyle(.plain)

            // Metric Value Display
            metricValueView

            // Down Button (Next Metric)
            Button(action: nextMetric) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var metricValueView: some View {
        VStack(spacing: 4) {
            // Main Value
            Text(watchState.workoutMetrics.currentMetricValue)
                .font(.system(size: 36, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: watchState.workoutMetrics.currentMetricValue)

            // Description and Units
            HStack(spacing: 4) {
                Text(watchState.workoutMetrics.currentMetricDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if !watchState.workoutMetrics.currentMetricUnits.isEmpty {
                    Text("(\(watchState.workoutMetrics.currentMetricUnits))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Page Indicator
            pageIndicator
        }
        .padding(.vertical, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<watchState.workoutMetrics.metricCount, id: \.self) { index in
                Circle()
                    .fill(index == watchState.workoutMetrics.currentMetricIndex ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func handleWorkoutToggle(_ isOn: Bool) {
        if isIndependentMode || !watchState.isReachable {
            // Independent workout mode
            if isOn {
                startIndependentWorkout()
            } else {
                showEndWorkoutConfirmation = true
            }
        } else {
            // iPhone-connected mode
            WatchConnectivityManager.shared.sendAction(.toggleWorkout(on: isOn))

            if isOn {
                showLoadingIndicator = true
            } else {
                showLoadingIndicator = false
            }
        }
    }

    private func startIndependentWorkout() {
        Task {
            do {
                showLoadingIndicator = true
                try await workoutService.requestAuthorization()
                try await workoutService.startWorkout()
                watchState.isIndependentWorkout = true
                watchState.workoutInProgress = true
                showLoadingIndicator = false
            } catch {
                showLoadingIndicator = false
                isWorkoutOn = false
                watchState.showError(error.localizedDescription)
            }
        }
    }

    private func pauseWorkout() {
        Task {
            try? await workoutService.pauseWorkout()
        }
    }

    private func resumeWorkout() {
        Task {
            try? await workoutService.resumeWorkout()
        }
    }

    private func endIndependentWorkout() async {
        do {
            let result = try await workoutService.endWorkout()

            // Queue for sync
            WorkoutDataSync.shared.queueWorkoutForSync(result)

            watchState.isIndependentWorkout = false
            watchState.workoutInProgress = false
            watchState.pendingSyncCount = WorkoutDataSync.shared.pendingItemCount
            isWorkoutOn = false
        } catch {
            watchState.showError(error.localizedDescription)
        }
    }

    private func discardIndependentWorkout() async {
        await workoutService.discardWorkout()
        watchState.isIndependentWorkout = false
        watchState.workoutInProgress = false
        isWorkoutOn = false
    }

    private func nextMetric() {
        watchState.workoutMetrics.nextMetric()
        WatchConnectivityManager.shared.sendAction(.changeMetric(index: watchState.workoutMetrics.currentMetricIndex))
    }

    private func previousMetric() {
        watchState.workoutMetrics.previousMetric()
        WatchConnectivityManager.shared.sendAction(.changeMetric(index: watchState.workoutMetrics.currentMetricIndex))
    }

    private func loadMetricsData() async {
        // Check if iPhone is reachable
        if watchState.isReachable {
            await WatchConnectivityManager.shared.requestMetricsData()
            isWorkoutOn = watchState.workoutInProgress
        } else {
            // Check if we have an active independent workout
            isWorkoutOn = workoutService.isWorkoutActive
        }

        // Update pending sync count
        watchState.pendingSyncCount = WorkoutDataSync.shared.pendingItemCount

        if isWorkoutOn && !isIndependentMode {
            showLoadingIndicator = true
            try? await Task.sleep(for: .seconds(1))
            showLoadingIndicator = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutMetricsView()
    }
    .environment(WatchState())
}
