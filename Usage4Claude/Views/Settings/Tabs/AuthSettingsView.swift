//
//  AuthSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 认证设置页面
/// 使用卡片式布局，用于配置 Session Key
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
                                        Text(L.Welcome.validFormat)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text(L.Welcome.invalidFormat)
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
        .onChange(of: settings.sessionKey) { newValue in
            // 当 sessionKey 改变且有效时，自动获取 Organization ID
            if settings.isValidSessionKey(newValue) {
                // 延迟一小段时间以避免频繁请求
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    fetchOrganizationId()
                }
            }
        }
    }

    // MARK: - Private Methods

    /// 获取 Organization ID（后台自动执行，无UI反馈）
    private func fetchOrganizationId() {
        // 调用 API 获取 organizations
        let apiService = ClaudeAPIService()
        apiService.fetchOrganizations { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let organizations):
                    if let firstOrg = organizations.first {
                        // 使用第一个组织的 UUID 作为 Organization ID
                        settings.organizationId = firstOrg.uuid
                    }
                case .failure:
                    // 静默失败，不显示错误信息
                    break
                }
            }
        }
    }
}

/// 关于页面
/// 显示应用信息、版本号和相关链接
