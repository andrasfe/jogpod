import SwiftUI
import SwiftData
import os.log

/// Main entry point for the JogPod application.
///
/// This app uses SwiftData for persistence and provides a podcast-enhanced
/// workout tracking experience.
///
/// ## Architecture
///
/// The app uses a dependency injection pattern where `AppDependencies` is
/// created at launch and passed through the environment to all views.
/// This enables easy testing and clean separation of concerns.
///
/// ## Navigation Structure
///
/// ```
/// JogPodApp
/// +-- WindowGroup
///     +-- MainTabView
///         +-- Dashboard (NavigationStack)
///         +-- Playlist (NavigationStack)
///         +-- Stats (NavigationStack)
///         +-- Settings (NavigationStack)
/// ```
///
/// ## Services Lifecycle
///
/// Services are initialized in two phases:
/// 1. **Synchronous init**: Credentials service and OAuth migration
/// 2. **Async initialization**: Heavy services via `AppDependencies.initializeServices()`
@main
struct JogPodApp: App {

    /// Logger for app lifecycle events.
    private static let logger = Logger(subsystem: "com.jogpod", category: "AppLifecycle")

    /// The app dependencies container.
    ///
    /// This is the composition root for all services in the application.
    /// It is created once at launch and passed through the environment.
    @State private var dependencies = AppDependencies()

    /// The credentials service for secure credential management.
    private let credentialsService: CredentialsService

    /// The OAuth token migration service.
    private let oauthMigration: OAuthTokenMigration

    init() {
        // Initialize credentials service
        let credentials = CredentialsService()
        self.credentialsService = credentials

        // Initialize OAuth token migration
        self.oauthMigration = OAuthTokenMigration(credentialsService: credentials)

        // Perform launch-time setup
        Self.performLaunchSetup(
            credentialsService: credentials,
            oauthMigration: oauthMigration
        )
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .appDependencies(dependencies)
        }
        .modelContainer(dependencies.modelContainer)
    }

    // MARK: - Launch Setup

    /// Performs one-time setup tasks during app launch.
    ///
    /// This method handles:
    /// 1. OAuth token migration from legacy UserDefaults to secure Keychain storage
    /// 2. Credentials bootstrap from environment variables (for development/CI)
    ///
    /// - Parameters:
    ///   - credentialsService: The credentials service for secure storage.
    ///   - oauthMigration: The OAuth token migration service.
    private static func performLaunchSetup(
        credentialsService: CredentialsService,
        oauthMigration: OAuthTokenMigration
    ) {
        // Step 1: Migrate legacy OAuth tokens from UserDefaults to Keychain
        // This must happen before any Fitbit API calls
        if let migrationStatus = oauthMigration.migrateOnLaunch() {
            logger.info("OAuth token migration: \(migrationStatus.description)")
        } else {
            logger.warning("OAuth token migration failed - user may need to re-authenticate")
        }

        // Step 2: Bootstrap credentials from environment (development/CI only)
        let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)
        do {
            try bootstrap.loadFromEnvironment()
            if bootstrap.isConfigured() {
                logger.debug("App credentials loaded from environment")
            }
        } catch {
            // This is expected in production where credentials come from Keychain
            logger.debug("No environment credentials found (expected in production)")
        }

        // Step 3: Log credential configuration status for debugging
        #if DEBUG
        let missingCredentials = bootstrap.missingCredentials()
        if !missingCredentials.isEmpty {
            let missing = missingCredentials.map(\.description).joined(separator: ", ")
            logger.warning("Missing credentials: \(missing)")
        }
        #endif
    }
}
