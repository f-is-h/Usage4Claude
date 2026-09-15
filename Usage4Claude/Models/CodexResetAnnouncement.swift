//
//  CodexResetAnnouncement.swift
//  Usage4Claude
//
//  Pure-data types + parsing for codex-reset.com's public `/api/forecast`.
//  Lives here (not Helpers/) so it can be cherry-picked into a SwiftPM test
//  target — every symbol here must stay free of `L.*`/`AppLog`/UI dependency,
//  same convention as CodexUsageData.swift.
//
//  Background: codex-reset.com is a third-party community project that
//  classifies public posts by Tibo Sottiaux (OpenAI). When he promises a
//  global reset, the site raises a "strong Watch" (the same event that fires
//  its Telegram/Discord alerts) and exposes it as `latest_alert` with kind
//  "watch" and state "active". That Watch is the only thing this app shows.
//
//  The site's percentages are ignored on purpose. 83 and 93 are fixed tiers
//  (a promise without / with a stated time), not likelihoods; the other
//  numbers are a cadence extrapolation or a display floor raised by vague
//  hints. Whether a time was given is already carried by `window`.
//
//  3.4.x read `/api/timeline` instead, looking for `preview` events. Timeline
//  is the site's curated history: in an archived snapshot taken during the
//  Watch before the 2026-09-12 reset, that post was a plain event with no
//  window, so the badge stayed hidden while the site showed 83%.
//

import Foundation

// MARK: - 内部数据模型

/// Codex 全局重置的官方预告：Tibo 公开承诺、站点尚未确认落地的一次重置（不是概率估计）
nonisolated struct CodexResetAnnouncement: Sendable, Equatable {
    /// Tibo 给出的时间窗口
    struct Window: Sendable, Equatable {
        /// 目标时间点的性质，对应站点的 `target_kind`
        enum Kind: Sendable, Equatable {
            /// "around 2 PM" 型：target 是估计的中心点，实际时间可能早于或晚于它
            case center
            /// "within an hour" 型：target 是截止时刻
            case deadline
            /// 只有起止窗口、没有明确目标点（如 "later today"），或 target_kind 为未知取值
            case range
        }

        /// 人类可读的窗口描述，原样取自站点（如 "end of Monday"）
        let label: String
        let end: Date
        /// 倒计时目标：没有 target_at 时等于 end
        let target: Date
        let kind: Kind
    }

    /// 从 Tibo 发帖算起的最长展示时长。
    /// 正常情况下站点确认重置后 latest_alert 就不再是 watch/active，下一次抓取即清掉徽章；
    /// 这个上限只防站点状态停滞，免得徽章无限期挂着。
    static let maxAge: TimeInterval = 24 * 60 * 60

    /// 原帖摘要（已折叠空白），供 tooltip 引述以便用户核实
    let summary: String
    /// Tibo 没给具体时间的承诺（站点 83% 档）为 nil
    let window: Window?
    /// 徽章最迟消失的时刻：发帖后 maxAge 与窗口结束取较晚者
    let expiresAt: Date

    /// - Parameter postedAt: Tibo 发帖时间，expiresAt 由它和窗口推出
    init(summary: String, window: Window?, postedAt: Date) {
        self.summary = summary
        self.window = window
        self.expiresAt = max(postedAt.addingTimeInterval(Self.maxAge), window?.end ?? postedAt)
    }

    func isActive(at now: Date) -> Bool { now < expiresAt }

    /// 已过声明的时间点但站点还没确认。重置晚到很常见（2026-08-23 那次晚了近 4 小时），
    /// 这时既不该再显示倒计时，也不该让徽章消失。
    func isOverdue(at now: Date) -> Bool {
        guard let window else { return false }
        return now >= window.target
    }
}

// MARK: - /api/forecast 响应模型

/// codex-reset.com `/api/forecast` 响应里本 app 用到的部分。
/// 第三方 API 随时可能改结构：字段全部 optional，顶层逐字段容错解码——
/// 某个字段类型变了只让该字段为 nil，不会让整份响应解码失败。
nonisolated struct CodexForecastResponse: Decodable, Sendable {
    /// 站点的 Alert v3 事件，与其 Telegram/Discord 推送同源
    struct Alert: Decodable, Sendable {
        struct Window: Decodable, Sendable {
            let label: String?
            let endAt: String?
            let targetAt: String?
            /// 实测取值："center" | "deadline"；也可能缺失
            let targetKind: String?

            private enum CodingKeys: String, CodingKey {
                case label
                case endAt = "end_at"
                case targetAt = "target_at"
                case targetKind = "target_kind"
            }
        }

        /// 实测取值："watch"（已承诺、未落地）| "reset"（已确认）
        let kind: String?
        /// 实测取值："active" | "confirmed"
        let state: String?
        /// Tibo 发帖时间
        let sourceAt: String?
        /// 站点截断在 200 字符
        let summary: String?
        /// Tibo 没给具体时间时为 null（2026-09-12 实测）
        let window: Window?

        private enum CodingKeys: String, CodingKey {
            case kind, state, summary, window
            case sourceAt = "source_at"
        }
    }

    /// 实测取值："model"（安静期，只有历史节奏模型）| "announced"（有官方信号）
    let mode: String?
    let latestAlert: Alert?
    /// `official_signal` 是否为非 null。内容不参与展示，只用于发现「站点有信号、我们却读不出」
    let hasOfficialSignal: Bool

    private enum CodingKeys: String, CodingKey {
        case mode
        case latestAlert = "latest_alert"
        case officialSignal = "official_signal"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try? container.decodeIfPresent(String.self, forKey: .mode)
        latestAlert = try? container.decodeIfPresent(Alert.self, forKey: .latestAlert)
        hasOfficialSignal = container.contains(.officialSignal)
            && (try? container.decodeNil(forKey: .officialSignal)) == false
    }

    private static let knownAlertKinds: Set<String> = ["watch", "reset"]
    private static let knownAlertStates: Set<String> = ["active", "confirmed"]
    /// 站点对摘要的截断长度（2026-09 实测，原帖更长时恰好停在 200 字符）
    private static let summaryTruncationLength = 200

    /// 当前仍有效的预告；没有则 nil。
    /// 条件：latest_alert 为 kind "watch" 且 state "active"，source_at 可解析，且未过 expiresAt。
    ///
    /// 刻意不回退到 official_signal：重置落地后它可能还挂着。2026-08-31 实测，帖子说的是
    /// 「已经重置了」，站点仍标 93% 并给出「周一结束前」的窗口——回退的话徽章会在重置之后
    /// 继续显示「即将重置」。
    /// - Parameter now: 判定基准时间，默认当前时间；测试时可注入固定值
    func activeAnnouncement(now: Date = Date()) -> CodexResetAnnouncement? {
        guard let alert = latestAlert, alert.kind == "watch", alert.state == "active" else { return nil }
        guard let sourceAt = Self.parseISO8601(alert.sourceAt) else { return nil }

        let announcement = CodexResetAnnouncement(
            summary: Self.normalizedSummary(alert.summary),
            window: alert.window.flatMap(Self.makeWindow),
            postedAt: sourceAt
        )
        return announcement.isActive(at: now) ? announcement : nil
    }

    /// 站点表示有官方信号，但 latest_alert 缺失，或出现了没见过的 kind/state——多半是源站改了结构。
    /// 3.4.x 读错数据源、漏掉 2026-09-12 的预告时没留下任何痕迹，所以单独暴露给服务层记日志。
    var hasUnrecognizedSignal: Bool {
        guard hasOfficialSignal || mode == "announced" else { return false }
        guard let alert = latestAlert else { return true }
        return !Self.knownAlertKinds.contains(alert.kind ?? "")
            || !Self.knownAlertStates.contains(alert.state ?? "")
    }

    /// end_at 解析不了就当作没给时间：Tibo 的承诺本身仍然成立，只是时间读不出来
    private static func makeWindow(_ raw: Alert.Window) -> CodexResetAnnouncement.Window? {
        guard let end = parseISO8601(raw.endAt) else { return nil }

        let kind: CodexResetAnnouncement.Window.Kind
        switch raw.targetKind {
        case "center": kind = .center
        case "deadline": kind = .deadline
        default: kind = .range
        }

        return CodexResetAnnouncement.Window(
            label: raw.label ?? "",
            end: end,
            target: parseISO8601(raw.targetAt) ?? end,
            kind: kind
        )
    }

    /// 站点保留了原帖换行，tooltip 里的多行引述会被切得很碎，所以把空白折叠成单个空格；
    /// 达到截断长度时补省略号，免得读起来像原帖就断在半个词上。
    private static func normalizedSummary(_ raw: String?) -> String {
        guard let raw else { return "" }
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return raw.count >= summaryTruncationLength ? collapsed + "…" : collapsed
    }

    /// 兼容实测出现过的两种 ISO8601 格式：
    /// 带毫秒 "2026-09-12T03:20:36.000Z" 与不带毫秒 "2026-07-21T16:47:15Z"
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
