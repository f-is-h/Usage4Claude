//
//  CodexAnnouncementFetchPolicy.swift
//  Usage4Claude
//
//  Pure fetch-cadence decision for CodexResetAnnouncementService, extracted
//  so it's cherry-pickable into a SwiftPM test target — same pattern as
//  SmartRefreshPolicy.swift. No Logger/UserDefaults/NotificationCenter; the
//  service applies the decision and owns all state/side effects.
//

import Foundation

/// Codex 重置预告（Beta）的抓取频率策略。
///
/// 判定顺序（任一命中即拒绝，全部通过才允许发起请求）：
///  1. 距上次尝试不足 `minInterval`（60s）—— 硬性最小间隔，对齐源站 `cache-control: max-age=60`
///  2. 仍在失败退避期内 —— 见 `backoffInterval`
///  3. 缓存内有「活跃预告」且未超过 `activeTTL`（10min）
///  4. 缓存为「无预告」且未超过 `quietTTL`（30min）
///  5. 否则允许抓取
enum CodexAnnouncementFetchPolicy {
    struct State: Sendable {
        /// 上一次实际发起网络请求的时间（无论成败）；nil 表示从未尝试过
        let lastAttemptAt: Date?
        /// 上一次成功写入缓存的时间（成功即写，即使结果是「无预告」）；nil 表示缓存为空
        let cachedAt: Date?
        /// 当前缓存内容是否是一条仍未过期的活跃预告
        let hasActiveAnnouncement: Bool
        /// 连续失败次数，成功一次即归零
        let consecutiveFailures: Int
    }

    static let minInterval: TimeInterval = 60
    static let quietTTL: TimeInterval = 30 * 60
    static let activeTTL: TimeInterval = 10 * 60
    /// 失败退避阶梯：5 → 15 → 30 → 60 分钟，超过阶梯长度后封顶在最后一档
    static let backoffLadder: [TimeInterval] = [5 * 60, 15 * 60, 30 * 60, 60 * 60]

    static func shouldFetch(state: State, now: Date) -> Bool {
        if let lastAttempt = state.lastAttemptAt, now.timeIntervalSince(lastAttempt) < minInterval {
            return false
        }

        if state.consecutiveFailures > 0, let lastAttempt = state.lastAttemptAt {
            let backoff = backoffInterval(consecutiveFailures: state.consecutiveFailures)
            if now.timeIntervalSince(lastAttempt) < backoff {
                return false
            }
        }

        guard let cachedAt = state.cachedAt else { return true }
        let ttl = state.hasActiveAnnouncement ? activeTTL : quietTTL
        return now.timeIntervalSince(cachedAt) >= ttl
    }

    /// 连续失败 N 次后，距下次允许重试的等待时长
    static func backoffInterval(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return 0 }
        let index = min(consecutiveFailures, backoffLadder.count) - 1
        return backoffLadder[index]
    }
}
