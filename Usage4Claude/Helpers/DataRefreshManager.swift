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
import AppKit

/// 数据刷新管理器
/// 负责管理所有数据刷新、定时器、更新检查和重置验证逻辑
class DataRefreshManager: ObservableObject {

    // MARK: - Dependencies

    /// Claude API 服务实例
    private let apiService = ClaudeAPIService()
    /// Codex API 服务实例
    private let codexApiService = CodexAPIService()
    /// 定时器管理器
    private let timerManager = TimerManager()
    /// 用户设置实例
    private let settings = UserSettings.shared

    // MARK: - Published State

    /// Claude 用量数据
    @Published var usageData: UsageData?
    /// Codex 用量数据（nil 表示无 Codex 账号或拉取失败）
    @Published var codexUsageData: CodexUsageData?
    /// 加载状态
    @Published var isLoading = false
    /// 错误消息
    @Published var errorMessage: String?
    /// Codex 错误消息（独立于 Claude，避免双 Provider 时被静默隐藏）
    @Published var codexErrorMessage: String?
    /// 刷新状态管理器
    let refreshState = RefreshState()

    // MARK: - Private State

    /// Claude 上次的重置时间（用于检测重置是否完成）
    private var lastResetsAt: Date?
    /// Codex 上次的重置时间
    private var lastCodexResetsAt: Date?
    /// 上次手动刷新时间
    private var lastManualRefreshTime: Date?
    /// 上次API请求时间
    private var lastAPIFetchTime: Date?
    /// 刷新动画开始时间（用于确保动画最小显示时长）
    private var refreshAnimationStartTime: Date?
    /// 动画最小显示时长（秒）
    private let minimumAnimationDuration: TimeInterval = 1.0
    /// App Nap 防护活动令牌
    private var refreshActivity: NSObjectProtocol?
    /// 系统唤醒观察者令牌
    private var wakeObserver: NSObjectProtocol?
    /// Codex 三级刷新全部失败，需要用户手动重新登录
    /// 暴露给 UI 层以显示"重新登录"按钮
    @Published private(set) var codexNeedsRelogin = false
    /// Codex 过期通知已发送，防止重复打扰
    private var codexSessionExpiredNotified = false

    private var shouldFetchClaudeUsage: Bool {
        #if DEBUG
        if shouldSuppressDebugClaudeUsageForDisplayOptions {
            return false
        }
        return settings.debugModeEnabled || settings.hasValidCredentials
        #else
        return settings.hasValidCredentials
        #endif
    }

    private var shouldSuppressDebugClaudeUsageForDisplayOptions: Bool {
        #if DEBUG
        return settings.debugModeEnabled
            && settings.displayMode == .custom
            && !settings.customDisplayMenuBarOnly
            && !settings.customDisplayTypes.contains { $0.provider == .claude }
        #else
        return false
        #endif
    }

    private var shouldSuppressDebugCodexUsageForDisplayOptions: Bool {
        #if DEBUG
        return settings.debugModeEnabled
            && settings.displayMode == .custom
            && !settings.customDisplayMenuBarOnly
            && !settings.customDisplayTypes.contains { $0.provider == .codex }
        #else
        return false
        #endif
    }

    private var shouldFetchCodexUsage: Bool {
        #if DEBUG
        if shouldSuppressDebugCodexUsageForDisplayOptions {
            return false
        }
        return settings.debugModeEnabled || settings.hasValidCodexCredentials
        #else
        return settings.hasValidCodexCredentials
        #endif
    }

    /// 定时器标识符统一定义在 TimerManager.Identifier，避免两处各自为政
    private typealias TimerID = TimerManager.Identifier

    // MARK: - Initialization

    init() {
        setupWakeObserver()
    }

    // MARK: - Data Fetching

    /// 获取用量数据（Claude + Codex 并发）
    func fetchUsage() {
        isLoading = true
        errorMessage = nil
        codexErrorMessage = nil
        lastAPIFetchTime = Date()

        let fetchClaude = shouldFetchClaudeUsage
        let fetchCodex = shouldFetchCodexUsage

        if !fetchClaude {
            clearClaudeUsageState()
        }
        if !fetchCodex {
            clearCodexUsageState()
        }

        guard fetchClaude || fetchCodex else {
            isLoading = false
            endRefreshAnimationWithMinimumDuration { }
            errorMessage = UsageError.noCredentials.localizedDescription
            return
        }

        // Claude 与 Codex 并发拉取：两个子任务立即启动，结果在 MainActor 上顺序 await 合并
        // （审计报告 4.2：替代 DispatchGroup + 跨线程共享可变结果变量的旧写法）
        let claudeTask: Task<Result<UsageData, Error>, Never>? =
            fetchClaude ? Task { await self.apiService.fetchUsageResult() } : nil
        let codexTask: Task<Result<CodexUsageData, Error>, Never>? =
            fetchCodex ? Task { await self.codexApiService.fetchUsageResult() } : nil

        Task { @MainActor [weak self] in
            let claudeResult = await claudeTask?.value
            let codexResult = await codexTask?.value

            guard let self = self else { return }
            self.isLoading = false
            self.endRefreshAnimationWithMinimumDuration { }

            var monitoringUtilizations: [ProviderType: Double] = [:]
            if fetchCodex {
                switch codexResult {
                case .success(let codex):
                    if let utilization = self.monitoringUtilization(for: codex) {
                        monitoringUtilizations[.codex] = utilization
                    }
                    self.processCodexSuccess(codex)

                case .failure(let error):
                    Logger.menuBar.info("Codex 请求失败（不影响主功能）: \(error.localizedDescription)")
                    if case UsageError.unauthorized = error {
                        self.attemptTokenRefreshAndRetry()
                    } else {
                        self.codexErrorMessage = error.localizedDescription
                        self.clearCodexUsageState(clearError: false)
                    }

                case .none:
                    self.clearCodexUsageState()
                }
            } else {
                self.clearCodexUsageState()
            }

            // 处理 Claude 结果
            if fetchClaude {
                switch claudeResult {
                case .success(let data):
                    let previousData = self.usageData
                    self.usageData = data
                    self.errorMessage = nil
                    monitoringUtilizations[.claude] = data.percentage

                    if self.settings.notificationsEnabled {
                        NotificationManager.shared.checkAndNotify(usageData: data, previousData: previousData)
                    }

                    let newResetsAt = data.resetsAt
                    let hasResetChanged = hasResetTimeChanged(from: self.lastResetsAt, to: newResetsAt)
                    if hasResetChanged {
                        self.cancelResetVerification()
                    } else if let resetsAt = newResetsAt {
                        self.scheduleResetVerification(resetsAt: resetsAt)
                    }
                    self.lastResetsAt = newResetsAt

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    Logger.menuBar.error("Claude API 请求失败: \(error.localizedDescription)")

                case .none:
                    break
                }
            }

            self.settings.updateSmartMonitoringMode(providerUtilizations: monitoringUtilizations)
        }
    }

    private func clearClaudeUsageState() {
        usageData = nil
        lastResetsAt = nil
        cancelResetVerification()
    }

    private func clearCodexUsageState(clearError: Bool = true) {
        codexUsageData = nil
        if clearError {
            codexErrorMessage = nil
        }
        lastCodexResetsAt = nil
        cancelCodexResetVerification()
    }

    private func monitoringUtilization(for codex: CodexUsageData) -> Double? {
        [
            codex.primary?.percentage,
            codex.secondary?.percentage,
            codex.extraUsage?.percentage
        ]
        .compactMap { $0 }
        .max()
    }

    /// 开始数据刷新
    /// 立即获取一次数据并启动定时器
    func startRefreshing() {
        beginRefreshActivity()
        fetchUsage()
        restartTimer()
        startCodexTokenRefreshTimer()

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
        timerManager.invalidate(TimerID.codexTokenRefresh)
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

    /// 启动 Codex accessToken 独立续期计时器（固定10分钟，与用量拉取解耦）
    private func startCodexTokenRefreshTimer() {
        timerManager.schedule(TimerID.codexTokenRefresh, interval: 10 * 60, repeats: true) { [weak self] in
            self?.codexApiService.proactivelyRefreshIfNeeded()
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

    /// 注册系统唤醒监听
    /// 系统从睡眠唤醒后立即刷新数据，防止定时器在睡眠期间暂停导致长时间不更新
    private func setupWakeObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.menuBar.debug("系统从睡眠唤醒，立即刷新数据")
            // 延迟 3 秒等待网络恢复后再请求
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.fetchUsage()
            }
        }
    }

    // MARK: - Smart Refresh

    /// 打开Popover时的智能刷新
    /// 如果距离上次刷新 > 30秒，则立即刷新数据
    func refreshOnPopoverOpen() {
        let now = Date()

        // 用户打开详细界面，强制切换到活跃模式（1分钟刷新）
        if settings.refreshMode == .smart {
            let wasIdle = settings.currentMonitoringMode != .active
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            // 如果之前处于空闲模式，需要重启定时器以应用新间隔
            // 否则 updateSmartMonitoringMode 的 switchToActiveMode() 会因 guard 直接返回，导致定时器仍以旧间隔运行
            if wasIdle {
                restartTimer()
                Logger.menuBar.debug("用户打开界面，从空闲模式切换到活跃模式，重启定时器")
            } else {
                Logger.menuBar.debug("用户打开界面，已在活跃模式")
            }
        }

        // 如果距离上次刷新 < 30秒，跳过
        if let lastFetch = lastAPIFetchTime,
           now.timeIntervalSince(lastFetch) < 30 {
            return
        }

        fetchUsage()
    }

    /// 处理手动刷新
    /// 防抖机制：10秒内只能刷新一次
    func handleManualRefresh() {
        let now = Date()

        // 防抖检查：10秒内只能刷新一次
        if let lastManual = lastManualRefreshTime,
           now.timeIntervalSince(lastManual) < 10 {
            return
        }

        // 用户主动刷新，强制切换到活跃模式（1分钟刷新）
        if settings.refreshMode == .smart {
            let wasIdle = settings.currentMonitoringMode != .active
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            // 同 refreshOnPopoverOpen：若之前是空闲模式，需要重启定时器
            if wasIdle {
                restartTimer()
                Logger.menuBar.debug("用户主动刷新，从空闲模式切换到活跃模式，重启定时器")
            } else {
                Logger.menuBar.debug("用户主动刷新，已在活跃模式")
            }
        }

        // 更新状态
        lastManualRefreshTime = now
        refreshAnimationStartTime = now  // 记录动画开始时间
        refreshState.refreshingProvider = nil
        refreshState.isRefreshing = true
        resetCodexReloginState()  // 用户主动刷新，允许重新尝试 token 刷新

        // 设置防抖
        refreshState.canRefresh = false
        // 10秒后解除防抖
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.refreshState.canRefresh = true
        }

        // 触发刷新
        fetchUsage()
    }

    /// 仅刷新 Claude 数据（Claude 圆环点击触发）
    func handleClaudeOnlyRefresh() {
        guard shouldFetchClaudeUsage else { return }
        let now = Date()
        if let lastManual = lastManualRefreshTime,
           now.timeIntervalSince(lastManual) < 10 { return }
        if settings.refreshMode == .smart {
            let wasIdle = settings.currentMonitoringMode != .active
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            if wasIdle { restartTimer() }
        }
        lastManualRefreshTime = now
        refreshAnimationStartTime = now
        refreshState.refreshingProvider = .claude
        refreshState.isRefreshing = true
        refreshState.canRefresh = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.refreshState.canRefresh = true
        }
        fetchClaudeOnly()
    }

    /// 仅刷新 Codex 数据（Codex 圆环点击触发）
    func handleCodexOnlyRefresh() {
        guard shouldFetchCodexUsage else {
            clearCodexUsageState()
            return
        }
        let now = Date()
        if let lastManual = lastManualRefreshTime,
           now.timeIntervalSince(lastManual) < 10 { return }
        lastManualRefreshTime = now
        refreshAnimationStartTime = now
        refreshState.refreshingProvider = .codex
        refreshState.isRefreshing = true
        refreshState.canRefresh = false
        resetCodexReloginState()  // 用户主动刷新，允许重新尝试 token 刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.refreshState.canRefresh = true
        }
        fetchCodexOnly()
    }

    private func fetchClaudeOnly() {
        guard shouldFetchClaudeUsage else {
            clearClaudeUsageState()
            return
        }
        isLoading = true
        errorMessage = nil
        lastAPIFetchTime = Date()

        // ClaudeAPIService.fetchUsage 保证 completion 一律在主线程回调，此处无需再包一层 DispatchQueue.main.async
        apiService.fetchUsage { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            self.endRefreshAnimationWithMinimumDuration { }

            switch result {
            case .success(let data):
                let previousData = self.usageData
                self.usageData = data
                self.errorMessage = nil
                if self.settings.notificationsEnabled {
                    NotificationManager.shared.checkAndNotify(usageData: data, previousData: previousData)
                }
                self.settings.updateSmartMonitoringMode(providerUtilizations: [.claude: data.percentage])
                let newResetsAt = data.resetsAt
                if hasResetTimeChanged(from: self.lastResetsAt, to: newResetsAt) {
                    self.cancelResetVerification()
                } else if let resetsAt = newResetsAt {
                    self.scheduleResetVerification(resetsAt: resetsAt)
                }
                self.lastResetsAt = newResetsAt
            case .failure(let error):
                self.clearClaudeUsageState()
                self.errorMessage = error.localizedDescription
                Logger.menuBar.error("Claude API 请求失败: \(error.localizedDescription)")
            }
        }
    }

    private func fetchCodexOnly(retryOnUnauthorized: Bool = true) {
        guard shouldFetchCodexUsage else {
            clearCodexUsageState()
            return
        }
        isLoading = true
        codexErrorMessage = nil
        lastAPIFetchTime = Date()

        codexApiService.fetchUsage { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.endRefreshAnimationWithMinimumDuration { }

                switch result {
                case .success(let data):
                    self.processCodexSuccess(data)
                case .failure(let error):
                    if retryOnUnauthorized, case UsageError.unauthorized = error {
                        // 401 说明缓存的 accessToken 已失效，立即清除避免下次继续用坏 token
                        self.codexApiService.clearAccessTokenCache()
                        self.attemptTokenRefreshAndRetry()
                    } else {
                        self.codexErrorMessage = error.localizedDescription
                        self.clearCodexUsageState(clearError: false)
                        Logger.menuBar.info("Codex 请求失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func processCodexSuccess(_ data: CodexUsageData) {
        let previousCodexData = codexUsageData
        codexUsageData = data
        codexErrorMessage = nil
        if let utilization = monitoringUtilization(for: data) {
            settings.updateSmartMonitoringMode(providerUtilizations: [.codex: utilization])
        }
        if settings.notificationsEnabled {
            NotificationManager.shared.checkAndNotify(codexUsageData: data, previousData: previousCodexData)
        }
        let newCodexResetsAt = data.primary?.resetsAt
        if hasResetTimeChanged(from: lastCodexResetsAt, to: newCodexResetsAt) {
            cancelCodexResetVerification()
        } else if let resetsAt = newCodexResetsAt {
            scheduleCodexResetVerification(resetsAt: resetsAt)
        }
        lastCodexResetsAt = newCodexResetsAt
    }

    private func attemptTokenRefreshAndRetry() {
        guard !codexNeedsRelogin else {
            Logger.menuBar.info("Codex 已确认需要重新登录，跳过刷新")
            markCodexNeedsRelogin()
            return
        }
        // OAuth 账户：refresh_token 已在 fetchUsage 内尝试续期，401 表示 refresh_token 失效。
        // 旧的 chatgpt.com 三级刷新链针对 session-token，对 OAuth 凭据无意义且必然失败，直接要求重新登录。
        if CodexAPIService.isOAuthRefreshToken(UserSettings.shared.codexSessionToken) {
            Logger.menuBar.info("Codex OAuth refresh_token 失效，需重新登录")
            markCodexNeedsRelogin()
            return
        }
        let prefix = UserSettings.shared.codexSessionToken.prefix(16)
        Logger.menuBar.info("Codex accessToken 已过期，启动三级刷新链（session prefix=\(prefix)…）")
        attemptLevel1SSRRefresh()
    }

    /// 级别 1：SSR bootstrap 刷新 accessToken
    private func attemptLevel1SSRRefresh() {
        Logger.menuBar.info("Codex 级别1：SSR bootstrap 刷新")
        Task { @MainActor [weak self] in
            guard let self else { return }
            CodexTokenRefreshCoordinator.shared.refresh { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let freshAccessToken):
                    Logger.menuBar.notice("Codex 级别1 SSR 刷新成功，用新 accessToken 重试")
                    self.retryCodexWithAccessToken(freshAccessToken)
                case .failure(let error):
                    Logger.menuBar.info("Codex 级别1 失败（\(error.localizedDescription)），降级至级别2")
                    self.attemptLevel2WebViewRefresh()
                }
            }
        }
    }

    /// 级别 2：隐藏 WebView 静默续期 session-token
    private func attemptLevel2WebViewRefresh() {
        Logger.menuBar.info("Codex 级别2：隐藏 WebView 静默续期")
        Task { @MainActor [weak self] in
            guard let self else { return }
            CodexSilentRefreshCoordinator.shared.refresh { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    Logger.menuBar.notice("Codex 级别2 WebView 续期成功，重新拉取用量")
                    // session-token 已在 coordinator 内写回，重新走完整的 session→usage 流程
                    self.fetchCodexOnly(retryOnUnauthorized: false)
                case .failure(let error):
                    Logger.menuBar.error("Codex 级别2 失败（\(error.localizedDescription)），进入级别3")
                    self.markCodexNeedsRelogin()
                }
            }
        }
    }

    /// 用新鲜 accessToken 直接查询用量（跳过 session 步骤）
    private func retryCodexWithAccessToken(_ accessToken: String) {
        isLoading = true
        codexApiService.fetchUsageWithAccessToken(accessToken) { [weak self] usageResult in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.endRefreshAnimationWithMinimumDuration { }
                switch usageResult {
                case .success(let data):
                    self.processCodexSuccess(data)
                case .failure(let error):
                    Logger.menuBar.error("Codex 新鲜 accessToken 仍失败: \(error.localizedDescription)，降级至级别2")
                    self.attemptLevel2WebViewRefresh()
                }
            }
        }
    }

    /// 重置重登状态（用户主动刷新时调用，允许再次尝试三级刷新链）
    private func resetCodexReloginState() {
        codexNeedsRelogin = false
        codexSessionExpiredNotified = false
    }

    /// 级别 3：标记需要重登，发送系统通知（仅一次）
    private func markCodexNeedsRelogin() {
        codexNeedsRelogin = true
        if !codexSessionExpiredNotified {
            codexSessionExpiredNotified = true
            if settings.notificationsEnabled {
                NotificationManager.shared.sendCodexSessionExpiredNotification()
            }
        }
        codexErrorMessage = UsageError.sessionExpired.localizedDescription
        clearCodexUsageState(clearError: false)
        Logger.menuBar.error("Codex 三级刷新均已失败，需要用户重新登录")
    }

    /// 账户切换后只清理并刷新对应 Provider，避免跨账号 previousData 误判重置。
    /// 通知去重状态按账号隔离，切换账号时保留，删除账号时再由 UserSettings 精准清理。
    func handleAccountChanged(provider: ProviderType?) {
        switch provider {
        case .claude:
            errorMessage = nil
            clearClaudeUsageState()
            if shouldFetchClaudeUsage {
                fetchClaudeOnly()
            }

        case .codex:
            resetCodexReloginState()
            codexApiService.clearAccessTokenCache()
            clearCodexUsageState()
            if shouldFetchCodexUsage {
                fetchCodexOnly()
            }

        case .none:
            clearClaudeUsageState()
            clearCodexUsageState()
            NotificationManager.shared.resetAllNotificationStates()
            fetchUsage()
        }
    }

    /// 结束刷新动画，确保至少显示最小时长
    /// - Parameter completion: 动画结束后的回调
    private func endRefreshAnimationWithMinimumDuration(completion: @escaping () -> Void) {
        guard let startTime = refreshAnimationStartTime else {
            // 没有记录开始时间，直接结束
            refreshState.isRefreshing = false
            refreshState.refreshingProvider = nil
            completion()
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = minimumAnimationDuration - elapsed

        if remaining > 0 {
            // 动画时间不足，延迟剩余时间后再结束
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.refreshState.isRefreshing = false
                self?.refreshState.refreshingProvider = nil
                completion()
            }
        } else {
            // 动画时间已足够，直接结束
            refreshState.isRefreshing = false
            refreshState.refreshingProvider = nil
            completion()
        }

        // 清除开始时间记录
        refreshAnimationStartTime = nil
    }

    // MARK: - Reset Verification

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

    // MARK: - Codex Reset Verification

    private func cancelCodexResetVerification() {
        timerManager.invalidate(TimerID.codexResetVerify1)
        timerManager.invalidate(TimerID.codexResetVerify2)
        timerManager.invalidate(TimerID.codexResetVerify3)
    }

    private func scheduleCodexResetVerification(resetsAt: Date) {
        cancelCodexResetVerification()

        let timeUntilReset = resetsAt.timeIntervalSinceNow
        guard timeUntilReset > 0 else {
            Logger.menuBar.debug("Codex 重置时间已过，跳过验证安排")
            return
        }

        timerManager.schedule(TimerID.codexResetVerify1, interval: timeUntilReset + 1, repeats: false) { [weak self] in
            Logger.menuBar.debug("Codex 重置验证 +1秒 - 开始刷新")
            self?.fetchUsage()
        }

        timerManager.schedule(TimerID.codexResetVerify2, interval: timeUntilReset + 10, repeats: false) { [weak self] in
            Logger.menuBar.debug("Codex 重置验证 +10秒 - 开始刷新")
            self?.fetchUsage()
        }

        timerManager.schedule(TimerID.codexResetVerify3, interval: timeUntilReset + 30, repeats: false) { [weak self] in
            Logger.menuBar.debug("Codex 重置验证 +30秒 - 开始刷新")
            self?.fetchUsage()
        }
    }

    // MARK: - Cleanup

    /// 清理所有资源
    func cleanup() {
        timerManager.invalidateAll()
        endRefreshActivity()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    deinit {
        cleanup()
    }
}
