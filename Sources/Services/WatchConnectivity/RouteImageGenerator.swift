//
//  RouteImageGenerator.swift
//  JogPod
//
//  Generates static route map images for Apple Watch stats view.
//  Uses MapKit MKMapSnapshotter for native map rendering.
//

import Foundation
import MapKit
import CoreLocation
import UIKit

// MARK: - RouteImageGenerator

/// Generates static map images of workout routes for the Apple Watch stats view.
///
/// This service creates PNG images showing the workout route overlaid on a map tile.
/// It uses MapKit's MKMapSnapshotter for native map rendering, replacing the legacy
/// Google Static Maps API approach.
///
/// ## Watch Display Sizes
///
/// The generator supports multiple watch sizes:
/// - 40mm/41mm: 312x156 points
/// - 44mm/45mm: 352x176 points
/// - 49mm (Ultra): 410x205 points
///
/// ## Usage
///
/// ```swift
/// let generator = RouteImageGenerator(
///     workoutService: workoutService,
///     persistenceManager: persistenceManager
/// )
///
/// if let imageData = await generator.generateRouteImage() {
///     // Send to watch
/// }
/// ```
///
/// ## Legacy Equivalence
///
/// Replaces `RouteImageGenerator.m` and `MapImageGenerator.m` from the legacy codebase.
/// The legacy implementation used Google Static Maps API with encoded polylines.
/// This modern implementation uses native MapKit for better privacy and performance.
public final class RouteImageGenerator: RouteImageGenerating, @unchecked Sendable {

    // MARK: - Configuration

    /// Default image size for 44mm/45mm watch displays.
    public static let defaultImageSize = CGSize(width: 352, height: 176)

    /// Image size for 40mm/41mm watch displays.
    public static let smallImageSize = CGSize(width: 312, height: 156)

    /// Image size for 49mm Ultra watch displays.
    public static let ultraImageSize = CGSize(width: 410, height: 205)

    /// Route line width in points.
    private static let routeLineWidth: CGFloat = 3.0

    /// Route line color.
    private static let routeColor: UIColor = .systemRed

    /// Padding ratio around the route (0.15 = 15% padding on each side).
    private static let paddingRatio: Double = 0.15

    /// Maximum number of coordinate points to include in the route.
    /// Downsampling helps performance for long routes.
    private static let maxCoordinateCount: Int = 200

    // MARK: - Dependencies

    private weak var workoutService: WorkoutServiceProtocol?
    private weak var persistenceManager: PersistenceManaging?

    /// The image size to generate.
    private let imageSize: CGSize

    /// Scale factor for retina displays (2x for watch).
    private let scale: CGFloat

    // MARK: - Initialization

    /// Creates a RouteImageGenerator with the specified dependencies.
    ///
    /// - Parameters:
    ///   - workoutService: Service providing current workout state.
    ///   - persistenceManager: Manager for fetching track points.
    ///   - imageSize: Size of the generated image. Defaults to 44mm watch size.
    ///   - scale: Scale factor for retina displays. Defaults to 2x.
    public init(
        workoutService: WorkoutServiceProtocol?,
        persistenceManager: PersistenceManaging?,
        imageSize: CGSize = RouteImageGenerator.defaultImageSize,
        scale: CGFloat = 2.0
    ) {
        self.workoutService = workoutService
        self.persistenceManager = persistenceManager
        self.imageSize = imageSize
        self.scale = scale
    }

    // MARK: - RouteImageGenerating

    /// Generates a PNG image of the current workout route.
    ///
    /// This method:
    /// 1. Fetches track points from the active workout
    /// 2. Creates a map snapshot with the route overlaid
    /// 3. Returns PNG-compressed image data
    ///
    /// - Returns: PNG image data, or nil if:
    ///   - No active workout
    ///   - No track points with valid coordinates
    ///   - Snapshot generation fails
    public func generateRouteImage() async -> Data? {
        // Get active workout ID
        guard let workoutID = await workoutService?.activeWorkoutID else {
            return nil
        }

        // Fetch coordinates for the workout
        guard let coordinates = await fetchCoordinates(forWorkoutID: workoutID),
              coordinates.count >= 2 else {
            return nil
        }

        // Downsample if needed for performance
        let sampledCoordinates = downsampleCoordinates(coordinates)

        // Generate the map snapshot
        return await generateSnapshot(for: sampledCoordinates)
    }

    // MARK: - Coordinate Fetching

    /// Fetches coordinates from track points for the specified workout.
    ///
    /// - Parameter workoutID: The workout ID to fetch coordinates for.
    /// - Returns: Array of coordinates, or nil if fetching fails.
    private func fetchCoordinates(forWorkoutID workoutID: String) async -> [CLLocationCoordinate2D]? {
        guard let persistence = persistenceManager else { return nil }

        do {
            let trackPoints = try await persistence.fetchTrackPoints(forWorkoutID: workoutID)

            let coordinates = trackPoints.compactMap { trackPoint -> CLLocationCoordinate2D? in
                guard trackPoint.hasValidLocation,
                      let lat = trackPoint.latitude,
                      let lon = trackPoint.longitude else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }

            return coordinates.isEmpty ? nil : coordinates
        } catch {
            print("[RouteImageGenerator] Failed to fetch track points: \(error)")
            return nil
        }
    }

    /// Downsamples coordinates to limit the number of points for performance.
    ///
    /// This matches the legacy behavior of limiting to ~200 points.
    ///
    /// - Parameter coordinates: The original coordinate array.
    /// - Returns: Downsampled coordinates.
    private func downsampleCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count > Self.maxCoordinateCount else {
            return coordinates
        }

        let increment = Int(ceil(Double(coordinates.count) / Double(Self.maxCoordinateCount)))
        var sampled: [CLLocationCoordinate2D] = []

        for i in stride(from: 0, to: coordinates.count, by: increment) {
            sampled.append(coordinates[i])
        }

        // Always include the last point
        if let last = coordinates.last, sampled.last != last {
            sampled.append(last)
        }

        return sampled
    }

    // MARK: - Snapshot Generation

    /// Generates a map snapshot with the route overlaid.
    ///
    /// - Parameter coordinates: The route coordinates to draw.
    /// - Returns: PNG image data, or nil if generation fails.
    private func generateSnapshot(for coordinates: [CLLocationCoordinate2D]) async -> Data? {
        // Calculate the bounding region
        guard let region = calculateRegion(for: coordinates) else {
            return nil
        }

        // Validate region
        guard region.center.latitude >= -90 && region.center.latitude <= 90,
              region.center.longitude >= -180 && region.center.longitude <= 180 else {
            return nil
        }

        // Configure snapshot options
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = imageSize
        options.scale = scale
        options.mapType = .standard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        // Create and run the snapshotter
        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot, coordinates: coordinates)
            return image?.pngData()
        } catch {
            print("[RouteImageGenerator] Snapshot failed: \(error)")
            return nil
        }
    }

    /// Calculates the map region that encompasses all coordinates with padding.
    ///
    /// - Parameter coordinates: The coordinates to encompass.
    /// - Returns: A map region, or nil if coordinates are invalid.
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        // Calculate center
        let centerLat = (minLat + maxLat) / 2.0
        let centerLon = (minLon + maxLon) / 2.0

        // Calculate span with padding
        var latDelta = (maxLat - minLat) * (1.0 + Self.paddingRatio * 2)
        var lonDelta = (maxLon - minLon) * (1.0 + Self.paddingRatio * 2)

        // Ensure minimum span for single-point or very short routes
        latDelta = max(latDelta, 0.002)
        lonDelta = max(lonDelta, 0.002)

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Draws the route polyline on the snapshot image.
    ///
    /// - Parameters:
    ///   - snapshot: The map snapshot to draw on.
    ///   - coordinates: The route coordinates.
    /// - Returns: The final image with route overlay.
    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D]) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)

        return renderer.image { context in
            // Draw the map snapshot
            snapshot.image.draw(at: .zero)

            let cgContext = context.cgContext

            // Configure stroke
            cgContext.setStrokeColor(Self.routeColor.cgColor)
            cgContext.setLineWidth(Self.routeLineWidth)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            // Draw the route path
            cgContext.beginPath()

            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)

                if index == 0 {
                    cgContext.move(to: point)
                } else {
                    cgContext.addLine(to: point)
                }
            }

            cgContext.strokePath()

            // Draw start and end markers
            if let start = coordinates.first, let end = coordinates.last {
                drawMarker(at: snapshot.point(for: start), color: .systemGreen, in: cgContext)
                drawMarker(at: snapshot.point(for: end), color: .systemRed, in: cgContext)
            }
        }
    }

    /// Draws a circular marker at the specified point.
    ///
    /// - Parameters:
    ///   - point: The center point of the marker.
    ///   - color: The marker color.
    ///   - context: The graphics context to draw in.
    private func drawMarker(at point: CGPoint, color: UIColor, in context: CGContext) {
        let markerRadius: CGFloat = 4.0
        let borderWidth: CGFloat = 1.5

        // White border
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - markerRadius - borderWidth,
            y: point.y - markerRadius - borderWidth,
            width: (markerRadius + borderWidth) * 2,
            height: (markerRadius + borderWidth) * 2
        ))

        // Colored center
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - markerRadius,
            y: point.y - markerRadius,
            width: markerRadius * 2,
            height: markerRadius * 2
        ))
    }
}

// MARK: - RouteImageGeneratorFactory

/// Factory for creating RouteImageGenerator instances.
///
/// This factory simplifies creation and configuration of RouteImageGenerator,
/// particularly for different watch sizes.
public enum RouteImageGeneratorFactory {

    /// Watch size enumeration for image size selection.
    public enum WatchSize {
        case small      // 40mm/41mm
        case regular    // 44mm/45mm
        case ultra      // 49mm

        var imageSize: CGSize {
            switch self {
            case .small:
                return RouteImageGenerator.smallImageSize
            case .regular:
                return RouteImageGenerator.defaultImageSize
            case .ultra:
                return RouteImageGenerator.ultraImageSize
            }
        }
    }

    /// Creates a RouteImageGenerator configured for the specified watch size.
    ///
    /// - Parameters:
    ///   - workoutService: Service providing current workout state.
    ///   - persistenceManager: Manager for fetching track points.
    ///   - watchSize: The target watch size.
    /// - Returns: A configured RouteImageGenerator.
    public static func makeGenerator(
        workoutService: WorkoutServiceProtocol?,
        persistenceManager: PersistenceManaging?,
        watchSize: WatchSize = .regular
    ) -> RouteImageGenerator {
        RouteImageGenerator(
            workoutService: workoutService,
            persistenceManager: persistenceManager,
            imageSize: watchSize.imageSize
        )
    }
}

// MARK: - Previews Support

#if DEBUG
/// Preview implementation for testing route image generation.
public final class PreviewRouteImageGenerator: RouteImageGenerating, Sendable {

    private let mockCoordinates: [CLLocationCoordinate2D]

    public init(mockCoordinates: [CLLocationCoordinate2D] = []) {
        self.mockCoordinates = mockCoordinates
    }

    /// Generates a sample route image for previews.
    public func generateRouteImage() async -> Data? {
        guard !mockCoordinates.isEmpty else {
            // Return a placeholder image
            return createPlaceholderImage()
        }

        // Generate actual image with mock coordinates
        let generator = RouteImageGenerator(
            workoutService: nil,
            persistenceManager: nil
        )

        // Use reflection or a test helper to generate with provided coordinates
        return createPlaceholderImage()
    }

    private func createPlaceholderImage() -> Data? {
        let size = RouteImageGenerator.defaultImageSize

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { context in
            // Gray background
            UIColor.systemGray5.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            // Placeholder text
            let text = "Route Preview"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            let textSize = text.size(withAttributes: attributes)
            let textPoint = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: textPoint, withAttributes: attributes)
        }

        return image.pngData()
    }
}
#endif
