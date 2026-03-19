//
//  NotificationManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-17.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import UserNotifications
import OSLog

/// 用量通知管理器
/// 负责在用量达到阈值或重置时发送 macOS 系统通知
class NotificationManager {
    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Constants

    /// 用量警告阈值（90%）
    private let warningThreshold: Double = 90.0

    /// 7天限制的早期警告阈值（75%）
    private let sevenDayEarlyWarningThreshold: Double = 75.0

    /// 重置检测阈值：百分比骤降超过此值视为重置
    private let resetDropThreshold: Double = 30.0

    // MARK: - State

    /// 已通知记录（防止同一周期内重复通知）
    /// key = LimitType.rawValue, value = true 表示已发送过警告
    private var notifiedWarnings: [String: Bool] = [:]

    private init() {}

    // MARK: - Permission

    /// 请求通知权限
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.menuBar.error("请求通知权限失败: \(error.localizedDescription)")
            }
            Logger.menuBar.info("通知权限: \(granted ? "已授权" : "未授权")")
        }
    }

    // MARK: - Check & Notify

    /// 检查用量数据并在需要时发送通知
    /// - Parameters:
    ///   - usageData: 最新的用量数据
    ///   - previousData: 上一次的用量数据（用于对比变化）
    func checkAndNotify(usageData: UsageData, previousData: UsageData?) {
        // 逐个限制类型检查
        checkLimit(
            type: .fiveHour,
            current: usageData.fiveHour?.percentage,
            previous: previousData?.fiveHour?.percentage,
            currentResetsAt: usageData.fiveHour?.resetsAt,
            previousResetsAt: previousData?.fiveHour?.resetsAt
        )
        checkLimit(
            type: .sevenDay,
            current: usageData.sevenDay?.percentage,
            previous: previousData?.sevenDay?.percentage,
            currentResetsAt: usageData.sevenDay?.resetsAt,
            previousResetsAt: previousData?.sevenDay?.resetsAt
        )
        checkLimit(
            type: .opusWeekly,
            current: usageData.opus?.percentage,
            previous: previousData?.opus?.percentage,
            currentResetsAt: usageData.opus?.resetsAt,
            previousResetsAt: previousData?.opus?.resetsAt
        )
        checkLimit(
            type: .sonnetWeekly,
            current: usageData.sonnet?.percentage,
            previous: previousData?.sonnet?.percentage,
            currentResetsAt: usageData.sonnet?.resetsAt,
            previousResetsAt: previousData?.sonnet?.resetsAt
        )

        // Extra Usage 单独处理
        checkLimit(
            type: .extraUsage,
            current: usageData.extraUsage?.percentage,
            previous: previousData?.extraUsage?.percentage,
            currentResetsAt: nil,
            previousResetsAt: nil
        )
    }

    // MARK: - Private Methods

    /// 检查单个限制类型的用量变化
    private func checkLimit(
        type: LimitType,
        current: Double?,
        previous: Double?,
        currentResetsAt: Date?,
        previousResetsAt: Date?
    ) {
        guard let currentPct = current else { return }

        // 检测重置：百分比骤降 或 resetsAt 发生变化
        if let previousPct = previous, isReset(
            currentPct: currentPct,
            previousPct: previousPct,
            currentResetsAt: currentResetsAt,
            previousResetsAt: previousResetsAt
        ) {
            sendResetNotification(limitType: type)
            notifiedWarnings.removeValue(forKey: type.rawValue)
            notifiedWarnings.removeValue(forKey: "\(type.rawValue)_75")
            return
        }

        let previousPct = previous ?? 0

        // 7天限制额外检查 75% 阈值
        if type == .sevenDay {
            let earlyKey = "\(type.rawValue)_75"
            let alreadyNotifiedEarly = notifiedWarnings[earlyKey] ?? false
            if !alreadyNotifiedEarly && previousPct < sevenDayEarlyWarningThreshold && currentPct >= sevenDayEarlyWarningThreshold {
                sendUsageWarning(limitType: type, percentage: currentPct)
                notifiedWarnings[earlyKey] = true
            }
        }

        // 检测是否跨越 90% 阈值
        let alreadyNotified = notifiedWarnings[type.rawValue] ?? false
        if !alreadyNotified && previousPct < warningThreshold && currentPct >= warningThreshold {
            sendUsageWarning(limitType: type, percentage: currentPct)
            notifiedWarnings[type.rawValue] = true
        }
    }

    /// 判断是否发生了重置
    private func isReset(
        currentPct: Double,
        previousPct: Double,
        currentResetsAt: Date?,
        previousResetsAt: Date?
    ) -> Bool {
        // 百分比骤降（从较高值降到较低值）
        if previousPct >= warningThreshold && (previousPct - currentPct) > resetDropThreshold {
            return true
        }

        // resetsAt 发生了变化（新的重置周期）
        if let current = currentResetsAt, let previous = previousResetsAt {
            if abs(current.timeIntervalSince(previous)) > 1.0 {
                // resetsAt 变了，且百分比也下降了，确认是重置
                if currentPct < previousPct {
                    return true
                }
            }
        }

        return false
    }

    /// 发送用量警告通知
    private func sendUsageWarning(limitType: LimitType, percentage: Double) {
        let content = UNMutableNotificationContent()
        content.title = L.UsageNotification.warningTitle
        content.body = L.UsageNotification.warningBody(limitType.displayName, Int(percentage))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage_warning_\(limitType.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.menuBar.error("发送用量警告通知失败: \(error.localizedDescription)")
            }
        }

        Logger.menuBar.info("已发送用量警告: \(limitType.displayName) \(Int(percentage))%")
    }

    /// 发送用量重置通知
    private func sendResetNotification(limitType: LimitType) {
        let content = UNMutableNotificationContent()
        content.title = L.UsageNotification.resetTitle
        content.body = L.UsageNotification.resetBody(limitType.displayName)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage_reset_\(limitType.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.menuBar.error("发送重置通知失败: \(error.localizedDescription)")
            }
        }

        Logger.menuBar.info("已发送重置通知: \(limitType.displayName)")
    }

    /// 重置所有已通知记录
    func resetAllNotificationStates() {
        notifiedWarnings.removeAll()
    }
}
