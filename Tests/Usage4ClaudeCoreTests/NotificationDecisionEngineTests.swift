import XCTest
@testable import Usage4ClaudeCore

/// 覆盖风险：审计报告「六、测试覆盖」指出的重复/漏发通知——
/// 陈旧标志清理写错、阈值穿越判定写错、重置检测写错都会在这里体现。
final class NotificationDecisionEngineTests: XCTestCase {

    private let warningKey = "claude:acc:fiveHour"
    private let earlyKey = "claude:acc:sevenDay:75"

    // MARK: - isReset

    func testIsResetOnLargePercentageDrop() {
        XCTAssertTrue(NotificationDecisionEngine.isReset(
            currentPct: 10, previousPct: 95, currentResetsAt: nil, previousResetsAt: nil
        ))
    }

    func testIsNotResetOnSmallPercentageDrop() {
        XCTAssertFalse(NotificationDecisionEngine.isReset(
            currentPct: 80, previousPct: 95, currentResetsAt: nil, previousResetsAt: nil
        ))
    }

    func testIsResetOnResetsAtChangeWithPercentageDecrease() {
        let previous = Date()
        let current = previous.addingTimeInterval(3600)
        XCTAssertTrue(NotificationDecisionEngine.isReset(
            currentPct: 5, previousPct: 50, currentResetsAt: current, previousResetsAt: previous
        ))
    }

    func testIsNotResetWhenResetsAtChangesButPercentageIncreases() {
        let previous = Date()
        let current = previous.addingTimeInterval(3600)
        XCTAssertFalse(NotificationDecisionEngine.isReset(
            currentPct: 60, previousPct: 50, currentResetsAt: current, previousResetsAt: previous
        ))
    }

    // MARK: - evaluate: no data

    func testEvaluateReturnsNoActionsWhenCurrentIsNil() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: nil, previous: 50,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: ["x": 1]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings, ["x": 1])
    }

    // MARK: - evaluate: 90% 阈值穿越

    func testEvaluateFiresWarningWhenCrossing90Percent() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 92, previous: 80,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[warningKey], 0)
    }

    func testEvaluateDoesNotDuplicateWarningAlreadyNotified() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 95, previous: 92,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: 0]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[warningKey], 0)
    }

    func testEvaluateFiresExactlyAtThresholdBoundary() {
        let (actions, _) = NotificationDecisionEngine.evaluate(
            current: 90, previous: 89.9,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertEqual(actions, [.warning(percentage: 90)])
    }

    func testEvaluateDoesNotFireWhenAlreadyAtThresholdWithoutCrossing() {
        // previous 已经 >= 阈值，说明这不是一次"穿越"，只是同一水平的重复读数
        let (actions, _) = NotificationDecisionEngine.evaluate(
            current: 91, previous: 90,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertTrue(actions.isEmpty)
    }

    func testEvaluateDoesNotFireWhenStayingAboveThresholdWithoutPreviousData() {
        // previous == nil 时按 0 处理，不应因为"从 0 到 current"的跨越误判——
        // 只要 current 本身 >= 阈值就该发；这里验证 current < 阈值时确实不发
        let (actions, _) = NotificationDecisionEngine.evaluate(
            current: 50, previous: nil,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: - evaluate: 75% 早期预警（仅 sevenDay/codexSecondary 类型传 earlyWarningKey）

    func testEvaluateFiresEarlyWarningWhenCrossing75Percent() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 78, previous: 60,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: earlyKey,
            notifiedWarnings: [:]
        )
        XCTAssertEqual(actions, [.warning(percentage: 78)])
        XCTAssertNotNil(warnings[earlyKey])
        XCTAssertNil(warnings[warningKey])
    }

    func testEvaluateFiresBothEarlyAndMainWarningInOrderWhenJumpingPast90() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 95, previous: 10,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: earlyKey,
            notifiedWarnings: [:]
        )
        XCTAssertEqual(actions, [.warning(percentage: 95), .warning(percentage: 95)])
        XCTAssertNotNil(warnings[earlyKey])
        XCTAssertNotNil(warnings[warningKey])
    }

    func testEvaluateDoesNotFireEarlyWarningWhenTypeIsIneligible() {
        // earlyWarningKey == nil 模拟非 sevenDay/codexSecondary 类型：即使跨越 75% 也不发早期预警
        let (actions, _) = NotificationDecisionEngine.evaluate(
            current: 78, previous: 60,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: - evaluate: 重置检测

    func testEvaluateFiresResetAndClearsBothKeysOnPercentageDrop() {
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 5, previous: 95,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: earlyKey,
            notifiedWarnings: [warningKey: 100, earlyKey: 100, "other": 1]
        )
        XCTAssertEqual(actions, [.reset])
        XCTAssertNil(warnings[warningKey])
        XCTAssertNil(warnings[earlyKey])
        XCTAssertEqual(warnings["other"], 1)
    }

    func testEvaluateFiresResetAndClearsBothKeysOnResetsAtChange() {
        // 百分比骤降之外的第二条重置触发路径：resetsAt 变了且百分比下降
        let previous = Date()
        let current = previous.addingTimeInterval(3600)
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 5, previous: 50,
            currentResetsAt: current, previousResetsAt: previous,
            warningKey: warningKey, earlyWarningKey: earlyKey,
            notifiedWarnings: [warningKey: 100, earlyKey: 100]
        )
        XCTAssertEqual(actions, [.reset])
        XCTAssertNil(warnings[warningKey])
        XCTAssertNil(warnings[earlyKey])
    }

    func testEvaluateDoesNotFireResetWhenNoPreviousData() {
        let (actions, _) = NotificationDecisionEngine.evaluate(
            current: 5, previous: nil,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [:]
        )
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: - evaluate: 陈旧标志清理（应用未运行期间配额已重置）

    func testEvaluateClearsStaleFlagFromPreviousCycleAndRefires() {
        let oldCycle = Date(timeIntervalSince1970: 1000)
        let newCycle = Date(timeIntervalSince1970: 5000)

        // 标志属于 oldCycle，但当前 resetsAt 已经是 newCycle——应用未运行期间发生了重置，
        // isReset 的内存对比（无 previous 或 previous 已经很低）捕获不到，需要靠陈旧标志清理来避免漏发
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 92, previous: 10,
            currentResetsAt: newCycle, previousResetsAt: newCycle,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: oldCycle.timeIntervalSince1970]
        )
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[warningKey], newCycle.timeIntervalSince1970)
    }

    func testEvaluateKeepsFlagWhenCycleUnchanged() {
        let cycle = Date(timeIntervalSince1970: 5000)
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 95, previous: 92,
            currentResetsAt: cycle, previousResetsAt: cycle,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: cycle.timeIntervalSince1970]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[warningKey], cycle.timeIntervalSince1970)
    }

    func testEvaluateTreatsExactlyOneSecondApartCycleAsUnchanged() {
        // clearIfStale 用 `> 1` 秒判断，恰好相差 1 秒不应被当作陈旧（边界值）
        let oldCycle = Date(timeIntervalSince1970: 5000)
        let newCycle = Date(timeIntervalSince1970: 5001)
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 95, previous: 92,
            currentResetsAt: newCycle, previousResetsAt: newCycle,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: oldCycle.timeIntervalSince1970]
        )
        XCTAssertTrue(actions.isEmpty, "1 秒内的抖动不应被当作新周期而重新触发警告")
        XCTAssertEqual(warnings[warningKey], oldCycle.timeIntervalSince1970)
    }

    func testEvaluateDoesNotClearFlagWhenCurrentResetsAtIsNilLikeExtraUsage() {
        // Extra Usage 一类没有 resetsAt 的类型：currentCycle == 0 时应跳过陈旧清理，维持原有行为
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 95, previous: 92,
            currentResetsAt: nil, previousResetsAt: nil,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: 12345]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[warningKey], 12345)
    }

    func testEvaluateMigratesLegacyBoolFlagAsAlwaysStale() {
        // 旧版 [String: Bool] 迁移为 1.0（NotificationManager.init 里做的转换），
        // 与任何真实 resetsAt epoch 都不同，应被当作陈旧标志清理并允许重新通知
        let cycle = Date(timeIntervalSince1970: 999_999)
        let (actions, warnings) = NotificationDecisionEngine.evaluate(
            current: 92, previous: 10,
            currentResetsAt: cycle, previousResetsAt: cycle,
            warningKey: warningKey, earlyWarningKey: nil,
            notifiedWarnings: [warningKey: 1.0]
        )
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[warningKey], cycle.timeIntervalSince1970)
    }
}
