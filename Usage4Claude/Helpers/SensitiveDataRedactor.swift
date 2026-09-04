//
//  SensitiveDataRedactor.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-01.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 敏感数据脱敏工具
/// 提供统一的敏感信息脱敏方法，用于日志记录和诊断报告
/// 支持 Organization ID、Session Key 和文本中的敏感信息脱敏
class SensitiveDataRedactor {
    // MARK: - Public Methods

    /// 脱敏 Organization ID
    /// - Parameter id: 原始 Organization ID
    /// - Returns: 脱敏后的字符串
    /// - Note: 对于短于8位的ID，全部替换为星号；否则保留前4位和后4位
    /// - Example: "12345678-1234-1234-1234-123456789012" -> "1234...9012"
    static func redactOrganizationId(_ id: String) -> String {
        guard id.count > 8 else {
            return String(repeating: "*", count: id.count)
        }
        let prefix = id.prefix(4)
        let suffix = id.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    /// 脱敏 Session Key
    /// - Parameter key: 原始 Session Key
    /// - Returns: 脱敏后的字符串
    /// - Note: 对于 sk-ant- 开头的 key，保留前缀并显示长度；其他情况返回 "***"
    /// - Example: "sk-ant-sid...XXXXX" -> "sk-ant-***...*** (128 chars)"
    static func redactSessionKey(_ key: String) -> String {
        guard key.count > 20 else {
            return "***"
        }

        // 保留前缀 "sk-ant-"
        if key.hasPrefix("sk-ant-") {
            return "sk-ant-***...*** (\(key.count) chars)"
        }

        // 其他格式的 key
        return "***...*** (\(key.count) chars)"
    }

    /// 脱敏 Codex Session Token（JWE 长串）
    /// - Parameter token: __Secure-next-auth.session-token 的值
    /// - Returns: 脱敏后的字符串，保留前8位和后4位
    static func redactCodexSessionToken(_ token: String) -> String {
        guard token.count > 12 else {
            return String(repeating: "*", count: token.count)
        }
        return "\(token.prefix(8))...\(token.suffix(4)) (\(token.count) chars)"
    }

    /// 脱敏 JWT Access Token（三段式 header.payload.signature）
    /// - Parameter token: Bearer accessToken 字符串
    /// - Returns: 脱敏后的字符串，每段只保留前6字符
    static func redactAccessToken(_ token: String) -> String {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            guard token.count > 12 else { return "***" }
            return "\(token.prefix(8))...\(token.suffix(4)) (\(token.count) chars)"
        }
        let h = String(parts[0].prefix(6))
        let p = String(parts[1].prefix(6))
        let s = String(parts[2].prefix(6))
        return "\(h)...\(p)...\(s)... (\(token.count) chars)"
    }

    /// 脱敏文本中的敏感信息
    /// 使用正则表达式查找并替换文本中的 Organization ID 和 Session Key
    /// - Parameter text: 包含敏感信息的原始文本
    /// - Returns: 脱敏后的文本
    /// - Note: 用于日志和诊断输出，自动识别并脱敏常见格式
    static func redactText(_ text: String) -> String {
        var sanitized = text

        // 脱敏 Session Key (保留前4位和后4位)
        // 匹配模式: sessionKey=xxx 或 sessionKey: xxx
        let sessionKeyPattern = "sessionKey[=:]\\s*[\"']?([a-zA-Z0-9-]{20,})[\"']?"
        if let regex = try? NSRegularExpression(pattern: sessionKeyPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "sessionKey=***REDACTED***"
            )
        }

        // 脱敏 Organization ID (UUID 格式)
        // 匹配模式: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        let orgIdPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        if let regex = try? NSRegularExpression(pattern: orgIdPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "********-****-****-****-************"
            )
        }

        // 脱敏 Cookie 中的 sessionKey
        // 匹配模式: Cookie: sessionKey=xxx
        let cookiePattern = "Cookie:\\s*sessionKey=([a-zA-Z0-9-]{20,})"
        if let regex = try? NSRegularExpression(pattern: cookiePattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "Cookie: sessionKey=***REDACTED***"
            )
        }

        return sanitized
    }

    /// 脱敏文本中的令牌：JSON 令牌字段与裸 JWT
    ///
    /// `redactText` 只认 sessionKey / Organization ID 这类形态，认不出
    /// `"accessToken": "<JWT>"`。日志和诊断报告都要经过这一道。
    /// - Parameter text: 原始文本
    /// - Returns: 令牌被替换后的文本
    static func redactTokens(_ text: String) -> String {
        var sanitized = text

        // JSON 里的令牌字段：accessToken / access_token / refresh_token / id_token / token / authorization
        let tokenFieldPattern = "\"(access_?token|refresh_?token|id_?token|session_?token|token|authorization)\"\\s*:\\s*\"[^\"]+\""
        if let regex = try? NSRegularExpression(pattern: tokenFieldPattern, options: .caseInsensitive) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "\"$1\": \"***REDACTED***\""
            )
        }

        // 裸 JWT（三段 base64url）：兜住不在已知字段名下的令牌
        let jwtPattern = "eyJ[A-Za-z0-9_-]{6,}\\.[A-Za-z0-9_-]{6,}\\.[A-Za-z0-9_-]+"
        if let regex = try? NSRegularExpression(pattern: jwtPattern, options: []) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "***REDACTED_JWT***"
            )
        }

        return sanitized
    }

    /// 脱敏一条日志消息
    ///
    /// `AppLog` 强制每条消息都过这里再写盘/写系统日志。我们靠自己的脱敏保证安全，
    /// 而不是靠 OSLog 的 `<private>` —— 后者只是默认不显示（装上 Apple 的 logging
    /// profile 即可读出），而且它会把错误详情一并埋掉，让日志失去诊断价值。
    /// - Parameter message: 原始日志消息
    /// - Returns: 可安全写入并公开展示的消息
    static func redactLogMessage(_ message: String) -> String {
        redactTokens(redactText(message))
    }
}
