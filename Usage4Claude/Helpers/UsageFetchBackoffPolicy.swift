//
//  UsageFetchBackoffPolicy.swift
//  Usage4Claude
//
//  Pure failure-backoff decision for the usage fetches, extracted so it's
//  cherry-pickable into a SwiftPM test target — same pattern as
//  CodexAnnouncementFetchPolicy.swift. No Timer/UserDefaults/NotificationCenter;
//  DataRefreshManager owns one State per provider and applies the decision.
//

import Foundation

/// 用量拉取的失败退避策略（每个 Provider 独立一份状态）。
///
/// 限流（429）、5xx、网络错误、Cloudflare 拦截之后，自动触发的刷新（定时器、系统唤醒、
/// 打开 Popover、重置验证）在退避期内一律跳过；手动刷新不受约束。
/// 按固定间隔持续重试会让用量接口的 429 一直续期，拖成数小时拿不到数据的死循环。
///  - 退避时长：1 → 2 → 4 → 8 → 16 → 30 分钟封顶（网络错误封顶 5 分钟），之后再乘以 1~1.2 的随机抖动，
///    所以实际最长约 36 分钟；抖动只会推迟、不会提前
///  - 服务端给出 `Retry-After`（> 0，采信上限 1 小时）时取两者较大值；`Retry-After: 0` 视为未提供
///    （Anthropic 用量接口实测会在持续限流时返回 0）
///  - 成功一次即完全复位
enum UsageFetchBackoffPolicy {
    /// 可退避的失败类型，决定退避封顶
    enum Failure: Equatable, Sendable {
        /// 429 限流；retryAfter 为解析后的有效 Retry-After，nil 表示未提供或为 0
        case rateLimited(retryAfter: TimeInterval?)
        /// 5xx 或 Cloudflare 拦截
        case serverError
        /// 网络不可达。恢复联网时没有任何事件会清除退避，封顶必须低，
        /// 否则断网一小时后还要再等半小时才能恢复刷新
        case network
    }

    struct State: Equatable, Sendable {
        /// 连续失败次数，成功一次即归零
        let consecutiveFailures: Int
        /// 在此时间之前自动刷新不得发起请求；nil 表示不受限
        let retryNotBefore: Date?

        static let initial = State(consecutiveFailures: 0, retryNotBefore: nil)
    }

    static let baseDelay: TimeInterval = 60
    static let maxDelay: TimeInterval = 30 * 60
    static let maxNetworkDelay: TimeInterval = 5 * 60
    /// Retry-After 的采信上限，防止异常值把刷新冻结过久
    static let maxRetryAfter: TimeInterval = 60 * 60
    /// 抖动上限（相对退避时长的比例），避免同一时刻被限流的客户端同步重试
    static let maxJitterFraction: Double = 0.2

    static func shouldFetch(state: State, now: Date) -> Bool {
        guard let notBefore = state.retryNotBefore else { return true }
        return now >= notBefore
    }

    /// 记录一次可退避的失败，返回新状态
    /// - Parameter jitterFraction: 0...maxJitterFraction 的随机数，由调用方传入以便测试
    static func recordFailure(
        state: State,
        failure: Failure,
        now: Date,
        jitterFraction: Double
    ) -> State {
        let failures = state.consecutiveFailures + 1
        let delay = backoffDelay(consecutiveFailures: failures, failure: failure, jitterFraction: jitterFraction)
        return State(consecutiveFailures: failures, retryNotBefore: now.addingTimeInterval(delay))
    }

    /// 连续失败 N 次后，距下次允许自动刷新的等待时长
    static func backoffDelay(
        consecutiveFailures: Int,
        failure: Failure,
        jitterFraction: Double
    ) -> TimeInterval {
        guard consecutiveFailures > 0 else { return 0 }

        let cap: TimeInterval
        var retryAfter: TimeInterval?
        switch failure {
        case .rateLimited(let value):
            cap = maxDelay
            retryAfter = value
        case .serverError:
            cap = maxDelay
        case .network:
            cap = maxNetworkDelay
        }

        // 指数先封顶再求幂，避免失败次数很大时 pow 溢出为 inf
        let exponent = Double(min(consecutiveFailures - 1, 16))
        var delay = min(baseDelay * pow(2, exponent), cap)
        if let retryAfter, retryAfter > 0 {
            delay = max(delay, min(retryAfter, maxRetryAfter))
        }
        let jitter = min(max(jitterFraction, 0), maxJitterFraction)
        return delay * (1 + jitter)
    }

    /// 解析 `Retry-After` 响应头，支持 delta-seconds 与 IMF-fixdate 两种格式（RFC 9110 §10.2.3）
    /// - Returns: 距 now 的等待秒数；缺失、无法解析或 <= 0 时返回 nil
    static func retryAfterInterval(from headerValue: String?, now: Date) -> TimeInterval? {
        guard let raw = headerValue?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        // delta-seconds 只允许纯数字；TimeInterval(_:) 会接受 "inf"、"1e3"、"+5" 这类非法值
        if raw.allSatisfy({ $0.isASCII && $0.isNumber }) {
            guard let seconds = TimeInterval(raw), seconds > 0 else { return nil }
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: raw) else { return nil }
        let interval = date.timeIntervalSince(now)
        return interval > 0 ? interval : nil
    }
}
