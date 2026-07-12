//
//  UsageRowComponents.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

// MARK: - Detail Usage Ring Helpers

struct UsageRingTrimRange: Equatable {
    let from: CGFloat
    let to: CGFloat
}

enum UsageRingDisplay {
    static func clampedPercentage(_ percentage: Double) -> Double {
        min(100, max(0, percentage))
    }

    static func displayedPercentage(usedPercentage: Double, showRemainingMode: Bool) -> Double {
        let used = clampedPercentage(usedPercentage)
        return showRemainingMode ? 100 - used : used
    }

    static func usedFraction(_ usedPercentage: Double) -> CGFloat {
        CGFloat(clampedPercentage(usedPercentage) / 100.0)
    }

    static func displayedTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange {
        let used = usedFraction(usedPercentage)

        if showRemainingMode {
            return UsageRingTrimRange(from: used, to: 1)
        }

        return UsageRingTrimRange(from: 0, to: used)
    }
}

/// 大圆环中心百分比与语义标签。
struct DetailUsageRingCenterText: View {
    let usedPercentage: Double
    let showRemainingMode: Bool

    private var displayPercentage: Double {
        UsageRingDisplay.displayedPercentage(
            usedPercentage: usedPercentage,
            showRemainingMode: showRemainingMode
        )
    }

    private var modeLabel: String {
        showRemainingMode ? L.Usage.available : L.Usage.used
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(displayPercentage))%")
                .font(.system(size: 28, weight: .bold))
            Text(modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .id(showRemainingMode ? "remaining" : "used")
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }
}

/// 剩余/已用模式切换时的一次性外侧扫光。
struct DetailUsageRingSweep: View {
    let trigger: Int
    let diameter: CGFloat
    let lineWidth: CGFloat
    let color: Color

    @State private var rotation: Double = -90
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.18)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.0),
                        color.opacity(0.35),
                        Color.white.opacity(0.95),
                        color.opacity(0.85),
                        color.opacity(0.0)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .scaleEffect(opacity > 0 ? 1.03 : 0.98)
            .allowsHitTesting(false)
            .onChange(of: trigger) { newValue in
                guard newValue > 0 else { return }
                runSweep()
            }
    }

    private func runSweep() {
        rotation = -90
        opacity = 1

        withAnimation(.easeOut(duration: 0.45)) {
            rotation = 270
            opacity = 0
        }
    }
}

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
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 8)

            // 右侧：重置时间或剩余额度
            // TimelineView 让这行文字自己按分钟粒度刷新，不再依赖外层每秒 objectWillChange
            // 触发整个 popover 重建（displayValue 精度只到分钟，60s 间隔足够）
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text(displayValue)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .id(showRemainingMode ? "remaining" : "reset")  // 强制识别为不同视图
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var limitName: String {
        switch type {
        case .fiveHour, .codexPrimary:
            return L.DetailRow.fiveHour
        case .sevenDay, .codexSecondary:
            return L.DetailRow.sevenDay
        case .opusWeekly:
            // Claude 5 时代：此槽位可能承载来自 limits 数组的具体模型每周限制（如 Fable）。
            // 有真实模型名则优先展示，否则回退到默认的 “Opus Weekly” 文案。
            return data?.opusModelName ?? L.DetailRow.opusWeekly
        case .sonnetWeekly:
            return data?.sonnetModelName ?? L.DetailRow.sonnetWeekly
        case .extraUsage, .codexExtraUsage:
            return L.DetailRow.extraUsage
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
            return showRemainingMode ? fiveHour.formattedCompactRemaining : detailCompactResetTime(fiveHour)

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
            return showRemainingMode ? limitData.formattedCompactRemaining : detailCompactResetTime(limitData)

        case .codexSecondary:
            guard let limitData = codexData?.secondary?.asUsageLimitData() else { return "-" }
            return showRemainingMode ? limitData.formattedCompactRemainingWithMinutes : limitData.formattedCompactResetDateWithMinutes

        case .codexExtraUsage:
            guard let extra = codexData?.extraUsage else { return "-" }
            return showRemainingMode ? extra.formattedDetailRemainingAmount : extra.formattedDetailCompactAmount
        }
    }

    private func detailCompactResetTime(_ limitData: UsageData.LimitData) -> String {
        guard let resetsAt = limitData.resetsAt else {
            return "-"
        }

        var calendar = Calendar.current
        calendar.locale = UserSettings.shared.appLocale
        let timeString = TimeFormatHelper.formatTimeOnly(resetsAt)

        if calendar.isDateInToday(resetsAt) {
            return "\(L.DetailRow.today) \(timeString)"
        }
        if calendar.isDateInTomorrow(resetsAt) {
            return "\(L.UsageData.tomorrow) \(timeString)"
        }
        return TimeFormatHelper.formatDateTime(resetsAt, dateTemplate: "Md")
    }
}
