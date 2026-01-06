//
//  StatsView.swift
//  JogPod
//
//  Workout statistics view displaying history, maps, and charts.
//

import SwiftUI
import SwiftData
import Charts
import MapKit

// MARK: - StatsView

/// The workout statistics and history view.
///
/// This view corresponds to the legacy `StatsViewController` and provides:
/// - Workout history list
/// - Route map visualization
/// - Performance charts and graphs
/// - Grid-based data display
/// - Listening log for each workout
///
/// ## Legacy Equivalence
///
/// This view replaces:
/// - `StatsViewController.h/.m`
/// - `StatsMapViewController.h/.m`
/// - `ChartViewController.h/.m`
/// - `GridViewController.h/.m`
/// - `ListeningLogViewController.h/.m`
/// - `WorkoutPickerViewController.h/.m`
/// - `ReportViewController.h/.m`
///
/// ## View Hierarchy
///
/// ```
/// StatsView
/// +-- NavigationStack
///     +-- ScrollView
///     |   +-- SummaryCard (total distance, workouts, avg pace)
///     |   +-- TimePeriodPicker (Week/Month/Year)
///     |   +-- ProgressChart (Swift Charts)
///     |   +-- VisualizationPicker (Map/Chart/Grid)
///     |   +-- Selected view content
///     +-- List: Workout History
///     |   +-- WorkoutRow (foreach)
///     +-- Navigation destinations
///         +-- WorkoutDetailView
/// ```
///
/// ## Data Visualization
///
/// - **Map View**: Shows workout routes with speed-based coloring
/// - **Chart View**: Displays pace, heart rate, elevation over time
/// - **Grid View**: Shows workout data in a tabular format
///
/// ## Accessibility
///
/// - Charts include VoiceOver descriptions
/// - List items have clear accessibility labels
/// - Supports Dynamic Type
public struct StatsView: View {

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var workouts: [WorkoutSession]

    // MARK: - State

    /// The currently selected visualization mode.
    @State private var selectedVisualization: VisualizationType = .chart

    /// The time period for progress charts.
    @State private var selectedTimePeriod: TimePeriod = .week

    /// The selected workout for detail view.
    @State private var selectedWorkout: WorkoutSession?

    /// Computed workout statistics from track points.
    @State private var workoutStats: [String: WorkoutStatistics] = [:]

    /// Loading state for statistics computation.
    @State private var isLoadingStats: Bool = true

    // MARK: - Body

    public var body: some View {
        Group {
            if workouts.isEmpty {
                emptyStateView
            } else {
                statsContent
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadWorkoutStatistics()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Workouts", systemImage: "figure.run")
        } description: {
            Text("Complete your first workout to see statistics here.")
        } actions: {
            Text("Start a workout from the Dashboard tab")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard

                timePeriodPicker

                progressChartSection

                visualizationPicker

                visualizationContent

                workoutHistorySection
            }
            .padding()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text("Total Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                SummaryItem(
                    title: "Workouts",
                    value: "\(workouts.count)",
                    icon: "figure.run"
                )

                SummaryItem(
                    title: "Distance",
                    value: formatTotalDistance(),
                    icon: "map"
                )

                SummaryItem(
                    title: "Time",
                    value: formatTotalDuration(),
                    icon: "clock"
                )
            }

            // Second row with additional stats
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Avg Pace",
                    value: formatAveragePace(),
                    icon: "speedometer"
                )

                SummaryItem(
                    title: "Calories",
                    value: formatTotalCalories(),
                    icon: "flame"
                )

                SummaryItem(
                    title: "Avg Distance",
                    value: formatAverageDistance(),
                    icon: "ruler"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Time Period Picker

    private var timePeriodPicker: some View {
        Picker("Time Period", selection: $selectedTimePeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Progress Chart Section

    private var progressChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)

            if filteredWorkoutsForPeriod.isEmpty {
                noDataForPeriodView
            } else {
                progressChart
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var noDataForPeriodView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No workouts in this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var progressChart: some View {
        Chart {
            ForEach(chartData, id: \.date) { dataPoint in
                BarMark(
                    x: .value("Date", dataPoint.date, unit: chartDateUnit),
                    y: .value("Distance", dataPoint.distance)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: chartAxisStride, count: chartAxisCount)) { value in
                AxisGridLine()
                AxisValueLabel(format: chartDateFormat)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let distance = value.as(Double.self) {
                        Text(formatDistance(distance))
                    }
                }
            }
        }
        .accessibilityLabel("Progress chart showing workout distances over time")
    }

    // MARK: - Visualization Picker

    private var visualizationPicker: some View {
        Picker("Visualization", selection: $selectedVisualization) {
            ForEach(VisualizationType.allCases) { type in
                Label(type.title, systemImage: type.iconName)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Visualization Content

    @ViewBuilder
    private var visualizationContent: some View {
        switch selectedVisualization {
        case .map:
            mapVisualization
        case .chart:
            chartVisualization
        case .grid:
            gridVisualization
        }
    }

    private var mapVisualization: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Route")
                .font(.headline)

            if let latestWorkout = workouts.first,
               let stats = workoutStats[latestWorkout.workoutID],
               !stats.coordinates.isEmpty {
                WorkoutMapView(coordinates: stats.coordinates)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                mapPlaceholder
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var mapPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No route data available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Map view placeholder. No route data available.")
    }

    private var chartVisualization: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.headline)

            if chartData.isEmpty {
                chartPlaceholder
            } else {
                performanceTrendsChart
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var performanceTrendsChart: some View {
        Chart {
            ForEach(chartData, id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Pace", dataPoint.averagePace)
                )
                .foregroundStyle(Color.orange.gradient)
                .symbol(.circle)

                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Pace", dataPoint.averagePace)
                )
                .foregroundStyle(Color.orange.opacity(0.1).gradient)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let pace = value.as(Double.self) {
                        Text(formatPace(pace))
                    }
                }
            }
        }
        .accessibilityLabel("Performance trends chart showing average pace over time")
    }

    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Performance Charts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Complete workouts to see trends")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("Chart view placeholder. Complete workouts to see performance trends.")
    }

    private var gridVisualization: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Data")
                .font(.headline)

            if workouts.isEmpty {
                gridPlaceholder
            } else {
                workoutDataGrid
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workoutDataGrid: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                GridHeaderCell(text: "Date")
                GridHeaderCell(text: "Distance")
                GridHeaderCell(text: "Duration")
                GridHeaderCell(text: "Pace")
            }
            .background(Color.orange.opacity(0.3))

            // Data rows
            ForEach(Array(workouts.prefix(10).enumerated()), id: \.element.workoutID) { index, workout in
                let stats = workoutStats[workout.workoutID]
                HStack(spacing: 0) {
                    GridDataCell(
                        text: workout.startTime?.formatted(.dateTime.month(.abbreviated).day()) ?? "--",
                        isAlternate: index % 2 == 0
                    )
                    GridDataCell(
                        text: formatDistance(stats?.distance ?? 0),
                        isAlternate: index % 2 == 0
                    )
                    GridDataCell(
                        text: formatDuration(stats?.duration ?? 0),
                        isAlternate: index % 2 == 0
                    )
                    GridDataCell(
                        text: formatPace(stats?.averagePace ?? 0),
                        isAlternate: index % 2 == 0
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var gridPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Data Grid")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No workout data available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("Grid view placeholder. No workout data available.")
    }

    // MARK: - Workout History Section

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)

            ForEach(workouts.prefix(5)) { workout in
                NavigationLink(value: workout) {
                    WorkoutHistoryRow(
                        workout: workout,
                        statistics: workoutStats[workout.workoutID]
                    )
                }
                .buttonStyle(.plain)
            }

            if workouts.count > 5 {
                NavigationLink("View All Workouts") {
                    AllWorkoutsView(workoutStats: workoutStats)
                }
                .font(.subheadline)
            }
        }
        .navigationDestination(for: WorkoutSession.self) { workout in
            WorkoutDetailView(
                workout: workout,
                statistics: workoutStats[workout.workoutID]
            )
        }
    }

    // MARK: - Data Loading

    private func loadWorkoutStatistics() async {
        isLoadingStats = true

        for workout in workouts {
            let stats = await computeStatistics(for: workout)
            workoutStats[workout.workoutID] = stats
        }

        isLoadingStats = false
    }

    private func computeStatistics(for workout: WorkoutSession) async -> WorkoutStatistics {
        let context = ModelContext(dependencies.modelContainer)
        let workoutID = workout.workoutID

        // Fetch track points for this workout
        let descriptor = FetchDescriptor<WorkoutTrackPoint>(
            predicate: #Predicate<WorkoutTrackPoint> { $0.workoutID == workoutID },
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )

        do {
            let trackPoints = try context.fetch(descriptor)
            return WorkoutStatistics(from: trackPoints, startTime: workout.startTime)
        } catch {
            return WorkoutStatistics()
        }
    }

    // MARK: - Chart Data

    private var chartData: [ChartDataPoint] {
        filteredWorkoutsForPeriod.compactMap { workout in
            guard let date = workout.startTime,
                  let stats = workoutStats[workout.workoutID] else {
                return nil
            }

            return ChartDataPoint(
                date: date,
                distance: stats.distance,
                duration: stats.duration,
                averagePace: stats.averagePace
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var filteredWorkoutsForPeriod: [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        switch selectedTimePeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        return workouts.filter { workout in
            guard let workoutDate = workout.startTime else { return false }
            return workoutDate >= startDate && workoutDate <= now
        }
    }

    private var chartDateUnit: Calendar.Component {
        switch selectedTimePeriod {
        case .week:
            return .day
        case .month:
            return .day
        case .year:
            return .month
        }
    }

    private var chartAxisStride: Calendar.Component {
        switch selectedTimePeriod {
        case .week:
            return .day
        case .month:
            return .weekOfMonth
        case .year:
            return .month
        }
    }

    private var chartAxisCount: Int {
        switch selectedTimePeriod {
        case .week:
            return 7
        case .month:
            return 4
        case .year:
            return 12
        }
    }

    private var chartDateFormat: Date.FormatStyle {
        switch selectedTimePeriod {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.day()
        case .year:
            return .dateTime.month(.abbreviated)
        }
    }

    // MARK: - Formatting Helpers

    private func formatTotalDistance() -> String {
        let totalMeters = workoutStats.values.reduce(0.0) { $0 + $1.distance }
        return formatDistance(totalMeters)
    }

    private func formatTotalDuration() -> String {
        let totalSeconds = workoutStats.values.reduce(0.0) { $0 + $1.duration }
        return formatDuration(totalSeconds)
    }

    private func formatAveragePace() -> String {
        let totalDistance = workoutStats.values.reduce(0.0) { $0 + $1.distance }
        let totalDuration = workoutStats.values.reduce(0.0) { $0 + $1.duration }

        guard totalDistance > 0 else { return "--:--" }

        let paceSecondsPerKm = totalDuration / (totalDistance / 1000)
        return formatPace(paceSecondsPerKm)
    }

    private func formatTotalCalories() -> String {
        let totalCalories = workoutStats.values.reduce(0) { $0 + $1.calories }
        if totalCalories > 0 {
            return "\(totalCalories)"
        }
        return "--"
    }

    private func formatAverageDistance() -> String {
        guard !workoutStats.isEmpty else { return "--" }
        let totalMeters = workoutStats.values.reduce(0.0) { $0 + $1.distance }
        let averageMeters = totalMeters / Double(workoutStats.count)
        return formatDistance(averageMeters)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }

    private func formatPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm > 0 && secondsPerKm.isFinite else { return "--:--" }
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

// MARK: - Supporting Types

/// Types of data visualization available.
private enum VisualizationType: String, CaseIterable, Identifiable {
    case map
    case chart
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map: return "Map"
        case .chart: return "Chart"
        case .grid: return "Grid"
        }
    }

    var iconName: String {
        switch self {
        case .map: return "map"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .grid: return "tablecells"
        }
    }
}

/// Time periods for chart filtering.
private enum TimePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

/// Chart data point for visualizations.
private struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let distance: Double
    let duration: TimeInterval
    let averagePace: Double
}

/// Computed statistics for a workout.
struct WorkoutStatistics {
    var distance: Double = 0
    var duration: TimeInterval = 0
    var averagePace: Double = 0
    var maxSpeed: Double = 0
    var calories: Int = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0
    var steps: Int = 0
    var coordinates: [CLLocationCoordinate2D] = []

    init() {}

    init(from trackPoints: [WorkoutTrackPoint], startTime: Date?) {
        guard !trackPoints.isEmpty else { return }

        // Calculate distance from track points
        var totalDistance: Double = 0
        var previousLocation: CLLocation?
        var speeds: [Double] = []
        var heartRates: [Int] = []
        var elevations: [Double] = []
        var totalSteps: Int = 0

        for point in trackPoints {
            // Collect coordinates for map
            if let coord = point.coordinate {
                coordinates.append(coord)
            }

            // Calculate distance
            if let location = point.clLocation {
                if let previous = previousLocation {
                    totalDistance += location.distance(from: previous)
                }
                previousLocation = location

                // Collect speed
                if let speed = point.speed, speed >= 0 {
                    speeds.append(speed)
                }

                // Collect elevation
                if let altitude = point.altitude {
                    elevations.append(altitude)
                }
            }

            // Collect heart rate
            if let hr = point.heartRate, hr > 0 {
                heartRates.append(Int(hr))
            }

            // Collect steps
            if let stepCount = point.steps {
                totalSteps = max(totalSteps, Int(stepCount))
            }
        }

        self.distance = totalDistance
        self.steps = totalSteps

        // Calculate duration
        if let firstTime = trackPoints.first?.time,
           let lastTime = trackPoints.last?.time {
            self.duration = lastTime.timeIntervalSince(firstTime)
        } else if let start = startTime, let lastTime = trackPoints.last?.time {
            self.duration = lastTime.timeIntervalSince(start)
        }

        // Calculate pace (seconds per km)
        if distance > 0 {
            self.averagePace = duration / (distance / 1000)
        }

        // Calculate max speed
        if !speeds.isEmpty {
            self.maxSpeed = speeds.max() ?? 0
        }

        // Calculate heart rate stats
        if !heartRates.isEmpty {
            self.averageHeartRate = heartRates.reduce(0, +) / heartRates.count
            self.maxHeartRate = heartRates.max() ?? 0
        }

        // Calculate elevation changes
        if elevations.count >= 2 {
            var gain: Double = 0
            var loss: Double = 0
            for i in 1..<elevations.count {
                let diff = elevations[i] - elevations[i - 1]
                if diff > 0 {
                    gain += diff
                } else {
                    loss += abs(diff)
                }
            }
            self.elevationGain = gain
            self.elevationLoss = loss
        }

        // Estimate calories (rough formula: 1 calorie per kg per km, assuming 70kg)
        // This is a simplified estimation
        self.calories = Int(distance / 1000 * 70)
    }
}

// MARK: - SummaryItem

/// A single summary statistic item.
private struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Grid Components

private struct GridHeaderCell: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
    }
}

private struct GridDataCell: View {
    let text: String
    let isAlternate: Bool

    var body: some View {
        Text(text)
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(isAlternate ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.05))
    }
}

// MARK: - WorkoutMapView

/// Map view showing workout route.
private struct WorkoutMapView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map {
            if !coordinates.isEmpty {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 3)

                // Start marker
                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            }
                    }
                }

                // End marker
                if let last = coordinates.last, coordinates.count > 1 {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            }
                    }
                }
            }
        }
        .mapStyle(.standard)
    }
}

// MARK: - WorkoutHistoryRow

/// Row displaying a workout in the history list.
private struct WorkoutHistoryRow: View {
    let workout: WorkoutSession
    let statistics: WorkoutStatistics?

    var body: some View {
        HStack(spacing: 12) {
            // Date circle
            VStack {
                Text(workout.startTime?.formatted(.dateTime.day()) ?? "--")
                    .font(.title2.weight(.semibold))
                Text(workout.startTime?.formatted(.dateTime.month(.abbreviated)) ?? "---")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.address ?? "Workout")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let stats = statistics {
                        Label(formatDistance(stats.distance), systemImage: "figure.walk")
                        Label(formatDuration(stats.duration), systemImage: "clock")
                    } else {
                        Label("-- km", systemImage: "figure.walk")
                        Label("--:--", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout on \(workout.startTime?.formatted(date: .abbreviated, time: .omitted) ?? "unknown date")")
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - WorkoutDetailView

/// Detail view for a single workout.
struct WorkoutDetailView: View {
    let workout: WorkoutSession
    let statistics: WorkoutStatistics?

    @Environment(\.modelContext) private var modelContext
    @State private var listeningLogs: [WorkoutListeningLog] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary header
                headerSection

                Divider()

                // Metrics grid
                metricsGrid

                // Map section
                if let stats = statistics, !stats.coordinates.isEmpty {
                    mapSection(coordinates: stats.coordinates)
                }

                // Performance section
                if statistics != nil {
                    performanceSection
                }

                // Weather section
                if workout.hasWeatherData {
                    weatherSection
                }

                // Listening log section
                listeningLogSection

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadListeningLogs()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(workout.startTime?.formatted(date: .complete, time: .shortened) ?? "Unknown")
                .font(.headline)

            if let address = workout.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricItem(
                title: "Distance",
                value: formatDistance(statistics?.distance ?? 0)
            )
            MetricItem(
                title: "Duration",
                value: formatDuration(statistics?.duration ?? 0)
            )
            MetricItem(
                title: "Avg Pace",
                value: formatPace(statistics?.averagePace ?? 0)
            )
            MetricItem(
                title: "Calories",
                value: statistics?.calories ?? 0 > 0 ? "\(statistics!.calories) kcal" : "-- kcal"
            )
        }
    }

    private func mapSection(coordinates: [CLLocationCoordinate2D]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)

            WorkoutMapView(coordinates: coordinates)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let stats = statistics {
                    if stats.steps > 0 {
                        MetricItem(title: "Steps", value: "\(stats.steps)")
                    }

                    if stats.averageHeartRate > 0 {
                        MetricItem(title: "Avg Heart Rate", value: "\(stats.averageHeartRate) bpm")
                    }

                    if stats.maxHeartRate > 0 {
                        MetricItem(title: "Max Heart Rate", value: "\(stats.maxHeartRate) bpm")
                    }

                    if stats.elevationGain > 0 {
                        MetricItem(title: "Elevation Gain", value: String(format: "%.0f m", stats.elevationGain))
                    }

                    if stats.elevationLoss > 0 {
                        MetricItem(title: "Elevation Loss", value: String(format: "%.0f m", stats.elevationLoss))
                    }

                    if stats.maxSpeed > 0 {
                        MetricItem(title: "Max Speed", value: String(format: "%.1f km/h", stats.maxSpeed * 3.6))
                    }
                }
            }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let temp = workout.temperatureInCelsius {
                    MetricItem(title: "Temperature", value: String(format: "%.1f C", temp))
                }

                if let humidity = workout.humidity {
                    MetricItem(title: "Humidity", value: String(format: "%.0f%%", humidity))
                }

                if let wind = workout.windSpeedInKmh {
                    MetricItem(title: "Wind", value: String(format: "%.0f km/h", wind))
                }
            }
        }
    }

    private var listeningLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listening Log")
                .font(.headline)

            if listeningLogs.isEmpty {
                Text("No podcasts were recorded during this workout.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(listeningLogs, id: \.entryTitle) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.entryTitle ?? "Unknown Episode")
                                .font(.subheadline)
                            Text(log.entityTitle ?? "Unknown Podcast")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let time = log.time {
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadListeningLogs() async {
        let workoutID = workout.workoutID
        let descriptor = FetchDescriptor<WorkoutListeningLog>(
            predicate: #Predicate<WorkoutListeningLog> { $0.workoutID == workoutID },
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )

        do {
            listeningLogs = try modelContext.fetch(descriptor)
        } catch {
            listeningLogs = []
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm > 0 && secondsPerKm.isFinite else { return "--:--/km" }
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

/// A metric item for the workout detail grid.
private struct MetricItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - AllWorkoutsView

/// View showing all workouts.
private struct AllWorkoutsView: View {
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var workouts: [WorkoutSession]

    let workoutStats: [String: WorkoutStatistics]

    var body: some View {
        List(workouts) { workout in
            NavigationLink(value: workout) {
                WorkoutHistoryRow(
                    workout: workout,
                    statistics: workoutStats[workout.workoutID]
                )
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle("All Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: WorkoutSession.self) { workout in
            WorkoutDetailView(
                workout: workout,
                statistics: workoutStats[workout.workoutID]
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StatsView()
    }
    .appDependencies(AppDependencies.makeForPreview())
    .modelContainer(for: JogPodSchema.models, inMemory: true)
}
