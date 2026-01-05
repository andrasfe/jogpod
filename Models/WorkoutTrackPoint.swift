import Foundation
import SwiftData
import CoreLocation

/// Represents a single GPS track point recorded during a workout.
///
/// This model is the SwiftData equivalent of the legacy `WorkoutLocation` Core Data entity.
/// It stores location data along with biometric information (heart rate, steps) captured
/// at a specific point in time during a workout.
///
/// - Note: The original Core Data model used `WorkoutLocation` as the class name. This has been
///   renamed to `WorkoutTrackPoint` for clarity, emphasizing that it represents a single point
///   in a workout track rather than a general location.
///
/// - Important: The `time` attribute should be used for chronological ordering of track points.
///   Points are typically recorded at regular intervals (e.g., every second or every few meters).
@Model
final class WorkoutTrackPoint {

    // MARK: - Attributes

    /// The workout session ID this track point belongs to.
    ///
    /// This links the track point to its parent `WorkoutSession`.
    /// Indexed for efficient queries.
    @Attribute(.spotlight)
    var workoutID: String

    /// The timestamp when this track point was recorded.
    ///
    /// Used for chronological ordering of track points within a workout.
    var time: Date?

    /// Heart rate in beats per minute at this point.
    ///
    /// Stored as Int16 for Core Data compatibility. Typical range: 40-220 BPM.
    var heartRate: Int16?

    /// Step count at this point.
    ///
    /// This may be cumulative or differential depending on how the app records it.
    /// Stored as Int16 for Core Data compatibility.
    var steps: Int16?

    /// Latitude coordinate.
    ///
    /// - Note: The legacy model stored location as a Transformable (likely CLLocation).
    ///   This has been decomposed into separate lat/long for SwiftData compatibility.
    var latitude: Double?

    /// Longitude coordinate.
    var longitude: Double?

    /// Horizontal accuracy in meters (from CLLocation).
    var horizontalAccuracy: Double?

    /// Altitude in meters (from CLLocation).
    var altitude: Double?

    /// Speed in meters per second (from CLLocation).
    var speed: Double?

    /// Course/heading in degrees (from CLLocation).
    var course: Double?

    // MARK: - Initialization

    /// Creates a new track point for a workout.
    ///
    /// - Parameters:
    ///   - workoutID: The ID of the parent workout session.
    ///   - time: When this point was recorded.
    init(workoutID: String, time: Date? = nil) {
        self.workoutID = workoutID
        self.time = time
    }

    /// Creates a new track point with location data.
    ///
    /// - Parameters:
    ///   - workoutID: The ID of the parent workout session.
    ///   - time: When this point was recorded.
    ///   - location: The CLLocation to extract coordinates from.
    ///   - heartRate: Optional heart rate in BPM.
    ///   - steps: Optional step count.
    convenience init(
        workoutID: String,
        time: Date,
        location: CLLocation,
        heartRate: Int16? = nil,
        steps: Int16? = nil
    ) {
        self.init(workoutID: workoutID, time: time)
        self.setLocation(location)
        self.heartRate = heartRate
        self.steps = steps
    }
}

// MARK: - Location Handling

extension WorkoutTrackPoint {

    /// Sets location data from a CLLocation object.
    ///
    /// - Parameter location: The CoreLocation object to extract data from.
    func setLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
    }

    /// Reconstructs a CLLocation from stored coordinates.
    ///
    /// - Returns: A CLLocation if coordinates are available, nil otherwise.
    var clLocation: CLLocation? {
        guard let lat = latitude, let long = longitude else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)

        return CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? -1,
            verticalAccuracy: -1,
            course: course ?? -1,
            speed: speed ?? -1,
            timestamp: time ?? Date()
        )
    }

    /// Returns the coordinate as a CLLocationCoordinate2D.
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let long = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: long)
    }

    /// Whether this track point has valid location data.
    var hasValidLocation: Bool {
        latitude != nil && longitude != nil
    }

    /// Speed converted to km/h.
    var speedInKmh: Double? {
        guard let mps = speed, mps >= 0 else { return nil }
        return mps * 3.6
    }

    /// Speed converted to miles per hour.
    var speedInMph: Double? {
        guard let mps = speed, mps >= 0 else { return nil }
        return mps * 2.23694
    }
}

// MARK: - Static Fetch Helpers

extension WorkoutTrackPoint {

    /// Creates a fetch descriptor for all track points of a workout, ordered chronologically.
    ///
    /// - Parameter workoutID: The workout ID to filter by.
    /// - Returns: A configured FetchDescriptor with chronological sort.
    static func fetchDescriptor(forWorkoutID workoutID: String) -> FetchDescriptor<WorkoutTrackPoint> {
        FetchDescriptor<WorkoutTrackPoint>(
            predicate: #Predicate<WorkoutTrackPoint> { $0.workoutID == workoutID },
            sortBy: [SortDescriptor(\.time, order: .forward)]
        )
    }
}
