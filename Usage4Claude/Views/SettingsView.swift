//
//  SettingsView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-15.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 设置视图
/// 使用 Toolbar 风格布局，标签页定义见 SettingsTab
struct SettingsView: View {
    @State private var selectedTab: SettingsTab
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared

    init(initialTab: SettingsTab = .display) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar 风格的标签导航
            HStack(spacing: 0) {
                ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, tab in
                    if index > 0 {
                        TabDivider()
                    }

                    ToolbarButton(
                        icon: tab.icon,
                        title: tab.title,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
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
                case .display:
                    DisplaySettingsView()
                case .data:
                    DataSettingsView()
                case .accounts:
                    AuthSettingsView()
                case .general:
                    GeneralSettingsView()
                case .about:
                    AboutView()
                }
            }
        }
        .frame(width: 500, height: 550, alignment: .top)
        .id(localization.updateTrigger)  // 语言变化时重新创建视图
        .onChange(of: selectedTab) { _ in
            // 切换标签后新页面的输入框会自动拿到第一响应者（账号页的别名框），清掉保持无焦点
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }
}

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
