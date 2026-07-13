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

    /// 已通知记录持久化的 UserDefaults key
    private static let notifiedWarningsKey = "notifiedWarnings"

    /// 已通知记录（防止同一账号同一周期内重复通知）
    /// key = provider + accountId + limitType，value = 发送警告时所属周期的 resetsAt epoch（未知时为 0）
    /// 持久化到 UserDefaults：否则应用重启后同一周期内会重复发送已经发过的 90%/75% 警告。
    /// 值记录周期标识而非 Bool：应用未运行期间发生的重置无法被 isReset 的内存对比捕获，
    /// 若不带周期标识，旧周期的标志会永久抑制新周期的警告（见 checkLimit 的陈旧标志清理）。
    private var notifiedWarnings: [String: Double] = [:] {
        didSet {
            UserDefaults.standard.set(notifiedWarnings, forKey: Self.notifiedWarningsKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: Self.notifiedWarningsKey) {
            // 兼容旧的 [String: Bool] 格式：Bool 转成 1.0，与任何真实 resetsAt 都不同，
            // 会在首次检查时被当作陈旧标志清理，行为等同于重新开始记录
            notifiedWarnings = saved.compactMapValues { ($0 as? NSNumber)?.doubleValue }
        }
    }

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

    /// 检查 Codex 用量数据并在需要时发送通知
    /// - Parameters:
    ///   - codexUsageData: 最新的 Codex 用量数据
    ///   - previousData: 上一次的 Codex 用量数据（用于对比变化）
    func checkAndNotify(codexUsageData: CodexUsageData, previousData: CodexUsageData?) {
        checkLimit(
            type: .codexPrimary,
            current: codexUsageData.primary?.percentage,
            previous: previousData?.primary?.percentage,
            currentResetsAt: codexUsageData.primary?.resetsAt,
            previousResetsAt: previousData?.primary?.resetsAt
        )
        checkLimit(
            type: .codexSecondary,
            current: codexUsageData.secondary?.percentage,
            previous: previousData?.secondary?.percentage,
            currentResetsAt: codexUsageData.secondary?.resetsAt,
            previousResetsAt: previousData?.secondary?.resetsAt
        )
        checkLimit(
            type: .codexExtraUsage,
            current: codexUsageData.extraUsage?.percentage,
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
            notifiedWarnings.removeValue(forKey: notificationKey(for: type))
            notifiedWarnings.removeValue(forKey: notificationKey(for: type, suffix: "75"))
            return
        }

        let previousPct = previous ?? 0

        // 陈旧标志清理：持久化的标志若属于旧周期（resetsAt 已变），直接作废。
        // 覆盖"应用未运行期间配额已重置"的场景——那种重置不会走上面的 isReset 分支。
        // currentResetsAt 为 nil（如 Extra Usage）或标志无周期信息（0）时跳过，维持原有行为。
        let currentCycle = currentResetsAt?.timeIntervalSince1970 ?? 0
        func clearIfStale(_ key: String) {
            guard currentCycle != 0,
                  let firedCycle = notifiedWarnings[key], firedCycle != 0,
                  abs(firedCycle - currentCycle) > 1 else { return }
            notifiedWarnings.removeValue(forKey: key)
        }

        // 7天限制额外检查 75% 阈值
        if type == .sevenDay || type == .codexSecondary {
            let earlyKey = notificationKey(for: type, suffix: "75")
            clearIfStale(earlyKey)
            let alreadyNotifiedEarly = notifiedWarnings[earlyKey] != nil
            if !alreadyNotifiedEarly && previousPct < sevenDayEarlyWarningThreshold && currentPct >= sevenDayEarlyWarningThreshold {
                sendUsageWarning(limitType: type, percentage: currentPct)
                notifiedWarnings[earlyKey] = currentCycle
            }
        }

        // 检测是否跨越 90% 阈值
        let warningKey = notificationKey(for: type)
        clearIfStale(warningKey)
        let alreadyNotified = notifiedWarnings[warningKey] != nil
        if !alreadyNotified && previousPct < warningThreshold && currentPct >= warningThreshold {
            sendUsageWarning(limitType: type, percentage: currentPct)
            notifiedWarnings[warningKey] = currentCycle
        }
    }

    private func notificationKey(for type: LimitType, suffix: String? = nil) -> String {
        let accountId: UUID?
        switch type.provider {
        case .claude:
            accountId = UserSettings.shared.currentAccountId
        case .codex:
            accountId = UserSettings.shared.currentCodexAccountId
        }
        return Self.makeNotificationKey(
            provider: type.provider,
            accountId: accountId,
            limitType: type,
            suffix: suffix
        )
    }

    static func makeNotificationKey(
        provider: ProviderType,
        accountId: UUID?,
        limitType: LimitType,
        suffix: String? = nil
    ) -> String {
        var key = "\(provider.rawValue):\(accountId?.uuidString ?? "none"):\(limitType.rawValue)"
        if let suffix {
            key += ":\(suffix)"
        }
        return key
    }

    static func makeAccountNotificationKeyPrefix(provider: ProviderType, accountId: UUID?) -> String {
        "\(provider.rawValue):\(accountId?.uuidString ?? "none"):"
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

    /// 发送 Codex 登录已过期系统通知（仅发送一次，不重复打扰）
    /// 由调用方负责去重控制（DataRefreshManager.codexSessionExpiredNotified）
    func sendCodexSessionExpiredNotification() {
        let content = UNMutableNotificationContent()
        content.title = L.UsageNotification.codexSessionExpiredTitle
        content.body = L.UsageNotification.codexSessionExpiredBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex_session_expired",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.menuBar.error("发送 Codex 过期通知失败: \(error.localizedDescription)")
            }
        }

        Logger.menuBar.info("已发送 Codex 登录过期通知")
    }

    /// 重置所有已通知记录
    func resetAllNotificationStates() {
        notifiedWarnings.removeAll()
    }

    /// 重置指定账号的已通知记录
    func resetNotificationStates(for provider: ProviderType, accountId: UUID?) {
        let prefix = Self.makeAccountNotificationKeyPrefix(provider: provider, accountId: accountId)
        notifiedWarnings = notifiedWarnings.filter { key, _ in
            !key.hasPrefix(prefix)
        }
    }

}
