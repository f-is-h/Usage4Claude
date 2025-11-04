//
//  ClaudeUsageMonitorApp.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// Usage4Claude 应用主入口
@main
struct ClaudeUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// 应用代理类
/// 负责应用生命周期管理、资源初始化和清理
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    /// 菜单栏管理器，负责所有菜单栏相关功能
    private var menuBarManager: MenuBarManager!
    
    /// 欢迎窗口，在首次启动时显示
    private var welcomeWindow: NSWindow?
    
    /// 用户设置实例
    private let settings = UserSettings.shared
    
    /// 通知观察者数组，用于在应用退出时清理
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Application Lifecycle
    
    /// 应用启动完成时调用
    /// 初始化菜单栏管理器，根据是否首次启动显示欢迎窗口或开始刷新数据
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化 MenuBar 管理器
        menuBarManager = MenuBarManager()
        
        // 检查是否首次启动且没有配置认证信息
        if settings.isFirstLaunch || !settings.hasValidCredentials {
            showWelcomeWindow()
        } else {
            // 启动定时刷新
            menuBarManager.startRefreshing()
        }
        
        // 监听打开设置的通知，并保存观察者引用
        let observer = NotificationCenter.default.addObserver(
            forName: .openSettings,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.openSettingsFromNotification(notification)
        }
        notificationObservers.append(observer)
    }
    
    // MARK: - Private Methods
    
    /// 显示欢迎窗口
    /// 在首次启动或未配置认证信息时调用
    private func showWelcomeWindow() {
        // 切换为 regular 模式，使应用显示在 Dock 中
        NSApp.setActivationPolicy(.regular)
        
        let welcomeView = WelcomeView()
        let hostingController = NSHostingController(rootView: welcomeView)
        
        welcomeWindow = NSWindow(
            contentViewController: hostingController
        )
        welcomeWindow?.title = L.Window.welcomeTitle
        welcomeWindow?.styleMask = [.titled, .closable]
        welcomeWindow?.level = .floating
        
        // 确保窗口在屏幕中心
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = welcomeWindow?.frame ?? NSRect.zero
            let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
            welcomeWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 监听窗口关闭事件
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: welcomeWindow,
            queue: .main
        ) { _ in
            // 窗口关闭时切换回 accessory 模式（不显示在 Dock）
            NSApp.setActivationPolicy(.accessory)
        }
        notificationObservers.append(observer)
        
        welcomeWindow?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 处理打开设置的通知
    /// 关闭欢迎窗口并根据认证配置状态启动刷新
    private func openSettingsFromNotification(_ notification: Notification) {
        // 关闭欢迎窗口（会自动触发切换回 accessory 模式）
        welcomeWindow?.close()
        welcomeWindow = nil
        
        // 如果认证信息已配置，启动刷新
        if settings.hasValidCredentials {
            menuBarManager.startRefreshing()
        }
    }
    
    /// 应用即将退出时调用
    /// 清理所有观察者、定时器和窗口资源
    func applicationWillTerminate(_ notification: Notification) {
        // 清理所有通知观察者
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // 清理 MenuBarManager 的资源
        menuBarManager?.cleanup()
        
        // 关闭所有窗口
        welcomeWindow?.close()
        welcomeWindow = nil
    }
    
    deinit {
        // 确保清理所有观察者
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
