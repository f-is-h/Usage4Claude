//
//  NotificationDecisionEngine.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  用量通知阈值判定的纯逻辑核心：不依赖 UserNotifications / UserSettings，
//  只回答"给定当前状态与已通知记录，该发哪些通知、记录该怎么更新"。拆到独立
//  文件是为了能塞进 SwiftPM 测试 target——重复/漏发通知的坑基本都出在这层
//  状态判定（陈旧标志清理、阈值穿越、重置检测、阈值调整），而不是发送通知本身。
//

import Foundation

/// 通知阈值判定需要执行的动作
enum NotificationDecisionAction: Equatable {
    /// 发送「已重置」通知
    case reset
    /// 发送「已达到阈值」通知，附带触发时的百分比。一次跨过多档也只产生一个
    case warning(percentage: Double)
}

/// 重置检测常量。刻意与用户设置的提醒阈值脱钩：阈值可以调到 50%，
/// 但"从 60% 降到 25%"不能因此被当成一次重置
enum NotificationResetDetection {
    /// 百分比骤降检测只在之前的用量不低于此值时生效
    static let dropFloor: Double = 90.0
    /// 降幅超过此值视为重置
    static let minimumDrop: Double = 30.0
}

/// 提醒阈值的分类：Claude 与 Codex 共用，也不区分具体模型
enum NotificationCategory {
    /// 5 小时限额（Claude 5 小时、Codex primary）
    case fiveHour
    /// 周限额（Claude 7 天、Codex secondary、所有模型周限额）
    case weekly
    /// 额外用量（Claude Extra Usage、Codex credits）
    case extraUsage
}

/// 用户设置的提醒阈值（整数百分比）
struct NotificationThresholdConfig: Equatable, Codable {
    static let range = 50...100
    static let step = 5
    /// 5 小时与周限额沿用改版前写死的阈值。额外用量改版前只有 90% 一档，现在与周限额一样两档：
    /// 按月计算、周期最长，又涉及真金白银，提前提醒更有价值
    static let `default` = NotificationThresholdConfig(
        fiveHour: 90,
        weeklyLower: 75,
        weeklyUpper: 90,
        extraUsageLower: 75,
        extraUsageUpper: 90
    )

    var fiveHour: Int
    /// 两档阈值中数值较小的一个（第一次提醒）。与对应的 upper 相等时只提醒一次
    var weeklyLower: Int
    var weeklyUpper: Int
    var extraUsageLower: Int
    var extraUsageUpper: Int

    /// 夹到允许范围并吸附到步长
    static func sanitize(_ value: Int) -> Int {
        let snapped = Int((Double(value) / Double(step)).rounded()) * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }

    /// 所有值合法化，并保证两档阈值 lower <= upper（持久化数据可能来自手改或旧版本）
    var sanitized: NotificationThresholdConfig {
        let weekly = Self.sanitizedPair(weeklyLower, weeklyUpper)
        let extraUsage = Self.sanitizedPair(extraUsageLower, extraUsageUpper)
        return NotificationThresholdConfig(
            fiveHour: Self.sanitize(fiveHour),
            weeklyLower: weekly.lower,
            weeklyUpper: weekly.upper,
            extraUsageLower: extraUsage.lower,
            extraUsageUpper: extraUsage.upper
        )
    }

    /// 某一类的阈值：升序、去重
    func thresholds(for category: NotificationCategory) -> [Int] {
        switch category {
        case .fiveHour:
            return [fiveHour]
        case .weekly:
            return Array(Set([weeklyLower, weeklyUpper])).sorted()
        case .extraUsage:
            return Array(Set([extraUsageLower, extraUsageUpper])).sorted()
        }
    }

    private static func sanitizedPair(_ first: Int, _ second: Int) -> (lower: Int, upper: Int) {
        let a = sanitize(first)
        let b = sanitize(second)
        return (min(a, b), max(a, b))
    }
}

/// 已通知记录的 key 规则：`provider:accountId:limitId:threshold`。
/// 同一限额的所有阈值共享前缀 `provider:accountId:limitId:`，便于整体清理；
/// 前缀以冒号结尾，`seven_day:` 才不会误匹配到 `seven_day_opus:`
enum NotificationKeys {
    static func accountPrefix(provider: ProviderType, accountId: UUID?) -> String {
        "\(provider.rawValue):\(accountId?.uuidString ?? "none"):"
    }

    static func limitPrefix(provider: ProviderType, accountId: UUID?, limitId: String) -> String {
        accountPrefix(provider: provider, accountId: accountId) + "\(limitId):"
    }

    static func key(limitPrefix: String, threshold: Int) -> String {
        limitPrefix + String(threshold)
    }

    /// 解析 key 属于该限额的哪个阈值；不属于该限额或尾部不是整数时返回 nil
    static func threshold(of key: String, limitPrefix: String) -> Int? {
        guard key.hasPrefix(limitPrefix) else { return nil }
        return Int(key.dropFirst(limitPrefix.count))
    }

    /// 迁移旧版 key。旧版 90% 警告的 key 没有阈值后缀（`provider:accountId:limitType`），
    /// 75% 早期预警是 `...:75`，恰好已是新格式，只需给前者补上 `:90`。
    /// 可重复执行；新旧 key 同时存在时保留新 key
    static func migrateLegacy(_ warnings: [String: Double]) -> [String: Double] {
        var migrated: [String: Double] = [:]
        for (key, cycle) in warnings where key.split(separator: ":", omittingEmptySubsequences: false).count != 3 {
            migrated[key] = cycle
        }
        for (key, cycle) in warnings where key.split(separator: ":", omittingEmptySubsequences: false).count == 3 {
            let newKey = key + ":90"
            if migrated[newKey] == nil {
                migrated[newKey] = cycle
            }
        }
        return migrated
    }
}

enum NotificationDecisionEngine {

    /// 判断是否发生了重置
    static func isReset(
        currentPct: Double,
        previousPct: Double,
        currentResetsAt: Date?,
        previousResetsAt: Date?
    ) -> Bool {
        // 百分比骤降（从较高值降到较低值）
        if previousPct >= NotificationResetDetection.dropFloor
            && (previousPct - currentPct) > NotificationResetDetection.minimumDrop {
            return true
        }

        // resetsAt 发生了变化（新的重置周期），且百分比也下降了，确认是重置
        if let current = currentResetsAt, let previous = previousResetsAt,
           abs(current.timeIntervalSince(previous)) > 1.0,
           currentPct < previousPct {
            return true
        }

        return false
    }

    /// 单个限额的通知判定
    /// - Parameters:
    ///   - current: 最新百分比，nil 表示尚无数据（直接跳过）
    ///   - previous: 上一次的百分比。nil（刚启动或刚切换账号）按 0 处理，
    ///     应用未运行期间越过的阈值会在首次刷新时补发
    ///   - currentResetsAt/previousResetsAt: 用于重置检测与周期识别
    ///   - hasResetTime: 该限额是否带重置时间。额外用量没有，用量回落到阈值以下时据此重新提醒
    ///   - limitPrefix: 该限额已通知记录的 key 前缀（见 `NotificationKeys`）
    ///   - thresholds: 该限额的提醒阈值
    ///   - notifiedWarnings: 当前已通知记录（key -> 所属周期的 resetsAt epoch，0 表示无周期信息）
    /// - Returns: 需要执行的动作与更新后的已通知记录
    static func evaluate(
        current: Double?,
        previous: Double?,
        currentResetsAt: Date?,
        previousResetsAt: Date?,
        hasResetTime: Bool,
        limitPrefix: String,
        thresholds: [Int],
        notifiedWarnings: [String: Double]
    ) -> (actions: [NotificationDecisionAction], updatedWarnings: [String: Double]) {
        guard let currentPct = current else { return ([], notifiedWarnings) }
        var warnings = notifiedWarnings

        if let previousPct = previous, isReset(
            currentPct: currentPct,
            previousPct: previousPct,
            currentResetsAt: currentResetsAt,
            previousResetsAt: previousResetsAt
        ) {
            warnings.keys.filter { $0.hasPrefix(limitPrefix) }.forEach { warnings.removeValue(forKey: $0) }
            return ([.reset], warnings)
        }

        removeOrphans(in: &warnings, limitPrefix: limitPrefix, thresholds: thresholds)

        let previousPct = previous ?? 0
        let currentCycle = currentResetsAt?.timeIntervalSince1970 ?? 0
        var crossed: [Int] = []

        for threshold in thresholds {
            let key = NotificationKeys.key(limitPrefix: limitPrefix, threshold: threshold)
            let value = Double(threshold)

            if let firedCycle = warnings[key] {
                // 陈旧记录：属于旧周期（resetsAt 已变），覆盖"应用未运行期间配额已重置"——
                // 那种重置不会走上面的 isReset 分支。
                // 没有重置时间的限额（额外用量）：用量回落到阈值以下只可能是月度重置或上限被调高，
                // 都该重新提醒；阈值低于骤降检测起点时 isReset 捕获不到，不清掉会永久抑制提醒。
                // 只看 hasResetTime 而不看本次 resetsAt 是否为 nil：7 天限额缺数据时的占位值同样是
                // 0% + nil，按 nil 判断会清掉记录，接口恢复后重复提醒
                if isStale(firedCycle: firedCycle, currentCycle: currentCycle)
                    || (!hasResetTime && currentPct < value) {
                    warnings.removeValue(forKey: key)
                } else {
                    continue
                }
            }

            if previousPct < value && currentPct >= value {
                crossed.append(threshold)
            }
        }

        guard !crossed.isEmpty else { return ([], warnings) }
        // 跨过的每一档都记下，但只发一条：一次刷新从 10% 跳到 95% 不该连发两条同样的"已达到 95%"
        for threshold in crossed {
            warnings[NotificationKeys.key(limitPrefix: limitPrefix, threshold: threshold)] = currentCycle
        }
        return ([.warning(percentage: currentPct)], warnings)
    }

    /// 用户调整阈值后调用：已经不高于当前用量的阈值直接记为本周期已提醒，不发通知。
    /// 用户调设置时看得到当前用量，没必要补发；但若什么都不记，previous 为 nil 的下一次判定
    /// （重启应用、切换账号后）会把它当成"应用未运行期间越过的阈值"补发出来
    static func silenceReached(
        current: Double,
        currentResetsAt: Date?,
        limitPrefix: String,
        thresholds: [Int],
        notifiedWarnings: [String: Double]
    ) -> [String: Double] {
        var warnings = notifiedWarnings
        removeOrphans(in: &warnings, limitPrefix: limitPrefix, thresholds: thresholds)
        let currentCycle = currentResetsAt?.timeIntervalSince1970 ?? 0

        for threshold in thresholds where current >= Double(threshold) {
            let key = NotificationKeys.key(limitPrefix: limitPrefix, threshold: threshold)
            if let firedCycle = warnings[key], !isStale(firedCycle: firedCycle, currentCycle: currentCycle) {
                continue
            }
            warnings[key] = currentCycle
        }
        return warnings
    }

    // MARK: - Private

    /// 持久化记录是否属于旧周期。任一侧没有周期信息（0）时不做判断
    private static func isStale(firedCycle: Double, currentCycle: Double) -> Bool {
        currentCycle != 0 && firedCycle != 0 && abs(firedCycle - currentCycle) > 1
    }

    /// 删除该限额下已不在当前阈值里的记录（用户改过阈值后遗留的）
    private static func removeOrphans(in warnings: inout [String: Double], limitPrefix: String, thresholds: [Int]) {
        let orphans = warnings.keys.filter { key in
            guard let threshold = NotificationKeys.threshold(of: key, limitPrefix: limitPrefix) else { return false }
            return !thresholds.contains(threshold)
        }
        orphans.forEach { warnings.removeValue(forKey: $0) }
    }
}
