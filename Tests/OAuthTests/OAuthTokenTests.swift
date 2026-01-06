import Testing
import Foundation
@testable import JogPod

// MARK: - OAuthToken Tests

@Suite("OAuth Token Tests")
struct OAuthTokenTests {

    // MARK: - Initialization Tests

    @Test("Token initializes with all required fields")
    func testTokenInitialization() {
        let token = OAuthToken(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "activity profile",
            issuedAt: Date(),
            userId: "user_789"
        )

        #expect(token.accessToken == "access_123")
        #expect(token.refreshToken == "refresh_456")
        #expect(token.tokenType == "Bearer")
        #expect(token.expiresIn == 3600)
        #expect(token.scope == "activity profile")
        #expect(token.userId == "user_789")
    }

    @Test("Token initializes with default values")
    func testTokenDefaultValues() {
        let token = OAuthToken(accessToken: "access_123")

        #expect(token.accessToken == "access_123")
        #expect(token.refreshToken == nil)
        #expect(token.tokenType == "Bearer")
        #expect(token.expiresIn == nil)
        #expect(token.scope == nil)
        #expect(token.userId == nil)
    }

    // MARK: - Expiration Tests

    @Test("Token expiration date is calculated correctly")
    func testExpirationDateCalculation() {
        let issuedAt = Date()
        let expiresIn: TimeInterval = 3600 // 1 hour

        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: expiresIn,
            issuedAt: issuedAt
        )

        let expectedExpiration = issuedAt.addingTimeInterval(expiresIn)
        #expect(token.expirationDate == expectedExpiration)
    }

    @Test("Token without expiresIn has nil expiration date")
    func testNoExpirationDate() {
        let token = OAuthToken(accessToken: "access_123")
        #expect(token.expirationDate == nil)
    }

    @Test("Fresh token is not expired")
    func testFreshTokenNotExpired() {
        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: 3600,
            issuedAt: Date()
        )

        #expect(token.isExpired == false)
    }

    @Test("Old token is expired")
    func testOldTokenIsExpired() {
        let oneHourAgo = Date().addingTimeInterval(-3600)

        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: 1800, // 30 minutes
            issuedAt: oneHourAgo
        )

        #expect(token.isExpired == true)
    }

    @Test("Token expires 60 seconds before actual expiration for safety")
    func testTokenExpiresWithSafetyMargin() {
        // Token issued with 90 seconds until expiration
        // With 60 second safety margin, it should be considered expired
        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: 90,
            issuedAt: Date().addingTimeInterval(-35) // 35 seconds ago
        )

        // 90 - 35 = 55 seconds left, which is less than 60 second safety margin
        #expect(token.isExpired == true)
    }

    @Test("Token without expiration info is not expired")
    func testTokenWithoutExpirationNotExpired() {
        let token = OAuthToken(
            accessToken: "access_123",
            expiresIn: nil
        )

        #expect(token.isExpired == false)
    }

    // MARK: - Codable Tests

    @Test("Token encodes to JSON correctly")
    func testTokenEncoding() throws {
        let issuedAt = Date(timeIntervalSince1970: 1700000000)

        let token = OAuthToken(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "activity",
            issuedAt: issuedAt,
            userId: "user_789"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(token)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["accessToken"] as? String == "access_123")
        #expect(json["refreshToken"] as? String == "refresh_456")
        #expect(json["tokenType"] as? String == "Bearer")
        #expect(json["expiresIn"] as? Double == 3600)
        #expect(json["scope"] as? String == "activity")
        #expect(json["userId"] as? String == "user_789")
    }

    @Test("Token decodes from JSON correctly")
    func testTokenDecoding() throws {
        let json = """
        {
            "accessToken": "access_123",
            "refreshToken": "refresh_456",
            "tokenType": "Bearer",
            "expiresIn": 3600,
            "scope": "activity profile",
            "issuedAt": 1700000000,
            "userId": "user_789"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let data = json.data(using: .utf8)!
        let token = try decoder.decode(OAuthToken.self, from: data)

        #expect(token.accessToken == "access_123")
        #expect(token.refreshToken == "refresh_456")
        #expect(token.tokenType == "Bearer")
        #expect(token.expiresIn == 3600)
        #expect(token.scope == "activity profile")
        #expect(token.userId == "user_789")
    }

    @Test("Token with optional fields decodes correctly")
    func testTokenDecodingWithOptionalFields() throws {
        let json = """
        {
            "accessToken": "access_123",
            "tokenType": "Bearer",
            "issuedAt": 1700000000
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let data = json.data(using: .utf8)!
        let token = try decoder.decode(OAuthToken.self, from: data)

        #expect(token.accessToken == "access_123")
        #expect(token.refreshToken == nil)
        #expect(token.expiresIn == nil)
        #expect(token.scope == nil)
        #expect(token.userId == nil)
    }

    // MARK: - Equatable Tests

    @Test("Identical tokens are equal")
    func testTokenEquality() {
        let issuedAt = Date()

        let token1 = OAuthToken(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "activity",
            issuedAt: issuedAt,
            userId: "user_789"
        )

        let token2 = OAuthToken(
            accessToken: "access_123",
            refreshToken: "refresh_456",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "activity",
            issuedAt: issuedAt,
            userId: "user_789"
        )

        #expect(token1 == token2)
    }

    @Test("Tokens with different access tokens are not equal")
    func testTokenInequalityAccessToken() {
        let token1 = OAuthToken(accessToken: "access_123")
        let token2 = OAuthToken(accessToken: "access_456")

        #expect(token1 != token2)
    }

    // MARK: - Sendable Tests

    @Test("Token can be passed across actor boundaries")
    func testTokenSendable() async {
        let token = OAuthToken(accessToken: "access_123")

        // This compiles because OAuthToken is Sendable
        let result = await Task.detached {
            return token.accessToken
        }.value

        #expect(result == "access_123")
    }
}

// MARK: - OAuth1Token Tests

@Suite("OAuth1 Token Tests")
struct OAuth1TokenTests {

    @Test("OAuth1 token initializes correctly")
    func testOAuth1TokenInitialization() {
        let token = OAuth1Token(
            token: "token_123",
            tokenSecret: "secret_456",
            userId: "user_789"
        )

        #expect(token.token == "token_123")
        #expect(token.tokenSecret == "secret_456")
        #expect(token.userId == "user_789")
    }

    @Test("OAuth1 token with nil userId")
    func testOAuth1TokenWithoutUserId() {
        let token = OAuth1Token(
            token: "token_123",
            tokenSecret: "secret_456"
        )

        #expect(token.userId == nil)
    }

    @Test("OAuth1 tokens are equatable")
    func testOAuth1TokenEquality() {
        let token1 = OAuth1Token(token: "token", tokenSecret: "secret", userId: "user")
        let token2 = OAuth1Token(token: "token", tokenSecret: "secret", userId: "user")

        #expect(token1 == token2)
    }

    @Test("OAuth1 tokens are codable")
    func testOAuth1TokenCodable() throws {
        let original = OAuth1Token(token: "token_123", tokenSecret: "secret_456", userId: "user_789")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OAuth1Token.self, from: data)

        #expect(decoded == original)
    }
}
