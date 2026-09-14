import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CodexTimelineResponse.activeAnnouncement(now:)` — the two-stage-probe
/// consumer's decoding + selection logic — and `CodexForecastQuietState.isQuiet(jsonData:)`,
/// the stage-1 sniff that decides whether the (larger) `/api/timeline` request is needed
/// at all.
///
/// Fixtures below are shaped from real `codex-reset.com` `/api/timeline` responses
/// captured during development (2026-08-29). `now` is always passed explicitly rather
/// than relying on the wall clock, so historical fixture dates stay meaningful.
final class CodexTimelineResponseTests: XCTestCase {

    private func decode(_ json: String) throws -> CodexTimelineResponse {
        try JSONDecoder().decode(CodexTimelineResponse.self, from: Data(json.utf8))
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

    // MARK: - target_kind: "center"

    func testCenterKindUsesTargetAtAsTarget() throws {
        let json = """
        {
          "events": [{
            "summary": "Reset will land around 14pm PST tomorrow.",
            "url": "https://x.com/thsottiaux/status/2091412393368945027",
            "preview": true,
            "scope": "global",
            "official_window": {
              "label": "around 2 PM PT on Aug 23",
              "start_at": "2026-08-23T20:00:00.000Z",
              "end_at": "2026-08-23T22:00:00.000Z",
              "target_at": "2026-08-23T21:00:00.000Z",
              "target_kind": "center"
            }
          }]
        }
        """
        let announcement = try decode(json).activeAnnouncement(now: date("2026-08-23T18:00:00Z"))

        XCTAssertEqual(announcement?.kind, .center)
        XCTAssertEqual(announcement?.target, date("2026-08-23T21:00:00Z"))
        XCTAssertEqual(announcement?.windowEnd, date("2026-08-23T22:00:00Z"))
        XCTAssertEqual(announcement?.label, "around 2 PM PT on Aug 23")
        XCTAssertEqual(announcement?.summary, "Reset will land around 14pm PST tomorrow.")
    }

    // MARK: - target_kind: "deadline"

    func testDeadlineKindUsesTargetAtAsTarget() throws {
        let json = """
        {
          "events": [{
            "summary": "Full reset within the hour.",
            "url": "https://x.com/thsottiaux/status/2071740419030053227",
            "preview": true,
            "scope": "global",
            "official_window": {
              "label": "within an hour",
              "start_at": "2026-06-29T23:39:41.000Z",
              "end_at": "2026-06-30T00:39:41.000Z",
              "target_at": "2026-06-30T00:39:41.000Z",
              "target_kind": "deadline"
            }
          }]
        }
        """
        let announcement = try decode(json).activeAnnouncement(now: date("2026-06-29T23:50:00Z"))

        XCTAssertEqual(announcement?.kind, .deadline)
        XCTAssertEqual(announcement?.target, date("2026-06-30T00:39:41Z"))
    }

    // MARK: - target_kind missing entirely → .range, falls back to windowEnd

    func testMissingTargetKindFallsBackToRangeUsingWindowEnd() throws {
        let json = """
        {
          "events": [{
            "summary": "Rejoice. Another reset later today.",
            "url": "https://x.com/thsottiaux/status/2075641131002700120",
            "preview": true,
            "scope": "global",
            "official_window": {
              "label": "later today",
              "start_at": "2026-07-10T17:59:43.000Z",
              "end_at": "2026-07-11T06:59:59.999Z"
            }
          }]
        }
        """
        let announcement = try decode(json).activeAnnouncement(now: date("2026-07-10T18:00:00Z"))

        XCTAssertEqual(announcement?.kind, .range)
        XCTAssertEqual(announcement?.target, announcement?.windowEnd)
        // 源数据本身带 .999 毫秒（"2026-07-11T06:59:59.999Z"），须精确到毫秒比对
        XCTAssertEqual(announcement?.windowEnd, dateWithFraction("2026-07-11T06:59:59.999Z"))
    }

    // MARK: - Two ISO8601 formats: with and without fractional seconds

    func testParsesTimestampsWithAndWithoutFractionalSeconds() throws {
        let json = """
        {
          "events": [
            {
              "summary": "A",
              "preview": true,
              "scope": "global",
              "official_window": {"end_at": "2026-08-23T22:00:00.000Z", "target_kind": "deadline"}
            },
            {
              "summary": "B",
              "preview": true,
              "scope": "global",
              "official_window": {"end_at": "2026-08-24T22:00:00Z", "target_kind": "deadline"}
            }
          ]
        }
        """
        let response = try decode(json)

        // 都应能成功解析——用早于两者的 now，两条都命中，取更早到期的 A
        let announcement = response.activeAnnouncement(now: date("2026-08-23T00:00:00Z"))
        XCTAssertEqual(announcement?.summary, "A")
    }

    // MARK: - kind 决定 tooltip 用「预计」还是「最迟」措辞，三种取值必须能区分开

    func testKindIsDistinguishableForTooltipWording() throws {
        func kind(forTargetKind raw: String?) throws -> CodexResetAnnouncement.Kind? {
            let field = raw.map { "\"target_kind\": \"\($0)\"," } ?? ""
            let json = """
            {
              "events": [{
                "summary": "x",
                "preview": true,
                "scope": "global",
                "official_window": {\(field) "end_at": "2026-08-23T22:00:00.000Z"}
              }]
            }
            """
            return try decode(json).activeAnnouncement(now: date("2026-08-23T00:00:00Z"))?.kind
        }

        // deadline 型（"within an hour"）语义是"不晚于"，确定性高于其余两种
        XCTAssertEqual(try kind(forTargetKind: "deadline"), .deadline)
        XCTAssertEqual(try kind(forTargetKind: "center"), .center)
        XCTAssertEqual(try kind(forTargetKind: nil), .range)
        // 未来若源站新增未知取值，应保守归入 range 而非崩溃或误判为 deadline
        XCTAssertEqual(try kind(forTargetKind: "something_new"), .range)
    }

    // MARK: - Expiry

    func testExpiredWindowIsExcluded() throws {
        let json = """
        {
          "events": [{
            "summary": "Old reset",
            "preview": true,
            "scope": "global",
            "official_window": {"end_at": "2026-08-23T22:00:00.000Z", "target_kind": "deadline"}
          }]
        }
        """
        // now 晚于 end_at
        let announcement = try decode(json).activeAnnouncement(now: date("2026-08-23T23:00:00Z"))
        XCTAssertNil(announcement)
    }

    // MARK: - Multiple active candidates → earliest windowEnd wins

    func testMultipleActiveCandidatesPicksEarliestWindowEnd() throws {
        let json = """
        {
          "events": [
            {
              "summary": "Later one",
              "preview": true,
              "scope": "global",
              "official_window": {"end_at": "2026-08-24T22:00:00.000Z", "target_kind": "deadline"}
            },
            {
              "summary": "Sooner one",
              "preview": true,
              "scope": "global",
              "official_window": {"end_at": "2026-08-23T22:00:00.000Z", "target_kind": "deadline"}
            }
          ]
        }
        """
        let announcement = try decode(json).activeAnnouncement(now: date("2026-08-23T00:00:00Z"))
        XCTAssertEqual(announcement?.summary, "Sooner one")
    }

    // MARK: - Exclusion filters

    func testNonPreviewEventIsExcluded() throws {
        let json = """
        {
          "events": [{
            "summary": "Historical confirmation, not a forward-looking preview",
            "preview": false,
            "scope": "global",
            "official_window": {"end_at": "2099-01-01T00:00:00.000Z", "target_kind": "deadline"}
          }]
        }
        """
        XCTAssertNil(try decode(json).activeAnnouncement(now: date("2026-01-01T00:00:00Z")))
    }

    func testMissingOfficialWindowIsExcluded() throws {
        let json = """
        {
          "events": [{
            "summary": "Just a tease, no committed window",
            "preview": true,
            "scope": "global"
          }]
        }
        """
        XCTAssertNil(try decode(json).activeAnnouncement(now: date("2026-01-01T00:00:00Z")))
    }

    func testNonGlobalScopeIsExcluded() throws {
        let json = """
        {
          "events": [{
            "summary": "Plan-specific, not a broad reset",
            "preview": true,
            "scope": "plus_only",
            "official_window": {"end_at": "2099-01-01T00:00:00.000Z", "target_kind": "deadline"}
          }]
        }
        """
        XCTAssertNil(try decode(json).activeAnnouncement(now: date("2026-01-01T00:00:00Z")))
    }

    // MARK: - Tolerant of malformed / missing data

    func testEmptyEventsArrayReturnsNil() throws {
        XCTAssertNil(try decode(#"{"events": []}"#).activeAnnouncement(now: Date()))
    }

    func testMissingEventsKeyReturnsNil() throws {
        XCTAssertNil(try decode("{}").activeAnnouncement(now: Date()))
    }

    func testUnparsableEndAtIsExcludedRatherThanCrashing() throws {
        let json = """
        {
          "events": [{
            "summary": "Malformed timestamp",
            "preview": true,
            "scope": "global",
            "official_window": {"end_at": "not-a-date", "target_kind": "deadline"}
          }]
        }
        """
        XCTAssertNil(try decode(json).activeAnnouncement(now: date("2026-01-01T00:00:00Z")))
    }

    func testUnknownExtraFieldsDoNotBreakDecoding() throws {
        // 第三方 API 随时可能新增字段——Codable 应容忍未声明的 key，而不是解码失败
        let json = """
        {
          "unexpected_top_level_field": 123,
          "events": [{
            "summary": "A",
            "preview": true,
            "scope": "global",
            "official_window": {
              "end_at": "2026-08-23T22:00:00.000Z",
              "target_kind": "deadline",
              "unexpected_nested_field": {"nested": true}
            },
            "unexpected_event_field": ["x", "y"]
          }]
        }
        """
        let announcement = try decode(json).activeAnnouncement(now: date("2026-08-23T00:00:00Z"))
        XCTAssertEqual(announcement?.summary, "A")
    }
}

/// Tests for `CodexForecastQuietState.isQuiet(jsonData:)` — the stage-1 sniff on
/// `/api/forecast` that decides whether to fetch the larger `/api/timeline` at all.
final class CodexForecastQuietStateTests: XCTestCase {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testAllWatchedKeysMissingIsQuiet() {
        XCTAssertTrue(CodexForecastQuietState.isQuiet(jsonData: data("{}")))
    }

    func testAllWatchedKeysExplicitNullIsQuiet() {
        let json = """
        {"mode":"model","official_signal":null,"teased_window":null,"signal_percent":null,"commitment":null}
        """
        XCTAssertTrue(CodexForecastQuietState.isQuiet(jsonData: data(json)))
    }

    func testMixOfMissingAndNullIsStillQuiet() {
        // official_signal 缺失、其余显式 null——两种「空」的写法都应视为安静
        let json = """
        {"mode":"model","teased_window":null,"signal_percent":null,"commitment":null}
        """
        XCTAssertTrue(CodexForecastQuietState.isQuiet(jsonData: data(json)))
    }

    func testAnyNonNullWatchedKeyIsNotQuiet() {
        // 未观测到信号期真实取值——只要不是 null/缺失，无论什么类型都应判定为「非安静」
        let json = """
        {"official_signal":{"kind":"dated_commitment"},"teased_window":null,"signal_percent":null,"commitment":null}
        """
        XCTAssertFalse(CodexForecastQuietState.isQuiet(jsonData: data(json)))
    }

    func testNonNullNumericSignalPercentIsNotQuiet() {
        let json = """
        {"official_signal":null,"teased_window":null,"signal_percent":93,"commitment":null}
        """
        XCTAssertFalse(CodexForecastQuietState.isQuiet(jsonData: data(json)))
    }

    func testMalformedJSONIsConservativelyNotQuiet() {
        // 解析失败时保守判定为「非安静」，触发 timeline 请求核实，而不是静默吞掉一次真实预告
        XCTAssertFalse(CodexForecastQuietState.isQuiet(jsonData: data("not json at all")))
    }
}
