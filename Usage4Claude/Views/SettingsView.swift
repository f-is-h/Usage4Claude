//
//  SettingsView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import ServiceManagement

/// 设置视图
/// 使用 Toolbar 风格布局，包含通用设置、认证信息和关于三个标签页
struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared
    
    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar 风格的标签导航
            HStack(spacing: 0) {
                // 通用设置按钮
                ToolbarButton(
                    icon: "gearshape",
                    title: L.SettingsTab.general,
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                // 分隔符
                TabDivider()
                
                // 认证设置按钮
                ToolbarButton(
                    icon: "key.horizontal",
                    title: L.SettingsTab.auth,
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                // 分隔符
                TabDivider()
                
                // 关于按钮
                ToolbarButton(
                    icon: "info.circle",
                    title: L.SettingsTab.about,
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal)
            .padding(.top, 7)
            .padding(.bottom, 7)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    GeneralSettingsView()
                case 1:
                    AuthSettingsView()
                case 2:
                    AboutView()
                default:
                    GeneralSettingsView()
                }
            }
        }
        .frame(width: 500, height: 550)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
    }
}

// MARK: - Toolbar Button Component

/// Toolbar 风格的按钮组件
struct ToolbarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())  // 扩大点击区域到整个背景
        }
        .buttonStyle(.plain)
        .focusable(false)  // 移除Focus效果
    }
}

/// 标签页分隔符
/// 优雅的渐变短竖线，两头透明渐变
struct TabDivider: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.secondary.opacity(0.0),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: 35)
        .padding(.horizontal, 8)
    }
}

// MARK: - Reusable Setting Card Component

/// 可复用的设置卡片组件
/// 提供统一的卡片式布局，包含图标、标题、内容和提示信息
struct SettingCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let hint: String
    @ViewBuilder let content: Content
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        hint: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.hint = hint
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行：图标 + 标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // 内容区域
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading, 32)
            
            // 提示信息
            if !hint.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(hint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 32)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.03))
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Settings Tabs

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
struct AuthSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showCopiedAlert = false
    @State private var isShowingPassword = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 认证信息卡片（合并 Org ID + Session Key + 状态）
                SettingCard(
                    icon: "lock.shield",
                    iconColor: .blue,
                    title: L.SettingsAuth.credentialsTitle,
                    hint: ""
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Organization ID 区域
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(.purple)
                                    .font(.subheadline)
                                Text(L.SettingsAuth.orgIdLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            TextField(L.SettingsAuth.orgIdPlaceholder, text: $settings.organizationId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            // 验证状态提示
                            if !settings.organizationId.isEmpty {
                                if settings.isValidOrganizationId(settings.organizationId) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("格式正确")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("Organization ID 应为 UUID 格式")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(L.SettingsAuth.orgIdHint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Session Key 区域
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Text(L.SettingsAuth.sessionKeyLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                if isShowingPassword {
                                    TextField(L.SettingsAuth.sessionKeyPlaceholder, text: $settings.sessionKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    SecureField(L.SettingsAuth.sessionKeyPlaceholder, text: $settings.sessionKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Button(action: {
                                    isShowingPassword.toggle()
                                }) {
                                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(isShowingPassword ? L.SettingsAuth.hidePassword : L.SettingsAuth.showPassword)
                            }

                            // 验证状态提示
                            if !settings.sessionKey.isEmpty {
                                if settings.isValidSessionKey(settings.sessionKey) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("格式正确")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text("Session Key 长度应在 20-500 字符之间")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(L.SettingsAuth.sessionKeyHint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // 配置状态区域
                        HStack(spacing: 12) {
                            Image(systemName: settings.hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(settings.hasValidCredentials ? .green : .orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settings.hasValidCredentials ? L.SettingsAuth.configured : L.SettingsAuth.notConfigured)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(settings.hasValidCredentials ? .green : .orange)
                                
                                if settings.hasValidCredentials {
                                    Text(L.SettingsAuth.readyToUse)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(L.SettingsAuth.needCredentials)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 说明卡片
                SettingCard(
                    icon: "book.fill",
                    iconColor: .blue,
                    title: L.SettingsAuth.howToTitle,
                    hint: ""
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.SettingsAuth.step1)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step2)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step3)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step4)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step5)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step6)
                            .font(.subheadline)
                        Text(L.SettingsAuth.step7)
                            .font(.subheadline)
                        
                        Button(action: {
                            if let url = URL(string: "https://claude.ai/settings/usage") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                Text(L.SettingsAuth.openBrowser)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                }

                // 诊断卡片
                SettingCard(
                    icon: "stethoscope",
                    iconColor: .blue,
                    title: L.Diagnostic.sectionTitle,
                    hint: ""
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.Diagnostic.sectionDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // 诊断组件
                        DiagnosticsView()
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
    }
}

/// 关于页面
/// 显示应用信息、版本号和相关链接
struct AboutView: View {
    /// 从 Bundle 中读取应用版本号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标（不使用template模式）
            if let icon = ImageHelper.createAppIcon(size: 100) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(radius: 5)
            }
            
            // 应用名称和版本
            VStack(spacing: 4) {
                Text("Usage4Claude")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(L.SettingsAbout.version(appVersion))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 描述
            Text(L.SettingsAbout.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal, 60)
            
            // 信息列表
            VStack(alignment: .leading, spacing: 12) {
                AboutInfoRow(icon: "person.fill", title: L.SettingsAbout.developer, value: "f-is-h")
                AboutInfoRow(icon: "doc.text", title: L.SettingsAbout.license, value: L.SettingsAbout.licenseValue)
            }
            
            Spacer()
            
            // 链接按钮
            VStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: "https://github.com/f-is-h/Usage4Claude") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text(L.SettingsAbout.github)
                    }
                }
                
                Button(action: {
                    if let url = URL(string: "https://ko-fi.com/1atte") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                        Text(L.SettingsAbout.coffee)
                    }
                }
            }
            
            // 版权信息
            Text(L.SettingsAbout.copyright)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

/// 关于页面信息行组件
struct AboutInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

/// 首次启动欢迎界面
/// 在用户首次启动应用时显示，引导用户配置认证信息
struct WelcomeView: View {
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 欢迎图标（不使用template模式）
            if let icon = ImageHelper.createAppIcon(size: 120) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(radius: 10)
            }
            
            // 欢迎文字
            VStack(spacing: 8) {
                Text(L.Welcome.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(L.Welcome.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // 操作按钮
            VStack(spacing: 12) {
                Button(action: {
                    settings.isFirstLaunch = false
                    dismiss()
                    // 打开设置窗口，跳转到认证信息标签页
                    NotificationCenter.default.post(name: .openSettings, object: nil, userInfo: ["tab": 1])
                }) {
                    Text(L.Welcome.setupButton)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    settings.isFirstLaunch = false
                    dismiss()
                }) {
                    Text(L.Welcome.laterButton)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 400, height: 500)
        .padding()
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
    }
}

// MARK: - Notifications

/// 设置相关通知
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openSettingsWithTab = Notification.Name("openSettingsWithTab")
}

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
