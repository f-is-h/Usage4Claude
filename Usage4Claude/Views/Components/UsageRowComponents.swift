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

/// Popover 大圆环的 trim 换算。口径本身定义在 `UsageDisplayMode`，菜单栏图标读的是同一份，
/// 这里只把它翻译成 `UsageRingArc` 要的 CGFloat。
enum UsageRingDisplay {
    static func displayedPercentage(usedPercentage: Double, showRemainingMode: Bool) -> Double {
        UsageDisplayMode.displayedPercentage(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode)
    }

    static func displayedTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange {
        let range = UsageDisplayMode.fillRange(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode)
        return UsageRingTrimRange(from: CGFloat(range.from), to: CGFloat(range.to))
    }

    /// 已用/剩余切换动画，参数取自 `UsageDisplayMode.Spring`，与菜单栏图标同一条曲线
    static let toggleAnimation: Animation = .spring(
        response: UsageDisplayMode.Spring.response,
        dampingFraction: UsageDisplayMode.Spring.dampingFraction,
        blendDuration: 0.05
    )
}

/// 大圆环的实线段，替代 `Circle().trim(from:to:)`。
///
/// 切换口径用的是欠阻尼 spring，端点会在目标附近来回摆动。目标是空弧时（已用 100% 切到剩余，
/// 或已用 0%），端点每摆回轨迹内一次就会切出一段几乎零长的弧，圆头线帽把它画成一个线宽大小的圆点，
/// 看起来就是收尾时「弹」出来一下。这里把不足 `minVisibleLength` 的弧直接当空弧处理。
struct UsageRingArc: Shape {
    var from: CGFloat
    var to: CGFloat

    /// 0.2%：远小于真实数据能出现的最小非零值（1%），又盖得住 spring 第二次回摆的幅度（约 0.04%）
    static let minVisibleLength: CGFloat = 0.002

    init(_ range: UsageRingTrimRange) {
        from = range.from
        to = range.to
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(from, to) }
        set {
            from = newValue.first
            to = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // spring 过冲会把端点推出 0...1，先钳回轨迹内再判断长度
        let start = min(1, max(0, from))
        let end = min(1, max(0, to))
        guard end - start >= Self.minVisibleLength else { return Path() }
        return Circle().path(in: rect).trimmedPath(from: start, to: end)
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

// MARK: - Mini Progress Icon Component

/// 迷你进度图标（带百分比数字和进度弧，与菜单栏图标风格一致）
struct MiniProgressIcon: View {
    let type: LimitType
    let color: Color
    let percentage: Double
    /// 非 nil 时改画这段文本而不是百分比。Codex 额外用量用它显示余额点数——
    /// 那是个没有限额的预付钱包，算不出诚实的百分比
    var textOverride: String? = nil
    /// 余额徽章样式（Codex 额外用量）：边框画得极细，把内部空间让给可能有 4 位的点数。
    /// 这一格画的是余额不是进度，不需要进度图标那样的线宽
    var badge: Bool = false
    let size: CGFloat = 22

    /// 与 `ShapeIconRenderer.hexBadgeKernRatio` 保持一致
    private static let badgeKernRatio: CGFloat = -0.05

    private var displayText: String {
        textOverride ?? "\(Int(percentage))"
    }

    var body: some View {
        Canvas { context, canvasSize in
            // 徽章边框细到一根 Retina 像素，和菜单栏图标同一套做法
            let lineWidth: CGFloat = badge ? 0.5 : 2.2
            let rect = CGRect(origin: .zero, size: canvasSize)
            let fullPath = IconShapePaths.pathForLimitType(type, in: rect)

            // 1. 形状边框（彩色）
            context.stroke(fullPath, with: .color(color), lineWidth: lineWidth)

            // 2. 数字（居中）——进度版按字符数分两档，徽章版统一从大档起步
            let baseFontSize = (badge || displayText.count < 3) ? canvasSize.width * 0.38 : canvasSize.width * 0.28
            // 六边形在 IconShapePaths 里被 inset 3pt，实际直径比画布窄不少，
            // 可用宽度必须按形状本身算，否则 "2.5k" 会直接压出边框
            let shapeWidth: CGFloat
            switch type {
            case .extraUsage, .codexExtraUsage:
                shapeWidth = min(canvasSize.width, canvasSize.height) - 6
            default:
                shapeWidth = canvasSize.width
            }
            // 徽章版的字距为负，收紧后同样宽度能放更大的字
            let kerning = badge ? baseFontSize * Self.badgeKernRatio : 0
            let measured = context
                .resolve(Text(displayText).font(.system(size: baseFontSize, weight: .bold)).kerning(kerning))
                .measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

            let fontSize: CGFloat
            if badge {
                // 与 ShapeIconRenderer.drawHexagonBadge 同一个几何解：六边形在文字高度带上
                // 收窄 0.577·capHeight，描边每侧再吃掉 0.577 个线宽
                let capRatio = NSFont.systemFont(ofSize: baseFontSize, weight: .bold).capHeight / baseFontSize
                // SwiftUI 的 kerning 不像 AppKit 的 .kern 那样在末字符后也加一份，
                // 测出来就是视觉宽度，不用像 ShapeIconRenderer 那边补偿尾随字距
                let unitWidth = measured.width / baseFontSize
                fontSize = min(baseFontSize, (shapeWidth - 1.155 * lineWidth) / (unitWidth + 0.577 * capRatio))
            } else {
                let usableWidth = (shapeWidth - lineWidth * 2) * 0.95
                fontSize = measured.width > usableWidth
                    ? max(baseFontSize * 0.5, baseFontSize * usableWidth / measured.width)
                    : baseFontSize
            }

            let text = Text(displayText)
                .font(.system(size: fontSize, weight: .bold))
                .kerning(badge ? fontSize * Self.badgeKernRatio : 0)
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

// MARK: - Detail Popover Text Layout

/// 点击小图标弹出的说明（标题旁小叹号、Codex 重置预告角标）共用的文字排版
/// - Note: popover 按内容的理想尺寸撑开，而 Text 的理想宽度是整行不换行。
///   按实测文字宽度定宽：短文案不留白，超过上限才换行
enum DetailPopoverText {
    static let fontSize: CGFloat = 12

    static func width(fitting lines: [String], maxWidth: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let widest = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return min(ceil(widest) + 2, maxWidth)
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
    /// 溢出模型行覆盖：提供时，行的百分比/标签/重置时间直接取自这个模型条目，
    /// `type` 仅用于决定外观（圆角方/斜切方形状与配色的槽位）。用于 popover 展示
    /// 超出前两个槽位的第三个及以后的模型（如同时出现 Fable / Opus / Sonnet）。
    var weeklyModelOverride: UsageData.WeeklyModelLimit? = nil

    var body: some View {
        HStack(spacing: 8) {
            // 图标（含百分比数字和进度弧）
            MiniProgressIcon(
                type: type,
                color: iconColor,
                percentage: percentageValue ?? 0,
                textOverride: iconTextOverride,
                badge: iconTextOverride != nil
            )

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
        if let override = weeklyModelOverride {
            return override.modelName ?? L.DetailRow.opusWeekly
        }
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
        UsageColorScheme.identityColorSwiftUI(
            for: type,
            codexExtraUsageExhausted: codexData?.extraUsage?.isExhausted ?? false
        )
    }

    /// Codex 额外用量的图标里画余额点数，不画百分比
    private var iconTextOverride: String? {
        guard type == .codexExtraUsage, weeklyModelOverride == nil else { return nil }
        guard let extra = codexData?.extraUsage, extra.enabled else { return "-" }
        return MenuBarIconRenderer.codexExtraUsageBadgeText(extra) ?? "-"
    }

    private var percentageValue: Double? {
        if let override = weeklyModelOverride {
            return override.limit.percentage
        }
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
        if let override = weeklyModelOverride {
            return showRemainingMode
                ? override.limit.formattedCompactRemaining
                : override.limit.formattedCompactResetDate
        }
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
