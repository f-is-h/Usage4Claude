//
//  CodexAPIService.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// Codex API 服务类
/// 两步认证流程：
///   1. GET /api/auth/session（用 session-token Cookie）→ 获取 accessToken
///   2. GET /backend-api/wham/usage（用 Bearer token）→ 获取用量数据
class CodexAPIService {
    // MARK: - Properties

    /// 一次性校验与诊断场景复用的共享实例。
    ///
    /// 与 `ClaudeAPIService.shared` 同理：OAuth token 的单飞与轮换写回都挂在实例的
    /// `OAuthTokenCache` 上，短生命周期的局部实例会绕开它们。诊断尤其不能另起炉灶——
    /// refresh_token 每次续期都会轮换，换回来的新值若不经服务层写回就等于把账号登出。
    static let shared = CodexAPIService()


    // MARK: - Properties

    private let baseURL = "https://chatgpt.com"
    private let settings = UserSettings.shared
    private let session: URLSession

    /// 当前进行中的任务（最多两个：session + usage）
    /// - Note: append 发生在主线程（session 请求发起）和 URLSession 回调线程（usage 请求发起，
    ///   由 fetchAccessToken 的 completion 触发）两处，cancelAllRequests 在主线程清空，
    ///   并发读写需靠 tasksLock 保护（见 trackTask/cancelAllRequests）。
    private var activeTasks: [URLSessionDataTask] = []

    /// 保护 activeTasks 的锁
    private let tasksLock = NSLock()

    // MARK: - Access Token Cache

    /// 主动刷新窗口：距过期不足20分钟时触发重新拉取
    /// 设为最大刷新间隔(15min) + 5min buffer，确保任意间隔下都能主动刷新而不依赖三级链兜底
    private static let tokenRefreshMargin: TimeInterval = 20 * 60

    /// access_token 缓存 + 单飞合并（actor，见 Services/OAuthTokenCache.swift；审计报告 4.2）。
    /// cookie session 路径与 OAuth refresh 路径共用：缓存键为账户凭据
    /// （session-token 或 "rt." 前缀的 OAuth refresh_token），互不串扰。
    private let tokenCache = OAuthTokenCache()

    /// 线程安全地记录进行中的任务，供 cancelAllRequests 统一取消
    private func trackTask(_ task: URLSessionDataTask) {
        tasksLock.lock()
        activeTasks.append(task)
        tasksLock.unlock()
    }

    /// 账户切换时清除缓存，确保下次立即重新拉取
    /// - Note: 异步生效。401 路径的清缓存在 fetchWhamUsage 内部完成（保证先于错误传播），
    ///   账户切换场景则依赖缓存按凭据键控——旧账户的缓存不会误配新账户的凭据。
    func clearAccessTokenCache() {
        Task { await tokenCache.clear() }
    }

    /// 由独立计时器调用：仅在缓存即将过期时主动续期，不触发用量拉取。
    /// fetchAccessToken 内部先查缓存（20 分钟余量），缓存仍新鲜时不会发起网络请求。
    func proactivelyRefreshIfNeeded() {
        guard settings.hasValidCodexCredentials else { return }
        fetchAccessToken(sessionToken: settings.codexSessionToken) { result in
            switch result {
            case .success:
                AppLog.trace(.auth, "Codex accessToken proactive renewal check finished")
            case .failure(let error):
                AppLog.warning(.auth, "Codex accessToken proactive renewal failed (\(error.localizedDescription)); will retry when usage is next fetched")
            }
        }
    }

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// 获取 Codex 用量（两步：session → usage）
    /// - Parameter completion: 成功返回 CodexUsageData，失败返回 Error
    func fetchUsage(completion: @escaping (Result<CodexUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            let mockData = createMockData()
            DispatchQueue.main.async { completion(.success(mockData)) }
            return
        }
        #endif

        cancelAllRequests()

        guard settings.hasValidCodexCredentials else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        let sessionToken = settings.codexSessionToken

        // fetchAccessToken 的 completion 已保证主线程回调
        fetchAccessToken(sessionToken: sessionToken) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let accessToken):
                self.fetchWhamUsage(accessToken: accessToken) { usageResult in
                    DispatchQueue.main.async { completion(usageResult) }
                }
            }
        }
    }

    // MARK: - Private: Step 1 — 凭据 → accessToken

    /// 判断账户凭据是否为 OAuth refresh_token
    ///
    /// 判定规则收在 `ProviderAuthPath`，诊断层与此共用同一处，避免两边脱钩
    static func isOAuthRefreshToken(_ credential: String) -> Bool {
        ProviderAuthPath.forCodex(credential: credential) == .oauth
    }

    /// 第一步：用账户凭据换取 accessToken
    /// - cookie 账户：GET /api/auth/session（session-token Cookie）
    /// - OAuth 账户（"rt." 前缀）：向 auth.openai.com 用 refresh_token 换取
    ///
    /// 缓存有效时（距过期 > 20 分钟）跳过网络请求；同一凭据的并发调用由
    /// OAuthTokenCache 合并为一次网络请求。completion 一律主线程回调。
    private func fetchAccessToken(sessionToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let accessToken = try await tokenCache.accessToken(
                    refreshToken: sessionToken,
                    margin: Self.tokenRefreshMargin
                ) { [weak self] credential in
                    guard let self else { throw UsageError.networkError }
                    if Self.isOAuthRefreshToken(credential) {
                        return try await self.refreshOAuthTokens(refreshToken: credential)
                    }
                    return try await self.fetchSessionTokens(sessionToken: credential)
                }
                await MainActor.run { completion(.success(accessToken)) }
            } catch {
                // 刷新失败回退：旧 token 尚未真正过期（哪怕已进入提前刷新窗口）时顶用一轮，
                // 避免网络瞬断/服务端抖动影响用量拉取。凭据失效类错误不回退——
                // 必须让 401 传播出去触发三级刷新链 / 重新登录提示。
                switch error {
                case UsageError.unauthorized, UsageError.sessionExpired:
                    break
                default:
                    if let fallback = await tokenCache.validCachedToken(refreshToken: sessionToken) {
                        AppLog.warning(.auth, "Codex token refresh failed (\(error.localizedDescription)); falling back to the cached token that has not expired yet")
                        await MainActor.run { completion(.success(fallback)) }
                        return
                    }
                }
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    /// cookie 账户：调用 /api/auth/session 换取 accessToken，返回统一的 Tokens 三元组。
    /// 若响应通过 Set-Cookie 轮换了 session-token，静默写回账户存储，并把新值作为
    /// 返回的 refreshToken——缓存键跟随新凭据，下次用新 session-token 查询可直接命中。
    private func fetchSessionTokens(sessionToken: String) async throws -> OAuthTokenCache.Tokens {
        guard let url = URL(string: "\(baseURL)/api/auth/session") else {
            throw UsageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                let result: Result<OAuthTokenCache.Tokens, Error> = {
                    if let error {
                        AppLog.error(.api, "Codex session request failed with a network error: \(error.localizedDescription)")
                        return .failure(UsageError.networkError)
                    }
                    guard let data else { return .failure(UsageError.noData) }

                    AppLog.trace(.api, "Codex session response received: \(data.count) bytes")
                    if let jsonString = String(data: data, encoding: .utf8),
                       jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                        return .failure(UsageError.cloudflareBlocked)
                    }

                    if let httpResponse = response as? HTTPURLResponse {
                        AppLog.event(.api, "Codex session response received: HTTP \(httpResponse.statusCode)")
                        // Phase 0 诊断：检查 /api/auth/session 是否下发新 session-token
                        let setCookieHeaders = httpResponse.allHeaderFields
                            .filter { ($0.key as? String)?.lowercased() == "set-cookie" }
                            .compactMap { $0.value as? String }
                        AppLog.trace(.auth, "Codex session returned \(setCookieHeaders.count) Set-Cookie header(s)")
                        for cookieStr in setCookieHeaders where cookieStr.contains("next-auth.session-token") {
                            AppLog.trace(.auth, "Codex session returned a new session-token cookie: \(cookieStr.prefix(80))")
                        }

                        switch httpResponse.statusCode {
                        case 200...299: break
                        case 401: return .failure(UsageError.unauthorized)
                        case 403: return .failure(UsageError.cloudflareBlocked)
                        case 429: return .failure(UsageError.rateLimited)
                        default:
                            return .failure(UsageError.httpError(statusCode: httpResponse.statusCode))
                        }
                    }

                    // 检查 HTTPCookieStorage 是否收到轮换后的新 session-token。
                    // 只是「登记」，写回要等下面解出 accessToken 之后——未登录时服务端
                    // 同样会下发一个全新的匿名 token，先写就会覆盖掉用户的真 token。
                    // （用已捕获的 sessionToken 参数比较，避免在后台线程读取 @Published 属性）
                    let chatgptURL = URL(string: "https://chatgpt.com")!
                    let storedCookies = HTTPCookieStorage.shared.cookies(for: chatgptURL) ?? []
                    let pendingRotation = CodexSessionTokenRotation.pending(
                        candidate: CodexWebLoginCoordinator.extractSessionToken(from: storedCookies),
                        replacing: sessionToken
                    )

                    do {
                        let sessionResponse = try JSONDecoder().decode(CodexSessionResponse.self, from: data)
                        guard let accessToken = sessionResponse.accessToken, !accessToken.isEmpty else {
                            AppLog.error(.auth, "Codex session response carried no accessToken — the session token has expired or the user is signed out")
                            return .failure(UsageError.sessionExpired)
                        }

                        // 到这里才证明会话确实已登录，轮换可以落盘
                        var effectiveSessionToken = sessionToken
                        if let rotation = pendingRotation?.authorized(by: accessToken) {
                            AppLog.event(.auth, "Codex session-token rotated on an authenticated session; writing the new token back to the account")
                            effectiveSessionToken = rotation.newToken
                            DispatchQueue.main.async {
                                // 用捕获的 sessionToken 反查账号，与上面的比较保持同一基准：
                                // 请求期间用户可能切换账号，写「当前账号」会污染别人的凭据
                                UserSettings.shared.silentlyUpdateCodexSessionToken(rotation.newToken, replacing: rotation.replacing)
                            }
                        }
                        let exp = jwtExpiry(from: accessToken)
                        if let exp {
                            AppLog.event(.auth, "Codex accessToken expires at \(exp), in \(Int(exp.timeIntervalSinceNow / 60)) min")
                        } else {
                            AppLog.warning(.auth, "Codex accessToken has no readable exp claim; caching it for 30 minutes")
                        }
                        return .success(OAuthTokenCache.Tokens(
                            accessToken: accessToken,
                            refreshToken: effectiveSessionToken,
                            expiresAt: exp ?? Date().addingTimeInterval(30 * 60)
                        ))
                    } catch {
                        AppLog.error(.api, "Codex session response could not be decoded: \(error.localizedDescription)")
                        return .failure(UsageError.decodingError)
                    }
                }()
                continuation.resume(with: result)
            }

            trackTask(task)
            task.resume()
        }
    }

    /// OAuth 账户：用 refresh_token 向 auth.openai.com 换取 access_token。
    /// 只会在 OAuthTokenCache 判定「确实需要发起新刷新」时被调用一次（并发调用共享同一次结果）。
    /// refresh_token 轮换时静默写回账户存储，并作为返回的 refreshToken（缓存键跟随新值）。
    private func refreshOAuthTokens(refreshToken: String) async throws -> OAuthTokenCache.Tokens {
        let tokens = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CodexOAuthTokens, Error>) in
            CodexOAuthService.refresh(refreshToken: refreshToken) { result in
                continuation.resume(with: result)
            }
        }

        let newRefresh = tokens.refreshToken.isEmpty ? refreshToken : tokens.refreshToken
        if newRefresh != refreshToken {
            AppLog.event(.auth, "Codex OAuth refresh_token rotated; writing the new token back to the account")
            await MainActor.run {
                // 用 refreshToken（发起本次刷新时的旧值）反查账号，理由同 Claude 侧
                UserSettings.shared.silentlyUpdateCodexSessionToken(newRefresh, replacing: refreshToken)
            }
        }

        return OAuthTokenCache.Tokens(
            accessToken: tokens.accessToken,
            refreshToken: newRefresh,
            expiresAt: jwtExpiry(from: tokens.accessToken) ?? Date().addingTimeInterval(30 * 60)
        )
    }

    /// 跳过 session 步骤，直接用已获取的 accessToken 查询用量（用于刷新后重试）
    func fetchUsageWithAccessToken(_ accessToken: String, completion: @escaping (Result<CodexUsageData, Error>) -> Void) {
        fetchWhamUsage(accessToken: accessToken) { result in
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Async 包装

    /// `fetchUsage(completion:)` 的 async 包装，供结构化并发调用方使用。
    /// 结果用 Result 表达而非 throws，与 completion 版本的错误语义保持一致。
    func fetchUsageResult() async -> Result<CodexUsageData, Error> {
        await withCheckedContinuation { continuation in
            fetchUsage { continuation.resume(returning: $0) }
        }
    }

    // MARK: - Private: Step 2 — accessToken → usage

    /// 第二步：用 Bearer accessToken 查询用量
    private func fetchWhamUsage(accessToken: String, completion: @escaping (Result<CodexUsageData, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/backend-api/wham/usage") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applyUsageHeaders(to: &request, accessToken: accessToken)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLog.error(.api, "Codex usage request failed with a network error: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }

            guard let data = data else {
                completion(.failure(UsageError.noData))
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                AppLog.trace(.api, "Codex usage response received: \(data.count) bytes")
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                }
            }

            if let httpResponse = response as? HTTPURLResponse {
                AppLog.event(.api, "Codex usage response received: HTTP \(httpResponse.statusCode)")
                switch httpResponse.statusCode {
                case 200...299: break
                case 401:
                    // 缓存的 accessToken 已失效。await 清缓存后再传播错误，
                    // 保证调用方收到 unauthorized 后立即发起的重试不会再命中这枚坏 token
                    Task { [weak self] in
                        await self?.tokenCache.clear()
                        completion(.failure(UsageError.unauthorized))
                    }
                    return
                case 403: completion(.failure(UsageError.cloudflareBlocked)); return
                case 429: completion(.failure(UsageError.rateLimited)); return
                default:
                    completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    return
                }
            }

            let decoder = JSONDecoder()
            do {
                let usageResponse = try decoder.decode(CodexUsageResponse.self, from: data)
                let usageData = usageResponse.toCodexUsageData()
                completion(.success(usageData))
            } catch {
                AppLog.error(.api, "Codex usage response could not be decoded: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }

        trackTask(task)
        task.resume()
    }

    // MARK: - Validation (used by WebLoginCoordinator)

    /// 验证 session token 并返回账户信息（用于 WebLogin 流程）
    /// - Parameters:
    ///   - sessionToken: __Secure-next-auth.session-token 值
    ///   - completion: 成功返回 (email, displayName)，失败返回 Error
    func validateSessionToken(_ sessionToken: String, cookieHeader: String, completion: @escaping (Result<CodexSessionValidation, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/session") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)
        // 使用 WebView 的完整 Cookie header，确保 Cloudflare 相关 Cookie 一并携带
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async { completion(.failure(UsageError.networkError)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(UsageError.noData)) }
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                AppLog.trace(.auth, "Codex session validation response received: \(data.count) bytes")
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    DispatchQueue.main.async { completion(.failure(UsageError.cloudflareBlocked)) }
                    return
                }
            }

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299: break
                case 401:
                    DispatchQueue.main.async { completion(.failure(UsageError.unauthorized)) }
                    return
                case 403:
                    DispatchQueue.main.async { completion(.failure(UsageError.cloudflareBlocked)) }
                    return
                default:
                    DispatchQueue.main.async {
                        completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    }
                    return
                }
            }

            let decoder = JSONDecoder()
            do {
                let sessionResponse = try decoder.decode(CodexSessionResponse.self, from: data)
                guard let accessToken = sessionResponse.accessToken, !accessToken.isEmpty else {
                    DispatchQueue.main.async { completion(.failure(UsageError.sessionExpired)) }
                    return
                }
                // session-token 是 JWE 无法本地解密，但内部 accessToken 是普通 JWT
                // 若 accessToken 已过期，说明 OAuth refresh token 也失效，拒绝此 session
                if let exp = jwtExpiry(from: accessToken), exp < Date() {
                    AppLog.warning(.auth, "Codex session validation rejected the login: the accessToken had already expired at \(exp)")
                    DispatchQueue.main.async { completion(.failure(UsageError.sessionExpired)) }
                    return
                }
                let email = sessionResponse.user?.email ?? ""
                let name = sessionResponse.user?.name ?? email
                let displayName = name.isEmpty ? "Codex" : name
                DispatchQueue.main.async {
                    completion(.success(CodexSessionValidation(
                        email: email, displayName: displayName, accessToken: accessToken
                    )))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }

        trackTask(task)
        task.resume()
    }

    // MARK: - Debug Mock Data

    #if DEBUG
    private func createMockData() -> CodexUsageData {
        let primaryResetAt = Date().addingTimeInterval(3600 * 2.5)
        let secondaryResetAt = Date().addingTimeInterval(3600 * 24 * 3.2)
        let extraPercentage = Double(settings.debugCodexExtraUsagePercentage)
        let debugCreditLimit = Decimal(1000)
        let remainingRatio = max(0, (100 - extraPercentage) / 100.0)
        let balance = debugCreditLimit * Decimal(remainingRatio)
        let balanceValue = balance.doubleValue

        return CodexUsageData(
            primary: .init(percentage: Double(settings.debugCodexPrimaryPercentage), resetsAt: primaryResetAt),
            secondary: .init(percentage: Double(settings.debugCodexSecondaryPercentage), resetsAt: secondaryResetAt),
            extraUsage: CodexExtraUsageData(
                hasCredits: true,
                unlimited: false,
                overageLimitReached: extraPercentage >= 100,
                spendControlReached: false,
                balance: balance,
                approxLocalMessages: [Int(balanceValue / 14), Int(balanceValue / 2)],
                approxCloudMessages: [Int(balanceValue / 34), Int(balanceValue / 25)],
                visualPercentage: extraPercentage
            )
        )
    }
    #endif
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

// MARK: - UsageProvider

extension CodexAPIService: UsageProvider {
    var providerType: ProviderType { .codex }

    func cancelAllRequests() {
        tasksLock.lock()
        let tasks = activeTasks
        activeTasks.removeAll()
        tasksLock.unlock()
        tasks.forEach { $0.cancel() }
        AppLog.event(.api, "Cancelled all in-flight Codex network requests")
    }
}
