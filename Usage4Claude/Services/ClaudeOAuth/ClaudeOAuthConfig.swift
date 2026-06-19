//
//  ClaudeOAuthConfig.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-19.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation

/// Claude（claude.ai）OAuth 配置常量
///
/// 复用 Anthropic 官方 Claude Code 的 public OAuth client（PKCE，无 client secret）。
/// 认证在用户的系统默认浏览器中完成，从而绕开 WKWebView 对 Google 嵌入式登录的封锁，
/// 以及 passkey/WebAuthn 在内嵌 WebView 中不可用的问题（见 Issue #49）。
enum ClaudeOAuthConfig {
    /// 授权端点（在 claude.ai 上完成登录与授权）
    static let authorizeURL = "https://claude.ai/oauth/authorize"
    /// token / refresh 端点
    static let tokenURL = "https://console.anthropic.com/v1/oauth/token"

    /// Claude Code 官方 public client id（PKCE，无 client secret）
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// OAuth scope：只读用量只需 user:profile（不请求 user:inference，避免过大权限）
    static let scope = "user:profile"

    // MARK: - 用量 / 账户接口（Bearer access_token）

    /// 订阅用量：返回 five_hour / seven_day 利用率与重置时间、extra_usage
    static let usageURL = "https://api.anthropic.com/api/oauth/usage"
    /// 账户信息：返回 account（email 等）与 organization
    static let profileURL = "https://api.anthropic.com/api/oauth/profile"
    /// OAuth 接口要求的 beta 头
    static let betaHeader = "oauth-2025-04-20"

    // MARK: - 本地回调（优先）/ 手动粘贴（fallback）

    /// 本地回调端口（loopback 自动回调，优先尝试）
    ///
    /// 必须避开 macOS 的 ephemeral 端口范围（49152–65535），否则系统出站连接
    /// 可能动态抢占该端口，导致登录回调服务器绑定失败（尤其重启后系统网络活动密集时）。
    /// 选用 registered-port 区间的固定端口，并与 Codex 的 1455/1457 错开。
    static let primaryPort: UInt16 = 1456
    static let fallbackPort: UInt16 = 1458
    static let callbackPath = "/callback"

    /// Claude Code 官方手动粘贴 redirect（若 client 不接受 localhost 则回退到此模式）
    static let manualRedirectURI = "https://console.anthropic.com/oauth/code/callback"

    /// 构造本地 redirect_uri
    static func redirectURI(port: UInt16) -> String {
        "http://localhost:\(port)\(callbackPath)"
    }
}
