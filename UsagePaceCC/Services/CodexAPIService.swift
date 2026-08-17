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
    private func fetchAccessToken(sessionToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/session") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.api.debug("Codex session error: \(error.localizedDescription)")
                completion(.failure(UsageError.networkError))
                return
            }

            guard let data = data else {
                completion(.failure(UsageError.noData))
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
                let sessionResponse = try decoder.decode(CodexSessionResponse.self, from: data)
                guard let accessToken = sessionResponse.accessToken, !accessToken.isEmpty else {
                    Logger.api.error("Codex session response missing accessToken")
                    completion(.failure(UsageError.sessionExpired))
                    return
                }
                completion(.success(accessToken))
            } catch {
                Logger.api.debug("Codex session decode error: \(error.localizedDescription)")
                completion(.failure(UsageError.decodingError))
            }
        }

        activeTasks.append(task)
        task.resume()
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
    func validateSessionToken(_ sessionToken: String, completion: @escaping (Result<(email: String, displayName: String), Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/auth/session") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.assumesHTTP3Capable = false
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)

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
