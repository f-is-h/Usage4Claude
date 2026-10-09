//
//  CommandCodeAPIHeaderBuilder.swift
//  Usage4Claude
//
//  Command Code API HTTP header builder. The undocumented billing endpoints at
//  api.commandcode.ai authenticate with the signed-in web session cookie, so
//  the builder mirrors the web app's request shape (Origin/Referer/User-Agent).
//

import Foundation

/// Command Code API 请求头构建器
/// 端点（/internal/billing/*）为未公开接口，用登录后的 Web 会话 Cookie 认证，
/// 因此需要带上与网页端一致的 Origin/Referer/User-Agent。
class CommandCodeAPIHeaderBuilder {

    /// 网页端 Origin，同时用作 Referer 前缀
    static let webOrigin = "https://commandcode.ai"

    /// 模拟的浏览器版本号（Chrome on macOS）。与 Claude 侧同理，建议定期更新。
    private static let simulatedChromeVersion = "143.0.0.0"

    private static var userAgent: String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(simulatedChromeVersion) Safari/537.36"
    }

    /// 构建 Command Code API 请求的标准 Headers
    /// - Parameter cookieHeader: 已解析的 `name=value` Cookie 头
    static func buildHeaders(cookieHeader: String) -> [String: String] {
        return [
            "accept": "application/json, text/plain, */*",
            "accept-language": "en-US,en;q=0.9",
            "user-agent": userAgent,
            "origin": webOrigin,
            "referer": "\(webOrigin)/",
            "cookie": cookieHeader
        ]
    }

    /// 为 URLRequest 应用标准 Headers
    static func applyHeaders(to request: inout URLRequest, cookieHeader: String) {
        for (key, value) in buildHeaders(cookieHeader: cookieHeader) {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
