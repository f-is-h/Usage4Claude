//
//  GrokUsageData.swift
//  Usage4Claude
//
//  Pure-data types + parsing for Grok Build billing/usage responses from
//  https://cli-chat-proxy.grok.com/v1/billing (?format=credits for weekly
//  subscription quota; default form for monthly included allowance).
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — every symbol here must stay free of `L.*`/`Logger`/UI dependency.
//

import Foundation

// MARK: - Internal data model

/// Grok Build / SuperGrok usage (app-normalized structure)
struct GrokUsageData: Sendable {
    /// Weekly subscription usage window (primary ring)
    let weekly: LimitData?
    /// Monthly included allowance window (secondary ring)
    let monthly: LimitData?
    /// Prepaid / on-demand credits residual info
    let credits: GrokCreditsData?

    struct LimitData: Sendable {
        /// Used percentage 0–100
        let percentage: Double
        /// Reset / period end; nil if unknown
        let resetsAt: Date?
        /// Optional absolute used amount (monthly form)
        let used: Double?
        /// Optional absolute limit amount (monthly form)
        let limit: Double?
    }
}

/// Prepaid / on-demand credit residual for Grok
nonisolated struct GrokCreditsData: Sendable {
    let prepaidBalance: Double?
    let onDemandCap: Double?
    let onDemandUsed: Double?
    let creditUsagePercent: Double?
    let isUnifiedBillingUser: Bool

    var enabled: Bool {
        if let p = prepaidBalance, p > 0 { return true }
        if let cap = onDemandCap, cap > 0 { return true }
        if let used = onDemandUsed, used > 0 { return true }
        if let pct = creditUsagePercent, pct > 0 { return true }
        return isUnifiedBillingUser && (creditUsagePercent != nil)
    }

    /// Visual fill for the "extra/credits" hexagon — prefer explicit percent,
    /// else on-demand used/cap ratio, else 0 when prepaid remains.
    var percentage: Double? {
        if let pct = creditUsagePercent {
            return min(100, max(0, pct))
        }
        if let cap = onDemandCap, cap > 0, let used = onDemandUsed {
            return min(100, max(0, used / cap * 100))
        }
        if let balance = prepaidBalance, balance > 0 {
            return 0
        }
        return nil
    }
}

// MARK: - API response models

/// Credits-format response: `GET .../billing?format=credits`
nonisolated struct GrokCreditsBillingResponse: Codable, Sendable {
    let config: Config?

    struct Config: Codable, Sendable {
        let currentPeriod: Period?
        let creditUsagePercent: Double?
        let onDemandCap: ValNumber?
        let onDemandUsed: ValNumber?
        let productUsage: [ProductUsage]?
        let isUnifiedBillingUser: Bool?
        let prepaidBalance: ValNumber?
        let billingPeriodStart: String?
        let billingPeriodEnd: String?
        let topUpMethod: String?
    }

    struct Period: Codable, Sendable {
        let type: String?
        let start: String?
        let end: String?
    }

    struct ProductUsage: Codable, Sendable {
        let product: String?
        let usagePercent: Double?
    }

    struct ValNumber: Codable, Sendable {
        let val: Double?

        init(val: Double?) { self.val = val }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? container.decodeIfPresent(Double.self, forKey: .val) {
                val = d
            } else if let i = try? container.decodeIfPresent(Int.self, forKey: .val) {
                val = Double(i)
            } else if let s = try? container.decodeIfPresent(String.self, forKey: .val),
                      let d = Double(s) {
                val = d
            } else {
                val = nil
            }
        }

        private enum CodingKeys: String, CodingKey { case val }
    }

    /// Weekly usage percent: prefer productUsage for GrokBuild, fall back to creditUsagePercent.
    var weeklyUsagePercent: Double? {
        if let product = config?.productUsage?.first(where: {
            ($0.product ?? "").localizedCaseInsensitiveContains("grok")
        })?.usagePercent {
            return product
        }
        if let first = config?.productUsage?.first?.usagePercent {
            return first
        }
        return config?.creditUsagePercent
    }

    func weeklyLimitData(using parser: ISO8601DateFormatter) -> GrokUsageData.LimitData? {
        guard let pct = weeklyUsagePercent else { return nil }
        let end = config?.currentPeriod?.end.flatMap { parser.date(from: $0) }
            ?? config?.billingPeriodEnd.flatMap { parser.date(from: $0) }
        // Treat 0% with no end date as "no data yet"
        if pct == 0 && end == nil { return nil }
        return .init(percentage: min(100, max(0, pct)), resetsAt: end, used: nil, limit: nil)
    }

    func creditsData() -> GrokCreditsData? {
        guard let config else { return nil }
        let data = GrokCreditsData(
            prepaidBalance: config.prepaidBalance?.val,
            onDemandCap: config.onDemandCap?.val,
            onDemandUsed: config.onDemandUsed?.val,
            creditUsagePercent: config.creditUsagePercent,
            isUnifiedBillingUser: config.isUnifiedBillingUser ?? false
        )
        return data.enabled || data.percentage != nil ? data : nil
    }
}

/// Monthly/default response: `GET .../billing` (no format=credits)
nonisolated struct GrokMonthlyBillingResponse: Codable, Sendable {
    let config: Config?

    struct Config: Codable, Sendable {
        let monthlyLimit: ValNumber?
        let used: ValNumber?
        let onDemandCap: ValNumber?
        let billingPeriodStart: String?
        let billingPeriodEnd: String?
        let history: [HistoryEntry]?
    }

    struct HistoryEntry: Codable, Sendable {
        let billingCycle: BillingCycle?
        let includedUsed: ValNumber?
        let onDemandUsed: ValNumber?
        let totalUsed: ValNumber?
    }

    struct BillingCycle: Codable, Sendable {
        let year: Int?
        let month: Int?
    }

    struct ValNumber: Codable, Sendable {
        let val: Double?

        init(val: Double?) { self.val = val }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? container.decodeIfPresent(Double.self, forKey: .val) {
                val = d
            } else if let i = try? container.decodeIfPresent(Int.self, forKey: .val) {
                val = Double(i)
            } else if let s = try? container.decodeIfPresent(String.self, forKey: .val),
                      let d = Double(s) {
                val = d
            } else {
                val = nil
            }
        }

        private enum CodingKeys: String, CodingKey { case val }
    }

    func monthlyLimitData(using parser: ISO8601DateFormatter) -> GrokUsageData.LimitData? {
        guard let limit = config?.monthlyLimit?.val, limit > 0,
              let used = config?.used?.val else { return nil }
        let pct = min(100, max(0, used / limit * 100))
        let end = config?.billingPeriodEnd.flatMap { parser.date(from: $0) }
        return .init(percentage: pct, resetsAt: end, used: used, limit: limit)
    }
}

// MARK: - Merge helper

enum GrokUsageDataBuilder {
    static func makeISO8601Parser() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    static func makeISO8601ParserNoFraction() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    static func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let d = makeISO8601Parser().date(from: string) { return d }
        return makeISO8601ParserNoFraction().date(from: string)
    }

    /// Combine credits + monthly billing payloads into one `GrokUsageData`.
    static func combine(
        credits: GrokCreditsBillingResponse?,
        monthly: GrokMonthlyBillingResponse?
    ) -> GrokUsageData {
        let frac = makeISO8601Parser()
        let noFrac = makeISO8601ParserNoFraction()

        func weeklyFromCredits(_ c: GrokCreditsBillingResponse) -> GrokUsageData.LimitData? {
            guard let pct = c.weeklyUsagePercent else { return nil }
            let endStr = c.config?.currentPeriod?.end ?? c.config?.billingPeriodEnd
            let end = endStr.flatMap { frac.date(from: $0) ?? noFrac.date(from: $0) }
            if pct == 0 && end == nil { return nil }
            return .init(percentage: min(100, max(0, pct)), resetsAt: end, used: nil, limit: nil)
        }

        func monthlyFrom(_ m: GrokMonthlyBillingResponse) -> GrokUsageData.LimitData? {
            guard let limit = m.config?.monthlyLimit?.val, limit > 0,
                  let used = m.config?.used?.val else { return nil }
            let pct = min(100, max(0, used / limit * 100))
            let endStr = m.config?.billingPeriodEnd
            let end = endStr.flatMap { frac.date(from: $0) ?? noFrac.date(from: $0) }
            return .init(percentage: pct, resetsAt: end, used: used, limit: limit)
        }

        return GrokUsageData(
            weekly: credits.flatMap(weeklyFromCredits),
            monthly: monthly.flatMap(monthlyFrom),
            credits: credits?.creditsData()
        )
    }
}

// MARK: - Formatting bridge

extension GrokUsageData.LimitData {
    /// Convert to Claude-shaped LimitData for shared countdown formatters
    func asUsageLimitData() -> UsageData.LimitData {
        UsageData.LimitData(percentage: percentage, resetsAt: resetsAt)
    }
}
