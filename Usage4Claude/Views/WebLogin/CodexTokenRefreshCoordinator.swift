//
//  CodexTokenRefreshCoordinator.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-05-13.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

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
    /// 发起本次刷新时该账号持有的 session-token。
    /// 请求期间用户可能切换账号，因此写回时用它反查账号而不是取「当前账号」
    private var refreshingFromToken: String?

    private override init() {}

    // MARK: - Public

    /// 刷新 accessToken。成功时 Result.success 携带新鲜的 accessToken 字符串。
    func refresh(completion: @escaping (Result<String, Error>) -> Void) {
        guard !isRefreshing else {
            AppLog.trace(.auth, "SSR token refresh already in progress; skipping this request")
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
        self.refreshingFromToken = sessionToken

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

        AppLog.event(.auth, "SSR token refresh: requesting chatgpt.com to trigger a server-side OAuth refresh")

        let task = urlSession?.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                AppLog.error(.auth, "SSR token refresh request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self.finish(result: .failure(error)) }
                return
            }

            if let http = response as? HTTPURLResponse {
                AppLog.event(.auth, "SSR token refresh response received: HTTP \(http.statusCode)")
                // Phase 0 诊断：记录 Set-Cookie 响应头，确认服务端是否续期 session-token
                let setCookieHeaders = http.allHeaderFields
                    .filter { ($0.key as? String)?.lowercased() == "set-cookie" }
                    .compactMap { $0.value as? String }
                // 只记 cookie 名，不记值：名字足以说明服务端下发了什么，而值一旦
                // 截断就会误导——allHeaderFields 会把多个 Set-Cookie 合并成一个
                // 逗号连接的串，截前 80 字符只能看到第一个 cookie，却让整串的
                // 「含 session-token」判断看起来像是在描述那一个。
                let cookieNames = setCookieHeaders
                    .flatMap { Self.cookieNames(inCombinedSetCookieHeader: $0) }
                AppLog.trace(.auth, "SSR token refresh set cookies: \(cookieNames.isEmpty ? "none" : cookieNames.joined(separator: ", "))")

                guard (200...299).contains(http.statusCode) else {
                    let err: Error = http.statusCode == 403
                        ? UsageError.cloudflareBlocked
                        : UsageError.httpError(statusCode: http.statusCode)
                    DispatchQueue.main.async { self.finish(result: .failure(err)) }
                    return
                }
            }

            // Level 1：登记 HTTPCookieStorage 里收到的新 session-token。
            // 只登记不写回——未登录时 chatgpt.com 同样会下发一个全新的匿名 token，
            // 写回要等下面从 bootstrap 解出 accessToken、证明会话已登录之后。
            // 与发起刷新时捕获的 token 比较：期间用户可能已切换账号，
            // 取「当前账号」会把本账号的新 token 写进别人的条目。
            let chatgptURL = URL(string: "https://chatgpt.com")!
            let storedCookies = HTTPCookieStorage.shared.cookies(for: chatgptURL) ?? []
            let pendingRotation = CodexSessionTokenRotation.pending(
                candidate: CodexWebLoginCoordinator.extractSessionToken(from: storedCookies),
                replacing: self.refreshingFromToken ?? ""
            )

            guard let data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                AppLog.error(.auth, "SSR token refresh response could not be decoded as text")
                DispatchQueue.main.async { self.finish(result: .failure(UsageError.noData)) }
                return
            }

            AppLog.trace(.auth, "SSR token refresh received \(html.count) bytes of HTML")

            if html.contains("Just a moment") || html.contains("cf-browser-verification") {
                AppLog.error(.auth, "SSR token refresh was served a Cloudflare challenge page")
                DispatchQueue.main.async { self.finish(result: .failure(UsageError.cloudflareBlocked)) }
                return
            }

            let result = Self.extractBootstrapAccessToken(from: html)

            DispatchQueue.main.async {
                // bootstrap 解出 accessToken 即证明这次响应代表已登录会话，
                // 轮换到这一步才允许落盘（未登录的响应会走 failure 分支，写回被丢弃）
                if let rotation = pendingRotation?.authorized(by: try? result.get()) {
                    AppLog.event(.auth, "SSR token refresh rotated the session-token on an authenticated session; writing it back")
                    UserSettings.shared.silentlyUpdateCodexSessionToken(rotation.newToken, replacing: rotation.replacing)
                }
                self.finish(result: result)
            }
        }
        dataTask = task
        task?.resume()
    }

    // MARK: - Private

    private static func extractBootstrapAccessToken(from html: String) -> Result<String, Error> {
        guard let idRange = html.range(of: "id=\"client-bootstrap\"") else {
            AppLog.error(.auth, "SSR token refresh could not find the client-bootstrap element in the HTML")
            return .failure(UsageError.sessionExpired)
        }

        guard let gtRange = html.range(of: ">", range: idRange.upperBound..<html.endIndex),
              let jsonStart = html.range(of: "{", range: gtRange.upperBound..<html.endIndex) else {
            AppLog.error(.auth, "SSR token refresh could not locate the start of the client-bootstrap JSON")
            return .failure(UsageError.sessionExpired)
        }

        guard let scriptEnd = html.range(of: "</script>", range: jsonStart.lowerBound..<html.endIndex) else {
            AppLog.error(.auth, "SSR token refresh could not locate the client-bootstrap closing tag")
            return .failure(UsageError.sessionExpired)
        }

        let jsonString = String(html[jsonStart.lowerBound..<scriptEnd.lowerBound])

        guard let jsonData = jsonString.data(using: .utf8),
              let bootstrap = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            AppLog.error(.auth, "SSR token refresh could not parse the client-bootstrap JSON")
            return .failure(UsageError.decodingError)
        }

        let authStatus = bootstrap["authStatus"] as? String ?? "unknown"
        guard let session = bootstrap["session"] as? [String: Any],
              let accessToken = session["accessToken"] as? String,
              !accessToken.isEmpty else {
            AppLog.error(.auth, "SSR token refresh bootstrap carried no accessToken (authStatus=\(authStatus))")
            return .failure(UsageError.sessionExpired)
        }

        if let exp = jwtExpiry(from: accessToken), exp < Date() {
            AppLog.error(.auth, "SSR token refresh returned an accessToken that is already expired (exp=\(exp))")
            return .failure(UsageError.sessionExpired)
        }

        AppLog.event(.auth, "SSR token refresh succeeded and returned a fresh accessToken (authStatus=\(authStatus))")
        return .success(accessToken)
    }

    /// 从（可能被 URLSession 合并过的）Set-Cookie 头里取出所有 cookie 名
    ///
    /// `HTTPURLResponse.allHeaderFields` 会把多条 Set-Cookie 合并成一个逗号连接的
    /// 字符串，所以不能按整串判断「这是哪个 cookie」。这里只提取名字，值不进日志。
    static func cookieNames(inCombinedSetCookieHeader header: String) -> [String] {
        // cookie 名出现在串首，或某个 ", " 之后，形如 `name=value`
        let pattern = "(?:^|,\\s*)([A-Za-z0-9_.\\-]+)="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(header.startIndex..., in: header)
        return regex.matches(in: header, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: header) else { return nil }
            return String(header[r])
        }
    }

    private func finish(result: Result<String, Error>) {
        isRefreshing = false
        dataTask = nil
        urlSession = nil
        refreshingFromToken = nil
        let cb = completion
        completion = nil
        cb?(result)
    }
}
