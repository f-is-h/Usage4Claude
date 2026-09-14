//
//  UsageDisplayMode.swift
//  Usage4Claude
//
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 进度显示口径：已用量填充 ↔ 余量填充。
///
/// Popover 的大圆环（`UsageRingDisplay`）和菜单栏图标（`MenuBarIconRenderer` /
/// `ShapeIconRenderer`）共用这一套换算。两处必须同口径，否则同一时刻菜单栏显示 90
/// 而主界面显示 10 —— 用户点一下切换，只有一半界面翻转过来。
///
/// 配色不走这里：颜色始终按「已用量」计算，余量模式下 90% 已用仍是红色，
/// 警示语义不会因为口径切换被反转掉。
enum UsageDisplayMode {

    /// 轨迹上实线段的起止位置，用占整条轨迹的比例表示
    /// （0 = 12 点方向的起点，1 = 绕行一整圈回到起点，顺时针推进）
    struct FillRange: Equatable {
        let from: Double
        let to: Double

        /// 实线段占整条轨迹的比例
        var length: Double { max(0, to - from) }
    }

    /// 百分比钳制到 0...100，防御脏数据把弧画到轨迹外
    static func clamped(_ percentage: Double) -> Double {
        min(100, max(0, percentage))
    }

    /// 要显示在图标中央的数字：已用模式给已用量，余量模式给剩余量
    static func displayedPercentage(usedPercentage: Double, showRemainingMode: Bool) -> Double {
        let used = clamped(usedPercentage)
        return showRemainingMode ? 100 - used : used
    }

    /// 已用模式填 `[0, used]`；余量模式填 `[used, 1]`，也就是从已用弧的末端接着画到终点。
    /// 两种模式的实线段永远互补，切换时视觉上就是同一条轨迹的明暗对调。
    static func fillRange(usedPercentage: Double, showRemainingMode: Bool) -> FillRange {
        let used = clamped(usedPercentage) / 100
        return showRemainingMode ? FillRange(from: used, to: 1) : FillRange(from: 0, to: used)
    }

    // MARK: - 单帧绘制状态

    /// 画一帧图标需要知道的全部：填色依据、实线段位置、中央数字。
    ///
    /// 静态渲染由 `state(usedPercentage:showRemainingMode:)` 从已用量和口径直接算出；
    /// 切换动画期间由 `interpolate` 给出中间值 —— 两条路径最终都汇进同一个绘制函数，
    /// 所以动画帧和静止帧不会长得不一样。
    struct State: Equatable {
        /// 配色和单色不透明度的依据，动画期间保持不变（口径切换不该让颜色跳变）
        let usedPercentage: Double
        let fill: FillRange
        /// 画在中央的数字
        let displayedPercentage: Double
    }

    static func state(usedPercentage: Double, showRemainingMode: Bool) -> State {
        State(
            usedPercentage: clamped(usedPercentage),
            fill: fillRange(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode),
            displayedPercentage: displayedPercentage(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode)
        )
    }

    /// 按进度在两个口径之间插值。
    ///
    /// 对 `from`/`to` 两端分别插值，和 Popover 那边 SwiftUI 对 `Circle().trim(from:to:)`
    /// 的做法一致：视觉上是实线段的两个端点各自滑向新位置，而不是整段擦掉重画。
    /// `progress` 允许越过 0...1（spring 会过冲），此处不钳制，只钳制最终的百分比数字。
    static func interpolate(from start: State, to end: State, progress: Double) -> State {
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

        let rawFrom = lerp(start.fill.from, end.fill.from, progress)
        let rawTo = lerp(start.fill.to, end.fill.to, progress)

        // 中央数字不跟着过冲：弧线过冲是弹性质感，读数过冲却会在收尾时抖一下
        // （66 → … → 34 → 33 → 34），静止的菜单栏上这一下很显眼
        let settled = min(1, max(0, progress))

        return State(
            usedPercentage: start.usedPercentage,
            // 过冲会把端点推出轨迹，钳回 0...1 免得弧画到圈外
            fill: FillRange(from: min(1, max(0, rawFrom)), to: min(1, max(0, rawTo))),
            displayedPercentage: clamped(lerp(start.displayedPercentage, end.displayedPercentage, settled))
        )
    }

    // MARK: - Spring 曲线

    /// Popover 大圆环用的 spring 参数，菜单栏这边照抄以保证两处手感一致
    /// （见 `UsageDetailView.toggleRemainingMode`）
    enum Spring {
        static let response: Double = 0.42
        static let dampingFraction: Double = 0.78
        /// 动画总时长。包络 e^(-t/τ) 的时间常数 τ = 1/(ζω₀) ≈ 0.086s，
        /// 0.55s 已衰减到千分之一以下，视觉上 0.4s 后就看不出变化了
        static let duration: Double = 0.55
    }

    /// SwiftUI `.spring(response:dampingFraction:)` 的归一化位移曲线。
    ///
    /// Popover 那边由 SwiftUI 自己驱动动画，菜单栏图标是逐帧重画的 NSImage，
    /// 只能手算同一条曲线，否则两处的切换手感会明显不同。
    /// 返回值可能略大于 1（欠阻尼过冲），调用方自行决定是否钳制。
    static func springProgress(
        elapsed: Double,
        response: Double = Spring.response,
        dampingFraction: Double = Spring.dampingFraction
    ) -> Double {
        guard elapsed > 0 else { return 0 }
        guard response > 0 else { return 1 }

        let omega0 = 2 * Double.pi / response
        let zeta = max(0, dampingFraction)
        let t = elapsed

        if zeta < 1 {
            // 欠阻尼：收敛前会有轻微过冲，正是 dampingFraction < 1 想要的回弹手感
            let omegaD = omega0 * (1 - zeta * zeta).squareRoot()
            let decay = exp(-zeta * omega0 * t)
            return 1 - decay * (cos(omegaD * t) + (zeta * omega0 / omegaD) * sin(omegaD * t))
        } else {
            // 临界阻尼及以上：单调趋近，无过冲
            let decay = exp(-omega0 * t)
            return 1 - decay * (1 + omega0 * t)
        }
    }
}
