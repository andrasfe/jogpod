//
//  OAuthMigrationView.swift
//  JogPod
//
//  OAuth migration view for legacy users who need to re-authenticate.
//

import AuthenticationServices
import SwiftUI
import os.log

// MARK: - OAuth Migration State

/// Represents the current state of the OAuth migration flow.
public enum OAuthMigrationState: Equatable, Sendable {
    /// Initial state - checking for legacy tokens.
    case checking

    /// Legacy tokens detected, user needs to re-authenticate.
    case needsMigration

    /// User initiated migration, OAuth flow in progress.
    case authenticating

    /// Migration completed successfully.
    case success(displayName: String?)

    /// Migration failed with an error.
    case failed(message: String)

    /// User cancelled the migration flow.
    case cancelled

    /// No migration needed - user either has no tokens or already has OAuth2 tokens.
    case notRequired
}

// MARK: - OAuth Migration View Model

/// View model for managing the OAuth migration flow.
///
/// This view model coordinates:
/// - Detection of legacy OAuth 1.0 tokens
/// - Presentation of the OAuth 2.0 authentication flow
/// - Cleanup of legacy tokens after successful migration
/// - Error handling and retry logic
@Observable
@MainActor
public final class OAuthMigrationViewModel: NSObject {

    // MARK: - Properties

    /// The current migration state.
    public private(set) var state: OAuthMigrationState = .checking

    /// Progress message for the current operation.
    public private(set) var progressMessage: String = ""

    private let credentialsService: CredentialsService
    private let userDefaults: UserDefaults
    private var oauthProvider: FitbitOAuthProvider?
    private let logger = Logger(subsystem: "com.jogpod", category: "OAuthMigration")

    // MARK: - Initialization

    /// Creates a new OAuth migration view model.
    /// - Parameters:
    ///   - credentialsService: The credentials service for token storage.
    ///   - userDefaults: The UserDefaults to check for legacy tokens.
    public init(
        credentialsService: CredentialsService,
        userDefaults: UserDefaults = .standard
    ) {
        self.credentialsService = credentialsService
        self.userDefaults = userDefaults
        super.init()
    }

    // MARK: - Public Methods

    /// Checks if OAuth migration is required.
    ///
    /// This should be called when the view appears to determine the initial state.
    public func checkMigrationRequired() async {
        state = .checking
        progressMessage = "Checking authentication status..."

        // Check if legacy tokens exist
        let hasLegacyTokens = FitbitOAuthProvider.hasLegacyTokens(in: userDefaults)

        // Check if OAuth2 tokens already exist
        let hasOAuth2Token = credentialsService.hasCredential(for: .fitbitUserToken)

        logger.info("Migration check - Legacy tokens: \(hasLegacyTokens), OAuth2 token: \(hasOAuth2Token)")

        if hasLegacyTokens && !hasOAuth2Token {
            // Legacy tokens found, migration needed
            state = .needsMigration
            progressMessage = ""
        } else if hasOAuth2Token {
            // Already have OAuth2 tokens, clear any legacy tokens and skip migration
            FitbitOAuthProvider.clearLegacyTokens(from: userDefaults)
            state = .notRequired
            progressMessage = ""
        } else {
            // No tokens at all - this is a fresh install or user never authenticated
            state = .notRequired
            progressMessage = ""
        }
    }

    /// Initiates the OAuth 2.0 authentication flow.
    ///
    /// This presents an ASWebAuthenticationSession for the user to sign in with Fitbit.
    public func startAuthentication() async {
        state = .authenticating
        progressMessage = "Connecting to Fitbit..."

        do {
            // Create the OAuth provider
            oauthProvider = try FitbitOAuthProvider(credentials: credentialsService)

            // Present the authentication session
            progressMessage = "Please sign in to your Fitbit account..."

            let profile = try await oauthProvider?.authenticate(
                presentationContext: self
            )

            // Authentication successful - clear legacy tokens
            FitbitOAuthProvider.clearLegacyTokens(from: userDefaults)

            logger.info("OAuth migration completed successfully for user: \(profile?.displayName ?? "unknown")")

            state = .success(displayName: profile?.displayName)
            progressMessage = ""

        } catch let error as OAuthError {
            handleOAuthError(error)
        } catch {
            logger.error("OAuth migration failed with unexpected error: \(error.localizedDescription)")
            state = .failed(message: "An unexpected error occurred. Please try again.")
            progressMessage = ""
        }
    }

    /// Skips the migration for now.
    ///
    /// The user can still use the app, but Fitbit features will be disabled
    /// until they complete the migration.
    public func skipMigration() {
        logger.info("User skipped OAuth migration")
        state = .cancelled
        progressMessage = ""

        // Clear legacy tokens since they can't be used anyway
        FitbitOAuthProvider.clearLegacyTokens(from: userDefaults)
    }

    /// Retries the migration after a failure.
    public func retryMigration() async {
        await startAuthentication()
    }

    // MARK: - Private Methods

    private func handleOAuthError(_ error: OAuthError) {
        logger.error("OAuth error during migration: \(error.localizedDescription)")

        switch error {
        case .userCancelled:
            state = .needsMigration
            progressMessage = ""

        case .notConfigured:
            state = .failed(message: "Fitbit integration is not configured. Please contact support.")
            progressMessage = ""

        case .networkError:
            state = .failed(message: "Network error. Please check your internet connection and try again.")
            progressMessage = ""

        case .tokenExpired, .tokenNotFound, .tokenRefreshFailed:
            // These shouldn't occur during initial authentication, but handle them
            state = .failed(message: "Authentication failed. Please try again.")
            progressMessage = ""

        case .serverError(let statusCode, _):
            if statusCode == 429 {
                state = .failed(message: "Too many requests. Please wait a moment and try again.")
            } else {
                state = .failed(message: "Fitbit server error. Please try again later.")
            }
            progressMessage = ""

        case .rateLimitExceeded(let retryAfter):
            let waitTime = retryAfter.map { Int($0) } ?? 60
            state = .failed(message: "Rate limit exceeded. Please wait \(waitTime) seconds and try again.")
            progressMessage = ""

        default:
            state = .failed(message: error.localizedDescription)
            progressMessage = ""
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthMigrationViewModel: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - OAuth Migration View

/// A view that guides legacy users through the OAuth 2.0 re-authentication process.
///
/// This view is displayed when the app detects that a user has legacy OAuth 1.0 tokens
/// from the original JogPod app. Since Fitbit deprecated OAuth 1.0a, users must
/// re-authenticate using OAuth 2.0 to continue using Fitbit features.
///
/// ## User Experience
///
/// 1. The view explains why re-authentication is needed
/// 2. User taps "Connect to Fitbit" to start the OAuth flow
/// 3. ASWebAuthenticationSession presents the Fitbit login
/// 4. On success, legacy tokens are cleared and user continues
/// 5. On failure, user can retry or skip for now
///
/// ## Accessibility
///
/// - All interactive elements have accessibility labels and hints
/// - VoiceOver announces state changes
/// - Supports Dynamic Type for all text
public struct OAuthMigrationView: View {

    // MARK: - Properties

    @State private var viewModel: OAuthMigrationViewModel

    /// Callback when migration is complete (success or skipped).
    private let onComplete: (Bool) -> Void

    // MARK: - Initialization

    /// Creates an OAuth migration view.
    /// - Parameters:
    ///   - credentialsService: The credentials service for token storage.
    ///   - onComplete: Called when migration finishes. Parameter is true if successful.
    public init(
        credentialsService: CredentialsService,
        onComplete: @escaping (Bool) -> Void
    ) {
        self._viewModel = State(initialValue: OAuthMigrationViewModel(
            credentialsService: credentialsService
        ))
        self.onComplete = onComplete
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Account Update")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if case .needsMigration = viewModel.state {
                            Button("Skip") {
                                viewModel.skipMigration()
                                onComplete(false)
                            }
                            .accessibilityLabel("Skip Fitbit connection")
                            .accessibilityHint("You can connect later from Settings")
                        }
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.state == .authenticating)
        .task {
            await viewModel.checkMigrationRequired()

            // If no migration needed, dismiss immediately
            if case .notRequired = viewModel.state {
                onComplete(true)
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .checking:
            checkingView

        case .needsMigration:
            migrationNeededView

        case .authenticating:
            authenticatingView

        case .success(let displayName):
            successView(displayName: displayName)

        case .failed(let message):
            failedView(message: message)

        case .cancelled:
            // This state is handled by onComplete callback
            EmptyView()

        case .notRequired:
            // This state is handled by onComplete callback
            EmptyView()
        }
    }

    private var checkingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Checking account status...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checking account status")
    }

    private var migrationNeededView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)
                    .accessibilityHidden(true)

                // Title
                Text("Reconnect Your Fitbit Account")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                // Explanation
                VStack(alignment: .leading, spacing: 16) {
                    explanationRow(
                        icon: "lock.shield",
                        title: "Security Update",
                        description: "Fitbit has upgraded their authentication system for better security."
                    )

                    explanationRow(
                        icon: "person.badge.key",
                        title: "One-Time Setup",
                        description: "You'll only need to sign in once to continue using Fitbit features."
                    )

                    explanationRow(
                        icon: "checkmark.seal",
                        title: "Same Account",
                        description: "Sign in with your existing Fitbit account to keep all your data."
                    )
                }
                .padding(.horizontal)

                Spacer(minLength: 40)

                // Connect button
                Button {
                    Task {
                        await viewModel.startAuthentication()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                        Text("Connect to Fitbit")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityLabel("Connect to Fitbit")
                .accessibilityHint("Opens Fitbit sign-in page")

                // Skip option
                Text("You can skip this and connect later from Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
    }

    private func explanationRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var authenticatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text(viewModel.progressMessage.isEmpty ? "Authenticating..." : viewModel.progressMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("A browser window will open for you to sign in to Fitbit.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to Fitbit")
        .accessibilityValue(viewModel.progressMessage)
    }

    private func successView(displayName: String?) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Connected Successfully")
                .font(.title2.weight(.semibold))

            if let name = displayName {
                Text("Welcome back, \(name)!")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("Your Fitbit account is now connected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer(minLength: 40)

            Button {
                onComplete(true)
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            .accessibilityLabel("Continue to app")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Provide haptic feedback for success
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Connection Failed")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer(minLength: 40)

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.retryMigration()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Try connecting again")

                Button {
                    viewModel.skipMigration()
                    onComplete(false)
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Skip Fitbit connection")
                .accessibilityHint("You can connect later from Settings")
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Provide haptic feedback for failure
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

#Preview("Needs Migration") {
    OAuthMigrationView(
        credentialsService: CredentialsService()
    ) { success in
        print("Migration completed: \(success)")
    }
}

#Preview("Success State") {
    // This preview would need a mock setup to show success state
    OAuthMigrationView(
        credentialsService: CredentialsService()
    ) { success in
        print("Migration completed: \(success)")
    }
}
