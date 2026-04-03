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
struct LinearUsageGraphView: View {
    let usageData: UsageData?
    let activeDisplayTypes: [LimitType]
    let isRefreshing: Bool

    // MARK: - Constants

    private let graphSize: CGFloat = 114
    private let padding: CGFloat = 8
    private let gridLineWidth: CGFloat = 0.5
    private let paceLineWidth: CGFloat = 1.5
    private let dotRadius: CGFloat = 5

    // MARK: - Body

    var body: some View {
        ZStack {
            if let data = usageData, !isRefreshing {
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
                    drawLimitPoints(context: context, in: drawArea, data: data)
                }
                .frame(width: graphSize, height: graphSize)

                // Center text showing projected usage
                VStack(spacing: 2) {
                    Text(projectedUsageText(data: data))
                        .font(.system(size: 16, weight: .bold))
                    Text(L.Usage.used)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                // Loading or no data state
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: graphSize - padding * 2, height: graphSize - padding * 2)

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
        .frame(width: graphSize, height: graphSize)
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

    /// Draw colored dots for each active limit type
    private func drawLimitPoints(context: GraphicsContext, in rect: CGRect, data: UsageData) {
        for limitType in activeDisplayTypes {
            guard let point = calculatePoint(for: limitType, data: data, in: rect) else {
                continue
            }

            let color = colorForLimitType(limitType, data: data)

            // Draw dot
            let dotRect = CGRect(
                x: point.x - dotRadius,
                y: point.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )

            context.fill(Circle().path(in: dotRect), with: .color(color))

            // Draw white border for visibility
            context.stroke(
                Circle().path(in: dotRect),
                with: .color(.white.opacity(0.8)),
                lineWidth: 1
            )
        }
    }

    // MARK: - Calculation Methods

    /// Calculate the position of a limit point on the graph
    /// X = elapsed time / total window (0 = just started, 1 = about to reset)
    /// Y = usage percentage
    private func calculatePoint(for limitType: LimitType, data: UsageData, in rect: CGRect) -> CGPoint? {
        let limitData = getLimitData(for: limitType, data: data)
        guard let limit = limitData else { return nil }

        let percentage = limit.percentage

        // Calculate X position based on elapsed time
        let xNormalized = calculateElapsedTimeRatio(for: limitType, resetsAt: limit.resetsAt)

        // Convert to canvas coordinates
        // X: 0 (left) = session start, 1 (right) = reset
        let x = rect.minX + xNormalized * rect.width
        // Y: 0 (bottom) = 0%, 1 (top) = 100%
        let y = rect.maxY - (CGFloat(percentage) / 100.0 * rect.height)

        return CGPoint(x: x, y: y)
    }

    /// Calculate the elapsed time ratio (0 = just started, 1 = about to reset)
    private func calculateElapsedTimeRatio(for limitType: LimitType, resetsAt: Date?) -> CGFloat {
        guard let resetsAt = resetsAt else {
            // If no reset time, assume just started
            return 0
        }

        let totalWindow: TimeInterval
        switch limitType {
        case .fiveHour:
            totalWindow = 5 * 3600  // 5 hours in seconds
        case .sevenDay, .opusWeekly, .sonnetWeekly, .extraUsage:
            totalWindow = 7 * 24 * 3600  // 7 days in seconds
        }

        let remainingTime = resetsAt.timeIntervalSinceNow
        let elapsedTime = totalWindow - remainingTime

        // Clamp to 0-1 range
        let ratio = elapsedTime / totalWindow
        return CGFloat(max(0, min(1, ratio)))
    }

    /// Get the LimitData for a specific limit type
    private func getLimitData(for limitType: LimitType, data: UsageData) -> UsageData.LimitData? {
        switch limitType {
        case .fiveHour:
            return data.fiveHour
        case .sevenDay:
            return data.sevenDay
        case .opusWeekly:
            return data.opus
        case .sonnetWeekly:
            return data.sonnet
        case .extraUsage:
            // ExtraUsageData has different structure, convert to LimitData-like values
            // ExtraUsage doesn't have resetsAt, so we return nil for it
            if let extra = data.extraUsage, let percentage = extra.percentage {
                return UsageData.LimitData(percentage: percentage, resetsAt: nil)
            }
            return nil
        }
    }

    /// Get the color for a limit type based on its percentage
    private func colorForLimitType(_ limitType: LimitType, data: UsageData) -> Color {
        switch limitType {
        case .fiveHour:
            if let limit = data.fiveHour {
                return UsageColorScheme.fiveHourColorSwiftUI(limit.percentage)
            }
        case .sevenDay:
            if let limit = data.sevenDay {
                return UsageColorScheme.sevenDayColorSwiftUI(limit.percentage)
            }
        case .opusWeekly:
            if let limit = data.opus {
                return Color(UsageColorScheme.opusWeeklyColor(limit.percentage))
            }
        case .sonnetWeekly:
            if let limit = data.sonnet {
                return Color(UsageColorScheme.sonnetWeeklyColor(limit.percentage))
            }
        case .extraUsage:
            if let extra = data.extraUsage, let percentage = extra.percentage {
                return Color(UsageColorScheme.extraUsageColor(percentage))
            }
        }
        return .gray
    }

    /// Calculate projected usage at reset time based on current pace
    private func projectedUsageText(data: UsageData) -> String {
        // Find the primary active limit for projection
        for limitType in activeDisplayTypes {
            if let projection = calculateProjectedUsage(for: limitType, data: data) {
                return "Proj: \(Int(min(projection, 999)))%"
            }
        }
        return "--%"
    }

    /// Calculate projected usage at reset time for a limit type
    private func calculateProjectedUsage(for limitType: LimitType, data: UsageData) -> Double? {
        guard let limitData = getLimitData(for: limitType, data: data),
              let resetsAt = limitData.resetsAt else {
            return nil
        }

        let percentage = limitData.percentage
        let elapsedRatio = calculateElapsedTimeRatio(for: limitType, resetsAt: resetsAt)

        // Avoid division by zero
        guard elapsedRatio > 0.01 else {
            return percentage
        }

        // Project: if we used X% in Y time, we'll use X/Y * 1.0 at reset
        let projected = percentage / Double(elapsedRatio)
        return projected
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
