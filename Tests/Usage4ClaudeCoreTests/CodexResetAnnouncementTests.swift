import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CodexForecastResponse` — decoding codex-reset.com's `/api/forecast` and
/// deciding which announcement (if any) to show — plus `CodexResetAnnouncement`'s
/// expiry and overdue rules.
///
/// Fixtures are trimmed from real responses: 2026-09-12 03:43 UTC (a live 83% Watch
/// with no window, during which 3.4.x's timeline parser found nothing), 2026-09-15 (quiet, the last
/// alert already confirmed) and 2026-08-31 (before `latest_alert` existed). `now` is
/// always passed explicitly so historical fixture dates stay meaningful.
final class CodexForecastResponseTests: XCTestCase {

    private func decode(_ json: String) throws -> CodexForecastResponse {
        try JSONDecoder().decode(CodexForecastResponse.self, from: Data(json.utf8))
    }

    private static let iso = ISO8601DateFormatter()
    private func date(_ string: String) -> Date {
        Self.iso.date(from: string)!
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private func dateWithFraction(_ string: String) -> Date {
        Self.isoFractional.date(from: string)!
    }

    /// 只改 latest_alert 的关键字段，其余结构取自 2026-09-12 实测
    private func alertJSON(
        kind: String = "watch",
        state: String = "active",
        sourceAt: String = "2026-09-12T03:20:36.000Z",
        summary: String = "A reset is also landing by midnight today.",
        window: String = "null"
    ) -> String {
        #"""
        {
          "mode": "announced",
          "official_signal": {"tweet_id": "2098612714704891959", "signal_type": "promise", "window": null},
          "latest_alert": {
            "id": "2098612714704891959",
            "kind": "\#(kind)",
            "state": "\#(state)",
            "source_at": "\#(sourceAt)",
            "summary": "\#(summary)",
            "url": "https://x.com/thsottiaux/status/2098612714704891959",
            "score": 83,
            "window": \#(window),
            "corrected": false
          }
        }
        """#
    }

    // MARK: - Real snapshots

    func testLiveWatchWithoutWindowFromSep12Snapshot() throws {
        let json = #"""
        {
          "mode": "announced",
          "probabilities": {"rounded_24h": 50, "rounded_48h": 75, "tease_tier": "T2", "commitment": 0.83, "signal_percent": 83},
          "signal_score": {"band": "promise", "base": 83, "modifiers": [], "value": 83},
          "last_reset_at": "2026-09-08T04:05:53.000Z",
          "official_signal": {
            "tweet_id": "2098612714704891959",
            "at": "2026-09-12T03:20:36.000Z",
            "kind": "signal",
            "signal_type": "promise",
            "signal_tier": "likely",
            "window": null
          },
          "teased_window": null,
          "tease_signal": {"tier": "T2", "floor_24h": 50, "floor_48h": 75, "expires_at": "2026-09-13T06:39:40.000Z"},
          "signal_tier": "likely",
          "alert_event_id": "signal:2098612714704891959:likely",
          "latest_alert": {
            "id": "2098612714704891959",
            "kind": "watch",
            "state": "active",
            "source_at": "2026-09-12T03:20:36.000Z",
            "summary": "Hi Astra users. A reset and a quick update on quality issues that have been posted around.\n\nWorking with some of you, we have found and fixed the following issues:\n- Some skills written for previous m",
            "url": "https://x.com/thsottiaux/status/2098612714704891959",
            "score": 83,
            "window": null,
            "corrected": false
          }
        }
        """#
        let response = try decode(json)
        let announcement = try XCTUnwrap(response.activeAnnouncement(now: date("2026-09-12T03:43:53Z")))

        XCTAssertNil(announcement.window)
        XCTAssertEqual(announcement.expiresAt, date("2026-09-12T03:20:36Z").addingTimeInterval(CodexResetAnnouncement.maxAge))
        // 站点摘要恰好截断在 200 字符：换行折叠成空格，末尾补省略号
        XCTAssertEqual(
            announcement.summary,
            "Hi Astra users. A reset and a quick update on quality issues that have been posted around. Working with some of you, we have found and fixed the following issues: - Some skills written for previous m…"
        )
        XCTAssertFalse(response.hasUnrecognizedSignal)
    }

    func testQuietSnapshotFromSep15ShowsNothing() throws {
        let json = #"""
        {
          "mode": "model",
          "probabilities": {"rounded_24h": 24, "rounded_48h": 42, "signal_percent": null, "commitment": null},
          "signal_score": null,
          "official_signal": null,
          "teased_window": null,
          "tease_signal": null,
          "signal_tier": null,
          "alert_event_id": null,
          "latest_alert": {
            "id": "2098685367058612394",
            "kind": "reset",
            "state": "confirmed",
            "source_at": "2026-09-12T08:09:17.000Z",
            "summary": "Reset all propagated. Sweet dreams. https://t.co/VgKVUixoJG",
            "url": "https://x.com/thsottiaux/status/2098685367058612394",
            "score": null,
            "window": null,
            "corrected": false
          }
        }
        """#
        let response = try decode(json)

        XCTAssertNil(response.activeAnnouncement(now: date("2026-09-15T00:28:48Z")))
        XCTAssertFalse(response.hasUnrecognizedSignal)
    }

    func testSchemaWithoutLatestAlertIsFlaggedButNotShown() throws {
        // 2026-08-31 实测：还没有 latest_alert。official_signal 挂着的是一条「已经重置了」的帖子，
        // 却被标成 93% 并带着「周一结束前」的窗口——回退到它会在重置之后继续显示预告
        let json = #"""
        {
          "mode": "announced",
          "probabilities": {"commitment": 0.93, "commitment_floor_percent": 93, "signal_percent": 93},
          "official_signal": {
            "tweet_id": "2094252447271366730",
            "summary": "What I wanted to say yesterday is that we hit 25M active users and to celebrate we have now reset usage for all paid subscriptions for ChatGPT Work and Codex.",
            "at": "2026-08-31T02:34:27.000Z",
            "signal_type": "dated_commitment",
            "window": {
              "label": "end of Monday",
              "start_at": "2026-08-31T02:34:27.000Z",
              "end_at": "2026-09-01T06:59:59.999Z",
              "time_zone": "America/Los_Angeles",
              "target_kind": "deadline",
              "target_at": "2026-09-01T06:59:59.999Z"
            }
          },
          "teased_window": null,
          "signal_tier": "likely",
          "alert_event_id": "signal:2094252447271366730:likely"
        }
        """#
        let response = try decode(json)

        XCTAssertNil(response.activeAnnouncement(now: date("2026-08-31T02:55:57Z")))
        XCTAssertTrue(response.hasUnrecognizedSignal)
    }

    // MARK: - Window

    func testDeadlineWindowLongerThanMaxAgeLastsUntilWindowEnd() throws {
        let window = #"{"label": "end of Monday", "start_at": "2026-08-31T02:34:27.000Z", "end_at": "2026-09-01T06:59:59.999Z", "time_zone": "America/Los_Angeles", "target_kind": "deadline", "target_at": "2026-09-01T06:59:59.999Z"}"#
        let json = alertJSON(sourceAt: "2026-08-31T02:34:27.000Z", window: window)
        let response = try decode(json)
        let announcement = try XCTUnwrap(response.activeAnnouncement(now: date("2026-08-31T03:00:00Z")))

        let end = dateWithFraction("2026-09-01T06:59:59.999Z")
        XCTAssertEqual(announcement.window?.kind, .deadline)
        XCTAssertEqual(announcement.window?.label, "end of Monday")
        XCTAssertEqual(announcement.window?.target, end)
        // 窗口结束（发帖后约 28.4 小时）晚于 maxAge，以窗口为准
        XCTAssertEqual(announcement.expiresAt, end)
        XCTAssertNotNil(response.activeAnnouncement(now: date("2026-09-01T06:00:00Z")))
        XCTAssertNil(response.activeAnnouncement(now: date("2026-09-01T07:00:00Z")))
    }

    func testCenterWindowUsesTargetAt() throws {
        let window = #"{"label": "around 2 PM PT on Aug 23", "start_at": "2026-08-23T20:00:00.000Z", "end_at": "2026-08-23T22:00:00.000Z", "target_at": "2026-08-23T21:00:00.000Z", "target_kind": "center"}"#
        let json = alertJSON(sourceAt: "2026-08-23T08:25:00.000Z", window: window)
        let announcement = try XCTUnwrap(decode(json).activeAnnouncement(now: date("2026-08-23T18:00:00Z")))

        XCTAssertEqual(announcement.window?.kind, .center)
        XCTAssertEqual(announcement.window?.target, date("2026-08-23T21:00:00Z"))
        XCTAssertEqual(announcement.window?.end, date("2026-08-23T22:00:00Z"))
    }

    func testMissingOrUnknownTargetKindFallsBackToRangeTargetingWindowEnd() throws {
        for field in ["", #""target_kind": "something_new","#] {
            let window = #"{\#(field) "label": "later today", "end_at": "2026-09-12T06:59:59.999Z"}"#
            let announcement = try XCTUnwrap(
                decode(alertJSON(window: window)).activeAnnouncement(now: date("2026-09-12T04:00:00Z"))
            )
            XCTAssertEqual(announcement.window?.kind, .range)
            XCTAssertEqual(announcement.window?.target, announcement.window?.end)
        }
    }

    func testUnparsableWindowEndDegradesToNoTime() throws {
        // 承诺本身仍然成立，只是时间读不出来——照样显示，只是不给倒计时
        let window = #"{"label": "soon", "end_at": "not-a-date", "target_kind": "deadline"}"#
        let announcement = try XCTUnwrap(
            decode(alertJSON(window: window)).activeAnnouncement(now: date("2026-09-12T04:00:00Z"))
        )
        XCTAssertNil(announcement.window)
    }

    func testParsesSourceAtWithoutFractionalSeconds() throws {
        let json = alertJSON(sourceAt: "2026-09-12T03:20:36Z")
        XCTAssertNotNil(try decode(json).activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
    }

    // MARK: - Which alerts count

    func testOnlyActiveWatchIsShown() throws {
        let now = date("2026-09-12T04:00:00Z")
        XCTAssertNotNil(try decode(alertJSON(kind: "watch", state: "active")).activeAnnouncement(now: now))
        XCTAssertNil(try decode(alertJSON(kind: "reset", state: "confirmed")).activeAnnouncement(now: now))
        XCTAssertNil(try decode(alertJSON(kind: "watch", state: "confirmed")).activeAnnouncement(now: now))
        XCTAssertNil(try decode(alertJSON(kind: "reset", state: "active")).activeAnnouncement(now: now))
        XCTAssertNil(try decode(alertJSON(kind: "watch", state: "expired")).activeAnnouncement(now: now))
    }

    func testUnparsableSourceAtShowsNothing() throws {
        XCTAssertNil(try decode(alertJSON(sourceAt: "")).activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
        XCTAssertNil(try decode(alertJSON(sourceAt: "yesterday")).activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
    }

    // MARK: - Expiry and overdue

    func testWatchWithoutWindowExpiresAfterMaxAge() throws {
        let response = try decode(alertJSON(sourceAt: "2026-09-12T03:20:36Z"))
        let posted = date("2026-09-12T03:20:36Z")

        XCTAssertNotNil(response.activeAnnouncement(now: posted.addingTimeInterval(CodexResetAnnouncement.maxAge - 1)))
        XCTAssertNil(response.activeAnnouncement(now: posted.addingTimeInterval(CodexResetAnnouncement.maxAge)))
    }

    func testShortWindowStaysVisibleAndTurnsOverdueWhenResetIsLate() throws {
        // 2026-08-23 那次晚到了近 4 小时：窗口过了，徽章不该消失，但也不该再倒计时
        let window = #"{"label": "within an hour", "end_at": "2026-09-12T04:20:36.000Z", "target_at": "2026-09-12T04:20:36.000Z", "target_kind": "deadline"}"#
        let response = try decode(alertJSON(sourceAt: "2026-09-12T03:20:36.000Z", window: window))

        let beforeTarget = try XCTUnwrap(response.activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
        XCTAssertFalse(beforeTarget.isOverdue(at: date("2026-09-12T04:00:00Z")))

        let late = try XCTUnwrap(response.activeAnnouncement(now: date("2026-09-12T07:30:00Z")))
        XCTAssertTrue(late.isOverdue(at: date("2026-09-12T07:30:00Z")))
    }

    func testAnnouncementWithoutWindowIsNeverOverdue() {
        let posted = date("2026-09-12T03:20:36Z")
        let announcement = CodexResetAnnouncement(summary: "x", window: nil, postedAt: posted)
        XCTAssertFalse(announcement.isOverdue(at: posted.addingTimeInterval(CodexResetAnnouncement.maxAge - 1)))
    }

    // MARK: - Schema drift

    func testUnknownStateWhileSignalIsLiveIsFlagged() throws {
        let response = try decode(alertJSON(kind: "watch", state: "open"))
        XCTAssertNil(response.activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
        XCTAssertTrue(response.hasUnrecognizedSignal)
    }

    func testWrongTypedLatestAlertDoesNotFailDecoding() throws {
        let json = #"{"mode": "announced", "official_signal": {"tweet_id": "1"}, "latest_alert": "watch"}"#
        let response = try decode(json)

        XCTAssertNil(response.latestAlert)
        XCTAssertEqual(response.mode, "announced")
        XCTAssertTrue(response.hasUnrecognizedSignal)
    }

    func testEmptyObjectShowsNothingAndIsNotFlagged() throws {
        let response = try decode("{}")
        XCTAssertNil(response.activeAnnouncement(now: Date()))
        XCTAssertFalse(response.hasUnrecognizedSignal)
    }

    func testUnknownExtraFieldsDoNotBreakDecoding() throws {
        let window = #"{"label": "within an hour", "end_at": "2026-09-12T04:20:36.000Z", "target_kind": "deadline", "unexpected_nested_field": {"nested": true}}"#
        let json = alertJSON(window: window)
            .replacingOccurrences(of: #""mode": "announced","#, with: #""mode": "announced", "unexpected_top_level_field": [1, 2],"#)
        XCTAssertNotNil(try decode(json).activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
    }

    func testShortSummaryIsCollapsedWithoutEllipsis() throws {
        let json = alertJSON(summary: #"Lands around 6pm PST today.\n\nEnjoy."#)
        let announcement = try XCTUnwrap(decode(json).activeAnnouncement(now: date("2026-09-12T04:00:00Z")))
        XCTAssertEqual(announcement.summary, "Lands around 6pm PST today. Enjoy.")
    }
}
