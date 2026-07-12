//
//  GeneralSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import ServiceManagement

/// 通用设置页面
/// 使用卡片式布局，包含开机启动、显示设置、刷新设置和语言设置
/// 各卡片内容按主题拆到 GeneralSettings*Section.swift，保持本文件体量可控
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GeneralSettingsDisplaySection()
                GeneralSettingsDisplayOptionsSection()

                // 刷新设置卡片
                SettingCard(
                    icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90",
                    iconColor: .green,
                    title: L.SettingsGeneral.refreshSection,
                    hint: settings.refreshMode == .smart ? L.SettingsGeneral.refreshHintSmart : L.SettingsGeneral.refreshHintFixed
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 刷新模式选择
                        Picker("", selection: $settings.refreshMode) {
                            ForEach(RefreshMode.allCases, id: \.self) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .focusable(false)

                        // 固定频率选择（仅在选择固定模式时显示）
                        if settings.refreshMode == .fixed {
                            HStack {
                                Text(L.SettingsGeneral.refreshInterval)
                                    .foregroundColor(.secondary)

                                Picker("", selection: $settings.refreshInterval) {
                                    ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                                        Text(interval.localizedName).tag(interval.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }

                // 通知设置卡片
                SettingCard(
                    icon: "bell.badge",
                    iconColor: .red,
                    title: L.SettingsNotification.section,
                    hint: L.SettingsNotification.hint
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("", isOn: $settings.notificationsEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()
                            Text(L.SettingsNotification.enable)
                            Spacer()
                        }
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(L.SettingsNotification.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // 外观设置卡片
                SettingCard(
                    icon: "circle.lefthalf.filled",
                    iconColor: .indigo,
                    title: L.SettingsGeneralAppearance.section,
                    hint: L.SettingsGeneralAppearance.hint
                ) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .focusable(false)
                }

                // 时间格式设置卡片
                SettingCard(
                    icon: "clock",
                    iconColor: .cyan,
                    title: L.SettingsGeneralTimeFormat.section,
                    hint: L.SettingsGeneralTimeFormat.hint
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $settings.timeFormatPreference) {
                            ForEach(TimeFormatPreference.allCases, id: \.self) { format in
                                Text(format.localizedName).tag(format)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .focusable(false)

                        // 当前时间预览
                        HStack(spacing: 4) {
                            Text(L.SettingsGeneralTimeFormat.preview + ":")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timePreviewString)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 20)
                    }
                }

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

                // 重置按钮
                HStack {
                    Spacer()
                    Button(L.SettingsGeneral.resetButton) {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.borderedProminent)
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

    /// 时间预览字符串
    private var timePreviewString: String {
        let now = Date()
        return TimeFormatHelper.formatTimeOnly(now)
    }

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
