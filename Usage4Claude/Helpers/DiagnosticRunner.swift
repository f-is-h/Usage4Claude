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
        let credentials: [String: String] = [
            "Organization ID": SensitiveDataRedactor.redactOrganizationId(orgId),
            "Session Key": SensitiveDataRedactor.redactSessionKey(sessionKey)
        ]

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

        guard let bodyString = String(data: data, encoding: .utf8) else {
            return makeUnknownResponseStep(name: stepName, data: data, responseTime: responseTime,
                                           statusCode: statusCode, headers: headers)
        }

        let isHTML = bodyString.contains("<!DOCTYPE html>") || bodyString.contains("<html")
        let hasCloudflare = bodyString.localizedCaseInsensitiveContains("cloudflare") ||
                            bodyString.contains("cf-mitigated") ||
                            bodyString.contains("Just a moment")

        if isHTML && (statusCode == 403 || hasCloudflare) {
            return DiagnosticStep(
                name: stepName, success: false,
                httpStatusCode: statusCode, responseTime: responseTime,
                responseType: .html, errorType: .cloudflareBlocked,
                errorDescription: L.Error.cloudflareBlocked,
                responseHeaders: headers,
                responseBodyPreview: String(bodyString.prefix(500)),
                cloudflareChallenge: true,
                cfMitigated: headers["cf-mitigated"] != nil,
                notes: nil
            )
        }

        if let json = try? JSONDecoder().decode(UsageResponse.self, from: data) {
            return DiagnosticStep(
                name: stepName, success: true,
                httpStatusCode: statusCode, responseTime: responseTime,
                responseType: .json, errorType: nil, errorDescription: nil,
                responseHeaders: headers,
                responseBodyPreview: "Valid usage data received (utilization: \(json.five_hour.utilization)%)",
                cloudflareChallenge: false,
                cfMitigated: headers["cf-mitigated"] != nil,
                notes: nil
            )
        }

        return DiagnosticStep(
            name: stepName, success: false,
            httpStatusCode: statusCode, responseTime: responseTime,
            responseType: .unknown, errorType: .decodingError,
            errorDescription: L.Error.decodingFailed,
            responseHeaders: headers,
            responseBodyPreview: String(bodyString.prefix(500)),
            cloudflareChallenge: false,
            cfMitigated: headers["cf-mitigated"] != nil,
            notes: nil
        )
    }

    // MARK: - Result Builders

    private func buildResult(credentials: [String: String], steps: [DiagnosticStep]) -> ProviderDiagnosticResult {
        let mainStep = steps.first
        let success = mainStep?.success ?? false
        let errorType = mainStep?.errorType

        let (diagnosis, suggestions, confidence) = diagnosisFor(
            success: success,
            errorType: errorType,
            cloudflare: mainStep?.cloudflareChallenge ?? false
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
        cloudflare: Bool
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
        case .decodingError:
            return (DiagnosticMessage.diagnosisDecoding, [
                DiagnosticMessage.suggestionVerifyCredentials,
                DiagnosticMessage.suggestionUpdateSessionKey,
                DiagnosticMessage.suggestionCheckBrowser
            ], .medium)
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

            if let bodyString = String(data: data, encoding: .utf8) {
                let isHTML = bodyString.contains("<!DOCTYPE html>") || bodyString.contains("<html")
                let hasCloudflare = bodyString.localizedCaseInsensitiveContains("cloudflare") ||
                                    bodyString.contains("Just a moment")

                if isHTML && hasCloudflare {
                    let step = DiagnosticStep(
                        name: stepName, success: false,
                        httpStatusCode: statusCode, responseTime: responseTime,
                        responseType: .html, errorType: .cloudflareBlocked,
                        errorDescription: "Cloudflare blocked the session endpoint",
                        responseHeaders: headers,
                        responseBodyPreview: String(bodyString.prefix(500)),
                        cloudflareChallenge: true,
                        cfMitigated: headers["cf-mitigated"] != nil,
                        notes: nil
                    )
                    return (step, nil)
                }
            }

            if statusCode == 401 || statusCode == 403 {
                let step = DiagnosticStep(
                    name: stepName, success: false,
                    httpStatusCode: statusCode, responseTime: responseTime,
                    responseType: .unknown, errorType: .sessionTokenInvalid,
                    errorDescription: "Session token rejected (HTTP \(statusCode))",
                    responseHeaders: headers,
                    responseBodyPreview: nil,
                    cloudflareChallenge: false,
                    cfMitigated: headers["cf-mitigated"] != nil,
                    notes: nil
                )
                return (step, nil)
            }

            let decoder = JSONDecoder()
            if let sessionResponse = try? decoder.decode(CodexSessionResponse.self, from: data),
               let accessToken = sessionResponse.accessToken, !accessToken.isEmpty {

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

                let step = DiagnosticStep(
                    name: stepName, success: true,
                    httpStatusCode: statusCode, responseTime: responseTime,
                    responseType: .json, errorType: nil, errorDescription: nil,
                    responseHeaders: headers,
                    responseBodyPreview: "Session response received (user: \(sessionResponse.user?.email ?? "unknown"))",
                    cloudflareChallenge: false,
                    cfMitigated: headers["cf-mitigated"] != nil,
                    notes: notes
                )
                return (step, accessToken)
            }

            // 解析失败
            let bodyPreview = String(data: data, encoding: .utf8).map { String($0.prefix(500)) }
            let step = DiagnosticStep(
                name: stepName, success: false,
                httpStatusCode: statusCode, responseTime: responseTime,
                responseType: .unknown, errorType: .decodingError,
                errorDescription: "Session response could not be parsed",
                responseHeaders: headers,
                responseBodyPreview: bodyPreview,
                cloudflareChallenge: false,
                cfMitigated: headers["cf-mitigated"] != nil,
                notes: nil
            )
            return (step, nil)

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

            let bodyPreview = data.isEmpty ? nil : String(data: data, encoding: .utf8).map { String($0.prefix(500)) }
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
