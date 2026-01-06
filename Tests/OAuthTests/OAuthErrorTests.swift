import Testing
@testable import JogPod

// MARK: - OAuthError Tests

@Suite("OAuth Error Tests")
struct OAuthErrorTests {

    // MARK: - Error Description Tests

    @Test("Error descriptions are properly formatted")
    func testErrorDescriptions() {
        let testCases: [(OAuthError, String)] = [
            (.notConfigured(reason: "Missing client ID"), "OAuth is not configured: Missing client ID"),
            (.invalidCallbackURL("http://bad"), "Invalid callback URL: http://bad"),
            (.userCancelled, "Authentication was cancelled."),
            (.timeout, "Authentication timed out."),
            (.missingAuthorizationCode, "Authorization code was not found in callback."),
            (.tokenExpired, "Access token has expired. Please re-authenticate."),
            (.tokenNotFound, "No authentication token found. Please sign in."),
            (.stateMismatch, "Security validation failed. Please try again."),
            (.operationInProgress, "An authentication operation is already in progress."),
        ]

        for (error, expectedDescription) in testCases {
            #expect(error.errorDescription == expectedDescription)
        }
    }

    @Test("Server error includes status code and message")
    func testServerErrorDescription() {
        let error = OAuthError.serverError(statusCode: 500, message: "Internal Server Error")
        #expect(error.errorDescription == "Server error (500): Internal Server Error")
    }

    @Test("Provider error includes description when available")
    func testProviderErrorWithDescription() {
        let error = OAuthError.providerError(error: "invalid_grant", description: "The token has expired")
        #expect(error.errorDescription == "Authentication error (invalid_grant): The token has expired")
    }

    @Test("Provider error without description shows only error code")
    func testProviderErrorWithoutDescription() {
        let error = OAuthError.providerError(error: "access_denied", description: nil)
        #expect(error.errorDescription == "Authentication error: access_denied")
    }

    @Test("Rate limit error shows retry time when available")
    func testRateLimitWithRetryAfter() {
        let error = OAuthError.rateLimitExceeded(retryAfter: 120)
        #expect(error.errorDescription == "Rate limit exceeded. Retry after 120 seconds.")
    }

    @Test("Rate limit error without retry time shows generic message")
    func testRateLimitWithoutRetryAfter() {
        let error = OAuthError.rateLimitExceeded(retryAfter: nil)
        #expect(error.errorDescription == "Rate limit exceeded. Please try again later.")
    }

    // MARK: - Equatable Tests

    @Test("Same errors are equal")
    func testErrorEquality() {
        #expect(OAuthError.userCancelled == OAuthError.userCancelled)
        #expect(OAuthError.timeout == OAuthError.timeout)
        #expect(OAuthError.tokenExpired == OAuthError.tokenExpired)
        #expect(OAuthError.stateMismatch == OAuthError.stateMismatch)
    }

    @Test("Different errors are not equal")
    func testErrorInequality() {
        #expect(OAuthError.userCancelled != OAuthError.timeout)
        #expect(OAuthError.tokenExpired != OAuthError.tokenNotFound)
    }

    @Test("Errors with same type but different values are not equal")
    func testErrorValueInequality() {
        #expect(OAuthError.serverError(statusCode: 500, message: "Error") != OAuthError.serverError(statusCode: 400, message: "Error"))
        #expect(OAuthError.notConfigured(reason: "A") != OAuthError.notConfigured(reason: "B"))
    }

    // MARK: - Classification Tests

    @Test("Timeout errors are retryable")
    func testTimeoutIsRetryable() {
        #expect(OAuthError.timeout.isRetryable == true)
    }

    @Test("Network errors are retryable")
    func testNetworkErrorIsRetryable() {
        #expect(OAuthError.networkError(underlying: "Connection failed").isRetryable == true)
    }

    @Test("Server 5xx errors are retryable")
    func testServer5xxIsRetryable() {
        #expect(OAuthError.serverError(statusCode: 500, message: "Internal Error").isRetryable == true)
        #expect(OAuthError.serverError(statusCode: 503, message: "Unavailable").isRetryable == true)
    }

    @Test("Server 4xx errors are not retryable")
    func testServer4xxIsNotRetryable() {
        #expect(OAuthError.serverError(statusCode: 400, message: "Bad Request").isRetryable == false)
        #expect(OAuthError.serverError(statusCode: 401, message: "Unauthorized").isRetryable == false)
    }

    @Test("Rate limit errors are retryable")
    func testRateLimitIsRetryable() {
        #expect(OAuthError.rateLimitExceeded(retryAfter: 60).isRetryable == true)
    }

    @Test("User cancelled requires user action")
    func testUserCancelledRequiresUserAction() {
        #expect(OAuthError.userCancelled.requiresUserAction == true)
    }

    @Test("Token expired requires user action")
    func testTokenExpiredRequiresUserAction() {
        #expect(OAuthError.tokenExpired.requiresUserAction == true)
    }

    @Test("Network error does not require user action")
    func testNetworkErrorDoesNotRequireUserAction() {
        #expect(OAuthError.networkError(underlying: "Timeout").requiresUserAction == false)
    }

    @Test("Token expired requires reauthentication")
    func testTokenExpiredRequiresReauth() {
        #expect(OAuthError.tokenExpired.requiresReauthentication == true)
    }

    @Test("Token not found requires reauthentication")
    func testTokenNotFoundRequiresReauth() {
        #expect(OAuthError.tokenNotFound.requiresReauthentication == true)
    }

    @Test("Token refresh failed requires reauthentication")
    func testTokenRefreshFailedRequiresReauth() {
        #expect(OAuthError.tokenRefreshFailed(underlying: "Invalid").requiresReauthentication == true)
    }

    @Test("Invalid grant provider error requires reauthentication")
    func testInvalidGrantRequiresReauth() {
        #expect(OAuthError.providerError(error: "invalid_grant", description: nil).requiresReauthentication == true)
    }

    @Test("Other provider errors do not require reauthentication")
    func testOtherProviderErrorsDoNotRequireReauth() {
        #expect(OAuthError.providerError(error: "server_error", description: nil).requiresReauthentication == false)
    }

    // MARK: - Recovery Suggestion Tests

    @Test("Token expired has recovery suggestion")
    func testTokenExpiredRecoverySuggestion() {
        #expect(OAuthError.tokenExpired.recoverySuggestion == "Please sign in again to continue.")
    }

    @Test("User cancelled has recovery suggestion")
    func testUserCancelledRecoverySuggestion() {
        #expect(OAuthError.userCancelled.recoverySuggestion == "Tap 'Sign In' to try again.")
    }

    @Test("Rate limit has recovery suggestion with time")
    func testRateLimitRecoverySuggestion() {
        let error = OAuthError.rateLimitExceeded(retryAfter: 60)
        #expect(error.recoverySuggestion == "Please wait 60 seconds before trying again.")
    }

    @Test("Network error has recovery suggestion")
    func testNetworkErrorRecoverySuggestion() {
        let error = OAuthError.networkError(underlying: "Connection failed")
        #expect(error.recoverySuggestion == "Check your internet connection and try again.")
    }

    // MARK: - Refresh Token Expiration Tests

    @Test("Refresh token expired error has correct description")
    func testRefreshTokenExpiredDescription() {
        let error = OAuthError.refreshTokenExpired
        #expect(error.errorDescription == "Your session has expired. Please sign in again.")
    }

    @Test("Refresh token expired requires reauthentication")
    func testRefreshTokenExpiredRequiresReauth() {
        #expect(OAuthError.refreshTokenExpired.requiresReauthentication == true)
    }

    @Test("Refresh token expired requires user action")
    func testRefreshTokenExpiredRequiresUserAction() {
        #expect(OAuthError.refreshTokenExpired.requiresUserAction == true)
    }

    @Test("Refresh token expired is not retryable")
    func testRefreshTokenExpiredIsNotRetryable() {
        #expect(OAuthError.refreshTokenExpired.isRetryable == false)
    }

    @Test("Refresh token expired indicates invalid refresh token")
    func testRefreshTokenExpiredIsRefreshTokenInvalid() {
        #expect(OAuthError.refreshTokenExpired.isRefreshTokenInvalid == true)
    }

    // MARK: - Token Refresh Exhausted Tests

    @Test("Token refresh exhausted error has correct description")
    func testTokenRefreshExhaustedDescription() {
        let error = OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Network timeout")
        #expect(error.errorDescription == "Token refresh failed after 3 attempts: Network timeout")
    }

    @Test("Token refresh exhausted requires reauthentication")
    func testTokenRefreshExhaustedRequiresReauth() {
        #expect(OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error").requiresReauthentication == true)
    }

    @Test("Token refresh exhausted requires user action")
    func testTokenRefreshExhaustedRequiresUserAction() {
        #expect(OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error").requiresUserAction == true)
    }

    @Test("Token refresh exhausted has recovery suggestion")
    func testTokenRefreshExhaustedRecoverySuggestion() {
        let error = OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error")
        #expect(error.recoverySuggestion == "Please sign in again to continue.")
    }

    @Test("Token refresh exhausted equality")
    func testTokenRefreshExhaustedEquality() {
        let error1 = OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error A")
        let error2 = OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error A")
        let error3 = OAuthError.tokenRefreshExhausted(attempts: 2, lastError: "Error A")
        let error4 = OAuthError.tokenRefreshExhausted(attempts: 3, lastError: "Error B")

        #expect(error1 == error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
    }

    // MARK: - Refresh Token Invalid Classification Tests

    @Test("Invalid grant provider error indicates invalid refresh token")
    func testInvalidGrantIsRefreshTokenInvalid() {
        #expect(OAuthError.providerError(error: "invalid_grant", description: nil).isRefreshTokenInvalid == true)
    }

    @Test("Invalid token provider error indicates invalid refresh token")
    func testInvalidTokenIsRefreshTokenInvalid() {
        #expect(OAuthError.providerError(error: "invalid_token", description: nil).isRefreshTokenInvalid == true)
    }

    @Test("Other provider errors do not indicate invalid refresh token")
    func testOtherErrorsNotRefreshTokenInvalid() {
        #expect(OAuthError.providerError(error: "server_error", description: nil).isRefreshTokenInvalid == false)
        #expect(OAuthError.networkError(underlying: "Timeout").isRefreshTokenInvalid == false)
        #expect(OAuthError.serverError(statusCode: 500, message: "Error").isRefreshTokenInvalid == false)
    }
}
