//
//  CodexUsageData+Formatting.swift
//  Usage4Claude
//
//  Locale-aware display formatting for `CodexExtraUsageData`. Lives outside
//  `Models/CodexUsageData.swift` because it depends on `L.*` — main-app-only —
//  and that file is shared with a SwiftPM test target.
//

import Foundation

extension CodexExtraUsageData {
    @MainActor var formattedCompactAmount: String {
        if unlimited {
            return L.ExtraUsage.unlimited
        }
        if overageLimitReached || spendControlReached {
            return L.ExtraUsage.limitReached
        }
        guard enabled, let balanceValue else {
            return L.ExtraUsage.notEnabled
        }
        return L.ExtraUsage.creditsBalance(balanceValue)
    }

    @MainActor var formattedRemainingAmount: String {
        guard let balanceValue else {
            return formattedCompactAmount
        }
        return L.ExtraUsage.creditsRemaining(balanceValue)
    }

    @MainActor var formattedDetailCompactAmount: String {
        if unlimited {
            return L.ExtraUsage.unlimited
        }
        if overageLimitReached || spendControlReached {
            return L.ExtraUsage.limitReached
        }
        guard enabled, let balanceValue else {
            return L.ExtraUsage.notEnabled
        }
        return L.DetailRow.creditsBalance(balanceValue)
    }

    @MainActor var formattedDetailRemainingAmount: String {
        guard let balanceValue else {
            return formattedDetailCompactAmount
        }
        return L.DetailRow.creditsRemaining(balanceValue)
    }
}
