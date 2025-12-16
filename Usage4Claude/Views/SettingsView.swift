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

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
