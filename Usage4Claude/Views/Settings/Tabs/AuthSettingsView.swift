//
//  AuthSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

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
