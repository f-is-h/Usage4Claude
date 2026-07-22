//
//  MenuBarUI.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import AppKit
import Combine

/// 菜单栏 UI 管理器
/// 负责管理菜单栏图标、弹出窗口、菜单创建以及图标绘制
/// 包含完整的 UI 层逻辑，实现从 MenuBarManager 中抽取的所有 UI 相关职责
class MenuBarUI {

    // MARK: - UI Components

    /// 系统菜单栏状态项
    private(set) var statusItem: NSStatusItem!
    /// 详情弹出窗口
    private(set) var popover: NSPopover!
    /// 弹出窗口关闭监听器 - 监听鼠标点击事件
    private var popoverCloseObserver: Any?
    /// 应用失焦观察者 - 用于在应用失去焦点时关闭 popover
    private var appResignActiveObserver: NSObjectProtocol?

    // MARK: - Icon Cache

    /// 图标缓存：键为 "mode_style_percentage_appearance"，值为缓存的图标
    private var iconCache: [String: NSImage] = [:]
    /// 缓存的最大条目数
    private let maxCacheSize = 50

    // MARK: - Settings Reference

    /// 用户设置实例（从外部传入）
    private let settings = UserSettings.shared

    // MARK: - Icon Renderer

    /// 图标渲染器 - 负责所有图标绘制逻辑
    private let iconRenderer = MenuBarIconRenderer()

    // MARK: - Initialization

    init() {
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Status Item Setup

    /// 初始化菜单栏状态项
    /// 设置点击事件处理
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        statusItem.isVisible = true

        if let button = statusItem.button {
            // 初始图标
            button.image = createSimpleCircleIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "Usage4Claude"
            button.appearsDisabled = false
        }
    }

    /// 配置状态项点击处理
    /// - Parameters:
    ///   - target: 目标对象
    ///   - action: 点击响应方法
    func configureClickHandler(target: AnyObject?, action: Selector) {
        guard let button = statusItem.button else { return }
        button.action = action
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = target
    }

    // MARK: - Popover Setup

    /// 初始化弹出窗口
    /// 设置窗口尺寸和外观
    private func setupPopover() {
        popover = NSPopover()
        // 固定尺寸以避免布局跳动
        popover.contentSize = NSSize(width: 280, height: 240)
        // 设置行为，允许自定义外观
        popover.behavior = .semitransient
    }

    /// 设置 Popover 内容视图
    /// - Parameter contentView: SwiftUI 视图
    func setPopoverContent<Content: View>(_ contentView: Content) {
        let hostingController = NSHostingController(rootView: contentView)
        popover.contentViewController = hostingController
    }

    /// 设置 popover 内容尺寸，确保 AppKit 在定位箭头前拿到真实宽高
    func setPopoverContentSize(_ size: NSSize) {
        popover.contentSize = size
    }

    // MARK: - Popover Control

    /// 打开弹出窗口
    /// - Parameter button: 菜单栏按钮
    func openPopover(relativeTo button: NSStatusBarButton) {
        // Popover 挂在系统状态栏上，继承状态栏外观而非 NSApp.appearance
        // 需要在每次打开时显式设置，确保与用户偏好同步
        switch settings.appearance {
        case .system:
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            popover.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        case .light:
            popover.appearance = NSAppearance(named: .aqua)
        case .dark:
            popover.appearance = NSAppearance(named: .darkAqua)
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 配置 popover 窗口属性
        configurePopoverWindow()

        // 设置监听器
        setupPopoverCloseObserver()
        setupAppResignActiveObserver()
    }

    /// 配置 popover 窗口属性
    private func configurePopoverWindow() {
        guard let popoverWindow = popover.contentViewController?.view.window else { return }

        // 设置窗口level，确保显示在其他窗口之上
        popoverWindow.level = .popUpMenu
        popoverWindow.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        // 让窗口成为 key window，显示 Focus 状态
        popoverWindow.makeKey()

        #if DEBUG
        // 根据调试开关设置背景颜色
        if settings.debugKeepDetailWindowOpen {
            // 开启时：纯白色不透明背景
            popoverWindow.backgroundColor = NSColor.white
            popoverWindow.isOpaque = true
            // 设置内容视图的背景
            if let contentView = popover.contentViewController?.view {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.white.cgColor
            }
        } else {
            // 关闭时：使用默认透明背景
            popoverWindow.backgroundColor = NSColor.clear
            popoverWindow.isOpaque = false
            // 恢复内容视图的透明背景
            if let contentView = popover.contentViewController?.view {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        #endif
    }

    /// 关闭弹出窗口
    func closePopover() {
        // 确保 popover 关闭
        if popover.isShown {
            popover.performClose(nil)
        }
        // 移除事件监听器
        removePopoverCloseObserver()
        removeAppResignActiveObserver()
    }

    /// 设置弹出窗口外部点击监听
    /// 点击 popover 外部时自动关闭
    private func setupPopoverCloseObserver() {
        // 先移除旧的观察者，防止累积
        removePopoverCloseObserver()

        // 使用全局事件监听器监听鼠标点击事件
        popoverCloseObserver = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }

            #if DEBUG
            // Debug模式：如果开启了"保持详情窗口打开"，则不自动关闭
            if UserSettings.shared.debugKeepDetailWindowOpen {
                return
            }
            #endif

            self.closePopover()
        }
    }

    /// 移除弹出窗口监听器
    private func removePopoverCloseObserver() {
        if let observer = popoverCloseObserver {
            NSEvent.removeMonitor(observer)
            popoverCloseObserver = nil
        }
    }

    /// 设置应用失焦监听
    /// 当应用失去焦点时自动关闭 popover
    private func setupAppResignActiveObserver() {
        // 先移除旧的观察者，防止累积
        removeAppResignActiveObserver()

        // 监听应用失去焦点事件
        appResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }

            #if DEBUG
            // Debug模式：如果开启了"保持详情窗口打开"，则不自动关闭
            if UserSettings.shared.debugKeepDetailWindowOpen {
                return
            }
            #endif

            self.closePopover()
        }
    }

    /// 移除应用失焦监听器
    private func removeAppResignActiveObserver() {
        if let observer = appResignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            appResignActiveObserver = nil
        }
    }

    // MARK: - Menu Management

    /// 创建标准菜单
    /// 用于右键菜单和弹出窗口中的三点菜单
    /// - Parameters:
    ///   - target: 菜单项目标对象
    /// - Returns: 配置好的 NSMenu 实例
    func createStandardMenu(
        warmupAllCount: Int,
        warmupIdleCount: Int,
        isWarmingUp: Bool,
        target: AnyObject?
    ) -> NSMenu {
        let menu = NSMenu()

        // 账户选择子菜单（多账户时显示）
        var hasAccountMenuItems = false

        if settings.accounts.count > 1 {
            let accountSubmenu = createAccountSubmenu(target: target)
            let currentAccountName = settings.currentAccountName ?? L.Menu.account
            let accountItem = NSMenuItem(
                title: "\(L.Menu.accountPrefix) \(currentAccountName)",
                action: nil,
                keyEquivalent: ""
            )
            accountItem.submenu = accountSubmenu
            setMenuItemIcon(accountItem, systemName: "person.2")
            menu.addItem(accountItem)
            hasAccountMenuItems = true
        }

        if settings.codexAccounts.count > 1 {
            let codexSubmenu = createCodexAccountSubmenu(target: target)
            let currentCodexName = settings.currentCodexAccount?.displayName ?? "Codex"
            let codexItem = NSMenuItem(
                title: "Codex: \(currentCodexName)",
                action: nil,
                keyEquivalent: ""
            )
            codexItem.submenu = codexSubmenu
            setMenuItemIcon(codexItem, systemName: "person.2.fill")
            menu.addItem(codexItem)
            hasAccountMenuItems = true
        }

        if hasAccountMenuItems {
            menu.addItem(NSMenuItem.separator())
        }

        if settings.menuBarAccountProfiles.count > 1 {
            let profileItem = NSMenuItem(
                title: "Menu Bar Profile",
                action: nil,
                keyEquivalent: ""
            )
            profileItem.submenu = createMenuBarProfileSubmenu(target: target)
            setMenuItemIcon(profileItem, systemName: "rectangle.3.group")
            menu.addItem(profileItem)
            menu.addItem(NSMenuItem.separator())
        }

        if warmupAllCount > 0 {
            let warmupIdleItem = NSMenuItem(
                title: "\(L.Menu.warmUpIdle) (\(warmupIdleCount))",
                action: #selector(MenuBarManager.warmUpIdleAccounts),
                keyEquivalent: ""
            )
            warmupIdleItem.target = target
            warmupIdleItem.isEnabled = !isWarmingUp && warmupIdleCount > 0
            setMenuItemIcon(warmupIdleItem, systemName: "flame")
            menu.addItem(warmupIdleItem)

            let warmupAllItem = NSMenuItem(
                title: "\(L.Menu.warmUpAll) (\(warmupAllCount))",
                action: #selector(MenuBarManager.warmUpAllAccounts),
                keyEquivalent: ""
            )
            warmupAllItem.target = target
            warmupAllItem.isEnabled = !isWarmingUp
            setMenuItemIcon(warmupAllItem, systemName: "flame.fill")
            menu.addItem(warmupAllItem)
            menu.addItem(NSMenuItem.separator())
        }

        // 通用设置
        let generalItem = NSMenuItem(
            title: L.Menu.generalSettings,
            action: #selector(MenuBarManager.openGeneralSettings),
            keyEquivalent: ","
        )
        generalItem.target = target
        setMenuItemIcon(generalItem, systemName: "gearshape")
        menu.addItem(generalItem)

        // 认证信息
        let authItem = NSMenuItem(
            title: L.Menu.authSettings,
            action: #selector(MenuBarManager.openAuthSettings),
            keyEquivalent: "a"
        )
        authItem.target = target
        authItem.keyEquivalentModifierMask = [.command, .shift] as NSEvent.ModifierFlags
        setMenuItemIcon(authItem, systemName: "key.horizontal")
        menu.addItem(authItem)

        // 关于
        let aboutItem = NSMenuItem(
            title: L.Menu.about,
            action: #selector(MenuBarManager.openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = target
        setMenuItemIcon(aboutItem, systemName: "info.circle")
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        if !settings.accounts.isEmpty {
            let claudeStatusItem = NSMenuItem(
                title: L.Menu.claudeStatus,
                action: #selector(MenuBarManager.openClaudeStatus),
                keyEquivalent: ""
            )
            claudeStatusItem.target = target
            setMenuItemIcon(claudeStatusItem, systemName: "safari")
            menu.addItem(claudeStatusItem)
        }

        if !settings.codexAccounts.isEmpty {
            let codexStatusItem = NSMenuItem(
                title: L.Menu.codexStatus,
                action: #selector(MenuBarManager.openCodexStatus),
                keyEquivalent: ""
            )
            codexStatusItem.target = target
            setMenuItemIcon(codexStatusItem, systemName: "safari.fill")
            menu.addItem(codexStatusItem)
        }

        // Buy Me A Coffee
        let coffeeItem = NSMenuItem(
            title: L.Menu.coffee,
            action: #selector(MenuBarManager.openCoffee),
            keyEquivalent: ""
        )
        coffeeItem.target = target
        setMenuItemIcon(coffeeItem, systemName: "cup.and.saucer")
        menu.addItem(coffeeItem)

        // GitHub Sponsor
        let sponsorItem = NSMenuItem(
            title: L.Menu.githubSponsor,
            action: #selector(MenuBarManager.openGithubSponsor),
            keyEquivalent: ""
        )
        sponsorItem.target = target
        setMenuItemIcon(sponsorItem, systemName: "heart")
        menu.addItem(sponsorItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: L.Menu.quit,
            action: #selector(MenuBarManager.quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = target
        setMenuItemIcon(quitItem, systemName: "power")
        menu.addItem(quitItem)

        return menu
    }

    /// 为菜单项设置图标
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

    /// 创建账户选择子菜单
    /// - Parameter target: 菜单项目标对象
    /// - Returns: 账户选择子菜单
    private func createAccountSubmenu(target: AnyObject?) -> NSMenu {
        let submenu = NSMenu()

        for account in settings.accounts {
            let item = NSMenuItem(
                title: account.displayName,
                action: #selector(MenuBarManager.switchAccount(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = account

            // 当前选中的账户显示勾选标记
            if account.id == settings.currentAccountId {
                item.state = .on
            }

            submenu.addItem(item)
        }

        return submenu
    }

    /// 创建 Codex 账户选择子菜单
    private func createCodexAccountSubmenu(target: AnyObject?) -> NSMenu {
        let submenu = NSMenu()

        for account in settings.codexAccounts {
            let item = NSMenuItem(
                title: account.displayName,
                action: #selector(MenuBarManager.switchCodexAccount(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = account

            if account.id == settings.currentCodexAccountId {
                item.state = .on
            }

            submenu.addItem(item)
        }

        return submenu
    }

    private func createMenuBarProfileSubmenu(target: AnyObject?) -> NSMenu {
        let submenu = NSMenu()

        for profile in settings.menuBarAccountProfiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(MenuBarManager.switchMenuBarProfile(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = profile.id
            if profile.id == settings.activeMenuBarAccountProfileId {
                item.state = .on
            }
            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())

        let cycleItem = NSMenuItem(
            title: "Next Profile",
            action: #selector(MenuBarManager.cycleMenuBarProfile),
            keyEquivalent: "m"
        )
        cycleItem.target = target
        cycleItem.keyEquivalentModifierMask = [.command, .option, .control]
        submenu.addItem(cycleItem)

        return submenu
    }

    // MARK: - Icon Management

    /// 更新菜单栏图标
    /// - Parameters:
    ///   - usageData: Claude 用量数据
    ///   - codexUsageData: Codex 用量数据
    func updateMenuBarIcon(usageData: UsageData?, codexUsageData: CodexUsageData? = nil, multiAccountUsage: [UUID: UsageData] = [:], multiAccountCodexUsage: [UUID: CodexUsageData] = [:]) {
        guard let button = statusItem.button else { return }

        // 生成缓存键
        var cacheKey = generateCacheKey(usageData: usageData, codexUsageData: codexUsageData)
        cacheKey += multiAccountCacheKeySuffix(multiAccountUsage: multiAccountUsage, multiAccountCodexUsage: multiAccountCodexUsage)

        // 尝试从缓存获取
        if let cachedImage = iconCache[cacheKey] {
            button.image = cachedImage
            button.imagePosition = .imageOnly
            statusItem.length = max(24, cachedImage.size.width + 6)
            return
        }

        // 缓存未命中，使用 IconRenderer 创建新图标
        let icon = iconRenderer.createIcon(
            usageData: usageData,
            codexUsageData: codexUsageData,
            multiAccountUsage: multiAccountUsage,
            multiAccountCodexUsage: multiAccountCodexUsage,
            button: button
        )

        // 存入缓存
        if iconCache.count >= maxCacheSize {
            iconCache.removeValue(forKey: iconCache.keys.first!)
        }
        iconCache[cacheKey] = icon

        button.image = icon
        button.imagePosition = .imageOnly
        statusItem.isVisible = true
        statusItem.length = max(24, icon.size.width + 6)
    }

    /// 清除图标缓存
    func clearIconCache() {
        iconCache.removeAll()
    }

    /// 多账户菜单栏模式的缓存键后缀（按选中顺序编码每个账户的 5小时/7天百分比）
    private func multiAccountCacheKeySuffix(multiAccountUsage: [UUID: UsageData], multiAccountCodexUsage: [UUID: CodexUsageData] = [:]) -> String {
        guard settings.isMultiAccountMenuBarActive else { return "" }
        var suffix = "_ma\(settings.multiAccountShowWeekly ? "w" : "f")\(settings.menuBarShowCodex ? "c" : "n")"
        for account in settings.menuBarAccounts {
            let data = multiAccountUsage[account.id]
            let fiveHour = data?.fiveHour?.percentage ?? 0
            let sevenDay = data?.sevenDay?.percentage ?? 0
            suffix += "_\(account.id.uuidString.prefix(8)):\(Int(fiveHour))/\(Int(sevenDay))"
        }
        for account in settings.menuBarCodexAccounts {
            let data = multiAccountCodexUsage[account.id]
            let primary = data?.primary?.percentage ?? 0
            let secondary = data?.secondary?.percentage ?? 0
            suffix += "_cx\(account.id.uuidString.prefix(8)):\(Int(primary))/\(Int(secondary))"
        }
        return suffix
    }

    /// 生成图标缓存键
    /// - Parameters:
    ///   - usageData: Claude 用量数据
    ///   - codexUsageData: Codex 用量数据
    /// - Returns: 缓存键字符串
    private func generateCacheKey(usageData: UsageData?, codexUsageData: CodexUsageData? = nil) -> String {
        let isMulti = settings.isMultiProviderActive
        guard let data = usageData else {
            var key = "no_data_\(settings.iconDisplayMode.rawValue)_\(settings.iconStyleMode.rawValue)_\(settings.displayMode.rawValue)_mp\(isMulti)"
            if let codex = codexUsageData {
                let activeTypes = settings.getActiveDisplayTypes(usageData: nil, codexUsageData: codex, forMenuBar: true)
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: ",")
                key += "_types\(activeTypes)"

                if let primary = codex.primary {
                    key += "_cxp\(Int(primary.percentage))"
                } else {
                    key += "_cxpnil"
                }

                if let secondary = codex.secondary {
                    key += "_cxs\(Int(secondary.percentage))"
                } else {
                    key += "_cxsnil"
                }

                if let extraUsage = codex.extraUsage {
                    key += "_cxe\(extraUsage.enabled ? 1 : 0)"
                    if let percentage = extraUsage.percentage {
                        key += "_\(Int(percentage))"
                    }
                } else {
                    key += "_cxenil"
                }
            }

            return key
        }

        var key = "\(settings.iconDisplayMode.rawValue)_\(settings.iconStyleMode.rawValue)_mp\(isMulti)"

        if let fiveHour = data.fiveHour {
            key += "_5h\(Int(fiveHour.percentage))"
        }
        if let sevenDay = data.sevenDay {
            key += "_7d\(Int(sevenDay.percentage))"
        }
        if let opus = data.opus {
            key += "_opus\(Int(opus.percentage))"
        }
        if let sonnet = data.sonnet {
            key += "_sonnet\(Int(sonnet.percentage))"
        }
        if let extraUsage = data.extraUsage, extraUsage.enabled, let percentage = extraUsage.percentage {
            key += "_extra\(Int(percentage))"
        }

        if let codex = codexUsageData {
            if let p = codex.primary { key += "_cxp\(Int(p.percentage))" }
            if let s = codex.secondary { key += "_cxs\(Int(s.percentage))" }
            if let e = codex.extraUsage?.percentage { key += "_cxe\(Int(e))" }
        }

        return key
    }

    // MARK: - Utility Icons

    /// 创建简单圆形图标（备用）
    /// 用于初始化状态栏按钮
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
    func cleanup() {
        removePopoverCloseObserver()
        removeAppResignActiveObserver()

        if popover.isShown {
            popover.performClose(nil)
        }
    }

    deinit {
        cleanup()
    }
}
