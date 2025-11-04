//
//  SettingsView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 设置视图
/// 使用 Toolbar 风格布局，包含通用设置、认证信息和关于三个标签页
struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    
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
            .padding(.top, 20)
            .padding(.bottom, 10)
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
/// 使用卡片式布局，包含显示设置、刷新设置和语言设置
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 显示设置卡片
                SettingCard(
                    icon: "gauge.with.dots.needle.0percent",
                    iconColor: .blue,
                    title: L.SettingsGeneral.displaySection,
                    hint: L.SettingsGeneral.menubarHint
                ) {
                    Picker("", selection: $settings.iconDisplayMode) {
                        ForEach(IconDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
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
            }
            .padding()
        }
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
            if let icon = createAppIcon(size: 100) {
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
    
    /// 创建应用图标（非模板模式）
    private func createAppIcon(size: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        let iconCopy = appIcon.copy() as! NSImage
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: size, height: size)
        return iconCopy
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
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 欢迎图标（不使用template模式）
            if let icon = createAppIcon(size: 120) {
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
    }
    
    /// 创建应用图标（非模板模式）
    private func createAppIcon(size: CGFloat) -> NSImage? {
        guard let appIcon = NSImage(named: "AppIcon") else { return nil }
        let iconCopy = appIcon.copy() as! NSImage
        iconCopy.isTemplate = false
        iconCopy.size = NSSize(width: size, height: size)
        return iconCopy
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
