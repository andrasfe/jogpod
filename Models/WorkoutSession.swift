import Foundation
import SwiftData

/// Represents a workout session with metadata including weather and location.
///
/// This model is the SwiftData equivalent of the legacy `WorkoutHistory` Core Data entity.
/// It stores high-level metadata about a workout session including start time, location,
/// and weather conditions at the time of the workout.
///
/// - Note: The original Core Data model used `WorkoutHistory` as the class name. This has been
///   renamed to `WorkoutSession` for clarity, as it represents a single session rather than
///   a historical record.
@Model
public final class WorkoutSession {

    // MARK: - Attributes

    /// Unique identifier for this workout session.
    ///
    /// This ID links `WorkoutLocation` and `WorkoutListeningLog` records to this session.
    @Attribute(.unique)
    var workoutID: String

    /// Reverse-geocoded address where the workout started.
    var address: String?

    /// Start time of the workout.
    var startTime: Date?

    // MARK: - Weather Attributes

    /// Humidity percentage at workout start (0.0 to 1.0 or 0 to 100).
    var humidity: Float?

    /// Temperature in Celsius at workout start.
    var temperatureInCelsius: Float?

    /// Wind speed in km/h at workout start.
    var windSpeedInKmh: Float?

    /// URL string for weather icon.
    var weatherIconUrl: String?

    // MARK: - Weather Alert Attributes

    /// Weather alert effective date.
    ///
    /// The date when the weather alert becomes effective.
    var alertDate: Date?

    /// Weather alert description text.
    var alertDescription: String?

    /// Weather alert expiration date.
    ///
    /// The date when the weather alert expires and is no longer valid.
    var alertExpires: Date?

    /// Type of weather alert (e.g., "heat", "storm", "wind").
    var alertType: String?

    // MARK: - Initialization

    /// Creates a new workout session with a unique identifier.
    ///
    /// - Parameter workoutID: The unique identifier for this session.
    ///   Defaults to a new UUID string if not provided.
    init(workoutID: String = UUID().uuidString) {
        self.workoutID = workoutID
    }

    /// Creates a new workout session with start time.
    ///
    /// - Parameters:
    ///   - workoutID: The unique identifier for this session.
    ///   - startTime: When the workout started.
    convenience init(workoutID: String = UUID().uuidString, startTime: Date) {
        self.init(workoutID: workoutID)
        self.startTime = startTime
    }
}

// MARK: - Computed Properties

extension WorkoutSession {

    /// Whether this session has any weather data recorded.
    var hasWeatherData: Bool {
        temperatureInCelsius != nil || humidity != nil || windSpeedInKmh != nil
    }

    /// Whether there is an active weather alert for this session.
    var hasWeatherAlert: Bool {
        alertType != nil && alertDescription != nil
    }

    /// Whether the weather alert is currently active (not expired).
    ///
    /// Returns `true` if there is an alert with an expiration date that is in the future,
    /// or if there is an alert without an expiration date specified.
    var isAlertActive: Bool {
        guard hasWeatherAlert else { return false }
        guard let expires = alertExpires else { return true }
        return expires > Date()
    }

    /// Formatted alert date string for display.
    var alertDateDisplay: String? {
        guard let date = alertDate else { return nil }
        return Self.alertDateFormatter.string(from: date)
    }

    /// Formatted alert expiration string for display.
    var alertExpiresDisplay: String? {
        guard let date = alertExpires else { return nil }
        return Self.alertDateFormatter.string(from: date)
    }

    /// Shared date formatter for alert date display.
    private static let alertDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Temperature formatted for display in Celsius.
    var temperatureDisplay: String? {
        guard let temp = temperatureInCelsius else { return nil }
        return String(format: "%.1f C", temp)
    }

    /// Temperature converted to Fahrenheit.
    var temperatureInFahrenheit: Float? {
        guard let celsius = temperatureInCelsius else { return nil }
        return (celsius * 9.0 / 5.0) + 32.0
    }
}

// MARK: - Static Fetch Helpers

extension WorkoutSession {

    /// Creates a fetch descriptor to find a workout session by ID.
    ///
    /// - Parameter workoutID: The workout ID to search for.
    /// - Returns: A configured FetchDescriptor.
    static func fetchDescriptor(forWorkoutID workoutID: String) -> FetchDescriptor<WorkoutSession> {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.workoutID == workoutID }
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// Creates a fetch descriptor for all sessions sorted by start time (most recent first).
    ///
    /// - Returns: A configured FetchDescriptor.
    static func allSessionsDescriptor() -> FetchDescriptor<WorkoutSession> {
        FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
    }
}
