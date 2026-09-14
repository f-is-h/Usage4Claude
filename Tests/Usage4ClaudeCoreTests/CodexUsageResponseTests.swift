import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CodexUsageResponse.toCodexUsageData()` — the /backend-api/wham/usage
/// JSON → in-memory transform.
///
/// Specs the production code intends to honor:
/// - Windows are classified as "5-hour" vs "7-day" by actual `limit_window_seconds`
///   duration, NOT by JSON field position (primary_window/secondary_window) — Codex
///   has been observed to put a 7-day window in the `primary_window` slot when the
///   5-hour limit is temporarily disabled.
/// - Missing `limit_window_seconds` conservatively classifies as non-5-hour.
/// - `resetsAt` prefers the absolute `reset_at` epoch; falls back to
///   `now + reset_after_seconds` when `reset_at` is absent.
/// - A window with `used_percent == 0` and no reset info at all is treated as
///   invalid/absent data (nil), not a real 0%.
final class CodexUsageResponseTests: XCTestCase {

    private func decode(_ json: String) throws -> CodexUsageResponse {
        try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
    }

    // MARK: - Window classification by actual duration

    func testClassifiesWindowsByDurationNotFieldPosition() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 40, "limit_window_seconds": 18000, "reset_after_seconds": 3600},
                "secondary_window": {"used_percent": 70, "limit_window_seconds": 604800, "reset_after_seconds": 86400}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()

        XCTAssertEqual(data.primary?.percentage, 40)
        XCTAssertEqual(data.secondary?.percentage, 70)
    }

    func testClassifiesSevenDayWindowAsSecondaryEvenWhenInPrimarySlot() throws {
        // Codex 曾临时取消5小时限制：唯一窗口仍出现在 primary_window 位置，
        // 但 limit_window_seconds 是 604800（7天）——不能按字段名硬映射。
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 55, "limit_window_seconds": 604800, "reset_after_seconds": 86400}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()

        XCTAssertNil(data.primary)
        XCTAssertEqual(data.secondary?.percentage, 55)
    }

    func testMissingLimitWindowSecondsIsConservativelyNonFiveHour() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 30, "reset_after_seconds": 3600}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()

        XCTAssertNil(data.primary)
        XCTAssertEqual(data.secondary?.percentage, 30)
    }

    // MARK: - Reset date resolution

    func testResetAtTakesPriorityOverResetAfterSeconds() throws {
        let epoch = 1_893_456_000
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 10, "limit_window_seconds": 18000, "reset_after_seconds": 99999, "reset_at": \(epoch)}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()

        XCTAssertEqual(data.primary?.resetsAt?.timeIntervalSince1970, TimeInterval(epoch))
    }

    func testFallsBackToResetAfterSecondsWhenResetAtAbsent() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 10, "limit_window_seconds": 18000, "reset_after_seconds": 3600}
            }
        }
        """
        let before = Date()
        let data = try decode(json).toCodexUsageData()
        let after = Date()

        let resetsAt = try XCTUnwrap(data.primary?.resetsAt)
        XCTAssertGreaterThanOrEqual(resetsAt.timeIntervalSince1970, before.addingTimeInterval(3600).timeIntervalSince1970)
        XCTAssertLessThanOrEqual(resetsAt.timeIntervalSince1970, after.addingTimeInterval(3600).timeIntervalSince1970)
    }

    func testResetsAtIsNilWhenNeitherFieldPresent() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 10, "limit_window_seconds": 18000}
            }
        }
        """
        // used_percent 非 0，即使没有重置信息也应视为有效数据（只有 used_percent==0 且无重置信息才判无效）
        let data = try decode(json).toCodexUsageData()
        XCTAssertEqual(data.primary?.percentage, 10)
        XCTAssertNil(data.primary?.resetsAt)
    }

    // MARK: - Zero-usage-with-no-reset-info is treated as invalid data

    func testZeroPercentWithNoResetInfoIsTreatedAsAbsent() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 0, "limit_window_seconds": 18000}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertNil(data.primary)
    }

    func testZeroPercentWithResetInfoIsStillValid() throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {"used_percent": 0, "limit_window_seconds": 18000, "reset_after_seconds": 3600}
            }
        }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertNotNil(data.primary)
        XCTAssertEqual(data.primary?.percentage, 0)
    }

    // MARK: - No rate_limit at all

    func testNoRateLimitProducesNilWindows() throws {
        let data = try decode("{}").toCodexUsageData()
        XCTAssertNil(data.primary)
        XCTAssertNil(data.secondary)
        XCTAssertNil(data.extraUsage)
    }

    // MARK: - Credits balance decoding (String/Double/Int JSON shapes all normalize correctly)

    func testCreditsBalanceDecodesFromJSONString() throws {
        let json = """
        { "credits": {"has_credits": true, "balance": "12.5"} }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertEqual(data.extraUsage?.balance, Decimal(string: "12.5"))
    }

    func testCreditsBalanceDecodesFromJSONNumberWithFraction() throws {
        let json = """
        { "credits": {"has_credits": true, "balance": 12.5} }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertEqual(data.extraUsage?.balance, Decimal(string: "12.5"))
    }

    func testCreditsBalanceDecodesFromJSONWholeNumber() throws {
        let json = """
        { "credits": {"has_credits": true, "balance": 12} }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertEqual(data.extraUsage?.balance, Decimal(12))
    }

    func testExtraUsageCarriesSpendControlAndOverageFlags() throws {
        let json = """
        {
            "credits": {"has_credits": true, "unlimited": false, "overage_limit_reached": true},
            "spend_control": {"reached": true}
        }
        """
        let data = try decode(json).toCodexUsageData()
        XCTAssertEqual(data.extraUsage?.overageLimitReached, true)
        XCTAssertEqual(data.extraUsage?.spendControlReached, true)
    }
}

/// `CodexExtraUsageData.parseBalance` / `.enabled` / `.percentage` — non-`@MainActor`
/// pure logic (the `L.*`-dependent `formatted*` properties live in
/// `CodexUsageData+Formatting.swift` and are out of scope for this SwiftPM target).
final class CodexExtraUsageDataTests: XCTestCase {

    private func makeData(
        hasCredits: Bool = false,
        unlimited: Bool = false,
        overageLimitReached: Bool = false,
        spendControlReached: Bool = false,
        balance: Decimal? = nil,
        visualPercentage: Double? = nil
    ) -> CodexExtraUsageData {
        CodexExtraUsageData(
            hasCredits: hasCredits,
            unlimited: unlimited,
            overageLimitReached: overageLimitReached,
            spendControlReached: spendControlReached,
            balance: balance,
            approxLocalMessages: nil,
            approxCloudMessages: nil,
            visualPercentage: visualPercentage
        )
    }

    // MARK: - parseBalance

    func testParseBalanceValidNumericString() {
        XCTAssertEqual(CodexExtraUsageData.parseBalance("12.34"), Decimal(string: "12.34"))
    }

    func testParseBalanceEmptyStringIsNil() {
        XCTAssertNil(CodexExtraUsageData.parseBalance(""))
    }

    func testParseBalanceNilInputIsNil() {
        XCTAssertNil(CodexExtraUsageData.parseBalance(nil))
    }

    func testParseBalanceIsLocaleInvariant() {
        // en_US_POSIX 强制小数点为 "."，不受系统 locale（如用逗号做小数点的语言环境）影响
        XCTAssertEqual(CodexExtraUsageData.parseBalance("1234.56"), Decimal(string: "1234.56"))
    }

    // MARK: - enabled / percentage

    func testEnabledTrueWhenHasCredits() {
        XCTAssertTrue(makeData(hasCredits: true).enabled)
    }

    func testEnabledTrueWhenPositiveBalance() {
        XCTAssertTrue(makeData(balance: 5).enabled)
    }

    func testDisabledWhenAllFlagsFalseAndNoBalance() {
        XCTAssertFalse(makeData().enabled)
    }

    func testPercentageIs100WhenOverageLimitReached() {
        XCTAssertEqual(makeData(overageLimitReached: true).percentage, 100)
    }

    func testPercentageIs100WhenSpendControlReached() {
        XCTAssertEqual(makeData(spendControlReached: true).percentage, 100)
    }

    func testPercentageIsZeroWhenHasCreditsOrUnlimitedOrPositiveBalance() {
        XCTAssertEqual(makeData(hasCredits: true).percentage, 0)
        XCTAssertEqual(makeData(unlimited: true).percentage, 0)
        XCTAssertEqual(makeData(balance: 1).percentage, 0)
    }

    func testPercentageIsNilWhenDisabled() {
        XCTAssertNil(makeData().percentage)
    }

    func testVisualPercentageOverridesEverything() {
        XCTAssertEqual(makeData(overageLimitReached: true, visualPercentage: 42).percentage, 42)
    }
}
