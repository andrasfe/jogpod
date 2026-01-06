//
//  AppDependencies.swift
//  JogPod
//
//  Dependency injection container for the JogPod application.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - AppDependencies

/// Central dependency container for the JogPod application.
///
/// This container manages the lifecycle and dependencies of all services
/// used throughout the application. It follows the composition root pattern,
/// where all dependencies are created at the app's entry point and passed
/// down through the view hierarchy.
///
/// ## Design Decisions
///
/// - **@Observable pattern**: Uses Swift's Observation framework for reactive
///   state management in SwiftUI views.
///
/// - **Protocol-based services**: Services conform to protocols enabling
///   easy testing with mock implementations.
///
/// - **Lazy initialization**: Heavy services are initialized on first access
///   to improve app launch time.
///
/// - **Composition over inheritance**: Services are composed rather than
///   inheriting from base classes.
///
/// ## Usage
///
/// The container is created at app launch and passed through the environment:
///
/// ```swift
/// @main
/// struct JogPodApp: App {
///     @State private var dependencies = AppDependencies()
///
///     var body: some Scene {
///         WindowGroup {
///             MainTabView()
///                 .environment(dependencies)
///         }
///     }
/// }
/// ```
///
/// Views access dependencies through the environment:
///
/// ```swift
/// struct DashboardView: View {
///     @Environment(AppDependencies.self) private var dependencies
///
///     var body: some View {
///         // Use dependencies.workoutService, etc.
///     }
/// }
/// ```
@Observable
@MainActor
public final class AppDependencies {

    // MARK: - Model Container

    /// The shared SwiftData model container.
    public let modelContainer: ModelContainer

    // MARK: - Core Services

    /// The persistence manager for database operations.
    ///
    /// This is lazily initialized on first access.
    public private(set) lazy var persistenceManager: PersistenceManager = {
        PersistenceManager(modelContainer: modelContainer)
    }()

    // MARK: - Feature Services

    /// The workout tracking service.
    ///
    /// Provides workout start/stop, location tracking, and metrics computation.
    /// Lazily initialized on first access.
    public private(set) var workoutService: WorkoutService?

    /// The audio player service for podcast playback.
    ///
    /// Manages playlist, playback controls, and background audio.
    /// Lazily initialized on first access.
    public private(set) var audioPlayerService: AudioPlayerService?

    // MARK: - Observers

    /// Observable wrapper for workout state updates.
    ///
    /// Publishes changes to workout status, metrics, and location for UI binding.
    public private(set) lazy var workoutObserver: WorkoutServiceObserver = {
        WorkoutServiceObserver()
    }()

    // MARK: - State

    /// Indicates whether services have been fully initialized.
    public private(set) var isInitialized: Bool = false

    /// Any error that occurred during initialization.
    public private(set) var initializationError: Error?

    // MARK: - Initialization

    /// Creates an AppDependencies container with a production model container.
    ///
    /// - Throws: Errors if the model container cannot be created.
    public init() {
        do {
            self.modelContainer = try JogPodSchema.makeContainer()
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    /// Creates an AppDependencies container with a custom model container.
    ///
    /// Use this initializer for testing with in-memory containers.
    ///
    /// - Parameter modelContainer: The model container to use.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Service Initialization

    /// Initializes all services asynchronously.
    ///
    /// This method should be called early in the app lifecycle, typically
    /// in an `.task` modifier on the root view. Services that require
    /// async setup are initialized here.
    ///
    /// ## Example
    ///
    /// ```swift
    /// MainTabView()
    ///     .task {
    ///         await dependencies.initializeServices()
    ///     }
    /// ```
    public func initializeServices() async {
        guard !isInitialized else { return }

        do {
            // Initialize workout service
            let locationService = LocationService()
            workoutService = WorkoutService(
                locationService: locationService,
                persistence: persistenceManager
            )

            // Initialize audio player service
            let nowPlayingManager = NowPlayingManager()
            audioPlayerService = AudioPlayerService(
                persistenceManager: persistenceManager,
                nowPlayingManager: nowPlayingManager
            )

            // Load playlist
            try await audioPlayerService?.loadPlaylist()

            isInitialized = true

        } catch {
            initializationError = error
            // Log the error but don't crash - allow partial functionality
            print("[AppDependencies] Service initialization failed: \(error)")
        }
    }

    // MARK: - Testing Support

    /// Creates an AppDependencies container for testing.
    ///
    /// This uses an in-memory model container and can inject mock services.
    ///
    /// - Returns: A configured AppDependencies for testing.
    public static func makeForTesting() throws -> AppDependencies {
        let container = try JogPodSchema.makeTestContainer()
        let dependencies = AppDependencies(modelContainer: container)
        return dependencies
    }

    /// Creates an AppDependencies container for SwiftUI previews.
    ///
    /// - Returns: A configured AppDependencies with sample data.
    @MainActor
    public static func makeForPreview() -> AppDependencies {
        do {
            let container = try JogPodSchema.makeTestContainer()
            let dependencies = AppDependencies(modelContainer: container)
            dependencies.isInitialized = true
            return dependencies
        } catch {
            fatalError("Failed to create preview dependencies: \(error)")
        }
    }
}

// MARK: - Environment Key

/// Environment key for accessing AppDependencies.
private struct AppDependenciesKey: EnvironmentKey {
    @MainActor
    static let defaultValue: AppDependencies = AppDependencies.makeForPreview()
}

extension EnvironmentValues {
    /// Access to the app's dependency container.
    public var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the AppDependencies container into the view hierarchy.
    ///
    /// - Parameter dependencies: The dependencies container to inject.
    /// - Returns: A view with the dependencies available in its environment.
    public func appDependencies(_ dependencies: AppDependencies) -> some View {
        self
            .environment(dependencies)
            .environment(\.appDependencies, dependencies)
    }
}
