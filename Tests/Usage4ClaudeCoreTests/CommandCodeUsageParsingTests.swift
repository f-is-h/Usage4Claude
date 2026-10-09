import XCTest
@testable import Usage4ClaudeCore

/// Tests for the Command Code billing parsers and the assembly step. The
/// endpoints are undocumented, so these lock in the defensive behavior: both
/// camelCase and snake_case, numeric strings, epoch-ms vs ISO timestamps, and
/// graceful degradation when fields are missing.
final class CommandCodeUsageParsingTests: XCTestCase {

    private func credits(_ json: String) throws -> CommandCodeCreditsPayload {
        try CommandCodeCreditsPayload.parse(from: Data(json.utf8))
    }

    // MARK: - Credits

    func testParsesCamelCaseCreditsWithEpochMilliseconds() throws {
        let json = """
        {
          "credits": { "monthlyCredits": 42.5, "purchasedCredits": 5, "monthlyCreditsGranted": 70 },
          "windowLimits": {
            "fiveHour": { "cap": 14, "used": 4.4, "resetAt": 1730000000000 },
            "weekly":   { "cap": 35, "used": 12,  "resetAt": 1730500000000 }
          }
        }
        """
        let payload = try credits(json)

        XCTAssertEqual(payload.monthlyCredits, 42.5)
        XCTAssertEqual(payload.purchasedCredits, 5)
        XCTAssertEqual(payload.monthlyCreditsGranted, 70)
        XCTAssertEqual(try XCTUnwrap(payload.fiveHourWindow).percentage, 4.4 / 14 * 100, accuracy: 0.0001)
        XCTAssertEqual(payload.fiveHourWindow?.resetsAt?.timeIntervalSince1970, 1_730_000_000)
        XCTAssertEqual(try XCTUnwrap(payload.weeklyWindow).percentage, 12.0 / 35 * 100, accuracy: 0.0001)
    }

    func testParsesSnakeCaseVariantWithNumericStrings() throws {
        let json = """
        {
          "credits": { "monthly_credits": "10.0", "purchased_credits": "0", "monthly_credits_granted": "10" },
          "windowLimits": {
            "fiveHour": { "limit": "3", "usage": "1.5", "reset_at": "2030-01-01T00:00:00Z" }
          }
        }
        """
        let payload = try credits(json)
        XCTAssertEqual(payload.monthlyCredits, 10)
        XCTAssertEqual(payload.purchasedCredits, 0)
        XCTAssertEqual(payload.monthlyCreditsGranted, 10)
        XCTAssertEqual(try XCTUnwrap(payload.fiveHourWindow).percentage, 50, accuracy: 0.0001)
        XCTAssertEqual(
            payload.fiveHourWindow?.resetsAt?.timeIntervalSince1970,
            ISO8601DateFormatter().date(from: "2030-01-01T00:00:00Z")?.timeIntervalSince1970
        )
    }

    func testWindowLimitsNestedUnderCreditsIsAccepted() throws {
        let json = """
        {
          "credits": {
            "monthlyCredits": 8,
            "windowLimits": { "fiveHour": { "cap": 3, "used": 3, "resetAt": 1730000000 } }
          }
        }
        """
        let payload = try credits(json)
        XCTAssertEqual(payload.fiveHourWindow?.percentage, 100)
    }

    func testWindowWithoutPositiveCapIsSkipped() throws {
        let json = """
        {
          "credits": { "monthlyCredits": 8 },
          "windowLimits": { "fiveHour": { "used": 3 }, "weekly": { "cap": 0, "used": 3 } }
        }
        """
        let payload = try credits(json)
        XCTAssertNil(payload.fiveHourWindow)
        XCTAssertNil(payload.weeklyWindow)
    }

    func testUsageOverCapIsClampedTo100() throws {
        let json = """
        { "credits": { "monthlyCredits": 8, "windowLimits": { "weekly": { "cap": 10, "used": 25 } } } }
        """
        XCTAssertEqual(try credits(json).weeklyWindow?.percentage, 100)
    }

    func testMissingCreditsObjectThrows() {
        XCTAssertThrowsError(try credits("{\"windowLimits\":{}}")) { error in
            XCTAssertEqual(error as? CommandCodeParseError, .missingCredits)
        }
    }

    func testMissingMonthlyCreditsThrows() {
        XCTAssertThrowsError(try credits("{\"credits\":{\"purchasedCredits\":1}}")) { error in
            XCTAssertEqual(error as? CommandCodeParseError, .missingMonthlyCredits)
        }
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try credits("not json")) { error in
            XCTAssertEqual(error as? CommandCodeParseError, .invalidJSON)
        }
    }

    // MARK: - Subscriptions

    private func subscription(_ json: String) throws -> CommandCodeSubscriptionPayload? {
        try CommandCodeSubscriptionPayload.parse(from: Data(json.utf8))
    }

    func testParsesActiveSubscription() throws {
        let json = """
        { "success": true, "data": { "planId": "individual-goat", "status": "active", "currentPeriodEnd": 1731000000000 } }
        """
        let payload = try XCTUnwrap(subscription(json))
        XCTAssertEqual(payload.planID, "individual-goat")
        XCTAssertEqual(payload.status, "active")
        XCTAssertEqual(payload.currentPeriodEnd?.timeIntervalSince1970, 1_731_000_000)
    }

    func testNullDataIsFreeTier() throws {
        XCTAssertNil(try subscription("{\"success\":true,\"data\":null}"))
    }

    func testUnsuccessfulResponseIsNil() throws {
        XCTAssertNil(try subscription("{\"success\":false,\"data\":{\"planId\":\"individual-max\"}}"))
    }

    func testMissingPlanIDIsNil() throws {
        XCTAssertNil(try subscription("{\"success\":true,\"data\":{\"status\":\"active\"}}"))
    }

    func testSubscriptionInvalidJSONThrows() {
        XCTAssertThrowsError(try subscription("[]")) { error in
            XCTAssertEqual(error as? CommandCodeParseError, .invalidJSON)
        }
    }

    // MARK: - Assembly

    func testMakePrefersServerGrantOverCatalog() throws {
        let payload = try credits("""
        { "credits": { "monthlyCredits": 20, "monthlyCreditsGranted": 50 } }
        """)
        let sub = try CommandCodeSubscriptionPayload.parse(from: Data("""
        { "success": true, "data": { "planId": "individual-goat", "status": "active" } }
        """.utf8))
        let data = CommandCodeUsageData.make(credits: payload, subscription: sub)

        XCTAssertEqual(data.monthlyCreditsGranted, 50)
        XCTAssertEqual(data.planName, "GOAT")
    }

    func testMakeFallsBackToCatalogGrant() throws {
        let payload = try credits("""
        { "credits": { "monthlyCredits": 35 } }
        """)
        let sub = try CommandCodeSubscriptionPayload.parse(from: Data("""
        { "success": true, "data": { "planId": "individual-goat", "status": "active" } }
        """.utf8))
        let data = CommandCodeUsageData.make(credits: payload, subscription: sub)

        XCTAssertEqual(data.monthlyCreditsGranted, 70)
        XCTAssertEqual(try XCTUnwrap(data.monthlyUsedPercentage), 50, accuracy: 0.0001)
    }

    func testMakeWithoutSubscriptionIsBalanceOnly() throws {
        let payload = try credits("""
        { "credits": { "monthlyCredits": 12.5 } }
        """)
        let data = CommandCodeUsageData.make(credits: payload, subscription: nil)

        XCTAssertEqual(data.monthlyCreditsRemaining, 12.5)
        XCTAssertNil(data.monthlyCreditsGranted)
        XCTAssertNil(data.planName)
        XCTAssertNil(data.monthlyUsedPercentage)
    }

    func testMakeUnknownPlanKeepsRawIDAndNoGrant() throws {
        let payload = try credits("""
        { "credits": { "monthlyCredits": 12.5 } }
        """)
        let sub = try CommandCodeSubscriptionPayload.parse(from: Data("""
        { "success": true, "data": { "planId": "enterprise-custom", "status": "active" } }
        """.utf8))
        let data = CommandCodeUsageData.make(credits: payload, subscription: sub)

        XCTAssertNil(data.monthlyCreditsGranted)
        XCTAssertEqual(data.planName, "enterprise-custom")
        XCTAssertNil(data.monthlyUsedPercentage)
    }
}
