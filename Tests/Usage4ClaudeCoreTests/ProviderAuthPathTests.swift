import XCTest
@testable import Usage4ClaudeCore

/// Tests for the single decision that says which auth path an account uses.
///
/// The bug this exists to prevent: the diagnostic assumed Claude always uses a
/// sessionKey cookie and Codex always a next-auth session-token, so for an OAuth
/// account it sent the refresh_token as a cookie. claude.ai answered 403
/// account_session_invalid and chatgpt.com answered HTTP 200 with an empty
/// session — every time, for accounts that were refreshing perfectly well. The
/// diagnostic then reported expired credentials with high confidence and told
/// people to re-authenticate something that was never broken.
///
/// The service layer had the dispatch right; the diagnostic had copied it and
/// copied it wrong. Keeping one decision that both layers ask is the only thing
/// that stops that drift, so the rule is pinned here.
final class ProviderAuthPathTests: XCTestCase {

    // MARK: - Claude

    func testClaudeOAuthRefreshTokenTakesTheOAuthPath() {
        XCTAssertEqual(
            ProviderAuthPath.forClaude(credential: "sk-ant-ort01-abc123def456"),
            .oauth
        )
    }

    func testClaudeCookieSessionKeyTakesTheCookiePath() {
        XCTAssertEqual(
            ProviderAuthPath.forClaude(credential: "sk-ant-sid01-abc123def456"),
            .cookie
        )
    }

    func testClaudeEmptyCredentialTakesTheCookiePath() {
        XCTAssertEqual(ProviderAuthPath.forClaude(credential: ""), .cookie)
    }

    // MARK: - Codex

    func testCodexOAuthRefreshTokenTakesTheOAuthPath() {
        XCTAssertEqual(ProviderAuthPath.forCodex(credential: "rt.AbCdEf123456"), .oauth)
    }

    /// next-auth session tokens are encrypted JWE strings and never carry the
    /// "rt." prefix, so they must stay on the cookie path.
    func testCodexNextAuthSessionTokenTakesTheCookiePath() {
        XCTAssertEqual(
            ProviderAuthPath.forCodex(credential: "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..abc"),
            .cookie
        )
    }

    func testCodexEmptyCredentialTakesTheCookiePath() {
        XCTAssertEqual(ProviderAuthPath.forCodex(credential: ""), .cookie)
    }

    // MARK: - Cross-provider

    /// The prefixes are provider-specific: a Claude OAuth token must not be read
    /// as a Codex one or vice versa.
    func testPrefixesDoNotCrossProviders() {
        XCTAssertEqual(ProviderAuthPath.forCodex(credential: "sk-ant-ort01-abc"), .cookie)
        XCTAssertEqual(ProviderAuthPath.forClaude(credential: "rt.abc"), .cookie)
    }

    func testProviderDispatchMatchesTheDirectCalls() {
        XCTAssertEqual(
            ProviderAuthPath.of(.claude, credential: "sk-ant-ort01-abc"),
            ProviderAuthPath.forClaude(credential: "sk-ant-ort01-abc")
        )
        XCTAssertEqual(
            ProviderAuthPath.of(.codex, credential: "rt.abc"),
            ProviderAuthPath.forCodex(credential: "rt.abc")
        )
    }

    /// The report shows this string, so it must name the path a user recognises.
    func testDisplayNamesAreDistinct() {
        XCTAssertNotEqual(ProviderAuthPath.cookie.displayName, ProviderAuthPath.oauth.displayName)
        XCTAssertEqual(ProviderAuthPath.oauth.displayName, "OAuth")
    }
}
