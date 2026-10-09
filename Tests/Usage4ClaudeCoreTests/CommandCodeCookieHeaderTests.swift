import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CommandCodeCookieHeader` — turning whatever the user pastes
/// (bare token, `name=value` pair, full `Cookie:` header, cURL capture) into a
/// resolved session cookie.
final class CommandCodeCookieHeaderTests: XCTestCase {

    // MARK: - Bare token

    func testBareTokenAssumesProductionCookieName() {
        let cookie = CommandCodeCookieHeader.cookie(fromRaw: "abc123token")
        XCTAssertEqual(cookie?.name, "__Secure-commandcode_prod_.session_token")
        XCTAssertEqual(cookie?.token, "abc123token")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(CommandCodeCookieHeader.cookie(fromRaw: "  abc123token  ")?.token, "abc123token")
    }

    // MARK: - Explicit pairs / headers

    func testFullCookieHeaderResolvesSessionCookie() {
        let raw = "session_key=abc; __Secure-commandcode_prod_.session_token=tok.123; theme=dark"
        let cookie = CommandCodeCookieHeader.cookie(fromRaw: raw)
        XCTAssertEqual(cookie?.name, "__Secure-commandcode_prod_.session_token")
        XCTAssertEqual(cookie?.token, "tok.123")
        XCTAssertEqual(cookie?.headerValue, "__Secure-commandcode_prod_.session_token=tok.123")
    }

    func testPastedHeaderLineWithCookiePrefixIsAccepted() {
        let raw = "Cookie: __Secure-commandcode_prod_.session_token=tok.123"
        let cookie = CommandCodeCookieHeader.cookie(fromRaw: raw)
        XCTAssertEqual(cookie?.token, "tok.123")
    }

    func testLegacyBetterAuthNameIsAccepted() {
        let raw = "better-auth.session_token=legacy.value"
        XCTAssertEqual(CommandCodeCookieHeader.cookie(fromRaw: raw)?.name, "better-auth.session_token")
        XCTAssertEqual(CommandCodeCookieHeader.cookie(fromRaw: raw)?.token, "legacy.value")
    }

    func testNameMatchIsCaseInsensitiveAndKeepsOriginalName() {
        let raw = "Better-Auth.Session_Token=legacy.value"
        let cookie = CommandCodeCookieHeader.cookie(fromRaw: raw)
        XCTAssertEqual(cookie?.name, "Better-Auth.Session_Token")
        XCTAssertEqual(cookie?.token, "legacy.value")
    }

    // MARK: - Rejections

    func testUnrelatedCookiesYieldNil() {
        XCTAssertNil(CommandCodeCookieHeader.cookie(fromRaw: "theme=dark; locale=en"))
    }

    func testNilOrEmptyYieldsNil() {
        XCTAssertNil(CommandCodeCookieHeader.cookie(fromRaw: nil))
        XCTAssertNil(CommandCodeCookieHeader.cookie(fromRaw: ""))
        XCTAssertNil(CommandCodeCookieHeader.cookie(fromRaw: "   "))
    }

    func testPairWithEmptyValueIsIgnored() {
        XCTAssertNil(CommandCodeCookieHeader.cookie(fromRaw: "__Secure-commandcode_prod_.session_token=; theme=dark"))
    }
}
