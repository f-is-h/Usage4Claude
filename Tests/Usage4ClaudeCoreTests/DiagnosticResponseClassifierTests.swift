import XCTest
@testable import Usage4ClaudeCore

/// Tests for `DiagnosticResponseClassifier` — the "raw HTTP response → failure
/// reason" decision that drives the exported diagnostic report.
///
/// The regression this guards against is Issue #84: both providers answered with
/// a perfectly ordinary "your credentials expired" response, and the classifier
/// filed both under "Data Parsing Error" simply because the body did not decode
/// into the success shape. Claude's structured 403 error body was never read at
/// all, and ChatGPT's signed-out session (HTTP 200, banner only) decoded fine
/// into a `CodexSessionResponse` with a nil accessToken and was still treated as
/// a parse failure. The Codex verdict then degraded to "Unknown error, please
/// share this report with developers", which is how the report ended up telling
/// the user to file the issue.
///
/// Specs the production code intends to honor:
/// - An authentication rejection is classified as such, never as a parse failure.
/// - A signed-out ChatGPT session is a rejected session, not unparsable data.
/// - `.unparsable` is reserved for bodies that genuinely fit no known shape.
final class DiagnosticResponseClassifierTests: XCTestCase {

    // MARK: - Claude: credentials rejected

    /// Verbatim body from the Issue #84 diagnostic report.
    func testClaude403PermissionErrorIsCredentialsRejected() {
        let body = Data("""
        {"type":"error","error":{"type":"permission_error","message":"Invalid authorization"},"request_id":"req_011CeeeicPEFMdpYgTLRwZmr"}
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 403, body: body)

        guard case .credentialsRejected(let detail) = outcome else {
            return XCTFail("Expected .credentialsRejected, got \(outcome)")
        }
        XCTAssertTrue(detail.contains("Invalid authorization"), "Server message should survive into the report: \(detail)")
        XCTAssertTrue(detail.contains("403"))
    }

    func testClaude401WithoutErrorBodyIsCredentialsRejected() {
        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 401, body: Data("nope".utf8))

        guard case .credentialsRejected = outcome else {
            return XCTFail("Expected .credentialsRejected, got \(outcome)")
        }
    }

    func testClaudeAuthenticationErrorTypeIsCredentialsRejected() {
        let body = Data("""
        {"type":"error","error":{"type":"authentication_error","message":"Missing session"}}
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 200, body: body)

        guard case .credentialsRejected = outcome else {
            return XCTFail("Expected .credentialsRejected, got \(outcome)")
        }
    }

    // MARK: - Claude: other outcomes

    func testClaudeValidUsageIsUsageDataAvailable() {
        let body = Data("""
        {
            "five_hour": { "utilization": 42, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": { "utilization": 10, "resets_at": "2026-05-07T15:00:00.000Z" },
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 200, body: body)

        guard case .usageDataAvailable(let preview) = outcome else {
            return XCTFail("Expected .usageDataAvailable, got \(outcome)")
        }
        XCTAssertTrue(preview.contains("42"))
    }

    /// Free Tier / Team without a member dashboard (Issue #83, #74) must stay
    /// distinct from a credential failure.
    func testClaudeAllNullLimitsIsDashboardUnavailable() {
        let body = Data("""
        {
            "member_dashboard_available": false,
            "five_hour": null,
            "seven_day": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 200, body: body)
        XCTAssertEqual(outcome, .usageDashboardUnavailable)
    }

    func testClaudeCloudflareHtmlIsChallenge() {
        let body = Data("<!DOCTYPE html><html><head><title>Just a moment...</title></head></html>".utf8)
        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: 403, body: body)
        XCTAssertEqual(outcome, .cloudflareChallenge)
    }

    func testClaudeNonJsonBodyIsUnparsable() {
        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(
            statusCode: 200,
            body: Data("upstream connect error".utf8)
        )
        XCTAssertEqual(outcome, .unparsable)
    }

    /// Every field on `UsageResponse` is optional, so an unfamiliar JSON object
    /// decodes cleanly with no limit data and lands on `.usageDashboardUnavailable`
    /// rather than `.unparsable`. That is deliberate — it is the same path the
    /// #83 fix relies on for Free Tier — but it means `.unparsable` only ever
    /// catches bodies that are not JSON objects at all. Pinned here so a future
    /// change to the decode order is a conscious one.
    func testClaudeUnfamiliarJsonObjectFallsToDashboardUnavailable() {
        let outcome = DiagnosticResponseClassifier.classifyClaudeUsage(
            statusCode: 200,
            body: Data("{\"something\":\"entirely new\"}".utf8)
        )
        XCTAssertEqual(outcome, .usageDashboardUnavailable)
    }

    // MARK: - Codex: session rejected

    /// Verbatim body from the Issue #84 diagnostic report: chatgpt.com answers
    /// HTTP 200 with the banner and nothing else when nobody is signed in.
    func testCodexSignedOutSessionIsRejectedNotUnparsable() {
        let body = Data("""
        {"WARNING_BANNER":"!!!!!!!!!!!!!!!!!!!! DO NOT SHARE ANY PART OF THE INFORMATION YOU SEE HERE. !!!!!!!!!!!!!!!!!!!!"}
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 200, body: body)

        guard case .sessionRejected(let detail) = outcome else {
            return XCTFail("Expected .sessionRejected, got \(outcome)")
        }
        XCTAssertTrue(detail.localizedCaseInsensitiveContains("no access token"), detail)
    }

    func testCodexEmptyAccessTokenIsRejected() {
        let body = Data("{\"accessToken\":\"\",\"user\":null}".utf8)
        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 200, body: body)

        guard case .sessionRejected = outcome else {
            return XCTFail("Expected .sessionRejected, got \(outcome)")
        }
    }

    func testCodex401IsRejected() {
        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 401, body: Data())

        guard case .sessionRejected(let detail) = outcome else {
            return XCTFail("Expected .sessionRejected, got \(outcome)")
        }
        XCTAssertTrue(detail.contains("401"))
    }

    // MARK: - Codex: other outcomes

    func testCodexValidSessionIsAuthenticated() {
        let body = Data("""
        {"accessToken":"header.payload.signature","user":{"name":"Ada","email":"ada@example.com"}}
        """.utf8)

        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 200, body: body)
        XCTAssertEqual(outcome, .authenticated(accessToken: "header.payload.signature", email: "ada@example.com"))
    }

    func testCodexCloudflareHtmlIsChallenge() {
        let body = Data("<html><body>Just a moment...</body></html>".utf8)
        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 200, body: body)
        XCTAssertEqual(outcome, .cloudflareChallenge)
    }

    /// A plain 403 HTML page with no Cloudflare marker is a rejection, not a
    /// challenge — the status code alone must not promote it.
    func testCodexPlainHtml403IsRejectedNotChallenge() {
        let body = Data("<html><body>Forbidden</body></html>".utf8)
        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 403, body: body)

        guard case .sessionRejected = outcome else {
            return XCTFail("Expected .sessionRejected, got \(outcome)")
        }
    }

    func testCodexUnrecognisedBodyIsUnparsable() {
        let outcome = DiagnosticResponseClassifier.classifyCodexSession(statusCode: 200, body: Data("[]".utf8))
        XCTAssertEqual(outcome, .unparsable)
    }
}
