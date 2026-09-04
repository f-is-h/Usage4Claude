//
//  DiagnosticResponseClassifier.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 诊断响应分类器
///
/// 把「原始 HTTP 响应 → 失败原因」的判定从 `DiagnosticRunner` 里剥出来，理由有二：
/// 一是这部分是纯函数，能进 `Package.swift` 的白名单做单测；二是历史上它被写成
/// 「解不出预期结构就一律算解析失败」，把最常见的凭据过期误报成 Data Parsing Error，
/// 诊断结论跟着退化成 Unknown（Issue #84）。分类必须先于解码。
nonisolated enum DiagnosticResponseClassifier {

    // MARK: - Claude

    /// Claude usage 接口的判定结果
    enum ClaudeUsageOutcome: Equatable {
        /// 被 Cloudflare 拦截
        case cloudflareChallenge
        /// 凭据被服务端拒绝（sessionKey 过期或与 orgId 不匹配）
        case credentialsRejected(detail: String)
        /// 凭据有效，但该套餐不提供用量看板
        case usageDashboardUnavailable
        /// 正常拿到用量数据
        case usageDataAvailable(utilizationPreview: String)
        /// 结构完全不认识，需要人工看原始响应
        case unparsable
    }

    static func classifyClaudeUsage(statusCode: Int, body: Data) -> ClaudeUsageOutcome {
        let bodyString = String(data: body, encoding: .utf8) ?? ""

        if looksLikeCloudflareChallenge(bodyString, statusCode: statusCode) {
            return .cloudflareChallenge
        }

        // 鉴权失败先判。claude.ai 在 401/403 时返回的是结构化 JSON 错误体，
        // 而不是 UsageResponse，直接往下解码只会得到「解析失败」这个错误结论。
        let decoder = JSONDecoder()
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: body) {
            let detail = claudeErrorDetail(errorResponse, statusCode: statusCode)
            if errorResponse.error.type == "permission_error"
                || errorResponse.error.type == "authentication_error"
                || statusCode == 401 || statusCode == 403 {
                return .credentialsRejected(detail: detail)
            }
        }

        if statusCode == 401 || statusCode == 403 {
            return .credentialsRejected(detail: "Server rejected the credentials (HTTP \(statusCode))")
        }

        if let usage = try? decoder.decode(UsageResponse.self, from: body) {
            if usage.isUsageDashboardUnavailable {
                return .usageDashboardUnavailable
            }
            let preview = usage.five_hour.map { "\($0.utilization)%" } ?? "n/a"
            return .usageDataAvailable(utilizationPreview: preview)
        }

        return .unparsable
    }

    /// 把服务端错误体压成一行可读描述，供报告展示
    private static func claudeErrorDetail(_ response: ErrorResponse, statusCode: Int) -> String {
        var detail = "HTTP \(statusCode): \(response.error.message)"
        if !response.error.type.isEmpty {
            detail += " (\(response.error.type))"
        }
        return detail
    }

    // MARK: - Codex

    /// Codex `/api/auth/session` 的判定结果
    enum CodexSessionOutcome: Equatable {
        /// 被 Cloudflare 拦截
        case cloudflareChallenge
        /// session token 已失效（含 401/403，以及 200 但无 accessToken 的空 session）
        case sessionRejected(detail: String)
        /// 拿到有效 accessToken
        case authenticated(accessToken: String, email: String?)
        /// 结构完全不认识
        case unparsable
    }

    static func classifyCodexSession(statusCode: Int, body: Data) -> CodexSessionOutcome {
        let bodyString = String(data: body, encoding: .utf8) ?? ""

        if looksLikeCloudflareChallenge(bodyString, statusCode: nil) {
            return .cloudflareChallenge
        }

        if statusCode == 401 || statusCode == 403 {
            return .sessionRejected(detail: "Session token rejected (HTTP \(statusCode))")
        }

        guard let session = try? JSONDecoder().decode(CodexSessionResponse.self, from: body) else {
            return .unparsable
        }

        // 未登录时 chatgpt.com 返回 HTTP 200 + 只有 WARNING_BANNER 的空 body。
        // CodexSessionResponse 两个字段都是 optional，解码会成功但 accessToken 为 nil，
        // 这是「没有 session」而不是「解析失败」，必须分开（Issue #84）。
        guard let accessToken = session.accessToken, !accessToken.isEmpty else {
            return .sessionRejected(
                detail: "Session endpoint returned HTTP \(statusCode) with no access token — not signed in, or the session token has expired"
            )
        }

        return .authenticated(accessToken: accessToken, email: session.user?.email)
    }

    // MARK: - Shared

    /// Cloudflare 挑战页判定
    ///
    /// - Parameter statusCode: 传入时要求 403 才算命中（Claude 的 usage 接口正常也会返回 HTML 之外的东西）；
    ///   传 nil 表示只看响应体特征。
    static func looksLikeCloudflareChallenge(_ bodyString: String, statusCode: Int?) -> Bool {
        let isHTML = bodyString.contains("<!DOCTYPE html>") || bodyString.contains("<html")
        guard isHTML else { return false }

        let hasCloudflareMarker = bodyString.localizedCaseInsensitiveContains("cloudflare")
            || bodyString.contains("cf-mitigated")
            || bodyString.contains("Just a moment")

        if let statusCode {
            return statusCode == 403 || hasCloudflareMarker
        }
        return hasCloudflareMarker
    }
}
