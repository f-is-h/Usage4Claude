//
//  ClaudeAPIResponseModels.swift
//  Usage4Claude
//
//  Pure-data types for the Claude.ai API: wire models (`UsageResponse`,
//  `ExtraUsageResponse`, `ErrorResponse`, `Organization`) and the in-memory
//  models they decode into (`UsageData`, `ExtraUsageData`).
//
//  Lives in Helpers/ so it can be cherry-picked into a SwiftPM test target —
//  every symbol here must stay free of `L.*`, `Logger`, `UserSettings`, or any
//  UI dependency. The display-side formatting (locale-aware reset strings,
//  status colors, etc.) lives in `UsageData+Formatting.swift` as extensions.
//

import Foundation

// MARK: - Organization

/// Organization 组织信息模型
/// 对应 Claude API /api/organizations 返回的组织信息
nonisolated struct Organization: Codable, Sendable, Identifiable, Equatable {
    /// 组织数字 ID
    let id: Int
    /// 组织 UUID（用于 API 调用）
    let uuid: String
    /// 组织名称
    let name: String
    /// 创建时间
    let createdAt: String?
    /// 更新时间
    let updatedAt: String?
    /// 组织权限列表
    let capabilities: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, uuid, name, capabilities
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func == (lhs: Organization, rhs: Organization) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

// MARK: - Usage Response (wire model)

/// API 响应数据模型
/// 对应 Claude API 返回的 JSON 结构
nonisolated struct UsageResponse: Codable, Sendable {
    /// 5小时用量限制数据
    let five_hour: LimitUsage
    /// 7天用量限制数据
    let seven_day: LimitUsage?
    /// 7天 OAuth 应用用量（暂未使用）
    let seven_day_oauth_apps: LimitUsage?
    /// 7天 Opus 用量限制数据
    let seven_day_opus: LimitUsage?
    /// 7天 Sonnet 用量限制数据（新字段）
    let seven_day_sonnet: LimitUsage?

    /// 新版 API 的统一限制数组（Claude 5 时代）。
    /// 每周针对具体模型的限制（如 Fable）不再走 `seven_day_opus` / `seven_day_sonnet`
    /// 独立字段，而是以 `kind == "weekly_scoped"` 的条目出现在这里，
    /// 通过 `scope.model.display_name` 标识具体模型。
    let limits: [LimitEntry]?

    /// 通用限制用量详情（适用于5小时、7天等各种限制）
    struct LimitUsage: Codable, Sendable {
        /// 当前使用率 (0-100，可以是浮点数)
        let utilization: Double
        /// 重置时间（ISO 8601 格式），nil 表示尚未开始使用
        let resets_at: String?
    }

    /// 新版 `limits` 数组中的单个条目。
    /// - `kind`: "session" / "weekly_all" / "weekly_scoped" 等
    /// - `percent`: 使用百分比 (0-100)
    /// - `scope.model.display_name`: 当限制针对具体模型时给出模型名（如 "Fable"）
    struct LimitEntry: Codable, Sendable {
        let kind: String?
        let group: String?
        let percent: Double?
        let severity: String?
        let resets_at: String?
        let is_active: Bool?
        let scope: Scope?

        struct Scope: Codable, Sendable {
            let model: Model?
            let surface: String?

            struct Model: Codable, Sendable {
                let id: String?
                let display_name: String?
            }
        }
    }

    /// 将 API 响应转换为应用内部使用的 UsageData 模型
    /// - Returns: 转换后的 UsageData 实例
    /// - Note: 会自动处理时间四舍五入，确保显示准确
    func toUsageData() -> UsageData {
        // 解析5小时限制数据
        let fiveHourData = parseLimitData(five_hour)

        // 解析7天限制数据。所有 Claude 账号都有 7 天限制；
        // 未开始使用时 API 可能返回 0 且无 resets_at，仍保留为 0% 占位。
        let sevenDayData: UsageData.LimitData = {
            guard let sevenDay = seven_day else {
                return UsageData.LimitData(percentage: 0, resetsAt: nil)
            }
            let parsed = parseLimitData(sevenDay)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        // 解析 Opus 限制数据（旧版独立字段，仅当存在且有效时）
        let legacyOpus: UsageData.LimitData? = {
            guard let opus = seven_day_opus else {
                return nil
            }
            if opus.utilization == 0 && opus.resets_at == nil {
                return nil
            }
            let parsed = parseLimitData(opus)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        // 解析 Sonnet 限制数据（旧版独立字段，仅当存在且有效时）
        let legacySonnet: UsageData.LimitData? = {
            guard let sonnet = seven_day_sonnet else {
                return nil
            }
            if sonnet.utilization == 0 && sonnet.resets_at == nil {
                return nil
            }
            let parsed = parseLimitData(sonnet)
            return UsageData.LimitData(percentage: parsed.percentage, resetsAt: parsed.resetsAt)
        }()

        // 解析新版 `limits` 数组里针对具体模型的每周限制（Claude 5 时代，如 Fable）。
        // 这些限制不再走 seven_day_opus / seven_day_sonnet 独立字段，而是以带
        // scope.model 的条目出现在 limits 中。保留出现顺序，过滤掉没有模型名
        // 或没有百分比的条目。
        var scopedModels: [(name: String, limit: UsageData.LimitData)] = (limits ?? []).compactMap { entry in
            guard let name = entry.scope?.model?.display_name, !name.isEmpty,
                  let percent = entry.percent else { return nil }
            let limit = UsageData.LimitData(percentage: percent, resetsAt: parseResetDate(entry.resets_at))
            return (name, limit)
        }

        // 旧字段优先；缺失时用 limits 里的模型限制回填 opus / sonnet 两个展示槽位，
        // 并记录对应的真实模型名，以便 UI 动态显示（如用 "Fable" 取代 "Opus Weekly"）。
        var opusData = legacyOpus
        var opusModelName: String? = nil
        var sonnetData = legacySonnet
        var sonnetModelName: String? = nil

        if opusData == nil, !scopedModels.isEmpty {
            let first = scopedModels.removeFirst()
            opusData = first.limit
            opusModelName = first.name
        }
        if sonnetData == nil, !scopedModels.isEmpty {
            let second = scopedModels.removeFirst()
            sonnetData = second.limit
            sonnetModelName = second.name
        }

        return UsageData(
            fiveHour: UsageData.LimitData(percentage: fiveHourData.percentage, resetsAt: fiveHourData.resetsAt),
            sevenDay: sevenDayData,
            opus: opusData,
            sonnet: sonnetData,
            extraUsage: nil,  // Extra Usage 将在阶段5通过单独的 API 获取
            opusModelName: opusModelName,
            sonnetModelName: sonnetModelName
        )
    }

    /// 解析 ISO 8601 重置时间字符串为 Date（四舍五入到秒）。
    /// 与 parseLimitData 内的时间解析逻辑保持一致，供 limits 数组条目复用。
    private func parseResetDate(_ resetString: String?) -> Date? {
        guard let resetString = resetString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: resetString) else { return nil }
        let rounded = round(date.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: rounded)
    }

    /// 解析单个限制的数据（5小时或7天）
    /// - Parameter limit: LimitUsage 结构
    /// - Returns: 包含百分比和重置时间的元组
    private func parseLimitData(_ limit: LimitUsage) -> (percentage: Double, resetsAt: Date?) {
        let resetsAt: Date?
        if let resetString = limit.resets_at {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: resetString) {
                // 对时间进行四舍五入到最接近的秒
                // 例如：05:59:59.645 → 06:00:00
                //       06:00:00.159 → 06:00:00
                let interval = date.timeIntervalSinceReferenceDate
                let roundedInterval = round(interval)
                resetsAt = Date(timeIntervalSinceReferenceDate: roundedInterval)
            } else {
                resetsAt = nil
            }
        } else {
            resetsAt = nil
        }

        return (percentage: Double(limit.utilization), resetsAt: resetsAt)
    }
}

// MARK: - Extra Usage Response (wire model)

/// Extra Usage API 响应模型
/// 用于解析 /api/organizations/{id}/overage_spend_limit 接口返回的数据
nonisolated struct ExtraUsageResponse: Codable, Sendable {
    /// 限制类型（如 "organization"）
    let limit_type: String?
    /// 是否启用
    let is_enabled: Bool?
    /// 每月额度上限（单位：美分）- 新字段名
    let monthly_limit: Int?
    /// 每月额度上限（单位：美分）- 旧字段名
    let monthly_credit_limit: Int?
    /// 货币单位（如 "EUR", "USD"）
    let currency: String?
    /// 已使用金额（单位：美分，API 可能返回浮点数如 21.0）
    let used_credits: Double?
    /// 信用额度耗尽
    let out_of_credits: Bool?

    // MARK: - Legacy fields (backwards compatibility)
    let type: String?
    let spend_limit_currency: String?
    let spend_limit_amount_cents: Int?
    let balance_cents: Int?

    /// 转换为 ExtraUsageData
    /// - Returns: 转换后的 ExtraUsageData，如果数据无效则返回 nil
    func toExtraUsageData() -> ExtraUsageData? {
        let resolvedCurrency = (currency ?? spend_limit_currency ?? "USD").uppercased()
        // 优先使用新字段名 monthly_limit，回退到旧字段名，单位均为美分
        let limitCents = monthly_limit ?? monthly_credit_limit ?? spend_limit_amount_cents
        // used_credits 单位为美分（API 可能以浮点形式返回，如 21.0 表示 21 美分）
        let usedCents = used_credits ?? balance_cents.map { Double($0) }

        // 使用 is_enabled 字段判断，回退到限额检查
        let enabled = is_enabled ?? (limitCents.map { $0 > 0 } ?? false)

        guard enabled, let limitCents = limitCents, limitCents > 0 else {
            return ExtraUsageData(
                enabled: false,
                used: nil,
                limit: nil,
                currency: resolvedCurrency
            )
        }

        // 美分转美元：除以 100
        let limit = Double(limitCents) / 100.0
        let used = (usedCents ?? 0.0) / 100.0

        return ExtraUsageData(
            enabled: true,
            used: used,
            limit: limit,
            currency: resolvedCurrency
        )
    }
}

// MARK: - Error Response (wire model)

/// API 错误响应模型
/// 对应 Claude API 返回的错误信息结构
nonisolated struct ErrorResponse: Codable, Sendable {
    let type: String
    let error: ErrorDetail

    /// 错误详情
    struct ErrorDetail: Codable, Sendable {
        let type: String
        let message: String
    }
}

// MARK: - Usage Data (in-memory storage)

/// 用量数据模型
/// 应用内部使用的标准化用量数据结构
///
/// Storage-only here — locale-aware formatting (resetsInHours, statusColor,
/// etc.) lives in `UsageData+Formatting.swift` as extensions, so this file
/// can be compiled by a SwiftPM test target without dragging in
/// `LocalizationHelper` / `UserSettings`.
struct UsageData: Sendable {
    /// 5小时限制数据（可选）
    let fiveHour: LimitData?
    /// 7天限制数据（可选）
    let sevenDay: LimitData?
    /// Opus 每周限制数据（可选）。在 Claude 5 时代，此槽位可承载来自新版
    /// `limits` 数组的“针对具体模型的每周限制”（如 Fable），真实模型名见 `opusModelName`。
    let opus: LimitData?
    /// Sonnet 每周限制数据（可选）。同上，可承载第二个模型的每周限制。
    let sonnet: LimitData?
    /// Extra Usage 限额数据（可选）
    let extraUsage: ExtraUsageData?

    /// opus 槽位对应的真实模型显示名（如 "Fable"）。为 nil 时 UI 回退到默认的
    /// “Opus Weekly” 本地化文案；非 nil 时按此名称展示。
    let opusModelName: String?
    /// sonnet 槽位对应的真实模型显示名。语义同 `opusModelName`。
    let sonnetModelName: String?

    /// 显式成员初始化器。新增的 `opusModelName` / `sonnetModelName` 提供默认值，
    /// 这样既能在 toUsageData() 中传入模型名，又不破坏其它以旧标签调用的构造点。
    init(
        fiveHour: LimitData?,
        sevenDay: LimitData?,
        opus: LimitData?,
        sonnet: LimitData?,
        extraUsage: ExtraUsageData?,
        opusModelName: String? = nil,
        sonnetModelName: String? = nil
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.opus = opus
        self.sonnet = sonnet
        self.extraUsage = extraUsage
        self.opusModelName = opusModelName
        self.sonnetModelName = sonnetModelName
    }

    /// 单个限制的数据（5小时、7天、Opus、Sonnet）
    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 用量重置时间，nil 表示尚未开始使用
        let resetsAt: Date?

        /// 距离重置的剩余时间（秒）
        /// - Returns: 剩余秒数，如果 resetsAt 为 nil 则返回 nil
        var resetsIn: TimeInterval? {
            guard let resetsAt = resetsAt else { return nil }
            return resetsAt.timeIntervalSinceNow
        }
    }

    /// 便捷访问：当前主要显示的数据（优先5小时，否则7天）
    var primaryLimit: LimitData? {
        return fiveHour ?? sevenDay
    }

    /// 是否同时有两种限制数据
    var hasBothLimits: Bool {
        return fiveHour != nil && sevenDay != nil
    }

    /// 是否只有7天限制数据
    var hasOnlySevenDay: Bool {
        return fiveHour == nil && sevenDay != nil
    }

    // MARK: - 向后兼容属性（保留用于旧代码）

    /// 当前使用百分比 (0-100)
    /// - Note: 向后兼容属性，返回主要限制的百分比
    var percentage: Double {
        return primaryLimit?.percentage ?? 0
    }

    /// 用量重置时间，nil 表示尚未开始使用
    /// - Note: 向后兼容属性，返回主要限制的重置时间
    var resetsAt: Date? {
        return primaryLimit?.resetsAt
    }

    /// 距离重置的剩余时间（秒）
    /// - Note: 向后兼容属性
    var resetsIn: TimeInterval? {
        return primaryLimit?.resetsIn
    }
}

// MARK: - Extra Usage Data (in-memory storage)

/// Extra Usage 数据模型
/// 额外付费用量数据结构（金额而非百分比）
struct ExtraUsageData: Sendable {
    /// 是否启用 Extra Usage
    let enabled: Bool
    /// 已使用金额
    let used: Double?
    /// 总限额
    let limit: Double?
    /// 货币代码（ISO 4217，如 USD、EUR、GBP）
    let currency: String

    /// 使用百分比（用于统一显示）
    var percentage: Double? {
        guard let used = used, let limit = limit, limit > 0 else {
            return nil
        }
        return (used / limit) * 100.0
    }

    /// 货币符号（根据 ISO 4217 货币代码解析）
    /// - Note: 用 NumberFormatter 而非手工映射表，一劳永逸覆盖所有货币（含 KRW/CNY/CHF 等），
    ///   固定用 en_US locale 解析以获得稳定符号（如 "$"、"CA$"），不随系统语言变化。
    var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.currencySymbol ?? currency
    }
}
