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
/// 根据已配置的账户自动选择对应的 runner 执行诊断测试，汇总结果生成多 provider 报告
@MainActor
class DiagnosticManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isTesting: Bool = false
    @Published var latestReport: DiagnosticReport?
    @Published var statusMessage: String = ""

    // MARK: - Private Properties

    private let settings = UserSettings.shared

    // MARK: - Public Methods

    /// 执行完整的诊断测试（自动按已配置账户决定测试范围）
    func runDiagnosticTest() async {
        isTesting = true
        statusMessage = L.Diagnostic.testingConnection

        let runners = buildRunners()

        guard !runners.isEmpty else {
            latestReport = buildNoAccountsReport()
            isTesting = false
            statusMessage = L.Diagnostic.testCompleted
            return
        }

        var providerResults: [ProviderDiagnosticResult] = []
        for runner in runners {
            let result = await runner.run()
            providerResults.append(result)
        }

        let report = DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            providers: providerResults
        )

        latestReport = report
        isTesting = false
        statusMessage = report.overallSuccess ? L.Diagnostic.testSuccess : L.Diagnostic.testFailed
    }

    /// 显示保存对话框并导出报告
    func saveReportWithDialog() {
        guard let report = latestReport else { return }

        let savePanel = NSSavePanel()
        savePanel.title = L.Diagnostic.exportTitle
        savePanel.message = L.Diagnostic.exportMessage
        savePanel.nameFieldStringValue = "Usage4Claude_Diagnostic_\(formatFilenameDate()).md"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try report.toMarkdown().write(to: url, atomically: true, encoding: .utf8)
                self.showSuccessNotification(url: url)
            } catch {
                self.showErrorNotification(error: error)
            }
        }
    }

    // MARK: - Private Methods

    private func buildRunners() -> [any DiagnosticRunner] {
        var runners: [any DiagnosticRunner] = []
        if !settings.accounts.isEmpty {
            runners.append(ClaudeDiagnosticRunner())
        }
        if !settings.codexAccounts.isEmpty {
            runners.append(CodexDiagnosticRunner())
        }
        return runners
    }

    private func buildNoAccountsReport() -> DiagnosticReport {
        let noAccountsResult = ProviderDiagnosticResult(
            providerType: .claude,
            credentials: [:],
            steps: [],
            success: false,
            errorType: .invalidCredentials,
            diagnosis: DiagnosticMessage.diagnosisNoCredentials,
            suggestions: [DiagnosticMessage.suggestionConfigureAuth],
            confidence: .high
        )
        return DiagnosticReport(
            timestamp: Date(),
            appVersion: getAppVersion(),
            osVersion: getOSVersion(),
            architecture: getArchitecture(),
            locale: settings.language.rawValue,
            refreshMode: settings.refreshMode == .smart ? "Smart" : "Fixed",
            refreshInterval: settings.refreshMode == .fixed ? "\(settings.refreshInterval) min" : nil,
            displayMode: settings.iconDisplayMode.rawValue,
            providers: [noAccountsResult]
        )
    }

    // MARK: - System Info

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

    // MARK: - Notifications

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
