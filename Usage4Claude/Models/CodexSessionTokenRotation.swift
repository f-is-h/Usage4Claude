//
//  CodexSessionTokenRotation.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-09.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 一次待写回的 Codex session-token 轮换
///
/// chatgpt.com 在**未登录**时同样会下发一个全新的匿名 `session-token` cookie。
/// 三条刷新路径（SSR bootstrap、隐藏 WebView、session 端点）过去都只凭
/// 「token 和原来不一样」就把它写进 Keychain，于是匿名 token 覆盖掉用户的真
/// token，账号被永久登出——点一次「测试连接」即可复现，因为诊断的 SSR 探测
/// 走的正是这条路径。
///
/// 这里把「已登录」变成写回的前置条件：拿到候选值只是第一步，真正落盘要经过
/// `authorized(by:)`，而它要求交出同一次会话解出的 accessToken。没有证明就
/// 拿不到可写回的值，「先写后验」因此不再取决于三处各自记得把顺序排对。
///
/// - Note: `replacing` 是发起刷新时该账号持有的 token，用于反查账号而不是取
///   「当前账号」——刷新期间用户可能已切换账号，详见 `AccountTokenRotation`。
nonisolated struct CodexSessionTokenRotation: Equatable, Sendable {

    /// 轮换后的新 token
    let newToken: String
    /// 发起刷新时的旧 token，用于定位要更新哪个账号
    let replacing: String

    /// 构造一次待写回的轮换
    ///
    /// - Parameters:
    ///   - candidate: 从响应 cookie 里取到的 token，可能不存在
    ///   - original: 发起刷新时该账号持有的 token
    /// - Returns: 候选值缺失、为空、或与原值相同时返回 nil —— 无需写回
    static func pending(candidate: String?, replacing original: String) -> CodexSessionTokenRotation? {
        guard let candidate, !candidate.isEmpty, candidate != original else { return nil }
        return CodexSessionTokenRotation(newToken: candidate, replacing: original)
    }

    /// 用「已登录」的证明放行写回
    ///
    /// - Parameter accessToken: 同一次会话解出的 accessToken。服务端只会为已登录
    ///   会话返回它，所以它就是这次响应确实代表已登录状态的证明。
    /// - Returns: 证明有效时返回自身，否则返回 nil —— 调用方据此跳过写回
    func authorized(by accessToken: String?) -> CodexSessionTokenRotation? {
        guard let accessToken, !accessToken.isEmpty else { return nil }
        return self
    }
}
