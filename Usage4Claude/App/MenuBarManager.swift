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

/// 刷新状态管理器
/// 用于在视图间同步刷新状态，支持响应式更新
class RefreshState: ObservableObject {
    /// 是否正在刷新
    @Published var isRefreshing = false
    /// 是否可以刷新（防抖控制）
    @Published var canRefresh = true
    /// 通知消息
    @Published var notificationMessage: String?
    /// 通知类型
    @Published var notificationType: NotificationType = .loading
    
    /// 通知类型
    enum NotificationType {
        case loading          // 彩虹加载动画
        case updateAvailable  // 彩虹文字通知
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

    /// 当前用量数据（从 dataManager 同步）
    @Published var usageData: UsageData?
    /// 加载状态（从 dataManager 同步）
    @Published var isLoading = false
    /// 错误消息（从 dataManager 同步）
    @Published var errorMessage: String?
    /// 是否有可用更新（从 dataManager 同步）
    @Published var hasAvailableUpdate = false
    /// 最新版本号（从 dataManager 同步）
    @Published var latestVersion: String?
    /// 用户已确认的版本号（点击检查更新后记录）
    private var acknowledgedVersion: String?

    /// 刷新状态管理器（从 dataManager 引用）
    var refreshState: RefreshState {
        return dataManager.refreshState
    }

    /// 是否应该显示徽章和通知（用户未确认时才显示）
    var shouldShowUpdateBadge: Bool {
        guard hasAvailableUpdate, let latest = latestVersion else { return false }
        return acknowledgedVersion != latest
    }

    // MARK: - Initialization

    init() {
        ui.configureClickHandler(target: self, action: #selector(handleClick))
        setupDataBindings()
        setupSettingsObservers()
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

        dataManager.$isLoading
            .assign(to: &$isLoading)

        dataManager.$errorMessage
            .assign(to: &$errorMessage)

        dataManager.$hasAvailableUpdate
            .sink { [weak self] hasUpdate in
                self?.hasAvailableUpdate = hasUpdate
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        dataManager.$latestVersion
            .assign(to: &$latestVersion)
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
        let menu = ui.createStandardMenu(hasUpdate: hasAvailableUpdate, shouldShowBadge: shouldShowUpdateBadge, target: self)
        ui.statusItem.menu = menu
        ui.statusItem.button?.performClick(nil)
        ui.statusItem.menu = nil
    }
    
    
    // MARK: - Menu Actions
    
    @objc func openWebUsage() {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
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
            // 处理手动刷新
            dataManager.handleManualRefresh()
        case .generalSettings:
            closePopover()
            openSettingsWindow(tab: 0)
        case .authSettings:
            closePopover()
            openSettingsWindow(tab: 1)
        case .checkForUpdates:
            closePopover()
            checkForUpdates()
        case .about:
            closePopover()
            openSettingsWindow(tab: 2)
        case .webUsage:
            closePopover()
            openWebUsage()
        case .coffee:
            closePopover()
            if let url = URL(string: "https://ko-fi.com/1atte") {
                NSWorkspace.shared.open(url)
            }
        case .githubSponsor:
            closePopover()
            openGithubSponsor()
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

                // 立即更新图标，无需等待
                self.updateMenuBarIcon()

                #if DEBUG
                // 调试模式下立即刷新数据（不使用防抖）
                self.dataManager.fetchUsage()

                // 如果模拟更新设置发生变化，重新应用更新状态
                if self.settings.simulateUpdateAvailable {
                    self.hasAvailableUpdate = true
                    self.latestVersion = "2.0.0"
                    Logger.menuBar.debug("模拟更新已启用")
                } else {
                    self.hasAvailableUpdate = false
                    self.latestVersion = ""
                    Logger.menuBar.debug("模拟更新已禁用")
                }
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

        // 显示更新通知（如果有）
        showUpdateNotificationIfNeeded()

        // 创建并设置内容视图
        ui.setPopoverContent(UsageDetailView(
            usageData: Binding(
                get: { self.usageData },
                set: { self.usageData = $0 }
            ),
            errorMessage: Binding(
                get: { self.errorMessage },
                set: { self.errorMessage = $0 }
            ),
            refreshState: self.refreshState,
            onMenuAction: { [weak self] action in
                self?.handleMenuAction(action)
            },
            hasAvailableUpdate: Binding(
                get: { self.hasAvailableUpdate },
                set: { self.hasAvailableUpdate = $0 }
            ),
            shouldShowUpdateBadge: Binding(
                get: { self.shouldShowUpdateBadge },
                set: { _ in }
            )
        ))

        // 打开 popover
        ui.openPopover(relativeTo: button)

        // 启动刷新定时器
        startPopoverRefreshTimer()
    }

    /// 显示更新通知（如果需要）
    private func showUpdateNotificationIfNeeded() {
        guard shouldShowUpdateBadge else { return }

        dataManager.refreshState.notificationMessage = L.Update.Notification.available
        dataManager.refreshState.notificationType = .updateAvailable

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.dataManager.refreshState.notificationMessage = nil
        }
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

    @objc func checkForUpdates() {
        // 记录用户已确认当前版本的更新
        if let version = latestVersion {
            acknowledgedVersion = version
            // 触发UI更新（隐藏徽章和通知）
            objectWillChange.send()
            // 更新菜单栏图标
            updateMenuBarIcon()
        }

        // 手动检查更新（会弹出对话框）
        dataManager.checkForUpdatesManually()
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
                if self?.settings.hasValidCredentials == true && self?.usageData == nil {
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
        ui.updateMenuBarIcon(usageData: usageData, hasUpdate: hasAvailableUpdate, shouldShowBadge: shouldShowUpdateBadge)
    }
    
    // MARK: - Cleanup
    
    /// 清理所有资源
    /// 在应用退出时调用，停止所有定时器并移除所有观察者
    func cleanup() {
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
