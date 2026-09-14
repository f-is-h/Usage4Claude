import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CodexAnnouncementFetchPolicy` — the pure cadence/backoff decision behind
/// `CodexResetAnnouncementService`. Covers each of the 5 decision levels' boundaries and
/// the backoff ladder.
final class CodexAnnouncementFetchPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(
        lastAttemptAt: Date? = nil,
        cachedAt: Date? = nil,
        hasActiveAnnouncement: Bool = false,
        consecutiveFailures: Int = 0
    ) -> CodexAnnouncementFetchPolicy.State {
        .init(
            lastAttemptAt: lastAttemptAt,
            cachedAt: cachedAt,
            hasActiveAnnouncement: hasActiveAnnouncement,
            consecutiveFailures: consecutiveFailures
        )
    }

    // MARK: - Never attempted before

    func testNeverAttemptedAlwaysFetches() {
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: state(), now: now))
    }

    // MARK: - Level 1: hard minimum interval (60s)

    func testBlocksWithinMinIntervalOf60Seconds() {
        let s = state(lastAttemptAt: now.addingTimeInterval(-59), cachedAt: now.addingTimeInterval(-3600))
        XCTAssertFalse(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    func testAllowsExactlyAtMinIntervalBoundary() {
        let s = state(lastAttemptAt: now.addingTimeInterval(-60), cachedAt: now.addingTimeInterval(-3600))
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    // MARK: - Level 2: backoff after failures

    func testBlocksDuringBackoffAfterOneFailure() {
        // 1 次失败 → 退避 5 分钟
        let s = state(lastAttemptAt: now.addingTimeInterval(-299), consecutiveFailures: 1)
        XCTAssertFalse(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    func testAllowsExactlyAtBackoffBoundaryAfterOneFailure() {
        let s = state(lastAttemptAt: now.addingTimeInterval(-300), consecutiveFailures: 1)
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    func testBackoffLadderEscalates() {
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 1), 5 * 60)
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 2), 15 * 60)
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 3), 30 * 60)
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 4), 60 * 60)
    }

    func testBackoffCapsAtLastRungBeyondLadderLength() {
        // 超过阶梯长度后应封顶在最后一档，而不是崩溃或继续增长
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 5), 60 * 60)
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 100), 60 * 60)
    }

    func testZeroFailuresHasNoBackoff() {
        XCTAssertEqual(CodexAnnouncementFetchPolicy.backoffInterval(consecutiveFailures: 0), 0)
    }

    func testSuccessResetsBackoffImmediately() {
        // consecutiveFailures == 0 之后即使刚刚才尝试过（但超过 minInterval），不应再被退避拦下
        let s = state(lastAttemptAt: now.addingTimeInterval(-60), consecutiveFailures: 0)
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    // MARK: - Level 3: active-announcement TTL (10min)

    func testBlocksWithinActiveTTLOf10Minutes() {
        let s = state(
            lastAttemptAt: now.addingTimeInterval(-120),
            cachedAt: now.addingTimeInterval(-599),
            hasActiveAnnouncement: true
        )
        XCTAssertFalse(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    func testAllowsExactlyAtActiveTTLBoundary() {
        let s = state(
            lastAttemptAt: now.addingTimeInterval(-120),
            cachedAt: now.addingTimeInterval(-600),
            hasActiveAnnouncement: true
        )
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    // MARK: - Level 4: quiet TTL (30min)

    func testBlocksWithinQuietTTLOf30Minutes() {
        let s = state(
            lastAttemptAt: now.addingTimeInterval(-120),
            cachedAt: now.addingTimeInterval(-1799),
            hasActiveAnnouncement: false
        )
        XCTAssertFalse(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    func testAllowsExactlyAtQuietTTLBoundary() {
        let s = state(
            lastAttemptAt: now.addingTimeInterval(-120),
            cachedAt: now.addingTimeInterval(-1800),
            hasActiveAnnouncement: false
        )
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }

    // MARK: - Active announcements use the shorter TTL, not the quiet one

    func testActiveAnnouncementUsesShorterTTLThanQuiet() {
        // 15 分钟前缓存：超过 activeTTL(10min) 应允许，但仍在 quietTTL(30min) 内——
        // 验证 hasActiveAnnouncement 确实切换到了更短的 TTL，而不是误用 quietTTL
        let s = state(
            lastAttemptAt: now.addingTimeInterval(-120),
            cachedAt: now.addingTimeInterval(-15 * 60),
            hasActiveAnnouncement: true
        )
        XCTAssertTrue(CodexAnnouncementFetchPolicy.shouldFetch(state: s, now: now))
    }
}
