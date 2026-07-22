//
//  MenuBarManager.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import AppKit
import Combine
import OSLog
import Sparkle
import Carbon.HIToolbox

/// 刷新状态管理器
/// 用于在视图间同步刷新状态，支持响应式更新
class RefreshState: ObservableObject {
    /// 是否正在刷新
    @Published var isRefreshing = false
    /// 当前正在刷新的 Provider；nil 表示全量刷新
    @Published var refreshingProvider: ProviderType?
    /// 是否可以刷新（防抖控制）
    @Published var canRefresh = true
    /// Prevents duplicate warm-up requests while a batch is running.
    @Published var isWarmingUp = false
    /// 通知消息
    @Published var notificationMessage: String?
    /// 通知类型
    @Published var notificationType: NotificationType = .loading
    
    /// 通知类型
    enum NotificationType {
        case loading          // 彩虹加载动画
        case warmupSuccess
        case warmupFailure
    }

    func isRefreshingProvider(_ provider: ProviderType) -> Bool {
        isRefreshing && (refreshingProvider == nil || refreshingProvider == provider)
    }
}

/// 菜单栏管理器
/// 负责协调 UI 和数据层，管理设置窗口
class MenuBarManager: ObservableObject {
    // MARK: - Properties

    /// UI 管理器
    private let ui = MenuBarUI()
    /// 数据刷新管理器
    private let dataManager = DataRefreshManager()
    /// 设置窗口
    private var settingsWindow: NSWindow?
    /// 用户设置实例
    @ObservedObject private var settings = UserSettings.shared
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()
    /// 窗口关闭观察者
    private var windowCloseObserver: NSObjectProtocol?
    /// 语言变化观察者
    private var languageChangeObserver: NSObjectProtocol?
    private var menuBarProfileHotKeyRef: EventHotKeyRef?
    private var menuBarProfileHotKeyHandler: EventHandlerRef?

    /// 当前用量数据（从 dataManager 同步）
    @Published var usageData: UsageData?
    /// Codex 用量数据（从 dataManager 同步）
    @Published var codexUsageData: CodexUsageData?
    /// 多账户菜单栏用量数据（从 dataManager 同步）
    @Published var multiAccountUsage: [UUID: UsageData] = [:]
    /// 多 Codex 账户菜单栏用量数据（从 dataManager 同步）
    @Published var multiAccountCodexUsage: [UUID: CodexUsageData] = [:]
    /// 加载状态（从 dataManager 同步）
    @Published var isLoading = false
    /// 错误消息（从 dataManager 同步）
    @Published var errorMessage: String?
    /// Codex 错误消息（独立于 Claude）
    @Published var codexErrorMessage: String?
    /// Codex 三级刷新均失败，需要用户手动重新登录
    @Published var codexNeedsRelogin = false

    /// 刷新状态管理器（从 dataManager 引用）
    var refreshState: RefreshState {
        return dataManager.refreshState
    }

    // MARK: - Initialization

    init() {
        ui.configureClickHandler(target: self, action: #selector(handleClick))
        setupDataBindings()
        setupSettingsObservers()
        setupMenuBarProfileHotKey()
    }

    /// 设置数据绑定
    /// 将 dataManager 的状态同步到 MenuBarManager
    private func setupDataBindings() {
        dataManager.$usageData
            .sink { [weak self] data in
                self?.usageData = data
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        dataManager.$codexUsageData
            .sink { [weak self] data in
                self?.codexUsageData = data
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        dataManager.$multiAccountUsage
            .sink { [weak self] data in
                self?.multiAccountUsage = data
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        dataManager.$multiAccountCodexUsage
            .sink { [weak self] data in
                self?.multiAccountCodexUsage = data
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        dataManager.$isLoading
            .assign(to: &$isLoading)

        dataManager.$errorMessage
            .assign(to: &$errorMessage)

        dataManager.$codexErrorMessage
            .assign(to: &$codexErrorMessage)

        dataManager.$codexNeedsRelogin
            .assign(to: &$codexNeedsRelogin)
    }
    
    /// 处理菜单栏图标点击事件
    /// 左键切换弹出窗口，右键显示菜单
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            // 如果无法获取当前事件，默认作为左键点击处理
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    /// 显示右键菜单
    private func showMenu() {
        let menu = ui.createStandardMenu(
            warmupAllCount: eligibleWarmupAccounts.count,
            warmupIdleCount: idleWarmupAccounts.count,
            isWarmingUp: refreshState.isWarmingUp,
            target: self
        )
        ui.statusItem.menu = menu
        ui.statusItem.button?.performClick(nil)
        ui.statusItem.menu = nil
    }
    
    
    // MARK: - Menu Actions
    
    @objc func openClaudeStatus() {
        if let url = URL(string: "https://status.claude.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openCodexStatus() {
        if let url = URL(string: "https://status.openai.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Manual Warm-up

    /// Accounts currently shown in the menu bar view: in multi-account mode the
    /// accounts selected under "Menu Bar accounts", otherwise the single
    /// displayed (current) account. Warm-ups only ever touch these — accounts
    /// not selected in the current menu bar view are never warmed up.
    private var menuBarVisibleClaudeAccounts: [Account] {
        if settings.isMultiAccountMenuBarActive {
            return settings.menuBarAccounts
        }
        if let current = settings.currentAccount, current.provider == .claude {
            return [current]
        }
        return []
    }

    private var eligibleWarmupAccounts: [Account] {
        menuBarVisibleClaudeAccounts.filter { account in
            account.oauthToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    /// Matches UsageResetter: no known reset, or a reset already in the past, is idle.
    private var idleWarmupAccounts: [Account] {
        eligibleWarmupAccounts.filter { account in
            let data = multiAccountUsage[account.id]
                ?? (account.id == settings.currentAccountId ? usageData : nil)
            guard let reset = data?.fiveHour?.resetsAt else {
                return !account.hasLocallyActiveWarmupWindow
            }
            return reset <= Date()
        }
    }

    @objc func warmUpIdleAccounts() {
        performWarmup(accounts: idleWarmupAccounts)
    }

    @objc func warmUpAllAccounts() {
        performWarmup(accounts: eligibleWarmupAccounts)
    }

    private func performWarmup(accounts: [Account]) {
        guard !refreshState.isWarmingUp else { return }
        guard !accounts.isEmpty else {
            showWarmupMessage(L.Menu.warmUpNone, type: .warmupFailure)
            return
        }

        refreshState.isWarmingUp = true
        ClaudeWarmupService.shared.warmUp(accounts: accounts) { [weak self] summary in
            guard let self else { return }
            self.refreshState.isWarmingUp = false
            let type: RefreshState.NotificationType = summary.succeeded == summary.total
                ? .warmupSuccess : .warmupFailure
            self.showWarmupMessage(L.Menu.warmUpSucceeded(summary.succeeded, summary.total), type: type)

            let warmedAt = Date()
            for result in summary.results where result.succeeded {
                self.settings.markAccountWarmed(accountId: result.accountID, at: warmedAt)
            }

            for result in summary.results where !result.succeeded {
                Logger.menuBar.info("Warm-up failed for \(result.accountName, privacy: .public): \(result.error ?? "Unknown error", privacy: .public)")
            }

            // Refresh visible usage so newly anchored windows appear immediately.
            self.dataManager.fetchUsage()
        }
    }

    private func showWarmupMessage(_ message: String, type: RefreshState.NotificationType) {
        refreshState.notificationType = type
        refreshState.notificationMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard self?.refreshState.notificationMessage == message else { return }
            self?.refreshState.notificationMessage = nil
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    /// 处理菜单操作
    /// 关闭弹出窗口并执行相应的操作
    private func handleMenuAction(_ action: UsageDetailView.MenuAction) {
        switch action {
        case .refresh:
            dataManager.handleManualRefresh()
        case .refreshClaude:
            dataManager.handleClaudeOnlyRefresh()
        case .refreshCodex:
            dataManager.handleCodexOnlyRefresh()
        case .generalSettings:
            closePopover()
            openSettingsWindow(tab: 0)
        case .authSettings:
            closePopover()
            openSettingsWindow(tab: 1)
        case .about:
            closePopover()
            openSettingsWindow(tab: 2)
        case .claudeStatus:
            closePopover()
            openClaudeStatus()
        case .codexStatus:
            closePopover()
            openCodexStatus()
        case .coffee:
            closePopover()
            if let url = URL(string: "https://ko-fi.com/1atte") {
                NSWorkspace.shared.open(url)
            }
        case .githubSponsor:
            closePopover()
            openGithubSponsor()
        case .codexRelogin:
            closePopover()
            WebLoginWindowManager.shared.showCodexLoginWindow()
        case .warmUpIdle:
            warmUpIdleAccounts()
        case .warmUpAll:
            warmUpAllAccounts()
        case .quit:
            quitApp()
        }
    }

    /// 设置设置变更观察者
    /// 监听设置变更、刷新频率变更等通知
    private func setupSettingsObservers() {
        NotificationCenter.default.publisher(for: .settingsChanged)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 设置改变时清除图标缓存（显示模式可能改变）
                self.ui.clearIconCache()

                // 菜单栏账户选择可能变化：清理已取消选择的账户数据并补拉新选中账户
                self.dataManager.syncMultiAccountFetches()

                // 立即更新图标，无需等待
                self.updateMenuBarIcon()

                #if DEBUG
                // 调试模式下立即刷新数据（不使用防抖）
                self.dataManager.fetchUsage()
                #endif
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .refreshIntervalChanged)
            .sink { [weak self] _ in
                // 重启数据刷新定时器
                self?.dataManager.stopRefreshing()
                self?.dataManager.startRefreshing()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .openSettings)
            .sink { [weak self] notification in
                let tab = notification.userInfo?["tab"] as? Int ?? 0
                self?.openSettingsWindow(tab: tab)
            }
            .store(in: &cancellables)

        // 监听账户变更通知
        NotificationCenter.default.publisher(for: .accountChanged)
            .sink { [weak self] notification in
                guard let self = self else { return }
                Logger.menuBar.notice("账户已切换，刷新数据")
                let providerRaw = notification.userInfo?[Notification.UserInfoKey.provider] as? String
                let provider = providerRaw.flatMap { ProviderType(rawValue: $0) }
                // 清除图标缓存，确保新数据到达时重新渲染
                self.ui.clearIconCache()
                // 只刷新切换的 Provider，避免另一家的数据和通知状态被误清理
                self.dataManager.handleAccountChanged(provider: provider)
                // 更新菜单栏图标
                self.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover Management

    /// 切换弹出窗口显示状态
    @objc func togglePopover() {
        guard let button = ui.statusItem.button else { return }

        if ui.popover.isShown {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    /// 打开弹出窗口
    private func openPopover(relativeTo button: NSStatusBarButton) {
        // 智能刷新数据
        dataManager.refreshOnPopoverOpen()

        ui.setPopoverContentSize(usageDetailContentSize())

        // 创建并设置内容视图
        ui.setPopoverContent(UsageDetailView(
            usageData: Binding(
                get: { self.usageData },
                set: { self.usageData = $0 }
            ),
            multiAccountUsage: Binding(
                get: { self.multiAccountUsage },
                set: { self.multiAccountUsage = $0 }
            ),
            multiAccountCodexUsage: Binding(
                get: { self.multiAccountCodexUsage },
                set: { self.multiAccountCodexUsage = $0 }
            ),
            codexUsageData: Binding(
                get: { self.codexUsageData },
                set: { self.codexUsageData = $0 }
            ),
            errorMessage: Binding(
                get: { self.errorMessage },
                set: { self.errorMessage = $0 }
            ),
            codexErrorMessage: Binding(
                get: { self.codexErrorMessage },
                set: { self.codexErrorMessage = $0 }
            ),
            codexNeedsRelogin: Binding(
                get: { self.codexNeedsRelogin },
                set: { _ in }
            ),
            refreshState: self.refreshState,
            onMenuAction: { [weak self] action in
                self?.handleMenuAction(action)
            }
        ))

        // 打开 popover
        ui.openPopover(relativeTo: button)

        // 启动刷新定时器
        startPopoverRefreshTimer()
    }

    private func usageDetailContentSize() -> NSSize {
        let baseHeight: CGFloat = 190
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 5

        if settings.isMultiAccountMenuBarActive {
            let codexColumnCount = settings.menuBarCodexAccounts.count
            let columnCount = max(settings.menuBarAccounts.count + codexColumnCount, 1)
            return NSSize(width: min(CGFloat(columnCount) * 290, 870), height: 286)
        }

        if settings.isMultiProviderActive && (codexUsageData != nil || codexErrorMessage != nil || settings.hasValidCodexCredentials) {
            let claudeRowCount: Int
            if let data = usageData {
                let types = settings.getActiveDisplayTypes(usageData: data)
                    .filter { $0.provider == .claude }
                claudeRowCount = types.count == 1 ? 2 : max(types.count, 1)
            } else {
                claudeRowCount = 2
            }

            let codexRowCount: Int
            if let codex = codexUsageData {
                let codexTypes = settings.getActiveDisplayTypes(usageData: nil, codexUsageData: codex)
                    .filter { $0.provider == .codex }
                codexRowCount = max(codexTypes.count, 1)
            } else {
                codexRowCount = 2
            }
            let maxRows = max(claudeRowCount, codexRowCount)
            let rowsHeight = CGFloat(maxRows) * rowHeight + CGFloat(max(0, maxRows - 1)) * spacing
            return NSSize(width: 580, height: baseHeight + rowsHeight)
        }

        let shouldUseCodexOnlyLayout = (!settings.hasValidCredentials && settings.hasValidCodexCredentials)
            || (usageData == nil && (codexUsageData != nil || codexErrorMessage != nil))
        if shouldUseCodexOnlyLayout {
            let activeCount: Int
            if let codex = codexUsageData {
                activeCount = settings.getActiveDisplayTypes(usageData: nil, codexUsageData: codex)
                    .filter { $0.provider == .codex }
                    .count
            } else {
                activeCount = 0
            }
            let rowCount = activeCount == 1 ? 2 : max(activeCount, codexUsageData == nil ? 0 : 1)
            let rowsHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing
            return NSSize(width: 290, height: baseHeight + rowsHeight)
        }

        let activeCount: Int
        if let data = usageData {
            activeCount = settings.getActiveDisplayTypes(usageData: data)
                .filter { $0.provider == .claude }
                .count
        } else {
            activeCount = 0
        }
        let rowCount = activeCount == 1 ? 2 : activeCount
        let rowsHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing
        return NSSize(width: 290, height: baseHeight + rowsHeight)
    }

    /// 关闭弹出窗口
    private func closePopover() {
        ui.closePopover()

        // 清理刷新定时器
        dataManager.stopPopoverRefreshTimer()
    }

    /// 更新弹出窗口内容
    private func updatePopoverContent() {
        objectWillChange.send()
    }

    /// 启动弹出窗口刷新定时器
    private func startPopoverRefreshTimer() {
        dataManager.startPopoverRefreshTimer { [weak self] in
            self?.updatePopoverContent()
        }
    }
    
    // MARK: - Data Fetching

    /// 开始数据刷新
    func startRefreshing() {
        dataManager.startRefreshing()
    }
    
    // MARK: - Settings Window
    
    @objc func openSettings() {
        openSettingsWindow(tab: 0)
    }

    @objc func openGeneralSettings() {
        openSettingsWindow(tab: 0)
    }

    @objc func openAuthSettings() {
        openSettingsWindow(tab: 1)
    }

    @objc func openAbout() {
        openSettingsWindow(tab: 2)
    }

    @objc func openCoffee() {
        if let url = URL(string: "https://ko-fi.com/1atte") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openGithubSponsor() {
        if let url = URL(string: "https://github.com/sponsors/f-is-h?frequency=one-time") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 切换账户
    /// - Parameter sender: 发送菜单项，representedObject 包含 Account 对象
    @objc func switchAccount(_ sender: NSMenuItem) {
        guard let account = sender.representedObject as? Account else {
            Logger.menuBar.error("切换账户失败：无法获取账户信息")
            return
        }

        settings.switchToAccount(account)
    }

    /// 切换 Codex 账户
    @objc func switchCodexAccount(_ sender: NSMenuItem) {
        guard let account = sender.representedObject as? Account else { return }
        settings.switchToCodexAccount(account)
    }

    @objc func switchMenuBarProfile(_ sender: NSMenuItem) {
        guard let profileId = sender.representedObject as? UUID,
              let profile = settings.menuBarAccountProfiles.first(where: { $0.id == profileId }) else { return }
        settings.applyMenuBarAccountProfile(profile)
        dataManager.refreshOnPopoverOpen()
        updateMenuBarIcon()
    }

    @objc func cycleMenuBarProfile() {
        settings.cycleMenuBarAccountProfile()
        dataManager.refreshOnPopoverOpen()
        updateMenuBarIcon()
    }

    /// 打开设置窗口
    /// - Parameter tab: 要显示的标签页索引 (0: 通用, 1: 认证, 2: 关于)
    private func openSettingsWindow(tab: Int) {
        if settingsWindow == nil {
            // 切换为 regular 模式，使应用显示在 Dock 中
            NSApp.setActivationPolicy(.regular)
            
            let settingsView = SettingsView(initialTab: tab)
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentViewController: hostingController
            )
            settingsWindow?.title = L.Window.settingsTitle
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
            settingsWindow?.setFrameAutosaveName("Usage4Claude.SettingsWindow")

            // 移除旧的观察者（如果存在）
            if let observer = windowCloseObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            // 添加窗口关闭观察者
            windowCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: settingsWindow,
                queue: .main
            ) { [weak self] _ in
                // 窗口关闭时切换回 accessory 模式（不显示在 Dock）
                NSApp.setActivationPolicy(.accessory)

                self?.settingsWindow = nil
                if self?.settings.hasAnyValidCredentials == true
                    && self?.usageData == nil
                    && self?.codexUsageData == nil {
                    self?.startRefreshing()
                }
            }

            // 添加窗口获得焦点观察者 - 当设置窗口成为 key window 时关闭 popover
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: settingsWindow,
                queue: .main
            ) { [weak self] _ in
                #if DEBUG
                // Debug模式：如果开启了"保持详情窗口打开"，则不自动关闭
                if UserSettings.shared.debugKeepDetailWindowOpen {
                    return
                }
                #endif

                if self?.ui.popover.isShown == true {
                    self?.closePopover()
                }
            }

            // 移除旧的语言变化观察者（如果存在）
            if let observer = languageChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }

            // 添加语言变化观察者 - 当语言切换时更新窗口标题
            languageChangeObserver = NotificationCenter.default.addObserver(
                forName: .languageChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.settingsWindow?.title = L.Window.settingsTitle
            }
        }

        // 先激活应用，再居中和显示窗口
        NSApp.activate(ignoringOtherApps: true)

        // 延迟一小段时间确保应用激活完成后再居中窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.settingsWindow?.center()
            self?.settingsWindow?.makeKeyAndOrderFront(nil)
        }

        if ui.popover.isShown {
            closePopover()
        }
    }
    
    // MARK: - Icon Management

    /// 更新菜单栏图标
    private func updateMenuBarIcon() {
        ui.updateMenuBarIcon(usageData: usageData, codexUsageData: codexUsageData, multiAccountUsage: multiAccountUsage, multiAccountCodexUsage: multiAccountCodexUsage)
    }

    // MARK: - Menu Bar Profile Hotkey

    private func setupMenuBarProfileHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<MenuBarManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.cycleMenuBarProfile()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &menuBarProfileHotKeyHandler
        )

        guard installStatus == noErr else {
            Logger.menuBar.error("菜单栏账户配置快捷键监听注册失败: \(installStatus)")
            return
        }

        var hotKeyID = EventHotKeyID(signature: Self.fourCharCode("U4CP"), id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
            UInt32(cmdKey | optionKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &menuBarProfileHotKeyRef
        )

        if hotKeyStatus != noErr {
            Logger.menuBar.error("菜单栏账户配置快捷键注册失败: \(hotKeyStatus)")
        }
    }

    private func unregisterMenuBarProfileHotKey() {
        if let hotKeyRef = menuBarProfileHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            menuBarProfileHotKeyRef = nil
        }
        if let handler = menuBarProfileHotKeyHandler {
            RemoveEventHandler(handler)
            menuBarProfileHotKeyHandler = nil
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
    
    // MARK: - Cleanup
    
    /// 清理所有资源
    /// 在应用退出时调用，停止所有定时器并移除所有观察者
    func cleanup() {
        unregisterMenuBarProfileHotKey()

        // 停止 popover 刷新定时器
        dataManager.stopPopoverRefreshTimer()

        // 清理窗口观察者
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }

        // 清理语言变化观察者
        if let observer = languageChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            languageChangeObserver = nil
        }

        // 取消所有 Combine 订阅
        cancellables.removeAll()

        // 清理 UI
        ui.cleanup()

        // 清理数据管理器
        dataManager.cleanup()

        // 关闭窗口
        settingsWindow?.close()
        settingsWindow = nil
    }
    
    deinit {
        cleanup()
    }
}
