//
//  OAuthGrantFailure.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 判定 OAuth token 端点的失败是否意味着「授权已死」
///
/// refresh_token 是一次性的：服务端发放新值的同时立刻作废旧值，用过或被撤销之后
/// 再拿它换 token 只会失败，且**无法自愈** —— 用户必须重新登录。
///
/// 问题在于两家的 HTTP 状态码不一样。RFC 6749 §5.2 规定这种情况返回
/// **HTTP 400 + `invalid_grant`**，Anthropic 遵循它；OpenAI 则返回 401。
/// 服务层原本只把 401 认作鉴权失败，400 一律落进通用的 `httpError`，
/// 于是 Claude 账号授权失效时界面提示的是「运行诊断」而不是「重新登录」——
/// 而诊断根本修不了一个已失效的授权。
///
/// 这里按响应内容判定，而不是只看状态码。
nonisolated enum OAuthGrantFailure {

    /// 这次失败是否代表授权已失效、只能重新登录
    /// - Parameters:
    ///   - statusCode: HTTP 状态码
    ///   - body: 响应体文本
    static func isDeadGrant(statusCode: Int, body: String) -> Bool {
        // OpenAI 用 401 表达「refresh_token 不再有效」
        if statusCode == 401 { return true }

        // RFC 6749 §5.2：refresh_token 失效返回 400 + invalid_grant（Anthropic 走这条）
        if statusCode == 400, body.contains("invalid_grant") { return true }

        // 兜底：明说 refresh_token 已被用过的文案（OpenAI 在个别路径上返回 400）
        if body.localizedCaseInsensitiveContains("refresh token has already been used") { return true }

        return false
    }
}
