import XCTest
import CoreGraphics
@testable import Usage4ClaudeCore

/// 覆盖风险：节奏图把点画错位置（时间轴反向、越出边框）或标签互相遮挡、被裁出图表 ——
/// 前者会让用户误判自己是超前还是落后于匀速消耗，后者让数字读不出来。
final class UsagePaceGraphMathTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let fiveHour = UsagePaceGraphMath.fiveHourWindow
    private let sevenDay = UsagePaceGraphMath.sevenDayWindow

    // MARK: - 时间轴位置

    func testWindowJustStartedIsZero() {
        let ratio = UsagePaceGraphMath.elapsedRatio(resetsAt: now.addingTimeInterval(fiveHour), windowSeconds: fiveHour, now: now)
        XCTAssertEqual(ratio, 0, accuracy: 1e-9)
    }

    func testHalfwayThroughWindowIsHalf() {
        let ratio = UsagePaceGraphMath.elapsedRatio(resetsAt: now.addingTimeInterval(fiveHour / 2), windowSeconds: fiveHour, now: now)
        XCTAssertEqual(ratio, 0.5, accuracy: 1e-9)
    }

    func testSevenDayWindowUsesItsOwnLength() {
        let ratio = UsagePaceGraphMath.elapsedRatio(resetsAt: now.addingTimeInterval(sevenDay / 4), windowSeconds: sevenDay, now: now)
        XCTAssertEqual(ratio, 0.75, accuracy: 1e-9)
    }

    func testNilResetIsTreatedAsNotStarted() {
        XCTAssertEqual(UsagePaceGraphMath.elapsedRatio(resetsAt: nil, windowSeconds: fiveHour, now: now), 0)
    }

    func testResetInThePastIsClampedToOne() {
        let ratio = UsagePaceGraphMath.elapsedRatio(resetsAt: now.addingTimeInterval(-60), windowSeconds: fiveHour, now: now)
        XCTAssertEqual(ratio, 1)
    }

    func testResetBeyondWindowIsClampedToZero() {
        let ratio = UsagePaceGraphMath.elapsedRatio(resetsAt: now.addingTimeInterval(fiveHour * 2), windowSeconds: fiveHour, now: now)
        XCTAssertEqual(ratio, 0)
    }

    // MARK: - 仅工作日时间轴

    /// 固定为周六日休息、UTC 的日历，结果不随运行机器的地区与时区变化
    private var workweekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-09-14 是周一
    private func utc(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        workweekCalendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testWeekdayRatioIgnoresTheWeekendInTheWindow() {
        // 周一 0 点开始、下周一重置：周三中午恰好用掉 5 个工作日中的一半
        let ratio = UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: utc(21), windowSeconds: sevenDay, calendar: workweekCalendar, now: utc(16, 12))
        XCTAssertEqual(ratio, 0.5, accuracy: 1e-9)
    }

    func testWeekdayRatioReachesOneWhenOnlyTheWeekendRemains() {
        let ratio = UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: utc(21), windowSeconds: sevenDay, calendar: workweekCalendar, now: utc(19, 15))
        XCTAssertEqual(ratio, 1, accuracy: 1e-9)
    }

    func testWeekdayRatioHoldsStillAcrossAMidWindowWeekend() {
        // 周四中午开始：工作日共 120 小时，到周五结束已过 36 小时，整个周末停在 0.3
        let resetsAt = utc(24, 12)
        let saturday = UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: resetsAt, windowSeconds: sevenDay, calendar: workweekCalendar, now: utc(19, 10))
        let sunday = UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: resetsAt, windowSeconds: sevenDay, calendar: workweekCalendar, now: utc(20, 20))
        XCTAssertEqual(saturday, 0.3, accuracy: 1e-9)
        XCTAssertEqual(sunday, 0.3, accuracy: 1e-9)
    }

    func testWindowEntirelyOnTheWeekendFallsBackToWallClock() {
        let ratio = UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: utc(19, 15), windowSeconds: fiveHour, calendar: workweekCalendar, now: utc(19, 12, 30))
        XCTAssertEqual(ratio, 0.5, accuracy: 1e-9)
    }

    func testWeekdayRatioTreatsNilResetAsNotStarted() {
        XCTAssertEqual(UsagePaceGraphMath.weekdayElapsedRatio(
            resetsAt: nil, windowSeconds: sevenDay, calendar: workweekCalendar, now: utc(16)), 0)
    }

    func testWeekdaySecondsHandlesADaylightSavingDay() {
        // 2026-11-01（周日）美东结束夏令时，当天 25 小时；逐日切分不能把这一小时算到周一头上
        var calendar = workweekCalendar
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!
        XCTAssertEqual(UsagePaceGraphMath.weekdaySeconds(from: friday, to: tuesday, calendar: calendar), 2 * 86_400)
    }

    // MARK: - 坐标换算

    private let plotRect = CGRect(x: 10, y: 20, width: 200, height: 100)

    func testPositionMapsStartAndZeroToBottomLeft() {
        XCTAssertEqual(UsagePaceGraphMath.position(elapsedRatio: 0, percentage: 0, in: plotRect), CGPoint(x: 10, y: 120))
    }

    func testPositionMapsResetAndFullToTopRight() {
        XCTAssertEqual(UsagePaceGraphMath.position(elapsedRatio: 1, percentage: 100, in: plotRect), CGPoint(x: 210, y: 20))
    }

    func testOverflowPercentageStaysOnTopEdge() {
        XCTAssertEqual(UsagePaceGraphMath.position(elapsedRatio: 0.5, percentage: 140, in: plotRect).y, 20)
    }

    func testNegativePercentageStaysOnBottomEdge() {
        XCTAssertEqual(UsagePaceGraphMath.position(elapsedRatio: 0.5, percentage: -5, in: plotRect).y, 120)
    }

    // MARK: - 标签布局

    private let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    private let labelSize = CGSize(width: 20, height: 10)

    private func frames(_ dots: [CGPoint]) -> [CGRect] {
        UsagePaceGraphMath.labelFrames(
            dots: dots,
            sizes: Array(repeating: labelSize, count: dots.count),
            markerRadius: 5,
            gap: 3,
            in: bounds
        )
    }

    private func assertNoOverlapAndInside(_ frames: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        for (i, a) in frames.enumerated() {
            XCTAssertTrue(bounds.contains(a), "标签 \(i) 超出图表：\(a)", file: file, line: line)
            for b in frames[(i + 1)...] {
                XCTAssertFalse(a.intersects(b), "标签重叠：\(a) / \(b)", file: file, line: line)
            }
        }
    }

    func testLabelSitsRightOfDotAndVerticallyCentered() {
        XCTAssertEqual(frames([CGPoint(x: 50, y: 50)]), [CGRect(x: 58, y: 45, width: 20, height: 10)])
    }

    func testLabelFlipsLeftNearRightEdge() {
        XCTAssertEqual(frames([CGPoint(x: 190, y: 50)]), [CGRect(x: 162, y: 45, width: 20, height: 10)])
    }

    func testLabelIsClampedInsideTopAndBottom() {
        XCTAssertEqual(frames([CGPoint(x: 50, y: 1)])[0].minY, 0)
        XCTAssertEqual(frames([CGPoint(x: 50, y: 99)])[0].maxY, 100)
    }

    func testLabelsInDifferentColumnsKeepTheirPosition() {
        let result = frames([CGPoint(x: 30, y: 50), CGPoint(x: 150, y: 50)])
        XCTAssertEqual(result.map(\.minY), [45, 45])
    }

    func testStackedLabelsInOneColumnDoNotOverlap() {
        // 7天 / Opus / Sonnet 共用重置时间且用量接近时的典型情形
        assertNoOverlapAndInside(frames([CGPoint(x: 100, y: 50), CGPoint(x: 100, y: 52), CGPoint(x: 100, y: 54)]))
    }

    func testStackedLabelsAtBottomMoveUp() {
        let result = frames([CGPoint(x: 100, y: 98), CGPoint(x: 100, y: 99)])
        assertNoOverlapAndInside(result)
    }

    func testResultOrderMatchesInputOrder() {
        // 输入顺序与 y 顺序相反时，返回值仍要与输入一一对应
        let result = frames([CGPoint(x: 50, y: 80), CGPoint(x: 150, y: 20)])
        XCTAssertEqual(result[0].midY, 80)
        XCTAssertEqual(result[1].midY, 20)
    }
}
