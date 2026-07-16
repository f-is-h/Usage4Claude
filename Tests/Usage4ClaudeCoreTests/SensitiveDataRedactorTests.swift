import XCTest
@testable import Usage4ClaudeCore

/// 覆盖风险：脱敏正则/长度分支写错 → 日志或诊断报告泄漏凭据。
final class SensitiveDataRedactorTests: XCTestCase {

    // MARK: - redactOrganizationId

    func testRedactOrganizationIdShortAllStars() {
        XCTAssertEqual(SensitiveDataRedactor.redactOrganizationId("12345678"), "********")
    }

    func testRedactOrganizationIdLongKeepsPrefixSuffix() {
        let id = "12345678-1234-1234-1234-123456789012"
        XCTAssertEqual(SensitiveDataRedactor.redactOrganizationId(id), "1234...9012")
    }

    // MARK: - redactSessionKey

    func testRedactSessionKeyShort() {
        XCTAssertEqual(SensitiveDataRedactor.redactSessionKey("short-key"), "***")
    }

    func testRedactSessionKeyWithAnthropicPrefix() {
        let key = "sk-ant-" + String(repeating: "x", count: 30)
        let redacted = SensitiveDataRedactor.redactSessionKey(key)
        XCTAssertEqual(redacted, "sk-ant-***...*** (\(key.count) chars)")
    }

    func testRedactSessionKeyWithoutAnthropicPrefix() {
        let key = String(repeating: "x", count: 25)
        let redacted = SensitiveDataRedactor.redactSessionKey(key)
        XCTAssertEqual(redacted, "***...*** (\(key.count) chars)")
    }

    // MARK: - redactCodexSessionToken

    func testRedactCodexSessionTokenShortAllStars() {
        XCTAssertEqual(SensitiveDataRedactor.redactCodexSessionToken("short"), "*****")
    }

    func testRedactCodexSessionTokenLongKeepsPrefixSuffix() {
        let token = "abcdefgh" + String(repeating: "x", count: 20) + "wxyz"
        let redacted = SensitiveDataRedactor.redactCodexSessionToken(token)
        XCTAssertEqual(redacted, "abcdefgh...wxyz (\(token.count) chars)")
    }

    // MARK: - redactAccessToken

    func testRedactAccessTokenJWTFormat() {
        let token = "headerpart.payloadpart.signaturepart"
        let redacted = SensitiveDataRedactor.redactAccessToken(token)
        XCTAssertEqual(redacted, "header...payloa...signat... (\(token.count) chars)")
    }

    func testRedactAccessTokenNonJWTShort() {
        XCTAssertEqual(SensitiveDataRedactor.redactAccessToken("not-a-jwt"), "***")
    }

    func testRedactAccessTokenNonJWTLong() {
        let token = String(repeating: "x", count: 30)
        let redacted = SensitiveDataRedactor.redactAccessToken(token)
        XCTAssertEqual(redacted, "\(token.prefix(8))...\(token.suffix(4)) (\(token.count) chars)")
    }

    // MARK: - redactText

    func testRedactTextSessionKeyPattern() {
        let text = "sessionKey=abcdefghij1234567890abcdef and more"
        let redacted = SensitiveDataRedactor.redactText(text)
        XCTAssertTrue(redacted.contains("sessionKey=***REDACTED***"))
        XCTAssertFalse(redacted.contains("abcdefghij1234567890abcdef"))
    }

    func testRedactTextOrganizationIdPattern() {
        let text = "org id: 12345678-1234-1234-1234-123456789012 done"
        let redacted = SensitiveDataRedactor.redactText(text)
        XCTAssertTrue(redacted.contains("********-****-****-****-************"))
        XCTAssertFalse(redacted.contains("12345678-1234-1234-1234-123456789012"))
    }

    func testRedactTextCookiePattern() {
        let text = "Cookie: sessionKey=abcdefghij1234567890abcdef"
        let redacted = SensitiveDataRedactor.redactText(text)
        XCTAssertEqual(redacted, "Cookie: sessionKey=***REDACTED***")
    }

    func testRedactTextLeavesUnrelatedContentUnchanged() {
        let text = "no sensitive data here, just a normal log line"
        XCTAssertEqual(SensitiveDataRedactor.redactText(text), text)
    }
}
