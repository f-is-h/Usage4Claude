//
//  GeneralSettingsNotificationSection.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 通知设置卡片：总开关 + 三类提醒阈值滑块
/// 5 小时与周限额由 Claude/Codex 共用；额外用量只在最近的数据里确实有额外用量时出现
struct GeneralSettingsNotificationSection: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        SettingCard(
            icon: "bell.badge",
            iconColor: .red,
            title: L.SettingsNotification.section,
            hint: L.SettingsNotification.hint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("", isOn: $settings.notificationsEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .focusable(false)
                        .labelsHidden()
                    Text(L.SettingsNotification.enable)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    thresholdSlider(
                        title: L.LimitTypes.fiveHour,
                        values: [settings.notificationThresholds.fiveHour]
                    ) { config, newValues in
                        config.fiveHour = newValues[0]
                    }

                    thresholdSlider(
                        title: L.SettingsNotification.weeklyLimits,
                        values: [settings.notificationThresholds.weeklyLower, settings.notificationThresholds.weeklyUpper]
                    ) { config, newValues in
                        config.weeklyLower = newValues[0]
                        config.weeklyUpper = newValues[1]
                    }

                    if notificationManager.hasExtraUsage {
                        thresholdSlider(
                            title: L.LimitTypes.extraUsage,
                            values: [settings.notificationThresholds.extraUsageLower, settings.notificationThresholds.extraUsageUpper]
                        ) { config, newValues in
                            config.extraUsageLower = newValues[0]
                            config.extraUsageUpper = newValues[1]
                        }
                    }
                }
                .disabled(!settings.notificationsEnabled)

                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(L.SettingsNotification.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// 一行阈值滑块。改动整体写回一次 notificationThresholds：
    /// 周限额的两个值分两次赋值会让 didSet 带着中间状态跑一遍静默标记
    private func thresholdSlider(
        title: String,
        values: [Int],
        apply: @escaping (inout NotificationThresholdConfig, [Int]) -> Void
    ) -> some View {
        ThresholdSlider(
            title: title,
            values: values,
            range: NotificationThresholdConfig.range,
            step: NotificationThresholdConfig.step
        ) { newValues in
            guard newValues.count == values.count else { return }
            var config = settings.notificationThresholds
            apply(&config, newValues)
            settings.notificationThresholds = config.sanitized
        }
    }
}
