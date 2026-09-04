//
//  CodexSilentRefreshCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import WebKit

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
    /// 发起本次刷新时该账号持有的 session-token。
    /// 刷新最长跑 25 秒，期间用户可能切换账号，因此写回时用它反查账号而不是取「当前账号」
    private var refreshingFromToken: String?

    /// 用于在写回前校验新 session-token。校验成功返回的 accessToken 是
    /// 「会话确实已登录」的证明，见 `CodexSessionTokenRotation`。
    private let apiService = CodexAPIService()

    private let timeoutInterval: TimeInterval = 25
    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    private override init() {}

    // MARK: - Public

    /// 触发静默刷新。成功时 Result.success 携带最新的 session-token 字符串。
    func refresh(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isRefreshing else {
            AppLog.trace(.auth, "Silent WebView refresh already in progress; skipping this request")
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
        self.refreshingFromToken = sessionToken

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
            AppLog.error(.auth, "Silent WebView refresh timed out after \(self.timeoutInterval)s; giving up")
            self.finish(result: .failure(UsageError.networkError))
        }

        guard let url = URL(string: "https://chatgpt.com") else {
            finish(result: .failure(UsageError.invalidURL))
            return
        }

        // 续期前重置 default() store 的 session-token：
        // 1. 删除所有残留（含其他账号 / 旧分片 .0/.1）
        // 2. 注入当前账号的完整 session-token
        // 3. 全部完成后再 load，确保服务端看到正确账号的 session
        let cookieStore = wv.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            let toDelete = cookies.filter { c in
                (c.domain.contains("chatgpt.com") || c.domain.contains("openai.com")) &&
                c.name.contains("session-token")
            }
            AppLog.trace(.auth, "Silent WebView refresh cleared \(toDelete.count) stale session-token cookie(s)")

            let group = DispatchGroup()
            for cookie in toDelete {
                group.enter()
                cookieStore.delete(cookie) { group.leave() }
            }

            group.notify(queue: .main) {
                let baseName = "__Secure-next-auth.session-token"
                // WebKit 单 cookie 上限约 4KB，NextAuth 超限时会自动分片为 .0/.1/.2...
                // 注入时同样分片，与 extractSessionToken 的读取逻辑对齐
                let chunkSize = 4000
                // originURL（HTTPS）是 __Secure- 前缀 cookie 合法性验证的必要条件
                let origin = URL(string: "https://chatgpt.com")!

                let tokenChunks = stride(from: 0, to: sessionToken.count, by: chunkSize).map { start -> String in
                    let from = sessionToken.index(sessionToken.startIndex, offsetBy: start)
                    let to = sessionToken.index(from, offsetBy: min(chunkSize, sessionToken.count - start))
                    return String(sessionToken[from..<to])
                }

                let shards: [(name: String, value: String)]
                if tokenChunks.count == 1 {
                    shards = [(baseName, tokenChunks[0])]
                } else {
                    shards = tokenChunks.enumerated().map { ("\(baseName).\($0.offset)", $0.element) }
                    AppLog.trace(.auth, "Silent WebView refresh: token exceeds the cookie size limit, injecting it as \(shards.count) shards")
                }

                let cookies = shards.compactMap { name, value in
                    HTTPCookie(properties: [
                        .name: name,
                        .value: value,
                        .originURL: origin,
                        .path: "/",
                        .secure: "TRUE"
                    ])
                }

                guard !cookies.isEmpty else {
                    AppLog.warning(.auth, "Silent WebView refresh could not build the session-token cookie; loading the page without it")
                    wv.load(URLRequest(url: url))
                    return
                }

                let injectGroup = DispatchGroup()
                for cookie in cookies {
                    injectGroup.enter()
                    cookieStore.setCookie(cookie) { injectGroup.leave() }
                }
                injectGroup.notify(queue: .main) {
                    AppLog.event(.auth, "Silent WebView refresh injected \(cookies.count) cookie(s) and is loading chatgpt.com")
                    wv.load(URLRequest(url: url))
                }
            }
        }
    }

    // MARK: - Navigation Callbacks (called by NavigationDelegate)

    fileprivate func didFinishNavigation() {
        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            let chatgptCookies = cookies.filter { $0.domain.contains("chatgpt.com") }
            AppLog.trace(.auth, "Silent WebView refresh finished loading; chatgpt.com now holds \(chatgptCookies.count) cookie(s)")

            guard let newToken = CodexWebLoginCoordinator.extractSessionToken(from: chatgptCookies) else {
                AppLog.error(.auth, "Silent WebView refresh found no session-token among the cookies; refresh failed")
                self.finish(result: .failure(UsageError.sessionExpired))
                return
            }

            // 与发起刷新时捕获的 token 比较：期间用户可能已切换账号，
            // 取「当前账号」会把本账号的新 token 写进别人的条目
            let originalToken = self.refreshingFromToken ?? ""
            guard let pendingRotation = CodexSessionTokenRotation.pending(
                candidate: newToken, replacing: originalToken
            ) else {
                AppLog.event(.auth, "Silent WebView refresh returned the same session-token; the server did not renew it")
                self.finish(result: .success(newToken))
                return
            }

            // 这条路径手里只有 cookie，没有任何东西能证明会话已登录：chatgpt.com
            // 在未登录时同样会下发一个全新的匿名 session-token。所以先校验再写回，
            // 否则会把匿名 token 覆盖掉用户的真 token，账号被永久登出。
            let cookieHeader = chatgptCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            AppLog.event(.auth, "Silent WebView refresh obtained a new session-token; validating it before writing it back")

            DispatchQueue.main.async {
                self.apiService.validateSessionToken(newToken, cookieHeader: cookieHeader) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let validation):
                        guard let rotation = pendingRotation.authorized(by: validation.accessToken) else {
                            AppLog.error(.auth, "Silent WebView refresh validation returned no proof of an authenticated session; discarding the new token")
                            self.finish(result: .failure(UsageError.sessionExpired))
                            return
                        }
                        AppLog.event(.auth, "Silent WebView refresh validated the new session-token; writing it back to the Keychain")
                        UserSettings.shared.silentlyUpdateCodexSessionToken(rotation.newToken, replacing: rotation.replacing)
                        self.finish(result: .success(rotation.newToken))

                    case .failure(let error):
                        // 校验失败说明这是个未登录的会话，绝不能写回
                        AppLog.error(.auth, "Silent WebView refresh could not validate the new session-token (\(error.localizedDescription)); discarding it rather than overwriting the stored one")
                        self.finish(result: .failure(error))
                    }
                }
            }
        }
    }

    fileprivate func didDetectCloudflareChallenge() {
        AppLog.error(.auth, "Silent WebView refresh hit a Cloudflare challenge and cannot continue")
        finish(result: .failure(UsageError.cloudflareBlocked))
    }

    fileprivate func didFailNavigation(error: Error) {
        AppLog.error(.auth, "Silent WebView refresh navigation failed: \(error.localizedDescription)")
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
        refreshingFromToken = nil
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
