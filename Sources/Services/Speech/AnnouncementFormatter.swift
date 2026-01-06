//
//  AnnouncementFormatter.swift
//  JogPod
//
//  Formats workout metrics into spoken announcements.
//

import Foundation

// MARK: - UnitSystem

/// The unit system for formatting measurements.
public enum UnitSystem: String, Sendable {
    /// Imperial units (miles, feet, Fahrenheit).
    case imperial

    /// Metric units (kilometers, meters, Celsius).
    case metric
}

// MARK: - WeatherData

/// Weather data for announcements.
public struct WeatherData: Sendable, Equatable {
    /// Temperature in the configured unit system.
    public let temperature: Double?

    /// Whether the temperature is valid.
    public var hasTemperature: Bool {
        temperature != nil && temperature != 0
    }

    /// Humidity as a percentage (0-100).
    public let humidity: Double?

    /// Wind speed in the configured unit system.
    public let windSpeed: Double?

    /// Wind direction as a string (e.g., "NW").
    public let windDirection: String?

    public init(
        temperature: Double? = nil,
        humidity: Double? = nil,
        windSpeed: Double? = nil,
        windDirection: String? = nil
    ) {
        self.temperature = temperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
    }
}

// MARK: - AnnouncementData

/// Data for generating workout announcements.
///
/// This struct contains all the metrics that can be announced during a workout.
/// Values are expected in base units (meters per second for speed, meters for distance, etc.)
/// and will be converted to the appropriate unit system when formatting.
public struct AnnouncementData: Sendable, Equatable {

    // MARK: - Speed Metrics (m/s)

    /// Current speed in meters per second.
    public var currentSpeed: Double

    /// Average speed in meters per second.
    public var averageSpeed: Double

    // MARK: - Heart Rate Metrics

    /// Current heart rate in BPM.
    public var currentHeartRate: Int

    /// Average heart rate in BPM.
    public var averageHeartRate: Int

    // MARK: - Distance Metrics (meters)

    /// Total distance in meters.
    public var distance: Double

    /// Total elevation gain in meters.
    public var totalAscent: Double

    /// Total elevation loss in meters.
    public var totalDescent: Double

    // MARK: - Other Metrics

    /// Calories burned.
    public var caloriesBurned: Int

    /// Workout duration in seconds.
    public var duration: TimeInterval

    // MARK: - Weather

    /// Weather data for announcements.
    public var weather: WeatherData?

    // MARK: - Initialization

    public init(
        currentSpeed: Double = 0,
        averageSpeed: Double = 0,
        currentHeartRate: Int = 0,
        averageHeartRate: Int = 0,
        distance: Double = 0,
        totalAscent: Double = 0,
        totalDescent: Double = 0,
        caloriesBurned: Int = 0,
        duration: TimeInterval = 0,
        weather: WeatherData? = nil
    ) {
        self.currentSpeed = currentSpeed
        self.averageSpeed = averageSpeed
        self.currentHeartRate = currentHeartRate
        self.averageHeartRate = averageHeartRate
        self.distance = distance
        self.totalAscent = totalAscent
        self.totalDescent = totalDescent
        self.caloriesBurned = caloriesBurned
        self.duration = duration
        self.weather = weather
    }
}

// MARK: - AnnouncementFormatter

/// Formats workout metrics into spoken announcement strings.
///
/// This class generates announcement text that matches the legacy format strings
/// from the Objective-C `WorkoutStats` class, ensuring behavioral equivalence
/// during migration.
///
/// ## Legacy Format Equivalence
///
/// The announcement strings are designed to match the legacy implementation exactly:
/// - "Current speed 5.2 miles per hour"
/// - "Average speed 8.1 kilometers per hour"
/// - "Heart rate 142"
/// - "Calories burned 350"
/// - "Distance 3.5 miles"
/// - "Uphill 150 feet"
/// - "Downhill 75 meters"
/// - "Duration 25 minutes"
/// - "Temperature 72 FAHRENHEIT"
///
/// ## Usage
///
/// ```swift
/// let formatter = AnnouncementFormatter(unitSystem: .imperial)
/// let data = AnnouncementData(currentSpeed: 2.3, distance: 5000)
///
/// // Format specific announcement
/// let speedAnnouncement = formatter.format(.currentSpeed, data: data)
/// // Returns: "Current speed 5.1 miles per hour"
///
/// // Get all enabled announcements
/// let enabled: Set<AnnouncementType> = [.currentSpeed, .distance]
/// let announcements = formatter.formatAll(data: data, enabled: enabled)
/// ```
public struct AnnouncementFormatter: Sendable {

    // MARK: - Constants

    /// Conversion factor from meters per second to miles per hour.
    private static let metersPerSecondToMph = 2.23694

    /// Conversion factor from meters per second to kilometers per hour.
    private static let metersPerSecondToKmh = 3.6

    /// Conversion factor from meters to miles.
    private static let metersToMiles = 0.000621371

    /// Conversion factor from meters to kilometers.
    private static let metersToKilometers = 0.001

    /// Conversion factor from meters to feet.
    private static let metersToFeet = 3.28084

    // MARK: - Properties

    /// The unit system to use for formatting.
    public let unitSystem: UnitSystem

    // MARK: - Initialization

    /// Creates a new AnnouncementFormatter.
    ///
    /// - Parameter unitSystem: The unit system to use. Defaults to `.imperial`.
    public init(unitSystem: UnitSystem = .imperial) {
        self.unitSystem = unitSystem
    }

    // MARK: - Formatting

    /// Formats a single announcement type.
    ///
    /// - Parameters:
    ///   - type: The type of announcement to format.
    ///   - data: The workout data to format.
    /// - Returns: The formatted announcement string, or nil if the data is not available.
    public func format(_ type: AnnouncementType, data: AnnouncementData) -> String? {
        switch type {
        case .currentSpeed:
            return formatCurrentSpeed(data.currentSpeed)

        case .averageSpeed:
            return formatAverageSpeed(data.averageSpeed)

        case .currentHeartRate:
            return formatCurrentHeartRate(data.currentHeartRate)

        case .averageHeartRate:
            return formatAverageHeartRate(data.averageHeartRate)

        case .totalAscent:
            return formatTotalAscent(data.totalAscent)

        case .totalDescent:
            return formatTotalDescent(data.totalDescent)

        case .caloriesBurned:
            return formatCaloriesBurned(data.caloriesBurned)

        case .duration:
            return formatDuration(data.duration)

        case .distance:
            return formatDistance(data.distance)

        case .temperature:
            return formatTemperature(data.weather?.temperature)

        case .humidity:
            return formatHumidity(data.weather?.humidity)

        case .windSpeed:
            return formatWindSpeed(data.weather?.windSpeed)
        }
    }

    /// Formats all enabled announcement types.
    ///
    /// - Parameters:
    ///   - data: The workout data to format.
    ///   - enabled: The set of enabled announcement types.
    /// - Returns: An array of formatted announcement strings.
    public func formatAll(
        data: AnnouncementData,
        enabled: Set<AnnouncementType>
    ) -> [String] {
        AnnouncementType.allCases
            .filter { enabled.contains($0) }
            .compactMap { format($0, data: data) }
    }

    // MARK: - Speed Formatting

    private func formatCurrentSpeed(_ speedMps: Double) -> String {
        let speed = convertSpeed(speedMps)
        return String(format: "Current speed %.1f %@", speed, speedUnitsLong)
    }

    private func formatAverageSpeed(_ speedMps: Double) -> String {
        let speed = convertSpeed(speedMps)
        return String(format: "Average speed %.1f %@", speed, speedUnitsLong)
    }

    private func convertSpeed(_ metersPerSecond: Double) -> Double {
        switch unitSystem {
        case .imperial:
            return metersPerSecond * Self.metersPerSecondToMph
        case .metric:
            return metersPerSecond * Self.metersPerSecondToKmh
        }
    }

    private var speedUnitsLong: String {
        switch unitSystem {
        case .imperial:
            return "miles per hour"
        case .metric:
            return "kilometers per hour"
        }
    }

    // MARK: - Heart Rate Formatting

    private func formatCurrentHeartRate(_ heartRate: Int) -> String? {
        guard heartRate > 0 else { return nil }
        return String(format: "Heart rate %d", heartRate)
    }

    private func formatAverageHeartRate(_ heartRate: Int) -> String? {
        guard heartRate > 0 else { return nil }
        return String(format: "Average heart rate %d", heartRate)
    }

    // MARK: - Distance Formatting

    private func formatDistance(_ distanceMeters: Double) -> String {
        let distance = convertDistance(distanceMeters)
        return String(format: "Distance %.1f %@", distance, distanceUnitsLong)
    }

    private func convertDistance(_ meters: Double) -> Double {
        switch unitSystem {
        case .imperial:
            return meters * Self.metersToMiles
        case .metric:
            return meters * Self.metersToKilometers
        }
    }

    private var distanceUnitsLong: String {
        switch unitSystem {
        case .imperial:
            return "miles"
        case .metric:
            return "kilometers"
        }
    }

    // MARK: - Elevation Formatting

    private func formatTotalAscent(_ meters: Double) -> String {
        let elevation = convertElevation(meters)
        return String(format: "Uphill %.0f %@", elevation, elevationUnitsLong)
    }

    private func formatTotalDescent(_ meters: Double) -> String {
        let elevation = convertElevation(meters)
        return String(format: "Downhill %.0f %@", elevation, elevationUnitsLong)
    }

    private func convertElevation(_ meters: Double) -> Double {
        switch unitSystem {
        case .imperial:
            return meters * Self.metersToFeet
        case .metric:
            return meters
        }
    }

    private var elevationUnitsLong: String {
        switch unitSystem {
        case .imperial:
            return "feet"
        case .metric:
            return "meters"
        }
    }

    // MARK: - Other Metrics Formatting

    private func formatCaloriesBurned(_ calories: Int) -> String {
        String(format: "Calories burned %d", calories)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return String(format: "Duration %d minutes", minutes)
    }

    // MARK: - Weather Formatting

    private func formatTemperature(_ temperature: Double?) -> String? {
        guard let temp = temperature, temp != 0 else { return nil }
        return String(format: "Temperature %.0f %@", temp, temperatureUnitsLong)
    }

    private var temperatureUnitsLong: String {
        switch unitSystem {
        case .imperial:
            return "FAHRENHEIT"
        case .metric:
            return "CELSIUS"
        }
    }

    private func formatHumidity(_ humidity: Double?) -> String? {
        guard let humidity = humidity else { return nil }
        return String(format: "Humidity %.0f percent", humidity)
    }

    private func formatWindSpeed(_ windSpeed: Double?) -> String? {
        guard let speed = windSpeed else { return nil }
        return String(format: "Wind speed %.0f %@", speed, speedUnitsLong)
    }
}

// MARK: - WorkoutSnapshot Extension

#if canImport(CoreLocation)
import CoreLocation

extension AnnouncementFormatter {

    /// Creates announcement data from a WorkoutSnapshot.
    ///
    /// This convenience method converts a WorkoutSnapshot (from WorkoutMetrics)
    /// into the AnnouncementData format expected by the formatter.
    ///
    /// - Parameters:
    ///   - snapshot: The workout snapshot to convert.
    ///   - weather: Optional weather data to include.
    /// - Returns: Announcement data populated from the snapshot.
    public func createAnnouncementData(
        from snapshot: WorkoutSnapshot,
        weather: WeatherData? = nil
    ) -> AnnouncementData {
        AnnouncementData(
            currentSpeed: snapshot.currentSpeed,
            averageSpeed: snapshot.averageSpeed,
            currentHeartRate: snapshot.currentHeartRate,
            averageHeartRate: snapshot.averageHeartRate,
            distance: snapshot.totalDistance,
            totalAscent: snapshot.totalElevationGain,
            totalDescent: snapshot.totalElevationLoss,
            caloriesBurned: snapshot.caloriesBurned,
            duration: snapshot.duration,
            weather: weather
        )
    }
}
#endif
