//
//  GeneralSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import ServiceManagement

/// 通用设置页面
/// 使用卡片式布局，包含开机启动、显示设置、刷新设置和语言设置
struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 开机启动设置卡片
                SettingCard(
                    icon: "power",
                    iconColor: .orange,
                    title: L.SettingsGeneral.launchSection,
                    hint: L.SettingsGeneral.launchHint
                ) {
                    HStack {
                        // 开关在左侧
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)   // 使用最小尺寸
                            .focusable(false)     // 移除默认 Focus
                            .labelsHidden()       // 隐藏默认标签
                        
                        // 文字标签
                        Text(L.SettingsGeneral.launchAtLogin)
                        
                        Spacer()
                        
                        // 状态指示器
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                                .font(.caption)
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 显示设置卡片
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
                                        } else if showPercentage {
                                            settings.iconDisplayMode = .percentageOnly
                                        } else {
                                            // 至少保留一个
                                            settings.iconDisplayMode = .percentageOnly
                                        }
                                    }
                                )) {
                                    Text(L.Display.showIcon)
                                }
                                .toggleStyle(.checkbox)
                                .focusable(false)

                                Toggle(isOn: Binding(
                                    get: { settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both },
                                    set: { showPercentage in
                                        let showIcon = settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both
                                        if showIcon && showPercentage {
                                            settings.iconDisplayMode = .both
                                        } else if showPercentage {
                                            settings.iconDisplayMode = .percentageOnly
                                        } else if showIcon {
                                            settings.iconDisplayMode = .iconOnly
                                        } else {
                                            // 至少保留一个
                                            settings.iconDisplayMode = .iconOnly
                                        }
                                    }
                                )) {
                                    Text(L.Display.showPercentage)
                                }
                                .toggleStyle(.checkbox)
                                .focusable(false)
                            }
                        }
                    }
                }

                // 显示选项卡片
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
                            }
                        }
                    }
                }

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
                    }
                }

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
                                .frame(width: 120)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // 语言设置卡片
                SettingCard(
                    icon: "globe",
                    iconColor: .orange,
                    title: L.SettingsGeneral.languageSection,
                    hint: L.SettingsGeneral.languageHint
                ) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.localizedName).tag(lang)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .focusable(false)
                }
                
                // 重置按钮
                HStack {
                    Spacer()
                    Button(L.SettingsGeneral.resetButton) {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)

                // MARK: - 调试模式区域（仅Debug编译可见）

                #if DEBUG
                // 调试设置卡片
                SettingCard(
                    icon: "ladybug.fill",
                    iconColor: .orange,
                    title: "调试模式",
                    hint: "切换场景后，点击刷新按钮查看效果"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 启用调试模式开关
                        HStack {
                            Toggle("", isOn: $settings.debugModeEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()

                            Text("启用调试模式")

                            Spacer()

                            Text("仅Debug编译可见")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 百分比滑块（仅在启用调试模式时显示）
                        if settings.debugModeEnabled {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 12) {
                                // 5小时限制
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("5小时限制百分比：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settings.debugFiveHourPercentage))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                    Slider(value: $settings.debugFiveHourPercentage, in: 0...100, step: 1)
                                        .tint(.green)
                                }

                                // 7天限制
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("7天限制百分比：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settings.debugSevenDayPercentage))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.purple)
                                    }
                                    Slider(value: $settings.debugSevenDayPercentage, in: 0...100, step: 1)
                                        .tint(.purple)
                                }

                                // Extra Usage 限制
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Extra Usage 百分比：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settings.debugExtraUsagePercentage))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.pink)
                                    }
                                    Slider(value: $settings.debugExtraUsagePercentage, in: 0...100, step: 1)
                                        .tint(.pink)
                                }

                                // Opus Weekly 限制
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Opus Weekly 百分比：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settings.debugOpusPercentage))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.orange)
                                    }
                                    Slider(value: $settings.debugOpusPercentage, in: 0...100, step: 1)
                                        .tint(.orange)
                                }

                                // Sonnet Weekly 限制
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Sonnet Weekly 百分比：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(settings.debugSonnetPercentage))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    }
                                    Slider(value: $settings.debugSonnetPercentage, in: 0...100, step: 1)
                                        .tint(.blue)
                                }
                            }
                            .padding(.leading, 20)
                        }

                        // 模拟更新开关
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Toggle("", isOn: $settings.simulateUpdateAvailable)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()

                            Text("模拟有可用更新")
                                .font(.subheadline)

                            Spacer()

                            Text("实时显示红点标识")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 单独显示所有形状图标开关
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Toggle("", isOn: $settings.debugShowAllShapesIndividually)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()

                            Text("形状图标可单独显示")
                                .font(.subheadline)

                            Spacer()

                            Text("方便截图")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 保持详情窗口打开开关
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Toggle("", isOn: $settings.debugKeepDetailWindowOpen)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .focusable(false)
                                .labelsHidden()

                            Text("保持详情窗口始终打开")
                                .font(.subheadline)

                            Spacer()

                            Text("背景变为不透明纯白色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                #endif
            }
            .padding()
        }
        .onAppear {
            // 设置页面打开时同步状态
            settings.syncLaunchAtLoginStatus()
            
            // 监听错误通知
            NotificationCenter.default.addObserver(
                forName: .launchAtLoginError,
                object: nil,
                queue: .main
            ) { notification in
                handleLaunchError(notification)
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text(L.LaunchAtLogin.errorTitle),
                message: Text(errorMessage),
                dismissButton: .default(Text(L.Update.okButton))
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// 状态图标
    private var statusIcon: String {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return "checkmark.circle.fill"
        case .requiresApproval:
            return "exclamationmark.circle.fill"
        case .notRegistered:
            return "circle"
        case .notFound:
            return "xmark.circle.fill"
        @unknown default:
            // 未知状态按未启用处理，会在 onAppear 时同步真实状态
            return "circle"
        }
    }
    
    /// 状态颜色
    private var statusColor: Color {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return .green
        case .requiresApproval:
            return .orange
        case .notRegistered:
            return .secondary
        case .notFound:
            return .red
        @unknown default:
            // 未知状态按未启用处理
            return .secondary
        }
    }
    
    /// 状态文本
    private var statusText: String {
        switch settings.launchAtLoginStatus {
        case .enabled:
            return L.LaunchAtLogin.statusEnabled
        case .requiresApproval:
            return L.LaunchAtLogin.statusRequiresApproval
        case .notRegistered:
            return L.LaunchAtLogin.statusDisabled
        case .notFound:
            return L.LaunchAtLogin.statusNotFound
        @unknown default:
            // 未知状态按未启用处理
            return L.LaunchAtLogin.statusDisabled
        }
    }
    
    // MARK: - Error Handling

    /// 处理开机启动错误
    private func handleLaunchError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let error = userInfo["error"] as? Error,
              let operation = userInfo["operation"] as? String else {
            return
        }

        let operationType = operation == "enable" ? L.LaunchAtLogin.errorEnable : L.LaunchAtLogin.errorDisable
        errorMessage = "\(operationType)\n\n\(error.localizedDescription)"
        showErrorAlert = true
    }

    // MARK: - Display Options Helpers

    /// 判断是否只剩一个圆形图标
    private var hasOnlyOneCircularIcon: Bool {
        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay]
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

        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay]

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
        .help(isDisabled ? "At least one circular icon must be selected" : "")
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
        }
    }
}

/// 认证设置页面
/// 使用卡片式布局，用于配置 Organization ID 和 Session Key
