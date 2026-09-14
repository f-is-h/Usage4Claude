import XCTest
@testable import Usage4ClaudeCore

/// 回归测试：JWT payload 使用 base64url 字母表（含 `-`/`_`，无 padding）。
/// 修复前的实现直接用标准 `Data(base64Encoded:)` 解码，只要 payload 的
/// base64 形式含 `-`/`_` 就会解码失败 → `jwtExpiry` 返回 nil。
final class JWTTests: XCTestCase {

    private func makeToken(payloadJSON: String) -> String {
        let base64url = Data(payloadJSON.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(base64url).signature"
    }

    func testJwtExpiryDecodesSimplePayload() {
        let exp: TimeInterval = 1_893_456_000
        let token = makeToken(payloadJSON: #"{"exp":\#(Int(exp))}"#)

        XCTAssertEqual(jwtExpiry(from: token)?.timeIntervalSince1970, exp)
    }

    /// payload 中的 "??????" 使其标准 base64 编码必然含 `/`（可用
    /// `Data(payloadJSON.utf8).base64EncodedString()` 验证），从而真正覆盖
    /// base64url → base64 字母表转换这条修复路径，而不只是走 padding 分支。
    func testJwtExpiryHandlesPayloadsRequiringURLSafeCharacters() {
        let exp: TimeInterval = 1_893_456_000
        let payloadJSON = #"{"exp":1893456000,"pad":"??????"}"#
        precondition(Data(payloadJSON.utf8).base64EncodedString().contains("/"))

        let token = makeToken(payloadJSON: payloadJSON)

        XCTAssertEqual(jwtExpiry(from: token)?.timeIntervalSince1970, exp)
    }

    func testJwtExpiryReturnsNilForMalformedToken() {
        XCTAssertNil(jwtExpiry(from: "not-a-jwt"))
        XCTAssertNil(jwtExpiry(from: "only.two"))
    }

    func testJwtExpiryReturnsNilWhenExpMissing() {
        let token = makeToken(payloadJSON: #"{"sub":"user"}"#)
        XCTAssertNil(jwtExpiry(from: token))
    }
}
