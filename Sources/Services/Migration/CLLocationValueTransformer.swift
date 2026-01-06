import Foundation
import CoreLocation

/// A custom value transformer for CLLocation that handles both legacy and secure unarchiving.
///
/// The legacy JogPod app (iOS 7 era) stored CLLocation objects using NSKeyedArchiver
/// without secure coding. This transformer attempts secure unarchiving first, then
/// falls back to legacy unarchiving for older data.
///
/// ## Legacy Data Format
///
/// The original Core Data model used a Transformable attribute with an empty
/// `valueTransformerName`, which caused Core Data to use NSKeyedArchiver internally.
/// CLLocation was archived using the pre-iOS 12 non-secure archiver.
///
/// ## Migration Strategy
///
/// 1. First attempt secure unarchiving (for any newer data)
/// 2. Fall back to legacy unarchiving (for iOS 7-11 era data)
/// 3. Handle edge cases where data might be corrupted or nil
///
/// - Important: This transformer is read-only for migration purposes.
///   The new SwiftData model stores location as separate latitude/longitude doubles.
@objc(CLLocationValueTransformer)
final class CLLocationValueTransformer: ValueTransformer {

    /// The transformer name for registration with Foundation.
    static let transformerName = NSValueTransformerName("CLLocationValueTransformer")

    /// Registers this transformer with the Foundation value transformer registry.
    ///
    /// Call this before creating the Core Data model that references this transformer.
    /// Safe to call multiple times - subsequent calls are no-ops.
    static func register() {
        // Only register once
        guard ValueTransformer(forName: transformerName) == nil else { return }
        ValueTransformer.setValueTransformer(CLLocationValueTransformer(), forName: transformerName)
    }

    // MARK: - ValueTransformer Overrides

    override class func transformedValueClass() -> AnyClass {
        CLLocation.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    /// Transforms a CLLocation to Data for storage.
    ///
    /// Uses secure archiving for writing new data.
    override func transformedValue(_ value: Any?) -> Any? {
        guard let location = value as? CLLocation else { return nil }

        do {
            return try NSKeyedArchiver.archivedData(
                withRootObject: location,
                requiringSecureCoding: true
            )
        } catch {
            // Fall back to non-secure archiving as last resort
            return try? NSKeyedArchiver.archivedData(
                withRootObject: location,
                requiringSecureCoding: false
            )
        }
    }

    /// Transforms Data back to a CLLocation.
    ///
    /// This method handles both secure and legacy archived data formats.
    /// It tries multiple unarchiving strategies to maximize compatibility
    /// with legacy iOS 7+ data.
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }

        // Strategy 1: Try secure unarchiving first (iOS 12+)
        if let location = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: CLLocation.self,
            from: data
        ) {
            return location
        }

        // Strategy 2: Try legacy unarchiving with allowed classes (iOS 11+)
        if let location = unarchiveWithAllowedClasses(data: data) {
            return location
        }

        // Strategy 3: Try completely legacy unarchiving (pre-iOS 11 data)
        if let location = unarchiveLegacy(data: data) {
            return location
        }

        // Strategy 4: Handle edge case where data might be the string description
        // The legacy CodingValueTransformer.m had a bug where it stored
        // CLLocation.description instead of the archived data in some cases
        if let location = parseLocationFromDescription(data: data) {
            return location
        }

        return nil
    }

    // MARK: - Private Unarchiving Methods

    /// Attempts to unarchive using allowed classes configuration.
    private func unarchiveWithAllowedClasses(data: Data) -> CLLocation? {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false

            // Allow CLLocation and its dependencies
            let allowedClasses: [AnyClass] = [
                CLLocation.self,
                NSDate.self,
                NSNumber.self,
                NSValue.self,
                NSDictionary.self,
                NSArray.self,
                NSString.self
            ]

            unarchiver.setClass(CLLocation.self, forClassName: "CLLocation")

            let location = unarchiver.decodeObject(of: allowedClasses, forKey: NSKeyedArchiveRootObjectKey)
            unarchiver.finishDecoding()

            return location as? CLLocation
        } catch {
            return nil
        }
    }

    /// Attempts completely legacy unarchiving without secure coding.
    private func unarchiveLegacy(data: Data) -> CLLocation? {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false

            // Decode without type checking
            let object = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            unarchiver.finishDecoding()

            return object as? CLLocation
        } catch {
            // Last resort: try initializing with data directly
            // This handles edge cases from very old archives (iOS 7-9 era)
            // where the archive format may be slightly different
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                unarchiver.decodingFailurePolicy = .setErrorAndReturn

                // Try decoding as raw object without specifying the key
                if let location = unarchiver.decodeObject() as? CLLocation {
                    unarchiver.finishDecoding()
                    return location
                }

                unarchiver.finishDecoding()
                return nil
            } catch {
                // Unable to unarchive - data may be corrupted or in unknown format
                return nil
            }
        }
    }

    /// Attempts to parse a CLLocation from a string description.
    ///
    /// The legacy CodingValueTransformer had a bug where it stored the string
    /// description of CLLocation instead of the archived data:
    /// ```
    /// if ([value isKindOfClass:[CLLocation class]]) {
    ///     return [(CLLocation*)value description];
    /// }
    /// ```
    ///
    /// CLLocation.description format is approximately:
    /// `<+37.78583400,-122.40641700> +/- 5.00m (speed 2.50 mps / course 90.00) @ 2024-01-01 12:00:00 +0000`
    private func parseLocationFromDescription(data: Data) -> CLLocation? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }

        // Try to parse coordinates from the description string
        // Format: <+lat,-long> or <lat,long>
        let pattern = #"<([+-]?\d+\.?\d*),([+-]?\d+\.?\d*)>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else {
            return nil
        }

        guard match.numberOfRanges >= 3 else { return nil }

        guard let latRange = Range(match.range(at: 1), in: string),
              let longRange = Range(match.range(at: 2), in: string),
              let latitude = Double(string[latRange]),
              let longitude = Double(string[longRange]) else {
            return nil
        }

        // Validate coordinate ranges
        guard latitude >= -90 && latitude <= 90 &&
              longitude >= -180 && longitude <= 180 else {
            return nil
        }

        // Create a basic CLLocation from the parsed coordinates
        // Additional properties (accuracy, altitude, etc.) are lost
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

// MARK: - CLLocation Secure Coding Registration

extension CLLocation {
    /// Ensures CLLocation is registered for secure coding.
    ///
    /// CLLocation conforms to NSSecureCoding since iOS 8, but this helps ensure
    /// the class is properly registered in the unarchiver's allowed classes.
    @objc static func registerForSecureCoding() {
        // CLLocation already conforms to NSSecureCoding
        // This is a no-op but documents the requirement
    }
}
