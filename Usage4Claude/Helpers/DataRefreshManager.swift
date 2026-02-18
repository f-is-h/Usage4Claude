//
//  DataRefreshManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine
import OSLog

/// 数据刷新管理器
/// 负责管理所有数据刷新、定时器、更新检查和重置验证逻辑
class DataRefreshManager: ObservableObject {

    // MARK: - Dependencies

    /// Claude API 服务实例
    private let apiService = ClaudeAPIService()
    /// 更新检查器实例
    private let updateChecker = UpdateChecker()
    /// 定时器管理器
    private let timerManager = TimerManager()
    /// 用户设置实例
    private let settings = UserSettings.shared

    // MARK: - Published State

    /// 当前用量数据
    @Published var usageData: UsageData?
    /// 加载状态
    @Published var isLoading = false
    /// 错误消息
    @Published var errorMessage: String?
    /// 是否有可用更新
    @Published var hasAvailableUpdate = false
    /// 最新版本号
    @Published var latestVersion: String?
    /// 刷新状态管理器
    let refreshState = RefreshState()

    // MARK: - Private State

    /// 上次的重置时间（用于检测重置是否完成）
    private var lastResetsAt: Date?
    /// 上次手动刷新时间
    private var lastManualRefreshTime: Date?
    /// 上次API请求时间
    private var lastAPIFetchTime: Date?
    /// 刷新动画开始时间（用于确保动画最小显示时长）
    private var refreshAnimationStartTime: Date?
    /// 动画最小显示时长（秒）
    private let minimumAnimationDuration: TimeInterval = 1.0
    /// 上次检查更新时间
    private var lastUpdateCheckTime: Date?
    /// App Nap 防护活动令牌
    private var refreshActivity: NSObjectProtocol?

    // MARK: - Timer Identifiers

    /// 定时器标识符
    private enum TimerID {
        static let mainRefresh = "mainRefresh"
        static let popoverRefresh = "popoverRefresh"
        static let resetVerify1 = "resetVerify1"
        static let resetVerify2 = "resetVerify2"
        static let resetVerify3 = "resetVerify3"
        static let dailyUpdate = "dailyUpdate"
    }

    // MARK: - Initialization

    init() {
        scheduleDailyUpdateCheck()
    }

    // MARK: - Data Fetching

    /// 获取用量数据
    /// 调用 API 服务获取最新的使用情况
    func fetchUsage() {
        isLoading = true
        errorMessage = nil

        // 记录本次API请求时间
        lastAPIFetchTime = Date()

        apiService.fetchUsage { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                // 确保动画至少显示最小时长
                self.endRefreshAnimationWithMinimumDuration {
                }

                switch result {
                case .success(let data):
                    let previousData = self.usageData
                    self.usageData = data
                    self.errorMessage = nil

                    // 检查是否需要发送用量通知
                    if self.settings.notificationsEnabled {
                        NotificationManager.shared.checkAndNotify(usageData: data, previousData: previousData)
                    }

                    // 智能模式：根据百分比变化调整刷新频率
                    self.settings.updateSmartMonitoringMode(currentUtilization: data.percentage)

                    // 检测重置时间是否发生变化
                    let newResetsAt = data.resetsAt
                    let hasResetChanged = self.hasResetTimeChanged(from: self.lastResetsAt, to: newResetsAt)

                    if hasResetChanged {
                        // 重置时间发生变化，取消所有待执行的验证
                        self.cancelResetVerification()
                    } else {
                        // 重置时间未变化，安排验证
                        if let resetsAt = newResetsAt {
                            self.scheduleResetVerification(resetsAt: resetsAt)
                        }
                    }

                    // 更新上次的重置时间
                    self.lastResetsAt = newResetsAt

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    Logger.menuBar.error("API 请求失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 开始数据刷新
    /// 立即获取一次数据并启动定时器
    func startRefreshing() {
        beginRefreshActivity()
        fetchUsage()
        restartTimer()

        #if DEBUG
        // 🧪 测试：确保图标显示徽章
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.objectWillChange.send()
        }
        #endif
    }

    /// 停止数据刷新
    func stopRefreshing() {
        timerManager.invalidate(TimerID.mainRefresh)
        endRefreshActivity()
    }

    /// 启动 Popover 刷新定时器
    /// 用于在 popover 打开时以 1 秒间隔触发 UI 更新
    /// - Parameter updateHandler: 每秒调用的更新闭包
    func startPopoverRefreshTimer(updateHandler: @escaping () -> Void) {
        timerManager.schedule(TimerID.popoverRefresh, interval: 1.0, repeats: true) {
            updateHandler()
        }
    }

    /// 停止 Popover 刷新定时器
    func stopPopoverRefreshTimer() {
        timerManager.invalidate(TimerID.popoverRefresh)
    }

    /// 重启刷新定时器
    /// 根据用户设置的刷新频率重新创建定时器
    private func restartTimer() {
        timerManager.invalidate(TimerID.mainRefresh)
        let interval = TimeInterval(settings.effectiveRefreshInterval)
        timerManager.schedule(TimerID.mainRefresh, interval: interval, repeats: true) { [weak self] in
            self?.fetchUsage()
        }
    }

    // MARK: - App Nap Prevention

    /// 开始后台活动声明，防止 macOS App Nap 冻结定时器
    private func beginRefreshActivity() {
        guard refreshActivity == nil else { return }
        refreshActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Periodic usage data refresh"
        )
    }

    /// 结束后台活动声明
    private func endRefreshActivity() {
        if let activity = refreshActivity {
            ProcessInfo.processInfo.endActivity(activity)
            refreshActivity = nil
        }
    }

    // MARK: - Smart Refresh

    /// 打开Popover时的智能刷新
    /// 如果距离上次刷新 > 30秒，则立即刷新数据
    func refreshOnPopoverOpen() {
        let now = Date()

        // 用户打开详细界面，强制切换到活跃模式（1分钟刷新）
        if settings.refreshMode == .smart {
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            Logger.menuBar.debug("用户打开界面，切换到活跃模式")
        }

        // 如果距离上次刷新 < 30秒，跳过
        if let lastFetch = lastAPIFetchTime,
           now.timeIntervalSince(lastFetch) < 30 {
            return
        }

        fetchUsage()
    }

    /// 处理手动刷新
    /// 防抖机制：10秒内只能刷新一次（调试模式下不启用）
    func handleManualRefresh() {
        let now = Date()

        #if !DEBUG
        // 防抖检查：10秒内只能刷新一次（仅在 Release 模式下）
        if let lastManual = lastManualRefreshTime,
           now.timeIntervalSince(lastManual) < 10 {
            return
        }
        #endif

        // 用户主动刷新，强制切换到活跃模式（1分钟刷新）
        if settings.refreshMode == .smart {
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            Logger.menuBar.debug("用户主动刷新，切换到活跃模式")
        }

        // 更新状态
        lastManualRefreshTime = now
        refreshAnimationStartTime = now  // 记录动画开始时间
        refreshState.isRefreshing = true

        #if DEBUG
        // 调试模式：立即允许下次刷新
        refreshState.canRefresh = true
        #else
        // 正式模式：设置防抖
        refreshState.canRefresh = false
        // 10秒后解除防抖
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.refreshState.canRefresh = true
        }
        #endif

        // 触发刷新
        fetchUsage()
    }

    /// 结束刷新动画，确保至少显示最小时长
    /// - Parameter completion: 动画结束后的回调
    private func endRefreshAnimationWithMinimumDuration(completion: @escaping () -> Void) {
        guard let startTime = refreshAnimationStartTime else {
            // 没有记录开始时间，直接结束
            refreshState.isRefreshing = false
            completion()
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = minimumAnimationDuration - elapsed

        if remaining > 0 {
            // 动画时间不足，延迟剩余时间后再结束
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.refreshState.isRefreshing = false
                completion()
            }
        } else {
            // 动画时间已足够，直接结束
            refreshState.isRefreshing = false
            completion()
        }

        // 清除开始时间记录
        refreshAnimationStartTime = nil
    }

    // MARK: - Reset Verification

    /// 检测重置时间是否发生变化
    /// - Parameters:
    ///   - oldTime: 上次的重置时间
    ///   - newTime: 新的重置时间
    /// - Returns: 如果重置时间发生了变化则返回 true
    private func hasResetTimeChanged(from oldTime: Date?, to newTime: Date?) -> Bool {
        // 如果两者都为 nil，没有变化
        if oldTime == nil && newTime == nil {
            return false
        }

        // 如果一个为 nil 另一个不为 nil，有变化
        if (oldTime == nil) != (newTime == nil) {
            return true
        }

        // 如果两者都不为 nil，比较时间值（允许1秒误差）
        if let old = oldTime, let new = newTime {
            return abs(old.timeIntervalSince(new)) > 1.0
        }

        return false
    }

    /// 取消所有重置验证定时器
    private func cancelResetVerification() {
        timerManager.invalidate(TimerID.resetVerify1)
        timerManager.invalidate(TimerID.resetVerify2)
        timerManager.invalidate(TimerID.resetVerify3)
    }

    /// 安排重置时间验证
    /// 在重置时间过后的1秒、10秒、30秒分别触发一次刷新
    /// - Parameter resetsAt: 用量重置时间
    private func scheduleResetVerification(resetsAt: Date) {
        // 清除旧的验证定时器
        cancelResetVerification()

        // 计算距离重置时间的间隔
        let timeUntilReset = resetsAt.timeIntervalSinceNow

        // 只有重置时间在未来才安排验证
        guard timeUntilReset > 0 else {
            Logger.menuBar.debug("重置时间已过，跳过验证安排")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        Logger.menuBar.debug("安排重置验证 - 重置时间: \(formatter.string(from: resetsAt))")

        // 重置后1秒验证
        timerManager.schedule(TimerID.resetVerify1, interval: timeUntilReset + 1, repeats: false) { [weak self] in
            Logger.menuBar.debug("重置验证 +1秒 - 开始刷新")
            self?.fetchUsage()
        }

        // 重置后10秒验证
        timerManager.schedule(TimerID.resetVerify2, interval: timeUntilReset + 10, repeats: false) { [weak self] in
            Logger.menuBar.debug("重置验证 +10秒 - 开始刷新")
            self?.fetchUsage()
        }

        // 重置后30秒验证
        timerManager.schedule(TimerID.resetVerify3, interval: timeUntilReset + 30, repeats: false) { [weak self] in
            Logger.menuBar.debug("重置验证 +30秒 - 开始刷新")
            self?.fetchUsage()
        }
    }

    // MARK: - Update Checking

    /// 安排每日更新检查
    private func scheduleDailyUpdateCheck() {
        #if DEBUG
        // 🧪 调试模式：检查是否启用模拟更新
        if settings.simulateUpdateAvailable {
            hasAvailableUpdate = true
            latestVersion = "2.0.0"
            Logger.menuBar.debug("模拟更新已启用，显示更新通知")
        } else {
            // 即使在 Debug 模式，也进行真实的更新检查
            checkForUpdatesInBackground()

            timerManager.schedule(TimerID.dailyUpdate, interval: 24 * 60 * 60, repeats: true) { [weak self] in
                self?.checkForUpdatesInBackground()
            }

            Logger.menuBar.info("Debug 模式：真实更新检查已启动")
        }
        #else
        // Release 模式：始终进行真实更新检查
        checkForUpdatesInBackground()

        // 每24小时检查一次
        timerManager.schedule(TimerID.dailyUpdate, interval: 24 * 60 * 60, repeats: true) { [weak self] in
            self?.checkForUpdatesInBackground()
        }

        Logger.menuBar.info("每日更新检查已启动")
        #endif
    }

    /// 后台静默检查更新（无UI提示）
    private func checkForUpdatesInBackground() {
        let now = Date()

        // 防止重复检查：距离上次检查 < 12小时则跳过
        if let lastCheck = lastUpdateCheckTime,
           now.timeIntervalSince(lastCheck) < 12 * 60 * 60 {
            return
        }

        lastUpdateCheckTime = now

        updateChecker.checkForUpdatesInBackground { [weak self] hasUpdate, version in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.hasAvailableUpdate = hasUpdate
                self.latestVersion = version
            }
        }
    }

    /// 用户手动检查更新
    func checkForUpdatesManually() {
        // 手动检查更新（会弹出对话框）
        updateChecker.checkForUpdates(manually: true)
    }

    // MARK: - Cleanup

    /// 清理所有资源
    func cleanup() {
        timerManager.invalidateAll()
        endRefreshActivity()
    }

    deinit {
        cleanup()
    }
}
