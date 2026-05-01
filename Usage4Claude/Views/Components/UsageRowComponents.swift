//
//  UsageRowComponents.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

// MARK: - Mini Progress Icon Component

/// 迷你进度图标（带百分比数字和进度弧，与菜单栏图标风格一致）
struct MiniProgressIcon: View {
    let type: LimitType
    let color: Color
    let percentage: Double
    let size: CGFloat = 22

    var body: some View {
        Canvas { context, canvasSize in
            let lineWidth: CGFloat = 2.2
            let rect = CGRect(origin: .zero, size: canvasSize)
            let fullPath = IconShapePaths.pathForLimitType(type, in: rect)

            // 1. 形状边框（彩色）
            context.stroke(fullPath, with: .color(color), lineWidth: lineWidth)

            // 2. 百分比数字（居中）
            let fontSize = percentage >= 100 ? canvasSize.width * 0.28 : canvasSize.width * 0.38
            let text = Text("\(Int(percentage))")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(color)
            context.draw(text, at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animation Type Hint View

/// 动画类型切换提示（长按圆环后显示），Claude 列和 Codex 列共用
struct AnimationTypeHintView: View {
    let animationTypeName: String

    private let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: rainbowColors, startPoint: .leading, endPoint: .trailing)
                )
            Text(L.LoadingAnimation.current(animationTypeName))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(colors: rainbowColors, startPoint: .leading, endPoint: .trailing)
                )
        }
        .padding(.horizontal, 12)
        .fixedSize(horizontal: true, vertical: true)
    }
}

// MARK: - Provider Divider

/// 双 Provider 主窗口中央的柔和竖线，视觉与设置页标签分隔线一致
struct ProviderDivider: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.secondary.opacity(0.0),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.3),
                Color.secondary.opacity(0.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: height)
    }
}

// MARK: - Unified Limit Row Component

/// 统一的限制行组件（支持所有 Claude 和 Codex 限制类型）
struct UnifiedLimitRow: View {
    let type: LimitType
    var data: UsageData? = nil
    var codexData: CodexUsageData? = nil
    let showRemainingMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            // 图标（含百分比数字和进度弧）
            MiniProgressIcon(type: type, color: iconColor, percentage: percentageValue ?? 0)

            // 限制类型名称
            Text(limitName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            // 右侧：重置时间或剩余额度
            Text(displayValue)
                .font(.system(size: 12))
                .fontWeight(.medium)
                .id(showRemainingMode ? "remaining" : "reset")  // 强制识别为不同视图
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var limitName: String {
        switch type {
        case .fiveHour:
            return L.Limit.fiveHour
        case .sevenDay:
            return L.Limit.sevenDay
        case .opusWeekly:
            return L.Limit.opusWeekly
        case .sonnetWeekly:
            return L.Limit.sonnetWeekly
        case .extraUsage:
            return L.Limit.extraUsage
        case .codexPrimary:
            return L.Limit.fiveHour
        case .codexSecondary:
            return L.Limit.sevenDay
        case .codexExtraUsage:
            return L.Limit.extraUsage
        }
    }

    private var iconColor: Color {
        switch type {
        case .fiveHour:
            return .green
        case .sevenDay:
            return .purple
        case .opusWeekly:
            return .orange
        case .sonnetWeekly:
            return .blue
        case .extraUsage:
            return .pink
        case .codexPrimary:
            return Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0)   // #2DD4BF
        case .codexSecondary:
            return Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0)   // #60A5FA
        case .codexExtraUsage:
            return Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0)    // #F59E0B
        }
    }

    private var percentageValue: Double? {
        switch type {
        case .fiveHour:       return data?.fiveHour?.percentage
        case .sevenDay:       return data?.sevenDay?.percentage
        case .opusWeekly:     return data?.opus?.percentage
        case .sonnetWeekly:   return data?.sonnet?.percentage
        case .extraUsage:     return data?.extraUsage?.percentage
        case .codexPrimary:   return codexData?.primary?.percentage
        case .codexSecondary: return codexData?.secondary?.percentage
        case .codexExtraUsage: return codexData?.extraUsage?.percentage
        }
    }

    private var displayValue: String {
        switch type {
        case .fiveHour:
            guard let fiveHour = data?.fiveHour else { return "-" }
            return showRemainingMode ? fiveHour.formattedCompactRemaining : fiveHour.formattedCompactResetTime

        case .sevenDay:
            guard let sevenDay = data?.sevenDay else { return "-" }
            return showRemainingMode ? sevenDay.formattedCompactRemaining : sevenDay.formattedCompactResetDate

        case .opusWeekly:
            guard let opus = data?.opus else { return "-" }
            return showRemainingMode ? opus.formattedCompactRemaining : opus.formattedCompactResetDate

        case .sonnetWeekly:
            guard let sonnet = data?.sonnet else { return "-" }
            return showRemainingMode ? sonnet.formattedCompactRemaining : sonnet.formattedCompactResetDate

        case .extraUsage:
            guard let extra = data?.extraUsage else { return "-" }
            return showRemainingMode ? extra.formattedRemainingAmount : extra.formattedCompactAmount

        case .codexPrimary:
            guard let limitData = codexData?.primary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemaining : limitData.formattedCompactResetTime

        case .codexSecondary:
            guard let limitData = codexData?.secondary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemaining : limitData.formattedCompactResetDate

        case .codexExtraUsage:
            guard let extra = codexData?.extraUsage else { return "-" }
            return showRemainingMode ? extra.formattedRemainingAmount : extra.formattedCompactAmount
        }
    }
}
