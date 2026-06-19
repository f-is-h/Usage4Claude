//
//  CodexOAuthConfig.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation

/// Codex（ChatGPT）OAuth 配置常量
///
/// 复用 OpenAI 官方 Codex CLI 的 public OAuth client（PKCE，无 client secret）。
/// 这些常量取自 openai/codex 源码 `codex-rs/login`，是官方 "Sign in with ChatGPT" 流程，
/// 在用户的系统默认浏览器中完成认证，因此不受 WKWebView 对 Google 嵌入式登录的封锁、
/// 也不受 WebAuthn/passkey 在内嵌 WebView 中不可用的限制。
enum CodexOAuthConfig {
    /// 授权服务 issuer
    static let issuer = "https://auth.openai.com"
    /// 授权端点
    static let authorizeURL = "\(issuer)/oauth/authorize"
    /// token / refresh 端点（授权码交换与 refresh 共用此端点）
    static let tokenURL = "\(issuer)/oauth/token"

    /// Codex CLI 官方 public client id（PKCE，无 client secret）
    /// 注意：OpenAI 仅为该 client 注册了固定的 localhost 回调，故 redirect_uri 必须用下方端口
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    /// OAuth scope（与官方 Codex CLI 一致）
    static let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"

    /// 本地回调端口（与官方一致；OpenAI 仅为该 client 注册了这两个 localhost 回调）
    static let primaryPort: UInt16 = 1455
    static let fallbackPort: UInt16 = 1457
    /// 回调路径
    static let callbackPath = "/auth/callback"

    /// originator 标识（与官方 Codex CLI 一致，降低授权端风控概率）
    static let originator = "codex_cli_rs"

    /// 构造本地 redirect_uri
    static func redirectURI(port: UInt16) -> String {
        "http://localhost:\(port)\(callbackPath)"
    }
}
