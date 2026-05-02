//
//  CodexUsageData.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

// MARK: - 内部数据模型

/// Codex 使用量数据（应用内部使用的标准化结构）
struct CodexUsageData: Sendable {
    /// 5小时窗口用量（primary）
    let primary: LimitData?
    /// 7天窗口用量（secondary）
    let secondary: LimitData?
    /// Codex Extra Usage / credits 数据
    let extraUsage: CodexExtraUsageData?

    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 重置时间，nil 表示尚未开始使用
        let resetsAt: Date?
    }
}

// MARK: - API 响应模型

/// Codex /backend-api/wham/usage 响应模型
nonisolated struct CodexUsageResponse: Codable, Sendable {
    let account_id: String?
    let email: String?
    let plan_type: String?
    let rate_limit: RateLimit?
    let credits: Credits?
    let spend_control: SpendControl?

    struct RateLimit: Codable, Sendable {
        let allowed: Bool?
        let limit_reached: Bool?
        let primary_window: Window?
        let secondary_window: Window?
    }

    struct Window: Codable, Sendable {
        /// 使用百分比 (0-100)
        let used_percent: Double
        /// 窗口时长（秒）：18000 = 5小时，604800 = 7天
        let limit_window_seconds: Int?
        /// 距重置剩余秒数
        let reset_after_seconds: Int?
        /// 重置时间（Unix 时间戳，与 Claude 的 ISO 8601 不同）
        let reset_at: Int?
    }

    struct Credits: Codable, Sendable {
        let has_credits: Bool?
        let unlimited: Bool?
        let overage_limit_reached: Bool?
        let balance: String?
        let approx_local_messages: [Int]?
        let approx_cloud_messages: [Int]?

        private enum CodingKeys: String, CodingKey {
            case has_credits
            case unlimited
            case overage_limit_reached
            case balance
            case approx_local_messages
            case approx_cloud_messages
        }

        init(
            has_credits: Bool?,
            unlimited: Bool?,
            overage_limit_reached: Bool?,
            balance: String?,
            approx_local_messages: [Int]?,
            approx_cloud_messages: [Int]?
        ) {
            self.has_credits = has_credits
            self.unlimited = unlimited
            self.overage_limit_reached = overage_limit_reached
            self.balance = balance
            self.approx_local_messages = approx_local_messages
            self.approx_cloud_messages = approx_cloud_messages
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            has_credits = try container.decodeIfPresent(Bool.self, forKey: .has_credits)
            unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited)
            overage_limit_reached = try container.decodeIfPresent(Bool.self, forKey: .overage_limit_reached)
            approx_local_messages = try container.decodeIfPresent([Int].self, forKey: .approx_local_messages)
            approx_cloud_messages = try container.decodeIfPresent([Int].self, forKey: .approx_cloud_messages)

            if let stringBalance = try? container.decodeIfPresent(String.self, forKey: .balance) {
                balance = stringBalance
            } else if let doubleBalance = try? container.decodeIfPresent(Double.self, forKey: .balance) {
                balance = String(doubleBalance)
            } else if let intBalance = try? container.decodeIfPresent(Int.self, forKey: .balance) {
                balance = String(intBalance)
            } else {
                balance = nil
            }
        }
    }

    struct SpendControl: Codable, Sendable {
        let reached: Bool?
    }

    /// 将 API 响应转换为内部 CodexUsageData
    func toCodexUsageData() -> CodexUsageData {
        let now = Date()

        func resolvedResetDate(for window: Window) -> Date? {
            if let resetAt = window.reset_at {
                return Date(timeIntervalSince1970: TimeInterval(resetAt))
            }
            if let resetAfterSeconds = window.reset_after_seconds {
                return now.addingTimeInterval(TimeInterval(resetAfterSeconds))
            }
            return nil
        }

        let primary: CodexUsageData.LimitData? = {
            guard let w = rate_limit?.primary_window else { return nil }
            let resetsAt = resolvedResetDate(for: w)
            return .init(percentage: w.used_percent, resetsAt: resetsAt)
        }()

        let secondary: CodexUsageData.LimitData? = {
            guard let w = rate_limit?.secondary_window else { return nil }
            // 如果 used_percent 为 0 且无重置信息，视为无效数据
            if w.used_percent == 0 && w.reset_at == nil && w.reset_after_seconds == nil { return nil }
            let resetsAt = resolvedResetDate(for: w)
            return .init(percentage: w.used_percent, resetsAt: resetsAt)
        }()

        let extraUsage = credits.map {
            CodexExtraUsageData(
                hasCredits: $0.has_credits ?? false,
                unlimited: $0.unlimited ?? false,
                overageLimitReached: $0.overage_limit_reached ?? false,
                spendControlReached: spend_control?.reached ?? false,
                balance: CodexExtraUsageData.parseBalance($0.balance),
                approxLocalMessages: $0.approx_local_messages,
                approxCloudMessages: $0.approx_cloud_messages
            )
        }

        return CodexUsageData(primary: primary, secondary: secondary, extraUsage: extraUsage)
    }
}

/// Codex Extra Usage / credits 数据
/// Codex 返回的是可用余额和大致可发送消息数，而不是 Claude Extra Usage 的 used/limit 格式。
nonisolated struct CodexExtraUsageData: Sendable {
    let hasCredits: Bool
    let unlimited: Bool
    let overageLimitReached: Bool
    let spendControlReached: Bool
    let balance: Decimal?
    let approxLocalMessages: [Int]?
    let approxCloudMessages: [Int]?
    let visualPercentage: Double?

    init(
        hasCredits: Bool,
        unlimited: Bool,
        overageLimitReached: Bool,
        spendControlReached: Bool,
        balance: Decimal?,
        approxLocalMessages: [Int]?,
        approxCloudMessages: [Int]?,
        visualPercentage: Double? = nil
    ) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.overageLimitReached = overageLimitReached
        self.spendControlReached = spendControlReached
        self.balance = balance
        self.approxLocalMessages = approxLocalMessages
        self.approxCloudMessages = approxCloudMessages
        self.visualPercentage = visualPercentage
    }

    var enabled: Bool {
        if hasCredits || unlimited || overageLimitReached || spendControlReached {
            return true
        }
        return (balanceValue ?? 0) > 0
    }

    var percentage: Double? {
        if let visualPercentage {
            return visualPercentage
        }
        if overageLimitReached || spendControlReached {
            return 100
        }
        if hasCredits || unlimited || (balanceValue ?? 0) > 0 {
            return 0
        }
        return nil
    }

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

    private var balanceValue: Double? {
        guard let balance else { return nil }
        return NSDecimalNumber(decimal: balance).doubleValue
    }

    static func parseBalance(_ value: String?) -> Decimal? {
        guard let value, !value.isEmpty else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}

// MARK: - 格式化桥接

extension CodexUsageData.LimitData {
    /// 转换为 UsageData.LimitData，复用其全部格式化方法（倒计时、重置时间等）
    func asUsageLimitData() -> UsageData.LimitData {
        return UsageData.LimitData(percentage: percentage, resetsAt: resetsAt)
    }
}

// MARK: - Session 响应模型

/// Codex /api/auth/session 响应模型
/// 用于获取 Bearer accessToken
nonisolated struct CodexSessionResponse: Codable, Sendable {
    let accessToken: String?
    let user: User?

    struct User: Codable, Sendable {
        let name: String?
        let email: String?
    }
}
