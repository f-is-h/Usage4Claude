//
//  CodexAPIService.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-24.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import OSLog

/// Codex API 服务类
/// 两步认证流程：
///   1. GET /api/auth/session（用 session-token Cookie）→ 获取 accessToken
///   2. GET /backend-api/wham/usage（用 Bearer token）→ 获取用量数据
class CodexAPIService {

    // MARK: - Properties

    private let baseURL = "https://chatgpt.com"
    private let settings = UserSettings.shared
    private let session: URLSession

    /// 当前进行中的任务（最多两个：session + usage）
    private var activeTasks: [URLSessionDataTask] = []

    // MARK: - Access Token Cache

    private var cachedAccessToken: String?
    private var cachedAccessTokenExpiry: Date?
    private var cachedForSessionToken: String?
    /// 主动刷新窗口：距过期不足20分钟时触发重新拉取
    /// 设为最大刷新间隔(15min) + 5min buffer，确保任意间隔下都能主动刷新而不依赖三级链兜底
    private static let tokenRefreshMargin: TimeInterval = 20 * 60

    /// 保护缓存三属性的锁：主线程读（计时器/fetchAccessToken 入口），URLSession 后台线程写
    private let cacheLock = NSLock()

    // MARK: - OAuth refresh 单飞（in-flight 合并）

    /// OAuth refresh_token 是一次性的（每次刷新都会轮换、旧值立即作废）。
    /// 多个计时器可能并发用同一 refresh_token 发起刷新，导致后到者用已作废的 token 被服务端拒绝。
    /// 这里做单飞合并：同一 refresh_token 的刷新进行中时，后续调用挂入等待队列复用其结果。
    /// 复用 cacheLock 保护以下三个属性。
    private var oauthRefreshInFlight = false
    private var oauthRefreshInFlightToken: String?
    private var oauthRefreshWaiters: [(Result<String, Error>) -> Void] = []

    /// 缓存是否在刷新窗口外（剩余 > 20 分钟）。调用方必须在主线程。
    private var hasCachedValidToken: Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let token = cachedAccessToken, !token.isEmpty,
              let expiry = cachedAccessTokenExpiry,
              let forToken = cachedForSessionToken else { return false }
        return forToken == settings.codexSessionToken
            && expiry > Date().addingTimeInterval(Self.tokenRefreshMargin)
    }

    /// 缓存 token 是否尚未过期（即使已进入主动刷新窗口）。可在任意线程调用。
    private func cachedTokenFallback(for sessionToken: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let token = cachedAccessToken, !token.isEmpty,
              let expiry = cachedAccessTokenExpiry,
              cachedForSessionToken == sessionToken,
              expiry > Date() else { return nil }
        return token
    }

    /// 账户切换或 401 时清除缓存，确保下次立即重新拉取
    func clearAccessTokenCache() {
        cacheLock.lock()
        cachedAccessToken = nil
        cachedAccessTokenExpiry = nil
        cachedForSessionToken = nil
        cacheLock.unlock()
    }

    /// 由独立计时器调用：仅在缓存即将过期时主动调用 session API 续期，不触发用量拉取
    func proactivelyRefreshIfNeeded() {
        guard settings.hasValidCodexCredentials, !hasCachedValidToken else { return }
        let sessionToken = settings.codexSessionToken
        fetchAccessToken(sessionToken: sessionToken) { result in
            switch result {
            case .success:
                Logger.api.notice("Codex accessToken: 独立计时器主动续期成功")
            case .failure(let error):
                Logger.api.warning("Codex accessToken: 主动续期失败（\(error.localizedDescription)），用量拉取时再试")
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

        fetchAccessToken(sessionToken: sessionToken) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }

            case .success(let accessToken):
                self.fetchWhamUsage(accessToken: accessToken) { usageResult in
                    DispatchQueue.main.async { completion(usageResult) }
                }
            }
        }
    }

    // MARK: - Private: Step 1 — Session → accessToken

    /// 第一步：用 session-token Cookie 换取 accessToken
    /// 缓存有效时（距过期 > 5 分钟）跳过网络请求，避免每60秒调用 session API
    private func fetchAccessToken(sessionToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 原子性读取缓存，避免 hasCachedValidToken 和 cachedAccessToken 之间的 TOCTOU 竞争
        cacheLock.lock()
        let cachedEntry: (token: String, remaining: Int)?
        if let token = cachedAccessToken, !token.isEmpty,
           let expiry = cachedAccessTokenExpiry,
           cachedForSessionToken == sessionToken,
           expiry > Date().addingTimeInterval(Self.tokenRefreshMargin) {
            cachedEntry = (token, Int(expiry.timeIntervalSinceNow / 60))
        } else {
            cachedEntry = nil
        }
        cacheLock.unlock()

        if let entry = cachedEntry {
            Logger.api.debug("Codex accessToken: 使用缓存（剩余约 \(entry.remaining) 分钟）")
            completion(.success(entry.token))
            return
        }

        // OAuth 账户：sessionKey 实为 OAuth refresh_token，用它向 auth.openai.com 换 access_token，
        // 不再走 chatgpt.com 的 /api/auth/session（cookie）路径。旧 session-token 账户继续走下方逻辑。
        if Self.isOAuthRefreshToken(sessionToken) {
            fetchAccessTokenViaOAuth(refreshToken: sessionToken, completion: completion)
            return
        }

        guard let url = URL(string: "\(baseURL)/api/auth/session") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error = error {
                Logger.api.debug("Codex session error: \(error.localizedDescription)")
                // 网络失败时，若旧 token 尚未真正过期则回退使用，避免瞬断影响用量拉取
                if let fallback = self.cachedTokenFallback(for: sessionToken) {
                    let remaining = Int((self.cachedAccessTokenExpiry?.timeIntervalSinceNow ?? 0) / 60)
                    Logger.api.warning("Codex session API 失败，回退缓存 token（剩余约 \(remaining) 分钟）")
                    completion(.success(fallback))
                } else {
                    completion(.failure(UsageError.networkError))
                }
                return
            }

            guard let data = data else {
                if let fallback = self.cachedTokenFallback(for: sessionToken) {
                    completion(.success(fallback))
                } else {
                    completion(.failure(UsageError.noData))
                }
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                Logger.api.debug("Codex session response received: \(data.count) bytes")
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                }
            }

            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("Codex session HTTP status: \(httpResponse.statusCode)")
                // Phase 0 诊断：检查 /api/auth/session 是否下发新 session-token
                let setCookieHeaders = httpResponse.allHeaderFields
                    .filter { ($0.key as? String)?.lowercased() == "set-cookie" }
                    .compactMap { $0.value as? String }
                Logger.api.debug("Codex session Set-Cookie 数量=\(setCookieHeaders.count)")
                for cookieStr in setCookieHeaders {
                    if cookieStr.contains("next-auth.session-token") {
                        Logger.api.info("Codex session Set-Cookie [SESSION-TOKEN] \(cookieStr.prefix(80))")
                    }
                }

                switch httpResponse.statusCode {
                case 200...299: break
                case 401: completion(.failure(UsageError.unauthorized)); return
                case 403: completion(.failure(UsageError.cloudflareBlocked)); return
                case 429: completion(.failure(UsageError.rateLimited)); return
                default:
                    completion(.failure(UsageError.httpError(statusCode: httpResponse.statusCode)))
                    return
                }
            }

            // Level 1：检查 HTTPCookieStorage 是否收到新的 session-token
            let chatgptURL = URL(string: "https://chatgpt.com")!
            let storedCookies = HTTPCookieStorage.shared.cookies(for: chatgptURL) ?? []
            if let newToken = CodexWebLoginCoordinator.extractSessionToken(from: storedCookies) {
                // 用已捕获的 sessionToken 参数比较，避免在后台线程读取 @Published 属性
                if newToken != sessionToken {
                    Logger.api.notice("Codex session: 检测到新 session-token，静默写回")
                    DispatchQueue.main.async {
                        UserSettings.shared.silentlyUpdateCurrentCodexSessionToken(newToken)
                    }
                }
            }

            let decoder = JSONDecoder()
            do {
                let sessionResponse = try decoder.decode(CodexSessionResponse.self, from: data)
                guard let accessToken = sessionResponse.accessToken, !accessToken.isEmpty else {
                    Logger.api.error("Codex session response missing accessToken")
                    completion(.failure(UsageError.sessionExpired))
                    return
                }
                let exp = jwtExpiry(from: accessToken)
                let expiry = exp ?? Date().addingTimeInterval(30 * 60)
                if let exp {
                    Logger.api.info("Codex accessToken expires at \(exp) (in \(Int(exp.timeIntervalSinceNow / 60)) min)")
                } else {
                    Logger.api.debug("Codex accessToken: exp 不可解析，缓存30分钟")
                }
                self.cacheLock.lock()
                self.cachedAccessToken = accessToken
                self.cachedAccessTokenExpiry = expiry
                self.cachedForSessionToken = sessionToken
                self.cacheLock.unlock()
                completion(.success(accessToken))
            } catch {
                Logger.api.debug("Codex session decode error: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }

        activeTasks.append(task)
        task.resume()
    }

    // MARK: - Private: OAuth refresh → accessToken

    /// 判断账户凭据是否为 OAuth refresh_token（OpenAI 格式以 "rt." 开头）
    /// 旧 session-token 是 next-auth 加密串，不会命中此前缀
    static func isOAuthRefreshToken(_ credential: String) -> Bool {
        credential.hasPrefix("rt.")
    }

    /// 用 OAuth refresh_token 向 auth.openai.com 换取 access_token
    /// 成功后缓存 access_token；若 refresh_token 发生轮换，则静默写回账户存储
    /// 通过单飞合并避免并发刷新（见 oauthRefreshInFlight 注释）
    private func fetchAccessTokenViaOAuth(refreshToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        cacheLock.lock()
        // 同一 refresh_token 已有刷新在进行：挂入等待队列复用其结果，不再重复发起
        if oauthRefreshInFlight, oauthRefreshInFlightToken == refreshToken {
            oauthRefreshWaiters.append(completion)
            cacheLock.unlock()
            return
        }
        // 成为发起者（不同账户的并发刷新极罕见——仅账户切换瞬间，此处不特殊合并，各自独立刷新）
        oauthRefreshInFlight = true
        oauthRefreshInFlightToken = refreshToken
        cacheLock.unlock()

        CodexOAuthService.refresh(refreshToken: refreshToken) { [weak self] result in
            guard let self else { return }

            let finalResult: Result<String, Error>
            switch result {
            case .failure(let error):
                // 网络瞬断时，若旧 access_token 尚未过期则回退使用
                if let fallback = self.cachedTokenFallback(for: refreshToken) {
                    Logger.api.warning("Codex OAuth refresh 失败，回退缓存 token")
                    finalResult = .success(fallback)
                } else {
                    finalResult = .failure(error)
                }

            case .success(let tokens):
                // refresh_token 可能轮换：响应携带新值且与旧值不同时，静默写回账户
                let newRefresh = tokens.refreshToken.isEmpty ? refreshToken : tokens.refreshToken
                if newRefresh != refreshToken {
                    Logger.api.notice("Codex OAuth: refresh_token 已轮换，静默写回")
                    DispatchQueue.main.async {
                        UserSettings.shared.silentlyUpdateCurrentCodexSessionToken(newRefresh)
                    }
                }

                let accessToken = tokens.accessToken
                let expiry = jwtExpiry(from: accessToken) ?? Date().addingTimeInterval(30 * 60)
                self.cacheLock.lock()
                self.cachedAccessToken = accessToken
                self.cachedAccessTokenExpiry = expiry
                // 缓存 key 跟随新 refresh_token，确保轮换后下次仍能命中缓存
                self.cachedForSessionToken = newRefresh
                self.cacheLock.unlock()
                finalResult = .success(accessToken)
            }

            // 清理单飞状态并取出所有等待者（均为同一 refresh_token，可安全复用同一结果）
            self.cacheLock.lock()
            let waiters = self.oauthRefreshWaiters
            self.oauthRefreshWaiters.removeAll()
            self.oauthRefreshInFlight = false
            self.oauthRefreshInFlightToken = nil
            self.cacheLock.unlock()

            completion(finalResult)
            for waiter in waiters { waiter(finalResult) }
        }
    }

    /// 跳过 session 步骤，直接用已获取的 accessToken 查询用量（用于刷新后重试）
    func fetchUsageWithAccessToken(_ accessToken: String, completion: @escaping (Result<CodexUsageData, Error>) -> Void) {
        fetchWhamUsage(accessToken: accessToken) { result in
            DispatchQueue.main.async { completion(result) }
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
                Logger.api.debug("Codex usage error: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }

            guard let data = data else {
                completion(.failure(UsageError.noData))
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                Logger.api.debug("Codex usage response received: \(data.count) bytes")
                if jsonString.contains("<!DOCTYPE html>") || jsonString.contains("<html") {
                    completion(.failure(UsageError.cloudflareBlocked))
                    return
                }
            }

            if let httpResponse = response as? HTTPURLResponse {
                Logger.api.debug("Codex usage HTTP status: \(httpResponse.statusCode)")
                switch httpResponse.statusCode {
                case 200...299: break
                case 401: completion(.failure(UsageError.unauthorized)); return
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
                Logger.api.debug("Codex usage decode error: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }

        activeTasks.append(task)
        task.resume()
    }

    // MARK: - Validation (used by WebLoginCoordinator)

    /// 验证 session token 并返回账户信息（用于 WebLogin 流程）
    /// - Parameters:
    ///   - sessionToken: __Secure-next-auth.session-token 值
    ///   - completion: 成功返回 (email, displayName)，失败返回 Error
    func validateSessionToken(_ sessionToken: String, cookieHeader: String, completion: @escaping (Result<(email: String, displayName: String), Error>) -> Void) {
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
                Logger.api.debug("Codex validate session response received: \(data.count) bytes")
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
                    Logger.api.warning("Codex validate: session stale (accessToken expired at \(exp)), rejecting login")
                    DispatchQueue.main.async { completion(.failure(UsageError.sessionExpired)) }
                    return
                }
                let email = sessionResponse.user?.email ?? ""
                let name = sessionResponse.user?.name ?? email
                let displayName = name.isEmpty ? "Codex" : name
                DispatchQueue.main.async { completion(.success((email: email, displayName: displayName))) }
            } catch {
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }

        activeTasks.append(task)
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

func jwtExpiry(from token: String) -> Date? {
    let parts = token.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    var base64 = String(parts[1])
    let remainder = base64.count % 4
    if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? TimeInterval else { return nil }
    return Date(timeIntervalSince1970: exp)
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
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
        Logger.api.debug("Codex: 已取消所有网络请求")
    }
}
