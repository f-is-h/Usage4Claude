//
//  UsagePaceGraphMath.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-09-14.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import Foundation
import CoreGraphics

/// 线性用量图（`LinearUsageGraphView`）的纯计算：时间轴位置、百分比钳制与标签避让。
///
/// 与 SwiftUI 解耦以便单元测试。坐标系与 Canvas 一致：y 轴向下，
/// 所以 100% 在绘制区域顶部（minY），0% 在底部（maxY）。
enum UsagePaceGraphMath {

    /// 5小时窗口时长（秒）
    static let fiveHourWindow: TimeInterval = 5 * 3600
    /// 7天窗口时长（秒）
    static let sevenDayWindow: TimeInterval = 7 * 24 * 3600

    // MARK: - 时间轴与数值

    /// 窗口已过去的比例（0 = 窗口刚开始，1 = 即将重置）
    /// - Parameters:
    ///   - resetsAt: 重置时间，nil 表示窗口尚未开始（尚未使用）
    ///   - windowSeconds: 窗口总时长（秒）
    ///   - now: 当前时间，便于测试注入
    /// - Returns: 钳制到 0...1 的比例；重置时间已过或超出窗口长度的脏数据不会把点画到图外
    static func elapsedRatio(resetsAt: Date?, windowSeconds: TimeInterval, now: Date = Date()) -> Double {
        guard let resetsAt = resetsAt, windowSeconds > 0 else { return 0 }
        let elapsed = windowSeconds - resetsAt.timeIntervalSince(now)
        return min(1, max(0, elapsed / windowSeconds))
    }

    /// 窗口已过去的比例，只计工作日时间（周末不计入时间轴）
    ///
    /// 只在工作日使用订阅的用户，周末不会消耗额度；把周末算进窗口会让匀速对角线
    /// 在周五显得「落后」、周一又突然「超前」。这里把窗口内的周末剔除，
    /// 周末期间比例停在周五结束时的位置不动。
    /// - Parameters:
    ///   - resetsAt: 重置时间，nil 表示窗口尚未开始（尚未使用）
    ///   - windowSeconds: 窗口总时长（秒）
    ///   - calendar: 判定周末用的日历（周末定义随地区而异，时区决定每天从何时开始）
    ///   - now: 当前时间，便于测试注入
    /// - Returns: 钳制到 0...1 的比例；窗口完全落在周末时退回按自然时间计算
    static func weekdayElapsedRatio(
        resetsAt: Date?,
        windowSeconds: TimeInterval,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Double {
        guard let resetsAt = resetsAt, windowSeconds > 0 else { return 0 }
        let windowStart = resetsAt.addingTimeInterval(-windowSeconds)
        let total = weekdaySeconds(from: windowStart, to: resetsAt, calendar: calendar)
        guard total > 0 else {
            return elapsedRatio(resetsAt: resetsAt, windowSeconds: windowSeconds, now: now)
        }
        let clampedNow = min(resetsAt, max(windowStart, now))
        let elapsed = weekdaySeconds(from: windowStart, to: clampedNow, calendar: calendar)
        return min(1, max(0, elapsed / total))
    }

    /// 区间内落在非周末日的秒数
    /// - Note: 按自然日逐日切分，夏令时切换日的 23 / 25 小时也能正确累计
    static func weekdaySeconds(from start: Date, to end: Date, calendar: Calendar) -> TimeInterval {
        guard end > start else { return 0 }
        var total: TimeInterval = 0
        var dayStart = calendar.startOfDay(for: start)
        while dayStart < end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            if !calendar.isDateInWeekend(dayStart) {
                total += min(end, nextDay).timeIntervalSince(max(start, dayStart))
            }
            dayStart = nextDay
        }
        return total
    }

    /// 百分比钳制到 0...100，防止超额数据把点画出图表边框
    static func clampedPercentage(_ percentage: Double) -> Double {
        min(100, max(0, percentage))
    }

    /// 把（时间比例, 已用百分比）换算成绘制区域内的坐标
    static func position(elapsedRatio: Double, percentage: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(min(1, max(0, elapsedRatio))) * rect.width,
            y: rect.maxY - CGFloat(clampedPercentage(percentage) / 100) * rect.height
        )
    }

    // MARK: - 标签布局

    /// 计算每个数据点百分比标签的位置
    /// - Parameters:
    ///   - dots: 数据点中心坐标
    ///   - sizes: 与 dots 一一对应的标签尺寸
    ///   - markerRadius: 数据点标记的视觉半径，标签与标记之间留出 gap
    ///   - gap: 标签与标记的间距
    ///   - bounds: 标签必须落在其中的区域
    /// - Returns: 与 dots 一一对应的标签矩形
    /// - Note: 默认放在点右侧并垂直居中，靠近右边缘时翻到左侧。
    ///   7天 / Opus / Sonnet 共用同一个重置时间，会落在同一列上，
    ///   因此自上而下逐个放置，与已放置的标签重叠时向下让位，触底后改为向上让位。
    ///   若让位后标签离点超过一个标签高度（已看不出属于哪个点），改放到点的另一侧。
    static func labelFrames(
        dots: [CGPoint],
        sizes: [CGSize],
        markerRadius: CGFloat,
        gap: CGFloat = 3,
        in bounds: CGRect
    ) -> [CGRect] {
        precondition(dots.count == sizes.count, "每个数据点都需要一个标签尺寸")

        var frames = [CGRect](repeating: .zero, count: dots.count)
        var placed: [CGRect] = []
        let order = dots.indices.sorted { dots[$0].y < dots[$1].y }

        for index in order {
            let dot = dots[index]
            let size = sizes[index]
            let rightX = dot.x + markerRadius + gap
            let leftX = dot.x - markerRadius - gap - size.width

            let preferredX = rightX + size.width > bounds.maxX ? max(bounds.minX, leftX) : rightX
            var frame = stackedFrame(x: preferredX, dot: dot, size: size, avoiding: placed, in: bounds)

            // 首选侧让位太远时，另一侧（需完整落在边界内）若更贴近数据点则改用另一侧
            let otherX = preferredX == rightX ? leftX : rightX
            if displacement(of: frame, from: dot, avoiding: placed) > size.height,
               otherX >= bounds.minX, otherX + size.width <= bounds.maxX {
                let other = stackedFrame(x: otherX, dot: dot, size: size, avoiding: placed, in: bounds)
                if displacement(of: other, from: dot, avoiding: placed)
                    < displacement(of: frame, from: dot, avoiding: placed) {
                    frame = other
                }
            }

            frames[index] = frame
            placed.append(frame)
        }
        return frames
    }

    /// 在给定 x 上垂直居中放置标签，与已放置的标签重叠时向下让位，触底后改为向上让位
    private static func stackedFrame(
        x: CGFloat,
        dot: CGPoint,
        size: CGSize,
        avoiding placed: [CGRect],
        in bounds: CGRect
    ) -> CGRect {
        let minY = bounds.minY
        let maxY = bounds.maxY - size.height

        var frame = CGRect(
            x: x,
            y: min(maxY, max(minY, dot.y - size.height / 2)),
            width: size.width,
            height: size.height
        )

        // 方向一旦改为向上就不再回头，保证循环必然结束
        var movingUp = false
        while let hit = placed.first(where: { $0.intersects(frame) }) {
            if !movingUp && hit.maxY + 1 <= maxY {
                frame.origin.y = hit.maxY + 1
                continue
            }
            movingUp = true
            let above = hit.minY - size.height - 1
            guard above >= minY else { break }  // 上下都放不下时接受重叠
            frame.origin.y = above
        }
        return frame
    }

    /// 标签中心与数据点的垂直距离；仍与已放置标签重叠的位置视为无穷远
    private static func displacement(of frame: CGRect, from dot: CGPoint, avoiding placed: [CGRect]) -> CGFloat {
        placed.contains(where: { $0.intersects(frame) }) ? .infinity : abs(frame.midY - dot.y)
    }
}
