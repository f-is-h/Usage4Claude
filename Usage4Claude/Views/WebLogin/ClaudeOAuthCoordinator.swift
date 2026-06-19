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
