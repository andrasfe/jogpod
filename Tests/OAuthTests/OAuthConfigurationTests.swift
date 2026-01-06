import Testing
import Foundation
@testable import JogPod

// MARK: - OAuth Configuration Tests

@Suite("OAuth Configuration Tests")
struct OAuthConfigurationTests {

    // MARK: - Test Fixtures

    private static func makeConfiguration(
        usePKCE: Bool = true,
        oauthVersion: OAuthConfiguration.OAuthVersion = .oauth2
    ) -> OAuthConfiguration {
        OAuthConfiguration(
            clientId: "test_client_id",
            clientSecret: "test_client_secret",
            callbackURLScheme: "jogpod",
            callbackURL: URL(string: "jogpod://oauth/callback")!,
            authorizationURL: URL(string: "https://api.example.com/oauth/authorize")!,
            tokenURL: URL(string: "https://api.example.com/oauth/token")!,
            scopes: ["activity", "profile"],
            usePKCE: usePKCE,
            oauthVersion: oauthVersion
        )
    }

    // MARK: - Initialization Tests

    @Test("Configuration initializes with all fields")
    func testConfigurationInitialization() {
        let config = Self.makeConfiguration()

        #expect(config.clientId == "test_client_id")
        #expect(config.clientSecret == "test_client_secret")
        #expect(config.callbackURLScheme == "jogpod")
        #expect(config.callbackURL.absoluteString == "jogpod://oauth/callback")
        #expect(config.authorizationURL.absoluteString == "https://api.example.com/oauth/authorize")
        #expect(config.tokenURL.absoluteString == "https://api.example.com/oauth/token")
        #expect(config.scopes == ["activity", "profile"])
        #expect(config.usePKCE == true)
        #expect(config.oauthVersion == .oauth2)
    }

    @Test("Configuration with OAuth 1.0")
    func testOAuth1Configuration() {
        let config = Self.makeConfiguration(usePKCE: false, oauthVersion: .oauth1)

        #expect(config.usePKCE == false)
        #expect(config.oauthVersion == .oauth1)
        #expect(config.oauthVersion.rawValue == "1.0")
    }

    @Test("Configuration with OAuth 2.0")
    func testOAuth2Configuration() {
        let config = Self.makeConfiguration(oauthVersion: .oauth2)

        #expect(config.oauthVersion == .oauth2)
        #expect(config.oauthVersion.rawValue == "2.0")
    }

    @Test("Configuration with empty scopes")
    func testEmptyScopes() {
        let config = OAuthConfiguration(
            clientId: "id",
            clientSecret: "secret",
            callbackURLScheme: "app",
            callbackURL: URL(string: "app://callback")!,
            authorizationURL: URL(string: "https://example.com/auth")!,
            tokenURL: URL(string: "https://example.com/token")!,
            scopes: []
        )

        #expect(config.scopes.isEmpty)
    }

    @Test("Configuration is Sendable")
    func testConfigurationSendable() async {
        let config = Self.makeConfiguration()

        let result = await Task.detached {
            return config.clientId
        }.value

        #expect(result == "test_client_id")
    }
}

// MARK: - PKCE Generator Tests

@Suite("PKCE Generator Tests")
struct PKCEGeneratorTests {

    @Test("PKCE generator creates code verifier")
    func testCodeVerifierGeneration() {
        let pkce = PKCEGenerator()

        #expect(!pkce.codeVerifier.isEmpty)
        // Code verifier should be base64url encoded (no +, /, or =)
        #expect(!pkce.codeVerifier.contains("+"))
        #expect(!pkce.codeVerifier.contains("/"))
        #expect(!pkce.codeVerifier.contains("="))
    }

    @Test("PKCE generator creates code challenge")
    func testCodeChallengeGeneration() {
        let pkce = PKCEGenerator()

        #expect(!pkce.codeChallenge.isEmpty)
        // Code challenge should be base64url encoded
        #expect(!pkce.codeChallenge.contains("+"))
        #expect(!pkce.codeChallenge.contains("/"))
        #expect(!pkce.codeChallenge.contains("="))
    }

    @Test("PKCE generator uses S256 method")
    func testCodeChallengeMethod() {
        let pkce = PKCEGenerator()

        #expect(pkce.codeChallengeMethod == "S256")
    }

    @Test("Code verifier and challenge are different")
    func testVerifierAndChallengeDifferent() {
        let pkce = PKCEGenerator()

        #expect(pkce.codeVerifier != pkce.codeChallenge)
    }

    @Test("Each PKCE instance generates unique values")
    func testUniqueValues() {
        let pkce1 = PKCEGenerator()
        let pkce2 = PKCEGenerator()

        #expect(pkce1.codeVerifier != pkce2.codeVerifier)
        #expect(pkce1.codeChallenge != pkce2.codeChallenge)
    }

    @Test("Code verifier has appropriate length")
    func testCodeVerifierLength() {
        let pkce = PKCEGenerator()

        // 32 bytes base64url encoded = ~43 characters
        #expect(pkce.codeVerifier.count >= 40)
        #expect(pkce.codeVerifier.count <= 50)
    }

    @Test("Code challenge has appropriate length")
    func testCodeChallengeLength() {
        let pkce = PKCEGenerator()

        // SHA256 hash base64url encoded = 43 characters
        #expect(pkce.codeChallenge.count >= 40)
        #expect(pkce.codeChallenge.count <= 50)
    }

    @Test("PKCE generator is Sendable")
    func testPKCESendable() async {
        let pkce = PKCEGenerator()

        let result = await Task.detached {
            return pkce.codeVerifier
        }.value

        #expect(result == pkce.codeVerifier)
    }
}
