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
    /// - Example: "sk-ant-sid01-XXXXX..." -> "sk-ant-***...*** (128 chars)"
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
}
