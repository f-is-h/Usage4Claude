//
//  GrokUsageResponseTests.swift
//  Usage4ClaudeCoreTests
//

import XCTest
@testable import Usage4ClaudeCore

final class GrokUsageResponseTests: XCTestCase {

    func testCreditsFormatWeeklyPercentFromProductUsage() throws {
        let json = """
        {
          "config": {
            "currentPeriod": {
              "type": "USAGE_PERIOD_TYPE_WEEKLY",
              "start": "2026-07-21T16:51:06.686549+00:00",
              "end": "2026-07-28T16:51:06.686549+00:00"
            },
            "creditUsagePercent": 12.5,
            "onDemandCap": { "val": 0 },
            "onDemandUsed": { "val": 0 },
            "productUsage": [
              { "product": "GrokBuild", "usagePercent": 12.5 }
            ],
            "isUnifiedBillingUser": true,
            "prepaidBalance": { "val": 0 },
            "billingPeriodStart": "2026-07-21T16:51:06.686549+00:00",
            "billingPeriodEnd": "2026-07-28T16:51:06.686549+00:00"
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(json.utf8))
        XCTAssertEqual(credits.weeklyUsagePercent, 12.5)
        let data = GrokUsageDataBuilder.combine(credits: credits, monthly: nil)
        XCTAssertEqual(data.weekly?.percentage, 12.5)
        XCTAssertNotNil(data.weekly?.resetsAt)
    }

    func testMonthlyFormatPercentage() throws {
        let json = """
        {
          "config": {
            "monthlyLimit": { "val": 150000 },
            "used": { "val": 75000 },
            "onDemandCap": { "val": 0 },
            "billingPeriodStart": "2026-07-01T00:00:00+00:00",
            "billingPeriodEnd": "2026-08-01T00:00:00+00:00"
          }
        }
        """
        let monthly = try JSONDecoder().decode(GrokMonthlyBillingResponse.self, from: Data(json.utf8))
        let data = GrokUsageDataBuilder.combine(credits: nil, monthly: monthly)
        XCTAssertEqual(data.monthly?.percentage ?? -1, 50, accuracy: 0.01)
        XCTAssertEqual(data.monthly?.used, 75000)
        XCTAssertEqual(data.monthly?.limit, 150000)
        XCTAssertNotNil(data.monthly?.resetsAt)
    }

    func testCombineBothPayloads() throws {
        let creditsJSON = """
        {
          "config": {
            "currentPeriod": {
              "type": "USAGE_PERIOD_TYPE_WEEKLY",
              "start": "2026-07-21T00:00:00+00:00",
              "end": "2026-07-28T00:00:00+00:00"
            },
            "creditUsagePercent": 2.0,
            "productUsage": [{ "product": "GrokBuild", "usagePercent": 2.0 }],
            "isUnifiedBillingUser": true,
            "prepaidBalance": { "val": 10 }
          }
        }
        """
        let monthlyJSON = """
        {
          "config": {
            "monthlyLimit": { "val": 100 },
            "used": { "val": 25 },
            "billingPeriodEnd": "2026-08-01T00:00:00+00:00"
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(creditsJSON.utf8))
        let monthly = try JSONDecoder().decode(GrokMonthlyBillingResponse.self, from: Data(monthlyJSON.utf8))
        let data = GrokUsageDataBuilder.combine(credits: credits, monthly: monthly)
        XCTAssertEqual(data.weekly?.percentage, 2.0)
        XCTAssertEqual(data.monthly?.percentage ?? -1, 25, accuracy: 0.01)
        XCTAssertTrue(data.credits?.enabled == true)
        XCTAssertEqual(data.credits?.prepaidBalance, 10)
    }

    func testValNumberAcceptsIntAndString() throws {
        let json = """
        {
          "config": {
            "monthlyLimit": { "val": "200" },
            "used": { "val": 50 }
          }
        }
        """
        let monthly = try JSONDecoder().decode(GrokMonthlyBillingResponse.self, from: Data(json.utf8))
        XCTAssertEqual(monthly.config?.monthlyLimit?.val, 200)
        XCTAssertEqual(monthly.config?.used?.val, 50)
    }

    func testEmptyPayloadYieldsEmptyUsage() {
        let data = GrokUsageDataBuilder.combine(credits: nil, monthly: nil)
        XCTAssertNil(data.weekly)
        XCTAssertNil(data.monthly)
        XCTAssertNil(data.credits)
    }

    func testWeeklyFallsBackToCreditUsagePercentWhenProductUsageMissing() throws {
        let json = """
        {
          "config": {
            "currentPeriod": {
              "type": "USAGE_PERIOD_TYPE_WEEKLY",
              "start": "2026-07-21T00:00:00+00:00",
              "end": "2026-07-28T00:00:00+00:00"
            },
            "creditUsagePercent": 33.0,
            "isUnifiedBillingUser": true
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(json.utf8))
        XCTAssertEqual(credits.weeklyUsagePercent, 33.0)
        let data = GrokUsageDataBuilder.combine(credits: credits, monthly: nil)
        XCTAssertEqual(data.weekly?.percentage, 33.0)
    }

    func testWeeklyPrefersGrokProductOverOtherProducts() throws {
        let json = """
        {
          "config": {
            "creditUsagePercent": 99.0,
            "productUsage": [
              { "product": "Other", "usagePercent": 50.0 },
              { "product": "GrokBuild", "usagePercent": 7.0 }
            ],
            "currentPeriod": {
              "end": "2026-07-28T00:00:00+00:00"
            }
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(json.utf8))
        XCTAssertEqual(credits.weeklyUsagePercent, 7.0)
    }

    func testZeroPercentWithoutEndDateIsNilWeekly() throws {
        let json = """
        {
          "config": {
            "creditUsagePercent": 0,
            "productUsage": [{ "product": "GrokBuild", "usagePercent": 0 }]
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(json.utf8))
        let data = GrokUsageDataBuilder.combine(credits: credits, monthly: nil)
        XCTAssertNil(data.weekly)
    }

    func testMonthlyMissingLimitOrUsedIsNil() throws {
        let noLimit = """
        { "config": { "used": { "val": 10 } } }
        """
        let noUsed = """
        { "config": { "monthlyLimit": { "val": 100 } } }
        """
        let zeroLimit = """
        { "config": { "monthlyLimit": { "val": 0 }, "used": { "val": 1 } } }
        """
        for json in [noLimit, noUsed, zeroLimit] {
            let monthly = try JSONDecoder().decode(GrokMonthlyBillingResponse.self, from: Data(json.utf8))
            let data = GrokUsageDataBuilder.combine(credits: nil, monthly: monthly)
            XCTAssertNil(data.monthly, "expected nil monthly for \(json)")
        }
    }

    func testClampsWeeklyPercentageToZeroHundred() throws {
        let json = """
        {
          "config": {
            "creditUsagePercent": 150,
            "currentPeriod": { "end": "2026-07-28T00:00:00+00:00" }
          }
        }
        """
        let credits = try JSONDecoder().decode(GrokCreditsBillingResponse.self, from: Data(json.utf8))
        let data = GrokUsageDataBuilder.combine(credits: credits, monthly: nil)
        XCTAssertEqual(data.weekly?.percentage, 100)
    }

    func testDateParserAcceptsFractionalAndNonFractionalISO8601() {
        let withFrac = GrokUsageDataBuilder.parseDate("2026-07-28T16:51:06.686549+00:00")
        let withoutFrac = GrokUsageDataBuilder.parseDate("2026-07-28T16:51:06+00:00")
        XCTAssertNotNil(withFrac)
        XCTAssertNotNil(withoutFrac)
        XCTAssertNil(GrokUsageDataBuilder.parseDate(nil))
        XCTAssertNil(GrokUsageDataBuilder.parseDate(""))
    }
}

final class GrokCreditsDataTests: XCTestCase {
    func testEnabledWhenPrepaidBalancePositive() {
        let c = GrokCreditsData(
            prepaidBalance: 5,
            onDemandCap: 0,
            onDemandUsed: 0,
            creditUsagePercent: nil,
            isUnifiedBillingUser: false
        )
        XCTAssertTrue(c.enabled)
        XCTAssertEqual(c.percentage, 0)
    }

    func testPercentageFromOnDemandUsedOverCap() {
        let c = GrokCreditsData(
            prepaidBalance: 0,
            onDemandCap: 100,
            onDemandUsed: 40,
            creditUsagePercent: nil,
            isUnifiedBillingUser: false
        )
        XCTAssertTrue(c.enabled)
        XCTAssertEqual(c.percentage ?? -1, 40, accuracy: 0.01)
    }

    func testCreditUsagePercentTakesPriority() {
        let c = GrokCreditsData(
            prepaidBalance: 0,
            onDemandCap: 100,
            onDemandUsed: 40,
            creditUsagePercent: 12,
            isUnifiedBillingUser: true
        )
        XCTAssertEqual(c.percentage, 12)
    }

    func testDisabledWhenAllZero() {
        let c = GrokCreditsData(
            prepaidBalance: 0,
            onDemandCap: 0,
            onDemandUsed: 0,
            creditUsagePercent: nil,
            isUnifiedBillingUser: false
        )
        XCTAssertFalse(c.enabled)
        XCTAssertNil(c.percentage)
    }
}

final class ProviderTypeGrokTests: XCTestCase {
    func testProviderTypeIncludesGrok() {
        XCTAssertEqual(ProviderType.grok.displayName, "Grok")
        XCTAssertTrue(ProviderType.allCases.contains(.grok))
    }
}
