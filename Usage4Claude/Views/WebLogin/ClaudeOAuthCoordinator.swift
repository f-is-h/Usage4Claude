//
//  ClaudeOAuthCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-19.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import AppKit
import Combine
import Foundation
import OSLog

/// Claude OAuth 登录协调器
///
/// 编排 "Sign in with Claude" 流程：系统浏览器授权 → localhost 回调 → 授权码换 token
/// → 拉 profile → 把 refresh_token 存入账户。彻底绕开内嵌 WKWebView 对 Google /
/// passkey 等登录方式的限制（Issue #49）。
///
/// 凭据约定：refresh_token（sk-ant-ort01-…）存入 `Account.sessionKey`，
/// `organizationId` 存组织 uuid（与旧 cookie 账户去重标识一致，便于平滑迁移）。
@MainActor
final class ClaudeOAuthCoordinator: ObservableObject {

    enum LoginState: Equatable {
        case starting
        case waitingForBrowser
        case exchanging
        case success(accountName: String)
        case failed(message: String)
    }

    @Published private(set) var loginState: LoginState = .starting

    private let server = OAuthCallbackServer()
    private var pkce: PKCECodes?
    private var redirectURI = ""
    private var authorizeURL: URL?
    private var onAccountCreated: ((Account) -> Void)?
    private var timeoutTask: Task<Void, Never>?
    private var finished = false

    private let loginTimeout: TimeInterval = 5 * 60

    // MARK: - Public

    func start(onAccountCreated: ((Account) -> Void)? = nil) {
        self.onAccountCreated = onAccountCreated
        finished = false
        loginState = .starting

        let pkce = PKCECodes()
        self.pkce = pkce

        let ports = [ClaudeOAuthConfig.primaryPort, ClaudeOAuthConfig.fallbackPort]
        guard let port = server.start(ports: ports, onCallback: { [weak self] query in
            Task { @MainActor in self?.handleCallback(query) }
        }) else {
            fail(L.WebLogin.claudeOAuthPortBusy)
            return
        }
        redirectURI = ClaudeOAuthConfig.redirectURI(port: port)

        guard let url = buildAuthorizeURL(pkce: pkce, redirectURI: redirectURI) else {
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        authorizeURL = url
        NSWorkspace.shared.open(url)
        loginState = .waitingForBrowser
        Logger.settings.notice("ClaudeOAuth: 已打开系统浏览器等待授权（回调端口 \(port)）")

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.loginTimeout ?? 300) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.failIfPending(L.WebLogin.codexOAuthTimeout)
        }
    }

    func reopenBrowser() {
        guard let url = authorizeURL, !finished else { return }
        NSWorkspace.shared.open(url)
    }

    /// 手动回退（Issue #68）：接收用户从系统浏览器地址栏粘回的回调链接，
    /// 解析出 code / state 后走与自动 loopback 回调完全相同的处理路径
    /// （包括 state 校验，并用同一 loopback redirect_uri 交换 token，无需重开浏览器）。
    /// 适用于浏览器已跳到 localhost 回调页、但本地回调服务器收不到请求的环境（如某些 Chromium 变体）。
    /// - Returns: 是否成功解析出 code 并进入后续流程；false 表示粘贴内容里没有可用的 code。
    @discardableResult
    func submitManualCallback(_ pasted: String) -> Bool {
        guard !finished else { return false }
        let query = Self.parseManualCallback(pasted)
        // code 或 error 至少有其一才交给 handleCallback：error 场景由其给出准确的失败原因，
        // 两者皆无（粘贴内容无效）则返回 false，由 UI 内联提示重新粘完整链接。
        guard query["code"] != nil || query["error"] != nil else {
            Logger.settings.error("ClaudeOAuth: 手动粘贴内容未解析出 code")
            return false
        }
        Logger.settings.notice("ClaudeOAuth: 使用手动粘贴的回调链接完成登录")
        handleCallback(query)
        return true
    }

    func cancel() {
        cleanup()
    }

    // MARK: - Private

    private func buildAuthorizeURL(pkce: PKCECodes, redirectURI: String) -> URL? {
        var comps = URLComponents(string: ClaudeOAuthConfig.authorizeURL)
        comps?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: ClaudeOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: ClaudeOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pkce.state)
        ]
        return comps?.url
    }

    /// 从用户手动粘贴的内容里解析 OAuth 回调参数（code / state）。
    /// 兼容三种形态：完整回调 URL（含 ?code=...&state=...）、`code#state`、以及纯 code。
    static func parseManualCallback(_ raw: String) -> [String: String] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [:] }

        // 1) 带 query 的 URL：一律以 query 解析为准（含 code / state / error，queryItems 已做百分号解码），
        //    避免把整条 URL 误当成 code（例如授权被拒时回调只带 error 不带 code）。
        if let items = URLComponents(string: text)?.queryItems, !items.isEmpty {
            var result: [String: String] = [:]
            for key in ["code", "state", "error"] {
                if let value = items.first(where: { $0.name == key })?.value, !value.isEmpty {
                    result[key] = value
                }
            }
            return result
        }

        // 2) `code#state` 形态
        if text.contains("#"), !text.contains("?"), !text.contains("/") {
            let parts = text.split(separator: "#", maxSplits: 1).map(String.init)
            var result = ["code": parts[0]]
            if parts.count > 1, !parts[1].isEmpty { result["state"] = parts[1] }
            return result
        }

        // 3) 纯 code（无 state；handleCallback 的 state 校验会拦下并提示重新粘完整链接）
        return ["code": text]
    }

    private func handleCallback(_ query: [String: String]) {
        guard !finished else { return }

        guard let returnedState = query["state"], returnedState == pkce?.state else {
            Logger.settings.error("ClaudeOAuth: state 校验失败")
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        if let error = query["error"] {
            Logger.settings.error("ClaudeOAuth: 授权端返回错误 \(error)")
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        guard let code = query["code"], let pkce = pkce else {
            fail(L.WebLogin.codexOAuthFailed)
            return
        }

        loginState = .exchanging
        ClaudeOAuthService.exchangeCode(
            code: code,
            state: returnedState,
            codeVerifier: pkce.codeVerifier,
            redirectURI: redirectURI
        ) { [weak self] result in
            Task { @MainActor in self?.handleTokens(result) }
        }
    }

    private func handleTokens(_ result: Result<ClaudeOAuthTokens, Error>) {
        guard !finished else { return }

        switch result {
        case .failure(let error):
            Logger.settings.error("ClaudeOAuth: token 交换失败 \(error.localizedDescription)")
            fail(L.WebLogin.codexOAuthFailed)

        case .success(let tokens):
            guard !tokens.refreshToken.isEmpty else {
                Logger.settings.error("ClaudeOAuth: 响应缺少 refresh_token")
                fail(L.WebLogin.codexOAuthFailed)
                return
            }
            // 拉 profile 完善账户信息（email / 组织 uuid），失败也不阻断登录
            ClaudeOAuthService.fetchProfile(accessToken: tokens.accessToken) { [weak self] profile in
                Task { @MainActor in self?.createAccount(tokens: tokens, profile: profile) }
            }
        }
    }

    private func createAccount(tokens: ClaudeOAuthTokens, profile: Result<(email: String, orgId: String, orgName: String), Error>) {
        guard !finished else { return }

        var email = ""
        var orgId = ""
        if case .success(let p) = profile {
            email = p.email
            orgId = p.orgId
        }
        let displayName = email.isEmpty ? "Claude" : email
        // organizationId 用组织 uuid（缺失时退回 email），与旧 cookie 账户的去重标识一致
        let stableOrgId = orgId.isEmpty ? email : orgId

        // 迁移：addAccount 对已存在的 organizationId 会直接跳过，故先移除同标识的旧账户再添加
        if !stableOrgId.isEmpty,
           let existing = UserSettings.shared.accounts.first(where: { $0.organizationId == stableOrgId }) {
            UserSettings.shared.removeAccount(existing)
        }

        let account = Account(
            sessionKey: tokens.refreshToken,
            organizationId: stableOrgId,
            organizationName: displayName,
            alias: nil,
            provider: .claude
        )
        UserSettings.shared.addAccount(account)
        UserSettings.shared.switchToAccount(account)

        loginState = .success(accountName: account.displayName)
        onAccountCreated?(account)
        Logger.settings.notice("ClaudeOAuth: 账户创建成功 - \(account.displayName)")
        finishCleanup()
    }

    private func fail(_ message: String) {
        loginState = .failed(message: message)
        finishCleanup()
    }

    private func failIfPending(_ message: String) {
        guard !finished else { return }
        fail(message)
    }

    private func finishCleanup() {
        finished = true
        cleanup()
    }

    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        server.stop()
    }
}
