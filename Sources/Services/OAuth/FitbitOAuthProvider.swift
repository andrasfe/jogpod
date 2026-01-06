import AuthenticationServices
import Foundation

// MARK: - Fitbit OAuth Constants

/// Constants for Fitbit OAuth API endpoints and configuration.
public enum FitbitOAuthConstants {
    /// Fitbit API base URL.
    public static let apiBaseURL = URL(string: "https://api.fitbit.com")!

    /// Fitbit OAuth2 authorization endpoint.
    public static let authorizationURL = URL(string: "https://www.fitbit.com/oauth2/authorize")!

    /// Fitbit OAuth2 token endpoint.
    public static let tokenURL = URL(string: "https://api.fitbit.com/oauth2/token")!

    /// Fitbit OAuth2 token revocation endpoint.
    public static let revokeURL = URL(string: "https://api.fitbit.com/oauth2/revoke")!

    /// Fitbit OAuth2 token introspection endpoint.
    public static let introspectURL = URL(string: "https://api.fitbit.com/1.1/oauth2/introspect")!

    /// Default scopes for JogPod (activity data for running workouts).
    public static let defaultScopes: [FitbitScope] = [
        .activity,
        .profile,
        .heartrate,
        .location
    ]

    /// Token expiration buffer (refresh 5 minutes before actual expiration).
    public static let tokenExpirationBuffer: TimeInterval = 300
}

// MARK: - Fitbit Scopes

/// OAuth scopes supported by Fitbit API.
public enum FitbitScope: String, CaseIterable, Sendable {
    case activity
    case cardioFitness = "cardio_fitness"
    case electrocardiogram
    case heartrate
    case irregularRhythmNotifications = "irregular_rhythm_notifications"
    case location
    case nutrition
    case oxygenSaturation = "oxygen_saturation"
    case profile
    case respiratoryRate = "respiratory_rate"
    case settings
    case sleep
    case socialInteractions = "social"
    case temperature
    case weight

    /// Human-readable description of the scope.
    public var description: String {
        switch self {
        case .activity: return "Activity & exercise data"
        case .cardioFitness: return "Cardio fitness level"
        case .electrocardiogram: return "ECG data"
        case .heartrate: return "Heart rate data"
        case .irregularRhythmNotifications: return "Irregular heart rhythm notifications"
        case .location: return "GPS and location data"
        case .nutrition: return "Food and water logs"
        case .oxygenSaturation: return "Blood oxygen saturation"
        case .profile: return "User profile"
        case .respiratoryRate: return "Breathing rate"
        case .settings: return "Account settings"
        case .sleep: return "Sleep data"
        case .socialInteractions: return "Friends and social features"
        case .temperature: return "Skin temperature"
        case .weight: return "Weight and body fat"
        }
    }
}

// MARK: - Fitbit User Profile

/// Represents a Fitbit user profile.
public struct FitbitUserProfile: Codable, Sendable, Equatable {
    public let userId: String
    public let displayName: String
    public let fullName: String?
    public let avatar: URL?
    public let avatar150: URL?
    public let memberSince: String?
    public let timezone: String?
    public let strideLengthRunning: Double?
    public let strideLengthWalking: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "encodedId"
        case displayName
        case fullName
        case avatar
        case avatar150
        case memberSince
        case timezone
        case strideLengthRunning
        case strideLengthWalking
    }
}

// MARK: - Fitbit OAuth Provider Protocol

/// Protocol for Fitbit-specific OAuth operations.
@MainActor
public protocol FitbitOAuthProviding: Sendable {
    /// Initiates Fitbit authentication.
    /// - Parameter presentationContext: The window to present from.
    /// - Returns: The authenticated user's profile.
    func authenticate(presentationContext: ASWebAuthenticationPresentationContextProviding) async throws -> FitbitUserProfile

    /// Signs out the current user.
    func signOut() async throws

    /// Returns the current user's profile, if authenticated.
    var currentUser: FitbitUserProfile? { get async }

    /// Whether the user is authenticated with Fitbit.
    var isAuthenticated: Bool { get async }

    /// Gets a valid access token for API requests.
    func getAccessToken() async throws -> String
}

// MARK: - Fitbit OAuth Provider Implementation

/// Fitbit-specific OAuth provider implementation.
///
/// This class provides a high-level interface for Fitbit authentication,
/// handling OAuth2 flows, token management, and user profile retrieval.
///
/// ## Features
///
/// - OAuth 2.0 with PKCE for secure authentication
/// - Automatic token refresh
/// - User profile caching
/// - Secure token storage via CredentialsService
///
/// ## Migration from Legacy OAuth1
///
/// Fitbit migrated to OAuth 2.0 in 2016. This implementation uses OAuth 2.0
/// exclusively, as OAuth 1.0a support was deprecated.
///
/// If migrating users with OAuth 1.0 tokens, they will need to re-authenticate.
/// The legacy tokens stored in UserDefaults can be cleared during migration.
///
/// ## Usage
///
/// ```swift
/// let provider = try FitbitOAuthProvider(credentials: credentialsService)
///
/// // Authenticate user
/// let profile = try await provider.authenticate(presentationContext: self)
/// print("Welcome, \(profile.displayName)!")
///
/// // Get access token for API requests
/// let token = try await provider.getAccessToken()
/// ```
@MainActor
public final class FitbitOAuthProvider: FitbitOAuthProviding {

    // MARK: - Properties

    private let oauthService: OAuthService
    private let credentials: CredentialsProviding
    private let urlSession: URLSession
    private let scopes: [FitbitScope]

    /// Cached user profile.
    private var cachedProfile: FitbitUserProfile?

    // MARK: - Initialization

    /// Creates a new Fitbit OAuth provider.
    /// - Parameters:
    ///   - credentials: The credentials service for token storage.
    ///   - scopes: The OAuth scopes to request.
    ///   - urlSession: The URL session for network requests.
    ///   - refreshConfiguration: Configuration for token refresh retry behavior.
    /// - Throws: OAuthError if credentials are not configured.
    public init(
        credentials: CredentialsProviding,
        scopes: [FitbitScope] = FitbitOAuthConstants.defaultScopes,
        urlSession: URLSession = .shared,
        refreshConfiguration: TokenRefreshConfiguration = .default
    ) throws {
        self.credentials = credentials
        self.scopes = scopes
        self.urlSession = urlSession

        // Load app credentials
        let clientId: String
        let clientSecret: String
        let callbackURLString: String

        do {
            clientId = try credentials.credential(for: .fitbitConsumerKey)
            clientSecret = try credentials.credential(for: .fitbitConsumerSecret)
            callbackURLString = try credentials.credential(for: .fitbitOAuthCallback)
        } catch {
            throw OAuthError.notConfigured(reason: "Fitbit credentials not found. Configure via CredentialsBootstrap.")
        }

        guard let callbackURL = URL(string: callbackURLString) else {
            throw OAuthError.invalidCallbackURL(callbackURLString)
        }

        // Extract URL scheme from callback URL
        guard let scheme = callbackURL.scheme else {
            throw OAuthError.invalidCallbackURL("Callback URL must have a scheme")
        }

        let configuration = OAuthConfiguration(
            clientId: clientId,
            clientSecret: clientSecret,
            callbackURLScheme: scheme,
            callbackURL: callbackURL,
            authorizationURL: FitbitOAuthConstants.authorizationURL,
            tokenURL: FitbitOAuthConstants.tokenURL,
            scopes: scopes.map { $0.rawValue },
            usePKCE: true,
            oauthVersion: .oauth2
        )

        self.oauthService = OAuthService(
            configuration: configuration,
            credentials: credentials,
            urlSession: urlSession,
            refreshConfiguration: refreshConfiguration
        )
    }

    // MARK: - FitbitOAuthProviding

    public var currentUser: FitbitUserProfile? {
        get async {
            if let cached = cachedProfile {
                return cached
            }

            // Try to fetch profile if authenticated
            guard await isAuthenticated else { return nil }

            do {
                cachedProfile = try await fetchUserProfile()
                return cachedProfile
            } catch {
                return nil
            }
        }
    }

    public var isAuthenticated: Bool {
        get async {
            await oauthService.isAuthenticated
        }
    }

    public func authenticate(
        presentationContext: ASWebAuthenticationPresentationContextProviding
    ) async throws -> FitbitUserProfile {
        // Perform OAuth flow
        _ = try await oauthService.authorize(presentationContext: presentationContext)

        // Fetch and cache user profile
        let profile = try await fetchUserProfile()
        cachedProfile = profile

        return profile
    }

    public func signOut() async throws {
        // Revoke token with Fitbit
        do {
            try await revokeTokenWithFitbit()
        } catch {
            // Continue with local cleanup even if revocation fails
            // The token will eventually expire on Fitbit's side
        }

        // Clear local tokens
        try await oauthService.revokeToken()

        // Clear cached profile
        cachedProfile = nil
    }

    public func getAccessToken() async throws -> String {
        try await oauthService.getValidAccessToken()
    }

    // MARK: - API Methods

    /// Fetches the user's profile from Fitbit API.
    public func fetchUserProfile() async throws -> FitbitUserProfile {
        let token = try await getAccessToken()

        var request = URLRequest(url: URL(string: "https://api.fitbit.com/1/user/-/profile.json")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError(underlying: "Invalid response type")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw OAuthError.rateLimitExceeded(retryAfter: retryAfter)
        }

        // Handle unauthorized (token expired or revoked)
        if httpResponse.statusCode == 401 {
            throw OAuthError.tokenExpired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        do {
            let wrapper = try JSONDecoder().decode(ProfileWrapper.self, from: data)
            return wrapper.user
        } catch {
            throw OAuthError.decodingError(underlying: error.localizedDescription)
        }
    }

    /// Refreshes the current token if needed.
    public func refreshTokenIfNeeded() async throws {
        guard let token = await oauthService.currentToken else {
            throw OAuthError.tokenNotFound
        }

        guard token.isExpired, let refreshToken = token.refreshToken else {
            return // Token is still valid or no refresh token available
        }

        let newToken = try await oauthService.refreshToken(refreshToken)
        try await oauthService.storeToken(newToken)
    }

    // MARK: - Private Methods

    private func revokeTokenWithFitbit() async throws {
        guard let token = await oauthService.currentToken else {
            return // Nothing to revoke
        }

        var request = URLRequest(url: FitbitOAuthConstants.revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "token", value: token.accessToken)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        // Add Basic auth
        let clientId = try credentials.credential(for: .fitbitConsumerKey)
        let clientSecret = try credentials.credential(for: .fitbitConsumerSecret)
        let authString = "\(clientId):\(clientSecret)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            // Revocation failed, but we'll still clear local tokens
            return
        }
    }
}

// MARK: - API Response Wrappers

private struct ProfileWrapper: Decodable {
    let user: FitbitUserProfile
}

// MARK: - Fitbit API Client Extension

extension FitbitOAuthProvider {
    /// Makes an authenticated request to the Fitbit API.
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "/1/user/-/activities.json").
    ///   - method: The HTTP method.
    ///   - body: Optional request body.
    /// - Returns: The response data.
    public func request(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let token = try await getAccessToken()

        var url = FitbitOAuthConstants.apiBaseURL
        url.appendPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError(underlying: "Invalid response type")
        }

        // Handle common error cases
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw OAuthError.tokenExpired
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw OAuthError.rateLimitExceeded(retryAfter: retryAfter)
        default:
            throw OAuthError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
    }
}

// MARK: - Legacy Migration Support

extension FitbitOAuthProvider {
    /// Checks if the user has legacy OAuth 1.0 tokens that need migration.
    /// - Parameter userDefaults: The UserDefaults to check.
    /// - Returns: True if legacy tokens exist.
    public static func hasLegacyTokens(in userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.string(forKey: "fitbitAuthCode") != nil ||
        userDefaults.string(forKey: "fitbitSecret") != nil
    }

    /// Clears legacy OAuth 1.0 tokens after migration.
    /// - Parameter userDefaults: The UserDefaults to clear.
    public static func clearLegacyTokens(from userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: "fitbitAuthCode")
        userDefaults.removeObject(forKey: "fitbitSecret")
        userDefaults.removeObject(forKey: "fitbitUserId")
    }
}

// MARK: - Token Validation

extension FitbitOAuthProvider {
    /// Validates the current token with Fitbit's introspection endpoint.
    /// - Returns: True if the token is valid.
    public func validateToken() async throws -> Bool {
        guard let token = await oauthService.currentToken else {
            return false
        }

        var request = URLRequest(url: FitbitOAuthConstants.introspectURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "token", value: token.accessToken)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        // Add Basic auth
        let clientId = try credentials.credential(for: .fitbitConsumerKey)
        let clientSecret = try credentials.credential(for: .fitbitConsumerSecret)
        let authString = "\(clientId):\(clientSecret)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return false
        }

        struct IntrospectionResponse: Decodable {
            let active: Bool
        }

        do {
            let result = try JSONDecoder().decode(IntrospectionResponse.self, from: data)
            return result.active
        } catch {
            return false
        }
    }
}
