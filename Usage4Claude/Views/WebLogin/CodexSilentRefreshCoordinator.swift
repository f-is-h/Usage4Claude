//
//  CodexSilentRefreshCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import WebKit
import OSLog

/// Codex 隐藏 WebView 静默续期协调器（级别 2 兜底）
///
/// 原理：用 WKWebsiteDataStore.default()（进程级单例）创建一个不加入视图层级的隐藏
/// WKWebView，load chatgpt.com。WebKit 会自动携带当前进程中已有的所有 Cookie（含
/// Cloudflare 的 cf_clearance/__cf_bm），服务端进行 NextAuth OAuth 刷新后通过
/// Set-Cookie 下发续期后的新 session-token，WebKit 自动存入共享 data store。
/// 加载完成后从 cookie store 读取新 session-token 并静默写回 Keychain。
///
/// 适用场景：Level 1 SSR 刷新失败后的降级路径。比 URLSession 路径更可靠，
/// 因为 WebKit 使用真实浏览器级别的 Cookie + TLS 指纹，通过 Cloudflare 的成功率更高。
@MainActor
final class CodexSilentRefreshCoordinator: NSObject {

    static let shared = CodexSilentRefreshCoordinator()

    private(set) var isRefreshing = false

    private var webView: WKWebView?
    private var navigationDelegate: NavigationDelegate?
    private var timeoutTask: Task<Void, Never>?
    private var completion: ((Result<String, Error>) -> Void)?

    private let timeoutInterval: TimeInterval = 25
    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    private override init() {}

    // MARK: - Public

    /// 触发静默刷新。成功时 Result.success 携带最新的 session-token 字符串。
    func refresh(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isRefreshing else {
            Logger.settings.debug("CodexSilentRefresh: 刷新已在进行中，跳过")
            completion(.failure(UsageError.networkError))
            return
        }

        let sessionToken = UserSettings.shared.codexSessionToken
        guard !sessionToken.isEmpty else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        isRefreshing = true
        self.completion = completion

        // 使用进程级共享 data store，与登录窗口的 WKWebView 共享同一套 cookie
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = safariUserAgent
        // 不加入任何视图层级，仅作后台加载用途

        let delegate = NavigationDelegate(coordinator: self)
        wv.navigationDelegate = delegate
        self.navigationDelegate = delegate
        self.webView = wv

        // 超时保护
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.timeoutInterval ?? 25) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, self.isRefreshing else { return }
            Logger.settings.error("CodexSilentRefresh: 超时（\(self.timeoutInterval)s），放弃")
            self.finish(result: .failure(UsageError.networkError))
        }

        guard let url = URL(string: "https://chatgpt.com") else {
            finish(result: .failure(UsageError.invalidURL))
            return
        }

        Logger.settings.info("CodexSilentRefresh: 隐藏 WebView 加载 chatgpt.com")
        wv.load(URLRequest(url: url))
    }

    // MARK: - Navigation Callbacks (called by NavigationDelegate)

    fileprivate func didFinishNavigation() {
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            let chatgptCookies = cookies.filter { $0.domain.contains("chatgpt.com") }
            Logger.settings.debug("CodexSilentRefresh: 加载完成，chatgpt.com Cookies 数量：\(chatgptCookies.count)")

            guard let newToken = CodexWebLoginCoordinator.extractSessionToken(from: chatgptCookies) else {
                Logger.settings.error("CodexSilentRefresh: Cookie 中未找到 session-token，静默刷新失败")
                self.finish(result: .failure(UsageError.sessionExpired))
                return
            }

            let currentToken = UserSettings.shared.codexSessionToken
            if newToken != currentToken {
                Logger.settings.notice("CodexSilentRefresh: 获取到新 session-token，静默写回 Keychain")
                UserSettings.shared.silentlyUpdateCurrentCodexSessionToken(newToken)
            } else {
                Logger.settings.info("CodexSilentRefresh: session-token 未变化（服务端未续期）")
            }

            self.finish(result: .success(newToken))
        }
    }

    fileprivate func didDetectCloudflareChallenge() {
        Logger.settings.error("CodexSilentRefresh: 遇到 Cloudflare 挑战，静默刷新无法继续")
        finish(result: .failure(UsageError.cloudflareBlocked))
    }

    fileprivate func didFailNavigation(error: Error) {
        Logger.settings.error("CodexSilentRefresh: 导航失败 - \(error.localizedDescription)")
        finish(result: .failure(error))
    }

    // MARK: - Private

    private func finish(result: Result<String, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        isRefreshing = false
        webView?.navigationDelegate = nil
        webView = nil
        navigationDelegate = nil
        let cb = completion
        completion = nil
        cb?(result)
    }
}

// MARK: - WKNavigationDelegate

extension CodexSilentRefreshCoordinator {

    final class NavigationDelegate: NSObject, WKNavigationDelegate {
        private weak var coordinator: CodexSilentRefreshCoordinator?

        init(coordinator: CodexSilentRefreshCoordinator) {
            self.coordinator = coordinator
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 用 JS 读取页面标题，检测 Cloudflare 交互式挑战页
            webView.evaluateJavaScript("document.title") { [weak self] result, _ in
                let title = result as? String ?? ""
                if title.contains("Just a moment") || title.contains("Attention Required") || title.contains("cf-browser-verification") {
                    self?.coordinator?.didDetectCloudflareChallenge()
                } else {
                    self?.coordinator?.didFinishNavigation()
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            coordinator?.didFailNavigation(error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            coordinator?.didFailNavigation(error: error)
        }
    }
}
