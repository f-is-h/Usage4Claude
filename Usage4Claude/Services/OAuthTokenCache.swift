//
//  OAuthTokenCache.swift
//  Usage4Claude
//
//  审计报告 4.2：OAuth access_token 的缓存 + 单飞合并，用 actor 替代手写
//  NSLock + 等待者数组。actor 方法天然串行化：并发调用者在 await 挂起点让出
//  执行权，后到者发现 refreshTask 已存在就直接复用同一个 Task，无需手动维护
//  等待者列表或操心「忘记唤醒某个等待者」这类问题。
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 单个 Provider 的 OAuth access_token 缓存 + 单飞刷新
actor OAuthTokenCache {
    /// 一次刷新换到的结果（不同 Provider 的响应结构不同，调用方在 refresh 闭包里统一成这个形状）
    struct Tokens {
        let accessToken: String
        /// 刷新端点可能不轮换 refresh_token（返回空字符串时应视为沿用旧值，由调用方在闭包里处理好）
        let refreshToken: String
        let expiresAt: Date
    }

    private var cachedAccessToken: String?
    private var cachedExpiry: Date?
    private var cachedForRefreshToken: String?

    private var refreshTask: Task<Tokens, Error>?
    private var refreshTaskToken: String?

    /// 获取有效的 access_token：命中缓存直接返回；否则发起刷新，
    /// 同一 refresh_token 的并发调用自动复用同一次网络请求的结果。
    /// - Parameters:
    ///   - refreshToken: 当前 refresh_token
    ///   - margin: 提前刷新余量，避免用到临期 token（默认 5 分钟）
    ///   - refresh: 实际发起网络刷新的闭包，返回新的 token 三元组
    func accessToken(
        refreshToken: String,
        margin: TimeInterval = 5 * 60,
        refresh: @escaping (String) async throws -> Tokens
    ) async throws -> String {
        if let cached = cachedAccessToken, !cached.isEmpty,
           let expiry = cachedExpiry,
           cachedForRefreshToken == refreshToken,
           expiry > Date().addingTimeInterval(margin) {
            return cached
        }

        // 同一 refresh_token 已有刷新在进行中：直接复用同一个 Task 的结果
        if let task = refreshTask, refreshTaskToken == refreshToken {
            return try await task.value.accessToken
        }

        let task = Task<Tokens, Error> {
            try await refresh(refreshToken)
        }
        refreshTask = task
        refreshTaskToken = refreshToken

        defer {
            // 避免把已完成（成功或失败）的旧 Task 留在原地，导致下次误判为"仍在进行中"
            if refreshTaskToken == refreshToken {
                refreshTask = nil
                refreshTaskToken = nil
            }
        }

        let tokens = try await task.value
        cachedAccessToken = tokens.accessToken
        cachedExpiry = tokens.expiresAt
        cachedForRefreshToken = tokens.refreshToken
        return tokens.accessToken
    }

    /// 清除缓存（账户切换或收到 401 时调用，强制下次重新走网络刷新）
    func clear() {
        cachedAccessToken = nil
        cachedExpiry = nil
        cachedForRefreshToken = nil
    }
}
