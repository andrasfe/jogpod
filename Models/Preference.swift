import Foundation
import SwiftData

/// A key-value storage model for user preferences.
///
/// This model is the SwiftData equivalent of the legacy `Preference` Core Data entity.
/// It provides a flexible schema for storing various types of values under named keys.
///
/// The model supports multiple value types:
/// - Boolean values (`boolValue`)
/// - Date values (`dateValue`)
/// - Float values (`floatValue`)
/// - Integer values (`intValue`)
/// - String values (`stringValue`)
/// - Coordinate values (`latCoord`, `longCoord`)
///
/// - Important: The `name` attribute must be unique. Use `#Unique` macro to enforce this.
@Model
final class Preference {

    // MARK: - Attributes

    /// The unique key/name for this preference.
    ///
    /// This is indexed for fast lookups and must be unique across all Preference instances.
    @Attribute(.unique)
    var name: String

    /// Boolean value storage.
    var boolValue: Bool?

    /// Date value storage.
    var dateValue: Date?

    /// Float value storage.
    var floatValue: Float?

    /// Integer value storage (Int16 for Core Data compatibility).
    var intValue: Int16?

    /// Latitude coordinate storage.
    var latCoord: Double?

    /// Longitude coordinate storage.
    var longCoord: Double?

    /// String value storage.
    var stringValue: String?

    // MARK: - Initialization

    /// Creates a new preference with the given name.
    ///
    /// - Parameter name: The unique key for this preference.
    init(name: String) {
        self.name = name
    }

    /// Creates a boolean preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - value: The boolean value to store.
    convenience init(name: String, boolValue value: Bool) {
        self.init(name: name)
        self.boolValue = value
    }

    /// Creates a string preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - value: The string value to store.
    convenience init(name: String, stringValue value: String) {
        self.init(name: name)
        self.stringValue = value
    }

    /// Creates an integer preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - value: The integer value to store.
    convenience init(name: String, intValue value: Int16) {
        self.init(name: name)
        self.intValue = value
    }

    /// Creates a float preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - value: The float value to store.
    convenience init(name: String, floatValue value: Float) {
        self.init(name: name)
        self.floatValue = value
    }

    /// Creates a date preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - value: The date value to store.
    convenience init(name: String, dateValue value: Date) {
        self.init(name: name)
        self.dateValue = value
    }

    /// Creates a coordinate preference.
    ///
    /// - Parameters:
    ///   - name: The unique key for this preference.
    ///   - latitude: The latitude coordinate.
    ///   - longitude: The longitude coordinate.
    convenience init(name: String, latitude: Double, longitude: Double) {
        self.init(name: name)
        self.latCoord = latitude
        self.longCoord = longitude
    }
}

// MARK: - Convenience Accessors

extension Preference {

    /// Returns the stored coordinate as a tuple, if both lat and long are present.
    var coordinate: (latitude: Double, longitude: Double)? {
        guard let lat = latCoord, let long = longCoord else { return nil }
        return (lat, long)
    }

    /// Sets both latitude and longitude coordinates.
    ///
    /// - Parameters:
    ///   - latitude: The latitude coordinate.
    ///   - longitude: The longitude coordinate.
    func setCoordinate(latitude: Double, longitude: Double) {
        self.latCoord = latitude
        self.longCoord = longitude
    }
}

// MARK: - Static Fetch Helpers

extension Preference {

    /// Creates a fetch descriptor to find a preference by name.
    ///
    /// - Parameter name: The preference name to search for.
    /// - Returns: A configured FetchDescriptor.
    static func fetchDescriptor(forName name: String) -> FetchDescriptor<Preference> {
        var descriptor = FetchDescriptor<Preference>(
            predicate: #Predicate<Preference> { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}
