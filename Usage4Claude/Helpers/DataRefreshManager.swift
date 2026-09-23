//
//  DataRefreshManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine
import AppKit

/// 数据刷新管理器
/// 负责管理所有数据刷新、定时器、更新检查和重置验证逻辑
class DataRefreshManager: ObservableObject {

    // MARK: - Dependencies

    /// Claude API 服务实例
    private let apiService = ClaudeAPIService()
    /// Codex API 服务实例
    private let codexApiService = CodexAPIService()
    /// Codex 重置预告服务实例（Beta，第三方数据源）——独立于用量刷新链路
    private let codexAnnouncementService = CodexResetAnnouncementService()
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
    /// 当前 errorMessage 是否为需要用户处理的认证类错误（未授权/会话过期/未配置）。
    /// 视图层据此决定：认证错误全屏提示引导去设置，瞬时错误（限流/网络）保留缓存数据，只在标题旁显示小叹号
    @Published var errorRequiresAuthAction = false
    /// Codex 错误消息（独立于 Claude，避免双 Provider 时被静默隐藏）
    @Published var codexErrorMessage: String?
    /// 当前 codexErrorMessage 是否为认证类错误，语义与 errorRequiresAuthAction 相同
    @Published var codexErrorRequiresAuthAction = false
    /// Codex 官方重置预告（Beta，第三方数据源）。完全旁路 refreshState/isLoading/codexErrorMessage——
    /// 失败静默契约：无论「没有预告」「网络失败」「解析失败」「功能已关闭」，UI 表现都必须是 nil，
    /// 逐像素一致，绝不打扰用户（见项目计划文档）。
    @Published var codexResetAnnouncement: CodexResetAnnouncement?
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
    /// Claude 用量拉取的失败退避状态（限流/5xx/网络错误后暂停自动刷新，见 UsageFetchBackoffPolicy）
    private var claudeBackoff = UsageFetchBackoffPolicy.State.initial
    /// Codex 用量拉取的失败退避状态
    private var codexBackoff = UsageFetchBackoffPolicy.State.initial

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
    /// - Parameter bypassBackoff: 是否无视失败退避。只有用户主动操作（手动刷新、打开 Popover）传 true；
    ///   定时器、系统唤醒、重置验证等自动触发都必须遵守退避，避免限流期间按固定间隔持续重试
    func fetchUsage(bypassBackoff: Bool = false) {
        let claudeEnabled = shouldFetchClaudeUsage
        let codexEnabled = shouldFetchCodexUsage

        if !claudeEnabled {
            clearClaudeUsageState()
        }
        if !codexEnabled {
            clearCodexUsageState()
        }

        guard claudeEnabled || codexEnabled else {
            isLoading = false
            endRefreshAnimationWithMinimumDuration { }
            errorMessage = UsageError.noCredentials.localizedDescription
            errorRequiresAuthAction = true
            return
        }

        let now = Date()
        let fetchClaude = claudeEnabled && (bypassBackoff || isBackoffElapsed(for: .claude, now: now))
        let fetchCodex = codexEnabled && (bypassBackoff || isBackoffElapsed(for: .codex, now: now))

        // 两个 Provider 都在退避期内：整次自动刷新跳过，保留缓存数据和错误提示
        guard fetchClaude || fetchCodex else { return }

        isLoading = true
        markRequestIssued(at: now)
        // 只清除本次实际发起请求的 Provider 的错误；因退避被跳过的一方继续显示原来的错误提示
        if fetchClaude {
            errorMessage = nil
            errorRequiresAuthAction = false
        }
        if fetchCodex {
            codexErrorMessage = nil
            codexErrorRequiresAuthAction = false
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
                    AppLog.warning(.refresh, "Codex refresh failed; Claude data is unaffected: \(error.localizedDescription)")
                    if case UsageError.unauthorized = error {
                        self.attemptTokenRefreshAndRetry()
                    } else {
                        self.presentCodexFailure(error)
                    }

                case .none:
                    self.clearCodexUsageState()
                }
            } else if !codexEnabled {
                // 仅在未配置 Codex 时清理；因退避跳过时要保留错误提示
                self.clearCodexUsageState()
            }

            // 处理 Claude 结果
            if fetchClaude {
                switch claudeResult {
                case .success(let data):
                    let previousData = self.usageData
                    self.usageData = data
                    self.errorMessage = nil
                    self.errorRequiresAuthAction = false
                    self.recordFetchSuccess(for: .claude)
                    monitoringUtilizations[.claude] = data.percentage

                    NotificationManager.shared.checkAndNotify(usageData: data, previousData: previousData)

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
                    self.errorRequiresAuthAction = self.requiresAuthAction(error)
                    self.recordFetchFailure(error, for: .claude)
                    AppLog.error(.refresh, "Claude refresh failed: \(error.localizedDescription)")

                case .none:
                    break
                }
            }

            self.settings.updateSmartMonitoringMode(providerUtilizations: monitoringUtilizations)
        }
    }

    private func clearClaudeUsageState() {
        usageData = nil
        refreshState.lastSuccessAt[.claude] = nil
        lastResetsAt = nil
        cancelResetVerification()
    }

    /// 判断错误是否需要用户去设置里处理认证信息（区别于限流/网络等可自愈的瞬时错误）
    private func requiresAuthAction(_ error: Error) -> Bool {
        switch error {
        case UsageError.unauthorized, UsageError.sessionExpired, UsageError.noCredentials:
            return true
        default:
            return false
        }
    }

    private func clearCodexUsageState(clearError: Bool = true) {
        codexUsageData = nil
        refreshState.lastSuccessAt[.codex] = nil
        if clearError {
            codexErrorMessage = nil
            codexErrorRequiresAuthAction = false
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

    /// 只刷新 Codex 的路径（圆环点击、token 续期后重试）用本次结果单独推进智能模式
    private func updateSmartMonitoringMode(codex data: CodexUsageData) {
        guard let utilization = monitoringUtilization(for: data) else { return }
        settings.updateSmartMonitoringMode(providerUtilizations: [.codex: utilization])
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

    /// 刷新间隔变化时调用（智能模式切档、用户修改刷新模式或间隔）
    /// 只按新间隔重排主定时器，不立即请求
    /// - Note: 切档发生在一次请求刚返回时，数据是新的。此前这里走 stop/start，会立刻补发一次请求，
    ///   与刚完成的请求相隔不到 1 秒；日志里 Claude OAuth 用量接口对这种连发的第二个请求返回了 429
    func handleRefreshIntervalChanged() {
        restartTimer()
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

    /// 记录一次请求已发出，并把主定时器顺延一个完整间隔
    /// - Note: 打开 Popover、手动刷新、点圆环、唤醒都会在定时器周期之外发请求。不顺延的话，
    ///   定时器可能几秒后又到点形成连发；日志里 Claude OAuth 用量接口对这种连发返回了 429
    private func markRequestIssued(at date: Date = Date()) {
        lastAPIFetchTime = date
        restartTimer()
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
            AppLog.event(.refresh, "System woke from sleep; refreshing immediately")
            // 延迟 3 秒等待网络恢复后再请求
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.fetchUsage()
            }
        }
    }

    // MARK: - Smart Refresh

    /// 打开 Popover 时立即刷新一次
    /// 与手动刷新同属用户主动操作，不受失败退避约束；只有 10 秒内刚发过请求时跳过，
    /// 那时的数据已是最新，重复请求只会形成连发（日志里连发正是触发 429 的原因）
    func refreshOnPopoverOpen() {
        let now = Date()

        // 独立旁支，放在最前面：即使下面因最小间隔提前 return，预告检查仍应按自己的频率策略执行
        fetchCodexResetAnnouncementIfNeeded()

        // 用户打开详细界面，强制切换到活跃模式（1分钟刷新）
        if settings.refreshMode == .smart {
            let wasIdle = settings.currentMonitoringMode != .active
            settings.currentMonitoringMode = .active
            settings.unchangedCount = 0
            // 如果之前处于空闲模式，需要重启定时器以应用新间隔
            // 否则 updateSmartMonitoringMode 的 switchToActiveMode() 会因 guard 直接返回，导致定时器仍以旧间隔运行
            if wasIdle {
                restartTimer()
                AppLog.event(.refresh, "Popover opened; switching from idle to active mode and restarting the timer")
            } else {
                AppLog.trace(.refresh, "Popover opened; already in active mode")
            }
        }

        if let lastFetch = lastAPIFetchTime,
           now.timeIntervalSince(lastFetch) < Self.popoverOpenMinimumInterval {
            return
        }

        fetchUsage(bypassBackoff: true)
    }

    /// 打开 Popover 触发刷新的最小间隔：挡住快速开关弹窗造成的连发
    private static let popoverOpenMinimumInterval: TimeInterval = 10

    // MARK: - Codex Reset Announcement (Beta)

    /// 独立于用量刷新链路的旁支：Codex 官方重置预告（第三方数据源 codex-reset.com）。
    /// 频率/退避/缓存全部委托给 CodexResetAnnouncementService（内部用
    /// CodexAnnouncementFetchPolicy 判定，安静期/关闭状态下几乎不产生网络请求）。
    /// 绝不触碰 refreshState/isLoading/codexErrorMessage——失败静默契约（见项目计划文档）。
    private func fetchCodexResetAnnouncementIfNeeded() {
        guard settings.showCodexResetAnnouncement else {
            if codexResetAnnouncement != nil {
                setCodexResetAnnouncement(nil)
            }
            return
        }

        #if DEBUG
        // 调试模式下预告完全由调试场景决定，不发真实请求：此时用量本身就是模拟数据，
        // 混进真实预告反而没法验收；选 .off 即不显示。不要求已登录 Codex 账户。
        // 真实预告很罕见（历史上约 10/53 次事件），没有这个开关几乎无法验收 UI。
        if settings.debugModeEnabled {
            setCodexResetAnnouncement(settings.debugCodexAnnouncementScenario.mockAnnouncement())
            return
        }
        #endif
        let codexActive = settings.hasValidCodexCredentials

        guard codexActive else {
            if codexResetAnnouncement != nil {
                setCodexResetAnnouncement(nil)
            }
            return
        }

        codexAnnouncementService.announcement { [weak self] announcement in
            self?.setCodexResetAnnouncement(announcement)
        }
    }

    /// `UsageDetailView` 通过 @Binding 接收 codexResetAnnouncement，但它自己不持有
    /// DataRefreshManager/MenuBarManager 作为 @ObservedObject——只有它实际观察的
    /// `refreshState` 发布变更时，body 才会重新求值、重新读取 binding 的最新值
    /// （其余数据字段能"自动"刷新，都是搭了 fetchUsage() 结束时必然重置
    /// refreshState.isRefreshing 的顺风车）。这里手动 ping 一次 refreshState 的
    /// objectWillChange，不改动它任何实际字段，因此不会触发刷新动画/加载态。
    private func setCodexResetAnnouncement(_ announcement: CodexResetAnnouncement?) {
        codexResetAnnouncement = announcement
        refreshState.objectWillChange.send()
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
                AppLog.event(.refresh, "Manual refresh requested; switching from idle to active mode and restarting the timer")
            } else {
                AppLog.trace(.refresh, "Manual refresh requested; already in active mode")
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

        // 触发刷新（用户主动操作，不受失败退避约束；10 秒防抖已限制频率）
        fetchUsage(bypassBackoff: true)
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
        errorRequiresAuthAction = false
        markRequestIssued()

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
                self.errorRequiresAuthAction = false
                NotificationManager.shared.checkAndNotify(usageData: data, previousData: previousData)
                self.recordFetchSuccess(for: .claude)
                self.settings.updateSmartMonitoringMode(providerUtilizations: [.claude: data.percentage])
                let newResetsAt = data.resetsAt
                if hasResetTimeChanged(from: self.lastResetsAt, to: newResetsAt) {
                    self.cancelResetVerification()
                } else if let resetsAt = newResetsAt {
                    self.scheduleResetVerification(resetsAt: resetsAt)
                }
                self.lastResetsAt = newResetsAt
            case .failure(let error):
                // 保留缓存数据（与 fetchUsage 的失败路径一致），瞬时错误下 UI 只显示小叹号
                self.errorMessage = error.localizedDescription
                self.errorRequiresAuthAction = self.requiresAuthAction(error)
                self.recordFetchFailure(error, for: .claude)
                AppLog.error(.refresh, "Claude-only refresh failed; keeping cached data: \(error.localizedDescription)")
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
        codexErrorRequiresAuthAction = false
        markRequestIssued()

        codexApiService.fetchUsage { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.endRefreshAnimationWithMinimumDuration { }

                switch result {
                case .success(let data):
                    self.processCodexSuccess(data)
                    self.updateSmartMonitoringMode(codex: data)
                case .failure(let error):
                    if retryOnUnauthorized, case UsageError.unauthorized = error {
                        // 401 说明缓存的 accessToken 已失效，立即清除避免下次继续用坏 token
                        self.codexApiService.clearAccessTokenCache()
                        self.attemptTokenRefreshAndRetry()
                    } else {
                        AppLog.error(.refresh, "Codex refresh failed: \(error.localizedDescription)")
                        self.presentCodexFailure(error)
                    }
                }
            }
        }
    }

    /// 展示一次不再重试的 Codex 拉取失败
    ///
    /// OAuth 账户的凭据失效类错误只能靠重新登录解决，标记重登（附一次性通知），
    /// 而不是只显示一行错误文案。cookie 账户的凭据失效由三级刷新链负责，这里维持原样。
    private func presentCodexFailure(_ error: Error) {
        recordFetchFailure(error, for: .codex)
        if CodexAPIService.isOAuthRefreshToken(settings.codexSessionToken) {
            switch error {
            case UsageError.unauthorized, UsageError.sessionExpired:
                markCodexNeedsRelogin()
                return
            default:
                break
            }
        }
        codexErrorMessage = error.localizedDescription
        codexErrorRequiresAuthAction = requiresAuthAction(error)
        // 与 Claude 一致：瞬时错误（限流/网络/5xx）保留缓存数据，界面只在标题旁显示小叹号；
        // 认证类错误说明旧数据已不可信，清掉数据改为全屏引导
        if codexErrorRequiresAuthAction {
            clearCodexUsageState(clearError: false)
        }
    }

    /// 应用一次成功的 Codex 用量结果（数据、通知、重置验证）
    /// - Note: 这里不推进智能模式。fetchUsage 要把 Claude 与 Codex 合并成一轮更新，在这里再更新一次
    ///   会让同一轮计数两次、降档速度翻倍；只刷新 Codex 的路径自行调用 updateSmartMonitoringMode(codex:)
    private func processCodexSuccess(_ data: CodexUsageData) {
        recordFetchSuccess(for: .codex)
        let previousCodexData = codexUsageData
        codexUsageData = data
        codexErrorMessage = nil
        codexErrorRequiresAuthAction = false
        NotificationManager.shared.checkAndNotify(codexUsageData: data, previousData: previousCodexData)
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
            AppLog.event(.refresh, "Codex is already flagged as needing re-login; skipping this refresh")
            markCodexNeedsRelogin()
            return
        }
        // OAuth 账户：401 只说明这枚 access_token 被拒（持久化的 token 可能已被服务端吊销），
        // 不代表 refresh_token 也失效了。服务层已清掉被拒的 token，重拉一次就会用 refresh_token
        // 续期；重试仍失败才由 presentCodexFailure 标记重登。
        // 旧的 chatgpt.com 三级刷新链针对 session-token，对 OAuth 凭据无意义，不走。
        if CodexAPIService.isOAuthRefreshToken(UserSettings.shared.codexSessionToken) {
            AppLog.event(.auth, "Codex OAuth accessToken was rejected; renewing it with the refresh_token and retrying once")
            fetchCodexOnly(retryOnUnauthorized: false)
            return
        }
        let prefix = UserSettings.shared.codexSessionToken.prefix(16)
        AppLog.event(.auth, "Codex accessToken expired; starting the three-tier refresh chain (session prefix=\(prefix)…)")
        attemptLevel1SSRRefresh()
    }

    /// 级别 1：SSR bootstrap 刷新 accessToken
    private func attemptLevel1SSRRefresh() {
        AppLog.event(.auth, "Codex refresh tier 1: SSR bootstrap")
        Task { @MainActor [weak self] in
            guard let self else { return }
            CodexTokenRefreshCoordinator.shared.refresh { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let freshAccessToken):
                    AppLog.event(.auth, "Codex refresh tier 1 succeeded; retrying usage with the new accessToken")
                    self.retryCodexWithAccessToken(freshAccessToken)
                case .failure(let error):
                    if let backoffError = self.tier1BackoffError(for: error) {
                        // chatgpt.com 在限流或出 5xx：WebView 访问同一个站点只会多打请求，
                        // 失败后还会被标记为需要重新登录，而凭据其实没问题
                        AppLog.warning(.auth, "Codex refresh tier 1 failed (\(error.localizedDescription)); backing off instead of escalating to tier 2")
                        self.presentCodexFailure(backoffError)
                        return
                    }
                    AppLog.warning(.auth, "Codex refresh tier 1 failed (\(error.localizedDescription)); falling back to tier 2")
                    self.attemptLevel2WebViewRefresh()
                }
            }
        }
    }

    /// 级别 2：隐藏 WebView 静默续期 session-token
    private func attemptLevel2WebViewRefresh() {
        AppLog.event(.auth, "Codex refresh tier 2: silent renewal via a hidden WebView")
        Task { @MainActor [weak self] in
            guard let self else { return }
            CodexSilentRefreshCoordinator.shared.refresh { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    AppLog.event(.auth, "Codex refresh tier 2 succeeded; re-fetching usage")
                    // session-token 已在 coordinator 内写回，重新走完整的 session→usage 流程
                    self.fetchCodexOnly(retryOnUnauthorized: false)
                case .failure(let error):
                    AppLog.warning(.auth, "Codex refresh tier 2 failed (\(error.localizedDescription)); falling back to tier 3")
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
                    self.updateSmartMonitoringMode(codex: data)
                case .failure(let error) where self.backoffFailure(for: error) != nil:
                    // 新 token 仍被限流或网络失败，说明问题不在凭据：进入退避，而不是升级到 WebView 刷新再多打请求
                    AppLog.warning(.auth, "Codex usage failed with a freshly issued accessToken for a non-auth reason (\(error.localizedDescription)); backing off instead of escalating to tier 2")
                    self.presentCodexFailure(error)
                case .failure(let error):
                    AppLog.warning(.auth, "Codex usage still failed with a freshly issued accessToken: \(error.localizedDescription); falling back to tier 2")
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

    /// 标记需要重登，发送系统通知（仅一次）
    /// cookie 账户在三级刷新链全部失败后到达这里；OAuth 账户在续期失败、access_token 也已不可用时到达
    private func markCodexNeedsRelogin() {
        codexNeedsRelogin = true
        if !codexSessionExpiredNotified {
            codexSessionExpiredNotified = true
            if settings.notificationsEnabled {
                NotificationManager.shared.sendCodexSessionExpiredNotification()
            }
        }
        codexErrorMessage = UsageError.sessionExpired.localizedDescription
        codexErrorRequiresAuthAction = true
        clearCodexUsageState(clearError: false)
        AppLog.error(.auth, "Codex credentials can no longer be renewed; the user must sign in again")
    }

    /// 账户切换后只清理并刷新对应 Provider，避免跨账号 previousData 误判重置。
    /// 通知去重状态按账号隔离，切换账号时保留，删除账号时再由 UserSettings 精准清理。
    /// 限流按 token 计，新账号不继承旧账号的失败退避。
    func handleAccountChanged(provider: ProviderType?) {
        switch provider {
        case .claude:
            errorMessage = nil
            errorRequiresAuthAction = false
            claudeBackoff = .initial
            clearClaudeUsageState()
            if shouldFetchClaudeUsage {
                fetchClaudeOnly()
            }

        case .codex:
            resetCodexReloginState()
            codexBackoff = .initial
            // The cache is keyed by credential; clearing here would discard
            // the access token just seeded by Browser Login.
            clearCodexUsageState()
            if shouldFetchCodexUsage {
                fetchCodexOnly()
            }

        case .none:
            claudeBackoff = .initial
            codexBackoff = .initial
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

    // MARK: - Fetch Backoff

    private func backoffState(for provider: ProviderType) -> UsageFetchBackoffPolicy.State {
        provider == .claude ? claudeBackoff : codexBackoff
    }

    private func setBackoffState(_ state: UsageFetchBackoffPolicy.State, for provider: ProviderType) {
        switch provider {
        case .claude: claudeBackoff = state
        case .codex: codexBackoff = state
        }
    }

    /// 自动刷新前检查该 Provider 是否已走出退避期；仍在退避期内时记日志并返回 false
    /// - Note: 定时器不会为退避单独重排，退避结束后的第一个常规 tick 才会恢复请求
    private func isBackoffElapsed(for provider: ProviderType, now: Date) -> Bool {
        let state = backoffState(for: provider)
        guard !UsageFetchBackoffPolicy.shouldFetch(state: state, now: now) else { return true }
        let remaining = Int((state.retryNotBefore?.timeIntervalSince(now) ?? 0).rounded(.up))
        AppLog.event(.refresh, "\(provider.displayName) automatic refresh skipped: backing off after \(state.consecutiveFailures) failure(s), \(remaining)s remaining")
        return false
    }

    /// 把错误归类为可退避的失败；返回 nil 表示不进入退避。
    /// 只有限流、5xx、网络错误、Cloudflare 拦截这类「立即重试只会加重」的错误退避；认证错误需要用户处理
    /// （Codex 另有三级刷新链），解析错误重试也不会变好，被新一轮请求取消（requestCancelled）也不是真实失败
    private func backoffFailure(for error: Error) -> UsageFetchBackoffPolicy.Failure? {
        switch error {
        case UsageError.rateLimited(let retryAfter):
            return .rateLimited(retryAfter: retryAfter)
        case UsageError.httpError(let statusCode) where statusCode == 429:
            // OAuth token 端点的 429 以 httpError 形式透传，没有 Retry-After 可用
            return .rateLimited(retryAfter: nil)
        case UsageError.httpError(let statusCode) where statusCode >= 500:
            return .serverError
        case UsageError.cloudflareBlocked:
            return .serverError
        case UsageError.networkError:
            return .network
        default:
            return nil
        }
    }

    /// 判断 Codex 第 1 级刷新（SSR）的失败是否应改为退避、不再升级到第 2 级 WebView
    /// - Returns: 用于退避和错误提示的错误；nil 表示照旧升级
    /// - Note: 只认 429 和 5xx，比 backoffFailure 窄。403（Cloudflare）正是 WebView 要解决的问题，
    ///   必须照旧升级；协调器在「刷新已在进行中」时也返回 networkError，不能当作网络故障
    private func tier1BackoffError(for error: Error) -> UsageError? {
        switch error {
        case UsageError.httpError(let statusCode) where statusCode == 429:
            // 协调器不解析 Retry-After；换成 rateLimited 让错误提示显示本地化的限流文案
            return .rateLimited(retryAfter: nil)
        case UsageError.httpError(let statusCode) where statusCode >= 500:
            return .httpError(statusCode: statusCode)
        default:
            return nil
        }
    }

    /// 记录一次拉取失败，不可退避的错误直接忽略
    private func recordFetchFailure(_ error: Error, for provider: ProviderType) {
        guard let failure = backoffFailure(for: error) else { return }
        let next = UsageFetchBackoffPolicy.recordFailure(
            state: backoffState(for: provider),
            failure: failure,
            now: Date(),
            jitterFraction: Double.random(in: 0...UsageFetchBackoffPolicy.maxJitterFraction)
        )
        setBackoffState(next, for: provider)
        let delay = Int((next.retryNotBefore?.timeIntervalSinceNow ?? 0).rounded(.up))
        AppLog.warning(.refresh, "\(provider.displayName) automatic refreshes backing off for \(delay)s after \(next.consecutiveFailures) consecutive failure(s)")
    }

    /// 记录一次拉取成功：更新最后成功时间，并清除失败退避
    private func recordFetchSuccess(for provider: ProviderType) {
        refreshState.lastSuccessAt[provider] = Date()
        let state = backoffState(for: provider)
        guard state != .initial else { return }
        AppLog.event(.refresh, "\(provider.displayName) fetch succeeded after \(state.consecutiveFailures) failure(s); backoff cleared")
        setBackoffState(.initial, for: provider)
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
            AppLog.trace(.refresh, "Claude reset time already passed; not scheduling reset verification")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        AppLog.event(.refresh, "Scheduling Claude reset verification for \(formatter.string(from: resetsAt))")

        // 重置后1秒验证
        timerManager.schedule(TimerID.resetVerify1, interval: timeUntilReset + 1, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Claude reset verification +1s: refreshing")
            self?.fetchUsage()
        }

        // 重置后10秒验证
        timerManager.schedule(TimerID.resetVerify2, interval: timeUntilReset + 10, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Claude reset verification +10s: refreshing")
            self?.fetchUsage()
        }

        // 重置后30秒验证
        timerManager.schedule(TimerID.resetVerify3, interval: timeUntilReset + 30, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Claude reset verification +30s: refreshing")
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
            AppLog.trace(.refresh, "Codex reset time already passed; not scheduling reset verification")
            return
        }

        timerManager.schedule(TimerID.codexResetVerify1, interval: timeUntilReset + 1, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Codex reset verification +1s: refreshing")
            self?.fetchUsage()
        }

        timerManager.schedule(TimerID.codexResetVerify2, interval: timeUntilReset + 10, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Codex reset verification +10s: refreshing")
            self?.fetchUsage()
        }

        timerManager.schedule(TimerID.codexResetVerify3, interval: timeUntilReset + 30, repeats: false) { [weak self] in
            AppLog.trace(.refresh, "Codex reset verification +30s: refreshing")
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
