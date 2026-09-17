import XCTest
@testable import Usage4ClaudeCore

/// Tests for `UsageFetchBackoffPolicy` — the pure failure-backoff decision that gates
/// automatic usage fetches after 429/5xx/network failures.
final class UsageFetchBackoffPolicyTests: XCTestCase {

    private typealias Policy = UsageFetchBackoffPolicy

    private let now = Date(timeIntervalSince1970: 1_800_000_000)  // Fri, 15 Jan 2027 08:00:00 GMT

    private func delay(
        _ failures: Int,
        _ failure: Policy.Failure = .serverError,
        jitter: Double = 0
    ) -> TimeInterval {
        Policy.backoffDelay(consecutiveFailures: failures, failure: failure, jitterFraction: jitter)
    }

    // MARK: - shouldFetch

    func testInitialStateAlwaysFetches() {
        XCTAssertTrue(Policy.shouldFetch(state: .initial, now: now))
    }

    func testBlocksBeforeRetryNotBefore() {
        let s = Policy.State(consecutiveFailures: 1, retryNotBefore: now.addingTimeInterval(1))
        XCTAssertFalse(Policy.shouldFetch(state: s, now: now))
    }

    func testAllowsExactlyAtRetryNotBefore() {
        let s = Policy.State(consecutiveFailures: 1, retryNotBefore: now)
        XCTAssertTrue(Policy.shouldFetch(state: s, now: now))
    }

    // MARK: - Exponential ladder

    func testDelayDoublesFromOneMinuteAndCapsAtThirtyMinutes() {
        XCTAssertEqual(delay(1), 60)
        XCTAssertEqual(delay(2), 120)
        XCTAssertEqual(delay(3), 240)
        XCTAssertEqual(delay(4), 480)
        XCTAssertEqual(delay(5), 960)
        XCTAssertEqual(delay(6), 30 * 60)
        XCTAssertEqual(delay(7), 30 * 60)
    }

    func testRateLimitedWithoutRetryAfterUsesTheSameLadder() {
        XCTAssertEqual(delay(3, .rateLimited(retryAfter: nil)), 240)
        XCTAssertEqual(delay(6, .rateLimited(retryAfter: nil)), 30 * 60)
    }

    func testNetworkFailuresCapAtFiveMinutes() {
        // 恢复联网时没有事件清除退避，封顶必须低
        XCTAssertEqual(delay(3, .network), 240)
        XCTAssertEqual(delay(4, .network), 5 * 60)
        XCTAssertEqual(delay(10_000, .network), 5 * 60)
    }

    func testHugeFailureCountStaysCappedAndFinite() {
        XCTAssertEqual(delay(10_000), 30 * 60)
    }

    func testZeroFailuresHasNoDelay() {
        XCTAssertEqual(delay(0), 0)
    }

    // MARK: - Jitter

    func testJitterExtendsDelayProportionally() {
        XCTAssertEqual(delay(2, jitter: 0.1), 132, accuracy: 0.0001)
    }

    func testJitterIsClampedToMaxFraction() {
        XCTAssertEqual(delay(1, jitter: 5), 72, accuracy: 0.0001)
        XCTAssertEqual(delay(1, jitter: -1), 60)
    }

    func testJitterAppliesOnTopOfTheCap() {
        // 抖动只推迟不提前：封顶 30 分钟时最多延到 36 分钟
        XCTAssertEqual(delay(10, jitter: 0.2), 36 * 60, accuracy: 0.0001)
    }

    // MARK: - Retry-After

    func testLargerRetryAfterWins() {
        XCTAssertEqual(delay(1, .rateLimited(retryAfter: 600)), 600)
    }

    func testSmallerRetryAfterDoesNotShortenBackoff() {
        XCTAssertEqual(delay(3, .rateLimited(retryAfter: 30)), 240)
    }

    func testZeroRetryAfterFallsBackToExponential() {
        // Anthropic 的用量接口在持续限流时会返回 retry-after: 0，不能据此立即重试
        XCTAssertEqual(delay(2, .rateLimited(retryAfter: 0)), 120)
    }

    func testRetryAfterIsCappedAtOneHour() {
        XCTAssertEqual(delay(1, .rateLimited(retryAfter: 86_400)), 60 * 60)
    }

    // MARK: - recordFailure

    func testRecordFailureIncrementsAndSchedulesNextAttempt() {
        let first = Policy.recordFailure(state: .initial, failure: .serverError, now: now, jitterFraction: 0)
        XCTAssertEqual(first, .init(consecutiveFailures: 1, retryNotBefore: now.addingTimeInterval(60)))

        let second = Policy.recordFailure(state: first, failure: .serverError, now: now, jitterFraction: 0)
        XCTAssertEqual(second, .init(consecutiveFailures: 2, retryNotBefore: now.addingTimeInterval(120)))
        XCTAssertFalse(Policy.shouldFetch(state: second, now: now.addingTimeInterval(119)))
        XCTAssertTrue(Policy.shouldFetch(state: second, now: now.addingTimeInterval(120)))
    }

    func testNetworkFailureAfterRateLimitsUsesTheNetworkCap() {
        var state = Policy.State.initial
        for _ in 0..<6 {
            state = Policy.recordFailure(state: state, failure: .rateLimited(retryAfter: nil), now: now, jitterFraction: 0)
        }
        state = Policy.recordFailure(state: state, failure: .network, now: now, jitterFraction: 0)
        XCTAssertEqual(state.consecutiveFailures, 7)
        XCTAssertEqual(state.retryNotBefore, now.addingTimeInterval(5 * 60))
    }

    // MARK: - Retry-After parsing

    func testParsesDeltaSeconds() {
        XCTAssertEqual(Policy.retryAfterInterval(from: "120", now: now), 120)
        XCTAssertEqual(Policy.retryAfterInterval(from: " 30 ", now: now), 30)
    }

    func testZeroSecondsIsTreatedAsAbsent() {
        XCTAssertNil(Policy.retryAfterInterval(from: "0", now: now))
    }

    func testNonDigitNumericFormsAreRejected() {
        for raw in ["-5", "+5", "1e3", "1.5", "inf", "nan", "0x10"] {
            XCTAssertNil(Policy.retryAfterInterval(from: raw, now: now), raw)
        }
    }

    func testMissingOrGarbageIsNil() {
        XCTAssertNil(Policy.retryAfterInterval(from: nil, now: now))
        XCTAssertNil(Policy.retryAfterInterval(from: "", now: now))
        XCTAssertNil(Policy.retryAfterInterval(from: "soon", now: now))
        XCTAssertNil(Policy.retryAfterInterval(from: "120, 120", now: now))
    }

    func testParsesFutureHTTPDate() {
        XCTAssertEqual(Policy.retryAfterInterval(from: "Fri, 15 Jan 2027 08:02:00 GMT", now: now), 120)
    }

    func testPastHTTPDateIsNil() {
        XCTAssertNil(Policy.retryAfterInterval(from: "Fri, 15 Jan 2027 07:59:00 GMT", now: now))
    }
}
