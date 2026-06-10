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
/// 登录 WebView 使用 nonPersistent 数据存储，确保多账号添加时不会因已有 session 而 auto-SSO
final class WebLoginWindowManager {
    static let shared = WebLoginWindowManager()

    private var loginWindow: NSWindow?
    private var codexLoginWindow: NSWindow?

    private init() {}

    // MARK: - Claude Login

    func showLoginWindow(onAccountCreated: ((Account) -> Void)? = nil) {
        if let window = loginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = WebLoginView(onAccountCreated: onAccountCreated)
        let window = makeWindow(title: L.WebLogin.windowTitle, content: loginView)
        self.loginWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.loginWindow = nil }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeLoginWindow() {
        loginWindow?.close()
        loginWindow = nil
    }

    // MARK: - Codex Login

    func showCodexLoginWindow(onAccountCreated: ((Account) -> Void)? = nil) {
        if let window = codexLoginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = CodexWebLoginView(onAccountCreated: onAccountCreated)
        let window = makeWindow(title: L.WebLogin.codexWindowTitle, content: loginView)
        self.codexLoginWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.codexLoginWindow = nil }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeCodexLoginWindow() {
        codexLoginWindow?.close()
        codexLoginWindow = nil
    }

    // MARK: - Private

    private func makeWindow<V: View>(title: String, content: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: content)
        window.title = title
        window.minSize = NSSize(width: 600, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        return window
    }
}
