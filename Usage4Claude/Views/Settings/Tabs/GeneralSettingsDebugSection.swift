//
//  GeneralSettingsDebugSection.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 通用设置页的调试模式卡片（仅 Debug 编译可见）
/// 从 GeneralSettingsView 拆出，便于保持单文件体量可控
#if DEBUG
struct GeneralSettingsDebugSection: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var tokenRefreshStatus: String? = nil
    @State private var isTestingTokenRefresh = false
    @State private var silentRefreshStatus: String? = nil
    @State private var isTestingSilentRefresh = false

    var body: some View {
        SettingCard(
            icon: "ladybug.fill",
            iconColor: .orange,
            title: "调试模式",
            hint: "切换场景后，点击刷新按钮查看效果"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // 启用调试模式开关
                HStack {
                    Toggle("", isOn: $settings.debugModeEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .focusable(false)
                        .labelsHidden()

                    Text("启用调试模式")

                    Spacer()

                    Text("仅Debug编译可见")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 百分比滑块（仅在启用调试模式时显示）
                if settings.debugModeEnabled {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        // 5小时限制
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("5小时限制百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugFiveHourPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            Slider(value: $settings.debugFiveHourPercentage, in: 0...100, step: 1)
                                .tint(.green)
                        }

                        // 7天限制
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("7天限制百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugSevenDayPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                            }
                            Slider(value: $settings.debugSevenDayPercentage, in: 0...100, step: 1)
                                .tint(.purple)
                        }

                        // Extra Usage 限制
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Extra Usage 百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugExtraUsagePercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.pink)
                            }
                            Slider(value: $settings.debugExtraUsagePercentage, in: 0...100, step: 1)
                                .tint(.pink)
                        }

                        // Opus Weekly 限制
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Opus Weekly 百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugOpusPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            Slider(value: $settings.debugOpusPercentage, in: 0...100, step: 1)
                                .tint(.orange)
                        }

                        // Sonnet Weekly 限制
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Sonnet Weekly 百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugSonnetPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            Slider(value: $settings.debugSonnetPercentage, in: 0...100, step: 1)
                                .tint(.blue)
                        }

                        Divider()
                            .padding(.vertical, 2)

                        Text("Codex")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        // Codex 5小时窗口
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Codex 5小时百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugCodexPrimaryPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0))
                            }
                            Slider(value: $settings.debugCodexPrimaryPercentage, in: 0...100, step: 1)
                                .tint(Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0))
                        }

                        // Codex 7天窗口
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Codex 7天百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugCodexSecondaryPercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0))
                            }
                            Slider(value: $settings.debugCodexSecondaryPercentage, in: 0...100, step: 1)
                                .tint(Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0))
                        }

                        // Codex Extra Usage
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Codex Extra Usage 百分比：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(settings.debugCodexExtraUsagePercentage))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0))
                            }
                            Slider(value: $settings.debugCodexExtraUsagePercentage, in: 0...100, step: 1)
                                .tint(Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0))
                        }
                    }
                    .padding(.leading, 20)
                }

                // 模拟更新开关
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Toggle("", isOn: $settings.simulateUpdateAvailable)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .focusable(false)
                        .labelsHidden()

                    Text("模拟有可用更新")
                        .font(.subheadline)

                    Spacer()

                    Text("实时显示红点标识")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 单独显示所有形状图标开关
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Toggle("", isOn: $settings.debugShowAllShapesIndividually)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .focusable(false)
                        .labelsHidden()

                    Text("形状图标可单独显示")
                        .font(.subheadline)

                    Spacer()

                    Text("方便截图")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 保持详情窗口打开开关
                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Toggle("", isOn: $settings.debugKeepDetailWindowOpen)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .focusable(false)
                        .labelsHidden()

                    Text("保持详情窗口始终打开")
                        .font(.subheadline)

                    Spacer()

                    Text("背景变为不透明纯白色")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Codex 续期防线测试（仅适用于 Codex）
                Divider()
                    .padding(.vertical, 4)

                // Level 1：SSR Token 刷新
                HStack {
                    Button(action: {
                        isTestingTokenRefresh = true
                        tokenRefreshStatus = nil
                        Task { @MainActor in
                            CodexTokenRefreshCoordinator.shared.refresh { result in
                                isTestingTokenRefresh = false
                                switch result {
                                case .success(let token):
                                    tokenRefreshStatus = "✓ 成功 (\(token.prefix(16))…)"
                                case .failure:
                                    tokenRefreshStatus = "✗ 失败"
                                }
                            }
                        }
                    }) {
                        if isTestingTokenRefresh {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Level 1：SSR 刷新")
                        }
                    }
                    .disabled(isTestingTokenRefresh || !settings.hasValidCodexCredentials)
                    .controlSize(.small)

                    if let status = tokenRefreshStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.hasPrefix("✓") ? .green : .red)
                    }

                    Spacer()

                    Text("SSR bootstrap accessToken")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Level 2：隐藏 WebView 静默刷新
                HStack {
                    Button(action: {
                        isTestingSilentRefresh = true
                        silentRefreshStatus = nil
                        CodexSilentRefreshCoordinator.shared.refresh { result in
                            isTestingSilentRefresh = false
                            switch result {
                            case .success:
                                silentRefreshStatus = "✓ 成功"
                            case .failure(let error):
                                silentRefreshStatus = "✗ 失败: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        if isTestingSilentRefresh {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Level 2：WebView 刷新")
                        }
                    }
                    .disabled(isTestingSilentRefresh || !settings.hasValidCodexCredentials)
                    .controlSize(.small)

                    if let status = silentRefreshStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.hasPrefix("✓") ? .green : .red)
                    }

                    Spacer()

                    Text("隐藏 WebView 读取 cookie")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
#endif
