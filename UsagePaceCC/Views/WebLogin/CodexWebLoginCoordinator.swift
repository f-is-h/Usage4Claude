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

    private let apiService = CodexAPIService()

    /// 允许导航的域名列表（包含 ChatGPT 的 SSO 域名）
    private let allowedDomains: Set<String> = [
        "chatgpt.com",
        "openai.com",
        "auth.openai.com",
        "auth0.openai.com",
        "accounts.google.com",
        "appleid.apple.com",
        "login.microsoftonline.com",
        "github.com",
        "accounts.google.co.jp",
        "accounts.google.com.hk",
        "www.google.com",
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
        config.websiteDataStore = .nonPersistent()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUserAgent
        webView.allowsBackForwardNavigationGestures = true

        let delegate = NavigationDelegate(coordinator: self)
        webView.navigationDelegate = delegate
        self.navigationDelegate = delegate

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

        let dataStore = webView.configuration.websiteDataStore
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: allTypes) { records in
            dataStore.removeData(ofTypes: allTypes, for: records) {
                Logger.settings.info("CodexWebLogin: 已清除所有 WebView 数据")
            }
        }
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

            let sessionCookie = cookies.first { cookie in
                cookie.name == "__Secure-next-auth.session-token" && cookie.domain.contains("chatgpt.com")
            }

            if let cookie = sessionCookie {
                let sessionToken = cookie.value
                Logger.settings.info("CodexWebLogin: 检测到 session-token Cookie")

                DispatchQueue.main.async {
                    self.cookieTimer?.invalidate()
                    self.cookieTimer = nil
                    self.validateSessionToken(sessionToken)
                }
            }
        }
    }

    // MARK: - Validation

    private func validateSessionToken(_ sessionToken: String) {
        loginState = .validating

        apiService.validateSessionToken(sessionToken) { [weak self] result in
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
