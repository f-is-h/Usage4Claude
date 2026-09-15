//
//  CodexUsageData.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  Pure-data types + parsing for the Codex /backend-api/wham/usage response.
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — every symbol here must stay free of `L.*`/`Logger`/UI dependency.
//  The `L.*`-dependent display formatting lives in
//  `CodexUsageData+Formatting.swift`.
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

    /// 5小时窗口的标准时长（秒）
    private static let fiveHourWindowSeconds = 18_000
    /// 7天窗口的标准时长（秒）
    private static let sevenDayWindowSeconds = 604_800

    /// 判断窗口是否属于"5小时档"——按 limit_window_seconds 实际时长判断，
    /// 而非 JSON 字段名（primary_window/secondary_window）。
    /// 背景：Codex 曾临时取消5小时限制，此时唯一窗口仍出现在 primary_window 位置，
    /// 但其 limit_window_seconds 是 604800（7天），若按字段位置硬映射会显示成"5小时限制"。
    /// 缺失 limit_window_seconds 时保守判定为非5小时，避免旧数据被误分类。
    private static func isFiveHourWindow(_ window: Window) -> Bool {
        guard let seconds = window.limit_window_seconds else { return false }
        return abs(seconds - fiveHourWindowSeconds) < abs(seconds - sevenDayWindowSeconds)
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

        func buildLimitData(_ window: Window?) -> CodexUsageData.LimitData? {
            guard let w = window else { return nil }
            // 如果 used_percent 为 0 且无重置信息，视为无效数据
            if w.used_percent == 0 && w.reset_at == nil && w.reset_after_seconds == nil { return nil }
            return .init(percentage: w.used_percent, resetsAt: resolvedResetDate(for: w))
        }

        // 按实际时长分类，而不是按 JSON 字段位置——见 isFiveHourWindow 注释
        let windows = [rate_limit?.primary_window, rate_limit?.secondary_window].compactMap { $0 }
        let primary = buildLimitData(windows.first { Self.isFiveHourWindow($0) })
        let secondary = buildLimitData(windows.first { !Self.isFiveHourWindow($0) })

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

    init(
        hasCredits: Bool,
        unlimited: Bool,
        overageLimitReached: Bool,
        spendControlReached: Bool,
        balance: Decimal?,
        approxLocalMessages: [Int]?,
        approxCloudMessages: [Int]?
    ) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.overageLimitReached = overageLimitReached
        self.spendControlReached = spendControlReached
        self.balance = balance
        self.approxLocalMessages = approxLocalMessages
        self.approxCloudMessages = approxCloudMessages
    }

    var enabled: Bool {
        if hasCredits || unlimited || overageLimitReached || spendControlReached {
            return true
        }
        return (balanceValue ?? 0) > 0
    }

    /// 点数已耗尽。三个判据全部来自 API 的明确信号，不含任何推断。
    var isExhausted: Bool {
        if unlimited { return false }
        if overageLimitReached || spendControlReached { return true }
        guard let balanceValue else { return false }
        return balanceValue <= 0
    }

    /// 「有余额 / 已耗尽」的二值信号，不是真实比例，**不要用于显示**。
    ///
    /// Codex credits 是预付钱包，服务端不返回任何限额字段，「已用百分之多少」必须先生造一个
    /// 分母才算得出来——拿启动时刻、历史最高余额还是消耗速率当基准，都是我们编的。所以显示层
    /// 不再碰它：菜单栏和详情行直接画余额点数（见 `menuBarBalanceText`）。
    ///
    /// 留下 0/100 是喂给 `NotificationManager` 的：100 让「点数用尽」在用户设的任意阈值下
    /// 都能触发提醒，充值后回到 0 才会走 `NotificationDecisionEngine` 的重置分支清掉已通知
    /// 记录——否则下次耗尽会被永久抑制。用户设的 75/90 等中间档对 Codex 不起作用，因为那些
    /// 百分比从来就不存在。
    var percentage: Double? {
        if isExhausted { return 100 }
        return enabled ? 0 : nil
    }

    /// 供 `CodexUsageData+Formatting.swift` 的 `L.*` 格式化属性复用，
    /// 因此不能是 `private`（跨文件 extension 访问不到）
    var balanceValue: Double? {
        guard let balance else { return nil }
        return NSDecimalNumber(decimal: balance).doubleValue
    }

    /// 图标里显示的余额文本，`nil` 表示没有余额可显示（调用方据此不画这一格）。
    var menuBarBalanceText: String? {
        Self.menuBarBalanceText(balanceValue)
    }

    /// 把点数余额压进图标能容纳的宽度。
    ///
    /// 菜单栏六边形里放得下 4 个字符左右（`ShapeIconRenderer.drawHexagonBadge` 会按可用
    /// 宽度解出字号，字数越多字号越小）。Codex 点数是四五位数的量级，原样显示会小到看不清，
    /// 所以大数必须缩写。
    ///
    /// 断点选在 1000 不是为了凑宽度：余额只有在快见底时才需要精确到个位（80 和 79 是两个
    /// 不同的决定），高位时用户只需要知道数量级。精度需求和缩写断点恰好对齐。
    static func menuBarBalanceText(_ balance: Double?) -> String? {
        guard let balance else { return nil }
        if balance <= 0 { return "0" }
        // 不足 1 点向下取整会显示成 0，与真耗尽撞脸，单独标记
        if balance < 1 { return "<1" }
        if balance < 1000 { return String(Int(balance)) }
        if balance < 10_000 {
            // 一位小数的 "2.5k"：小数点很窄，视觉宽度约等于 3 个字符
            let tenths = (balance / 100).rounded(.down) / 10
            return String(format: "%.1fk", tenths)
        }
        return String(Int((balance / 1000).rounded(.down))) + "k"
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
/// 一次成功的 session-token 校验结果
///
/// 带出 `accessToken` 是刻意的：服务端只会为**已登录**会话返回它，所以它就是
/// 「这个 session-token 确实处于已登录状态」的证明。写回轮换后的 session-token
/// 必须凭它放行，详见 `CodexSessionTokenRotation`。
nonisolated struct CodexSessionValidation: Sendable {
    let email: String
    let displayName: String
    /// 已登录的证明
    let accessToken: String
}

nonisolated struct CodexSessionResponse: Codable, Sendable {
    let accessToken: String?
    let user: User?

    struct User: Codable, Sendable {
        let name: String?
        let email: String?
    }
}
