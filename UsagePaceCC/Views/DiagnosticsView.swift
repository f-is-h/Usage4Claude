//
//  DiagnosticsView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-11.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 诊断视图组件
/// 显示在认证设置页面底部，提供连接测试和报告导出功能
struct DiagnosticsView: View {

    @StateObject private var diagnosticManager = DiagnosticManager()
    @State private var showDetailedReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 测试按钮和状态
            HStack {
                Button(action: {
                    Task {
                        await diagnosticManager.runDiagnosticTest()
                    }
                }) {
                    HStack {
                        if diagnosticManager.isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(L.Diagnostic.testButton)
                    }
                }
                .disabled(diagnosticManager.isTesting)

                if diagnosticManager.latestReport != nil {
                    Button(L.Diagnostic.viewDetailsButton) {
                        showDetailedReport.toggle()
                    }

                    Button(L.Diagnostic.exportButton) {
                        diagnosticManager.saveReportWithDialog()
                    }
                }

                // 日志文件夹访问按钮
                Button(L.Diagnostic.openLogFolder) {
                    if let logPath = DiagnosticLogger.shared.getLogFilePath() {
                        let folderURL = URL(fileURLWithPath: logPath).deletingLastPathComponent()
                        NSWorkspace.shared.open(folderURL)
                    }
                }
            }

            // 状态消息
            if !diagnosticManager.statusMessage.isEmpty {
                Text(diagnosticManager.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 简要测试结果
            if let report = diagnosticManager.latestReport {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    // 状态指示
                    HStack {
                        Image(systemName: report.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(report.success ? .green : .red)

                        Text(report.success ? L.Diagnostic.resultSuccess : L.Diagnostic.resultFailed)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    // 关键信息
                    if let statusCode = report.httpStatusCode {
                        DetailRow(
                            label: L.Diagnostic.httpStatus,
                            value: "\(statusCode)",
                            valueColor: statusCodeColor(statusCode)
                        )
                    }

                    if let responseTime = report.responseTime {
                        DetailRow(
                            label: L.Diagnostic.responseTime,
                            value: String(format: "%.0f ms", responseTime)
                        )
                    }

                    DetailRow(
                        label: L.Diagnostic.responseType,
                        value: report.responseType.rawValue
                    )

                    if report.cloudflareChallenge {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(L.Diagnostic.cloudflareDetected)
                                .font(.caption)
                        }
                    }

                    // 诊断结果
                    if !report.success {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.Diagnostic.diagnosis)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(report.diagnosis)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !report.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.Diagnostic.suggestions)
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                ForEach(Array(report.suggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                                    Text("• \(suggestion)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
            }

            // 隐私说明
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text(L.Diagnostic.privacyNotice)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showDetailedReport) {
            DetailedReportView(report: diagnosticManager.latestReport)
        }
    }

    // MARK: - Helper Views

    private struct DetailRow: View {
        let label: String
        let value: String
        var valueColor: Color = .primary

        var body: some View {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)
            }
        }
    }

    // MARK: - Helper Methods

    private func statusCodeColor(_ code: Int) -> Color {
        switch code {
        case 200..<300:
            return .green
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .secondary
        }
    }
}

/// 详细报告视图
/// 以弹窗形式显示完整的 Markdown 格式诊断报告
struct DetailedReportView: View {

    let report: DiagnosticReport?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L.Diagnostic.detailedReportTitle)
                    .font(.headline)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 报告内容
            if let report = report {
                ScrollView {
                    Text(report.toMarkdown())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(L.Diagnostic.noReportAvailable)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()

                Button(L.Diagnostic.copyToClipboard) {
                    if let report = report {
                        let markdown = report.toMarkdown()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(markdown, forType: .string)
                    }
                }

                Button(L.Update.okButton) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: - Preview

struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .frame(width: 500)
            .padding()
    }
}
