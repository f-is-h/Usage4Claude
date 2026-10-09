//
//  CommandCodeUsageData.swift
//  Usage4Claude
//
//  In-memory model for Command Code usage, mirroring the role CodexUsageData
//  plays for Codex. Lives here (not Helpers/) so it can be cherry-picked into a
//  SwiftPM test target — every symbol must stay free of L.*/UI dependencies.
//  Display formatting lives in CommandCodeUsageData+Formatting.swift.
//

import Foundation

/// Command Code usage (normalized for the app).
///
/// Command Code exposes the same three shapes the app already renders for the
/// other providers: a rolling 5-hour cap, a rolling weekly cap, and a monthly
/// credit balance. The 5-hour/weekly windows are returned as `used`/`cap` in
/// credit-value units; the monthly credits are a USD balance.
nonisolated struct CommandCodeUsageData: Sendable, Equatable {

    /// A rolling usage window (5-hour or weekly).
    struct Window: Sendable, Equatable {
        /// Used share of the cap (0-100), clamped.
        let percentage: Double
        /// Window reset time, nil when the server did not report one.
        let resetsAt: Date?
    }

    /// Rolling 5-hour window (`windowLimits.fiveHour`).
    let fiveHour: Window?
    /// Rolling weekly window (`windowLimits.weekly`).
    let weekly: Window?
    /// Remaining monthly credits (USD) — the raw `credits.monthlyCredits` value.
    let monthlyCreditsRemaining: Double?
    /// Monthly credit allowance (USD). Prefers the server's `monthlyCreditsGranted`,
    /// falling back to the plan catalog. nil when neither is known (balance-only).
    let monthlyCreditsGranted: Double?
    /// Purchased pay-as-you-go credits (USD).
    let purchasedCredits: Double
    /// Human-readable plan name (e.g. "GOAT"), or the raw plan ID when unrecognized.
    let planName: String?
    /// End of the current billing period, when reported.
    let billingPeriodEnd: Date?

    /// Used share of the monthly credit allowance (0-100), or nil when the grant
    /// is unknown (the credits row then shows a balance-only badge).
    var monthlyUsedPercentage: Double? {
        guard let remaining = monthlyCreditsRemaining,
              let granted = monthlyCreditsGranted,
              granted > 0 else { return nil }
        return min(max((granted - remaining) / granted * 100.0, 0), 100)
    }

    /// Primary limit for menu-bar/compact display (5-hour, else weekly).
    var primaryLimit: Window? { fiveHour ?? weekly }

    /// True when at least one window or the monthly balance is present.
    var hasAnyData: Bool {
        fiveHour != nil || weekly != nil || monthlyCreditsRemaining != nil
    }
}
