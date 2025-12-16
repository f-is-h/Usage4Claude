//
//  DiagnosticManager.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-11.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

/// 诊断管理器
/// 负责执行连接测试、生成诊断报告、导出报告等功能
@MainActor
class DiagnosticManager: ObservableObject {

    // MARK: - Published Properties

    /// 是否正在进行诊断测试
    @Published var isTesting: Bool = false

    /// 最新的诊断报告
    @Published var latestReport: DiagnosticReport?

    /// 测试状态消息
    @Published var statusMessage: String = ""

    // MARK: - Private Properties

    private let settings = UserSettings.shared

    // MARK: - Public Methods

    /// 执行完整的诊断测试
    func runDiagnosticTest() async {
        await MainActor.run {
            isTesting = true
            statusMessage = L.Diagnostic.testingConnection
        }

        // 检查凭据
        guard settings.hasValidCredentials else {
            let report = createReportForMissingCredentials()
            await MainActor.run {
                self.latestReport = report
                self.isTesting = false
                self.statusMessage = L.Diagnostic.testCompleted
            }
            return
        }

        // 记录开始时间
        let startTime = Date()

        // 构建请求
        guard let request = buildDiagnosticRequest() else {
            let report = createReportForInvalidURL()
            await MainActor.run {
                self.latestReport = report
                self.isTesting = false
                self.statusMessage = L.Diagnostic.testCompleted
            }
            return
        }

        // 执行请求
        let session = URLSession(configuration: .default)

        do {
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime) * 1000 // 毫秒

            // 分析响应
            let report = analyzeResponse(data: data, response: response, responseTime: responseTime)

            await MainActor.run {
                self.latestReport = report
                self.isTesting = false
                self.statusMessage = report.success ? L.Diagnostic.testSuccess : L.Diagnostic.testFailed
            }

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            let report = createReportForNetworkError(error: error, responseTime: responseTime)

            await MainActor.run {
                self.latestReport = report
                self.isTesting = false
                self.statusMessage = L.Diagnostic.testFailed
            }
        }
    }

    /// 导出诊断报告到文件
    /// - Returns: 导出的文件路径，失败返回 nil
    func exportReport() -> URL? {
        guard let report = latestReport else {
            return nil
        }

        // 生成 Markdown 内容
        let markdown = report.toMarkdown()

        // 创建临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Usage4Claude_Diagnostic_\(formatFilenameDate()).md"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export report: \(error)")
            return nil
        }
    }

    /// 显示保存对话框并导出报告
    func saveReportWithDialog() {
        guard let report = latestReport else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = L.Diagnostic.exportTitle
        savePanel.message = L.Diagnostic.exportMessage
        savePanel.nameFieldStringValue = "Usage4Claude_Diagnostic_\(formatFilenameDate()).md"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                return
            }

            let markdown = report.toMarkdown()

            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)

                // 显示成功通知
                self.showSuccessNotification(url: url)

            } catch {
                // 显示错误通知
                self.showErrorNotification(error: error)
            }
        }
    }

    // MARK: - Private Methods - 请求构建

    private func buildDiagnosticRequest() -> URLRequest? {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/usage"

        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        // 使用统一的 Header 构建器添加完整的浏览器 Headers
        ClaudeAPIHeaderBuilder.applyHeaders(
            to: &request,
            organizationId: settings.organizationId,
            sessionKey: settings.sessionKey
        )

        return request
    }

    // MARK: - Private Methods - 响应分析

    private func analyzeResponse(data: Data, response: URLResponse, responseTime: Double) -> DiagnosticReport {
        guard let httpResponse = response as? HTTPURLResponse else {
            return createReportForUnknownResponse(data: data, responseTime: responseTime)
        }

        let statusCode = httpResponse.statusCode
        let headers = extractSafeHeaders(from: httpResponse)

        // 检查是否是 HTML 响应（Cloudflare challenge）
        if let bodyString = String(data: data, encoding: .utf8) {
            let isHTML = bodyString.contains("<!DOCTYPE html>") || bodyString.contains("<html")
            let containsCloudflare = bodyString.localizedCaseInsensitiveContains("cloudflare") ||
                                     bodyString.contains("cf-mitigated") ||
                                     bodyString.contains("Just a moment")

            if isHTML && (statusCode == 403 || containsCloudflare) {
                return createReportForCloudflareBlock(
                    statusCode: statusCode,
                    headers: headers,
                    bodyPreview: String(bodyString.prefix(500)),
                    responseTime: responseTime
                )
            }

            // 尝试解析 JSON
            if let json = try? JSONDecoder().decode(UsageResponse.self, from: data) {
                return createReportForSuccess(
                    statusCode: statusCode,
                    headers: headers,
                    usageData: json,
                    responseTime: responseTime
                )
            }

            // JSON 解析失败
            return createReportForDecodingError(
                statusCode: statusCode,
                headers: headers,
                bodyPreview: String(bodyString.prefix(500)),
                responseTime: responseTime
            )
        }

        // 无法读取响应体
        return createReportForUnknownResponse(
            data: data,
            responseTime: responseTime,
            statusCode: statusCode,
            headers: headers
        )
    }

    // MARK: - Private Methods - 报告生成

    private func createReportForSuccess(
        statusCode: Int,
        headers: [String: String],
        usageData: UsageResponse,
        responseTime: Double
    ) -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: true,
            httpStatusCode: statusCode,
            responseTime: responseTime,
            responseType: .json,
            errorType: nil,
            errorDescription: nil,
            responseHeaders: headers,
            responseBodyPreview: "Valid usage data received (utilization: \(usageData.five_hour.utilization)%)",
            cloudflareChallenge: false,
            cfMitigated: headers["cf-mitigated"] != nil,
            diagnosis: DiagnosticMessage.diagnosisSuccess,
            suggestions: [DiagnosticMessage.suggestionSuccess],
            confidence: .high
        )
    }

    private func createReportForCloudflareBlock(
        statusCode: Int,
        headers: [String: String],
        bodyPreview: String,
        responseTime: Double
    ) -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: false,
            httpStatusCode: statusCode,
            responseTime: responseTime,
            responseType: .html,
            errorType: .cloudflareBlocked,
            errorDescription: L.Error.cloudflareBlocked,
            responseHeaders: headers,
            responseBodyPreview: bodyPreview,
            cloudflareChallenge: true,
            cfMitigated: headers["cf-mitigated"] != nil,
            diagnosis: DiagnosticMessage.diagnosisCloudflare,
            suggestions: [
                DiagnosticMessage.suggestionVisitBrowser,
                DiagnosticMessage.suggestionWaitAndRetry,
                DiagnosticMessage.suggestionCheckVPN,
                DiagnosticMessage.suggestionUseSmartMode
            ],
            confidence: .high
        )
    }

    private func createReportForDecodingError(
        statusCode: Int,
        headers: [String: String],
        bodyPreview: String,
        responseTime: Double
    ) -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: false,
            httpStatusCode: statusCode,
            responseTime: responseTime,
            responseType: .unknown,
            errorType: .decodingError,
            errorDescription: L.Error.decodingFailed,
            responseHeaders: headers,
            responseBodyPreview: bodyPreview,
            cloudflareChallenge: false,
            cfMitigated: headers["cf-mitigated"] != nil,
            diagnosis: DiagnosticMessage.diagnosisDecoding,
            suggestions: [
                DiagnosticMessage.suggestionVerifyCredentials,
                DiagnosticMessage.suggestionUpdateSessionKey,
                DiagnosticMessage.suggestionCheckBrowser
            ],
            confidence: .medium
        )
    }

    private func createReportForNetworkError(error: Error, responseTime: Double) -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: false,
            httpStatusCode: nil,
            responseTime: responseTime,
            responseType: .unknown,
            errorType: .networkError,
            errorDescription: error.localizedDescription,
            responseHeaders: [:],
            responseBodyPreview: nil,
            cloudflareChallenge: false,
            cfMitigated: false,
            diagnosis: DiagnosticMessage.diagnosisNetwork,
            suggestions: [
                DiagnosticMessage.suggestionCheckInternet,
                DiagnosticMessage.suggestionCheckFirewall,
                DiagnosticMessage.suggestionRetryLater
            ],
            confidence: .high
        )
    }

    private func createReportForMissingCredentials() -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: "Not configured",
            sessionKeyRedacted: "Not configured",
            success: false,
            httpStatusCode: nil,
            responseTime: nil,
            responseType: .unknown,
            errorType: .invalidCredentials,
            errorDescription: L.Error.noCredentials,
            responseHeaders: [:],
            responseBodyPreview: nil,
            cloudflareChallenge: false,
            cfMitigated: false,
            diagnosis: DiagnosticMessage.diagnosisNoCredentials,
            suggestions: [DiagnosticMessage.suggestionConfigureAuth],
            confidence: .high
        )
    }

    private func createReportForInvalidURL() -> DiagnosticReport {
        DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: false,
            httpStatusCode: nil,
            responseTime: nil,
            responseType: .unknown,
            errorType: .invalidCredentials,
            errorDescription: L.Error.invalidUrl,
            responseHeaders: [:],
            responseBodyPreview: nil,
            cloudflareChallenge: false,
            cfMitigated: false,
            diagnosis: DiagnosticMessage.diagnosisInvalidUrl,
            suggestions: [DiagnosticMessage.suggestionCheckOrgId],
            confidence: .high
        )
    }

    private func createReportForUnknownResponse(
        data: Data,
        responseTime: Double,
        statusCode: Int? = nil,
        headers: [String: String] = [:]
    ) -> DiagnosticReport {
        let preview: String
        if let bodyString = String(data: data, encoding: .utf8) {
            preview = String(bodyString.prefix(500))
        } else {
            preview = "Unable to decode response"
        }

        return DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            organizationIdRedacted: redactOrganizationId(settings.organizationId),
            sessionKeyRedacted: redactSessionKey(settings.sessionKey),
            success: false,
            httpStatusCode: statusCode,
            responseTime: responseTime,
            responseType: .unknown,
            errorType: .unknown,
            errorDescription: "Unknown response format",
            responseHeaders: headers,
            responseBodyPreview: preview,
            cloudflareChallenge: false,
            cfMitigated: false,
            diagnosis: DiagnosticMessage.diagnosisUnknown,
            suggestions: [
                DiagnosticMessage.suggestionExportAndShare,
                DiagnosticMessage.suggestionContactSupport
            ],
            confidence: .low
        )
    }

    // MARK: - Private Methods - 数据脱敏

    /// 脱敏 Organization ID
    /// 例如: "12345678-abcd-ef90-1234-567890abcdef" -> "1234...cdef"
    /// 脱敏 Organization ID
    /// 使用统一的脱敏工具
    private func redactOrganizationId(_ orgId: String) -> String {
        return SensitiveDataRedactor.redactOrganizationId(orgId)
    }

    /// 脱敏 Session Key
    /// 使用统一的脱敏工具
    private func redactSessionKey(_ sessionKey: String) -> String {
        return SensitiveDataRedactor.redactSessionKey(sessionKey)
    }

    /// 从 HTTP 响应中提取安全的头信息（过滤敏感数据）
    private func extractSafeHeaders(from response: HTTPURLResponse) -> [String: String] {
        var safeHeaders: [String: String] = [:]

        // 允许的头信息列表
        let allowedHeaders = [
            "content-type",
            "content-length",
            "cf-mitigated",
            "cf-ray",
            "server",
            "date",
            "cache-control",
            "x-request-id"
        ]

        for (key, value) in response.allHeaderFields {
            let keyStr = (key as? String ?? "").lowercased()
            if allowedHeaders.contains(keyStr) {
                safeHeaders[keyStr] = value as? String ?? ""
            }
        }

        return safeHeaders
    }

    // MARK: - Private Methods - 系统信息

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func getArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private func formatFilenameDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Private Methods - 通知

    private func showSuccessNotification(url: URL) {
        let alert = NSAlert()
        alert.messageText = L.Diagnostic.exportSuccessTitle
        alert.informativeText = L.Diagnostic.exportSuccessMessage + "\n\n\(url.path)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.Update.okButton)
        alert.runModal()
    }

    private func showErrorNotification(error: Error) {
        let alert = NSAlert()
        alert.messageText = L.Diagnostic.exportErrorTitle
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.Update.okButton)
        alert.runModal()
    }
}
