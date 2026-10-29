import XCTest
@testable import Usage4ClaudeCore

final class AntigravityAccountTests: XCTestCase {
    func testClientDiscoveryAcceptsOnePair() {
        let text = "123-test.apps.googleusercontent.com GOCSPX-" + String(repeating: "a", count: 28)
        let client = AntigravityOAuthConfig.parseClient(fromInstalledArtifactText: text)
        XCTAssertEqual(client?.clientID, "123-test.apps.googleusercontent.com")
        XCTAssertNotNil(client?.clientSecret)
    }
    func testClientDiscoveryRejectsAmbiguousAndIncompleteArtifacts() {
        XCTAssertNil(AntigravityOAuthConfig.parseClient(fromInstalledArtifactText: "123-test.apps.googleusercontent.com"))
        let text = "123-first.apps.googleusercontent.com 456-second.apps.googleusercontent.com GOCSPX-" + String(repeating: "a", count: 28)
        XCTAssertNil(AntigravityOAuthConfig.parseClient(fromInstalledArtifactText: text))
    }
    func testOAuthAccountRoundTripPreservesIdentityAndCredentials() throws {
        let credentials = AntigravityCredentials(accessToken: "access", refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 12345), clientID: "client", clientSecret: "secret")
        let account = AntigravityAccount(email: "a@example.test", subject: "google-id", alias: "Work", credentials: credentials)
        let restored = try JSONDecoder().decode(AntigravityAccount.self, from: JSONEncoder().encode(account))
        XCTAssertEqual(restored, account)
        XCTAssertFalse(restored.isLocal)
        XCTAssertEqual(restored.displayName, "Work")
    }
    func testLocalAccountDoesNotInventCredentials() {
        let account = AntigravityAccount(email: "Antigravity", subject: "local")
        XCTAssertTrue(account.isLocal)
        XCTAssertNil(account.credentials)
    }
    private func bucket(_ fraction: Double, disabled: Bool = false) -> [String: Any] {
        ["bucketId": "gemini-weekly", "window": "weekly", "remainingFraction": fraction, "disabled": disabled]
    }
    private func payload(_ buckets: [[String: Any]]) -> [String: Any] {
        ["groups": [["displayName": "Gemini Models", "buckets": buckets]]]
    }
    func testMeasuredQuotaIsConvertedToUsedPercentage() throws {
        let data = try AntigravityRemoteQuotaParser.parse(["summary": payload([bucket(0.75)])])
        XCTAssertEqual(data.gemini.weekly!.percentage, 25, accuracy: 0.001)
        XCTAssertNil(data.gemini.fiveHour)
    }
    func testDisabledQuotaDoesNotBecomeZeroUsage() {
        XCTAssertThrowsError(try AntigravityRemoteQuotaParser.parse(payload([bucket(1, disabled: true)])))
    }
    func testOutOfRangeAndNonfiniteQuotasAreRejected() {
        for fraction in [-1.0, 2.0, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try AntigravityRemoteQuotaParser.parse(payload([bucket(fraction)])))
        }
    }
    func testUnknownSummaryNeverInventsFullAllowance() {
        XCTAssertThrowsError(try AntigravityRemoteQuotaParser.parse(["models": [:]]))
        XCTAssertThrowsError(try AntigravityRemoteQuotaParser.parse(payload([])))
    }
    func testOmittedZeroFractionMeansExhausted() throws {
        let bucket: [String: Any] = ["bucketId": "gemini-weekly", "window": "weekly", "resetTime": "2026-11-04T00:00:00Z"]
        let data = try AntigravityRemoteQuotaParser.parse(payload([bucket]))
        XCTAssertEqual(data.gemini.weekly?.percentage, 100)
    }
    func testBucketWithoutWindowOrFractionIsDropped() {
        XCTAssertThrowsError(try AntigravityRemoteQuotaParser.parse(payload([["bucketId": "gemini-weekly"]])))
    }
    func testNestedRemainingFraction() throws {
        let bucket: [String: Any] = ["id": "3p-weekly", "window": "weekly",
            "remaining": ["case": "remainingFraction", "value": 0.5]]
        let data = try AntigravityRemoteQuotaParser.parse(["response": ["groups": [["name": "Claude and GPT models", "buckets": [bucket]]]]])
        XCTAssertEqual(data.thirdParty.weekly?.percentage, 50)
    }
}
