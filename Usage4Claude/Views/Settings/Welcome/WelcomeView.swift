//
//  WelcomeView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

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

