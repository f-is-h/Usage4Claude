//
//  ProviderAuthPath.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 账号凭据决定的认证路径
///
/// 一个账号的凭据形态决定了它该走哪条链路：cookie 账号用 sessionKey /
/// session-token 发 Cookie，OAuth 账号用 refresh_token 换 access_token。
/// 判定规则只有这一处，服务层和诊断层都必须问它。
///
/// 之所以要收口：诊断层曾自己假设「Claude 一定走 cookie、Codex 一定走
/// session-token」，于是把 OAuth 账号的 refresh_token 当 Cookie 发出去，
/// 稳定拿到 403 / 空 session，再据此报「凭据已过期，请重新登录」——而那些账号
/// 一直在正常刷新。服务层的分流是对的，诊断层复制了一份并且复制错了，
/// 这种脱钩只能靠共用同一个判定来根治。
nonisolated enum ProviderAuthPath: String, Equatable, Sendable {

    /// 浏览器 Cookie 凭据：Claude 的 sessionKey、Codex 的 next-auth session-token
    case cookie

    /// OAuth refresh_token 凭据
    case oauth

    // MARK: - 判定

    /// Claude OAuth refresh_token 的前缀
    private static let claudeOAuthPrefix = "sk-ant-ort01-"

    /// Codex（OpenAI）OAuth refresh_token 的前缀。
    /// 旧的 session-token 是 next-auth 加密串，不会命中此前缀。
    private static let codexOAuthPrefix = "rt."

    /// Claude 账号凭据对应的认证路径
    static func forClaude(credential: String) -> ProviderAuthPath {
        credential.hasPrefix(claudeOAuthPrefix) ? .oauth : .cookie
    }

    /// Codex 账号凭据对应的认证路径
    static func forCodex(credential: String) -> ProviderAuthPath {
        credential.hasPrefix(codexOAuthPrefix) ? .oauth : .cookie
    }

    /// 指定 provider 的凭据对应的认证路径
    static func of(_ provider: ProviderType, credential: String) -> ProviderAuthPath {
        switch provider {
        case .claude: return forClaude(credential: credential)
        case .codex:  return forCodex(credential: credential)
        }
    }

    /// 报告与诊断里展示的名称
    var displayName: String {
        switch self {
        case .cookie: return "Browser cookie"
        case .oauth:  return "OAuth"
        }
    }
}
