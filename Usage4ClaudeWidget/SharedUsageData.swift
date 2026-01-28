//
//  SharedUsageData.swift
//  Usage4ClaudeWidget
//
//  Shared data model for App Group communication between main app and widget.
//  Widget-only version without UsageData dependency.
//

import Foundation

/// App Group identifier for sharing data between app and widget
let appGroupIdentifier = "group.xyz.fi5h.Usage4Claude"

/// Codable wrapper for sharing usage data via App Group UserDefaults
struct SharedUsageData: Codable {
    /// Limit type for display
    enum LimitType: String, Codable, CaseIterable {
        case fiveHour = "5h"
        case sevenDay = "7d"
        case opus = "opus"
        case sonnet = "sonnet"
        case extraUsage = "extra"

        var displayName: String {
            switch self {
            case .fiveHour: return "5h"
            case .sevenDay: return "7d"
            case .opus: return "Opus"
            case .sonnet: return "Sonnet"
            case .extraUsage: return "Extra"
            }
        }

        var iconName: String {
            switch self {
            case .fiveHour: return "laptopcomputer"
            case .sevenDay: return "keyboard"
            case .opus: return "hand.tap"
            case .sonnet: return "circle"
            case .extraUsage: return "dollarsign.circle"
            }
        }
    }

    /// Single limit data for widget display
    struct LimitEntry: Codable, Identifiable {
        var id: String { type.rawValue }
        let type: LimitType
        let percentage: Double
        let resetsAt: Date?
        let isAvailable: Bool

        /// Formatted remaining time string (compact)
        var formattedRemaining: String {
            guard let resetsAt = resetsAt else { return "-" }
            let remaining = resetsAt.timeIntervalSinceNow
            guard remaining > 0 else { return "Soon" }

            let totalMinutes = Int(ceil(remaining / 60))
            if totalMinutes < 60 {
                return "\(totalMinutes)m"
            }

            let totalHours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if totalHours < 24 {
                return minutes > 0 ? "\(totalHours)h\(minutes)m" : "\(totalHours)h"
            }

            let days = totalHours / 24
            let hours = totalHours % 24
            return hours > 0 ? "\(days)d\(hours)h" : "\(days)d"
        }
    }

    /// Extra usage specific data
    struct ExtraUsageEntry: Codable {
        let enabled: Bool
        let used: Double?
        let limit: Double?
        let currency: String

        var percentage: Double? {
            guard let used = used, let limit = limit, limit > 0 else { return nil }
            return (used / limit) * 100.0
        }

        var formattedAmount: String {
            guard enabled, let used = used, let limit = limit else { return "-" }
            return String(format: "$%.0f/$%.0f", used, limit)
        }
    }

    // MARK: - Properties

    let fiveHour: LimitEntry?
    let sevenDay: LimitEntry?
    let opus: LimitEntry?
    let sonnet: LimitEntry?
    let extraUsage: ExtraUsageEntry?
    let lastUpdated: Date
    let hasError: Bool
    let errorMessage: String?

    /// Active limit entries for widget display (non-nil, available entries)
    var activeLimits: [LimitEntry] {
        [fiveHour, sevenDay, opus, sonnet].compactMap { $0 }.filter { $0.isAvailable }
    }

    /// Check if any data is available
    var hasData: Bool {
        !activeLimits.isEmpty || (extraUsage?.enabled == true)
    }

    /// Create error state
    static func error(_ message: String) -> SharedUsageData {
        SharedUsageData(
            fiveHour: nil,
            sevenDay: nil,
            opus: nil,
            sonnet: nil,
            extraUsage: nil,
            lastUpdated: Date(),
            hasError: true,
            errorMessage: message
        )
    }

    /// Create empty placeholder
    static var placeholder: SharedUsageData {
        SharedUsageData(
            fiveHour: LimitEntry(type: .fiveHour, percentage: 77, resetsAt: Date().addingTimeInterval(3600 * 2), isAvailable: true),
            sevenDay: LimitEntry(type: .sevenDay, percentage: 100, resetsAt: Date().addingTimeInterval(3600 * 24 * 3), isAvailable: true),
            opus: LimitEntry(type: .opus, percentage: 71, resetsAt: Date().addingTimeInterval(3600 * 24 * 5), isAvailable: true),
            sonnet: nil,
            extraUsage: nil,
            lastUpdated: Date(),
            hasError: false,
            errorMessage: nil
        )
    }
}

// MARK: - UserDefaults Storage

extension SharedUsageData {
    private static let storageKey = "SharedUsageData"

    /// Save to App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }

    /// Load from App Group UserDefaults
    static func load() -> SharedUsageData? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SharedUsageData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
