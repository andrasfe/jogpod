//
//  OAuthMigrationContainer.swift
//  JogPod
//
//  Container view that conditionally displays the OAuth migration flow.
//

import AuthenticationServices
import SwiftUI
import os.log

// MARK: - OAuth Migration Container

/// A container view that checks for and presents the OAuth migration flow if needed.
///
/// This view should be placed at the app's root level to intercept legacy users
/// who need to re-authenticate with Fitbit. It presents the migration flow as
/// a full-screen modal when legacy tokens are detected.
///
/// ## Integration
///
/// Place this container around your main app content:
///
/// ```swift
/// OAuthMigrationContainer(credentialsService: credentials) {
///     MainTabView()
/// }
/// ```
///
/// ## Behavior
///
/// 1. On appear, checks for legacy OAuth 1.0 tokens
/// 2. If legacy tokens exist (and no OAuth2 token), presents migration sheet
/// 3. User completes or skips migration
/// 4. Main content is displayed
///
/// The container will not block the app if migration fails - users can still
/// access the app, but Fitbit features will be unavailable until they complete
/// the migration from Settings.
public struct OAuthMigrationContainer<Content: View>: View {

    // MARK: - Properties

    private let credentialsService: CredentialsService
    private let content: Content

    @State private var shouldShowMigration = false
    @State private var hasCompletedCheck = false
    @State private var migrationResult: Bool?

    private let logger = Logger(subsystem: "com.jogpod", category: "OAuthMigrationContainer")

    // MARK: - Initialization

    /// Creates an OAuth migration container.
    /// - Parameters:
    ///   - credentialsService: The credentials service for token management.
    ///   - content: The main app content to display after migration check.
    public init(
        credentialsService: CredentialsService,
        @ViewBuilder content: () -> Content
    ) {
        self.credentialsService = credentialsService
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        content
            .task {
                await checkForMigration()
            }
            .fullScreenCover(isPresented: $shouldShowMigration) {
                OAuthMigrationView(
                    credentialsService: credentialsService
                ) { success in
                    migrationResult = success
                    shouldShowMigration = false

                    if success {
                        logger.info("OAuth migration completed successfully")
                    } else {
                        logger.info("OAuth migration skipped by user")
                    }
                }
            }
    }

    // MARK: - Private Methods

    private func checkForMigration() async {
        guard !hasCompletedCheck else { return }
        hasCompletedCheck = true

        // Check if legacy tokens exist
        let hasLegacyTokens = FitbitOAuthProvider.hasLegacyTokens()

        // Check if we already have OAuth2 tokens
        let hasOAuth2Token = credentialsService.hasCredential(for: .fitbitUserToken)

        logger.debug("Migration check - Legacy: \(hasLegacyTokens), OAuth2: \(hasOAuth2Token)")

        if hasLegacyTokens && !hasOAuth2Token {
            // Need to show migration flow
            // Small delay to allow the app UI to settle before presenting
            try? await Task.sleep(for: .milliseconds(500))
            shouldShowMigration = true
        } else if hasLegacyTokens && hasOAuth2Token {
            // Already migrated, clean up legacy tokens
            FitbitOAuthProvider.clearLegacyTokens()
            logger.info("Cleaned up legacy tokens after previous migration")
        }
    }
}

// MARK: - Environment Extension for Migration Status

/// Environment key for tracking OAuth migration completion status.
private struct OAuthMigrationCompletedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether OAuth migration has been completed successfully.
    public var oauthMigrationCompleted: Bool {
        get { self[OAuthMigrationCompletedKey.self] }
        set { self[OAuthMigrationCompletedKey.self] = newValue }
    }
}

// MARK: - View Modifier for Migration Alert

/// A view modifier that shows a migration reminder banner.
///
/// Use this on views that require Fitbit authentication to remind users
/// who skipped migration that they need to complete it.
public struct OAuthMigrationReminderModifier: ViewModifier {

    private let credentialsService: CredentialsService
    private let onTapConnect: () -> Void

    @State private var showReminder = false

    public init(
        credentialsService: CredentialsService,
        onTapConnect: @escaping () -> Void
    ) {
        self.credentialsService = credentialsService
        self.onTapConnect = onTapConnect
    }

    public func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if showReminder {
                    migrationReminderBanner
                }
            }
            .task {
                checkForPendingMigration()
            }
    }

    private var migrationReminderBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fitbit Disconnected")
                    .font(.subheadline.weight(.semibold))

                Text("Tap to reconnect your account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Connect") {
                onTapConnect()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fitbit disconnected. Tap to reconnect your account.")
        .accessibilityAddTraits(.isButton)
    }

    private func checkForPendingMigration() {
        // Show reminder if:
        // 1. Legacy tokens were cleared (indicating user had them before)
        // 2. No OAuth2 token exists (indicating migration wasn't completed)
        let hasOAuth2Token = credentialsService.hasCredential(for: .fitbitUserToken)

        // Check if user previously had Fitbit enabled but doesn't have tokens now
        // This would happen if they skipped migration
        if !hasOAuth2Token {
            // Check UserDefaults for a flag indicating previous Fitbit usage
            let previouslyUsedFitbit = UserDefaults.standard.bool(forKey: "com.jogpod.previously_used_fitbit")
            showReminder = previouslyUsedFitbit
        }
    }
}

extension View {
    /// Adds an OAuth migration reminder banner for users who skipped migration.
    /// - Parameters:
    ///   - credentialsService: The credentials service for checking token status.
    ///   - onTapConnect: Called when user taps the connect button.
    public func oauthMigrationReminder(
        credentialsService: CredentialsService,
        onTapConnect: @escaping () -> Void
    ) -> some View {
        modifier(OAuthMigrationReminderModifier(
            credentialsService: credentialsService,
            onTapConnect: onTapConnect
        ))
    }
}

// MARK: - Settings Integration Helper

/// Helper for integrating OAuth migration into the Settings flow.
///
/// Use this when the user wants to connect Fitbit from Settings after
/// skipping the initial migration.
@Observable
@MainActor
public final class OAuthSettingsHelper: NSObject {

    public private(set) var isAuthenticating = false
    public private(set) var authenticationError: String?
    public private(set) var isConnected = false
    public private(set) var connectedUserName: String?

    private let credentialsService: CredentialsService
    private var oauthProvider: FitbitOAuthProvider?
    private let logger = Logger(subsystem: "com.jogpod", category: "OAuthSettings")

    public init(credentialsService: CredentialsService) {
        self.credentialsService = credentialsService
        super.init()
    }

    /// Checks if Fitbit is currently connected.
    public func checkConnectionStatus() async {
        isConnected = credentialsService.hasCredential(for: .fitbitUserToken)

        if isConnected {
            do {
                oauthProvider = try FitbitOAuthProvider(credentials: credentialsService)
                if let profile = await oauthProvider?.currentUser {
                    connectedUserName = profile.displayName
                }
            } catch {
                // Provider creation failed, but we might still have tokens
                logger.warning("Failed to create OAuth provider: \(error.localizedDescription)")
            }
        }
    }

    /// Initiates Fitbit authentication from Settings.
    public func connect() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        authenticationError = nil

        do {
            oauthProvider = try FitbitOAuthProvider(credentials: credentialsService)

            let profile = try await oauthProvider?.authenticate(presentationContext: self)

            // Clean up any legacy tokens
            FitbitOAuthProvider.clearLegacyTokens()

            // Mark that user has connected Fitbit (for reminder logic)
            UserDefaults.standard.set(true, forKey: "com.jogpod.previously_used_fitbit")

            isConnected = true
            connectedUserName = profile?.displayName
            isAuthenticating = false

            logger.info("Successfully connected to Fitbit as: \(profile?.displayName ?? "unknown")")

        } catch let error as OAuthError {
            isAuthenticating = false

            switch error {
            case .userCancelled:
                // User cancelled, don't show error
                break
            default:
                authenticationError = error.localizedDescription
            }

            logger.error("Fitbit connection failed: \(error.localizedDescription)")

        } catch {
            isAuthenticating = false
            authenticationError = "An unexpected error occurred."
            logger.error("Unexpected error connecting to Fitbit: \(error.localizedDescription)")
        }
    }

    /// Disconnects from Fitbit.
    public func disconnect() async {
        do {
            oauthProvider = try FitbitOAuthProvider(credentials: credentialsService)
            try await oauthProvider?.signOut()

            isConnected = false
            connectedUserName = nil

            logger.info("Disconnected from Fitbit")

        } catch {
            logger.error("Error disconnecting from Fitbit: \(error.localizedDescription)")
            // Still clear local state
            isConnected = false
            connectedUserName = nil
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthSettingsHelper: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Preview

#Preview {
    OAuthMigrationContainer(credentialsService: CredentialsService()) {
        NavigationStack {
            Text("Main App Content")
                .navigationTitle("JogPod")
        }
    }
}
