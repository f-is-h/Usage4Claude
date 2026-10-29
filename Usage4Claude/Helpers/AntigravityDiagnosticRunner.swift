//
//  AntigravityDiagnosticRunner.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//

import Foundation

/// Antigravity 诊断：检查 agy 是否安装，再通过服务层实际跑一次 `/usage`
///
/// 与 Codex OAuth 诊断一致，直接复用 `AntigravityAPIService.fetchUsageResult()`，
/// 不另起一套调用路径，诊断看到的就是刷新时真实走的那条路。
/// 报告文案与 DiagnosticMessage 一样只用英文，不走本地化。
@MainActor
final class AntigravityDiagnosticRunner: DiagnosticRunner {

    let providerType: ProviderType = .antigravity

    func run() async -> ProviderDiagnosticResult {
        guard let cliURL = AntigravityAPIService.locateCLI(refresh: true) else {
            return ProviderDiagnosticResult(
                providerType: .antigravity,
                credentials: ["agy CLI": "Not found"],
                steps: [],
                success: false,
                errorType: .invalidCredentials,
                diagnosis: "The Antigravity CLI (agy) was not found. Searched: "
                    + AntigravityAPIService.cliCandidatePaths.joined(separator: ", "),
                suggestions: ["Install the Antigravity CLI and sign in by running `agy` once in a terminal."],
                confidence: .high
            )
        }

        let credentials = ["agy CLI": cliURL.path, "Auth": "Managed by agy (not read by this app)"]
        let startTime = Date()
        let result = await AntigravityAPIService.shared.fetchUsageResult()
        let responseTime = Date().timeIntervalSince(startTime)

        let step: DiagnosticStep
        let diagnosis: String
        let suggestions: [String]

        switch result {
        case .success(let data):
            let windows = AntigravityUsageData.limitTypes
                .compactMap { type in data.limit(for: type).map { "\(type.rawValue)=\(Int($0.percentage))%" } }
                .joined(separator: ", ")
            step = DiagnosticStep(
                name: "agy -p /usage", success: true,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .json, errorType: nil, errorDescription: nil,
                responseHeaders: [:],
                responseBodyPreview: windows.isEmpty ? "No quota windows returned" : windows,
                cloudflareChallenge: false, cfMitigated: false, notes: nil
            )
            diagnosis = "agy returned valid quota data."
            suggestions = []

        case .failure(let error):
            let antigravityError = error as? AntigravityError
            let errorType: DiagnosticErrorType
            let advice: String
            switch antigravityError {
            case .notLoggedIn:
                errorType = .authenticationFailed
                advice = "Run `agy` in a terminal and sign in to Antigravity."
            case .timeout:
                errorType = .timeout
                advice = "agy did not respond in time. Check the network and try again."
            case .malformedOutput:
                errorType = .decodingError
                advice = "agy's output format may have changed. Check `agy -p /usage --output-format json` in a terminal."
            default:
                errorType = .unknown
                advice = "Run `agy -p /usage --output-format json` in a terminal to see the full error."
            }
            step = DiagnosticStep(
                name: "agy -p /usage", success: false,
                httpStatusCode: nil, responseTime: responseTime,
                responseType: .unknown, errorType: errorType,
                errorDescription: error.localizedDescription,
                responseHeaders: [:], responseBodyPreview: nil,
                cloudflareChallenge: false, cfMitigated: false, notes: nil
            )
            diagnosis = "agy failed: \(error.localizedDescription)"
            suggestions = [advice]
        }

        return ProviderDiagnosticResult(
            providerType: .antigravity,
            credentials: credentials,
            steps: [step],
            success: step.success,
            errorType: step.errorType,
            diagnosis: diagnosis,
            suggestions: suggestions,
            confidence: .high
        )
    }
}
