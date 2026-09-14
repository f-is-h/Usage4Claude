//
//  DiagnosticRunner.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-05-14.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

// MARK: - Protocol

protocol DiagnosticRunner {
    var providerType: ProviderType { get }
    func run() async -> ProviderDiagnosticResult
}

// MARK: - Claude Runner

@MainActor
final class ClaudeDiagnosticRunner: DiagnosticRunner {

    let providerType: ProviderType = .claude
    private let settings = UserSettings.shared

    func run() async -> ProviderDiagnosticResult {
        guard settings.hasValidCredentials else {
            return makeNoCredentialsResult()
        }

        let orgId = settings.organizationId
        let sessionKey = settings.sessionKey
        var credentials: [String: String] = [
            "Organization ID": SensitiveDataRedactor.redactOrganizationId(orgId),
            "Session Key": SensitiveDataRedactor.redactSessionKey(sessionKey)
        ]

        // 必须和服务层走同一条路：OAuth 账号的凭据是 refresh_token，拿它当 sessionKey
        // Cookie 发出去只会稳定拿到 403，然后被误报成「凭据已过期」。
        let authPath = ProviderAuthPath.forClaude(credential: sessionKey)
        credentials["Auth Path"] = authPath.displayName
        if authPath == .oauth {
            return await runOAuthPath(credentials: credentials)
        }

        let urlString = "https://claude.ai/api/organizations/\(orgId)/usage"
        guard let url = URL(string: urlString) else {
            return makeInvalidUrlResult(credentials: credentials)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        ClaudeAPIHeaderBuilder.applyHeaders(to: &request, organizationId: orgId, sessionKey: sessionKey)

        let startTime = Date()
        let session = URLSession(configuration: .default)

        do {
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            let step = analyzeResponse(
                stepName: "Usage API",
                data: data,
                response: response,
                responseTime: responseTime
            )
            return buildResult(credentials: credentials, steps: [step])
        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            let step = makeNetworkErrorStep(name: "Usage API", error: error, responseTime: responseTime)
            return buildResult(credentials: credentials, steps: [step])
        }
    }

    // MARK: - OAuth Path

    /// OAuth 账号的诊断：走服务层的真实取数路径，**绝不自己换 token**
    ///
    /// OAuth refresh_token 每次续期都会轮换，服务端在发放新值的同时立刻作废旧值。
    /// 诊断若自己调 `ClaudeOAuthService.refresh`，换回来的新 token 无处写回、随手丢弃，
    /// 存储里的旧 token 当场失效——点一次「测试连接」就把账号登出了。
    /// `CLAUDE.md` 记着这条不变式：任何取 token 的新路径都必须复用 `OAuthTokenCache`
    /// 的单飞与轮换写回，也就是只能经由服务层。
    ///
    /// 代价是拿不到 HTTP 状态码与响应头。这是刻意的取舍：诊断的价值在于结论可信，
    /// 而重造一条会和服务层脱钩的请求链正是这轮 bug 的来源。
    private func runOAuthPath(credentials: [String: String]) async -> ProviderDiagnosticResult {
        let startTime = Date()
        let result = await ClaudeAPIService.shared.fetchUsageResult()
        let responseTime = Date().timeIntervalSince(startTime) * 1000

        let step: DiagnosticStep
        switch result {
        case .success(let usage):
            step = DiagnosticStep(
                name: "OAuth Usage API", success: true,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .json, errorType: nil, errorDescription: nil,
                responseHeaders: [:],
                responseBodyPreview: "Valid usage data received (utilization: \(usage.percentage)%)",
                cloudflareChallenge: false, cfMitigated: false, notes: nil
            )
        case .failure(let error):
            let usageError = error as? UsageError
            let errorType: DiagnosticErrorType
            switch usageError {
            case .cloudflareBlocked:           errorType = .cloudflareBlocked
            case .usageDashboardUnavailable:   errorType = .usageDashboardUnavailable
            case .networkError:                errorType = .networkError
            case .sessionExpired, .unauthorized: errorType = .authenticationFailed
            default:                           errorType = .unknown
            }
            step = DiagnosticStep(
                name: "OAuth Usage API", success: false,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .unknown, errorType: errorType,
                errorDescription: error.localizedDescription,
                responseHeaders: [:], responseBodyPreview: nil,
                cloudflareChallenge: errorType == .cloudflareBlocked,
                cfMitigated: false, notes: nil
            )
        }

        return buildResult(credentials: credentials, steps: [step], authPath: .oauth)
    }

    // MARK: - Response Analysis

    private func analyzeResponse(
        stepName: String,
        data: Data,
        response: URLResponse,
        responseTime: Double
    ) -> DiagnosticStep {
        guard let httpResponse = response as? HTTPURLResponse else {
            return makeUnknownResponseStep(name: stepName, data: data, responseTime: responseTime)
        }

        let statusCode = httpResponse.statusCode
        let headers = extractSafeHeaders(from: httpResponse)
        let cfMitigated = headers["cf-mitigated"] != nil
        // 报告要导出到 GitHub Issue，响应体一律先脱敏再截断
        let bodyPreview = String(data: data, encoding: .utf8).map {
            SensitiveDataRedactor.redactBodyPreview($0)
        }

        func makeStep(
            success: Bool,
            responseType: DiagnosticStep.ResponseType,
            errorType: DiagnosticErrorType?,
            errorDescription: String?,
            preview: String?,
            cloudflare: Bool = false,
            notes: String? = nil
        ) -> DiagnosticStep {
            DiagnosticStep(
                name: stepName, success: success,
                httpStatusCode: statusCode, responseTime: responseTime,
                responseType: responseType, errorType: errorType,
                errorDescription: errorDescription,
                responseHeaders: headers,
                responseBodyPreview: preview,
                cloudflareChallenge: cloudflare,
                cfMitigated: cfMitigated,
                notes: notes
            )
        }

        switch DiagnosticResponseClassifier.classifyClaudeUsage(statusCode: statusCode, body: data) {
        case .cloudflareChallenge:
            return makeStep(success: false, responseType: .html, errorType: .cloudflareBlocked,
                            errorDescription: L.Error.cloudflareBlocked, preview: bodyPreview,
                            cloudflare: true)

        case .credentialsRejected(let detail):
            // 凭据过期是最常见的失败。必须报成鉴权失败而不是解析失败，否则诊断建议会把用户
            // 引去核对根本没错的 Organization ID，最后跑来提 issue（Issue #84）。
            return makeStep(success: false, responseType: .json, errorType: .authenticationFailed,
                            errorDescription: L.Error.sessionExpired, preview: bodyPreview,
                            notes: detail)

        case .usageDashboardUnavailable:
            // 解码成功但一条限额都没有：账号未开放用量看板（Issue #83 / #74）。
            // 报告必须把它和「凭据错误」分开，否则诊断结论会把用户带偏。
            return makeStep(success: false, responseType: .json, errorType: .usageDashboardUnavailable,
                            errorDescription: L.Error.usageDashboardUnavailable, preview: bodyPreview)

        case .usageDataAvailable(let utilizationPreview):
            return makeStep(success: true, responseType: .json, errorType: nil, errorDescription: nil,
                            preview: "Valid usage data received (utilization: \(utilizationPreview))")

        case .unparsable:
            return makeStep(success: false, responseType: .unknown, errorType: .decodingError,
                            errorDescription: L.Error.decodingFailed, preview: bodyPreview)
        }
    }

    // MARK: - Result Builders

    private func buildResult(
        credentials: [String: String],
        steps: [DiagnosticStep],
        authPath: ProviderAuthPath = .cookie
    ) -> ProviderDiagnosticResult {
        // 多步路径（OAuth 是「换 token → 拉用量」两步）必须全部通过才算成功，
        // 只看 steps.first 会把「token 换到了但用量拿不到」误报成连接正常
        let failingStep = steps.first { !$0.success }
        let success = !steps.isEmpty && failingStep == nil
        let errorType = failingStep?.errorType

        let (diagnosis, suggestions, confidence) = diagnosisFor(
            success: success,
            errorType: errorType,
            cloudflare: failingStep?.cloudflareChallenge ?? false,
            authPath: authPath
        )

        return ProviderDiagnosticResult(
            providerType: .claude,
            credentials: credentials,
            steps: steps,
            success: success,
            errorType: errorType,
            diagnosis: diagnosis,
            suggestions: suggestions,
            confidence: confidence
        )
    }

    private func makeNoCredentialsResult() -> ProviderDiagnosticResult {
        ProviderDiagnosticResult(
            providerType: .claude,
            credentials: ["Organization ID": "Not configured", "Session Key": "Not configured"],
            steps: [],
            success: false,
            errorType: .invalidCredentials,
            diagnosis: DiagnosticMessage.diagnosisNoCredentials,
            suggestions: [DiagnosticMessage.suggestionConfigureAuth],
            confidence: .high
        )
    }

    private func makeInvalidUrlResult(credentials: [String: String]) -> ProviderDiagnosticResult {
        ProviderDiagnosticResult(
            providerType: .claude,
            credentials: credentials,
            steps: [],
            success: false,
            errorType: .invalidCredentials,
            diagnosis: DiagnosticMessage.diagnosisInvalidUrl,
            suggestions: [DiagnosticMessage.suggestionCheckOrgId],
            confidence: .high
        )
    }

    // MARK: - Diagnosis

    private func diagnosisFor(
        success: Bool,
        errorType: DiagnosticErrorType?,
        cloudflare: Bool,
        authPath: ProviderAuthPath
    ) -> (diagnosis: String, suggestions: [String], confidence: ProviderDiagnosticResult.ConfidenceLevel) {
        if success {
            return (DiagnosticMessage.diagnosisSuccess, [DiagnosticMessage.suggestionSuccess], .high)
        }
        switch errorType {
        case .cloudflareBlocked:
            return (DiagnosticMessage.diagnosisCloudflare, [
                DiagnosticMessage.suggestionVisitBrowser,
                DiagnosticMessage.suggestionWaitAndRetry,
                DiagnosticMessage.suggestionCheckVPN,
                DiagnosticMessage.suggestionUseSmartMode
            ], .high)
        case .authenticationFailed, .invalidCredentials:
            // OAuth 账号没有 Session Key 可填，指向「重新登录」而不是「核对凭据」
            if authPath == .oauth {
                return (DiagnosticMessage.diagnosisOAuthAuthFailed, [
                    DiagnosticMessage.suggestionReloginOAuth,
                    DiagnosticMessage.suggestionCheckBrowser
                ], .high)
            }
            return (DiagnosticMessage.diagnosisAuthFailed, [
                DiagnosticMessage.suggestionUpdateSessionKey,
                DiagnosticMessage.suggestionVerifyCredentials,
                DiagnosticMessage.suggestionCheckBrowser
            ], .high)
        case .decodingError:
            return (DiagnosticMessage.diagnosisDecoding, [
                DiagnosticMessage.suggestionVerifyCredentials,
                DiagnosticMessage.suggestionUpdateSessionKey,
                DiagnosticMessage.suggestionCheckBrowser
            ], .medium)
        case .usageDashboardUnavailable:
            return (DiagnosticMessage.diagnosisDashboardUnavailable, [
                DiagnosticMessage.suggestionCheckPlanDashboard,
                DiagnosticMessage.suggestionAskOrgAdmin,
                DiagnosticMessage.suggestionUpgradePlan
            ], .high)
        case .networkError:
            return (DiagnosticMessage.diagnosisNetwork, [
                DiagnosticMessage.suggestionCheckInternet,
                DiagnosticMessage.suggestionCheckFirewall,
                DiagnosticMessage.suggestionRetryLater
            ], .high)
        default:
            return (DiagnosticMessage.diagnosisUnknown, [
                DiagnosticMessage.suggestionExportAndShare,
                DiagnosticMessage.suggestionContactSupport
            ], .low)
        }
    }
}

// MARK: - Codex Runner

@MainActor
final class CodexDiagnosticRunner: DiagnosticRunner {

    let providerType: ProviderType = .codex
    private let settings = UserSettings.shared

    func run() async -> ProviderDiagnosticResult {
        guard settings.hasValidCodexCredentials else {
            return makeNoCredentialsResult()
        }

        let sessionToken = settings.codexSessionToken
        var credentials: [String: String] = [
            "Session Token": SensitiveDataRedactor.redactCodexSessionToken(sessionToken)
        ]

        // 与服务层同一个判定：OAuth 账号的凭据是 refresh_token，拿它当 session-token
        // Cookie 发给 /api/auth/session 只会得到一个空 session，然后被误报成「session 已过期」。
        let authPath = ProviderAuthPath.forCodex(credential: sessionToken)
        credentials["Auth Path"] = authPath.displayName
        if authPath == .oauth {
            return await runOAuthPath(credentials: credentials)
        }

        var steps: [DiagnosticStep] = []

        // Step 1: /api/auth/session — 用 session-token Cookie 换 accessToken
        let (sessionStep, accessToken) = await runSessionStep(sessionToken: sessionToken)
        steps.append(sessionStep)

        if let at = accessToken {
            credentials["Access Token"] = SensitiveDataRedactor.redactAccessToken(at)
        }

        var usageSuccess = false

        // Step 2: /backend-api/wham/usage — 用 Bearer accessToken 拉使用量
        if let at = accessToken {
            let usageStep = await runUsageStep(accessToken: at)
            steps.append(usageStep)
            usageSuccess = usageStep.success
        }

        // Step 3: SSR refresh probe — 仅在 session 或 usage 失败时触发
        if !sessionStep.success || !usageSuccess {
            let ssrStep = await runSsrProbeStep()
            steps.append(ssrStep)
        }

        return aggregateResult(credentials: credentials, steps: steps)
    }

    // MARK: - OAuth Path

    /// OAuth 账号的诊断：走服务层的真实取数路径，**绝不自己换 token**
    ///
    /// 理由同 Claude 侧：OAuth refresh_token 每次续期都会轮换并立刻作废旧值，
    /// 只有服务层的 `OAuthTokenCache` 路径会把新值写回账号。诊断自己调
    /// `CodexOAuthService.refresh` 会把新 token 丢掉，点一次就把账号登出。
    ///
    /// 也不跑 SSR 探测——那是 cookie 账号的续期兜底，对 OAuth 账号没有意义。
    private func runOAuthPath(credentials: [String: String]) async -> ProviderDiagnosticResult {
        let startTime = Date()
        let result = await CodexAPIService.shared.fetchUsageResult()
        let responseTime = Date().timeIntervalSince(startTime) * 1000

        let step: DiagnosticStep
        let diagnosis: String
        let suggestions: [String]

        switch result {
        case .success:
            step = DiagnosticStep(
                name: "OAuth Usage API", success: true,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .json, errorType: nil, errorDescription: nil,
                responseHeaders: [:],
                responseBodyPreview: "Valid Codex usage data received",
                cloudflareChallenge: false, cfMitigated: false, notes: nil
            )
            diagnosis = DiagnosticMessage.diagnosisCodexSuccess
            suggestions = [DiagnosticMessage.suggestionSuccess]

        case .failure(let error):
            var isCloudflare = false
            if let usageError = error as? UsageError, case .cloudflareBlocked = usageError {
                isCloudflare = true
            }
            step = DiagnosticStep(
                name: "OAuth Usage API", success: false,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .unknown,
                errorType: isCloudflare ? .cloudflareBlocked : .sessionTokenInvalid,
                errorDescription: error.localizedDescription,
                responseHeaders: [:], responseBodyPreview: nil,
                cloudflareChallenge: isCloudflare, cfMitigated: false, notes: nil
            )
            diagnosis = isCloudflare
                ? DiagnosticMessage.diagnosisCodexUsageCloudflare
                : DiagnosticMessage.diagnosisCodexOAuthFailed
            suggestions = isCloudflare
                ? [DiagnosticMessage.suggestionCodexCheckChatGPTBrowser, DiagnosticMessage.suggestionWaitAndRetry]
                : [DiagnosticMessage.suggestionReloginOAuth]
        }

        return ProviderDiagnosticResult(
            providerType: .codex,
            credentials: credentials,
            steps: [step],
            success: step.success,
            errorType: step.errorType,
            diagnosis: diagnosis,
            suggestions: suggestions,
            confidence: .high
        )
    }

    // MARK: - Step: Session
    // MARK: - Step: Session

    private func runSessionStep(sessionToken: String) async -> (step: DiagnosticStep, accessToken: String?) {
        let stepName = "Session Token Validation"
        let urlString = "https://chatgpt.com/api/auth/session"
        guard let url = URL(string: urlString) else {
            return (makeNetworkErrorStep(name: stepName, error: URLError(.badURL), responseTime: 0), nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        CodexAPIHeaderBuilder.applySessionHeaders(to: &request, sessionToken: sessionToken)

        let startTime = Date()
        let session = URLSession(configuration: .default)

        do {
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime) * 1000

            guard let httpResponse = response as? HTTPURLResponse else {
                return (makeUnknownResponseStep(name: stepName, data: data, responseTime: responseTime), nil)
            }

            let statusCode = httpResponse.statusCode
            let headers = extractSafeHeaders(from: httpResponse)
            let cfMitigated = headers["cf-mitigated"] != nil
            // session 响应带 accessToken，报告要导出，务必先脱敏
            let bodyPreview = String(data: data, encoding: .utf8).map {
                SensitiveDataRedactor.redactBodyPreview($0)
            }

            func makeStep(
                success: Bool,
                responseType: DiagnosticStep.ResponseType,
                errorType: DiagnosticErrorType?,
                errorDescription: String?,
                preview: String?,
                cloudflare: Bool = false,
                notes: String? = nil
            ) -> DiagnosticStep {
                DiagnosticStep(
                    name: stepName, success: success,
                    httpStatusCode: statusCode, responseTime: responseTime,
                    responseType: responseType, errorType: errorType,
                    errorDescription: errorDescription,
                    responseHeaders: headers,
                    responseBodyPreview: preview,
                    cloudflareChallenge: cloudflare,
                    cfMitigated: cfMitigated,
                    notes: notes
                )
            }

            switch DiagnosticResponseClassifier.classifyCodexSession(statusCode: statusCode, body: data) {
            case .cloudflareChallenge:
                let step = makeStep(success: false, responseType: .html, errorType: .cloudflareBlocked,
                                    errorDescription: "Cloudflare blocked the session endpoint",
                                    preview: bodyPreview, cloudflare: true)
                return (step, nil)

            case .sessionRejected(let detail):
                // 未登录时 chatgpt.com 返回 200 + 只有 WARNING_BANNER 的空 body。曾被当成
                // 解析失败，导致下游 diagnoseCodex 匹配不到任何分支、退化成 Unknown（Issue #84）。
                let step = makeStep(success: false, responseType: .json, errorType: .sessionTokenInvalid,
                                    errorDescription: detail, preview: bodyPreview)
                return (step, nil)

            case .authenticated(let accessToken, let email):
                var notes: String? = nil
                if let expDate = jwtExpiry(from: accessToken) {
                    let remaining = expDate.timeIntervalSince(Date())
                    if remaining > 0 {
                        let mins = Int(remaining / 60)
                        notes = "Access token expires in \(mins) min"
                    } else {
                        notes = "Access token is already expired"
                    }
                }
                let step = makeStep(success: true, responseType: .json, errorType: nil, errorDescription: nil,
                                    preview: "Session response received (user: \(email ?? "unknown"))",
                                    notes: notes)
                return (step, accessToken)

            case .unparsable:
                let step = makeStep(success: false, responseType: .unknown, errorType: .decodingError,
                                    errorDescription: "Session response could not be parsed",
                                    preview: bodyPreview)
                return (step, nil)
            }

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            return (makeNetworkErrorStep(name: stepName, error: error, responseTime: responseTime), nil)
        }
    }

    // MARK: - Step: Usage

    private func runUsageStep(accessToken: String) async -> DiagnosticStep {
        let stepName = "Usage API"
        let urlString = "https://chatgpt.com/backend-api/wham/usage"
        guard let url = URL(string: urlString) else {
            return makeNetworkErrorStep(name: stepName, error: URLError(.badURL), responseTime: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        CodexAPIHeaderBuilder.applyUsageHeaders(to: &request, accessToken: accessToken)

        let startTime = Date()
        let session = URLSession(configuration: .default)

        do {
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime) * 1000

            guard let httpResponse = response as? HTTPURLResponse else {
                return makeUnknownResponseStep(name: stepName, data: data, responseTime: responseTime)
            }

            let statusCode = httpResponse.statusCode
            let headers = extractSafeHeaders(from: httpResponse)

            if let bodyString = String(data: data, encoding: .utf8) {
                let isHTML = bodyString.contains("<!DOCTYPE html>") || bodyString.contains("<html")
                let hasCloudflare = bodyString.localizedCaseInsensitiveContains("cloudflare") ||
                                    bodyString.contains("Just a moment")

                if isHTML && hasCloudflare {
                    return DiagnosticStep(
                        name: stepName, success: false,
                        httpStatusCode: statusCode, responseTime: responseTime,
                        responseType: .html, errorType: .cloudflareBlocked,
                        errorDescription: "Cloudflare blocked the usage endpoint",
                        responseHeaders: headers,
                        responseBodyPreview: String(bodyString.prefix(500)),
                        cloudflareChallenge: true,
                        cfMitigated: headers["cf-mitigated"] != nil,
                        notes: nil
                    )
                }
            }

            if statusCode == 401 || statusCode == 403 {
                return DiagnosticStep(
                    name: stepName, success: false,
                    httpStatusCode: statusCode, responseTime: responseTime,
                    responseType: .unknown, errorType: .accessTokenExpired,
                    errorDescription: "Usage endpoint rejected the access token (HTTP \(statusCode))",
                    responseHeaders: headers,
                    responseBodyPreview: nil,
                    cloudflareChallenge: false,
                    cfMitigated: headers["cf-mitigated"] != nil,
                    notes: nil
                )
            }

            let decoder = JSONDecoder()
            if (200..<300).contains(statusCode),
               (try? decoder.decode(CodexUsageResponse.self, from: data)) != nil {
                return DiagnosticStep(
                    name: stepName, success: true,
                    httpStatusCode: statusCode, responseTime: responseTime,
                    responseType: .json, errorType: nil, errorDescription: nil,
                    responseHeaders: headers,
                    responseBodyPreview: "Valid Codex usage data received",
                    cloudflareChallenge: false,
                    cfMitigated: headers["cf-mitigated"] != nil,
                    notes: nil
                )
            }

            let bodyPreview = data.isEmpty ? nil : String(data: data, encoding: .utf8).map {
                SensitiveDataRedactor.redactBodyPreview($0)
            }
            return DiagnosticStep(
                name: stepName, success: false,
                httpStatusCode: statusCode, responseTime: responseTime,
                responseType: .unknown, errorType: .usageEndpointFailed,
                errorDescription: "Usage response could not be parsed (HTTP \(statusCode))",
                responseHeaders: headers,
                responseBodyPreview: bodyPreview,
                cloudflareChallenge: false,
                cfMitigated: headers["cf-mitigated"] != nil,
                notes: nil
            )

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            return makeNetworkErrorStep(name: stepName, error: error, responseTime: responseTime)
        }
    }

    // MARK: - Step: SSR Refresh Probe

    private func runSsrProbeStep() async -> DiagnosticStep {
        let stepName = "SSR Token Refresh Probe"

        // 若后台刷新已在进行中则跳过探测，避免误导诊断结论
        guard !CodexTokenRefreshCoordinator.shared.isRefreshing else {
            return DiagnosticStep(
                name: stepName, success: false,
                httpStatusCode: nil, responseTime: nil,
                responseType: .unknown, errorType: .ssrBootstrapFailed,
                errorDescription: "Skipped: a background token refresh is already in progress",
                responseHeaders: [:], responseBodyPreview: nil,
                cloudflareChallenge: false, cfMitigated: false,
                notes: "Retry the diagnostic after the background refresh completes"
            )
        }

        let startTime = Date()

        return await withCheckedContinuation { continuation in
            CodexTokenRefreshCoordinator.shared.refresh { result in
                let responseTime = Date().timeIntervalSince(startTime) * 1000
                switch result {
                case .success(let newToken):
                    var notes: String? = nil
                    if let expDate = jwtExpiry(from: newToken) {
                        let remaining = expDate.timeIntervalSince(Date())
                        if remaining > 0 {
                            let mins = Int(remaining / 60)
                            notes = "SSR returned fresh token, expires in \(mins) min"
                        }
                    }
                    let step = DiagnosticStep(
                        name: stepName, success: true,
                        httpStatusCode: 200, responseTime: responseTime,
                        responseType: .html, errorType: nil, errorDescription: nil,
                        responseHeaders: [:],
                        responseBodyPreview: "SSR bootstrap successfully returned a new access token",
                        cloudflareChallenge: false, cfMitigated: false,
                        notes: notes
                    )
                    continuation.resume(returning: step)

                case .failure(let error):
                    let (errorType, errorDesc): (DiagnosticErrorType, String)
                    if let usageError = error as? UsageError, case .cloudflareBlocked = usageError {
                        errorType = .cloudflareBlocked
                        errorDesc = "Cloudflare blocked the SSR request"
                    } else {
                        errorType = .ssrBootstrapFailed
                        errorDesc = error.localizedDescription
                    }
                    let step = DiagnosticStep(
                        name: stepName, success: false,
                        httpStatusCode: nil, responseTime: responseTime,
                        responseType: .unknown, errorType: errorType,
                        errorDescription: errorDesc,
                        responseHeaders: [:],
                        responseBodyPreview: nil,
                        cloudflareChallenge: errorType == .cloudflareBlocked,
                        cfMitigated: false,
                        notes: nil
                    )
                    continuation.resume(returning: step)
                }
            }
        }
    }

    // MARK: - Aggregation

    private func aggregateResult(
        credentials: [String: String],
        steps: [DiagnosticStep]
    ) -> ProviderDiagnosticResult {
        let sessionStep = steps.first { $0.name == "Session Token Validation" }
        let usageStep = steps.first { $0.name == "Usage API" }
        let ssrStep = steps.first { $0.name == "SSR Token Refresh Probe" }

        let sessionOk = sessionStep?.success ?? false
        let usageOk = usageStep?.success ?? false
        let ssrOk = ssrStep?.success ?? false
        let overallSuccess = sessionOk && usageOk

        let (diagnosis, suggestions, confidence) = diagnoseCodex(
            sessionStep: sessionStep,
            usageStep: usageStep,
            ssrStep: ssrStep,
            sessionOk: sessionOk,
            usageOk: usageOk,
            ssrOk: ssrOk
        )

        return ProviderDiagnosticResult(
            providerType: .codex,
            credentials: credentials,
            steps: steps,
            success: overallSuccess,
            errorType: overallSuccess ? nil : (sessionStep?.errorType ?? usageStep?.errorType ?? .unknown),
            diagnosis: diagnosis,
            suggestions: suggestions,
            confidence: confidence
        )
    }

    private func diagnoseCodex(
        sessionStep: DiagnosticStep?,
        usageStep: DiagnosticStep?,
        ssrStep: DiagnosticStep?,
        sessionOk: Bool,
        usageOk: Bool,
        ssrOk: Bool
    ) -> (String, [String], ProviderDiagnosticResult.ConfidenceLevel) {
        // 两步都通过
        if sessionOk && usageOk {
            return (DiagnosticMessage.diagnosisCodexSuccess, [DiagnosticMessage.suggestionSuccess], .high)
        }

        // session 通过，usage 被 Cloudflare 拦截
        if sessionOk && usageStep?.cloudflareChallenge == true {
            return (DiagnosticMessage.diagnosisCodexUsageCloudflare, [
                DiagnosticMessage.suggestionCodexCheckChatGPTBrowser,
                DiagnosticMessage.suggestionWaitAndRetry,
                DiagnosticMessage.suggestionCheckVPN
            ], .high)
        }

        // session 通过，usage 401 — 区分 SSR 能否恢复
        if sessionOk && !usageOk && usageStep?.errorType == .accessTokenExpired {
            if ssrOk {
                return (DiagnosticMessage.diagnosisCodexAccessExpired, [
                    DiagnosticMessage.suggestionCodexRestartApp
                ], .high)
            } else {
                return (DiagnosticMessage.diagnosisCodexSsrFailed, [
                    DiagnosticMessage.suggestionCodexRelogin
                ], .high)
            }
        }

        // session 被 Cloudflare 拦截
        if sessionStep?.cloudflareChallenge == true {
            return (DiagnosticMessage.diagnosisCodexSessionCloudflare, [
                DiagnosticMessage.suggestionCodexCheckChatGPTBrowser,
                DiagnosticMessage.suggestionWaitAndRetry,
                DiagnosticMessage.suggestionCheckVPN
            ], .high)
        }

        // session 401/403（token 失效）— SSR 能否恢复
        if sessionStep?.errorType == .sessionTokenInvalid {
            if ssrOk {
                return (DiagnosticMessage.diagnosisCodexSsrRecovered, [
                    DiagnosticMessage.suggestionCodexRestartApp
                ], .high)
            } else {
                return (DiagnosticMessage.diagnosisCodexSsrFailed, [
                    DiagnosticMessage.suggestionCodexRelogin,
                    DiagnosticMessage.suggestionCodexClearWebViewCache
                ], .high)
            }
        }

        // session 解析失败（usage 端点异常）
        if sessionOk && !usageOk {
            return (DiagnosticMessage.diagnosisCodexUsageFailed, [
                DiagnosticMessage.suggestionRetryLater,
                DiagnosticMessage.suggestionExportAndShare
            ], .medium)
        }

        // 网络错误
        if sessionStep?.errorType == .networkError {
            return (DiagnosticMessage.diagnosisNetwork, [
                DiagnosticMessage.suggestionCheckInternet,
                DiagnosticMessage.suggestionCheckFirewall
            ], .high)
        }

        // 兜底：SSR 刷新是最后一道恢复手段，它都失败了就说明 session 确实没救了。
        // 上面任何一条分支都没命中时，仍然优先给出这个结论，而不是让报告输出
        // 「Unknown error，请找开发者」把用户推去提 issue（Issue #84）。
        if let ssrStep, !ssrStep.success {
            return (DiagnosticMessage.diagnosisCodexSsrFailed, [
                DiagnosticMessage.suggestionCodexRelogin,
                DiagnosticMessage.suggestionCodexClearWebViewCache
            ], .medium)
        }

        return (DiagnosticMessage.diagnosisUnknown, [
            DiagnosticMessage.suggestionExportAndShare,
            DiagnosticMessage.suggestionContactSupport
        ], .low)
    }

    // MARK: - Fallbacks

    private func makeNoCredentialsResult() -> ProviderDiagnosticResult {
        ProviderDiagnosticResult(
            providerType: .codex,
            credentials: ["Session Token": "Not configured"],
            steps: [],
            success: false,
            errorType: .invalidCredentials,
            diagnosis: DiagnosticMessage.diagnosisCodexNoCredentials,
            suggestions: [DiagnosticMessage.suggestionCodexRelogin],
            confidence: .high
        )
    }
}

// MARK: - Shared Helpers

private extension ClaudeDiagnosticRunner {
    func extractSafeHeaders(from response: HTTPURLResponse) -> [String: String] {
        extractSafeResponseHeaders(from: response)
    }

    func makeNetworkErrorStep(name: String, error: Error, responseTime: Double) -> DiagnosticStep {
        DiagnosticStep(
            name: name, success: false,
            httpStatusCode: nil, responseTime: responseTime,
            responseType: .unknown, errorType: .networkError,
            errorDescription: error.localizedDescription,
            responseHeaders: [:], responseBodyPreview: nil,
            cloudflareChallenge: false, cfMitigated: false, notes: nil
        )
    }

    func makeUnknownResponseStep(
        name: String, data: Data, responseTime: Double,
        statusCode: Int? = nil, headers: [String: String] = [:]
    ) -> DiagnosticStep {
        let preview = String(data: data, encoding: .utf8).map { String($0.prefix(500)) }
        return DiagnosticStep(
            name: name, success: false,
            httpStatusCode: statusCode, responseTime: responseTime,
            responseType: .unknown, errorType: .unknown,
            errorDescription: "Unknown response format",
            responseHeaders: headers, responseBodyPreview: preview,
            cloudflareChallenge: false, cfMitigated: false, notes: nil
        )
    }
}

private extension CodexDiagnosticRunner {
    func extractSafeHeaders(from response: HTTPURLResponse) -> [String: String] {
        extractSafeResponseHeaders(from: response)
    }

    func makeNetworkErrorStep(name: String, error: Error, responseTime: Double) -> DiagnosticStep {
        DiagnosticStep(
            name: name, success: false,
            httpStatusCode: nil, responseTime: responseTime,
            responseType: .unknown, errorType: .networkError,
            errorDescription: error.localizedDescription,
            responseHeaders: [:], responseBodyPreview: nil,
            cloudflareChallenge: false, cfMitigated: false, notes: nil
        )
    }

    func makeUnknownResponseStep(
        name: String, data: Data, responseTime: Double,
        statusCode: Int? = nil, headers: [String: String] = [:]
    ) -> DiagnosticStep {
        let preview = String(data: data, encoding: .utf8).map { String($0.prefix(500)) }
        return DiagnosticStep(
            name: name, success: false,
            httpStatusCode: statusCode, responseTime: responseTime,
            responseType: .unknown, errorType: .unknown,
            errorDescription: "Unknown response format",
            responseHeaders: headers, responseBodyPreview: preview,
            cloudflareChallenge: false, cfMitigated: false, notes: nil
        )
    }
}

// MARK: - Shared header extraction

private func extractSafeResponseHeaders(from response: HTTPURLResponse) -> [String: String] {
    let allowedHeaders = [
        "content-type", "content-length", "cf-mitigated",
        "cf-ray", "server", "date", "cache-control", "x-request-id"
    ]
    var safeHeaders: [String: String] = [:]
    for (key, value) in response.allHeaderFields {
        let keyStr = (key as? String ?? "").lowercased()
        if allowedHeaders.contains(keyStr) {
            safeHeaders[keyStr] = value as? String ?? ""
        }
    }
    return safeHeaders
}
