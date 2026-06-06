//
//  CodexTokenRefreshCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-05-13.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// Codex session token 静默刷新协调器
/// 通过 URLSession GET chatgpt.com，触发服务端 SSR OAuth refresh，
/// 从 client-bootstrap JSON 读取服务端新生成的 accessToken。
///
/// 为什么用 SSR 而不是 /api/auth/session：
///   - GET /api/auth/session 只返回 JWE 中缓存的 accessToken，不触发 OAuth refresh
///   - SSR 渲染时服务端中间件会检测 accessToken 是否过期，并用 JWE 中的 refresh token 刷新
///   - 成功条件：JWE 中的 OAuth refresh token 尚未过期（通常比 accessToken 有效期更长）
@MainActor
final class CodexTokenRefreshCoordinator: NSObject {

    static let shared = CodexTokenRefreshCoordinator()

    private(set) var isRefreshing = false

    private var dataTask: URLSessionDataTask?
    private var urlSession: URLSession?
    private var completion: ((Result<String, Error>) -> Void)?

    private override init() {}

    // MARK: - Public

    /// 刷新 accessToken。成功时 Result.success 携带新鲜的 accessToken 字符串。
    func refresh(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isRefreshing else {
            Logger.settings.debug("CodexTokenRefresh: 刷新已在进行中，跳过")
            completion(.failure(UsageError.networkError))
            return
        }

        let sessionToken = UserSettings.shared.codexSessionToken
        guard !sessionToken.isEmpty else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        isRefreshing = true
        self.completion = completion

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        urlSession = URLSession(configuration: config)

        guard let url = URL(string: "https://chatgpt.com") else {
            finish(result: .failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        // 使用与 /api/auth/session 端点相同的请求头（已证明能通过 Cloudflare）
        let sessionHeaders = CodexAPIHeaderBuilder.buildSessionHeaders(sessionToken: sessionToken)
        for (key, value) in sessionHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        // 覆盖为 HTML 页面对应的 Fetch 模式
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "accept")
        request.setValue("navigate", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("document", forHTTPHeaderField: "sec-fetch-dest")

        Logger.settings.info("CodexTokenRefresh: URLSession GET chatgpt.com 触发 SSR OAuth refresh")

        let task = urlSession?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                Logger.settings.error("CodexTokenRefresh: 请求失败 - \(error.localizedDescription)")
                DispatchQueue.main.async { self.finish(result: .failure(error)) }
                return
            }

            if let http = response as? HTTPURLResponse {
                Logger.settings.debug("CodexTokenRefresh: HTTP \(http.statusCode)")
                // Phase 0 诊断：记录 Set-Cookie 响应头，确认服务端是否续期 session-token
                let setCookieHeaders = http.allHeaderFields
                    .filter { ($0.key as? String)?.lowercased() == "set-cookie" }
                    .compactMap { $0.value as? String }
                Logger.settings.debug("CodexTokenRefresh: Set-Cookie 响应头数量=\(setCookieHeaders.count)")
                for cookieStr in setCookieHeaders {
                    let isSessionToken = cookieStr.contains("next-auth.session-token")
                    Logger.settings.info("CodexTokenRefresh: Set-Cookie [\(isSessionToken ? "SESSION-TOKEN" : "other")] \(cookieStr.prefix(80))")
                }

                guard (200...299).contains(http.statusCode) else {
                    let err: Error = http.statusCode == 403
                        ? UsageError.cloudflareBlocked
                        : UsageError.httpError(statusCode: http.statusCode)
                    DispatchQueue.main.async { self.finish(result: .failure(err)) }
                    return
                }
            }

            // Level 1：检查 HTTPCookieStorage 是否收到新的 session-token
            let chatgptURL = URL(string: "https://chatgpt.com")!
            let storedCookies = HTTPCookieStorage.shared.cookies(for: chatgptURL) ?? []
            if let newToken = CodexWebLoginCoordinator.extractSessionToken(from: storedCookies) {
                let currentToken = UserSettings.shared.codexSessionToken
                if newToken != currentToken {
                    Logger.settings.notice("CodexTokenRefresh: URLSession 检测到新 session-token，静默写回")
                    DispatchQueue.main.async {
                        UserSettings.shared.silentlyUpdateCurrentCodexSessionToken(newToken)
                    }
                } else {
                    Logger.settings.debug("CodexTokenRefresh: session-token 未变化")
                }
            }

            guard let data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                Logger.settings.error("CodexTokenRefresh: 响应无法解码")
                DispatchQueue.main.async { self.finish(result: .failure(UsageError.noData)) }
                return
            }

            Logger.settings.debug("CodexTokenRefresh: 收到 HTML 响应 \(html.count) 字节")

            if html.contains("Just a moment") || html.contains("cf-browser-verification") {
                Logger.settings.error("CodexTokenRefresh: Cloudflare 挑战页")
                DispatchQueue.main.async { self.finish(result: .failure(UsageError.cloudflareBlocked)) }
                return
            }

            let result = Self.extractBootstrapAccessToken(from: html)
            DispatchQueue.main.async { self.finish(result: result) }
        }
        dataTask = task
        task?.resume()
    }

    // MARK: - Private

    private static func extractBootstrapAccessToken(from html: String) -> Result<String, Error> {
        guard let idRange = html.range(of: "id=\"client-bootstrap\"") else {
            Logger.settings.error("CodexTokenRefresh: HTML 中未找到 client-bootstrap 元素")
            return .failure(UsageError.sessionExpired)
        }

        guard let gtRange = html.range(of: ">", range: idRange.upperBound..<html.endIndex),
              let jsonStart = html.range(of: "{", range: gtRange.upperBound..<html.endIndex) else {
            Logger.settings.error("CodexTokenRefresh: 无法定位 client-bootstrap JSON 起点")
            return .failure(UsageError.sessionExpired)
        }

        guard let scriptEnd = html.range(of: "</script>", range: jsonStart.lowerBound..<html.endIndex) else {
            Logger.settings.error("CodexTokenRefresh: 无法定位 client-bootstrap 结束标签")
            return .failure(UsageError.sessionExpired)
        }

        let jsonString = String(html[jsonStart.lowerBound..<scriptEnd.lowerBound])

        guard let jsonData = jsonString.data(using: .utf8),
              let bootstrap = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Logger.settings.error("CodexTokenRefresh: client-bootstrap JSON 解析失败")
            return .failure(UsageError.decodingError)
        }

        let authStatus = bootstrap["authStatus"] as? String ?? "unknown"
        guard let session = bootstrap["session"] as? [String: Any],
              let accessToken = session["accessToken"] as? String,
              !accessToken.isEmpty else {
            Logger.settings.error("CodexTokenRefresh: bootstrap 无 accessToken (authStatus=\(authStatus))")
            return .failure(UsageError.sessionExpired)
        }

        if let exp = jwtExpiry(from: accessToken), exp < Date() {
            Logger.settings.error("CodexTokenRefresh: bootstrap accessToken 仍已过期 exp=\(exp)")
            return .failure(UsageError.sessionExpired)
        }

        Logger.settings.info("CodexTokenRefresh: SSR 成功返回新鲜 accessToken (authStatus=\(authStatus))")
        return .success(accessToken)
    }

    private func finish(result: Result<String, Error>) {
        isRefreshing = false
        dataTask = nil
        urlSession = nil
        let cb = completion
        completion = nil
        cb?(result)
    }
}
