//
//  AboutView.swift
//  UsagePaceCC
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

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
                Text("UsagePaceCC")
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
                AboutInfoRow(icon: "person.fill", title: L.SettingsAbout.developer, value: "Yen NQ")
                AboutInfoRow(icon: "doc.text", title: L.SettingsAbout.license, value: L.SettingsAbout.licenseValue)
            }
            
            Spacer()
            
            // 链接按钮
            VStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: "https://github.com/quangyendn/UsagePaceCC") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text(L.SettingsAbout.github)
                    }
                    .frame(minWidth: 200)
                }
                .focusable(false)
            }
            
            // 版权信息
            Text(L.SettingsAbout.copyright)
                .font(.caption)
                .foregroundColor(.secondary)

            // 归因信息 — 基于 f-is-h/Usage4Claude
            Button(action: {
                if let url = URL(string: "https://github.com/f-is-h/Usage4Claude") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(L.SettingsAbout.basedOn)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .underline()
            }
            .buttonStyle(.plain)
            .focusable(false)

            // 免责声明 — 与 Anthropic 无关联
            Text(L.SettingsAbout.disclaimer)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

