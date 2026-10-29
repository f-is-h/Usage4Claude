import XCTest
@testable import Usage4ClaudeCore

/// `agy -p /usage --output-format json` 输出解析
final class AntigravityUsageParserTests: XCTestCase {

    /// agy 1.4.9 的真实输出（免费档：只有每周窗口）
    private let freeTierOutput = """
    {"conversation_id":"","status":"SUCCESS","response":"Gemini Models\\tWeekly Limit Remaining\\t100%\\n","duration_seconds":0,"num_turns":0,"usage":{"input_tokens":0,"output_tokens":0,"thinking_tokens":0,"cache_read_tokens":0,"total_tokens":0},"command":{"name":"usage","data":{"description":"Within each group, models share a weekly limit.","groups":[{"name":"Gemini Models","description":"Models within this group: Gemini Flash, Gemini Pro","buckets":[{"id":"gemini-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":0.9975000023841858,"reset_time":"2026-11-04T18:31:45Z"}]},{"name":"Claude and GPT models","description":"Models within this group: Claude Opus, Claude Sonnet, GPT-OSS","buckets":[{"id":"3p-weekly","name":"Weekly Limit Remaining","window":"weekly","remaining_fraction":1,"reset_time":"2026-11-04T18:46:29Z"}]}]}}}
    """

    func testParsesFreeTierWeeklyBuckets() throws {
        let data = try AntigravityUsageParser.parse(cliOutput: freeTierOutput)

        XCTAssertNil(data.gemini.fiveHour)
        XCTAssertNil(data.thirdParty.fiveHour)
        let geminiWeekly = try XCTUnwrap(data.gemini.weekly)
        XCTAssertEqual(geminiWeekly.percentage, 0.25, accuracy: 0.001)
        XCTAssertEqual(geminiWeekly.resetsAt, ISO8601DateFormatter().date(from: "2026-11-04T18:31:45Z"))
        XCTAssertTrue(data.hasAnyLimit)
    }

    func testUntouchedWindowHasNoResetTime() throws {
        // 剩余 100% 时 reset_time 只是「现在 + 窗口长度」，不是真实重置时间
        let data = try AntigravityUsageParser.parse(cliOutput: freeTierOutput)
        let thirdPartyWeekly = try XCTUnwrap(data.thirdParty.weekly)
        XCTAssertEqual(thirdPartyWeekly.percentage, 0)
        XCTAssertNil(thirdPartyWeekly.resetsAt)
    }

    func testParsesPaidTierFiveHourBuckets() throws {
        let output = """
        {"status":"SUCCESS","command":{"name":"usage","data":{"groups":[
          {"name":"Gemini Models","buckets":[
            {"id":"gemini-5h","window":"5h","remaining_fraction":0.4,"reset_time":"2026-10-29T03:00:00.123Z"},
            {"id":"gemini-weekly","window":"weekly","remaining_fraction":0.9,"reset_time":"2026-11-04T00:00:00Z"}]},
          {"name":"Claude and GPT models","buckets":[
            {"id":"3p-5h","window":"5h","remaining_fraction":0,"reset_time":"2026-10-29T02:00:00Z"}]}]}}}
        """.replacingOccurrences(of: "\n", with: "")

        let data = try AntigravityUsageParser.parse(cliOutput: output)
        XCTAssertEqual(try XCTUnwrap(data.gemini.fiveHour).percentage, 60, accuracy: 0.001)
        XCTAssertNotNil(data.gemini.fiveHour?.resetsAt, "fractional seconds must parse")
        XCTAssertEqual(try XCTUnwrap(data.gemini.weekly).percentage, 10, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(data.thirdParty.fiveHour).percentage, 100)
        XCTAssertNil(data.thirdParty.weekly)
        XCTAssertEqual(try XCTUnwrap(data.maxPercentage), 100)
    }

    func testFallsBackToGroupNameAndWindowForUnknownIds() throws {
        let output = #"{"status":"SUCCESS","command":{"data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly-v2","window":"weekly","remaining_fraction":0.5,"reset_time":"2026-11-04T00:00:00Z"},{"id":"mystery","window":"daily","remaining_fraction":0.5}]},{"name":"Claude and GPT models","buckets":[{"id":"other-5h","window":"5h","remaining_fraction":0.75,"reset_time":"2026-11-04T00:00:00Z"}]}]}}}"#

        let data = try AntigravityUsageParser.parse(cliOutput: output)
        XCTAssertEqual(try XCTUnwrap(data.gemini.weekly).percentage, 50, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(data.thirdParty.fiveHour).percentage, 25, accuracy: 0.001)
        XCTAssertNil(data.gemini.fiveHour, "unknown windows are ignored")
    }

    func testGroupNameWinsOverUnknownIdForGeminiBuckets() throws {
        let output = #"{"status":"SUCCESS","command":{"data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"flash-weekly","window":"weekly","remaining_fraction":0.4,"reset_time":"2026-11-04T00:00:00Z"}]},{"name":"Claude and GPT models","buckets":[{"id":"3p-weekly","window":"weekly","remaining_fraction":0.9,"reset_time":"2026-11-04T00:00:00Z"}]}]}}}"#

        let data = try AntigravityUsageParser.parse(cliOutput: output)
        XCTAssertEqual(try XCTUnwrap(data.gemini.weekly).percentage, 60, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(data.thirdParty.weekly).percentage, 10, accuracy: 0.001)
    }

    func testSkipsNonJSONLinesBeforeTheResult() throws {
        let output = "A new version of agy is available.\n" + freeTierOutput
        XCTAssertNoThrow(try AntigravityUsageParser.parse(cliOutput: output))
    }

    func testNotLoggedIn() {
        let output = #"{"status":"ERROR","response":"You are not logged into Antigravity."}"#
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: output)) { error in
            XCTAssertEqual(error as? AntigravityParseError, .notLoggedIn)
        }
    }

    func testTransientSignInFailureIsNotTreatedAsLoggedOut() {
        let message = "Failed to sign in to quota service: network unreachable"
        let output = #"{"status":"ERROR","response":"\#(message)"}"#
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: output)) { error in
            XCTAssertEqual(error as? AntigravityParseError, .commandFailed(message))
        }
    }

    func testCommandFailureCarriesMessage() {
        let output = #"{"status":"ERROR","response":"quota service unavailable"}"#
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: output)) { error in
            XCTAssertEqual(error as? AntigravityParseError, .commandFailed("quota service unavailable"))
        }
    }

    func testNoJSONAndMalformedOutput() {
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: "")) { error in
            XCTAssertEqual(error as? AntigravityParseError, .noJSON)
        }
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: "{not json")) { error in
            XCTAssertEqual(error as? AntigravityParseError, .malformed)
        }
        XCTAssertThrowsError(try AntigravityUsageParser.parse(cliOutput: #"{"status":"SUCCESS"}"#)) { error in
            XCTAssertEqual(error as? AntigravityParseError, .malformed)
        }
    }

    func testRemainingFractionIsClamped() throws {
        let output = #"{"status":"SUCCESS","command":{"data":{"groups":[{"name":"Gemini Models","buckets":[{"id":"gemini-weekly","window":"weekly","remaining_fraction":-0.2,"reset_time":"2026-11-04T00:00:00Z"}]}]}}}"#
        let data = try AntigravityUsageParser.parse(cliOutput: output)
        XCTAssertEqual(try XCTUnwrap(data.gemini.weekly).percentage, 100)
    }

    func testTokenExpiryRoundTripsWithFractionalSeconds() throws {
        let nano = try XCTUnwrap(AntigravityUsageParser.parseDate("2026-11-04T12:00:00.123456789+09:00"))
        XCTAssertEqual(nano.timeIntervalSince1970, 1793761200.123, accuracy: 0.001)
        XCTAssertNotNil(AntigravityUsageParser.parseDate("2026-11-04T12:00:00Z"))
        let date = Date(timeIntervalSince1970: 1793761200.5)
        let parsed = try XCTUnwrap(AntigravityUsageParser.parseDate(AntigravityUsageParser.formatDate(date)))
        XCTAssertEqual(parsed.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testAccountEmailIsReadFromCLILog() {
        let log = """
        I1029 14:18:09.326113       1 server_oauth.go:224] applyAuthResult: email=old@example.test, authMethod=consumer, quotaProject=
        I1029 14:18:09.326159       1 server_oauth.go:229] OAuth: authenticated successfully as user@example.test
        I1029 14:18:10.000000       1 server.go:10] done
        """
        XCTAssertEqual(AntigravityUsageParser.accountEmail(fromLog: log), "user@example.test")
        XCTAssertNil(AntigravityUsageParser.accountEmail(fromLog: "OAuth: authenticated successfully as \n"))
        XCTAssertNil(AntigravityUsageParser.accountEmail(fromLog: "no auth line"))
    }
}
