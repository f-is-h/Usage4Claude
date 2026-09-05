import XCTest
@testable import Usage4ClaudeCore

/// 覆盖风险：Popover 与菜单栏图标口径不一致，或余量模式把 0%/100% 边界画反 ——
/// 前者让同一时刻两处数字对不上，后者会把「用满了」显示成一整圈填充。
final class UsageDisplayModeTests: XCTestCase {

    // MARK: - 显示数值

    func testUsedModeShowsUsedPercentage() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 66, showRemainingMode: false), 66)
    }

    func testRemainingModeShowsComplement() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 66, showRemainingMode: true), 34)
    }

    func testRemainingModeAtZeroUsedIsFull() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 0, showRemainingMode: true), 100)
    }

    func testRemainingModeAtFullUsedIsZero() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 100, showRemainingMode: true), 0)
    }

    // MARK: - 钳制（脏数据不该把弧画到轨迹外）

    func testNegativeUsedIsClampedToZero() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: -20, showRemainingMode: false), 0)
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: -20, showRemainingMode: true), 100)
    }

    func testOverflowUsedIsClampedToHundred() {
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 140, showRemainingMode: false), 100)
        XCTAssertEqual(UsageDisplayMode.displayedPercentage(usedPercentage: 140, showRemainingMode: true), 0)
    }

    // MARK: - 填充区间

    func testUsedModeFillsFromStart() {
        let range = UsageDisplayMode.fillRange(usedPercentage: 25, showRemainingMode: false)
        XCTAssertEqual(range.from, 0)
        XCTAssertEqual(range.to, 0.25, accuracy: 1e-9)
    }

    func testRemainingModeFillsFromUsedEndToFinish() {
        let range = UsageDisplayMode.fillRange(usedPercentage: 25, showRemainingMode: true)
        XCTAssertEqual(range.from, 0.25, accuracy: 1e-9)
        XCTAssertEqual(range.to, 1)
    }

    /// 两种模式的实线段必须互补：切换时视觉上就是同一条轨迹的明暗对调，不会缺一块或叠一块
    func testFillRangesAreComplementary() {
        for used in stride(from: 0.0, through: 100.0, by: 5.0) {
            let usedRange = UsageDisplayMode.fillRange(usedPercentage: used, showRemainingMode: false)
            let remainingRange = UsageDisplayMode.fillRange(usedPercentage: used, showRemainingMode: true)

            XCTAssertEqual(usedRange.to, remainingRange.from, accuracy: 1e-9, "used=\(used) 两段应当首尾相接")
            XCTAssertEqual(usedRange.length + remainingRange.length, 1, accuracy: 1e-9, "used=\(used) 两段之和应当是整条轨迹")
        }
    }

    /// 填充长度必须与中央数字一致，否则会出现「画了 34% 的弧、写着 66」
    func testFillLengthMatchesDisplayedPercentage() {
        for used in stride(from: 0.0, through: 100.0, by: 5.0) {
            for remaining in [false, true] {
                let range = UsageDisplayMode.fillRange(usedPercentage: used, showRemainingMode: remaining)
                let displayed = UsageDisplayMode.displayedPercentage(usedPercentage: used, showRemainingMode: remaining)
                XCTAssertEqual(range.length * 100, displayed, accuracy: 1e-9, "used=\(used) remaining=\(remaining)")
            }
        }
    }

    func testEmptyAndFullEdges() {
        let emptyUsed = UsageDisplayMode.fillRange(usedPercentage: 0, showRemainingMode: false)
        XCTAssertEqual(emptyUsed.length, 0)

        let fullUsed = UsageDisplayMode.fillRange(usedPercentage: 100, showRemainingMode: false)
        XCTAssertEqual(fullUsed.length, 1, accuracy: 1e-9)

        let emptyRemaining = UsageDisplayMode.fillRange(usedPercentage: 100, showRemainingMode: true)
        XCTAssertEqual(emptyRemaining.length, 0, accuracy: 1e-9)

        let fullRemaining = UsageDisplayMode.fillRange(usedPercentage: 0, showRemainingMode: true)
        XCTAssertEqual(fullRemaining.length, 1)
    }
}

/// 覆盖风险：菜单栏图标是逐帧手画的，spring 曲线或插值算错会让切换动画
/// 卡在半截、反向弹出去，或者中途把弧画到轨迹外面。
final class UsageDisplayTransitionTests: XCTestCase {

    // MARK: - Spring 曲线

    func testSpringStartsAtZero() {
        XCTAssertEqual(UsageDisplayMode.springProgress(elapsed: 0), 0)
    }

    func testSpringConvergesToOneByDuration() {
        let end = UsageDisplayMode.springProgress(elapsed: UsageDisplayMode.Spring.duration)
        XCTAssertEqual(end, 1, accuracy: 0.01, "动画时长结束时应已基本收敛，否则收尾会有可见跳变")
    }

    func testSpringRisesEarly() {
        // 前段必须实际动起来，否则观感是「延迟一下才跳过去」
        let quarter = UsageDisplayMode.springProgress(elapsed: UsageDisplayMode.Spring.response / 4)
        XCTAssertGreaterThan(quarter, 0.1)
        XCTAssertLessThan(quarter, 1.0)
    }

    /// 欠阻尼（dampingFraction < 1）应当有轻微过冲，这是回弹手感的来源
    func testUnderdampedOvershoots() {
        let peak = stride(from: 0.0, through: UsageDisplayMode.Spring.duration, by: 0.005)
            .map { UsageDisplayMode.springProgress(elapsed: $0) }
            .max() ?? 0
        XCTAssertGreaterThan(peak, 1.0)
        XCTAssertLessThan(peak, 1.15, "过冲过大在 18pt 图标上会显得弹跳失控")
    }

    /// 临界阻尼不该过冲
    func testCriticallyDampedDoesNotOvershoot() {
        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let value = UsageDisplayMode.springProgress(elapsed: t, response: 0.42, dampingFraction: 1.0)
            XCTAssertLessThanOrEqual(value, 1.0 + 1e-9, "t=\(t)")
        }
    }

    // MARK: - 插值

    func testInterpolateAtZeroIsStart() {
        let start = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: true)
        XCTAssertEqual(UsageDisplayMode.interpolate(from: start, to: end, progress: 0), start)
    }

    func testInterpolateAtOneIsEnd() {
        let start = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: true)
        XCTAssertEqual(UsageDisplayMode.interpolate(from: start, to: end, progress: 1), end)
    }

    /// 配色依据在动画期间不能变，否则环会在切换途中改颜色
    func testInterpolateKeepsUsedPercentage() {
        let start = UsageDisplayMode.state(usedPercentage: 93, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 93, showRemainingMode: true)
        for p in stride(from: 0.0, through: 1.0, by: 0.1) {
            let mid = UsageDisplayMode.interpolate(from: start, to: end, progress: p)
            XCTAssertEqual(mid.usedPercentage, 93, accuracy: 1e-9)
        }
    }

    /// 过冲不能把弧的端点推出轨迹
    func testOvershootIsClampedToTrack() {
        let start = UsageDisplayMode.state(usedPercentage: 20, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 20, showRemainingMode: true)
        let overshoot = UsageDisplayMode.interpolate(from: start, to: end, progress: 1.12)

        XCTAssertGreaterThanOrEqual(overshoot.fill.from, 0)
        XCTAssertLessThanOrEqual(overshoot.fill.to, 1)
        XCTAssertGreaterThanOrEqual(overshoot.displayedPercentage, 0)
        XCTAssertLessThanOrEqual(overshoot.displayedPercentage, 100)
    }

    /// 中央数字不跟着过冲：否则收尾会出现 34 → 33 → 34 的抖动
    func testOvershootDoesNotBounceTheNumber() {
        let start = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: true)

        for progress in [1.0, 1.02, 1.2] {
            let frame = UsageDisplayMode.interpolate(from: start, to: end, progress: progress)
            XCTAssertEqual(frame.displayedPercentage, end.displayedPercentage, accuracy: 1e-9,
                           "progress=\(progress) 时数字应当已经停在终值")
        }
    }

    /// 弧线本身仍要保留过冲，那是弹性手感的来源
    func testOvershootStillMovesTheArc() {
        let start = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 66, showRemainingMode: true)
        let overshoot = UsageDisplayMode.interpolate(from: start, to: end, progress: 1.02)

        XCTAssertGreaterThan(overshoot.fill.from, end.fill.from, "起点应当略微越过终位再弹回")
    }

    /// 中间帧的端点必须落在起止之间，不能反向甩出去
    func testMidFramesStayBetweenEnds() {
        let start = UsageDisplayMode.state(usedPercentage: 40, showRemainingMode: false)
        let end = UsageDisplayMode.state(usedPercentage: 40, showRemainingMode: true)
        for p in stride(from: 0.0, through: 1.0, by: 0.05) {
            let mid = UsageDisplayMode.interpolate(from: start, to: end, progress: p)
            XCTAssertGreaterThanOrEqual(mid.fill.from, start.fill.from - 1e-9, "p=\(p)")
            XCTAssertLessThanOrEqual(mid.fill.from, end.fill.from + 1e-9, "p=\(p)")
            XCTAssertLessThanOrEqual(mid.fill.to, 1 + 1e-9, "p=\(p)")
        }
    }
}
