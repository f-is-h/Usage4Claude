//
//  CommandCodeUsageData+Formatting.swift
//  Usage4Claude
//
//  Bridges Command Code's rolling windows into `UsageData.LimitData` so the
//  shared reset-time / compact formatting can be reused, plus small helpers for
//  the credit balance badge.
//

import Foundation

extension CommandCodeUsageData.Window {
    /// Reuse Claude's reset/countdown formatting by viewing a Command Code
    /// window as a `UsageData.LimitData`.
    func asUsageLimitData() -> UsageData.LimitData {
        UsageData.LimitData(percentage: percentage, resetsAt: resetsAt)
    }
}

extension CommandCodeUsageData {
    /// Compact text for the credits badge: whole dollars, one decimal it is under $1 and not zero.
    var creditsBadgeText: String? {
        guard let remaining = monthlyCreditsRemaining else { return nil }
        return Self.creditsBadgeText(remaining)
    }

    static func creditsBadgeText(_ remaining: Double) -> String {
        if remaining <= 0 { return "$0" }
        if remaining < 1 { return String(format: "$%.1f", remaining) }
        return "$" + String(Int(remaining.rounded()))
    }

    /// Detailed credits line, e.g. "$42.50 left of $70".
    var formattedMonthlyRemaining: String {
        guard let remaining = monthlyCreditsRemaining else { return "-" }
        if let granted = monthlyCreditsGranted {
            return String(format: "$%.2f / $%.0f", remaining, granted)
        }
        return String(format: "$%.2f", remaining)
    }
}
