//
//  UsageDetailView+Helpers.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

// MARK: - Helper Methods Extension

extension UsageDetailView {

    // MARK: - Animation Methods

    /// 启动旋转动画
    func startRotationAnimation() {
        // 清除旧的定时器
        stopRotationAnimation()

        // 重置角度
        rotationAngle = 0

        // 创建新的定时器，每 0.016 秒更新一次（约 60fps）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            withAnimation(.linear(duration: 0.016)) {
                rotationAngle += 6  // 每帧旋转 6 度，1秒完成一圈
                if rotationAngle >= 360 {
                    rotationAngle -= 360
                }
            }
        }
    }

    /// 停止旋转动画
    func stopRotationAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.default) {
            rotationAngle = 0
        }
    }

    /// 加载动画视图
    /// 根据animationType返回不同的加载效果
    @ViewBuilder
    func loadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            rainbowLoadingAnimation()
        case .dashed:
            dashedLoadingAnimation()
        case .pulse:
            pulseLoadingAnimation()
        }
    }

    /// 效果1：彩虹渐变旋转（推荐）
    func rainbowLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .blue]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(rotationAngle))
    }

    /// 效果2：虚线旋转
    func dashedLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 1)
            .stroke(
                Color.blue,
                style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8])
            )
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(rotationAngle))
    }

    /// 效果3：脉冲效果
    func pulseLoadingAnimation() -> some View {
        ZStack {
            // 内圈 - 快速脉冲
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    Color.blue.opacity(0.8),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(rotationAngle))

            // 外圈 - 慢速脉冲
            Circle()
                .trim(from: 0, to: 0.4)
                .stroke(
                    Color.blue.opacity(0.4),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
        }
    }

    /// 外侧圆环的彩虹加载动画（逆时针旋转）
    func outerRainbowLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .blue]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 114, height: 114)
            .rotationEffect(.degrees(-rotationAngle))  // 逆时针旋转
    }

    /// 外侧圆环的虚线加载动画（逆时针旋转）
    func outerDashedLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 1)
            .stroke(
                Color.purple,  // 使用紫色系与7天限制主题一致
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
            )
            .frame(width: 114, height: 114)
            .rotationEffect(.degrees(-rotationAngle))  // 逆时针旋转
    }

    /// 外侧圆环的脉冲加载动画（逆时针旋转）
    func outerPulseLoadingAnimation() -> some View {
        Circle()
            .trim(from: 0, to: 0.4)
            .stroke(
                Color.purple.opacity(0.6),  // 使用紫色系与7天限制主题一致
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 114, height: 114)
            .rotationEffect(.degrees(-rotationAngle * 0.7))  // 慢速逆时针旋转
    }

    /// 外侧圆环加载动画视图（根据animationType返回对应效果）
    @ViewBuilder
    func outerLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            outerRainbowLoadingAnimation()
        case .dashed:
            outerDashedLoadingAnimation()
        case .pulse:
            outerPulseLoadingAnimation()
        }
    }

    // MARK: - Graph View Selection

    /// 根据用户设置选择圆形或线性图表
    /// - Parameter data: 用量数据
    /// - Returns: 对应类型的图表视图
    @ViewBuilder
    func usageGraphView(data: UsageData) -> some View {
        switch UserSettings.shared.graphDisplayType {
        case .circular:
            circularGraphView(data: data)
        case .linear:
            LinearUsageGraphView(
                usageData: data,
                activeDisplayTypes: activeDisplayTypes,
                isRefreshing: refreshState.isRefreshing
            )
        }
    }

    /// 圆形图表视图
    @ViewBuilder
    func circularGraphView(data: UsageData) -> some View {
        ZStack {
            // 根据用户选择的显示类型确定主要限制
            let primaryLimitData = getPrimaryLimitData(data: data, activeTypes: activeDisplayTypes)

            if let primary = primaryLimitData {
                // 1. 主圆环背景（灰色）
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    .frame(width: 100, height: 100)

                if refreshState.isRefreshing {
                    // 加载动画
                    loadingAnimation()
                } else {
                    // 2. 主进度条（根据用户选择的限制类型）
                    Circle()
                        .trim(from: 0, to: CGFloat(primary.percentage) / 100.0)
                        .stroke(
                            colorForPrimaryByActiveTypes(data: data, activeTypes: activeDisplayTypes),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: primary.percentage)
                }

                // 3. 外层细圆环（仅在用户同时选择了5h和7d限制时显示）
                if activeDisplayTypes.contains(.fiveHour) &&
                   activeDisplayTypes.contains(.sevenDay) {
                    // 在自定义模式下，即使数据为 nil 也显示占位圆环
                    let sevenDayPercentage = data.sevenDay?.percentage ?? (UserSettings.shared.displayMode == .custom ? 0 : nil)

                    if let percentage = sevenDayPercentage {
                        // 7天背景圆环（灰色）
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                            .frame(width: 114, height: 114)

                        if refreshState.isRefreshing {
                            // 刷新时显示对应类型的外侧圆环动画（逆时针旋转）
                            outerLoadingAnimation()
                        } else {
                            // 7天进度条（紫色系）
                            Circle()
                                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                                .stroke(
                                    colorForSevenDay(percentage),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 114, height: 114)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: percentage)
                        }
                    }
                }

                // 4. 中间显示区域：百分比（显示主要限制的百分比）
                VStack(spacing: 2) {
                    Text("\(Int(primary.percentage))%")
                        .font(.system(size: 28, weight: .bold))
                    Text(L.Usage.used)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Primary Limit Selection

    /// 根据用户选择的显示类型确定主要限制数据
    /// - Parameters:
    ///   - data: 用量数据
    ///   - activeTypes: 当前激活的显示类型
    /// - Returns: 主要限制的数据
    func getPrimaryLimitData(data: UsageData, activeTypes: [LimitType]) -> UsageData.LimitData? {
        // 在自定义模式下，即使数据为 nil 也显示占位数据（0%）
        let showPlaceholder = UserSettings.shared.displayMode == .custom
        let placeholderData = UsageData.LimitData(percentage: 0, resetsAt: nil)

        // 从激活的类型中找到第一个圆形类型
        if activeTypes.contains(.fiveHour) {
            if let fiveHour = data.fiveHour {
                return fiveHour
            } else if showPlaceholder {
                return placeholderData
            }
        } else if activeTypes.contains(.sevenDay) {
            if let sevenDay = data.sevenDay {
                return sevenDay
            } else if showPlaceholder {
                return placeholderData
            }
        }
        // 如果没有圆形类型，返回nil
        return nil
    }

    /// 根据用户选择的显示类型确定主要限制的颜色
    /// - Parameters:
    ///   - data: 用量数据
    ///   - activeTypes: 当前激活的显示类型
    /// - Returns: 主要限制的颜色
    func colorForPrimaryByActiveTypes(data: UsageData, activeTypes: [LimitType]) -> Color {
        // 从激活的类型中找到第一个圆形类型并返回对应颜色
        if activeTypes.contains(.fiveHour) {
            if let fiveHour = data.fiveHour {
                return colorForPercentage(fiveHour.percentage)
            } else {
                // 数据为 nil 时返回灰色
                return .gray
            }
        } else if activeTypes.contains(.sevenDay) {
            if let sevenDay = data.sevenDay {
                return colorForSevenDay(sevenDay.percentage)
            } else {
                return .gray
            }
        }
        return .gray
    }

    // MARK: - Color Methods

    /// 根据使用百分比返回对应的颜色
    /// - 0-70%: 绿色（安全）
    /// - 70-90%: 橙色（警告）
    /// - 90-100%: 红色（危险）
    /// 根据5小时限制使用百分比返回对应的颜色
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 对应的状态颜色
    /// - Note: 使用统一配色方案 (绿→橙→红)
    func colorForPercentage(_ percentage: Double) -> Color {
        return UsageColorScheme.fiveHourColorSwiftUI(percentage)
    }

    /// 根据7天限制使用百分比返回配色
    /// - Parameter percentage: 当前使用百分比
    /// - Returns: 对应的状态颜色
    /// - Note: 使用统一配色方案 (青蓝→蓝紫→深紫)
    func colorForSevenDay(_ percentage: Double) -> Color {
        return UsageColorScheme.sevenDayColorSwiftUI(percentage)
    }

    /// 获取主要限制的颜色（根据数据类型自动选择绿/橙/红或紫色系）
    func colorForPrimary(_ data: UsageData) -> Color {
        if let fiveHour = data.fiveHour {
            // 有5小时限制数据，使用绿/橙/红
            return colorForPercentage(fiveHour.percentage)
        } else if let sevenDay = data.sevenDay {
            // 只有7天限制数据，使用紫色系
            return colorForSevenDay(sevenDay.percentage)
        }
        return .gray
    }

    // MARK: - Text Helper Methods

    /// 创建彩虹文字
    /// - Parameter text: 要显示的文本
    /// - Returns: 带彩虹效果的文本视图
    @ViewBuilder
    func rainbowText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    /// 创建菜单更新文本（部分文字带颜色）
    /// - Returns: 带颜色的AttributedString
    func createUpdateMenuText() -> AttributedString {
        let baseText = L.Menu.checkUpdates
        let badgeText = L.Update.Notification.badgeShort
        let fullText = baseText + "   " + badgeText

        var attributedString = AttributedString(fullText)

        // 找到徽章文本的范围并设置颜色
        if let range = attributedString.range(of: badgeText) {
            attributedString[range].foregroundColor = .orange
        }

        return attributedString
    }
}
