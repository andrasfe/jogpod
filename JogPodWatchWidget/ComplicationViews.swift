//
//  ComplicationViews.swift
//  JogPodWatchWidget
//
//  SwiftUI views for various complication families.
//  Supports circular, corner, and rectangular complications for watchOS 10+.
//

import SwiftUI
import WidgetKit

// MARK: - Circular Complication View

/// View for accessoryCircular complication family.
///
/// Displays a compact circular view with:
/// - Active workout: distance value with running icon
/// - Idle: last workout distance or placeholder
///
/// ## Design Notes
///
/// The circular complication has very limited space (about 36x36 points).
/// We prioritize showing the most important single metric: distance.
struct CircularComplicationView: View {

    let entry: WorkoutComplicationEntry

    var body: some View {
        ZStack {
            if entry.isWorkoutActive, let metrics = entry.currentMetrics {
                // Active workout: show current distance
                activeWorkoutView(metrics: metrics)
            } else if let summary = entry.lastWorkoutSummary {
                // Idle: show last workout
                lastWorkoutView(summary: summary)
            } else {
                // No data
                noDataView
            }
        }
        .widgetAccentable()
    }

    private func activeWorkoutView(metrics: ComplicationWorkoutMetrics) -> some View {
        VStack(spacing: 0) {
            // Running indicator
            Image(systemName: "figure.run")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green)

            // Distance value
            Text(metrics.formattedDistance)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)

            // Unit
            Text(metrics.distanceUnit)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func lastWorkoutView(summary: ComplicationWorkoutSummary) -> some View {
        VStack(spacing: 0) {
            // Checkmark to indicate completed
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.blue)

            // Last distance
            Text(summary.formattedDistance)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)

            // Unit
            Text(summary.distanceUnit)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var noDataView: some View {
        VStack(spacing: 2) {
            Image(systemName: "figure.run")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("--")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Graphic Corner Complication View

/// View for accessoryCorner complication family.
///
/// Displays workout status with:
/// - Active workout: running icon with pace
/// - Idle: summary icon with relative time
///
/// Corner complications appear at the corners of watch faces like Infograph.
struct CornerComplicationView: View {

    let entry: WorkoutComplicationEntry

    var body: some View {
        if entry.isWorkoutActive, let metrics = entry.currentMetrics {
            activeWorkoutCorner(metrics: metrics)
        } else if let summary = entry.lastWorkoutSummary {
            lastWorkoutCorner(summary: summary)
        } else {
            noDataCorner
        }
    }

    private func activeWorkoutCorner(metrics: ComplicationWorkoutMetrics) -> some View {
        ZStack {
            // Gauge showing workout progress
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: "figure.run")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.green)

                Text(metrics.pace)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .widgetLabel {
            Text("\(metrics.formattedDistance) \(metrics.distanceUnit)")
        }
    }

    private func lastWorkoutCorner(summary: ComplicationWorkoutSummary) -> some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: "figure.run.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
            }
        }
        .widgetLabel {
            Text(summary.relativeTimeString)
        }
    }

    private var noDataCorner: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "figure.run")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .widgetLabel {
            Text("JogPod")
        }
    }
}

// MARK: - Graphic Rectangular Complication View

/// View for accessoryRectangular complication family.
///
/// Displays detailed workout information with multiple metrics:
/// - Active workout: distance, pace, duration
/// - Idle: last workout summary with date
///
/// This is the largest complication type and can show the most information.
struct RectangularComplicationView: View {

    let entry: WorkoutComplicationEntry

    var body: some View {
        if entry.isWorkoutActive, let metrics = entry.currentMetrics {
            activeWorkoutRectangular(metrics: metrics)
        } else if let summary = entry.lastWorkoutSummary {
            lastWorkoutRectangular(summary: summary)
        } else {
            noDataRectangular
        }
    }

    private func activeWorkoutRectangular(metrics: ComplicationWorkoutMetrics) -> some View {
        HStack(spacing: 8) {
            // Left side: running indicator
            VStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.green)

                Text("ACTIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(width: 40)

            // Right side: metrics
            VStack(alignment: .leading, spacing: 2) {
                // Distance
                HStack(spacing: 4) {
                    Text(metrics.formattedDistance)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Text(metrics.distanceUnit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Pace and Duration
                HStack(spacing: 8) {
                    // Pace
                    HStack(spacing: 2) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(metrics.pace)
                            .font(.system(size: 10, weight: .medium))
                    }

                    // Duration
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(metrics.shortDuration)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func lastWorkoutRectangular(summary: ComplicationWorkoutSummary) -> some View {
        HStack(spacing: 8) {
            // Left side: checkmark
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)

                Text("LAST")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            // Right side: summary
            VStack(alignment: .leading, spacing: 2) {
                // Distance
                HStack(spacing: 4) {
                    Text(summary.formattedDistance)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Text(summary.distanceUnit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Pace and Time ago
                HStack(spacing: 8) {
                    // Pace
                    HStack(spacing: 2) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(summary.averagePace)
                            .font(.system(size: 10, weight: .medium))
                    }

                    // Time ago
                    Text(summary.relativeTimeString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var noDataRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("JogPod")
                    .font(.system(size: 14, weight: .semibold))

                Text("No workouts yet")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Inline Complication View

/// View for accessoryInline complication family.
///
/// Displays a single line of text with optional icon.
/// Used in places where only minimal text can be shown.
struct InlineComplicationView: View {

    let entry: WorkoutComplicationEntry

    var body: some View {
        if entry.isWorkoutActive, let metrics = entry.currentMetrics {
            Label(
                "\(metrics.formattedDistance)\(metrics.distanceUnit) | \(metrics.pace)",
                systemImage: "figure.run"
            )
        } else if let summary = entry.lastWorkoutSummary {
            Label(
                "\(summary.formattedDistance)\(summary.distanceUnit) \(summary.relativeTimeString)",
                systemImage: "figure.run.circle"
            )
        } else {
            Label("JogPod", systemImage: "figure.run")
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ComplicationViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Circular - Active
            CircularComplicationView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular - Active")

            // Circular - Last Workout
            CircularComplicationView(entry: WorkoutComplicationEntry(
                isWorkoutActive: false,
                lastWorkoutSummary: ComplicationWorkoutSummary(
                    workoutDate: Date().addingTimeInterval(-7200),
                    distance: 8.5,
                    distanceUnit: "km",
                    averagePace: "5:45",
                    duration: 2700,
                    calories: 420
                )
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular - Last")

            // Corner - Active
            CornerComplicationView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCorner))
                .previewDisplayName("Corner - Active")

            // Rectangular - Active
            RectangularComplicationView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular - Active")

            // Rectangular - Last Workout
            RectangularComplicationView(entry: WorkoutComplicationEntry(
                isWorkoutActive: false,
                lastWorkoutSummary: ComplicationWorkoutSummary(
                    workoutDate: Date().addingTimeInterval(-86400),
                    distance: 10.0,
                    distanceUnit: "km",
                    averagePace: "5:15",
                    duration: 3150,
                    calories: 580
                )
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular - Last")

            // Rectangular - No Data
            RectangularComplicationView(entry: .noData)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular - No Data")
        }
    }
}
#endif
