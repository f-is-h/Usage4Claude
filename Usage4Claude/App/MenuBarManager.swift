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
/// 负责管理菜单栏图标、弹出窗口、设置窗口和数据刷新
class MenuBarManager: ObservableObject {
    // MARK: - Properties
    
    /// 系统菜单栏状态项
    private var statusItem: NSStatusItem!
    /// 详情弹出窗口
    private var popover: NSPopover!
    /// 设置窗口
    private var settingsWindow: NSWindow?
    /// 数据刷新定时器
    private var timer: Timer?
    /// 弹出窗口实时刷新定时器（1秒间隔）
    private var popoverRefreshTimer: Timer?
    /// 重置验证定时器 - 重置后1秒
    private var resetVerifyTimer1: Timer?
    /// 重置验证定时器 - 重置后10秒
    private var resetVerifyTimer2: Timer?
    /// 重置验证定时器 - 重置后30秒
    private var resetVerifyTimer3: Timer?
    /// Claude API 服务实例
    private let apiService = ClaudeAPIService()
    /// 更新检查器实例
    private let updateChecker = UpdateChecker()
    /// 用户设置实例
    @ObservedObject private var settings = UserSettings.shared
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()
    /// 窗口关闭观察者
    private var windowCloseObserver: NSObjectProtocol?
    
    /// 当前用量数据
    @Published var usageData: UsageData?
    /// 加载状态
    @Published var isLoading = false
    /// 错误消息
    @Published var errorMessage: String?
    /// 上次的重置时间（用于检测重置是否完成）
    private var lastResetsAt: Date?
    /// 刷新状态管理器
    let refreshState = RefreshState()
    /// 上次手动刷新时间
    private var lastManualRefreshTime: Date?
    /// 上次API请求时间
    private var lastAPIFetchTime: Date?
    /// 刷新动画开始时间（用于确保动画最小显示时长）
    private var refreshAnimationStartTime: Date?
    /// 动画最小显示时长（秒）
    private let minimumAnimationDuration: TimeInterval = 1.0
    /// 是否有可用更新
    @Published var hasAvailableUpdate = false
    /// 最新版本号
    @Published var latestVersion: String?
    /// 用户已确认的版本号（点击检查更新后记录）
    private var acknowledgedVersion: String?
    /// 上次检查更新时间
    private var lastUpdateCheckTime: Date?
    /// 每日更新检查定时器
    private var dailyUpdateTimer: Timer?

    /// 图标缓存：键为 "mode_percentage"，值为缓存的图标
    private var iconCache: [String: NSImage] = [:]
    /// 缓存的最大条目数
    private let maxCacheSize = 50

    /// 是否应该显示徽章和通知（用户未确认时才显示）
    var shouldShowUpdateBadge: Bool {
        guard hasAvailableUpdate, let latest = latestVersion else { return false }
        // 如果用户已经确认过这个版本，则不显示徽章
        return acknowledgedVersion != latest
    }
    
    // MARK: - Initialization
    
    init() {
        setupStatusItem()
        setupPopover()
        setupSettingsObservers()
        scheduleDailyUpdateCheck()
    }
    
    /// 初始化菜单栏状态项
    /// 设置点击事件处理
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateMenuBarIcon(percentage: 0)
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
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
        let menu = createStandardMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    /// 为菜单项设置图标
    /// 统一设置图标尺寸和样式
    /// - Parameters:
    ///   - item: 菜单项
    ///   - systemName: SF Symbol 图标名称
    private func setMenuItemIcon(_ item: NSMenuItem, systemName: String) {
        if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = true
            item.image = image
        }
    }
    
    /// 创建标准菜单
    /// 用于右键菜单和弹出窗口中的三点菜单，确保菜单内容一致
    /// - Returns: 配置好的 NSMenu 实例
    private func createStandardMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 通用设置
        let generalItem = NSMenuItem(
            title: L.Menu.generalSettings,
            action: #selector(openGeneralSettings),
            keyEquivalent: ","
        )
        generalItem.target = self
        setMenuItemIcon(generalItem, systemName: "gearshape")
        menu.addItem(generalItem)
        
        // 认证信息
        let authItem = NSMenuItem(
            title: L.Menu.authSettings,
            action: #selector(openAuthSettings),
            keyEquivalent: "a"
        )
        authItem.target = self
        authItem.keyEquivalentModifierMask = [.command, .shift]
        setMenuItemIcon(authItem, systemName: "key.horizontal")
        menu.addItem(authItem)
        
        // 检查更新
        let updateItem = NSMenuItem(
            title: "",
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        )
        updateItem.target = self
        
        // 根据是否有更新设置不同的样式
        if hasAvailableUpdate {
            // 有更新：显示彩虹文字（即使用户已确认也保留）
            let baseText = L.Menu.checkUpdates
            let highlightText = L.Update.Notification.badgeMenu
            // 使用制表符来实现右对齐效果
            let title = "\(baseText)\t\(highlightText)"

            // 使用UTF-16长度正确计算range（支持emoji）
            let highlightLocation = baseText.utf16.count + 1  // 基础文本 + 1个制表符
            let highlightLength = highlightText.utf16.count
            let highlightRange = NSRange(location: highlightLocation, length: highlightLength)

            let attributedTitle = createRainbowText(title, highlightRange: highlightRange)
            updateItem.attributedTitle = attributedTitle

            // 徽章图标：仅在用户未确认时显示
            if shouldShowUpdateBadge {
                if let badgeImage = createBadgeIcon() {
                    updateItem.image = badgeImage
                }
            } else {
                // 用户已确认，不显示徽章，使用普通图标
                setMenuItemIcon(updateItem, systemName: "arrow.triangle.2.circlepath")
            }
        } else {
            // 无更新：普通样式
            updateItem.title = L.Menu.checkUpdates
            setMenuItemIcon(updateItem, systemName: "arrow.triangle.2.circlepath")
        }
        
        menu.addItem(updateItem)
        
        // 关于
        let aboutItem = NSMenuItem(
            title: L.Menu.about,
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        setMenuItemIcon(aboutItem, systemName: "info.circle")
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 访问 Claude 用量
        let webItem = NSMenuItem(
            title: L.Menu.webUsage,
            action: #selector(openWebUsage),
            keyEquivalent: "w"
        )
        webItem.target = self
        webItem.keyEquivalentModifierMask = [.command, .shift]
        setMenuItemIcon(webItem, systemName: "safari")
        menu.addItem(webItem)
        
        // Buy Me A Coffee
        let coffeeItem = NSMenuItem(
            title: L.Menu.coffee,
            action: #selector(openCoffee),
            keyEquivalent: ""
        )
        coffeeItem.target = self
        setMenuItemIcon(coffeeItem, systemName: "cup.and.saucer")
        menu.addItem(coffeeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(
            title: L.Menu.quit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        setMenuItemIcon(quitItem, systemName: "power")
        menu.addItem(quitItem)
        
        return menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func openWebUsage() {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    /// 处理菜单操作
    /// 关闭弹出窗口并执行相应的操作
    private func handleMenuAction(_ action: UsageDetailView.MenuAction) {
        switch action {
        case .refresh:
            // 处理手动刷新
            handleManualRefresh()
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
        case .quit:
            quitApp()
        }
    }
    
    /// 设置设置变更观察者
    /// 监听设置变更、刷新频率变更等通知
    private func setupSettingsObservers() {
        NotificationCenter.default.publisher(for: .settingsChanged)
            .sink { [weak self] _ in
                // 设置改变时清除图标缓存（显示模式可能改变）
                self?.iconCache.removeAll()
                self?.updateMenuBarIcon(percentage: self?.usageData?.percentage ?? 0)

                #if DEBUG
                // 如果模拟更新设置发生变化，重新应用更新状态
                if let self = self {
                    if self.settings.simulateUpdateAvailable {
                        self.hasAvailableUpdate = true
                        self.latestVersion = "2.0.0"
                        Logger.menuBar.debug("模拟更新已启用")
                    } else {
                        self.hasAvailableUpdate = false
                        self.latestVersion = ""
                        Logger.menuBar.debug("模拟更新已禁用")
                    }
                    // 刷新图标以显示/隐藏更新徽章
                    if let percentage = self.usageData?.percentage {
                        self.updateMenuBarIcon(percentage: percentage)
                    }
                }
                #endif
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .refreshIntervalChanged)
            .sink { [weak self] _ in
                self?.restartTimer()
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
    
    /// 初始化弹出窗口
    /// 设置窗口尺寸、外观和内容视图
    private func setupPopover() {
        popover = NSPopover()
        // 固定尺寸以避免布局跳动
        popover.contentSize = NSSize(width: 280, height: 240)
        
        let hostingController = NSHostingController(
            rootView: UsageDetailView(
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
                hasAvailableUpdate: self.hasAvailableUpdate,  // 传入更新状态（菜单文字）
                shouldShowUpdateBadge: self.shouldShowUpdateBadge  // 传入徽章显示状态（用户未确认时才显示）
            )
        )
        popover.contentViewController = hostingController

        // 让 SwiftUI 自动处理 appearance，跟随系统 Light/Dark 模式
    }
    
    /// 切换弹出窗口显示状态
    /// 打开时会重新创建内容视图并启动实时刷新定时器
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    /// 打开弹出窗口
    /// - Parameter button: 菜单栏按钮
    private func openPopover(relativeTo button: NSStatusBarButton) {
        // 智能刷新数据
        refreshOnPopoverOpen()

        // 显示更新通知（如果有）
        showUpdateNotificationIfNeeded()

        // 创建并设置内容视图控制器
        popover.contentViewController = createPopoverContentViewController()

        // 显示 popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 配置 popover 窗口
        configurePopoverWindow()

        // 启动定时器和监听器
        startPopoverRefreshTimer()
        setupPopoverCloseObserver()
    }

    /// 显示更新通知（如果需要）
    private func showUpdateNotificationIfNeeded() {
        guard shouldShowUpdateBadge else { return }

        refreshState.notificationMessage = L.Update.Notification.available
        refreshState.notificationType = .updateAvailable

        // 3秒后恢复正常显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.refreshState.notificationMessage = nil
        }
    }

    /// 创建 popover 内容视图控制器
    /// - Returns: 配置好的 NSHostingController
    private func createPopoverContentViewController() -> NSHostingController<UsageDetailView> {
        return NSHostingController(
            rootView: UsageDetailView(
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
                hasAvailableUpdate: self.hasAvailableUpdate,
                shouldShowUpdateBadge: self.shouldShowUpdateBadge
            )
        )
    }

    /// 配置 popover 窗口属性
    private func configurePopoverWindow() {
        guard let popoverWindow = popover.contentViewController?.view.window else { return }

        // 设置窗口level，确保显示在其他窗口之上
        popoverWindow.level = .popUpMenu

        // 禁止窗口成为key window，避免Focus外观变化
        popoverWindow.styleMask.remove(.titled)
    }
    
    /// 关闭弹出窗口
    /// 停止定时器并移除事件监听器
    private func closePopover() {
        // 确保 popover 关闭
        if popover.isShown {
            popover.performClose(nil)
        }
        
        // 清理刷新定时器
        popoverRefreshTimer?.invalidate()
        popoverRefreshTimer = nil
        
        // 移除事件监听器
        removePopoverCloseObserver()
    }
    
    /// 弹出窗口关闭监听器
    private var popoverCloseObserver: Any?
    
    /// 设置弹出窗口外部点击监听
    /// 点击 popover 外部时自动关闭
    private func setupPopoverCloseObserver() {
        // 先移除旧的观察者，防止累积
        removePopoverCloseObserver()

        // 监听鼠标点击事件，点击popover外部时关闭
        popoverCloseObserver = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return event }
            
            // 检查点击是否在popover或status item之外
            if let popoverWindow = self.popover.contentViewController?.view.window,
               let statusButton = self.statusItem.button {
                let popoverFrame = popoverWindow.frame
                let buttonFrame = statusButton.window?.convertToScreen(statusButton.frame) ?? .zero
                let screenClickLocation = NSEvent.mouseLocation
                
                // 如果点击在popover和button之外，关闭popover
                if !popoverFrame.contains(screenClickLocation) && !buttonFrame.contains(screenClickLocation) {
                    self.closePopover()
                }
            }
            
            return event
        }
    }
    
    /// 移除弹出窗口监听器
    private func removePopoverCloseObserver() {
        if let observer = popoverCloseObserver {
            NSEvent.removeMonitor(observer)
            popoverCloseObserver = nil
        }
    }
    
    /// 更新弹出窗口内容
    /// 用于实时刷新倒计时显示
    private func updatePopoverContent() {
        // 语言变化时视图会因为 .id() 自动重新创建，无需手动处理
        // 这里只需要触发 usageData 的更新，视图会自动响应
        objectWillChange.send()
    }
    
    /// 启动弹出窗口刷新定时器
    /// 每秒更新一次内容，以实现实时倒计时
    private func startPopoverRefreshTimer() {
        popoverRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePopoverContent()
        }
    }
    
    // MARK: - Data Fetching
    
    /// 开始数据刷新
    /// 立即获取一次数据并启动定时器
    func startRefreshing() {
        fetchUsage()
        restartTimer()
        
        #if DEBUG
        // 🧪 测试：确保图标显示徽章
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let percentage = self?.usageData?.percentage {
                self?.updateMenuBarIcon(percentage: percentage)
            }
        }
        #endif
    }
    
    /// 重启刷新定时器
    /// 根据用户设置的刷新频率重新创建定时器
    /// 智能模式下会根据监控模式动态调整间隔
    private func restartTimer() {
        timer?.invalidate()
        let interval = TimeInterval(settings.effectiveRefreshInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }
    
    // MARK: - Settings Window
    
    @objc private func openSettings() {
        openSettingsWindow(tab: 0)
    }
    
    @objc private func openGeneralSettings() {
        openSettingsWindow(tab: 0)
    }
    
    @objc private func openAuthSettings() {
        openSettingsWindow(tab: 1)
    }
    
    @objc private func openAbout() {
        openSettingsWindow(tab: 2)
    }
    
    @objc private func openCoffee() {
        if let url = URL(string: "https://ko-fi.com/1atte") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func checkForUpdates() {
        // 记录用户已确认当前版本的更新
        if let version = latestVersion {
            acknowledgedVersion = version
            // 触发UI更新（隐藏徽章和通知）
            objectWillChange.send()
            // 更新菜单栏图标
            if let percentage = usageData?.percentage {
                updateMenuBarIcon(percentage: percentage)
            }
        }

        // 手动检查更新（会弹出对话框）
        updateChecker.checkForUpdates(manually: true)
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
            
            // 添加新的观察者并保存引用
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
        }
        
        // 先激活应用，再居中和显示窗口
        NSApp.activate(ignoringOtherApps: true)
        
        // 延迟一小段时间确保应用激活完成后再居中窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.settingsWindow?.center()
            self?.settingsWindow?.makeKeyAndOrderFront(nil)
        }
        
        if popover.isShown {
            closePopover()
        }
    }
    
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
                    self.usageData = data
                    self.updateStatusBarIcon(percentage: data.percentage)
                    self.errorMessage = nil

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
    
    // MARK: - Refresh Methods
    
    /// 打开Popover时的智能刷新
    /// 如果距离上次刷新 > 30秒，则立即刷新数据
    private func refreshOnPopoverOpen() {
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
    private func handleManualRefresh() {
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
        resetVerifyTimer1?.invalidate()
        resetVerifyTimer2?.invalidate()
        resetVerifyTimer3?.invalidate()
        resetVerifyTimer1 = nil
        resetVerifyTimer2 = nil
        resetVerifyTimer3 = nil
    }
    
    /// 安排重置时间验证
    /// 在重置时间过后的1秒、10秒、30秒分别触发一次刷新
    /// 如果检测到重置时间变化，会自动取消后续验证
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
        resetVerifyTimer1 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 1,
            repeats: false
        ) { [weak self] _ in
            Logger.menuBar.debug("重置验证 +1秒 - 开始刷新")
            self?.fetchUsage()
            self?.resetVerifyTimer1 = nil
        }

        // 重置后10秒验证
        resetVerifyTimer2 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 10,
            repeats: false
        ) { [weak self] _ in
            Logger.menuBar.debug("重置验证 +10秒 - 开始刷新")
            self?.fetchUsage()
            self?.resetVerifyTimer2 = nil
        }

        // 重置后30秒验证
        resetVerifyTimer3 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 30,
            repeats: false
        ) { [weak self] _ in
            Logger.menuBar.debug("重置验证 +30秒 - 开始刷新")
            self?.fetchUsage()
            self?.resetVerifyTimer3 = nil
        }
    }
    
    // MARK: - Icon Drawing
    
    /// 更新菜单栏图标
    /// - Parameter percentage: 当前使用百分比
    private func updateStatusBarIcon(percentage: Double) {
        updateMenuBarIcon(percentage: percentage)
    }
    
    /// 根据用户设置更新菜单栏图标
    /// 支持三种显示模式：仅百分比、仅图标、两者组合
    /// - Parameter percentage: 当前使用百分比
    private func updateMenuBarIcon(percentage: Double) {
        guard let button = statusItem.button else { return }
        guard let data = usageData else { return }

        // 生成缓存键（包含5小时和7天的百分比）
        let cacheKey: String
        if data.hasBothLimits, let fiveHour = data.fiveHour, let sevenDay = data.sevenDay {
            cacheKey = "\(settings.iconDisplayMode.rawValue)_\(Int(fiveHour.percentage))_\(Int(sevenDay.percentage))"
        } else {
            cacheKey = "\(settings.iconDisplayMode.rawValue)_\(Int(percentage))"
        }

        var baseImage: NSImage?

        // 尝试从缓存获取
        if let cachedImage = iconCache[cacheKey] {
            baseImage = cachedImage
        } else {
            // 缓存未命中，创建新图标
            switch settings.iconDisplayMode {
            case .percentageOnly:
                if data.hasBothLimits, let fiveHour = data.fiveHour, let sevenDay = data.sevenDay {
                    // 场景2：双圆环（并排显示）
                    baseImage = createDualCircleImage(
                        fiveHourPercentage: fiveHour.percentage,
                        sevenDayPercentage: sevenDay.percentage,
                        size: NSSize(width: 18, height: 18)
                    )
                } else if let fiveHour = data.fiveHour {
                    // 场景1a：仅5小时限制（绿/橙/红配色）
                    baseImage = createCircleImage(percentage: fiveHour.percentage, size: NSSize(width: 18, height: 18))
                } else if let sevenDay = data.sevenDay {
                    // 场景1b：仅7天限制（紫色系配色）
                    baseImage = createCircleImage(percentage: sevenDay.percentage, size: NSSize(width: 18, height: 18), useSevenDayColor: true)
                }
            case .iconOnly:
                if let appIcon = NSImage(named: "AppIcon"),
                   let iconCopy = appIcon.copy() as? NSImage {
                    iconCopy.size = NSSize(width: 18, height: 18)
                    iconCopy.isTemplate = false
                    baseImage = iconCopy
                } else {
                    baseImage = createSimpleCircleIcon()
                }
            case .both:
                if data.hasBothLimits, let fiveHour = data.fiveHour, let sevenDay = data.sevenDay {
                    // 双限制：显示应用图标 + 双圆环
                    baseImage = createCombinedDualImage(
                        fiveHourPercentage: fiveHour.percentage,
                        sevenDayPercentage: sevenDay.percentage
                    )
                } else if let fiveHour = data.fiveHour {
                    // 单限制（仅5小时）：应用图标 + 单圆环（绿/橙/红）
                    baseImage = createCombinedImage(percentage: fiveHour.percentage)
                } else if let sevenDay = data.sevenDay {
                    // 单限制（仅7天）：应用图标 + 单圆环（紫色系）
                    baseImage = createCombinedImage(percentage: sevenDay.percentage, useSevenDayColor: true)
                }
            }

            // 存入缓存
            if let image = baseImage {
                // 如果缓存已满，移除最旧的条目
                if iconCache.count >= maxCacheSize {
                    iconCache.removeValue(forKey: iconCache.keys.first!)
                }
                iconCache[cacheKey] = image
            }
        }

        // 如果有更新且用户未确认，添加徽章
        if shouldShowUpdateBadge, let base = baseImage {
            button.image = addBadgeToImage(base)
        } else {
            button.image = baseImage
        }
    }
    
    /// 在图标上添加徽章（小红点）
    /// - Parameter baseImage: 基础图标
    /// - Returns: 带徽章的图标
    private func addBadgeToImage(_ baseImage: NSImage) -> NSImage {
        let size = baseImage.size
        // 适度扩大画布以容纳徽章
        let expandedSize = NSSize(width: size.width + 3, height: size.height + 3)
        let badgedImage = NSImage(size: expandedSize)

        badgedImage.lockFocus()

        // 绘制原图标（居左下）
        baseImage.draw(in: NSRect(origin: .zero, size: size))

        // 右上角添加完美圆形红点（适中位置）
        let badgeRadius: CGFloat = 3  // 徽章半径
        let badgeDiameter = badgeRadius * 2

        // 确保是正方形区域以绘制完美圆形，位置适中
        let badgeX = expandedSize.width - badgeDiameter - 0.5  // 距离右边缘0.5px
        let badgeY = expandedSize.height - badgeDiameter - 0.5  // 距离上边缘0.5px
        let badgeRect = NSRect(
            x: badgeX,
            y: badgeY,
            width: badgeDiameter,
            height: badgeDiameter
        )

        // 使用圆形路径绘制徽章
        NSGraphicsContext.saveGraphicsState()
        NSColor.systemRed.setFill()
        let circlePath = NSBezierPath(ovalIn: badgeRect)
        circlePath.fill()
        NSGraphicsContext.restoreGraphicsState()

        badgedImage.unlockFocus()
        badgedImage.isTemplate = baseImage.isTemplate

        return badgedImage
    }
    
    /// 创建组合图标（应用图标 + 百分比圆环）
    /// - Parameters:
    ///   - percentage: 当前使用百分比
    ///   - useSevenDayColor: 是否使用7天限制的紫色系配色（默认false，使用绿/橙/红）
    /// - Returns: 组合后的图标
    private func createCombinedImage(percentage: Double, useSevenDayColor: Bool = false) -> NSImage {
        let size = NSSize(width: 40, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        if let appIcon = NSImage(named: "AppIcon"),
           let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = false
            iconCopy.size = NSSize(width: 14, height: 14)
            let symbolRect = NSRect(x: 2, y: 2, width: 14, height: 14)
            iconCopy.draw(in: symbolRect)
        }

        let circleX: CGFloat = 22
        let center = NSPoint(x: circleX + 9, y: 9)
        let radius: CGFloat = 7

        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundPath.lineWidth = 2.0
        backgroundPath.stroke()

        let color = useSevenDayColor ? colorForSevenDay(percentage) : colorForPercentage(percentage)
        color.setStroke()

        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)

        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        progressPath.lineWidth = 2.5
        progressPath.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let text = "\(Int(percentage))"
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        // 不要设置 isTemplate，否则图标会变成纯白色
        return image
    }

    /// 创建组合图标（应用图标 + 双圆环）用于双限制场景
    /// - Parameters:
    ///   - fiveHourPercentage: 5小时限制的使用百分比
    ///   - sevenDayPercentage: 7天限制的使用百分比
    /// - Returns: 包含应用图标和两个独立圆环的组合图标
    private func createCombinedDualImage(
        fiveHourPercentage: Double,
        sevenDayPercentage: Double
    ) -> NSImage {
        // 画布宽度需要容纳：图标(14px) + 间距(4px) + 双圆环(约32px)
        let size = NSSize(width: 56, height: 18)  // 增加4px以容纳更大圆环间距
        let image = NSImage(size: size)
        image.lockFocus()

        // 1. 绘制应用图标（左侧）
        if let appIcon = NSImage(named: "AppIcon"),
           let iconCopy = appIcon.copy() as? NSImage {
            iconCopy.isTemplate = false
            iconCopy.size = NSSize(width: 14, height: 14)
            let symbolRect = NSRect(x: 2, y: 2, width: 14, height: 14)
            iconCopy.draw(in: symbolRect)
        }

        // 2. 绘制双圆环（右侧）
        let circlesStartX: CGFloat = 20  // 图标后留4px间距
        let circleRadius: CGFloat = 7
        let circleSpacing: CGFloat = 5

        // 左圆环中心（5小时限制）
        let leftCenter = NSPoint(x: circlesStartX + circleRadius, y: 9)

        // 右圆环中心（7天限制）
        let rightCenter = NSPoint(
            x: circlesStartX + circleRadius * 2 + circleSpacing + circleRadius,
            y: 9
        )

        // 绘制左圆环（5小时限制）
        // 背景圆环
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(
            withCenter: leftCenter,
            radius: circleRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        leftBackgroundPath.lineWidth = 2.0
        leftBackgroundPath.stroke()

        // 进度圆环
        let fiveHourColor = colorForPercentage(fiveHourPercentage)
        fiveHourColor.setStroke()

        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)

        leftProgressPath.appendArc(
            withCenter: leftCenter,
            radius: circleRadius,
            startAngle: startAngle,
            endAngle: leftEndAngle,
            clockwise: true
        )
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.stroke()

        // 绘制右圆环（7天限制）
        // 背景圆环
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(
            withCenter: rightCenter,
            radius: circleRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        rightBackgroundPath.lineWidth = 2.0
        rightBackgroundPath.stroke()

        // 进度圆环（使用紫色系配色以区分）
        let sevenDayColor = colorForSevenDay(sevenDayPercentage)
        sevenDayColor.setStroke()

        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)

        rightProgressPath.appendArc(
            withCenter: rightCenter,
            radius: circleRadius,
            startAngle: startAngle,
            endAngle: rightEndAngle,
            clockwise: true
        )
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.stroke()

        // 3. 绘制百分比文字
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        // 左圆环百分比（5小时）
        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        let leftTextRect = NSRect(
            x: leftCenter.x - leftTextSize.width / 2,
            y: leftCenter.y - leftTextSize.height / 2,
            width: leftTextSize.width,
            height: leftTextSize.height
        )
        leftText.draw(in: leftTextRect, withAttributes: attrs)

        // 右圆环百分比（7天）
        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        let rightTextRect = NSRect(
            x: rightCenter.x - rightTextSize.width / 2,
            y: rightCenter.y - rightTextSize.height / 2,
            width: rightTextSize.width,
            height: rightTextSize.height
        )
        rightText.draw(in: rightTextRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }
    
    /// 创建圆形进度图标（带百分比数字）
    /// - Parameters:
    ///   - percentage: 当前使用百分比
    ///   - size: 图标尺寸
    ///   - useSevenDayColor: 是否使用7天限制的紫色系配色（默认false，使用绿/橙/红）
    /// - Returns: 圆形进度图标
    private func createCircleImage(percentage: Double, size: NSSize, useSevenDayColor: Bool = false) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 2

        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let backgroundPath = NSBezierPath()
        backgroundPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundPath.lineWidth = 2.0
        backgroundPath.stroke()

        let color = useSevenDayColor ? colorForSevenDay(percentage) : colorForPercentage(percentage)
        color.setStroke()
        
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (CGFloat(percentage) / 100.0 * 360)
        
        progressPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        progressPath.lineWidth = 2.5
        progressPath.stroke()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let fontSize: CGFloat = size.width * 0.35
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = "\(Int(percentage))"
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
        
        image.unlockFocus()
        return image
    }

    /// 创建同心圆环图标（5小时内圈 + 7天外圈）
    /// - Parameters:
    ///   - fiveHourPercentage: 5小时限制的使用百分比
    ///   - sevenDayPercentage: 7天限制的使用百分比
    ///   - size: 图标尺寸
    /// - Returns: 同心圆环图标
    private func createConcentricCircleImage(
        fiveHourPercentage: Double,
        sevenDayPercentage: Double,
        size: NSSize
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let outerRadius = min(size.width, size.height) / 2 - 2
        let innerRadius = outerRadius - 3  // 内圈半径小3px

        // 1. 绘制外圈背景（灰色，7天限制）
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let outerBackgroundPath = NSBezierPath()
        outerBackgroundPath.appendArc(
            withCenter: center,
            radius: outerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        outerBackgroundPath.lineWidth = 1.5
        outerBackgroundPath.stroke()

        // 2. 绘制外圈进度（7天，紫色）
        let sevenDayColor = colorForSevenDay(sevenDayPercentage)
        sevenDayColor.setStroke()

        let outerProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let outerEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)

        outerProgressPath.appendArc(
            withCenter: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: outerEndAngle,
            clockwise: true
        )
        outerProgressPath.lineWidth = 1.5
        outerProgressPath.stroke()

        // 3. 绘制内圈背景（灰色，5小时限制）
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let innerBackgroundPath = NSBezierPath()
        innerBackgroundPath.appendArc(
            withCenter: center,
            radius: innerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        innerBackgroundPath.lineWidth = 2.0
        innerBackgroundPath.stroke()

        // 4. 绘制内圈进度（5小时，绿/橙/红）
        let fiveHourColor = colorForPercentage(fiveHourPercentage)
        fiveHourColor.setStroke()

        let innerProgressPath = NSBezierPath()
        let innerEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)

        innerProgressPath.appendArc(
            withCenter: center,
            radius: innerRadius,
            startAngle: startAngle,
            endAngle: innerEndAngle,
            clockwise: true
        )
        innerProgressPath.lineWidth = 2.5
        innerProgressPath.stroke()

        // 5. 绘制中心百分比（显示5小时）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let fontSize: CGFloat = size.width * 0.35
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let text = "\(Int(fiveHourPercentage))"
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    /// 创建双圆环图标（5小时和7天限制并排显示）
    /// - Parameters:
    ///   - fiveHourPercentage: 5小时限制的使用百分比
    ///   - sevenDayPercentage: 7天限制的使用百分比
    ///   - size: 图标大小
    /// - Returns: 包含两个独立圆环的图标
    private func createDualCircleImage(
        fiveHourPercentage: Double,
        sevenDayPercentage: Double,
        size: NSSize
    ) -> NSImage {
        let circleSize = min(size.width, size.height)
        let spacing: CGFloat = 5  // 两个圆环之间的间距
        
        // 正确计算画布宽度：左圆环 + 间距 + 右圆环
        let totalWidth = circleSize + spacing + circleSize
        let image = NSImage(size: NSSize(width: totalWidth, height: size.height))
        image.lockFocus()

        let radius = circleSize / 2 - 2

        // 左侧圆环中心（5小时限制）
        let leftCenter = NSPoint(x: circleSize / 2, y: size.height / 2)

        // 右侧圆环中心（7天限制）
        let rightCenter = NSPoint(x: circleSize + spacing + circleSize / 2, y: size.height / 2)

        // 绘制左侧圆环（5小时限制）
        // 1. 背景圆环
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let leftBackgroundPath = NSBezierPath()
        leftBackgroundPath.appendArc(
            withCenter: leftCenter,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        leftBackgroundPath.lineWidth = 2.0
        leftBackgroundPath.stroke()

        // 2. 进度圆环（5小时，绿/橙/红）
        let fiveHourColor = colorForPercentage(fiveHourPercentage)
        fiveHourColor.setStroke()

        let leftProgressPath = NSBezierPath()
        let startAngle: CGFloat = 90
        let leftEndAngle = startAngle - (CGFloat(fiveHourPercentage) / 100.0 * 360)

        leftProgressPath.appendArc(
            withCenter: leftCenter,
            radius: radius,
            startAngle: startAngle,
            endAngle: leftEndAngle,
            clockwise: true
        )
        leftProgressPath.lineWidth = 2.5
        leftProgressPath.stroke()

        // 绘制右侧圆环（7天限制）
        // 3. 背景圆环
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        let rightBackgroundPath = NSBezierPath()
        rightBackgroundPath.appendArc(
            withCenter: rightCenter,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        rightBackgroundPath.lineWidth = 2.0
        rightBackgroundPath.stroke()

        // 4. 进度圆环（7天，使用紫色系配色以区分）
        let sevenDayColor = colorForSevenDay(sevenDayPercentage)
        sevenDayColor.setStroke()

        let rightProgressPath = NSBezierPath()
        let rightEndAngle = startAngle - (CGFloat(sevenDayPercentage) / 100.0 * 360)

        rightProgressPath.appendArc(
            withCenter: rightCenter,
            radius: radius,
            startAngle: startAngle,
            endAngle: rightEndAngle,
            clockwise: true
        )
        rightProgressPath.lineWidth = 2.5
        rightProgressPath.stroke()

        // 5. 绘制左侧百分比文字（5小时）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let fontSize: CGFloat = circleSize * 0.35
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let leftText = "\(Int(fiveHourPercentage))"
        let leftTextSize = leftText.size(withAttributes: attrs)
        let leftTextRect = NSRect(
            x: leftCenter.x - leftTextSize.width / 2,
            y: leftCenter.y - leftTextSize.height / 2,
            width: leftTextSize.width,
            height: leftTextSize.height
        )
        leftText.draw(in: leftTextRect, withAttributes: attrs)

        // 6. 绘制右侧百分比文字（7天）
        let rightText = "\(Int(sevenDayPercentage))"
        let rightTextSize = rightText.size(withAttributes: attrs)
        let rightTextRect = NSRect(
            x: rightCenter.x - rightTextSize.width / 2,
            y: rightCenter.y - rightTextSize.height / 2,
            width: rightTextSize.width,
            height: rightTextSize.height
        )
        rightText.draw(in: rightTextRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    /// 根据5小时限制使用百分比返回对应的颜色
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 对应的状态颜色
    /// - Note: 使用统一配色方案 (绿→橙→红)
    private func colorForPercentage(_ percentage: Double) -> NSColor {
        return UsageColorScheme.fiveHourColor(percentage)
    }

    /// 根据7天限制使用百分比返回配色
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 对应的状态颜色
    private func colorForSevenDay(_ percentage: Double) -> NSColor {
        return UsageColorScheme.sevenDayColor(percentage)
    }

    /// 创建简单圆形图标（备用）
    /// - Returns: 简单的圆形轮廓图标
    private func createSimpleCircleIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        let path = NSBezierPath(ovalIn: rect)
        
        NSColor.labelColor.setStroke()
        path.lineWidth = 2.0
        path.stroke()
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    // MARK: - Update Check Methods
    
    /// 安排每日更新检查
    private func scheduleDailyUpdateCheck() {
        #if DEBUG
        // 🧪 调试模式：检查是否启用模拟更新
        if settings.simulateUpdateAvailable {
            hasAvailableUpdate = true
            latestVersion = "2.0.0"

            // 触发图标更新
            if let percentage = usageData?.percentage {
                updateMenuBarIcon(percentage: percentage)
            }
            Logger.menuBar.debug("模拟更新已启用，显示更新通知")
        } else {
            // 即使在 Debug 模式，也进行真实的更新检查
            checkForUpdatesInBackground()

            dailyUpdateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
                self?.checkForUpdatesInBackground()
            }

            Logger.menuBar.info("Debug 模式：真实更新检查已启动")
        }
        #else
        // Release 模式：始终进行真实更新检查
        checkForUpdatesInBackground()

        // 每24小时检查一次
        dailyUpdateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
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

                let wasUpdateAvailable = self.hasAvailableUpdate
                self.hasAvailableUpdate = hasUpdate
                self.latestVersion = version

                // 如果更新状态变化，刷新菜单栏图标
                if wasUpdateAvailable != hasUpdate {
                    if let percentage = self.usageData?.percentage {
                        self.updateMenuBarIcon(percentage: percentage)
                    }
                }
            }
        }
    }
    
    /// 创建彩虹文字 NSAttributedString
    /// - Parameters:
    ///   - text: 完整文本
    ///   - highlightRange: 需要高亮的范围
    /// - Returns: 带彩虹效果的属性字符串
    private func createRainbowText(_ text: String, highlightRange: NSRange) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)

        // 基础样式 - 使用UTF-16长度
        let font = NSFont.menuFont(ofSize: 0)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.utf16.count))

        // 设置段落样式以支持制表符对齐
        let paragraphStyle = NSMutableParagraphStyle()

        // 计算基础文本的宽度，动态设置制表位位置
        let nsText = text as NSString
        let baseText = nsText.substring(to: highlightRange.location)
        let baseTextSize = (baseText as NSString).size(withAttributes: [.font: font])

        // 制表位位置 = 基础文本宽度 + 一些间距
        let tabLocation = baseTextSize.width + 20  // 基础文本宽度 + 20pt间距
        let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
        paragraphStyle.tabStops = [tabStop]

        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.utf16.count))

        // 彩虹渐变（为高亮部分的每个字符设置不同颜色）
        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]

        // 获取高亮文本
        let highlightText = nsText.substring(with: highlightRange) as String

        // 遍历高亮文本的每个字符（正确处理emoji和组合字符）
        var utf16Offset = 0
        for (index, char) in highlightText.enumerated() {
            let charString = String(char)
            let charUtf16Count = charString.utf16.count
            let colorIndex = index % colors.count

            attributedString.addAttribute(
                .foregroundColor,
                value: colors[colorIndex],
                range: NSRange(location: highlightRange.location + utf16Offset, length: charUtf16Count)
            )

            utf16Offset += charUtf16Count
        }

        return attributedString
    }
    
    /// 创建徽章图标（小红点）
    /// - Returns: 带徽章的图标
    private func createBadgeIcon() -> NSImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        
        // 绘制图标 + 红点
        if let icon = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            icon.size = NSSize(width: 12, height: 12)
            icon.draw(in: NSRect(x: 0, y: 2, width: 12, height: 12))
        }
        
        // 右上角红点
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 6, height: 6)).fill()
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    // MARK: - Cleanup
    
    /// 清理所有资源
    /// 在应用退出时调用，停止所有定时器并移除所有观察者
    func cleanup() {
        // 停止所有定时器
        timer?.invalidate()
        timer = nil
        popoverRefreshTimer?.invalidate()
        popoverRefreshTimer = nil
        resetVerifyTimer1?.invalidate()
        resetVerifyTimer1 = nil
        resetVerifyTimer2?.invalidate()
        resetVerifyTimer2 = nil
        resetVerifyTimer3?.invalidate()
        resetVerifyTimer3 = nil
        dailyUpdateTimer?.invalidate()  // 清理更新检查定时器
        dailyUpdateTimer = nil
        
        // 移除所有事件监听器
        removePopoverCloseObserver()
        
        // 清理窗口观察者
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        
        // 取消所有 Combine 订阅
        cancellables.removeAll()
        
        // 关闭 popover 和窗口
        if popover.isShown {
            popover.performClose(nil)
        }
        settingsWindow?.close()
        settingsWindow = nil
    }
    
    deinit {
        cleanup()
    }
}
