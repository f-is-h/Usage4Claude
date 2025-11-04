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
    
    // MARK: - Initialization
    
    init() {
        setupStatusItem()
        setupPopover()
        setupSettingsObservers()
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
        let event = NSApp.currentEvent!
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
    
    /// 创建标准菜单
    /// 用于右键菜单和弹出窗口中的三点菜单，确保菜单内容一致
    /// - Returns: 配置好的 NSMenu 实例
    private func createStandardMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 通用设置
        let generalItem = NSMenuItem(
            title: L.Menu.generalSettings,
            action: #selector(openGeneralSettings),
            keyEquivalent: ""
        )
        generalItem.target = self
        menu.addItem(generalItem)
        
        // 认证信息
        let authItem = NSMenuItem(
            title: L.Menu.authSettings,
            action: #selector(openAuthSettings),
            keyEquivalent: ""
        )
        authItem.target = self
        menu.addItem(authItem)
        
        // 检查更新
        let updateItem = NSMenuItem(
            title: L.Menu.checkUpdates,
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        
        // 关于
        let aboutItem = NSMenuItem(
            title: L.Menu.about,
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 访问 Claude 用量
        let webItem = NSMenuItem(
            title: L.Menu.webUsage,
            action: #selector(openWebUsage),
            keyEquivalent: ""
        )
        webItem.target = self
        menu.addItem(webItem)
        
        // Buy Me A Coffee
        let coffeeItem = NSMenuItem(
            title: L.Menu.coffee,
            action: #selector(openCoffee),
            keyEquivalent: ""
        )
        coffeeItem.target = self
        menu.addItem(coffeeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(
            title: L.Menu.quit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
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
        // 关闭 popover
        if popover.isShown {
            closePopover()
        }
        
        switch action {
        case .generalSettings:
            openSettingsWindow(tab: 0)
        case .authSettings:
            openSettingsWindow(tab: 1)
        case .checkForUpdates:
            checkForUpdates()
        case .about:
            openSettingsWindow(tab: 2)
        case .webUsage:
            openWebUsage()
        case .coffee:
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
                self?.updateMenuBarIcon(percentage: self?.usageData?.percentage ?? 0)
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
                onMenuAction: { [weak self] action in
                    self?.handleMenuAction(action)
                }
            )
        )
        popover.contentViewController = hostingController
        
        // 设置窗口appearance为统一样式，避免Focus导致的颜色变化
        if #available(macOS 10.14, *) {
            hostingController.view.appearance = NSAppearance(named: .aqua)
        }
    }
    
    /// 切换弹出窗口显示状态
    /// 打开时会重新创建内容视图并启动实时刷新定时器
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                closePopover()
            } else {
                // 每次打开时重新创建 contentViewController，确保显示最新数据
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
                        onMenuAction: { [weak self] action in
                            self?.handleMenuAction(action)
                        }
                    )
                )
                
                // 设置窗口appearance为统一样式
                if #available(macOS 10.14, *) {
                    hostingController.view.appearance = NSAppearance(named: .aqua)
                }
                
                popover.contentViewController = hostingController
                
                // 显示popover - 不要调用激活应用，让它保持非激活状态
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // 重要：不调用 becomeKey()，保持窗口在非Focus状态，避免颜色闪烁
                // 这样窗口会保持一致的外观，不会有Focus/非Focus的明显差异
                
                // 配置窗口属性
                if let popoverWindow = popover.contentViewController?.view.window {
                    // 设置窗口level，确保显示在其他窗口之上
                    popoverWindow.level = .popUpMenu
                    
                    // 禁止窗口成为key window，避免Focus外观变化
                    popoverWindow.styleMask.remove(.titled)
                }
                
                // 开始刷新定时器
                startPopoverRefreshTimer()
                
                // 监听应用失去焦点事件，自动关闭popover
                setupPopoverCloseObserver()
            }
        }
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
        // 不要每次都重新创建controller，而是更新现有的rootView
        if let hostingController = popover.contentViewController as? NSHostingController<UsageDetailView> {
            hostingController.rootView = UsageDetailView(
                usageData: Binding(
                    get: { self.usageData },
                    set: { self.usageData = $0 }
                ),
                errorMessage: Binding(
                    get: { self.errorMessage },
                    set: { self.errorMessage = $0 }
                ),
                onMenuAction: { [weak self] action in
                    self?.handleMenuAction(action)
                }
            )
        }
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
        
        #if DEBUG
        let minutes = interval / 60
        print("⏱️ 定时器已重启，刷新间隔: \(minutes) 分钟")
        #endif
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
        
        apiService.fetchUsage { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let data):
                    self?.usageData = data
                    self?.updateStatusBarIcon(percentage: data.percentage)
                    self?.errorMessage = nil
                    
                    // 智能模式：根据百分比变化调整刷新频率
                    self?.settings.updateSmartMonitoringMode(currentUtilization: data.percentage)
                    
                    // 检测重置时间是否发生变化
                    if let self = self {
                        let newResetsAt = data.resetsAt
                        let hasResetChanged = self.hasResetTimeChanged(from: self.lastResetsAt, to: newResetsAt)
                        
                        if hasResetChanged {
                            // 重置时间发生变化，取消所有待执行的验证
                            #if DEBUG
                            print("✅ 检测到重置时间变化，取消剩余验证")
                            #endif
                            self.cancelResetVerification()
                        } else {
                            // 重置时间未变化，安排验证
                            if let resetsAt = newResetsAt {
                                self.scheduleResetVerification(resetsAt: resetsAt)
                            }
                        }
                        
                        // 更新上次的重置时间
                        self.lastResetsAt = newResetsAt
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("Error fetching usage: \(error)")
                }
            }
        }
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
            #if DEBUG
            print("⏰ 重置时间已过，跳过验证安排")
            #endif
            return
        }
        
        #if DEBUG
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        print("⏰ 安排重置验证 - 重置时间: \(formatter.string(from: resetsAt))")
        #endif
        
        // 重置后1秒验证
        resetVerifyTimer1 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 1,
            repeats: false
        ) { [weak self] _ in
            #if DEBUG
            print("✅ 重置验证 +1秒 - 开始刷新")
            #endif
            self?.fetchUsage()
            self?.resetVerifyTimer1 = nil
        }
        
        // 重置后10秒验证
        resetVerifyTimer2 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 10,
            repeats: false
        ) { [weak self] _ in
            #if DEBUG
            print("✅ 重置验证 +10秒 - 开始刷新")
            #endif
            self?.fetchUsage()
            self?.resetVerifyTimer2 = nil
        }
        
        // 重置后30秒验证
        resetVerifyTimer3 = Timer.scheduledTimer(
            withTimeInterval: timeUntilReset + 30,
            repeats: false
        ) { [weak self] _ in
            #if DEBUG
            print("✅ 重置验证 +30秒 - 开始刷新")
            #endif
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
        
        switch settings.iconDisplayMode {
        case .percentageOnly:
            button.image = createCircleImage(percentage: percentage, size: NSSize(width: 18, height: 18))
        case .iconOnly:
            if let appIcon = NSImage(named: "AppIcon") {
                let iconCopy = appIcon.copy() as! NSImage
                iconCopy.size = NSSize(width: 18, height: 18)
                iconCopy.isTemplate = false
                button.image = iconCopy
            } else {
                button.image = createSimpleCircleIcon()
            }
        case .both:
            button.image = createCombinedImage(percentage: percentage)
        }
    }
    
    /// 创建组合图标（应用图标 + 百分比圆环）
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 组合后的图标
    private func createCombinedImage(percentage: Double) -> NSImage {
        let size = NSSize(width: 40, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        
        if let appIcon = NSImage(named: "AppIcon") {
            let iconCopy = appIcon.copy() as! NSImage
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
        
        let color = colorForPercentage(percentage)
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
    
    /// 创建圆形进度图标（带百分比数字）
    /// - Parameters:
    ///   - percentage: 当前使用百分比
    ///   - size: 图标尺寸
    /// - Returns: 圆形进度图标
    private func createCircleImage(percentage: Double, size: NSSize) -> NSImage {
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
        
        let color = colorForPercentage(percentage)
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
    
    /// 根据使用百分比返回对应的颜色
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 对应的状态颜色
    /// - Note: 0-70% 绿色, 70-90% 橙色, 90-100% 红色
    private func colorForPercentage(_ percentage: Double) -> NSColor {
        if percentage < 70 {
            return NSColor.systemGreen
        } else if percentage < 90 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemRed
        }
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
