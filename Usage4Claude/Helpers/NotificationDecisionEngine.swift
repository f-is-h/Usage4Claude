//
//  NotificationDecisionEngine.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  用量通知阈值判定的纯逻辑核心：不依赖 UserNotifications / UserSettings，
//  只回答"给定当前状态与已通知记录，该发哪些通知、记录该怎么更新"。拆到独立
//  文件是为了能塞进 SwiftPM 测试 target——重复/漏发通知的坑基本都出在这层
//  状态判定（陈旧标志清理、阈值穿越、重置检测），而不是发送通知本身。
//

import Foundation

/// 通知阈值判定需要执行的动作
enum NotificationDecisionAction: Equatable {
    /// 发送「已重置」通知
    case reset
    /// 发送「已达到阈值」通知，附带触发时的百分比
    case warning(percentage: Double)
}

enum NotificationThresholds {
    /// 用量警告阈值（90%）
    static let warning: Double = 90.0
    /// 7天限制的早期警告阈值（75%）
    static let sevenDayEarlyWarning: Double = 75.0
    /// 重置检测阈值：百分比骤降超过此值视为重置
    static let resetDrop: Double = 30.0
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
        if previousPct >= NotificationThresholds.warning && (previousPct - currentPct) > NotificationThresholds.resetDrop {
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

    /// 单个限制类型的通知判定
    /// - Parameters:
    ///   - current: 最新百分比，nil 表示尚无数据（调用方应跳过）
    ///   - previous: 上一次的百分比
    ///   - currentResetsAt/previousResetsAt: 用于重置检测
    ///   - warningKey: 90% 阈值的已通知记录 key
    ///   - earlyWarningKey: 75% 阈值的已通知记录 key；传 nil 表示该类型不做早期预警
    ///   - notifiedWarnings: 当前已通知记录（key -> 所属周期的 resetsAt epoch，0 表示无周期信息）
    /// - Returns: 需要执行的动作（顺序即建议的发送顺序）与更新后的已通知记录
    static func evaluate(
        current: Double?,
        previous: Double?,
        currentResetsAt: Date?,
        previousResetsAt: Date?,
        warningKey: String,
        earlyWarningKey: String?,
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
            warnings.removeValue(forKey: warningKey)
            if let earlyWarningKey {
                warnings.removeValue(forKey: earlyWarningKey)
            }
            return ([.reset], warnings)
        }

        let previousPct = previous ?? 0
        var actions: [NotificationDecisionAction] = []
        let currentCycle = currentResetsAt?.timeIntervalSince1970 ?? 0

        // 陈旧标志清理：持久化的标志若属于旧周期（resetsAt 已变），直接作废。
        // 覆盖"应用未运行期间配额已重置"的场景——那种重置不会走上面的 isReset 分支。
        func clearIfStale(_ key: String) {
            guard currentCycle != 0,
                  let firedCycle = warnings[key], firedCycle != 0,
                  abs(firedCycle - currentCycle) > 1 else { return }
            warnings.removeValue(forKey: key)
        }

        if let earlyWarningKey {
            clearIfStale(earlyWarningKey)
            let alreadyNotifiedEarly = warnings[earlyWarningKey] != nil
            if !alreadyNotifiedEarly
                && previousPct < NotificationThresholds.sevenDayEarlyWarning
                && currentPct >= NotificationThresholds.sevenDayEarlyWarning {
                actions.append(.warning(percentage: currentPct))
                warnings[earlyWarningKey] = currentCycle
            }
        }

        clearIfStale(warningKey)
        let alreadyNotified = warnings[warningKey] != nil
        if !alreadyNotified
            && previousPct < NotificationThresholds.warning
            && currentPct >= NotificationThresholds.warning {
            actions.append(.warning(percentage: currentPct))
            warnings[warningKey] = currentCycle
        }

        return (actions, warnings)
    }
}
