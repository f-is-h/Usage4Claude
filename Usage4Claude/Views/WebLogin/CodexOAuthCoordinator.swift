//
//  CodexOAuthCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import AppKit
import Combine
import Foundation
import OSLog

/// Codex OAuth 登录协调器
///
/// 编排完整的 "Sign in with ChatGPT" 流程：
///   1. 生成 PKCE + state
///   2. 起本地回调服务器（localhost:1455/1457）
///   3. 用系统默认浏览器打开授权页（Google / 微软 / 企业 SSO / passkey 在真实浏览器中均可用）
///   4. 接收回调，校验 state，用授权码换 token
///   5. 解析账户信息，把 refresh_token 存入账户体系
///
/// 凭据存储约定：refresh_token 存入 `Account.sessionKey`，`organizationId` 存 email
/// （与旧 session-token 账户共用同一套多账号体系，零结构改动）。
@MainActor
final class CodexOAuthCoordinator: ObservableObject {

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

    /// 用户未完成登录时的整体超时
    private let loginTimeout: TimeInterval = 5 * 60

    // MARK: - Public

    func start(onAccountCreated: ((Account) -> Void)? = nil) {
        self.onAccountCreated = onAccountCreated
        finished = false
        loginState = .starting

        let pkce = PKCECodes()
        self.pkce = pkce

        // 起本地回调服务器（依次尝试 1455 / 1457）
        let ports = [CodexOAuthConfig.primaryPort, CodexOAuthConfig.fallbackPort]
        guard let port = server.start(ports: ports, onCallback: { [weak self] query in
            Task { @MainActor in self?.handleCallback(query) }
        }) else {
            fail(L.WebLogin.codexOAuthPortBusy)
            return
        }
        redirectURI = CodexOAuthConfig.redirectURI(port: port)

        guard let url = buildAuthorizeURL(pkce: pkce, redirectURI: redirectURI) else {
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        authorizeURL = url
        NSWorkspace.shared.open(url)
        loginState = .waitingForBrowser
        Logger.settings.notice("CodexOAuth: 已打开系统浏览器等待授权（回调端口 \(port)）")

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.loginTimeout ?? 300) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.failIfPending(L.WebLogin.codexOAuthTimeout)
        }
    }

    /// 用户误关浏览器标签时，重新打开授权页
    func reopenBrowser() {
        guard let url = authorizeURL, !finished else { return }
        NSWorkspace.shared.open(url)
    }

    func cancel() {
        cleanup()
    }

    // MARK: - Private

    private func buildAuthorizeURL(pkce: PKCECodes, redirectURI: String) -> URL? {
        var comps = URLComponents(string: CodexOAuthConfig.authorizeURL)
        comps?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: CodexOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: CodexOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "originator", value: CodexOAuthConfig.originator),
            URLQueryItem(name: "state", value: pkce.state)
        ]
        return comps?.url
    }

    private func handleCallback(_ query: [String: String]) {
        guard !finished else { return }

        // 校验 state，防 CSRF
        guard let returnedState = query["state"], returnedState == pkce?.state else {
            Logger.settings.error("CodexOAuth: state 校验失败")
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        if let error = query["error"] {
            Logger.settings.error("CodexOAuth: 授权端返回错误 \(error)")
            fail(L.WebLogin.codexOAuthFailed)
            return
        }
        guard let code = query["code"], let verifier = pkce?.codeVerifier else {
            fail(L.WebLogin.codexOAuthFailed)
            return
        }

        loginState = .exchanging
        CodexOAuthService.exchangeCode(code: code, codeVerifier: verifier, redirectURI: redirectURI) { [weak self] result in
            Task { @MainActor in self?.handleTokens(result) }
        }
    }

    private func handleTokens(_ result: Result<CodexOAuthTokens, Error>) {
        guard !finished else { return }

        switch result {
        case .failure(let error):
            Logger.settings.error("CodexOAuth: token 交换失败 \(error.localizedDescription)")
            fail(L.WebLogin.codexOAuthFailed)

        case .success(let tokens):
            guard !tokens.refreshToken.isEmpty else {
                Logger.settings.error("CodexOAuth: 响应缺少 refresh_token")
                fail(L.WebLogin.codexOAuthFailed)
                return
            }
            let email = CodexOAuthService.email(fromIDToken: tokens.idToken) ?? ""
            let displayName = email.isEmpty ? "Codex" : email
            // organizationId 用 email 作为去重稳定标识（email 缺失时退回 account_id）
            let account = Account(
                sessionKey: tokens.refreshToken,
                organizationId: email.isEmpty ? (tokens.accountId ?? "") : email,
                organizationName: displayName,
                alias: nil,
                provider: .codex
            )
            let stored = UserSettings.shared.addCodexAccount(account)
            UserSettings.shared.switchToCodexAccount(stored)

            loginState = .success(accountName: stored.displayName)
            onAccountCreated?(stored)
            Logger.settings.notice("CodexOAuth: 账户创建成功 - \(stored.displayName)")
            finishCleanup()
        }
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
