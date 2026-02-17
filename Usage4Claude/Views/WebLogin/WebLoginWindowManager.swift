//
//  WebLoginWindowManager.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-06.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import AppKit
import SwiftUI

/// Web 登录窗口管理单例
/// 负责创建、显示和关闭登录窗口
final class WebLoginWindowManager {
    static let shared = WebLoginWindowManager()

    private var loginWindow: NSWindow?

    private init() {}

    /// 显示登录窗口
    /// - Parameter onAccountCreated: 账户创建成功后的回调
    func showLoginWindow(onAccountCreated: ((Account) -> Void)? = nil) {
        // 如果窗口已存在，直接前置
        if let window = loginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = WebLoginView(onAccountCreated: onAccountCreated)
        let hostingView = NSHostingView(rootView: loginView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = L.WebLogin.windowTitle
        window.minSize = NSSize(width: 600, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.loginWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭登录窗口
    func closeLoginWindow() {
        loginWindow?.close()
        loginWindow = nil
    }
}
