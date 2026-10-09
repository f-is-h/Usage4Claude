//
//  CommandCodePlanCatalog.swift
//  Usage4Claude
//
//  Static catalog of Command Code subscription plan IDs → monthly credit
//  allowance (in USD). Lives here (not Helpers/) so it can be cherry-picked into
//  a SwiftPM test target — every symbol must stay free of L.*/UI dependencies.
//
//  The /internal/billing/credits endpoint returns the *remaining* monthly
//  credits, not the plan total. The total is published on the public pricing
//  page (https://commandcode.ai/pricing) and is keyed by the `planId` returned
//  from /internal/billing/subscriptions. When the credits response carries an
//  explicit `monthlyCreditsGranted`, that value wins over this catalog.
//

import Foundation

nonisolated enum CommandCodePlanCatalog {

    struct Plan: Sendable, Equatable {
        /// Upstream plan ID (e.g. "individual-goat").
        let id: String
        /// Human-readable name (e.g. "GOAT").
        let displayName: String
        /// Monthly credit allowance in USD.
        let monthlyCreditsUSD: Double
    }

    /// Known plans, newest pricing page. Order is irrelevant for lookup; the
    /// resolver prefers an exact match and falls back to the longest prefix so
    /// variant IDs (e.g. a future "individual-pro-v2") still resolve sensibly.
    static let plans: [Plan] = [
        Plan(id: "individual-go", displayName: "Go", monthlyCreditsUSD: 10),
        Plan(id: "individual-goat", displayName: "GOAT", monthlyCreditsUSD: 70),
        Plan(id: "individual-pro", displayName: "Pro", monthlyCreditsUSD: 30),
        Plan(id: "individual-pro-v1", displayName: "Pro", monthlyCreditsUSD: 80),
        Plan(id: "individual-provider", displayName: "Provider", monthlyCreditsUSD: 15),
        Plan(id: "individual-max", displayName: "Max", monthlyCreditsUSD: 150),
        Plan(id: "individual-ultra", displayName: "Ultra", monthlyCreditsUSD: 300),
        Plan(id: "teams-pro", displayName: "Teams Pro", monthlyCreditsUSD: 40)
    ]

    /// Resolve a plan ID to its catalog entry, or nil when unknown.
    /// - Parameter planID: raw plan ID from the subscriptions response.
    /// - Returns: the matching plan, or nil so callers degrade to balance-only.
    static func plan(forID planID: String) -> Plan? {
        let normalized = planID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        guard !normalized.isEmpty else { return nil }

        if let exact = plans.first(where: { $0.id == normalized }) {
            return exact
        }
        // Longest prefix first so "individual-pro-v1" beats "individual-pro" and
        // "individual-provider" beats "individual-pro".
        return plans
            .sorted { $0.id.count > $1.id.count }
            .first { normalized.hasPrefix($0.id) }
    }
}
