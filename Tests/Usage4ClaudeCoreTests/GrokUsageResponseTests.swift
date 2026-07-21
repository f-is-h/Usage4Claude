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
}

final class ProviderTypeGrokTests: XCTestCase {
    func testProviderTypeIncludesGrok() {
        XCTAssertEqual(ProviderType.grok.displayName, "Grok")
        XCTAssertTrue(ProviderType.allCases.contains(.grok))
    }
}
