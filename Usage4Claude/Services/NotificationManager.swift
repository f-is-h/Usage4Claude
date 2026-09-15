//
//  NotificationManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-17.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Combine
import Foundation
import UserNotifications

/// 用量通知管理器
/// 负责在用量达到阈值或重置时发送 macOS 系统通知
/// 继承 NSObject 是 UNUserNotificationCenterDelegate 的协议要求
final class NotificationManager: NSObject, ObservableObject {
    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - State

    /// 最近一次数据里是否有额外用量（Claude Extra Usage 或 Codex credits）。
    /// 设置页据此决定是否显示额外用量的阈值滑块——设置页拿不到 DataRefreshManager
    @Published private(set) var hasExtraUsage = false

    private var claudeHasExtraUsage = false
    private var codexHasExtraUsage = false

    /// 已通知记录持久化的 UserDefaults key
    private static let notifiedWarningsKey = "notifiedWarnings"

    /// 已通知记录（防止同一账号同一周期内重复通知）
    /// key 规则见 `NotificationKeys`，value = 发送警告时所属周期的 resetsAt epoch（未知时为 0）
    /// 持久化到 UserDefaults：否则应用重启后同一周期内会重复发送已经发过的警告。
    /// 值记录周期标识而非 Bool：应用未运行期间发生的重置无法被 isReset 的内存对比捕获，
    /// 若不带周期标识，旧周期的标志会永久抑制新周期的警告（见 NotificationDecisionEngine 的陈旧记录清理）。
    private var notifiedWarnings: [String: Double] = [:] {
        didSet {
            UserDefaults.standard.set(notifiedWarnings, forKey: Self.notifiedWarningsKey)
        }
    }

    /// 每个限额最近一次读数，key 为限额前缀（含账号）。只存内存，
    /// 供用户调整阈值时判断哪些阈值已经低于当前用量
    private var latestReadings: [String: Reading] = [:]

    private struct Reading {
        let category: NotificationCategory
        let percentage: Double
        let resetsAt: Date?
    }

    private override init() {
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: Self.notifiedWarningsKey) {
            // 兼容旧的 [String: Bool] 格式：Bool 转成 1.0，与任何真实 resetsAt 都不同，
            // 会在首次检查时被当作陈旧标志清理，行为等同于重新开始记录
            let values = saved.compactMapValues { ($0 as? NSNumber)?.doubleValue }
            // 旧版 90% 警告的 key 没有阈值后缀，迁移到按阈值存储的新格式
            notifiedWarnings = NotificationKeys.migrateLegacy(values)
        }
        // 不设置 delegate 时，macOS 会静默丢弃前台应用的通知（add 成功、无任何报错）。
        // 本应用打开设置窗口/弹窗时恰好处于前台激活状态——用量警告最常在这时触发。
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    /// 请求通知权限
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                AppLog.error(.settings, "Requesting notification permission failed: \(error.localizedDescription)")
            }
            AppLog.event(.settings, "Notification permission \(granted ? "granted" : "denied")")
        }
    }

    // MARK: - Check & Notify

    /// 检查用量数据并在需要时发送通知
    /// - Parameters:
    ///   - usageData: 最新的用量数据
    ///   - previousData: 上一次的用量数据（用于对比变化）
    func checkAndNotify(usageData: UsageData, previousData: UsageData?) {
        let accountId = UserSettings.shared.currentAccountId

        checkLimit(
            provider: .claude,
            accountId: accountId,
            limitId: LimitType.fiveHour.rawValue,
            displayName: LimitType.fiveHour.displayName,
            category: .fiveHour,
            current: usageData.fiveHour?.percentage,
            previous: previousData?.fiveHour?.percentage,
            currentResetsAt: usageData.fiveHour?.resetsAt,
            previousResetsAt: previousData?.fiveHour?.resetsAt
        )
        checkLimit(
            provider: .claude,
            accountId: accountId,
            limitId: LimitType.sevenDay.rawValue,
            displayName: LimitType.sevenDay.displayName,
            category: .weekly,
            current: usageData.sevenDay?.percentage,
            previous: previousData?.sevenDay?.percentage,
            currentResetsAt: usageData.sevenDay?.resetsAt,
            previousResetsAt: previousData?.sevenDay?.resetsAt
        )

        // 模型周限额：遍历全部模型（菜单栏只显示前两个，提醒不能漏掉第三个及以后的）。
        // 上一次数据按限额标识对齐而不是按下标——API 返回顺序变了也不会拿错模型比较
        let previousModels = Dictionary(
            (previousData?.weeklyModels ?? []).enumerated().map {
                (Self.weeklyModelLimitId($0.element, index: $0.offset), $0.element.limit)
            },
            uniquingKeysWith: { first, _ in first }
        )
        for (index, model) in usageData.weeklyModels.enumerated() {
            let limitId = Self.weeklyModelLimitId(model, index: index)
            let previous = previousModels[limitId]
            checkLimit(
                provider: .claude,
                accountId: accountId,
                limitId: limitId,
                displayName: Self.weeklyModelDisplayName(model, index: index),
                category: .weekly,
                current: model.limit.percentage,
                previous: previous?.percentage,
                currentResetsAt: model.limit.resetsAt,
                previousResetsAt: previous?.resetsAt
            )
        }

        // Extra Usage 没有重置时间
        checkLimit(
            provider: .claude,
            accountId: accountId,
            limitId: LimitType.extraUsage.rawValue,
            displayName: LimitType.extraUsage.displayName,
            category: .extraUsage,
            current: usageData.extraUsage?.percentage,
            previous: previousData?.extraUsage?.percentage,
            currentResetsAt: nil,
            previousResetsAt: nil
        )

        // 额外用量走单独的请求，失败时为 nil：沿用上次的判断，免得设置里的滑块时有时无
        if let extraUsage = usageData.extraUsage {
            claudeHasExtraUsage = extraUsage.enabled && extraUsage.percentage != nil
            updateHasExtraUsage()
        }
    }

    /// 检查 Codex 用量数据并在需要时发送通知
    /// - Parameters:
    ///   - codexUsageData: 最新的 Codex 用量数据
    ///   - previousData: 上一次的 Codex 用量数据（用于对比变化）
    func checkAndNotify(codexUsageData: CodexUsageData, previousData: CodexUsageData?) {
        let accountId = UserSettings.shared.currentCodexAccountId

        checkLimit(
            provider: .codex,
            accountId: accountId,
            limitId: LimitType.codexPrimary.rawValue,
            displayName: LimitType.codexPrimary.displayName,
            category: .fiveHour,
            current: codexUsageData.primary?.percentage,
            previous: previousData?.primary?.percentage,
            currentResetsAt: codexUsageData.primary?.resetsAt,
            previousResetsAt: previousData?.primary?.resetsAt
        )
        checkLimit(
            provider: .codex,
            accountId: accountId,
            limitId: LimitType.codexSecondary.rawValue,
            displayName: LimitType.codexSecondary.displayName,
            category: .weekly,
            current: codexUsageData.secondary?.percentage,
            previous: previousData?.secondary?.percentage,
            currentResetsAt: codexUsageData.secondary?.resetsAt,
            previousResetsAt: previousData?.secondary?.resetsAt
        )
        checkLimit(
            provider: .codex,
            accountId: accountId,
            limitId: LimitType.codexExtraUsage.rawValue,
            displayName: LimitType.codexExtraUsage.displayName,
            category: .extraUsage,
            current: codexUsageData.extraUsage?.percentage,
            previous: previousData?.extraUsage?.percentage,
            currentResetsAt: nil,
            previousResetsAt: nil
        )

        if let extraUsage = codexUsageData.extraUsage {
            codexHasExtraUsage = extraUsage.enabled && extraUsage.percentage != nil
            updateHasExtraUsage()
        }
    }

    /// 用户调整阈值后调用：已经低于当前用量的阈值直接记为本周期已提醒，不补发通知
    func applyThresholdChange(_ config: NotificationThresholdConfig) {
        var warnings = notifiedWarnings
        for (limitPrefix, reading) in latestReadings {
            warnings = NotificationDecisionEngine.silenceReached(
                current: reading.percentage,
                currentResetsAt: reading.resetsAt,
                limitPrefix: limitPrefix,
                thresholds: config.thresholds(for: reading.category),
                notifiedWarnings: warnings
            )
        }
        if warnings != notifiedWarnings {
            notifiedWarnings = warnings
        }
    }

    // MARK: - Private Methods

    /// 检查单个限额的用量变化
    /// 状态判定交给纯函数 `NotificationDecisionEngine.evaluate`（见该文件），
    /// 这里只负责拼 key、读阈值、把返回的 actions 落地成真实的系统通知
    private func checkLimit(
        provider: ProviderType,
        accountId: UUID?,
        limitId: String,
        displayName: String,
        category: NotificationCategory,
        current: Double?,
        previous: Double?,
        currentResetsAt: Date?,
        previousResetsAt: Date?
    ) {
        let limitPrefix = NotificationKeys.limitPrefix(provider: provider, accountId: accountId, limitId: limitId)
        let thresholds = UserSettings.shared.notificationThresholds.thresholds(for: category)

        if let current {
            latestReadings[limitPrefix] = Reading(category: category, percentage: current, resetsAt: currentResetsAt)
        }

        let (actions, updatedWarnings) = NotificationDecisionEngine.evaluate(
            current: current,
            previous: previous,
            currentResetsAt: currentResetsAt,
            previousResetsAt: previousResetsAt,
            // 额外用量按月结算，接口不给重置时间
            hasResetTime: category != .extraUsage,
            limitPrefix: limitPrefix,
            thresholds: thresholds,
            notifiedWarnings: notifiedWarnings
        )
        // 只在真正变化时赋值：notifiedWarnings 的 didSet 会写 UserDefaults，
        // 无条件赋值会导致每次 checkLimit 调用都触发一次磁盘写入
        if updatedWarnings != notifiedWarnings {
            notifiedWarnings = updatedWarnings
        }

        // 关闭通知时照常判定、照常记录，只是不发送：否则关闭期间越过的阈值，
        // 会在重新开启后 previous 为 nil 的下一次判定（重启应用、切换账号）时被补发出来
        guard UserSettings.shared.notificationsEnabled else { return }

        for action in actions {
            switch action {
            case .reset:
                sendResetNotification(limitId: limitId, displayName: displayName)
            case .warning(let percentage):
                sendUsageWarning(limitId: limitId, displayName: displayName, percentage: percentage)
            }
        }
    }

    /// 模型周限额的标识。有模型名时按模型名（API 的 scope.model.id 目前为 null，不可用）；
    /// 旧版 seven_day_opus / seven_day_sonnet 字段没有模型名，沿用原来的 LimitType 标识，已有记录继续有效
    private static func weeklyModelLimitId(_ model: UsageData.WeeklyModelLimit, index: Int) -> String {
        if let name = model.modelName, !name.isEmpty {
            return "model_\(name)"
        }
        switch index {
        case 0: return LimitType.opusWeekly.rawValue
        case 1: return LimitType.sonnetWeekly.rawValue
        default: return "model_slot_\(index)"
        }
    }

    /// 模型周限额在通知里的名称：有模型名时用真实模型名，否则回退到按槽位的 Opus/Sonnet 文案
    private static func weeklyModelDisplayName(_ model: UsageData.WeeklyModelLimit, index: Int) -> String {
        if let name = model.modelName, !name.isEmpty {
            return L.UsageNotification.modelWeeklyLimit(name)
        }
        return index == 0 ? LimitType.opusWeekly.displayName : LimitType.sonnetWeekly.displayName
    }

    private func updateHasExtraUsage() {
        let value = claudeHasExtraUsage || codexHasExtraUsage
        if hasExtraUsage != value {
            hasExtraUsage = value
        }
    }

    /// 发送用量警告通知
    private func sendUsageWarning(limitId: String, displayName: String, percentage: Double) {
        let content = UNMutableNotificationContent()
        content.title = L.UsageNotification.warningTitle
        content.body = L.UsageNotification.warningBody(displayName, Int(percentage))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage_warning_\(limitId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLog.error(.settings, "Delivering the usage warning notification failed: \(error.localizedDescription)")
            }
        }

        AppLog.event(.settings, "Delivered a usage warning notification: \(limitId) at \(Int(percentage))%")
    }

    /// 发送用量重置通知
    private func sendResetNotification(limitId: String, displayName: String) {
        let content = UNMutableNotificationContent()
        content.title = L.UsageNotification.resetTitle
        content.body = L.UsageNotification.resetBody(displayName)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage_reset_\(limitId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLog.error(.settings, "Delivering the limit reset notification failed: \(error.localizedDescription)")
            }
        }

        AppLog.event(.settings, "Delivered a limit reset notification: \(limitId)")
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
                AppLog.error(.settings, "Delivering the Codex session expiry notification failed: \(error.localizedDescription)")
            }
        }

        AppLog.event(.settings, "Delivered a Codex session expiry notification")
    }

    /// 重置所有已通知记录
    func resetAllNotificationStates() {
        notifiedWarnings.removeAll()
        latestReadings.removeAll()
    }

    /// 重置指定账号的已通知记录
    func resetNotificationStates(for provider: ProviderType, accountId: UUID?) {
        let prefix = NotificationKeys.accountPrefix(provider: provider, accountId: accountId)
        notifiedWarnings = notifiedWarnings.filter { key, _ in
            !key.hasPrefix(prefix)
        }
        latestReadings = latestReadings.filter { key, _ in
            !key.hasPrefix(prefix)
        }
    }

}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 应用处于前台时也照常显示横幅和声音
    /// （系统默认行为是前台静默丢弃；菜单栏应用打开设置窗口或弹窗时即为前台）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
