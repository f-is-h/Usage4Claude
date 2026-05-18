//
//  CodexWebLoginCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Combine
import Foundation
import WebKit
import os

/// Codex WebView 管理和 Cookie 检测核心逻辑
/// 负责加载 chatgpt.com 登录页面、监测 __Secure-next-auth.session-token Cookie、验证并创建账户
final class CodexWebLoginCoordinator: ObservableObject {

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

    private let apiService = CodexAPIService()

    /// 允许导航的域名列表（包含 ChatGPT 的 SSO 域名）
    private let allowedDomains: Set<String> = [
        "chatgpt.com",
        "openai.com",
        "auth.openai.com",
        "auth0.openai.com",
        "google.com",
        "youtube.com",
        "appleid.apple.com",
        "login.microsoftonline.com",
        "github.com",
        "google.co.jp",
        "google.com.hk",
        "challenges.cloudflare.com"
    ]

    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    // MARK: - Init

    init() {
        setupWebView()
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
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

        progressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.loadProgress = webView.estimatedProgress
            }
        }

        self.webView = webView
    }

    // MARK: - Public Methods

    func loadLoginPage() {
        guard let url = URL(string: "https://chatgpt.com/auth/login") else { return }
        loginState = .loading
        webView.load(URLRequest(url: url))
    }

    func setOnAccountCreated(_ callback: @escaping (Account) -> Void) {
        self.onAccountCreated = callback
    }

    func cleanup() {
        cookieTimer?.invalidate()
        cookieTimer = nil
        progressObservation = nil
    }

    // MARK: - Cookie Monitoring

    fileprivate func startCookieMonitoring() {
        cookieTimer?.invalidate()
        cookieTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForSessionToken()
        }
    }

    private func checkForSessionToken() {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }

            let chatgptCookies = cookies.filter { $0.domain.contains("chatgpt.com") }
            guard let sessionToken = Self.extractSessionToken(from: chatgptCookies) else { return }

            let cookieHeader = chatgptCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            Logger.settings.info("CodexWebLogin: 检测到 session-token Cookie")

            DispatchQueue.main.async {
                self.cookieTimer?.invalidate()
                self.cookieTimer = nil
                self.validateSessionToken(sessionToken, cookieHeader: cookieHeader)
            }
        }
    }

    /// 从 chatgpt.com Cookie 列表中提取 session token 值
    /// 支持标准名称、无 __Secure- 前缀版本，以及 next-auth 分片 Cookie（.0/.1/...）
    static func extractSessionToken(from cookies: [HTTPCookie]) -> String? {
        let baseNames = ["__Secure-next-auth.session-token", "next-auth.session-token"]

        for baseName in baseNames {
            if let cookie = cookies.first(where: { $0.name == baseName }) {
                return cookie.value
            }
            let chunks = cookies
                .filter { cookie in
                    guard cookie.name.hasPrefix(baseName + ".") else { return false }
                    let suffix = cookie.name.dropFirst(baseName.count + 1)
                    return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
                }
                .sorted {
                    let ia = Int($0.name.dropFirst(baseName.count + 1)) ?? 0
                    let ib = Int($1.name.dropFirst(baseName.count + 1)) ?? 0
                    return ia < ib
                }
            if !chunks.isEmpty {
                return chunks.map(\.value).joined()
            }
        }
        return nil
    }

    // MARK: - Validation

    private func validateSessionToken(_ sessionToken: String, cookieHeader: String) {
        loginState = .validating

        apiService.validateSessionToken(sessionToken, cookieHeader: cookieHeader) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let info):
                let account = Account(
                    sessionKey: sessionToken,
                    organizationId: info.email,
                    organizationName: info.displayName,
                    alias: nil,
                    provider: .codex
                )

                let storedAccount = UserSettings.shared.addCodexAccount(account)
                UserSettings.shared.switchToCodexAccount(storedAccount)

                self.loginState = .success(accountName: storedAccount.displayName)
                self.onAccountCreated?(storedAccount)

                Logger.settings.notice("CodexWebLogin: 账户创建成功 - \(storedAccount.displayName)")

            case .failure(let error):
                self.loginState = .failed(message: error.localizedDescription)
                Logger.settings.error("CodexWebLogin: 验证失败 - \(error.localizedDescription)")

                // 验证失败后重新开始监听
                self.startCookieMonitoring()
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension CodexWebLoginCoordinator {

    final class NavigationDelegate: NSObject, WKNavigationDelegate {
        private weak var coordinator: CodexWebLoginCoordinator?

        init(coordinator: CodexWebLoginCoordinator) {
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
            if case .validating = coordinator.loginState { return }
            if case .success = coordinator.loginState { return }
            coordinator.loginState = .waitingForLogin
            coordinator.startCookieMonitoring()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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

            let isAllowed = coordinator.allowedDomains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }

            if isAllowed {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - WKUIDelegate

extension CodexWebLoginCoordinator {

    /// 处理页面通过 window.open() 触发的弹出窗口
    /// Google OAuth 传统流程会用弹出窗口完成授权，缺少此代理会导致登录静默失败
    final class UIDelegate: NSObject, WKUIDelegate {
        private weak var coordinator: CodexWebLoginCoordinator?

        init(coordinator: CodexWebLoginCoordinator) {
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
