//
//  GeneralSettingsDisplaySection.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 通用设置页的"显示设置"卡片：菜单栏图标样式 + 显示内容（图标/百分比）开关
/// 从 GeneralSettingsView 拆出，便于保持单文件体量可控
struct GeneralSettingsDisplaySection: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
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
                    .focusable(false)

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

                    HStack(spacing: 16) {
                        Toggle(isOn: Binding(
                            get: { settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both },
                            set: { showIcon in
                                let showPercentage = settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both
                                if showIcon && showPercentage {
                                    settings.iconDisplayMode = .both
                                } else if showIcon {
                                    settings.iconDisplayMode = .iconOnly
                                } else {
                                    settings.iconDisplayMode = .percentageOnly
                                }
                            }
                        )) {
                            Text(L.Display.showIcon)
                        }
                        .toggleStyle(.checkbox)
                        .focusable(false)
                        .disabled(settings.iconDisplayMode == .iconOnly)

                        Toggle(isOn: Binding(
                            get: { settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both },
                            set: { showPercentage in
                                let showIcon = settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both
                                if showIcon && showPercentage {
                                    settings.iconDisplayMode = .both
                                } else if showPercentage {
                                    settings.iconDisplayMode = .percentageOnly
                                } else {
                                    settings.iconDisplayMode = .iconOnly
                                }
                            }
                        )) {
                            Text(L.Display.showPercentage)
                        }
                        .toggleStyle(.checkbox)
                        .focusable(false)
                        .disabled(settings.iconDisplayMode == .percentageOnly)
                    }
                }
            }
        }
    }
}
