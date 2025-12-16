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
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 开机启动设置卡片
                SettingCard(
                    icon: "power",
                    iconColor: .orange,
                    title: L.SettingsGeneral.launchSection,
                    hint: L.SettingsGeneral.launchHint
                ) {
                    HStack {
                        // 开关在左侧
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)   // 使用最小尺寸
                            .focusable(false)     // 移除默认 Focus
                            .labelsHidden()       // 隐藏默认标签
                        
                        // 文字标签
                        Text(L.SettingsGeneral.launchAtLogin)
                        
                        Spacer()
                        
                        // 状态指示器
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
                
                // 显示设置卡片
                SettingCard(
                    icon: "gauge.with.dots.needle.0percent",
                    iconColor: .blue,
                    title: L.SettingsGeneral.displaySection,
                    hint: L.SettingsGeneral.menubarHint
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 图标样式选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.SettingsGeneral.menubarTheme)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $settings.iconStyleMode) {
                                ForEach(IconStyleMode.allCases, id: \.self) { mode in
                                    Text(mode.localizedName).tag(mode)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                            
                            // 描述文字
                            if !settings.iconStyleMode.description.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text(settings.iconStyleMode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                        
                        // 显示内容选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.SettingsGeneral.displayContent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $settings.iconDisplayMode) {
                                ForEach(IconDisplayMode.allCases, id: \.self) { mode in
                                    // 单色模式下禁用"仅显示图标"和"同时显示"选项
                                    if settings.iconStyleMode == .monochrome && (mode == .iconOnly || mode == .both) {
                                        Text(mode.localizedName)
                                            .tag(mode)
                                            .disabled(true)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(mode.localizedName).tag(mode)
                                    }
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                            
                            // 提示信息（单色模式下）
                            if settings.iconStyleMode == .monochrome {
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(L.SettingsGeneral.monochromeNoIconHint)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                }
                
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

                // MARK: - 调试模式区域（仅Debug编译可见）

                #if DEBUG
                // 调试设置卡片
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

                        // 模拟更新开关（独立于调试模式）
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

                            Text("重启菜单栏查看效果")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 场景选择（仅在启用调试模式时显示）
                        if settings.debugModeEnabled {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("模拟数据场景：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)

                                Picker("", selection: $settings.debugScenario) {
                                    ForEach(UserSettings.DebugScenario.allCases, id: \.self) { scenario in
                                        Text(scenario.displayName).tag(scenario)
                                    }
                                }
                                .pickerStyle(.segmented)

                                // 百分比设置（仅在非真实数据场景时显示）
                                if settings.debugScenario != .realData {
                                    Divider()
                                        .padding(.vertical, 4)

                                    VStack(alignment: .leading, spacing: 12) {
                                        // 5小时百分比滑块（仅在 fiveHourOnly 或 both 场景显示）
                                        if settings.debugScenario == .fiveHourOnly || settings.debugScenario == .both {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text("5小时限制百分比：")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(Int(settings.debugFiveHourPercentage))%")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.blue)
                                                }

                                                Slider(
                                                    value: $settings.debugFiveHourPercentage,
                                                    in: 0...100,
                                                    step: 1
                                                )
                                                .tint(.blue)
                                            }
                                        }

                                        // 7天百分比滑块（仅在 sevenDayOnly 或 both 场景显示）
                                        if settings.debugScenario == .sevenDayOnly || settings.debugScenario == .both {
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

                                                Slider(
                                                    value: $settings.debugSevenDayPercentage,
                                                    in: 0...100,
                                                    step: 1
                                                )
                                                .tint(.purple)
                                            }
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
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

/// 认证设置页面
/// 使用卡片式布局，用于配置 Organization ID 和 Session Key
