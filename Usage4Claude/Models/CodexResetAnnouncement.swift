//
//  CodexResetAnnouncement.swift
//  Usage4Claude
//
//  Pure-data types + parsing for codex-reset.com's public JSON endpoints.
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — every symbol here must stay free of `L.*`/`Logger`/UI dependency,
//  same convention as CodexUsageData.swift.
//
//  Background: codex-reset.com is a third-party community project tracking
//  when OpenAI publicly announces a global Codex usage-limit reset. Its
//  "forecast" percentage means two different things depending on state — a
//  historical-cadence guess in quiet periods (no predictive power; the site's
//  own backtest shows it barely beats a naive baseline) vs. a wording
//  classification score once a real announcement is live (e.g. 93% just means
//  "a dated commitment was posted", not "93% likely"). Either way the number
//  is not usable as a probability, so this app does not surface it at all.
//  Instead it surfaces the one piece of ground truth worth showing: whether
//  Tibo Sottiaux (OpenAI) has *actually* posted a still-pending reset window.
//

import Foundation

// MARK: - 内部数据模型

/// Codex 全局重置的官方预告（一条真实存在、尚未过期的公开预告，而非概率估计）
nonisolated struct CodexResetAnnouncement: Sendable, Equatable {
    /// 预告目标时间点的性质，对应 codex-reset.com 的 `target_kind`
    enum Kind: Sendable, Equatable {
        /// "around 2 PM" 型：target 是估计的中心点，实际时间可能早于或晚于它
        case center
        /// "within an hour" 型：target 是截止时刻，实际时间不会晚于它
        case deadline
        /// 只有起止窗口、没有明确目标点（如 "later today" / "within a few hours"）
        case range
    }

    /// 人类可读的窗口描述，原样取自站点（如 "around 2 PM PT on Aug 23"）
    let label: String
    /// 原帖摘要，供 tooltip 展示以便用户核实
    let summary: String
    /// 窗口结束时间——过了这个点即视为预告已过期
    let windowEnd: Date
    /// 倒计时目标：kind == .range 时等于 windowEnd
    let target: Date
    let kind: Kind

    func isActive(at now: Date) -> Bool { now < windowEnd }
}

// MARK: - /api/timeline 响应模型

/// codex-reset.com `/api/timeline` 响应模型
/// 字段全部 optional——第三方 API 随时可能改结构，缺字段不应导致整体解码失败。
nonisolated struct CodexTimelineResponse: Codable, Sendable {
    struct Event: Codable, Sendable {
        struct OfficialWindow: Codable, Sendable {
            let label: String?
            let start_at: String?
            let end_at: String?
            let target_at: String?
            /// 实测取值："center" | "deadline"；也可能整个字段缺失（对应 Kind.range）
            let target_kind: String?
        }

        let summary: String?
        /// true 表示这是一条「预告」事件（而非事后确认的历史记录）
        let preview: Bool?
        /// 实测恒为 "global"；非 global 的预告（如仅限特定 plan）不应触发 UI
        let scope: String?
        let official_window: OfficialWindow?
    }

    let events: [Event]?

    /// 取当前仍然有效（尚未过期）的、最快到期的一条全局重置预告
    /// 判定条件（全部满足）：`preview == true`、`official_window.end_at` 可解析且晚于 now、`scope == "global"`。
    /// 多条同时命中时取 `windowEnd` 最早的一条——最先到期、最值得关注。
    /// - Parameter now: 判定基准时间，默认当前时间；测试时可注入固定值
    func activeAnnouncement(now: Date = Date()) -> CodexResetAnnouncement? {
        guard let events else { return nil }

        let candidates: [CodexResetAnnouncement] = events.compactMap { event in
            guard event.preview == true, event.scope == "global" else { return nil }
            guard let window = event.official_window else { return nil }
            guard let end = Self.parseISO8601(window.end_at), end > now else { return nil }

            let target = Self.parseISO8601(window.target_at) ?? end
            let kind: CodexResetAnnouncement.Kind
            switch window.target_kind {
            case "center": kind = .center
            case "deadline": kind = .deadline
            default: kind = .range
            }

            let label = window.label ?? event.summary ?? ""

            return CodexResetAnnouncement(
                label: label,
                summary: event.summary ?? "",
                windowEnd: end,
                target: target,
                kind: kind
            )
        }

        return candidates.min { $0.windowEnd < $1.windowEnd }
    }

    /// 兼容实测出现过的两种 ISO8601 格式：
    /// 带毫秒 "2026-08-23T06:29:05.000Z" 与不带毫秒 "2026-07-21T16:47:15Z"
    private static func parseISO8601(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = iso8601WithFractional.date(from: string) { return date }
        return iso8601Plain.date(from: string)
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - /api/forecast 安静期判定（两段式探测第一段）

/// 判定 `/api/forecast` 是否处于「无预告」的安静态，避免安静期也拉取较大的 `/api/timeline`。
/// 未观测到信号期这几个字段的真实取值（抓取时全为 null），因此不假设具体类型或取值，
/// 只反向断言已实测的安静态——这些 key 缺失或为 JSON null。任何偏离都判定为「非安静」，
/// 触发更详细的 timeline 请求核实：宁可多拉一次 46KB，也不漏掉一次真实预告。
enum CodexForecastQuietState {
    private static let watchedKeys = ["official_signal", "teased_window", "signal_percent", "commitment"]

    /// - Parameter jsonData: `/api/forecast` 的原始响应体
    /// - Returns: true 表示安静期（可跳过 timeline 请求）；解析失败时保守返回 false（触发核实）
    static func isQuiet(jsonData: Data) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] else {
            return false
        }
        return watchedKeys.allSatisfy { key in
            guard let value = object[key] else { return true }   // 字段缺失 = 安静
            return value is NSNull                                 // 存在但为 null = 安静
        }
    }
}
