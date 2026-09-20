//
//  LinearUsageGraphView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-01-11.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// 线性用量图（圆环的替代显示）
/// 以匀速消耗对角线为参照，显示每个限制在当前窗口内是超前还是落后于匀速节奏：
/// X 轴为窗口已过去的比例（0 = 窗口开始，1 = 重置），Y 轴为已用百分比。
/// 与 Provider 无关：Claude 与 Codex 各自通过下方对应的初始化方法构建数据点。
struct LinearUsageGraphView: View {
    /// 图上的一个限制数据点
    struct Point {
        /// 决定标记形状与时间窗口长度
        let type: LimitType
        /// 已用百分比
        let percentage: Double
        let resetsAt: Date?
        let color: Color
    }

    /// 要绘制的数据点；nil 表示尚无用量数据
    let points: [Point]?
    let isRefreshing: Bool
    /// 余量模式下标签显示剩余百分比；点的位置始终按已用量，保证与匀速对角线可比
    let showRemainingMode: Bool
    /// 周限制的时间轴只计工作日；5小时窗口始终按自然时间
    let weekdaysOnly: Bool

    // MARK: - Constants

    private let graphWidth: CGFloat = 262
    private let graphHeight: CGFloat = 100
    private let gridLineWidth: CGFloat = 0.5
    private let paceLineWidth: CGFloat = 1.5
    /// 标记绘制框边长；`IconShapePaths` 会为笔画内缩，实际形状约 10pt
    private let markerBoxSize: CGFloat = 16
    /// 标记的视觉半径，用于标签避让
    private let markerRadius: CGFloat = 5
    /// 标记周围镂空描边的线宽，轮廓外侧留出一半（1pt）的空隙。
    /// 再宽的话，两个标记贴在一起时后画的会在先画的上啃出明显缺口
    private let markerKnockoutWidth: CGFloat = 2
    /// 绘制区域到画布边缘的留白：要放得下落在边框上的标记（半径 + 镂空外侧 1pt），
    /// 否则 0% / 100% 及窗口起点、终点的标记会被 Canvas 边界切掉一部分
    private let padding: CGFloat = 7

    // MARK: - Body

    var body: some View {
        ZStack {
            if let points = points, !isRefreshing {
                Canvas { context, size in
                    let drawArea = CGRect(
                        x: padding,
                        y: padding,
                        width: size.width - padding * 2,
                        height: size.height - padding * 2
                    )

                    drawGrid(context: context, in: drawArea)
                    drawIdealPaceLine(context: context, in: drawArea)
                    drawPoints(context: context, in: drawArea, points: points)
                }
                .frame(width: graphWidth, height: graphHeight)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: graphWidth - padding * 2, height: graphHeight - padding * 2)

                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("--")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: graphWidth, height: graphHeight)
    }

    // MARK: - Drawing Methods

    /// 绘制背景网格：25% / 50% / 75% / 100% 横线、四等分竖线与外框
    private func drawGrid(context: GraphicsContext, in rect: CGRect) {
        let gridColor = Color.gray.opacity(0.15)

        for percentage in stride(from: 25.0, through: 100.0, by: 25.0) {
            let y = rect.maxY - (CGFloat(percentage) / 100.0 * rect.height)

            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))

            context.stroke(path, with: .color(gridColor), lineWidth: gridLineWidth)
        }

        for fraction in stride(from: 0.25, through: 0.75, by: 0.25) {
            let x = rect.minX + CGFloat(fraction) * rect.width

            var path = Path()
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            context.stroke(path, with: .color(gridColor), lineWidth: gridLineWidth)
        }

        var borderPath = Path()
        borderPath.addRect(rect)
        context.stroke(borderPath, with: .color(Color.gray.opacity(0.3)), lineWidth: gridLineWidth)
    }

    /// 绘制匀速消耗参照线：从（窗口开始, 0%）到（重置, 100%）的圆点对角线
    /// - Note: 它是参照物而非数据，视觉上要弱于数据点、又要与实线网格区分开，
    ///   所以用圆点线：近零长度的线段配圆头端点，每段画成一个直径等于线宽的圆点
    private func drawIdealPaceLine(context: GraphicsContext, in rect: CGRect) {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        let dotStyle = StrokeStyle(
            lineWidth: paceLineWidth,
            lineCap: .round,
            dash: [0.01, 4]
        )

        context.stroke(path, with: .color(Color.gray.opacity(0.5)), style: dotStyle)
    }

    /// 绘制数据点标记与百分比标签
    /// - Note: 标记沿用限制行图标的形状（圆 / 圆角方 / 斜切方），颜色相近时仍能区分；
    ///   先画全部标记再画标签，避免标签被后画的标记压住
    private func drawPoints(context: GraphicsContext, in rect: CGRect, points: [Point]) {
        let positions = points.map { point in
            UsagePaceGraphMath.position(
                elapsedRatio: elapsedRatio(for: point),
                percentage: point.percentage,
                in: rect
            )
        }

        for (point, position) in zip(points, positions) {
            let box = CGRect(
                x: position.x - markerBoxSize / 2,
                y: position.y - markerBoxSize / 2,
                width: markerBoxSize,
                height: markerBoxSize
            )
            let marker = IconShapePaths.pathForLimitType(point.type, in: box)
            // 镂空：先沿轮廓挖掉一圈，让弹窗背景透出来，再填充标记。
            // 浅色 / 深色模式下都表现为一圈与背景同色的空隙（白色描边在深色下会变成亮边），
            // 同列重叠的标记（7天 / Opus / Sonnet 共用重置时间）也靠这圈空隙区分
            var knockout = context
            knockout.blendMode = .clear
            knockout.stroke(marker, with: .color(.black), lineWidth: markerKnockoutWidth)
            context.fill(marker, with: .color(point.color))
        }

        let labels = points.map { context.resolve(labelText(for: $0)) }
        let frames = UsagePaceGraphMath.labelFrames(
            dots: positions,
            sizes: labels.map { $0.measure(in: rect.size) },
            markerRadius: markerRadius,
            in: rect
        )
        for (label, frame) in zip(labels, frames) {
            context.draw(label, in: frame)
        }
    }

    private func labelText(for point: Point) -> Text {
        let displayed = UsageRingDisplay.displayedPercentage(
            usedPercentage: point.percentage,
            showRemainingMode: showRemainingMode
        )
        return Text("\(Int(displayed))%")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.primary)
    }

    // MARK: - Helper Methods

    private func elapsedRatio(for point: Point) -> Double {
        let windowSeconds = Self.windowSeconds(for: point.type)
        // 5小时窗口短于一天，剔除周末只会让周五晚上跨到周六的窗口停住不动，没有意义
        if weekdaysOnly && windowSeconds > UsagePaceGraphMath.fiveHourWindow {
            return UsagePaceGraphMath.weekdayElapsedRatio(resetsAt: point.resetsAt, windowSeconds: windowSeconds)
        }
        return UsagePaceGraphMath.elapsedRatio(resetsAt: point.resetsAt, windowSeconds: windowSeconds)
    }

    /// 限制类型对应的窗口时长
    /// - Note: Codex 窗口在解析时已按实际时长归类（见 `CodexUsageResponse.toCodexUsageData`），
    ///   codexPrimary 必为5小时窗口，codexSecondary 必为7天窗口
    private static func windowSeconds(for type: LimitType) -> TimeInterval {
        switch type {
        case .fiveHour, .codexPrimary:
            return UsagePaceGraphMath.fiveHourWindow
        case .sevenDay, .opusWeekly, .sonnetWeekly, .extraUsage,
             .codexSecondary, .codexExtraUsage:
            return UsagePaceGraphMath.sevenDayWindow
        }
    }

    fileprivate static func weeklyModelColor(_ type: LimitType, _ percentage: Double) -> Color {
        type == .sonnetWeekly
            ? Color(UsageColorScheme.sonnetWeeklyColor(percentage))
            : Color(UsageColorScheme.opusWeeklyColor(percentage))
    }
}

// MARK: - Provider Initializers

extension LinearUsageGraphView {
    /// Claude 限制
    /// - Note: 额外用量是消费上限，没有重置窗口，不放在节奏图上；
    ///   与圆环一致，自定义模式下缺失的 5h / 7d 以 0% 占位；
    ///   与限制行一致，智能模式下第三个及以后的模型按圆角方 / 斜切方轮换补齐
    init(
        usageData: UsageData?,
        activeDisplayTypes: [LimitType],
        isRefreshing: Bool,
        showRemainingMode: Bool
    ) {
        self.isRefreshing = isRefreshing
        self.showRemainingMode = showRemainingMode
        self.weekdaysOnly = UserSettings.shared.linearGraphWeekdaysOnly
        guard let data = usageData else {
            self.points = nil
            return
        }

        let settings = UserSettings.shared
        let placeholder = settings.shouldShowCustomPlaceholderInPopover
            ? UsageData.LimitData(percentage: 0, resetsAt: nil)
            : nil

        var points: [Point] = activeDisplayTypes.compactMap { type in
            switch type {
            case .fiveHour:
                return (data.fiveHour ?? placeholder).map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.fiveHourColorSwiftUI($0.percentage))
                }
            case .sevenDay:
                return (data.sevenDay ?? placeholder).map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.sevenDayColorSwiftUI($0.percentage))
                }
            case .opusWeekly:
                return data.opus.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: Self.weeklyModelColor(type, $0.percentage))
                }
            case .sonnetWeekly:
                return data.sonnet.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: Self.weeklyModelColor(type, $0.percentage))
                }
            case .extraUsage, .codexPrimary, .codexSecondary, .codexExtraUsage:
                return nil
            }
        }

        if settings.displayMode == .smart {
            for (offset, model) in data.weeklyModels.enumerated().dropFirst(2) {
                let type: LimitType = offset % 2 == 0 ? .opusWeekly : .sonnetWeekly
                points.append(Point(
                    type: type,
                    percentage: model.limit.percentage,
                    resetsAt: model.limit.resetsAt,
                    color: Self.weeklyModelColor(type, model.limit.percentage)
                ))
            }
        }

        self.points = points
    }

    /// Codex 限制
    /// - Note: Codex credits 是余额而非窗口百分比，不放在节奏图上
    init(
        codexUsageData: CodexUsageData?,
        activeDisplayTypes: [LimitType],
        isRefreshing: Bool,
        showRemainingMode: Bool
    ) {
        self.isRefreshing = isRefreshing
        self.showRemainingMode = showRemainingMode
        self.weekdaysOnly = UserSettings.shared.linearGraphWeekdaysOnly
        guard let data = codexUsageData else {
            self.points = nil
            return
        }

        let placeholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover
            ? CodexUsageData.LimitData(percentage: 0, resetsAt: nil)
            : nil

        self.points = activeDisplayTypes.compactMap { type in
            switch type {
            case .codexPrimary:
                return (data.primary ?? placeholder).map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.codexPrimaryColorSwiftUI($0.percentage))
                }
            case .codexSecondary:
                return (data.secondary ?? placeholder).map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.codexSecondaryColorSwiftUI($0.percentage))
                }
            case .codexExtraUsage, .fiveHour, .sevenDay, .extraUsage, .opusWeekly, .sonnetWeekly:
                return nil
            }
        }
    }
}

// MARK: - Preview

struct LinearUsageGraphView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LinearUsageGraphView(
                usageData: UsageData(
                    fiveHour: UsageData.LimitData(
                        percentage: 45,
                        resetsAt: Date().addingTimeInterval(3600 * 2.5)
                    ),
                    sevenDay: UsageData.LimitData(
                        percentage: 20,
                        resetsAt: Date().addingTimeInterval(3600 * 24 * 5)
                    ),
                    opus: nil,
                    sonnet: nil,
                    extraUsage: nil
                ),
                activeDisplayTypes: [.fiveHour, .sevenDay],
                isRefreshing: false,
                showRemainingMode: false
            )

            LinearUsageGraphView(
                codexUsageData: CodexUsageData(
                    primary: .init(percentage: 30, resetsAt: Date().addingTimeInterval(3600 * 3)),
                    secondary: .init(percentage: 12, resetsAt: Date().addingTimeInterval(3600 * 24 * 6)),
                    extraUsage: nil
                ),
                activeDisplayTypes: [.codexPrimary, .codexSecondary],
                isRefreshing: false,
                showRemainingMode: true
            )

            LinearUsageGraphView(
                usageData: nil,
                activeDisplayTypes: [.fiveHour],
                isRefreshing: true,
                showRemainingMode: false
            )
        }
        .padding()
    }
}
