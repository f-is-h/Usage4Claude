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

    /// API clients are kept per account. The provider clients cancel an earlier
    /// request on the same instance, so sharing one client would make concurrent
    /// account refreshes cancel each other.
    private var claudeAPIServices: [UUID: ClaudeAPIService] = [:]
    private var codexAPIServices: [UUID: CodexAPIService] = [:]
    /// 定时器管理器
    private let timerManager = TimerManager()
    /// 用户设置实例
    private let settings = UserSettings.shared

    // MARK: - Published State

    /// Claude 用量数据
    @Published var usageData: UsageData?
    /// Codex 用量数据（nil 表示无 Codex 账号或拉取失败）
    @Published var codexUsageData: CodexUsageData?
    /// Most recent usage for every saved account, ordered with Claude accounts first.
    /// A failed refresh retains the account's last successful payload and updates only its error state.
    @Published private(set) var accountUsageSnapshots: [AccountUsageSnapshot] = []
    /// 加载状态
    @Published var isLoading = false
    /// 错误消息
    @Published var errorMessage: String?
    /// Codex 错误消息（独立于 Claude，避免双 Provider 时被静默隐藏）
    @Published var codexErrorMessage: String?
    /// 刷新状态管理器
    let refreshState = RefreshState()

    // MARK: - Private State

    /// Reset verification is account-scoped so one account cannot cancel another account's checks.
    private var resetVerificationDates: [UUID: Date] = [:]
    /// 上次手动刷新时间
    private var lastManualRefreshTime: Date?
    /// 上次API请求时间
    private var lastAPIFetchTime: Date?
    /// Monotonically increasing request generation prevents a cancelled, older
    /// refresh from publishing errors after a newer refresh has completed.
    private var refreshGeneration = 0
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

    private func accountMenuBarPlan() -> [AccountUsageSnapshot] {
        AccountMenuBarPlan.make(
            claudeAccounts: settings.claudeAccounts,
            codexAccounts: settings.codexAccounts
        ).filter { snapshot in
            switch snapshot.provider {
            case .claude:
                return !shouldSuppressDebugClaudeUsageForDisplayOptions
            case .codex:
                return !shouldSuppressDebugCodexUsageForDisplayOptions
            }
        }
    }

    /// 定时器标识符统一定义在 TimerManager.Identifier，避免两处各自为政
    private typealias TimerID = TimerManager.Identifier

    // MARK: - Initialization

    init() {
        setupWakeObserver()
    }

    // MARK: - Data Fetching

    /// Fetches every account by default; a provider-only refresh leaves the other provider's snapshots unchanged.
    func fetchUsage(provider: ProviderType? = nil) {
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        if provider == nil || provider == .claude { errorMessage = nil }
        if provider == nil || provider == .codex { codexErrorMessage = nil }
        lastAPIFetchTime = Date()

        let plan = accountMenuBarPlan()
        let accountsToFetch = provider.map { requestedProvider in
            plan.filter { $0.provider == requestedProvider }
        } ?? plan

        guard !plan.isEmpty else {
            accountUsageSnapshots = []
            clearClaudeUsageState()
            clearCodexUsageState()
            isLoading = false
            endRefreshAnimationWithMinimumDuration { }
            errorMessage = UsageError.noCredentials.localizedDescription
            return
        }

        // Publish the current account plan before any request completes so the
        // menu bar and popover can represent every account during the initial load.
        // The reducer preserves each account's last known payload and error state.
        accountUsageSnapshots = AccountUsageReducer.merge(
            plan: plan,
            previous: accountUsageSnapshots,
            results: [:]
        )

        // One dedicated service instance per account keeps the existing client-side
        // cancellation semantics local to that account while all accounts fetch together.
        let tasks: [Task<(UUID, Result<AccountUsagePayload, Error>), Never>] = accountsToFetch.compactMap { descriptor in
            guard let account = account(for: descriptor.id, provider: descriptor.provider) else { return nil }
            switch account.provider {
            case .claude:
                let service = claudeAPIService(for: account.id)
                return Task {
                    let result = await service.fetchUsageResult(for: account)
                    return (account.id, result.map(AccountUsagePayload.claude))
                }
            case .codex:
                let service = codexAPIService(for: account.id)
                return Task {
                    let result = await service.fetchUsageResult(for: account)
                    return (account.id, result.map(AccountUsagePayload.codex))
                }
            }
        }

        Task { @MainActor [weak self] in
            var results: [UUID: Result<AccountUsagePayload, Error>] = [:]
            for task in tasks {
                let (accountId, result) = await task.value
                results[accountId] = result
            }

            guard let self, generation == self.refreshGeneration else { return }
            self.isLoading = false
            self.endRefreshAnimationWithMinimumDuration { }
            self.apply(results: results, to: plan)
        }
    }

    private func account(for id: UUID, provider: ProviderType) -> Account? {
        switch provider {
        case .claude:
            settings.claudeAccounts.first { $0.id == id }
        case .codex:
            settings.codexAccounts.first { $0.id == id }
        }
    }

    private func claudeAPIService(for accountId: UUID) -> ClaudeAPIService {
        if let service = claudeAPIServices[accountId] { return service }
        let service = ClaudeAPIService()
        claudeAPIServices[accountId] = service
        return service
    }

    private func codexAPIService(for accountId: UUID) -> CodexAPIService {
        if let service = codexAPIServices[accountId] { return service }
        let service = CodexAPIService()
        codexAPIServices[accountId] = service
        return service
    }

    /// Atomically publish the all-account state, then preserve the existing selected-account
    /// bindings for the popover, notifications, reset checks, and relogin UX.
    private func apply(
        results: [UUID: Result<AccountUsagePayload, Error>],
        to plan: [AccountUsageSnapshot]
    ) {
        let previousSnapshots = accountUsageSnapshots
        accountUsageSnapshots = AccountUsageReducer.applying(
            results,
            to: previousSnapshots,
            plan: plan
        )
        processSuccessfulResults(results, previousSnapshots: previousSnapshots)

        let selectedClaudeId = settings.currentAccount?.id
        let selectedCodexId = settings.currentCodexAccount?.id
        applySelectedClaudeResult(selectedClaudeId.flatMap { results[$0] })
        applySelectedCodexResult(selectedCodexId.flatMap { results[$0] })
        updateSmartMonitoringFromSnapshots()
        pruneUnusedServices(using: plan)
        pruneResetVerifications(validAccountIds: Set(plan.map(\.id)))
    }

    private func processSuccessfulResults(
        _ results: [UUID: Result<AccountUsagePayload, Error>],
        previousSnapshots: [AccountUsageSnapshot]
    ) {
        let previousPayloads = Dictionary(uniqueKeysWithValues: previousSnapshots.map { ($0.id, $0.payload) })

        for (accountId, result) in results {
            guard case .success(let payload) = result else { continue }

            switch payload {
            case .claude(let usage):
                let previous: UsageData?
                if case .claude(let value)? = previousPayloads[accountId] {
                    previous = value
                } else {
                    previous = nil
                }
                if settings.notificationsEnabled {
                    NotificationManager.shared.checkAndNotify(
                        accountId: accountId,
                        usageData: usage,
                        previousData: previous
                    )
                }
                reconcileResetVerification(accountId: accountId, resetsAt: usage.resetsAt)

            case .codex(let usage):
                let previous: CodexUsageData?
                if case .codex(let value)? = previousPayloads[accountId] {
                    previous = value
                } else {
                    previous = nil
                }
                if settings.notificationsEnabled {
                    NotificationManager.shared.checkAndNotify(
                        accountId: accountId,
                        codexUsageData: usage,
                        previousData: previous
                    )
                }
                reconcileResetVerification(accountId: accountId, resetsAt: usage.primary?.resetsAt)
            }
        }
    }

    private func applySelectedClaudeResult(_ result: Result<AccountUsagePayload, Error>?) {
        switch result {
        case .success(.claude(let data)):
            usageData = data
            errorMessage = nil

        case .failure(let error):
            // The reducer has already retained any last good payload for this account.
            usageData = accountUsageSnapshots.selectedClaude(accountId: settings.currentAccount?.id)
            errorMessage = error.localizedDescription
            Logger.menuBar.error("Claude API 请求失败: \(error.localizedDescription)")

        case .success, .none:
            usageData = accountUsageSnapshots.selectedClaude(accountId: settings.currentAccount?.id)
            if settings.currentAccount == nil { clearClaudeUsageState() }
        }
    }

    private func applySelectedCodexResult(_ result: Result<AccountUsagePayload, Error>?) {
        switch result {
        case .success(.codex(let data)):
            processCodexSuccess(data)

        case .failure(let error):
            // Non-selected Codex errors never reach this path. The legacy 401 fallback
            // is intentionally retained only for the selected account.
            codexUsageData = accountUsageSnapshots.selectedCodex(accountId: settings.currentCodexAccount?.id)
            if case UsageError.unauthorized = error {
                selectedCodexAPIService?.clearAccessTokenCache()
                attemptTokenRefreshAndRetry()
            } else {
                codexErrorMessage = error.localizedDescription
                Logger.menuBar.info("Codex 请求失败（不影响其它账户）: \(error.localizedDescription)")
            }

        case .success, .none:
            codexUsageData = accountUsageSnapshots.selectedCodex(accountId: settings.currentCodexAccount?.id)
            if settings.currentCodexAccount == nil { clearCodexUsageState() }
        }
    }

    private var selectedCodexAPIService: CodexAPIService? {
        guard let accountId = settings.currentCodexAccount?.id else { return nil }
        return codexAPIServices[accountId]
    }

    private func updateSmartMonitoringFromSnapshots() {
        var utilizations: [ProviderType: Double] = [:]
        for snapshot in accountUsageSnapshots {
            let utilization: Double?
            switch snapshot.payload {
            case .claude(let usage):
                utilization = usage.percentage
            case .codex(let usage):
                utilization = monitoringUtilization(for: usage)
            case .none:
                utilization = nil
            }
            if let utilization {
                utilizations[snapshot.provider] = max(utilizations[snapshot.provider] ?? 0, utilization)
            }
        }
        settings.updateSmartMonitoringMode(providerUtilizations: utilizations)
    }

    private func pruneUnusedServices(using plan: [AccountUsageSnapshot]) {
        let validIDs = Set(plan.map(\.id))
        claudeAPIServices = claudeAPIServices.filter { validIDs.contains($0.key) }
        codexAPIServices = codexAPIServices.filter { validIDs.contains($0.key) }
    }

    private func clearClaudeUsageState() {
        usageData = nil
    }

    private func clearCodexUsageState(clearError: Bool = true) {
        codexUsageData = nil
        if clearError {
            codexErrorMessage = nil
        }
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
            guard let self, let account = self.settings.currentCodexAccount else { return }
            self.codexAPIService(for: account.id).proactivelyRefreshIfNeeded()
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
        guard !settings.claudeAccounts.isEmpty else { return }
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
        guard !settings.codexAccounts.isEmpty else {
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
        guard !settings.claudeAccounts.isEmpty else {
            clearClaudeUsageState()
            return
        }
        fetchUsage(provider: .claude)
    }

    private func fetchCodexOnly(retryOnUnauthorized: Bool = true) {
        guard !settings.codexAccounts.isEmpty else {
            clearCodexUsageState()
            return
        }
        // A failed selected-account retry must not fan out into another fallback loop.
        // The all-account refresh still retains each account's last good payload.
        if retryOnUnauthorized {
            fetchUsage(provider: .codex)
        } else if let account = settings.currentCodexAccount {
            fetchSelectedCodexUsageWithoutFallback(account)
        }
    }

    /// Retry used after the selected account's legacy silent-refresh flow. It is
    /// intentionally scoped to that account and does not restart the provider-wide
    /// loop or a second unauthorized fallback chain.
    private func fetchSelectedCodexUsageWithoutFallback(_ account: Account) {
        isLoading = true
        codexErrorMessage = nil
        lastAPIFetchTime = Date()
        let service = codexAPIService(for: account.id)
        let generation = refreshGeneration

        Task { @MainActor [weak self] in
            let result = await service.fetchUsageResult(for: account)
            guard let self, generation == self.refreshGeneration else { return }
            self.isLoading = false
            self.endRefreshAnimationWithMinimumDuration { }

            let plan = self.accountMenuBarPlan()
            let payloadResult = result.map(AccountUsagePayload.codex)
            let previousSnapshots = self.accountUsageSnapshots
            self.accountUsageSnapshots = AccountUsageReducer.applying(
                [account.id: payloadResult],
                to: previousSnapshots,
                plan: plan
            )
            self.processSuccessfulResults(
                [account.id: payloadResult],
                previousSnapshots: previousSnapshots
            )

            switch result {
            case .success(let data):
                self.processCodexSuccess(data)
            case .failure(let error):
                self.codexUsageData = self.accountUsageSnapshots.selectedCodex(accountId: account.id)
                self.codexErrorMessage = error.localizedDescription
                Logger.menuBar.info("Codex 重试失败: \(error.localizedDescription)")
            }
        }
    }

    private func processCodexSuccess(_ data: CodexUsageData) {
        codexUsageData = data
        codexErrorMessage = nil
        if let utilization = monitoringUtilization(for: data) {
            settings.updateSmartMonitoringMode(providerUtilizations: [.codex: utilization])
        }
    }

    private func attemptTokenRefreshAndRetry() {
        guard !codexNeedsRelogin else {
            Logger.menuBar.info("Codex 已确认需要重新登录，跳过刷新")
            markCodexNeedsRelogin()
            return
        }
        // OAuth 账户：refresh_token 已在 fetchUsage 内尝试续期，401 表示 refresh_token 失效。
        // 旧的 chatgpt.com 三级刷新链针对 session-token，对 OAuth 凭据无意义且必然失败，直接要求重新登录。
        guard let account = settings.currentCodexAccount else {
            markCodexNeedsRelogin()
            return
        }
        if CodexAPIService.isOAuthRefreshToken(account.sessionKey) {
            Logger.menuBar.info("Codex OAuth refresh_token 失效，需重新登录")
            markCodexNeedsRelogin()
            return
        }
        let prefix = account.sessionKey.prefix(16)
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
        guard let account = settings.currentCodexAccount else {
            markCodexNeedsRelogin()
            return
        }
        let generation = refreshGeneration
        codexAPIService(for: account.id).fetchUsageWithAccessToken(accessToken) { [weak self] usageResult in
            DispatchQueue.main.async {
                guard let self, generation == self.refreshGeneration else { return }
                self.isLoading = false
                self.endRefreshAnimationWithMinimumDuration { }
                switch usageResult {
                case .success(let data):
                    let previousSnapshots = self.accountUsageSnapshots
                    self.replaceSelectedCodexSnapshot(account: account, data: data)
                    self.processSuccessfulResults(
                        [account.id: .success(.codex(data))],
                        previousSnapshots: previousSnapshots
                    )
                    self.processCodexSuccess(data)
                case .failure(let error):
                    Logger.menuBar.error("Codex 新鲜 accessToken 仍失败: \(error.localizedDescription)，降级至级别2")
                    self.attemptLevel2WebViewRefresh()
                }
            }
        }
    }

    private func replaceSelectedCodexSnapshot(account: Account, data: CodexUsageData) {
        let plan = accountMenuBarPlan()
        accountUsageSnapshots = AccountUsageReducer.applying(
            [account.id: .success(.codex(data))],
            to: accountUsageSnapshots,
            plan: plan
        )
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
        // Keep the selected account's last good usage visible while its re-login
        // prompt is shown; the snapshot reducer owns stale-data retention.
        codexUsageData = accountUsageSnapshots.selectedCodex(accountId: settings.currentCodexAccount?.id)
        Logger.menuBar.error("Codex 三级刷新均已失败，需要用户重新登录")
    }

    /// 账户切换后只清理并刷新对应 Provider，避免跨账号 previousData 误判重置。
    /// 通知去重状态按账号隔离，切换账号时保留，删除账号时再由 UserSettings 精准清理。
    func handleAccountChanged(provider: ProviderType?) {
        refreshGeneration += 1
        reconcileSnapshotsWithCurrentAccounts()

        switch provider {
        case .claude:
            errorMessage = nil
            clearClaudeUsageState()
            if !settings.claudeAccounts.isEmpty {
                fetchClaudeOnly()
            }

        case .codex:
            resetCodexReloginState()
            selectedCodexAPIService?.clearAccessTokenCache()
            clearCodexUsageState()
            if !settings.codexAccounts.isEmpty {
                fetchCodexOnly()
            }

        case .none:
            clearClaudeUsageState()
            clearCodexUsageState()
            NotificationManager.shared.resetAllNotificationStates()
            fetchUsage()
        }
    }

    private func reconcileSnapshotsWithCurrentAccounts() {
        let plan = accountMenuBarPlan()
        accountUsageSnapshots = AccountUsageReducer.merge(
            plan: plan,
            previous: accountUsageSnapshots,
            results: [:]
        )
        pruneUnusedServices(using: plan)
        pruneResetVerifications(validAccountIds: Set(plan.map(\.id)))
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

    private func reconcileResetVerification(accountId: UUID, resetsAt: Date?) {
        guard let resetsAt, resetsAt.timeIntervalSinceNow > 0 else {
            cancelResetVerification(for: accountId)
            return
        }
        guard resetVerificationDates[accountId] != resetsAt else { return }

        cancelResetVerification(for: accountId)
        resetVerificationDates[accountId] = resetsAt
        let timeUntilReset = resetsAt.timeIntervalSinceNow
        for offset in [1.0, 10.0, 30.0] {
            timerManager.schedule(
                resetVerificationTimerID(accountId: accountId, offset: offset),
                interval: timeUntilReset + offset,
                repeats: false
            ) { [weak self] in
                self?.fetchUsage()
            }
        }
    }

    private func pruneResetVerifications(validAccountIds: Set<UUID>) {
        let removedAccountIds = resetVerificationDates.keys.filter { !validAccountIds.contains($0) }
        for accountId in removedAccountIds {
            cancelResetVerification(for: accountId)
        }
    }

    private func cancelResetVerification(for accountId: UUID) {
        for offset in [1.0, 10.0, 30.0] {
            timerManager.invalidate(resetVerificationTimerID(accountId: accountId, offset: offset))
        }
        resetVerificationDates.removeValue(forKey: accountId)
    }

    private func resetVerificationTimerID(accountId: UUID, offset: Double) -> String {
        "resetVerify.\(accountId.uuidString).\(Int(offset))"
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
