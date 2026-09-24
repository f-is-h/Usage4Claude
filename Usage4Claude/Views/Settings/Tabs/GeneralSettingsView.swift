//
//  GeneralSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import ServiceManagement

/// 「通用」设置页
/// 管理应用自身的行为：语言、开机启动、恢复默认设置，以及 DEBUG 下的调试开关
/// 显示相关的卡片在 DisplaySettingsView，刷新与通知在 DataSettingsView
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        DocsScrollView {
            VStack(spacing: 16) {
                // 语言设置卡片
                SettingCard(
                    icon: "globe",
                    iconColor: .orange,
                    title: L.SettingsGeneral.languageSection,
                    hint: L.SettingsGeneral.languageHint
                ) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.localizedName).tag(lang)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .focusable(false)
                }

                // 开机启动设置卡片
                SettingCard(
                    icon: "power",
                    iconColor: .orange,
                    title: L.SettingsGeneral.launchSection,
                    hint: L.SettingsGeneral.launchHint
                ) {
                    HStack {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .focusable(false)
                            .labelsHidden()

                        Text(L.SettingsGeneral.launchAtLogin)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                                .font(.caption)
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 重置按钮：resetToDefaults 会重置全部标签页的设置，不只是本页，
                // 所以按钮文案写的是「所有」，位置也放在这一页而不是「显示」页
                HStack {
                    Spacer()
                    Button(L.SettingsGeneral.resetButton) {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
                }
                .padding(.top, 8)

                #if DEBUG
                GeneralSettingsDebugSection()
                #endif
            }
            .padding()
        }
        .onAppear {
            // 设置页面打开时同步状态
            settings.syncLaunchAtLoginStatus()

            // 监听错误通知
            NotificationCenter.default.addObserver(
                forName: .launchAtLoginError,
                object: nil,
                queue: .main
            ) { notification in
                handleLaunchError(notification)
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(L.LaunchAtLogin.errorTitle),
                message: Text(errorMessage),
                dismissButton: .default(Text(L.Update.okButton))
            )
        }
    }

    // MARK: - Computed Properties

    /// 状态图标
    private var statusIcon: String {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return "checkmark.circle.fill"
        case .requiresApproval:
            return "exclamationmark.circle.fill"
        case .notRegistered:
            return "circle"
        case .notFound:
            return "xmark.circle.fill"
        @unknown default:
            // 未知状态按未启用处理，会在 onAppear 时同步真实状态
            return "circle"
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return .green
        case .requiresApproval:
            return .orange
        case .notRegistered:
            return .secondary
        case .notFound:
            return .red
        @unknown default:
            // 未知状态按未启用处理
            return .secondary
        }
    }

    /// 状态文本
    private var statusText: String {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return L.LaunchAtLogin.statusEnabled
        case .requiresApproval:
            return L.LaunchAtLogin.statusRequiresApproval
        case .notRegistered:
            return L.LaunchAtLogin.statusDisabled
        case .notFound:
            return L.LaunchAtLogin.statusNotFound
        @unknown default:
            // 未知状态按未启用处理
            return L.LaunchAtLogin.statusDisabled
        }
    }

    // MARK: - Error Handling

    /// 处理开机启动错误
    private func handleLaunchError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let error = userInfo["error"] as? Error,
              let operation = userInfo["operation"] as? String else {
            return
        }

        let operationType = operation == "enable" ? L.LaunchAtLogin.errorEnable : L.LaunchAtLogin.errorDisable
        errorMessage = "\(operationType)\n\n\(error.localizedDescription)"
        showErrorAlert = true
    }
}
