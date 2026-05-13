import XCTest
@testable import Usage4ClaudeCore

/// Tests for `ExtraUsageResponse.toExtraUsageData()` — the JSON → in-memory
/// transform that backs the /api/organizations/<id>/overage_spend_limit fetch.
///
/// Specs the production code intends to honor:
/// - Prefer the new `monthly_limit` field; fall back to `monthly_credit_limit`,
///   then to legacy `spend_limit_amount_cents` when older fields are absent.
/// - Prefer `used_credits` (a Double, since the API may return floats like
///   `21.0`); fall back to legacy `balance_cents` (Int).
/// - Cents → dollars conversion (divide by 100).
/// - Currency is always uppercased; defaults to "USD" when absent everywhere.
/// - is_enabled=false short-circuits to a disabled struct (no used/limit).
/// - When is_enabled is missing, fall back to "limit > 0" as the implicit signal.
final class ExtraUsageResponseTests: XCTestCase {

    // MARK: - Decode helper

    private func decode(_ json: String) throws -> ExtraUsageResponse {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(ExtraUsageResponse.self, from: data)
    }

    // MARK: - Happy path: new fields

    func testNewFieldsParseEnabledWithCentsToDollars() throws {
        let json = """
        {
            "limit_type": "organization",
            "is_enabled": true,
            "monthly_limit": 5000,
            "currency": "usd",
            "used_credits": 1250.0,
            "out_of_credits": false
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertNotNil(extra)
        XCTAssertEqual(extra?.enabled, true)
        XCTAssertEqual(extra?.used, 12.50)
        XCTAssertEqual(extra?.limit, 50.00)
        XCTAssertEqual(extra?.currency, "USD", "currency should be uppercased")
    }

    func testNewFieldsParseEnabledWithEUR() throws {
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 10000,
            "currency": "eur",
            "used_credits": 0.0
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertEqual(extra?.enabled, true)
        XCTAssertEqual(extra?.limit, 100.00)
        XCTAssertEqual(extra?.used, 0.00)
        XCTAssertEqual(extra?.currency, "EUR")
    }

    func testFractionalCentsInUsedCredits() throws {
        // The API returns used_credits as a Double — it can include fractional
        // cents (e.g. 21.5 cents). Make sure we don't lose precision.
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 5000,
            "currency": "USD",
            "used_credits": 1234.5
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.used, 12.345)
    }

    // MARK: - is_enabled=false short-circuit

    func testIsEnabledFalseReturnsDisabledRegardlessOfLimit() throws {
        // Even when monthly_limit is positive, is_enabled=false wins.
        let json = """
        {
            "is_enabled": false,
            "monthly_limit": 5000,
            "currency": "USD",
            "used_credits": 0.0
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertEqual(extra?.enabled, false)
        XCTAssertNil(extra?.used)
        XCTAssertNil(extra?.limit)
        XCTAssertEqual(extra?.currency, "USD")
    }

    // MARK: - monthly_credit_limit fallback (older API)

    func testMonthlyCreditLimitFallback() throws {
        // Older response shape used `monthly_credit_limit` instead of
        // `monthly_limit`. Fallback chain: monthly_limit → monthly_credit_limit
        // → spend_limit_amount_cents.
        let json = """
        {
            "is_enabled": true,
            "monthly_credit_limit": 2500,
            "currency": "USD",
            "used_credits": 750.0
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertEqual(extra?.enabled, true)
        XCTAssertEqual(extra?.limit, 25.00)
        XCTAssertEqual(extra?.used, 7.50)
    }

    // MARK: - Legacy field fallback

    func testLegacyFieldsParseWhenNewFieldsAbsent() throws {
        // Old API shape: spend_limit_amount_cents + balance_cents +
        // spend_limit_currency, with no is_enabled / monthly_limit.
        let json = """
        {
            "type": "organization",
            "spend_limit_currency": "usd",
            "spend_limit_amount_cents": 2500,
            "balance_cents": 750
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertEqual(extra?.enabled, true,
                       "limit > 0 should imply enabled when is_enabled is absent")
        XCTAssertEqual(extra?.used, 7.50)
        XCTAssertEqual(extra?.limit, 25.00)
        XCTAssertEqual(extra?.currency, "USD")
    }

    func testLegacyFieldsZeroLimitReturnsDisabled() throws {
        // Legacy zero-limit means feature isn't on for this org.
        let json = """
        {
            "spend_limit_amount_cents": 0,
            "balance_cents": 0,
            "spend_limit_currency": "USD"
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.enabled, false)
        XCTAssertNil(extra?.limit)
        XCTAssertNil(extra?.used)
    }

    // MARK: - New fields take precedence over legacy fields

    func testNewFieldsPreferredOverLegacyWhenBothPresent() throws {
        // If a backwards-compat response includes both, the new fields win.
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 5000,
            "currency": "USD",
            "used_credits": 1000.0,
            "spend_limit_amount_cents": 9999,
            "balance_cents": 9999,
            "spend_limit_currency": "EUR"
        }
        """
        let extra = try decode(json).toExtraUsageData()

        XCTAssertEqual(extra?.limit, 50.00,
                       "monthly_limit (5000c) should win over legacy (9999c)")
        XCTAssertEqual(extra?.used, 10.00)
        XCTAssertEqual(extra?.currency, "USD",
                       "currency (USD) should win over spend_limit_currency (EUR)")
    }

    // MARK: - Currency defaulting

    func testMissingCurrencyEverywhereDefaultsToUSD() throws {
        let json = """
        {
            "is_enabled": false
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.currency, "USD")
    }

    // MARK: - Implicit enabled signal

    func testMissingIsEnabledWithPositiveLimitIsEnabled() throws {
        // No is_enabled, but monthly_limit > 0 → infer enabled.
        let json = """
        {
            "monthly_limit": 1000,
            "currency": "USD",
            "used_credits": 250.0
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.enabled, true)
        XCTAssertEqual(extra?.limit, 10.00)
        XCTAssertEqual(extra?.used, 2.50)
    }

    func testMissingIsEnabledWithNoLimitIsDisabled() throws {
        // No is_enabled, no limit anywhere → disabled.
        let json = """
        {
            "currency": "USD"
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.enabled, false)
    }

    // MARK: - used_credits missing → defaults to 0

    func testEnabledWithMissingUsedCreditsDefaultsToZero() throws {
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 5000,
            "currency": "USD"
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.enabled, true)
        XCTAssertEqual(extra?.used, 0.00)
        XCTAssertEqual(extra?.limit, 50.00)
    }

    // MARK: - percentage derived property

    func testPercentageComputedCorrectly() throws {
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 4000,
            "currency": "USD",
            "used_credits": 1000.0
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertEqual(extra?.percentage, 25.0)
    }

    func testPercentageNilWhenDisabled() throws {
        let json = """
        {
            "is_enabled": false
        }
        """
        let extra = try decode(json).toExtraUsageData()
        XCTAssertNil(extra?.percentage)
    }

    // MARK: - currencySymbol mapping

    func testCurrencySymbolForCommonCurrencies() {
        let cases: [(code: String, symbol: String)] = [
            ("USD", "$"),
            ("EUR", "€"),
            ("GBP", "£"),
            ("JPY", "¥"),
            ("CAD", "CA$"),
            ("AUD", "A$"),
            ("BRL", "R$"),
            ("INR", "₹")
        ]
        for c in cases {
            let extra = ExtraUsageData(enabled: true, used: 0, limit: 100, currency: c.code)
            XCTAssertEqual(extra.currencySymbol, c.symbol, "expected \(c.symbol) for \(c.code)")
        }
    }

    func testCurrencySymbolFallsBackToCodeForUnknown() {
        let extra = ExtraUsageData(enabled: true, used: 0, limit: 100, currency: "ZZZ")
        XCTAssertEqual(extra.currencySymbol, "ZZZ",
                       "unknown currency code should fall back to the raw code")
    }
}
