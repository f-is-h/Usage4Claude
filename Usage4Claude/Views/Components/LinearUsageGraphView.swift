//
//  LinearUsageGraphView.swift
//  Usage4Claude
//
//  Created by Claude on 2026-01-11.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// Linear graph view showing usage pace with ideal pace reference line
/// X-axis: Normalized time (0 = session start, 1 = reset time)
/// Y-axis: Usage percentage (0-100%)
/// Provider-agnostic: Claude and Codex each build their points via the matching initializer below.
struct LinearUsageGraphView: View {
    /// A single plotted limit
    struct Point {
        let type: LimitType
        let percentage: Double
        let resetsAt: Date?
        let color: Color
    }

    /// Points to plot; nil means there is no usage data yet
    let points: [Point]?
    let isRefreshing: Bool

    // MARK: - Constants

    private let graphWidth: CGFloat = 262
    private let graphHeight: CGFloat = 100
    private let padding: CGFloat = 4
    private let gridLineWidth: CGFloat = 0.5
    private let paceLineWidth: CGFloat = 1.5
    private let dotRadius: CGFloat = 5

    // MARK: - Body

    var body: some View {
        ZStack {
            if let points = points, !isRefreshing {
                // Graph content
                Canvas { context, size in
                    let drawArea = CGRect(
                        x: padding,
                        y: padding,
                        width: size.width - padding * 2,
                        height: size.height - padding * 2
                    )

                    // 1. Draw background grid
                    drawGrid(context: context, in: drawArea)

                    // 2. Draw ideal pace line (dashed diagonal)
                    drawIdealPaceLine(context: context, in: drawArea)

                    // 3. Draw limit points
                    drawLimitPoints(context: context, in: drawArea, points: points)
                }
                .frame(width: graphWidth, height: graphHeight)
            } else {
                // Loading or no data state
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

    /// Draw subtle horizontal grid lines at 25%, 50%, 75%, 100%
    private func drawGrid(context: GraphicsContext, in rect: CGRect) {
        let gridColor = Color.gray.opacity(0.15)

        for percentage in stride(from: 25.0, through: 100.0, by: 25.0) {
            let y = rect.maxY - (CGFloat(percentage) / 100.0 * rect.height)

            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))

            context.stroke(path, with: .color(gridColor), lineWidth: gridLineWidth)
        }

        // Draw vertical grid lines at 25%, 50%, 75%
        for fraction in stride(from: 0.25, through: 0.75, by: 0.25) {
            let x = rect.minX + CGFloat(fraction) * rect.width

            var path = Path()
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            context.stroke(path, with: .color(gridColor), lineWidth: gridLineWidth)
        }

        // Draw border
        var borderPath = Path()
        borderPath.addRect(rect)
        context.stroke(borderPath, with: .color(Color.gray.opacity(0.3)), lineWidth: gridLineWidth)
    }

    /// Draw dashed diagonal line representing ideal pace (0,0) to (1,100)
    private func drawIdealPaceLine(context: GraphicsContext, in rect: CGRect) {
        var path = Path()
        // Start from bottom-left (time=0, usage=0) to top-right (time=1, usage=100)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        let dashStyle = StrokeStyle(
            lineWidth: paceLineWidth,
            lineCap: .round,
            dash: [4, 4]
        )

        context.stroke(path, with: .color(Color.gray.opacity(0.5)), style: dashStyle)
    }

    /// Draw colored dots for each point with percentage labels
    private func drawLimitPoints(context: GraphicsContext, in rect: CGRect, points: [Point]) {
        for point in points {
            let position = calculatePosition(for: point, in: rect)

            // Draw dot
            let dotRect = CGRect(
                x: position.x - dotRadius,
                y: position.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )

            context.fill(Circle().path(in: dotRect), with: .color(point.color))

            // Draw white border for visibility
            context.stroke(
                Circle().path(in: dotRect),
                with: .color(.white.opacity(0.8)),
                lineWidth: 1
            )

            // Draw percentage label next to dot
            drawPercentageLabel(
                context: context,
                at: position,
                percentage: point.percentage,
                in: rect
            )
        }
    }

    /// Draw percentage label near a data point
    private func drawPercentageLabel(
        context: GraphicsContext,
        at point: CGPoint,
        percentage: Double,
        in rect: CGRect
    ) {
        let label = Text("\(Int(percentage))%")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.primary)

        // Position: top-right of dot by default
        var labelX = point.x + dotRadius + 4
        var labelY = point.y - dotRadius - 2

        // Boundary check: if too close to right edge, flip to left
        let labelWidth: CGFloat = 28  // Approximate width of "100%"
        if labelX + labelWidth > rect.maxX {
            labelX = point.x - dotRadius - labelWidth - 2
        }

        // If too close to top, move below dot
        if labelY < rect.minY + 8 {
            labelY = point.y + dotRadius + 10
        }

        context.draw(label, at: CGPoint(x: labelX, y: labelY))
    }

    // MARK: - Calculation Methods

    /// Calculate the position of a point on the graph
    /// X = elapsed time / total window (0 = just started, 1 = about to reset)
    /// Y = usage percentage
    private func calculatePosition(for point: Point, in rect: CGRect) -> CGPoint {
        // Calculate X position based on elapsed time
        let xNormalized = calculateElapsedTimeRatio(for: point.type, resetsAt: point.resetsAt)

        // Convert to canvas coordinates
        // X: 0 (left) = session start, 1 (right) = reset
        let x = rect.minX + xNormalized * rect.width
        // Y: 0 (bottom) = 0%, 1 (top) = 100%
        let y = rect.maxY - (CGFloat(point.percentage) / 100.0 * rect.height)

        return CGPoint(x: x, y: y)
    }

    /// Calculate the elapsed time ratio (0 = just started, 1 = about to reset)
    private func calculateElapsedTimeRatio(for limitType: LimitType, resetsAt: Date?) -> CGFloat {
        guard let resetsAt = resetsAt else {
            // If no reset time, assume just started
            return 0
        }

        // Codex windows are already classified by actual duration (see CodexUsageResponse.toCodexUsageData),
        // so codexPrimary is always the 5-hour window and codexSecondary the 7-day one
        let totalWindow: TimeInterval
        switch limitType {
        case .fiveHour, .codexPrimary:
            totalWindow = 5 * 3600  // 5 hours in seconds
        case .sevenDay, .opusWeekly, .sonnetWeekly, .extraUsage,
             .codexSecondary, .codexExtraUsage:
            totalWindow = 7 * 24 * 3600  // 7 days in seconds
        }

        let remainingTime = resetsAt.timeIntervalSinceNow
        let elapsedTime = totalWindow - remainingTime

        // Clamp to 0-1 range
        let ratio = elapsedTime / totalWindow
        return CGFloat(max(0, min(1, ratio)))
    }
}

// MARK: - Provider Initializers

extension LinearUsageGraphView {
    /// Claude limits
    init(usageData: UsageData?, activeDisplayTypes: [LimitType], isRefreshing: Bool) {
        self.isRefreshing = isRefreshing
        guard let data = usageData else {
            self.points = nil
            return
        }
        self.points = activeDisplayTypes.compactMap { type in
            switch type {
            case .fiveHour:
                return data.fiveHour.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.fiveHourColorSwiftUI($0.percentage))
                }
            case .sevenDay:
                return data.sevenDay.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.sevenDayColorSwiftUI($0.percentage))
                }
            case .opusWeekly:
                return data.opus.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: Color(UsageColorScheme.opusWeeklyColor($0.percentage)))
                }
            case .sonnetWeekly:
                return data.sonnet.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: Color(UsageColorScheme.sonnetWeeklyColor($0.percentage)))
                }
            case .extraUsage:
                // ExtraUsage has no reset window, so it sits at the start of the timeline
                guard let percentage = data.extraUsage?.percentage else { return nil }
                return Point(type: type, percentage: percentage, resetsAt: nil,
                             color: Color(UsageColorScheme.extraUsageColor(percentage)))
            case .codexPrimary, .codexSecondary, .codexExtraUsage:
                return nil
            }
        }
    }

    /// Codex limits
    init(codexUsageData: CodexUsageData?, activeDisplayTypes: [LimitType], isRefreshing: Bool) {
        self.isRefreshing = isRefreshing
        guard let data = codexUsageData else {
            self.points = nil
            return
        }
        self.points = activeDisplayTypes.compactMap { type in
            switch type {
            case .codexPrimary:
                return data.primary.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.codexPrimaryColorSwiftUI($0.percentage))
                }
            case .codexSecondary:
                return data.secondary.map {
                    Point(type: type, percentage: $0.percentage, resetsAt: $0.resetsAt,
                          color: UsageColorScheme.codexSecondaryColorSwiftUI($0.percentage))
                }
            case .codexExtraUsage:
                // Codex credits are a balance, not a percentage of a window
                return nil
            case .fiveHour, .sevenDay, .extraUsage, .opusWeekly, .sonnetWeekly:
                return nil
            }
        }
    }
}

// MARK: - Preview

struct LinearUsageGraphView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Normal state with data
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
                isRefreshing: false
            )

            // Codex
            LinearUsageGraphView(
                codexUsageData: CodexUsageData(
                    primary: .init(percentage: 30, resetsAt: Date().addingTimeInterval(3600 * 3)),
                    secondary: .init(percentage: 12, resetsAt: Date().addingTimeInterval(3600 * 24 * 6)),
                    extraUsage: nil
                ),
                activeDisplayTypes: [.codexPrimary, .codexSecondary],
                isRefreshing: false
            )

            // Loading state
            LinearUsageGraphView(
                usageData: nil,
                activeDisplayTypes: [.fiveHour],
                isRefreshing: true
            )
        }
        .padding()
    }
}
