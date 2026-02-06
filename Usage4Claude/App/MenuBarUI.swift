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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // 初始图标
            button.image = createSimpleCircleIcon()
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

    // MARK: - Popover Control

    /// 打开弹出窗口
    /// - Parameter button: 菜单栏按钮
    func openPopover(relativeTo button: NSStatusBarButton) {
        // 激活应用，使 popover 能够正确响应焦点变化
        NSApp.activate(ignoringOtherApps: true)

        // 显示 popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 配置 popover 窗口
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
    ///   - hasUpdate: 是否有可用更新
    ///   - shouldShowBadge: 是否显示更新徽章
    ///   - target: 菜单项目标对象
    /// - Returns: 配置好的 NSMenu 实例
    func createStandardMenu(hasUpdate: Bool, shouldShowBadge: Bool, target: AnyObject?) -> NSMenu {
        let menu = NSMenu()

        // 账户选择子菜单（仅当有多个账户时显示）
        if settings.accounts.count > 1 {
            let accountSubmenu = createAccountSubmenu(target: target)
            let currentAccountName = settings.currentAccountName ?? L.Menu.account
            let menuTitle = "\(L.Menu.accountPrefix) \(currentAccountName)"

            let accountItem = NSMenuItem(
                title: menuTitle,
                action: nil,
                keyEquivalent: ""
            )
            accountItem.submenu = accountSubmenu
            setMenuItemIcon(accountItem, systemName: "person.2")
            menu.addItem(accountItem)
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

        // 检查更新
        let updateItem = NSMenuItem(
            title: "",
            action: #selector(MenuBarManager.checkForUpdates),
            keyEquivalent: "u"
        )
        updateItem.target = target

        // 根据是否有更新设置不同的样式
        if hasUpdate {
            // 有更新：显示彩虹文字
            let baseText = L.Menu.checkUpdates
            let highlightText = L.Update.Notification.badgeMenu
            let title = "\(baseText)\t\(highlightText)"

            let highlightLocation = baseText.utf16.count + 1
            let highlightLength = highlightText.utf16.count
            let highlightRange = NSRange(location: highlightLocation, length: highlightLength)

            let attributedTitle = createRainbowText(title, highlightRange: highlightRange)
            updateItem.attributedTitle = attributedTitle

            // 徽章图标：仅在用户未确认时显示
            if shouldShowBadge {
                if let badgeImage = createBadgeIcon() {
                    updateItem.image = badgeImage
                }
            } else {
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
            action: #selector(MenuBarManager.openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = target
        setMenuItemIcon(aboutItem, systemName: "info.circle")
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // 访问 Claude 用量
        let webItem = NSMenuItem(
            title: L.Menu.webUsage,
            action: #selector(MenuBarManager.openWebUsage),
            keyEquivalent: "w"
        )
        webItem.target = target
        webItem.keyEquivalentModifierMask = [.command, .shift] as NSEvent.ModifierFlags
        setMenuItemIcon(webItem, systemName: "safari")
        menu.addItem(webItem)

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

    /// 创建彩虹文字 NSAttributedString
    /// - Parameters:
    ///   - text: 完整文本
    ///   - highlightRange: 需要高亮的范围
    /// - Returns: 带彩虹效果的属性字符串
    private func createRainbowText(_ text: String, highlightRange: NSRange) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)

        let font = NSFont.menuFont(ofSize: 0)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.utf16.count))

        let paragraphStyle = NSMutableParagraphStyle()
        let nsText = text as NSString
        let baseText = nsText.substring(to: highlightRange.location)
        let baseTextSize = (baseText as NSString).size(withAttributes: [.font: font])

        let tabLocation = baseTextSize.width + 20
        let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
        paragraphStyle.tabStops = [tabStop]

        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.utf16.count))

        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
        let highlightText = nsText.substring(with: highlightRange) as String

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

        if let icon = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil) {
            icon.size = NSSize(width: 12, height: 12)
            icon.draw(in: NSRect(x: 0, y: 2, width: 12, height: 12))
        }

        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 6, height: 6)).fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Icon Management

    /// 更新菜单栏图标
    /// - Parameters:
    ///   - usageData: 用量数据
    ///   - hasUpdate: 是否有可用更新
    ///   - shouldShowBadge: 是否显示更新徽章
    func updateMenuBarIcon(usageData: UsageData?, hasUpdate: Bool, shouldShowBadge: Bool) {
        guard let button = statusItem.button else { return }

        // 确定是否实际显示徽章
        let showBadge = hasUpdate && shouldShowBadge

        // 生成缓存键
        let cacheKey = generateCacheKey(usageData: usageData, hasUpdate: showBadge)

        // 尝试从缓存获取
        if let cachedImage = iconCache[cacheKey] {
            button.image = cachedImage
            return
        }

        // 缓存未命中，使用 IconRenderer 创建新图标
        let icon = iconRenderer.createIcon(
            usageData: usageData,
            hasUpdate: showBadge,
            button: button
        )

        // 存入缓存
        if iconCache.count >= maxCacheSize {
            iconCache.removeValue(forKey: iconCache.keys.first!)
        }
        iconCache[cacheKey] = icon

        button.image = icon
    }

    /// 清除图标缓存
    func clearIconCache() {
        iconCache.removeAll()
    }

    /// 生成图标缓存键
    /// - Parameters:
    ///   - usageData: 用量数据
    ///   - hasUpdate: 是否有更新徽章
    /// - Returns: 缓存键字符串
    private func generateCacheKey(usageData: UsageData?, hasUpdate: Bool) -> String {
        guard let data = usageData else {
            return "no_data_\(settings.iconStyleMode.rawValue)_\(hasUpdate)"
        }

        var key = "\(settings.iconDisplayMode.rawValue)_\(settings.iconStyleMode.rawValue)"

        // 包含所有限制类型的百分比，确保形状图标也能正确缓存
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

        if hasUpdate {
            key += "_badge"
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
