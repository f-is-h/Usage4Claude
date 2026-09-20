//
//  DataSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-20.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// 「数据」设置页
/// 管理数据怎么来、什么时候提醒：刷新策略、通知阈值、Codex 重置预告
struct DataSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                        .focusable(false)

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
                                .focusable(false)
                                .frame(width: 120)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }

                // 通知设置卡片
                GeneralSettingsNotificationSection()

                // Codex 重置预告卡片（Beta）：状态驱动，只登录 Claude 时完全不出现这个词
                if settings.hasValidCodexCredentials {
                    SettingCard(
                        icon: "bell.and.waves.left.and.right",
                        iconColor: .teal,
                        title: L.SettingsGeneral.codexAnnouncementSection,
                        hint: L.SettingsGeneral.codexAnnouncementHint
                    ) {
                        HStack {
                            Toggle("", isOn: $settings.showCodexResetAnnouncement)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()
                            Text(L.SettingsGeneral.codexAnnouncementEnable)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 预览
struct DataSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DataSettingsView()
    }
}
