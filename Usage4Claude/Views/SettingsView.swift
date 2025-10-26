//
//  SettingsView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 设置视图
/// 包含通用设置、认证信息和关于三个标签页
struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    
    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 添加顶部间距
            Spacer()
                .frame(height: 20)
            
            TabView(selection: $selectedTab) {
                // 通用设置
                GeneralSettingsView()
                    .tabItem {
                        Label(L.SettingsTab.general, systemImage: "gearshape")
                    }
                    .tag(0)
                
                // 认证设置
                AuthSettingsView()
                    .tabItem {
                        Label(L.SettingsTab.auth, systemImage: "key.fill")
                    }
                    .tag(1)
                
                // 关于
                AboutView()
                    .tabItem {
                        Label(L.SettingsTab.about, systemImage: "info.circle")
                    }
                    .tag(2)
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Settings Tabs

/// 通用设置页面
/// 包含图标显示模式、刷新频率和语言设置
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text(L.SettingsGeneral.displaySection).font(.headline)) {
                Picker(L.SettingsGeneral.menubarIcon, selection: $settings.iconDisplayMode) {
                    ForEach(IconDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(L.SettingsGeneral.menubarHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text(L.SettingsGeneral.refreshSection).font(.headline)) {
                // 刷新模式选择
                Picker(L.SettingsGeneral.refreshMode, selection: $settings.refreshMode) {
                    ForEach(RefreshMode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                // 固定频率选择（仅在选择固定模式时显示）
                if settings.refreshMode == .fixed {
                    Picker(L.SettingsGeneral.refreshInterval, selection: $settings.refreshInterval) {
                        ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.localizedName).tag(interval.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)
                }
                
                Text(settings.refreshMode == .smart ? L.SettingsGeneral.refreshHintSmart : L.SettingsGeneral.refreshHintFixed)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text(L.SettingsGeneral.languageSection).font(.headline)) {
                Picker(L.SettingsGeneral.interfaceLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.localizedName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(L.SettingsGeneral.languageHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button(L.SettingsGeneral.resetButton) {
                    settings.resetToDefaults()
                }
            }
        }
        .padding()
    }
}

/// 认证设置页面
/// 用于配置 Organization ID 和 Session Key
struct AuthSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showCopiedAlert = false
    @State private var isShowingPassword = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 说明文字
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(L.SettingsAuth.howToTitle)
                            .font(.headline)
                    }
                    
                    Text(L.SettingsAuth.step1)
                    Text(L.SettingsAuth.step2)
                    Text(L.SettingsAuth.step3)
                    Text(L.SettingsAuth.step4)
                    Text(L.SettingsAuth.step5)
                    Text(L.SettingsAuth.step6)
                    Text(L.SettingsAuth.step7)
                    
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
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Divider()
                
                // Organization ID
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.SettingsAuth.orgIdLabel)
                        .font(.headline)
                    
                    TextField(L.SettingsAuth.orgIdPlaceholder, text: $settings.organizationId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    
                    Text(L.SettingsAuth.orgIdHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Session Key
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.SettingsAuth.sessionKeyLabel)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            isShowingPassword.toggle()
                        }) {
                            Image(systemName: isShowingPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isShowingPassword {
                        TextField(L.SettingsAuth.sessionKeyPlaceholder, text: $settings.sessionKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField(L.SettingsAuth.sessionKeyPlaceholder, text: $settings.sessionKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Text(L.SettingsAuth.sessionKeyHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 验证状态
                HStack {
                    Image(systemName: settings.hasValidCredentials ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(settings.hasValidCredentials ? .green : .orange)
                    
                    Text(settings.hasValidCredentials ? L.SettingsAuth.configured : L.SettingsAuth.notConfigured)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(settings.hasValidCredentials ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
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
