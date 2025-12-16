//
//  ClaudeAPIHeaderBuilder.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// Claude API HTTP 请求头构建器
/// 提供统一的请求头构建逻辑，用于绕过 Cloudflare 防护
/// 包含完整的浏览器模拟 Headers
class ClaudeAPIHeaderBuilder {
    // MARK: - Public Methods

    /// 构建 Claude API 请求的标准 HTTP Headers
    /// - Parameters:
    ///   - organizationId: 组织 ID
    ///   - sessionKey: 会话密钥
    /// - Returns: HTTP Headers 字典
    /// - Note: 这些 Headers 用于绕过 Cloudflare 反机器人检测
    /// - Important: 请求头必须与真实浏览器请求保持一致，避免触发 Cloudflare Challenge
    static func buildHeaders(
        organizationId: String,
        sessionKey: String
    ) -> [String: String] {
        return [
            // 基础 Headers
            "accept": "*/*",
            "accept-language": "zh-CN,zh;q=0.9,en;q=0.8",
            "content-type": "application/json",

            // Anthropic 平台标识
            "anthropic-client-platform": "web_claude_ai",
            "anthropic-client-version": "1.0.0",

            // 浏览器标识（Chrome 131 on macOS）
            "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",

            // 来源和引用信息
            "origin": "https://claude.ai",
            "referer": "https://claude.ai/settings/usage",

            // Fetch API 相关（重要：Cloudflare 检测这些字段）
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin",

            // 认证 Cookie
            "Cookie": "sessionKey=\(sessionKey)"
        ]
    }

    /// 为 URLRequest 应用标准 Headers
    /// - Parameters:
    ///   - request: 要设置 Headers 的 URLRequest（传入传出参数）
    ///   - organizationId: 组织 ID
    ///   - sessionKey: 会话密钥
    /// - Note: 直接修改传入的 request 对象
    static func applyHeaders(
        to request: inout URLRequest,
        organizationId: String,
        sessionKey: String
    ) {
        let headers = buildHeaders(organizationId: organizationId, sessionKey: sessionKey)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
