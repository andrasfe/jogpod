import Foundation

// MARK: - OAuth Error Types

/// Comprehensive error types for OAuth authentication operations.
///
/// This enum covers all error scenarios that can occur during the OAuth flow,
/// from configuration issues to network failures and token management problems.
public enum OAuthError: Error, LocalizedError, Equatable, Sendable {

    // MARK: - Configuration Errors

    /// OAuth provider credentials are not configured.
    case notConfigured(reason: String)

    /// The callback URL is invalid or malformed.
    case invalidCallbackURL(String)

    /// The authorization URL could not be constructed.
    case invalidAuthorizationURL(String)

    // MARK: - Authentication Flow Errors

    /// User cancelled the authentication flow.
    case userCancelled

    /// Authentication session failed to start.
    case sessionStartFailed(underlying: String)

    /// The authentication session timed out.
    case timeout

    /// The authorization callback did not contain expected data.
    case invalidCallback(reason: String)

    /// The authorization code or verifier is missing from callback.
    case missingAuthorizationCode

    /// PKCE code verifier validation failed.
    case pkceVerificationFailed

    // MARK: - Token Errors

    /// Token exchange request failed.
    case tokenExchangeFailed(underlying: String)

    /// Token refresh request failed.
    case tokenRefreshFailed(underlying: String)

    /// Token refresh exhausted all retries.
    case tokenRefreshExhausted(attempts: Int, lastError: String)

    /// Refresh token has expired or been revoked; user must re-authenticate.
    case refreshTokenExpired

    /// Access token has expired and refresh is not available.
    case tokenExpired

    /// Token response was malformed or missing expected fields.
    case invalidTokenResponse(reason: String)

    /// Token storage operation failed.
    case tokenStorageFailed(underlying: String)

    /// Token retrieval failed; user needs to re-authenticate.
    case tokenNotFound

    // MARK: - Network Errors

    /// Network request failed.
    case networkError(underlying: String)

    /// Server returned an error response.
    case serverError(statusCode: Int, message: String)

    /// Response body could not be decoded.
    case decodingError(underlying: String)

    // MARK: - Provider-Specific Errors

    /// OAuth provider returned an explicit error.
    case providerError(error: String, description: String?)

    /// The requested scope is not available.
    case invalidScope(String)

    /// Rate limit exceeded for API calls.
    case rateLimitExceeded(retryAfter: TimeInterval?)

    // MARK: - State Errors

    /// State parameter mismatch (potential CSRF attack).
    case stateMismatch

    /// An authentication operation is already in progress.
    case operationInProgress

    /// The OAuth flow is in an unexpected state.
    case unexpectedState(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let reason):
            return "OAuth is not configured: \(reason)"
        case .invalidCallbackURL(let url):
            return "Invalid callback URL: \(url)"
        case .invalidAuthorizationURL(let url):
            return "Invalid authorization URL: \(url)"
        case .userCancelled:
            return "Authentication was cancelled."
        case .sessionStartFailed(let underlying):
            return "Failed to start authentication session: \(underlying)"
        case .timeout:
            return "Authentication timed out."
        case .invalidCallback(let reason):
            return "Invalid callback received: \(reason)"
        case .missingAuthorizationCode:
            return "Authorization code was not found in callback."
        case .pkceVerificationFailed:
            return "PKCE verification failed."
        case .tokenExchangeFailed(let underlying):
            return "Token exchange failed: \(underlying)"
        case .tokenRefreshFailed(let underlying):
            return "Token refresh failed: \(underlying)"
        case .tokenRefreshExhausted(let attempts, let lastError):
            return "Token refresh failed after \(attempts) attempts: \(lastError)"
        case .refreshTokenExpired:
            return "Your session has expired. Please sign in again."
        case .tokenExpired:
            return "Access token has expired. Please re-authenticate."
        case .invalidTokenResponse(let reason):
            return "Invalid token response: \(reason)"
        case .tokenStorageFailed(let underlying):
            return "Failed to store tokens: \(underlying)"
        case .tokenNotFound:
            return "No authentication token found. Please sign in."
        case .networkError(let underlying):
            return "Network error: \(underlying)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decodingError(let underlying):
            return "Failed to decode response: \(underlying)"
        case .providerError(let error, let description):
            if let description = description {
                return "Authentication error (\(error)): \(description)"
            }
            return "Authentication error: \(error)"
        case .invalidScope(let scope):
            return "Invalid or unavailable scope: \(scope)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .stateMismatch:
            return "Security validation failed. Please try again."
        case .operationInProgress:
            return "An authentication operation is already in progress."
        case .unexpectedState(let state):
            return "Unexpected state: \(state)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Ensure OAuth credentials are configured in the app settings."
        case .userCancelled:
            return "Tap 'Sign In' to try again."
        case .timeout:
            return "Check your internet connection and try again."
        case .tokenExpired, .tokenNotFound, .refreshTokenExpired, .tokenRefreshExhausted:
            return "Please sign in again to continue."
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError:
            return "Please try again later. If the problem persists, contact support."
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Please wait \(Int(retryAfter)) seconds before trying again."
            }
            return "Please wait a few minutes before trying again."
        case .stateMismatch:
            return "For security reasons, please restart the sign-in process."
        case .operationInProgress:
            return "Please wait for the current operation to complete."
        default:
            return nil
        }
    }

    // MARK: - Equatable

    public static func == (lhs: OAuthError, rhs: OAuthError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured(let lReason), .notConfigured(let rReason)):
            return lReason == rReason
        case (.invalidCallbackURL(let lURL), .invalidCallbackURL(let rURL)):
            return lURL == rURL
        case (.invalidAuthorizationURL(let lURL), .invalidAuthorizationURL(let rURL)):
            return lURL == rURL
        case (.userCancelled, .userCancelled):
            return true
        case (.sessionStartFailed(let lUnderlying), .sessionStartFailed(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.timeout, .timeout):
            return true
        case (.invalidCallback(let lReason), .invalidCallback(let rReason)):
            return lReason == rReason
        case (.missingAuthorizationCode, .missingAuthorizationCode):
            return true
        case (.pkceVerificationFailed, .pkceVerificationFailed):
            return true
        case (.tokenExchangeFailed(let lUnderlying), .tokenExchangeFailed(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.tokenRefreshFailed(let lUnderlying), .tokenRefreshFailed(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.tokenRefreshExhausted(let lAttempts, let lError), .tokenRefreshExhausted(let rAttempts, let rError)):
            return lAttempts == rAttempts && lError == rError
        case (.refreshTokenExpired, .refreshTokenExpired):
            return true
        case (.tokenExpired, .tokenExpired):
            return true
        case (.invalidTokenResponse(let lReason), .invalidTokenResponse(let rReason)):
            return lReason == rReason
        case (.tokenStorageFailed(let lUnderlying), .tokenStorageFailed(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.tokenNotFound, .tokenNotFound):
            return true
        case (.networkError(let lUnderlying), .networkError(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.serverError(let lCode, let lMessage), .serverError(let rCode, let rMessage)):
            return lCode == rCode && lMessage == rMessage
        case (.decodingError(let lUnderlying), .decodingError(let rUnderlying)):
            return lUnderlying == rUnderlying
        case (.providerError(let lError, let lDesc), .providerError(let rError, let rDesc)):
            return lError == rError && lDesc == rDesc
        case (.invalidScope(let lScope), .invalidScope(let rScope)):
            return lScope == rScope
        case (.rateLimitExceeded(let lRetry), .rateLimitExceeded(let rRetry)):
            return lRetry == rRetry
        case (.stateMismatch, .stateMismatch):
            return true
        case (.operationInProgress, .operationInProgress):
            return true
        case (.unexpectedState(let lState), .unexpectedState(let rState)):
            return lState == rState
        default:
            return false
        }
    }
}

// MARK: - Error Classification

extension OAuthError {
    /// Whether this error is recoverable by retrying.
    public var isRetryable: Bool {
        switch self {
        case .timeout, .networkError:
            return true
        case .serverError(let code, _):
            // Retry on 5xx server errors
            return code >= 500
        case .rateLimitExceeded:
            return true
        default:
            return false
        }
    }

    /// Whether this error requires user action to recover.
    public var requiresUserAction: Bool {
        switch self {
        case .notConfigured, .userCancelled, .tokenExpired, .tokenNotFound, .refreshTokenExpired, .tokenRefreshExhausted, .stateMismatch:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates the user needs to re-authenticate.
    public var requiresReauthentication: Bool {
        switch self {
        case .tokenExpired, .tokenNotFound, .tokenRefreshFailed, .refreshTokenExpired, .tokenRefreshExhausted, .stateMismatch:
            return true
        case .providerError(let error, _):
            // Common OAuth error codes that require re-auth
            return ["invalid_grant", "invalid_token", "access_denied"].contains(error)
        default:
            return false
        }
    }

    /// Whether this error indicates the refresh token itself has expired or been revoked.
    /// This is a non-retryable condition requiring full re-authentication.
    public var isRefreshTokenInvalid: Bool {
        switch self {
        case .refreshTokenExpired:
            return true
        case .providerError(let error, _):
            // OAuth error codes indicating the refresh token is invalid
            return ["invalid_grant", "invalid_token"].contains(error)
        default:
            return false
        }
    }
}
