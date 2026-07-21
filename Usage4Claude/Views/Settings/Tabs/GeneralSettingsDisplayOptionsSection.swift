//
//  GeneralSettingsDisplayOptionsSection.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 通用设置页的"显示选项"卡片：智能/自定义显示模式 + 自定义显示类型勾选
/// 从 GeneralSettingsView 拆出，便于保持单文件体量可控
struct GeneralSettingsDisplayOptionsSection: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        SettingCard(
            icon: "rectangle.3.group",
            iconColor: .purple,
            title: L.DisplayOptions.title,
            hint: settings.displayMode == .smart ? L.DisplayOptions.smartDisplayDescription : L.DisplayOptions.customDisplayDescription
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // 显示模式选择
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.DisplayOptions.displayModeLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.displayMode) {
                        Text(L.DisplayOptions.smartDisplay).tag(DisplayMode.smart)
                        Text(L.DisplayOptions.customDisplay).tag(DisplayMode.custom)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .focusable(false)
                }

                // 自定义选择（仅在自定义模式时显示）
                if settings.displayMode == .custom {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.DisplayOptions.selectLimitTypes)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(LimitType.allCases, id: \.self) { limitType in
                                LimitTypeCheckbox(
                                    limitType: limitType,
                                    isSelected: settings.customDisplayTypes.contains(limitType),
                                    isDisabled: shouldDisableCheckbox(for: limitType)
                                ) {
                                    toggleLimitType(limitType)
                                }
                            }
                        }
                        .padding(.leading, 20)

                        // 约束提示信息
                        if hasOnlyOneCircularIcon {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(L.DisplayOptions.circularIconConstraint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 20)
                        }

                        // 主题可用性提示
                        if !canUseColoredTheme {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(L.DisplayOptions.coloredThemeUnavailable)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 20)
                        }

                        Divider()

                        // "仅应用于菜单栏"开关：开启后 Popover 走智能显示
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $settings.customDisplayMenuBarOnly) {
                                Text(L.DisplayOptions.menuBarOnlyToggle)
                                    .font(.subheadline)
                            }
                            .toggleStyle(.checkbox)

                            Text(L.DisplayOptions.menuBarOnlyDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Display Options Helpers

    /// 判断是否只剩一个圆形图标
    private var hasOnlyOneCircularIcon: Bool {
        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay, .codexPrimary, .codexSecondary, .grokWeekly, .grokMonthly]
        let selectedCircular = settings.customDisplayTypes.intersection(circularTypes)
        return selectedCircular.count == 1
    }

    /// 判断是否可以使用彩色主题
    private var canUseColoredTheme: Bool {
        // 现在所有限制类型都支持彩色显示
        // 只要有选择任何限制类型就可以使用彩色主题
        return !settings.customDisplayTypes.isEmpty
    }

    /// 判断是否应该禁用某个复选框
    private func shouldDisableCheckbox(for limitType: LimitType) -> Bool {
        #if DEBUG
        // Debug模式下如果开启了"单独显示所有形状"，允许取消所有限制
        if settings.debugShowAllShapesIndividually {
            return false
        }
        #endif

        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay, .codexPrimary, .codexSecondary, .grokWeekly, .grokMonthly]

        // 如果这是最后一个选中的圆形图标，则禁用
        if circularTypes.contains(limitType) {
            let selectedCircular = settings.customDisplayTypes.intersection(circularTypes)
            return selectedCircular.count == 1 && selectedCircular.contains(limitType)
        }

        return false
    }

    /// 切换限制类型的选中状态
    private func toggleLimitType(_ limitType: LimitType) {
        if settings.customDisplayTypes.contains(limitType) {
            // 检查是否可以取消选择
            if !shouldDisableCheckbox(for: limitType) {
                settings.customDisplayTypes.remove(limitType)
            }
        } else {
            settings.customDisplayTypes.insert(limitType)
        }
    }
}

// MARK: - Limit Type Checkbox Component

/// 限制类型复选框组件
struct LimitTypeCheckbox: View {
    let limitType: LimitType
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            if !isDisabled {
                onToggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isDisabled ? .secondary : (isSelected ? .blue : .primary))
                    .font(.body)

                HStack(spacing: 6) {
                    // 限制类型图标
                    limitTypeIcon
                        .font(.caption)

                    // 限制类型名称
                    Text(limitType.displayName)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(isDisabled ? L.DisplayOptions.circularIconConstraint : "")
        .fixedSize()
    }

    @ViewBuilder
    private var limitTypeIcon: some View {
        // 使用与详情界面相同的Canvas绘制图标
        Canvas { context, canvasSize in
            let lineWidth: CGFloat = 1.8
            let path = shapePath(for: limitType, in: CGRect(origin: .zero, size: canvasSize))

            // 绘制背景边框
            context.stroke(path, with: .color(Color.gray.opacity(0.3)), lineWidth: lineWidth)

            // 绘制满进度环（100%）
            context.stroke(path, with: .color(iconColor(for: limitType)), lineWidth: lineWidth)
        }
        .frame(width: 14, height: 14)
    }

    private func shapePath(for type: LimitType, in rect: CGRect) -> Path {
        return IconShapePaths.pathForLimitType(type, in: rect)
    }

    private func iconColor(for type: LimitType) -> Color {
        switch type {
        case .fiveHour: return .green
        case .sevenDay: return .purple
        case .extraUsage: return .pink
        case .opusWeekly: return .orange
        case .sonnetWeekly: return .blue
        case .codexPrimary:  return Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0)
        case .codexSecondary: return Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0)
        case .codexExtraUsage: return Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0)
        case .grokWeekly: return Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0)
        case .grokMonthly: return Color(red: 244/255.0, green: 114/255.0, blue: 182/255.0)
        case .grokCredits: return Color(red: 250/255.0, green: 204/255.0, blue: 21/255.0)
        }
    }
}
