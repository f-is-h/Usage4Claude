//
//  WebLoginCoordinator.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-06.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Combine
import Foundation
import WebKit
import os

/// WKWebView 管理和 Cookie 检测核心逻辑
/// 负责加载 claude.ai 登录页面、监测 sessionKey Cookie、验证并创建账户
final class WebLoginCoordinator: ObservableObject {

    // MARK: - Login State

    enum LoginState: Equatable {
        case loading
        case waitingForLogin
        case validating
        case success(accountName: String)
        case failed(message: String)
    }

    // MARK: - Published Properties

    @Published var loginState: LoginState = .loading
    @Published var loadProgress: Double = 0

    // MARK: - Properties

    private(set) var webView: WKWebView!
    private var cookieTimer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private var onAccountCreated: ((Account) -> Void)?
    private var navigationDelegate: NavigationDelegate?
    private var uiDelegate: UIDelegate?

    /// 允许导航的域名列表
    private let allowedDomains: Set<String> = [
        "claude.ai",
        "google.com",
        "youtube.com",
        "appleid.apple.com",
        "login.microsoftonline.com",
        "github.com",
        "google.co.jp",
        "google.com.hk",
        "challenges.cloudflare.com"
    ]

    /// Safari 17.6 macOS User-Agent
    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    // MARK: - Init

    init() {
        setupWebView()
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        // nonPersistent：完全空白，任何 OAuth provider 都无已有 session，确保多账号添加时不会 auto-SSO
        config.websiteDataStore = .nonPersistent()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUserAgent
        webView.allowsBackForwardNavigationGestures = true

        let delegate = NavigationDelegate(coordinator: self)
        webView.navigationDelegate = delegate
        self.navigationDelegate = delegate

        let ui = UIDelegate(coordinator: self)
        webView.uiDelegate = ui
        self.uiDelegate = ui

        // 监听加载进度
        progressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.loadProgress = webView.estimatedProgress
            }
        }

        self.webView = webView
    }

    // MARK: - Public Methods

    /// 加载登录页面
    func loadLoginPage() {
        guard let url = URL(string: "https://claude.ai/login") else { return }
        loginState = .loading
        webView.load(URLRequest(url: url))
    }

    /// 设置账户创建回调
    func setOnAccountCreated(_ callback: @escaping (Account) -> Void) {
        self.onAccountCreated = callback
    }

    func cleanup() {
        cookieTimer?.invalidate()
        cookieTimer = nil
        progressObservation = nil
    }

    /// 将登录 WebView（nonPersistent）中指定域的 cookie 复制到 default store
    /// 用于在成功登录后同步 session，供 Level 2 静默刷新使用
    private func transferCookiesToDefaultStore(domains: [String]) {
        let sourceStore = webView.configuration.websiteDataStore.httpCookieStore
        let destStore = WKWebsiteDataStore.default().httpCookieStore
        sourceStore.getAllCookies { cookies in
            let relevant = cookies.filter { c in domains.contains { c.domain.contains($0) } }
            for cookie in relevant { destStore.setCookie(cookie) { } }
            Logger.settings.info("WebLogin: 复制 \(relevant.count) 个 Claude cookie 到 default store")
        }
    }

    // MARK: - Cookie Monitoring

    /// 启动 Cookie 轮询定时器
    fileprivate func startCookieMonitoring() {
        cookieTimer?.invalidate()
        cookieTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForSessionKey()
        }
    }

    /// 检查 Cookie 中是否包含 sessionKey
    private func checkForSessionKey() {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }

            let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
            guard let sessionCookie = claudeCookies.first(where: { $0.name == "sessionKey" }) else { return }

            let sessionKey = sessionCookie.value
            // 将 WebView 的完整 cookie（含 cf_clearance/__cf_bm）拼成 header，
            // 避免验证请求因缺少 Cloudflare 通行证而被拦截
            let cookieHeader = claudeCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            Logger.settings.info("WebLogin: 检测到 sessionKey Cookie")

            DispatchQueue.main.async {
                self.cookieTimer?.invalidate()
                self.cookieTimer = nil
                self.validateSessionKey(sessionKey, cookieHeader: cookieHeader)
            }
        }
    }

    // MARK: - Validation

    /// 验证 sessionKey 并获取组织信息
    private func validateSessionKey(_ sessionKey: String, cookieHeader: String) {
        loginState = .validating

        let apiService = ClaudeAPIService()
        apiService.fetchOrganizations(sessionKey: sessionKey, cookieHeader: cookieHeader) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let organizations):
                    if let firstOrg = organizations.first {
                        let account = Account(
                            sessionKey: sessionKey,
                            organizationId: firstOrg.uuid,
                            organizationName: firstOrg.name,
                            alias: nil
                        )

                        // 添加并切换到新账户
                        UserSettings.shared.addAccount(account)
                        UserSettings.shared.switchToAccount(account)

                        self.loginState = .success(accountName: account.displayName)
                        self.onAccountCreated?(account)
                        self.transferCookiesToDefaultStore(domains: ["claude.ai"])

                        Logger.settings.notice("WebLogin: 账户创建成功 - \(account.displayName)")
                    } else {
                        self.loginState = .failed(message: L.Error.noOrganizationsFound)
                    }

                case .failure(let error):
                    let message: String
                    if let usageError = error as? UsageError {
                        message = usageError.localizedDescription
                    } else {
                        message = error.localizedDescription
                    }
                    self.loginState = .failed(message: message)
                    Logger.settings.error("WebLogin: 验证失败 - \(message)")

                    // 验证失败后重新开始监听
                    self.startCookieMonitoring()
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebLoginCoordinator {

    /// 独立的 NavigationDelegate 类，避免 NSObject + ObservableObject 冲突
    final class NavigationDelegate: NSObject, WKNavigationDelegate {
        private weak var coordinator: WebLoginCoordinator?

        init(coordinator: WebLoginCoordinator) {
            self.coordinator = coordinator
            super.init()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard let coordinator = coordinator else { return }
            if coordinator.loginState != .validating {
                coordinator.loginState = .loading
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let coordinator = coordinator else { return }
            // 页面加载完成后，如果还没在验证就开始监听 Cookie
            if case .validating = coordinator.loginState { return }
            if case .success = coordinator.loginState { return }
            coordinator.loginState = .waitingForLogin
            coordinator.startCookieMonitoring()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // 忽略取消的导航
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }

            coordinator?.loginState = .failed(message: error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let coordinator = coordinator,
                  let url = navigationAction.request.url,
                  let host = url.host?.lowercased() else {
                decisionHandler(.allow)
                return
            }

            // 检查域名是否在允许列表中
            let isAllowed = coordinator.allowedDomains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }

            if isAllowed {
                decisionHandler(.allow)
            } else {
                // 在系统浏览器中打开不允许的域名
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - WKUIDelegate

extension WebLoginCoordinator {

    /// 处理页面通过 window.open() 触发的弹出窗口
    /// Google OAuth 传统流程会用弹出窗口完成授权，缺少此代理会导致登录静默失败
    final class UIDelegate: NSObject, WKUIDelegate {
        private weak var coordinator: WebLoginCoordinator?

        init(coordinator: WebLoginCoordinator) {
            self.coordinator = coordinator
            super.init()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            webView.load(navigationAction.request)
            return nil
        }
    }
}
