import XCTest
@testable import Usage4ClaudeCore

/// Tests for the guard that decides whether a rotated Codex session-token may be
/// persisted.
///
/// The bug this exists to prevent: chatgpt.com issues a fresh anonymous
/// `session-token` cookie when nobody is signed in, and three refresh paths used
/// to persist any token that merely differed from the stored one. That wrote the
/// anonymous token over the user's real one and signed the account out for good.
/// Clicking "Test Connection" reproduced it every time, because the diagnostic's
/// SSR probe runs the same path.
///
/// Specs the production code intends to honor:
/// - Persisting requires proof that the same session was authenticated, and the
///   accessToken is that proof: the server returns it only for a signed-in session.
/// - No proof means no write, leaving the stored token untouched.
final class CodexSessionTokenRotationTests: XCTestCase {

    // MARK: - pending

    func testChangedTokenIsPending() {
        let rotation = CodexSessionTokenRotation.pending(candidate: "new", replacing: "old")
        XCTAssertEqual(rotation, CodexSessionTokenRotation(newToken: "new", replacing: "old"))
    }

    func testUnchangedTokenIsNotPending() {
        XCTAssertNil(CodexSessionTokenRotation.pending(candidate: "same", replacing: "same"))
    }

    func testMissingCandidateIsNotPending() {
        XCTAssertNil(CodexSessionTokenRotation.pending(candidate: nil, replacing: "old"))
    }

    func testEmptyCandidateIsNotPending() {
        XCTAssertNil(CodexSessionTokenRotation.pending(candidate: "", replacing: "old"))
    }

    // MARK: - authorized

    func testProofAuthorisesTheWriteBack() {
        let rotation = CodexSessionTokenRotation(newToken: "new", replacing: "old")
        XCTAssertEqual(rotation.authorized(by: "an-access-token"), rotation)
    }

    /// The signed-out case: the server hands back a new cookie but no accessToken.
    /// This is the exact shape that used to destroy the stored credential.
    func testAbsentProofBlocksTheWriteBack() {
        let rotation = CodexSessionTokenRotation(newToken: "anonymous-token", replacing: "the-real-token")
        XCTAssertNil(rotation.authorized(by: nil))
    }

    func testEmptyProofBlocksTheWriteBack() {
        let rotation = CodexSessionTokenRotation(newToken: "anonymous-token", replacing: "the-real-token")
        XCTAssertNil(rotation.authorized(by: ""))
    }

    // MARK: - The full signed-out sequence

    /// Walks the sequence the log captured: chatgpt.com answers HTTP 200, sets a
    /// new session-token, and the bootstrap then reports authStatus=logged_out
    /// with no accessToken. Nothing may be written.
    func testSignedOutResponseNeverProducesAWrite() {
        let stored = "the-users-real-session-token"
        let anonymousCookie = "a-fresh-anonymous-session-token"

        let pending = CodexSessionTokenRotation.pending(candidate: anonymousCookie, replacing: stored)
        XCTAssertNotNil(pending, "The cookie did change, so a rotation is pending")

        // authStatus=logged_out carries no accessToken
        XCTAssertNil(pending?.authorized(by: nil), "A signed-out response must not authorise a write")
    }

    /// The counterpart: a genuinely authenticated refresh still rotates.
    func testAuthenticatedResponseStillRotates() {
        let pending = CodexSessionTokenRotation.pending(
            candidate: "rotated-token", replacing: "previous-token"
        )
        let authorized = pending?.authorized(by: "header.payload.signature")

        XCTAssertEqual(authorized?.newToken, "rotated-token")
        XCTAssertEqual(authorized?.replacing, "previous-token",
                       "The old token identifies which account to update")
    }
}
