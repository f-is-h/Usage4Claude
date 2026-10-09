//
//  CommandCodeAPIResponseModels.swift
//  Usage4Claude
//
//  Wire models + defensive parsing for the Command Code billing endpoints:
//    GET https://api.commandcode.ai/internal/billing/credits
//    GET https://api.commandcode.ai/internal/billing/subscriptions
//
//  These endpoints are UNDOCUMENTED and community-reverse-engineered, so all
//  parsing is defensive: field names accept camelCase and snake_case variants,
//  numbers accept JSON numbers or numeric strings, and timestamps accept epoch
//  seconds/milliseconds or ISO-8601 strings. Unknown shapes degrade gracefully
//  rather than failing the whole fetch.
//
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — every symbol must stay free of L.*/Logger/UI dependencies.
//

import Foundation

/// Errors from parsing Command Code billing responses. Kept self-contained so
/// this file compiles in the SwiftPM test target; the service layer maps these
/// to `UsageError` for the shared backoff/refresh pipeline.
nonisolated enum CommandCodeParseError: Error, Equatable {
    /// The response body was not a JSON object.
    case invalidJSON
    /// The credits response carried no `credits` object.
    case missingCredits
    /// The credits response carried no `monthlyCredits` value.
    case missingMonthlyCredits
}

// MARK: - Credits

/// Parsed `/internal/billing/credits` payload.
nonisolated struct CommandCodeCreditsPayload: Sendable, Equatable {
    /// Remaining monthly credits (USD).
    let monthlyCredits: Double
    /// Purchased pay-as-you-go credits (USD).
    let purchasedCredits: Double
    /// Monthly allowance (USD) when the server reports it explicitly.
    let monthlyCreditsGranted: Double?
    /// Rolling 5-hour window, nil when absent or without a cap.
    let fiveHourWindow: CommandCodeUsageData.Window?
    /// Rolling weekly window, nil when absent or without a cap.
    let weeklyWindow: CommandCodeUsageData.Window?

    /// Accepted key names for the 5-hour window object.
    static let fiveHourWindowNames = ["fiveHour", "five_hour", "rolling5h", "5h"]
    /// Accepted key names for the weekly window object.
    static let weeklyWindowNames = ["weekly", "week"]

    static func parse(from data: Data) throws -> CommandCodeCreditsPayload {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CommandCodeParseError.invalidJSON
        }
        // Some deployments wrap the payload in a `data` envelope.
        let envelope = root["data"] as? [String: Any]
        guard let credits = (root["credits"] as? [String: Any])
            ?? (envelope?["credits"] as? [String: Any]) else {
            throw CommandCodeParseError.missingCredits
        }
        guard let monthly = CommandCodeJSON.double(credits["monthlyCredits"] ?? credits["monthly_credits"]) else {
            throw CommandCodeParseError.missingMonthlyCredits
        }
        let windowLimits = (root["windowLimits"] as? [String: Any])
            ?? (credits["windowLimits"] as? [String: Any])
            ?? (envelope?["windowLimits"] as? [String: Any])

        return CommandCodeCreditsPayload(
            monthlyCredits: monthly,
            purchasedCredits: CommandCodeJSON.double(credits["purchasedCredits"] ?? credits["purchased_credits"]) ?? 0,
            monthlyCreditsGranted: CommandCodeJSON.double(credits["monthlyCreditsGranted"] ?? credits["monthly_credits_granted"]),
            fiveHourWindow: window(from: windowLimits, names: fiveHourWindowNames),
            weeklyWindow: window(from: windowLimits, names: weeklyWindowNames)
        )
    }

    /// Resolve a named window object into a `CommandCodeUsageData.Window`.
    /// A window without a positive cap has no meaningful percentage and is skipped.
    static func window(from windowLimits: [String: Any]?, names: [String]) -> CommandCodeUsageData.Window? {
        guard let windowLimits else { return nil }
        for name in names {
            guard let raw = windowLimits[name] as? [String: Any] else { continue }
            guard let cap = CommandCodeJSON.double(raw["cap"] ?? raw["limit"] ?? raw["capCredits"] ?? raw["cap_credits"]),
                  cap > 0 else {
                continue
            }
            let used = CommandCodeJSON.double(raw["used"] ?? raw["usage"] ?? raw["usedCredits"] ?? raw["used_credits"]) ?? 0
            let resetsAt = CommandCodeJSON.date(raw["resetAt"] ?? raw["reset_at"] ?? raw["resetsAt"] ?? raw["resets_at"])
            let percentage = min(max(used / cap * 100.0, 0), 100)
            return CommandCodeUsageData.Window(percentage: percentage, resetsAt: resetsAt)
        }
        return nil
    }
}

// MARK: - Subscriptions

/// Parsed `/internal/billing/subscriptions` payload.
nonisolated struct CommandCodeSubscriptionPayload: Sendable, Equatable {
    /// Upstream plan ID (e.g. "individual-goat").
    let planID: String
    /// Subscription status (e.g. "active"), or "unknown".
    let status: String
    /// End of the current billing period, when reported.
    let currentPeriodEnd: Date?

    /// Parse the subscriptions response.
    /// - Returns: the subscription, or nil for the free tier / any shape the
    ///   parser cannot use (the service treats this as optional enrichment).
    /// - Throws: only on a body that is not a JSON object.
    static func parse(from data: Data) throws -> CommandCodeSubscriptionPayload? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CommandCodeParseError.invalidJSON
        }
        if let success = root["success"] as? Bool, success == false {
            return nil
        }
        guard let dataValue = root["data"] ?? root["subscription"] else { return nil }
        if dataValue is NSNull { return nil }
        guard let dict = dataValue as? [String: Any] else { return nil }
        guard let planID = (dict["planId"] as? String) ?? (dict["plan_id"] as? String), !planID.isEmpty else {
            return nil
        }
        let status = (dict["status"] as? String) ?? "unknown"
        let periodEnd = CommandCodeJSON.date(dict["currentPeriodEnd"] ?? dict["current_period_end"])
        return CommandCodeSubscriptionPayload(planID: planID, status: status, currentPeriodEnd: periodEnd)
    }
}

// MARK: - Assembly

extension CommandCodeUsageData {
    /// Combine the two payloads into the in-memory model. The subscription is
    /// optional; when it is missing or its plan is unknown, the monthly grant
    /// falls back to the plan catalog and finally to nil (balance-only row).
    static func make(
        credits: CommandCodeCreditsPayload,
        subscription: CommandCodeSubscriptionPayload?
    ) -> CommandCodeUsageData {
        let plan = subscription.flatMap { CommandCodePlanCatalog.plan(forID: $0.planID) }
        let grant = credits.monthlyCreditsGranted ?? plan?.monthlyCreditsUSD
        let planName = plan?.displayName ?? subscription?.planID
        return CommandCodeUsageData(
            fiveHour: credits.fiveHourWindow,
            weekly: credits.weeklyWindow,
            monthlyCreditsRemaining: credits.monthlyCredits,
            monthlyCreditsGranted: grant,
            purchasedCredits: credits.purchasedCredits,
            planName: planName,
            billingPeriodEnd: subscription?.currentPeriodEnd
        )
    }
}

// MARK: - Value coercion

/// Lenient coercion helpers shared by the parsers above.
nonisolated enum CommandCodeJSON {

    /// Coerce a JSON value to a finite Double, accepting numbers and numeric strings.
    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            let d = number.doubleValue
            return d.isFinite ? d : nil
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let d = Double(trimmed), d.isFinite else { return nil }
            return d
        default:
            return nil
        }
    }

    /// Coerce a JSON value to a Date, accepting epoch seconds/milliseconds
    /// (numeric or numeric string) or ISO-8601 strings.
    static func date(_ value: Any?) -> Date? {
        if let timestamp = double(value), timestamp > 0 {
            // Values past ~year 2286 in seconds are assumed to be milliseconds.
            let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
            return Date(timeIntervalSince1970: seconds)
        }
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }
}
