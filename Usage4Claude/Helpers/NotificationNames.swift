//
//  NotificationNames.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 通知名称扩展
/// 提供类型安全的通知名称常量，避免硬编码字符串导致的拼写错误
/// 所有应用内通知应使用这些常量而非直接使用字符串
extension Notification.Name {
    // MARK: - Settings Related

    /// 设置已更改通知
    /// 当用户修改任何设置项时发送
    static let settingsChanged = Notification.Name("settingsChanged")

    /// 菜单栏实际明暗变化（壁纸换了、图标位置移动等）
    ///
    /// 与 `AppleInterfaceThemeChangedNotification` 是两回事：菜单栏的明暗由壁纸决定，
    /// 系统 Dark/Light 没变时它照样会翻转。彩色图标的数字与背景色都依赖它，
    /// 收到后必须清图标缓存再重绘（缓存键不含外观）。
    static let menuBarAppearanceChanged = Notification.Name("menuBarAppearanceChanged")

    /// 刷新间隔已更改通知
    /// 当用户修改刷新间隔或刷新模式时发送
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")

    /// 语言已更改通知
    /// 当用户切换应用语言时发送，触发 UI 重新渲染
    static let languageChanged = Notification.Name("languageChanged")

    /// 账户已更改通知（v2.1.0）
    /// 当用户切换账户时发送，触发数据刷新
    static let accountChanged = Notification.Name("accountChanged")

    /// 进度显示口径（已用量 / 余量）已切换通知
    /// 单独于 settingsChanged 是因为菜单栏图标要为它播一段切换动画：
    /// 走 settingsChanged 会让图标立即重画成终态，动画就没得播了
    static let remainingModeToggled = Notification.Name("remainingModeToggled")

    // MARK: - Window Related

    /// 打开设置窗口通知
    /// 发送此通知以打开设置窗口
    static let openSettings = Notification.Name("openSettings")

    /// 首次启动引导已结束
    /// AppDelegate 据此关闭引导窗口并开始刷新。
    /// 不要复用 .openSettings：那个通知会被 MenuBarManager 当成「打开设置窗口」，
    /// 引导完成后会莫名其妙弹出设置窗（v2.0.0 起就有的副作用）
    static let onboardingFinished = Notification.Name("onboardingFinished")

    #if DEBUG
    /// 重新打开首次启动引导窗口（仅 DEBUG 的调试入口使用）
    static let showWelcomeWindow = Notification.Name("showWelcomeWindow")
    #endif

    /// 主界面里弹出的说明小弹窗（标题旁小叹号、Codex 重置预告）已收起
    /// MenuBarUI 据此判断用户是否点了主界面之外：是的话主界面一并关闭
    static let detailPopoverDismissed = Notification.Name("detailPopoverDismissed")

    /// 打开设置窗口并导航到指定标签页通知
    /// userInfo 包含 "tab" 键，值为标签页索引（Int）
    /// - Example: NotificationCenter.default.post(name: .openSettingsWithTab, object: nil, userInfo: ["tab": 1])
    static let openSettingsWithTab = Notification.Name("openSettingsWithTab")

    // MARK: - Error Related

    /// 开机启动设置错误通知
    /// 当设置开机启动失败时发送
    static let launchAtLoginError = Notification.Name("launchAtLoginError")
}

// MARK: - UserInfo Keys

/// 通知 userInfo 字典的键名常量
/// 提供类型安全的 userInfo 键访问
extension Notification {
    /// UserInfo 键名枚举
    enum UserInfoKey {
        /// 标签页索引键
        /// 用于 openSettingsWithTab 通知，值类型为 Int
        static let tab = "tab"

        /// 账户变更的 Provider 键
        /// 用于 accountChanged 通知，值类型为 ProviderType.rawValue
        static let provider = "provider"
    }
}
