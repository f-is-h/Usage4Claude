import XCTest
@testable import Usage4ClaudeCore

/// 覆盖风险：重复/漏发通知——阈值穿越、重置检测、陈旧记录清理、阈值调整后的静默标记、
/// 旧记录迁移，任何一处写错都会在这里体现。
final class NotificationDecisionEngineTests: XCTestCase {

    private let prefix = "claude:acc:five_hour:"

    private func key(_ threshold: Int) -> String {
        NotificationKeys.key(limitPrefix: prefix, threshold: threshold)
    }

    private func evaluate(
        current: Double?,
        previous: Double?,
        currentResetsAt: Date? = nil,
        previousResetsAt: Date? = nil,
        hasResetTime: Bool = true,
        thresholds: [Int] = [90],
        warnings: [String: Double] = [:]
    ) -> (actions: [NotificationDecisionAction], updatedWarnings: [String: Double]) {
        NotificationDecisionEngine.evaluate(
            current: current,
            previous: previous,
            currentResetsAt: currentResetsAt,
            previousResetsAt: previousResetsAt,
            hasResetTime: hasResetTime,
            limitPrefix: prefix,
            thresholds: thresholds,
            notifiedWarnings: warnings
        )
    }

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

    func testIsNotResetWhenDropStartsBelowDetectionFloor() {
        // 重置检测与用户阈值脱钩：阈值可以设到 50%，但 60% → 25% 不能算重置
        XCTAssertFalse(NotificationDecisionEngine.isReset(
            currentPct: 25, previousPct: 60, currentResetsAt: nil, previousResetsAt: nil
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
        let (actions, warnings) = evaluate(current: nil, previous: 50, warnings: ["x": 1])
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings, ["x": 1])
    }

    // MARK: - evaluate: 阈值穿越

    func testEvaluateFiresWarningWhenCrossingThreshold() {
        let (actions, warnings) = evaluate(current: 92, previous: 80)
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[key(90)], 0)
    }

    func testEvaluateFiresAtCustomThreshold() {
        let (actions, warnings) = evaluate(current: 61, previous: 55, thresholds: [60])
        XCTAssertEqual(actions, [.warning(percentage: 61)])
        XCTAssertNotNil(warnings[key(60)])
    }

    func testEvaluateDoesNotDuplicateWarningAlreadyNotified() {
        let (actions, warnings) = evaluate(current: 95, previous: 80, warnings: [key(90): 0])
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[key(90)], 0)
    }

    func testEvaluateFiresExactlyAtThresholdBoundary() {
        let (actions, _) = evaluate(current: 90, previous: 89.9)
        XCTAssertEqual(actions, [.warning(percentage: 90)])
    }

    func testEvaluateDoesNotFireWhenAlreadyAtThresholdWithoutCrossing() {
        // previous 已经 >= 阈值，说明这不是一次"穿越"，只是同一水平的重复读数
        let (actions, _) = evaluate(current: 91, previous: 90)
        XCTAssertTrue(actions.isEmpty)
    }

    func testEvaluateDoesNotFireBelowThresholdWithoutPreviousData() {
        let (actions, _) = evaluate(current: 50, previous: nil)
        XCTAssertTrue(actions.isEmpty)
    }

    func testEvaluateCatchesUpWithoutPreviousDataWhenAboveThreshold() {
        // previous == nil（刚启动或刚切换账号）按 0 处理：应用未运行期间越过的阈值要补发
        let (actions, _) = evaluate(current: 93, previous: nil)
        XCTAssertEqual(actions, [.warning(percentage: 93)])
    }

    // MARK: - evaluate: 两档阈值

    func testEvaluateFiresOnlyLowerThresholdWhenCrossingIt() {
        let (actions, warnings) = evaluate(current: 78, previous: 60, thresholds: [75, 90])
        XCTAssertEqual(actions, [.warning(percentage: 78)])
        XCTAssertNotNil(warnings[key(75)])
        XCTAssertNil(warnings[key(90)])
    }

    func testEvaluateSendsSingleWarningWhenJumpingPastBothThresholds() {
        // 一次刷新跨过两档只发一条，两档都记为已提醒，之后不会再补发低档
        let (actions, warnings) = evaluate(current: 95, previous: 10, thresholds: [75, 90])
        XCTAssertEqual(actions, [.warning(percentage: 95)])
        XCTAssertNotNil(warnings[key(75)])
        XCTAssertNotNil(warnings[key(90)])
    }

    func testEvaluateTreatsDuplicateThresholdsAsOne() {
        let (actions, warnings) = evaluate(current: 92, previous: 80, thresholds: [90, 90])
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings.count, 1)
    }

    // MARK: - evaluate: 重置检测

    func testEvaluateFiresResetAndClearsAllThresholdsOfLimit() {
        let otherLimitKey = "claude:acc:seven_day:90"
        let (actions, warnings) = evaluate(
            current: 5, previous: 95, thresholds: [75, 90],
            warnings: [key(75): 100, key(90): 100, otherLimitKey: 1]
        )
        XCTAssertEqual(actions, [.reset])
        XCTAssertNil(warnings[key(75)])
        XCTAssertNil(warnings[key(90)])
        XCTAssertEqual(warnings[otherLimitKey], 1)
    }

    func testEvaluateFiresResetOnResetsAtChange() {
        // 百分比骤降之外的第二条重置触发路径：resetsAt 变了且百分比下降
        let previous = Date()
        let current = previous.addingTimeInterval(3600)
        let (actions, warnings) = evaluate(
            current: 5, previous: 50,
            currentResetsAt: current, previousResetsAt: previous,
            thresholds: [75, 90],
            warnings: [key(75): 100, key(90): 100]
        )
        XCTAssertEqual(actions, [.reset])
        XCTAssertTrue(warnings.isEmpty)
    }

    func testEvaluateDoesNotFireResetWhenNoPreviousData() {
        let (actions, _) = evaluate(current: 5, previous: nil)
        XCTAssertTrue(actions.isEmpty)
    }

    func testLowUserThresholdDoesNotTurnDropIntoReset() {
        // 阈值 50% 已提醒，同一周期内读数从 60 回落到 25：不是重置，不发重置通知，也不清记录
        let cycle = Date(timeIntervalSince1970: 5000)
        let (actions, warnings) = evaluate(
            current: 25, previous: 60,
            currentResetsAt: cycle, previousResetsAt: cycle,
            thresholds: [50],
            warnings: [key(50): cycle.timeIntervalSince1970]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[key(50)], cycle.timeIntervalSince1970)
    }

    // MARK: - evaluate: 陈旧记录清理（应用未运行期间配额已重置）

    func testEvaluateClearsStaleFlagFromPreviousCycleAndRefires() {
        let oldCycle = Date(timeIntervalSince1970: 1000)
        let newCycle = Date(timeIntervalSince1970: 5000)

        // 记录属于 oldCycle，但当前 resetsAt 已经是 newCycle——应用未运行期间发生了重置，
        // isReset 的内存对比捕获不到，需要靠陈旧记录清理来避免漏发
        let (actions, warnings) = evaluate(
            current: 92, previous: 10,
            currentResetsAt: newCycle, previousResetsAt: newCycle,
            warnings: [key(90): oldCycle.timeIntervalSince1970]
        )
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[key(90)], newCycle.timeIntervalSince1970)
    }

    func testEvaluateKeepsFlagWhenCycleUnchanged() {
        let cycle = Date(timeIntervalSince1970: 5000)
        let (actions, warnings) = evaluate(
            current: 95, previous: 80,
            currentResetsAt: cycle, previousResetsAt: cycle,
            warnings: [key(90): cycle.timeIntervalSince1970]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[key(90)], cycle.timeIntervalSince1970)
    }

    func testEvaluateTreatsExactlyOneSecondApartCycleAsUnchanged() {
        // 陈旧判断用 `> 1` 秒，恰好相差 1 秒不应被当作陈旧（边界值）
        let oldCycle = Date(timeIntervalSince1970: 5000)
        let newCycle = Date(timeIntervalSince1970: 5001)
        let (actions, warnings) = evaluate(
            current: 95, previous: 80,
            currentResetsAt: newCycle, previousResetsAt: newCycle,
            warnings: [key(90): oldCycle.timeIntervalSince1970]
        )
        XCTAssertTrue(actions.isEmpty, "1 秒内的抖动不应被当作新周期而重新触发警告")
        XCTAssertEqual(warnings[key(90)], oldCycle.timeIntervalSince1970)
    }

    func testEvaluateMigratesLegacyBoolFlagAsAlwaysStale() {
        // 旧版 [String: Bool] 迁移为 1.0（NotificationManager.init 里做的转换），
        // 与任何真实 resetsAt epoch 都不同，应被当作陈旧记录清理并允许重新通知
        let cycle = Date(timeIntervalSince1970: 999_999)
        let (actions, warnings) = evaluate(
            current: 92, previous: 10,
            currentResetsAt: cycle, previousResetsAt: cycle,
            warnings: [key(90): 1.0]
        )
        XCTAssertEqual(actions, [.warning(percentage: 92)])
        XCTAssertEqual(warnings[key(90)], cycle.timeIntervalSince1970)
    }

    // MARK: - evaluate: 无周期信息的限额（额外用量）

    func testEvaluateKeepsFlagWithoutCycleWhileAboveThreshold() {
        let (actions, warnings) = evaluate(
            current: 95, previous: 80, hasResetTime: false, warnings: [key(90): 12345]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertEqual(warnings[key(90)], 12345)
    }

    func testEvaluateRearmsThresholdWithoutCycleAfterUsageDropsBelowIt() {
        // 额外用量没有 resetsAt：50% 提醒过后月度归零（起点 70 低于骤降检测起点，不会被判为重置），
        // 回落到阈值以下必须清掉记录，否则下个月再也不会提醒
        let afterReset = evaluate(
            current: 0, previous: 70, hasResetTime: false, thresholds: [50], warnings: [key(50): 0]
        )
        XCTAssertTrue(afterReset.actions.isEmpty)
        XCTAssertNil(afterReset.updatedWarnings[key(50)])

        let nextMonth = evaluate(
            current: 55, previous: 0, hasResetTime: false, thresholds: [50], warnings: afterReset.updatedWarnings
        )
        XCTAssertEqual(nextMonth.actions, [.warning(percentage: 55)])
    }

    func testMissingDataPlaceholderDoesNotRearmLimitWithResetTime() {
        // 7 天限额缺数据时占位为 0% + nil：不能当成额外用量那样清记录，否则接口恢复后会重复提醒
        let cycle = Date(timeIntervalSince1970: 5000)
        let flagged = [key(75): cycle.timeIntervalSince1970]

        let placeholder = evaluate(
            current: 0, previous: 80,
            currentResetsAt: nil, previousResetsAt: cycle,
            thresholds: [75, 90], warnings: flagged
        )
        XCTAssertTrue(placeholder.actions.isEmpty)
        XCTAssertEqual(placeholder.updatedWarnings, flagged)

        let recovered = evaluate(
            current: 80, previous: 0,
            currentResetsAt: cycle, previousResetsAt: nil,
            thresholds: [75, 90], warnings: placeholder.updatedWarnings
        )
        XCTAssertTrue(recovered.actions.isEmpty)
    }

    // MARK: - evaluate: 阈值调整

    func testEvaluateRemovesRecordsOfThresholdsNoLongerConfigured() {
        let otherLimitKey = "claude:acc:seven_day:90"
        let (actions, warnings) = evaluate(
            current: 92, previous: 92, thresholds: [95],
            warnings: [key(90): 0, otherLimitKey: 0]
        )
        XCTAssertTrue(actions.isEmpty)
        XCTAssertNil(warnings[key(90)])
        XCTAssertEqual(warnings[otherLimitKey], 0)
    }

    func testRaisedThresholdFiresWhenReached() {
        // 用量 92% 时把阈值从 90 调到 95：90 的记录不能挡住 95 的提醒
        let (actions, _) = evaluate(current: 95, previous: 92, thresholds: [95], warnings: [key(90): 0])
        XCTAssertEqual(actions, [.warning(percentage: 95)])
    }

    // MARK: - silenceReached

    func testSilenceMarksOnlyThresholdsAtOrBelowCurrentUsage() {
        let cycle = Date(timeIntervalSince1970: 5000)
        let warnings = NotificationDecisionEngine.silenceReached(
            current: 88, currentResetsAt: cycle,
            limitPrefix: prefix, thresholds: [75, 90], notifiedWarnings: [:]
        )
        XCTAssertEqual(warnings[key(75)], cycle.timeIntervalSince1970)
        XCTAssertNil(warnings[key(90)])
    }

    func testLoweredThresholdIsNotNotifiedAfterRelaunch() {
        // 88% 时把阈值从 90 调到 85：当下不发；重启后 previous 为 nil 的首次判定也不能补发
        let cycle = Date(timeIntervalSince1970: 5000)
        let silenced = NotificationDecisionEngine.silenceReached(
            current: 88, currentResetsAt: cycle,
            limitPrefix: prefix, thresholds: [85], notifiedWarnings: [key(90): 0]
        )
        XCTAssertNil(silenced[key(90)])

        let (actions, _) = evaluate(
            current: 88, previous: nil,
            currentResetsAt: cycle, previousResetsAt: nil,
            thresholds: [85], warnings: silenced
        )
        XCTAssertTrue(actions.isEmpty)
    }

    func testSilenceRefreshesStaleRecordButKeepsCurrentOne() {
        let oldCycle = Date(timeIntervalSince1970: 1000)
        let cycle = Date(timeIntervalSince1970: 5000)
        let warnings = NotificationDecisionEngine.silenceReached(
            current: 95, currentResetsAt: cycle,
            limitPrefix: prefix, thresholds: [75, 90],
            notifiedWarnings: [key(75): oldCycle.timeIntervalSince1970, key(90): 4999.5]
        )
        XCTAssertEqual(warnings[key(75)], cycle.timeIntervalSince1970)
        XCTAssertEqual(warnings[key(90)], 4999.5)
    }

    // MARK: - NotificationThresholdConfig

    func testDefaultConfigThresholds() {
        // 5 小时与周限额沿用改版前的固定阈值；额外用量从单档 90% 变成两档
        let config = NotificationThresholdConfig.default
        XCTAssertEqual(config.thresholds(for: .fiveHour), [90])
        XCTAssertEqual(config.thresholds(for: .weekly), [75, 90])
        XCTAssertEqual(config.thresholds(for: .extraUsage), [75, 90])
    }

    func testPairedThresholdsCollapseWhenEqual() {
        var config = NotificationThresholdConfig.default
        config.weeklyLower = 90
        config.extraUsageUpper = 75
        XCTAssertEqual(config.thresholds(for: .weekly), [90])
        XCTAssertEqual(config.thresholds(for: .extraUsage), [75])
    }

    func testSanitizeSnapsToStepAndClampsToRange() {
        XCTAssertEqual(NotificationThresholdConfig.sanitize(87), 85)
        XCTAssertEqual(NotificationThresholdConfig.sanitize(88), 90)
        XCTAssertEqual(NotificationThresholdConfig.sanitize(20), 50)
        XCTAssertEqual(NotificationThresholdConfig.sanitize(130), 100)
    }

    func testSanitizedOrdersPairedValues() {
        let config = NotificationThresholdConfig(
            fiveHour: 90,
            weeklyLower: 95,
            weeklyUpper: 60,
            extraUsageLower: 100,
            extraUsageUpper: 52
        ).sanitized
        XCTAssertEqual(config.weeklyLower, 60)
        XCTAssertEqual(config.weeklyUpper, 95)
        XCTAssertEqual(config.extraUsageLower, 50)
        XCTAssertEqual(config.extraUsageUpper, 100)
    }

    // MARK: - NotificationKeys

    func testThresholdParsingDoesNotMatchLimitSharingTextPrefix() {
        // "seven_day" 与 "seven_day_opus" 文本上共享开头，前缀带冒号才不会误认
        let sevenDayPrefix = "claude:acc:seven_day:"
        XCTAssertNil(NotificationKeys.threshold(of: "claude:acc:seven_day_opus:90", limitPrefix: sevenDayPrefix))
        XCTAssertEqual(NotificationKeys.threshold(of: "claude:acc:seven_day:75", limitPrefix: sevenDayPrefix), 75)
    }

    func testMigrateLegacyKeys() {
        let migrated = NotificationKeys.migrateLegacy([
            "claude:acc:five_hour": 100,
            "claude:acc:seven_day:75": 200,
            "codex:none:codex_secondary": 300
        ])
        XCTAssertEqual(migrated, [
            "claude:acc:five_hour:90": 100,
            "claude:acc:seven_day:75": 200,
            "codex:none:codex_secondary:90": 300
        ])
        XCTAssertEqual(NotificationKeys.migrateLegacy(migrated), migrated, "迁移必须可以重复执行")
    }

    func testMigrationKeepsExistingNewKeyOverLegacyOne() {
        let migrated = NotificationKeys.migrateLegacy([
            "claude:acc:five_hour": 1,
            "claude:acc:five_hour:90": 2
        ])
        XCTAssertEqual(migrated, ["claude:acc:five_hour:90": 2])
    }
}
