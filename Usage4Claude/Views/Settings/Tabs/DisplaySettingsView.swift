//
//  DisplaySettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-20.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// 「显示」设置页
/// 管理用户看到的样子：菜单栏外观、显示哪些限额、图表样式、明暗外观、时间格式
struct DisplaySettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GeneralSettingsDisplaySection()
                GeneralSettingsDisplayOptionsSection()

                // 图表样式卡片
                SettingCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .cyan,
                    title: L.GraphStyle.title,
                    hint: L.GraphStyle.hint
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $settings.graphDisplayType) {
                            ForEach(GraphDisplayType.allCases, id: \.self) { type in
                                Text(type.localizedName).tag(type)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .focusable(false)

                        // 描述文字
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(settings.graphDisplayType == .circular
                                ? L.GraphStyle.circularDescription
                                : L.GraphStyle.linearDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 20)

                        // 仅工作日（只对线性图有意义）
                        if settings.graphDisplayType == .linear {
                            HStack {
                                Toggle("", isOn: $settings.linearGraphWeekdaysOnly)
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .focusable(false)
                                    .labelsHidden()
                                Text(L.GraphStyle.weekdaysOnly)
                                Spacer()
                            }

                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(L.GraphStyle.weekdaysOnlyDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }

                // 外观设置卡片
                SettingCard(
                    icon: "circle.lefthalf.filled",
                    iconColor: .indigo,
                    title: L.SettingsGeneralAppearance.section,
                    hint: L.SettingsGeneralAppearance.hint
                ) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .focusable(false)
                }

                // 时间格式设置卡片
                SettingCard(
                    icon: "clock",
                    iconColor: .cyan,
                    title: L.SettingsGeneralTimeFormat.section,
                    hint: L.SettingsGeneralTimeFormat.hint
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $settings.timeFormatPreference) {
                            ForEach(TimeFormatPreference.allCases, id: \.self) { format in
                                Text(format.localizedName).tag(format)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .focusable(false)

                        // 当前时间预览
                        HStack(spacing: 4) {
                            Text(L.SettingsGeneralTimeFormat.preview + ":")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(TimeFormatHelper.formatTimeOnly(Date()))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 预览
struct DisplaySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DisplaySettingsView()
    }
}
