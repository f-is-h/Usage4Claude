import XCTest
@testable import Usage4ClaudeCore

/// Tests for `SmartRefreshPolicy` — the 4-level monitoring mode state machine
/// that drives smart-mode refresh interval selection.
///
/// Specs the production code intends to honor:
/// - Any provider's utilization changing snaps back to `.active` immediately.
/// - Only when ALL providers are unchanged does the unchanged-count accumulate.
/// - Escalation thresholds: active→idleShort at 3 unchanged, idleShort→idleMedium
///   at 6, idleMedium→idleLong at 12. idleLong has no further escalation.
/// - `update` returns whether the mode actually changed this call.
final class SmartRefreshPolicyTests: XCTestCase {

    func testStartsInActiveMode() {
        let policy = SmartRefreshPolicy()
        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertEqual(policy.unchangedCount, 0)
    }

    func testIgnoresEmptyUtilizations() {
        let policy = SmartRefreshPolicy()
        let changed = policy.update(providerUtilizations: [:])
        XCTAssertFalse(changed)
        XCTAssertEqual(policy.currentMode, .active)
    }

    func testFirstReadingCountsAsUnchangedSinceNoBaselineExistsYet() {
        // There's no prior value to compare .claude against, so
        // hasProviderUtilizationChanged() can't detect a "change" — the very
        // first call is therefore treated as an unchanged reading and already
        // increments the counter once. This is the production behavior as
        // written, not something this test suite is trying to change.
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 42.0])
        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertEqual(policy.unchangedCount, 1)
        XCTAssertEqual(policy.lastUtilization, 42.0)
    }

    func testEscalatesToIdleShortAfterThreeUnchangedReadings() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0]) // 1st unchanged reading (no baseline yet) -> count=1

        _ = policy.update(providerUtilizations: [.claude: 10.0]) // count=2
        let changed = policy.update(providerUtilizations: [.claude: 10.0]) // count=3 -> escalate

        XCTAssertEqual(policy.currentMode, .idleShort)
        XCTAssertTrue(changed, "the call that crosses the threshold should report a change")
        XCTAssertEqual(policy.unchangedCount, 0, "counter resets after an escalation")
    }

    func testDoesNotEscalateBeforeThreshold() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0]) // count=1

        let changed = policy.update(providerUtilizations: [.claude: 10.0]) // count=2, still below the 3 threshold

        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertFalse(changed)
    }

    func testEscalatesThroughAllFourLevels() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0])

        // active -> idleShort (3 unchanged)
        for _ in 0..<3 { policy.update(providerUtilizations: [.claude: 10.0]) }
        XCTAssertEqual(policy.currentMode, .idleShort)

        // idleShort -> idleMedium (6 unchanged)
        for _ in 0..<6 { policy.update(providerUtilizations: [.claude: 10.0]) }
        XCTAssertEqual(policy.currentMode, .idleMedium)

        // idleMedium -> idleLong (12 unchanged)
        for _ in 0..<12 { policy.update(providerUtilizations: [.claude: 10.0]) }
        XCTAssertEqual(policy.currentMode, .idleLong)

        // idleLong has no further escalation, even after many more unchanged readings
        for _ in 0..<50 { policy.update(providerUtilizations: [.claude: 10.0]) }
        XCTAssertEqual(policy.currentMode, .idleLong)
    }

    func testAnyProviderChangeSnapsBackToActive() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0, .codex: 20.0])
        for _ in 0..<3 { policy.update(providerUtilizations: [.claude: 10.0, .codex: 20.0]) }
        XCTAssertEqual(policy.currentMode, .idleShort)

        // Only codex changes; claude stays flat. Any change should reset to active.
        let changed = policy.update(providerUtilizations: [.claude: 10.0, .codex: 25.0])

        XCTAssertTrue(changed)
        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertEqual(policy.unchangedCount, 0)
    }

    func testTinyFluctuationBelowEpsilonDoesNotCountAsChange() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0])
        for _ in 0..<3 { policy.update(providerUtilizations: [.claude: 10.005]) }

        // 0.005 delta is within the 0.01 epsilon used by the production comparison
        XCTAssertEqual(policy.currentMode, .idleShort)
    }

    func testAlreadyActiveModeReportsNoChangeOnRealChange() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0])

        // Still in .active; a genuine change keeps it in .active, so there's
        // nothing to "switch" to — update() should report no mode change.
        let changed = policy.update(providerUtilizations: [.claude: 50.0])

        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertFalse(changed)
    }

    func testResetRestoresInitialState() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.claude: 10.0])
        for _ in 0..<3 { policy.update(providerUtilizations: [.claude: 10.0]) }
        XCTAssertEqual(policy.currentMode, .idleShort)

        policy.reset()

        XCTAssertEqual(policy.currentMode, .active)
        XCTAssertEqual(policy.unchangedCount, 0)
        XCTAssertNil(policy.lastUtilization)

        // After reset, escalation starts over from scratch: 2 calls (the
        // post-reset baseline + 1 more) is one short of the 3-reading threshold.
        policy.update(providerUtilizations: [.claude: 10.0]) // count=1
        _ = policy.update(providerUtilizations: [.claude: 10.0]) // count=2
        XCTAssertEqual(policy.currentMode, .active, "only 2 unchanged readings after reset, should not have escalated yet")
    }

    func testLastUtilizationPrefersClaudeWhenBothProvidersPresent() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.codex: 99.0, .claude: 5.0])
        XCTAssertEqual(policy.lastUtilization, 5.0)
    }

    func testLastUtilizationFallsBackToAnyProviderWhenClaudeAbsent() {
        let policy = SmartRefreshPolicy()
        policy.update(providerUtilizations: [.codex: 77.0])
        XCTAssertEqual(policy.lastUtilization, 77.0)
    }
}
