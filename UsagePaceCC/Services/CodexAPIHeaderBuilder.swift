//
//  CodexAPIHeaderBuilder.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// Codex API HTTP 请求头构建器
/// 提供两种请求头：
///   - Session 端点（/api/auth/session）：使用 session-token Cookie
///   - Usage 端点（/backend-api/wham/usage）：使用 Bearer accessToken
class CodexAPIHeaderBuilder {

    // MARK: - Session 端点 Headers（Cookie 认证）

    /// 构建 /api/auth/session 请求的 Headers
    /// - Parameter sessionToken: __Secure-next-auth.session-token cookie 值
    static func buildSessionHeaders(sessionToken: String) -> [String: String] {
        return [
            "accept": "*/*",
            "accept-language": "zh-CN,zh;q=0.9,en;q=0.8",
            "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "origin": "https://chatgpt.com",
            "referer": "https://chatgpt.com/",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin",
            "Cookie": "__Secure-next-auth.session-token=\(sessionToken)"
        ]
    }

    /// 为 URLRequest 应用 Session 端点 Headers
    static func applySessionHeaders(to request: inout URLRequest, sessionToken: String) {
        let headers = buildSessionHeaders(sessionToken: sessionToken)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    // MARK: - Usage 端点 Headers（Bearer Token 认证）

    /// 构建 /backend-api/wham/usage 请求的 Headers
    /// - Parameter accessToken: 从 /api/auth/session 获取的 Bearer token
    static func buildUsageHeaders(accessToken: String) -> [String: String] {
        return [
            "accept": "*/*",
            "accept-language": "zh-CN,zh;q=0.9,en;q=0.8",
            "content-type": "application/json",
            "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            "authorization": "Bearer \(accessToken)",
            "origin": "https://chatgpt.com",
            "referer": "https://chatgpt.com/",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin"
        ]
    }

    /// 为 URLRequest 应用 Usage 端点 Headers
    static func applyUsageHeaders(to request: inout URLRequest, accessToken: String) {
        let headers = buildUsageHeaders(accessToken: accessToken)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
