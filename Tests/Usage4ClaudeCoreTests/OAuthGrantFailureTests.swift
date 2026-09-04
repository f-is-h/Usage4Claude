import XCTest
@testable import Usage4ClaudeCore

/// Tests for telling a dead OAuth grant apart from an ordinary HTTP failure.
///
/// The bug this exists to prevent: refresh tokens are single-use, and when one
/// is spent or revoked the account can only be recovered by signing in again.
/// The services recognised that state from HTTP 401 alone, but RFC 6749 §5.2
/// specifies HTTP 400 with `invalid_grant`, which is what Anthropic returns. So
/// a dead Claude grant fell through to a generic `httpError` and the UI offered
/// "run diagnostics" instead of "sign in again" — advice that cannot possibly
/// help, since no diagnostic can revive a revoked grant.
///
/// Specs the production code intends to honor:
/// - A spent or revoked refresh token is recognised from either provider's shape.
/// - A transient server failure is not mistaken for one, since that would push
///   users to re-authenticate over a blip.
final class OAuthGrantFailureTests: XCTestCase {

    // MARK: - Dead grants

    /// Anthropic, verbatim from a captured log.
    func testAnthropic400InvalidGrantIsDead() {
        let body = #"{"error": "invalid_grant", "error_description": "Refresh token not found or invalid"}"#
        XCTAssertTrue(OAuthGrantFailure.isDeadGrant(statusCode: 400, body: body))
    }

    /// OpenAI, verbatim from a captured log.
    func testOpenAI401AlreadyUsedIsDead() {
        let body = #"{"error":{"message":"Your refresh token has already been used to generate a new access token. Please try signing in again.","type":"invalid_request_error"}}"#
        XCTAssertTrue(OAuthGrantFailure.isDeadGrant(statusCode: 401, body: body))
    }

    /// 401 means the credential was rejected, whatever the body says.
    func testAny401IsDead() {
        XCTAssertTrue(OAuthGrantFailure.isDeadGrant(statusCode: 401, body: ""))
    }

    /// The "already used" wording is decisive even on a status code that would
    /// otherwise read as transient.
    func testAlreadyUsedWordingIsDeadOnAnyStatus() {
        let body = "Your refresh token has already been used to generate a new access token."
        XCTAssertTrue(OAuthGrantFailure.isDeadGrant(statusCode: 400, body: body))
    }

    // MARK: - Not dead grants

    /// A transient failure must not send the user off to re-authenticate.
    func testServerErrorIsNotDead() {
        XCTAssertFalse(OAuthGrantFailure.isDeadGrant(statusCode: 500, body: "internal server error"))
    }

    func testRateLimitIsNotDead() {
        XCTAssertFalse(OAuthGrantFailure.isDeadGrant(statusCode: 429, body: "too many requests"))
    }

    /// A 400 that is not about the grant, such as a malformed request, is a bug
    /// on our side rather than a revoked authorisation.
    func testUnrelated400IsNotDead() {
        let body = #"{"error": "invalid_request", "error_description": "Missing client_id"}"#
        XCTAssertFalse(OAuthGrantFailure.isDeadGrant(statusCode: 400, body: body))
    }

    func testCloudflareHtmlIsNotDead() {
        XCTAssertFalse(OAuthGrantFailure.isDeadGrant(statusCode: 403, body: "<html>Just a moment...</html>"))
    }
}
