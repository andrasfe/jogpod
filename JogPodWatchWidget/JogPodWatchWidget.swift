//
//  JogPodWatchWidget.swift
//  JogPodWatchWidget
//
//  Main widget bundle for JogPod watchOS complications.
//  Provides WidgetKit-based complications for watchOS 10+.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

/// Widget bundle containing all JogPod complications.
///
/// This bundle registers all available complication types with WidgetKit.
/// Each complication is a separate widget that can be added to compatible
/// watch faces.
@main
struct JogPodWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutComplication()
    }
}

// MARK: - Workout Complication Widget

/// Main workout complication widget.
///
/// Supports multiple complication families:
/// - accessoryCircular: Small circular complication
/// - accessoryCorner: Corner complication with label
/// - accessoryRectangular: Larger rectangular complication
/// - accessoryInline: Single line text complication
///
/// ## Deep Link Support
///
/// Tapping any complication launches the JogPod app using a URL scheme.
/// The URL includes context about which view to navigate to.
struct WorkoutComplication: Widget {

    // MARK: - Properties

    /// Unique identifier for this complication.
    let kind: String = "com.jogpod.workout-complication"

    // MARK: - Widget Configuration

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WorkoutTimelineProvider()
        ) { entry in
            WorkoutComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("JogPod Workout")
        .description("Track your running workouts at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Complication Entry View

/// Entry view that routes to the appropriate complication view based on family.
struct WorkoutComplicationEntryView: View {

    // MARK: - Environment

    @Environment(\.widgetFamily) var widgetFamily

    // MARK: - Properties

    let entry: WorkoutComplicationEntry

    // MARK: - Body

    var body: some View {
        Group {
            switch widgetFamily {
            case .accessoryCircular:
                CircularComplicationView(entry: entry)

            case .accessoryCorner:
                CornerComplicationView(entry: entry)

            case .accessoryRectangular:
                RectangularComplicationView(entry: entry)

            case .accessoryInline:
                InlineComplicationView(entry: entry)

            @unknown default:
                // Fallback to circular for unknown families
                CircularComplicationView(entry: entry)
            }
        }
        // Deep link to app when tapped
        .widgetURL(complicationURL)
    }

    // MARK: - Deep Link URL

    /// URL for launching the app when complication is tapped.
    private var complicationURL: URL? {
        if entry.isWorkoutActive {
            // Navigate to workout metrics view
            return URL(string: "jogpod://workout")
        } else if entry.lastWorkoutSummary != nil {
            // Navigate to stats view
            return URL(string: "jogpod://stats")
        } else {
            // Navigate to dashboard
            return URL(string: "jogpod://dashboard")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct JogPodWatchWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Active workout previews
            WorkoutComplicationEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular")

            WorkoutComplicationEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCorner))
                .previewDisplayName("Corner")

            WorkoutComplicationEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")

            WorkoutComplicationEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Inline")

            // No data preview
            WorkoutComplicationEntryView(entry: .noData)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("No Data")
        }
    }
}
#endif
