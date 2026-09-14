import XCTest
@testable import Usage4ClaudeCore

/// Tests for the pure half of the logging system: line formatting, the repeat
/// collapser, session-outcome detection, and the disk retention policy.
///
/// Context for why these exist at all. The app previously ran two parallel
/// logging systems: `Logger` (OSLog) with 205 call sites, and a file logger with
/// zero, which is the one the "Open Log Folder" button pointed at — so the
/// folder was empty for every user. Measured against the real system log, only
/// about 22% of those 205 calls produced anything a user could export: 64 were
/// at `.debug`, which never reaches disk, and 122 interpolated a string, which
/// OSLog redacts to `<private>` unless told otherwise.
///
/// Specs the production code intends to honor:
/// - Disk usage has a hard, provable ceiling. The old design wrote one 5 MB file
///   per day and only ever pruned `.old` archives, so the daily files grew
///   without bound.
/// - A repeated message collapses into a count instead of one line per repeat.
/// - A session with no clean-exit marker is reported as an external kill. This
///   is the single bit Issue #79 needs and cannot otherwise obtain: the app
///   leaves no `.ips` because it is not crashing, it is being terminated.
final class LogFormattingTests: XCTestCase {

    // MARK: - Truncation

    func testShortMessagePassesThroughUntouched() {
        XCTAssertEqual(LogFormatting.truncate("short"), "short")
    }

    /// A whole response body must never be able to bloat the log file.
    func testOverlongMessageIsTruncatedAndAnnotated() {
        let message = String(repeating: "x", count: 600)
        let truncated = LogFormatting.truncate(message)

        XCTAssertTrue(truncated.hasPrefix(String(repeating: "x", count: LogFormatting.maxMessageLength)))
        XCTAssertTrue(truncated.contains("+88 chars truncated"), truncated)
    }

    // MARK: - Line format

    func testLineCarriesTimestampLevelCategoryAndMessage() {
        let line = LogFormatting.line(
            timestamp: Date(timeIntervalSince1970: 0),
            level: .error,
            category: .api,
            message: "Usage request failed"
        )

        XCTAssertTrue(line.hasPrefix("1970-01-01T00:00:00.000Z"), line)
        XCTAssertTrue(line.contains("ERROR"))
        XCTAssertTrue(line.contains("API"))
        XCTAssertTrue(line.hasSuffix("Usage request failed"))
    }

    /// Fixed-width level labels keep the file scannable by eye.
    func testAllLevelLabelsShareOneWidth() {
        let widths = Set(LogLevel.allCases.map(\.label.count))
        XCTAssertEqual(widths.count, 1, "Level labels must align: \(LogLevel.allCases.map(\.label))")
    }

    func testTimestampsAreUTCRegardlessOfLocalTimeZone() {
        let formatted = LogFormatting.iso8601(Date(timeIntervalSince1970: 1_756_000_000))
        XCTAssertTrue(formatted.hasSuffix("Z"), formatted)
        XCTAssertEqual(formatted, "2025-08-24T01:46:40.000Z")
    }

    // MARK: - RepeatCollapser

    func testFirstMessageIsAlwaysWritten() {
        var collapser = RepeatCollapser()
        XCTAssertEqual(collapser.admit(key: "a", level: .event), .write(flushedSummary: nil))
    }

    /// Offline for a night means the same error every refresh cycle. Without
    /// collapsing, that is hundreds of identical lines crowding out everything else.
    func testConsecutiveDuplicatesAreSuppressed() {
        var collapser = RepeatCollapser()
        _ = collapser.admit(key: "a", level: .event)

        XCTAssertEqual(collapser.admit(key: "a", level: .event), .suppress)
        XCTAssertEqual(collapser.admit(key: "a", level: .event), .suppress)
        XCTAssertEqual(collapser.admit(key: "a", level: .event), .suppress)
    }

    func testDifferentMessageFlushesTheSuppressedCount() {
        var collapser = RepeatCollapser()
        _ = collapser.admit(key: "a", level: .event)
        _ = collapser.admit(key: "a", level: .event)
        _ = collapser.admit(key: "a", level: .event)

        XCTAssertEqual(collapser.admit(key: "b", level: .event), .write(flushedSummary: .init(count: 2, level: .event)))
    }

    func testAlternatingMessagesAreNeverSuppressed() {
        var collapser = RepeatCollapser()
        XCTAssertEqual(collapser.admit(key: "a", level: .event), .write(flushedSummary: nil))
        XCTAssertEqual(collapser.admit(key: "b", level: .event), .write(flushedSummary: nil))
        XCTAssertEqual(collapser.admit(key: "a", level: .event), .write(flushedSummary: nil))
    }

    func testFlushReturnsPendingCountThenClears() {
        var collapser = RepeatCollapser()
        _ = collapser.admit(key: "a", level: .event)
        _ = collapser.admit(key: "a", level: .event)

        XCTAssertEqual(collapser.flush(), .init(count: 1, level: .event))
        XCTAssertNil(collapser.flush(), "A second flush has nothing left to report")
    }

    /// A collapsed run of errors must summarise as an error, or anyone filtering
    /// the log by level loses the count.
    func testSummaryCarriesTheLevelOfTheCollapsedMessage() {
        var collapser = RepeatCollapser()
        _ = collapser.admit(key: "boom", level: .error)
        _ = collapser.admit(key: "boom", level: .error)

        let flushed = collapser.flush()
        XCTAssertEqual(flushed?.level, .error)
        XCTAssertTrue(
            LogFormatting.repeatSummaryLine(timestamp: Date(), count: 1, level: .error).contains("ERROR")
        )
    }

    func testFlushOnCleanStateReportsNothing() {
        var collapser = RepeatCollapser()
        _ = collapser.admit(key: "a", level: .event)
        XCTAssertNil(collapser.flush())
    }

    // MARK: - Session start line

    /// The OS version must be numeric. `ProcessInfo.operatingSystemVersionString`
    /// is localized, and on a Chinese system it emitted 「版本27.0（版号26A5416b）」
    /// straight into a log that is supposed to be English end to end.
    func testSessionStartLineIsLocaleIndependent() {
        let line = LogFormatting.sessionStartLine(
            timestamp: Date(timeIntervalSince1970: 0),
            appVersion: "3.4.0",
            osVersion: "27.0.0 (26A5416b)",
            arch: "arm64",
            pid: 4242
        )

        XCTAssertTrue(line.contains(LogFormatting.sessionStartMarker))
        XCTAssertTrue(line.contains("app=3.4.0"))
        XCTAssertTrue(line.contains("os=27.0.0 (26A5416b)"))
        XCTAssertTrue(line.contains("pid=4242"))
        XCTAssertFalse(line.contains("build="), "build is bound to the marketing version here; printing both is noise")
    }

    // MARK: - SessionLogScanner (Issue #79)

    private func logText(_ lines: String...) -> String {
        lines.joined(separator: "\n")
    }

    func testSessionEndedCleanlyWhenEndMarkerFollowsStart() {
        let text = logText(
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "2026-09-04T00:00:01.000Z EVENT API          something happened",
            "\(LogFormatting.sessionEndMarker) reason=clean uptime=42s"
        )
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: text), .clean)
    }

    /// The Issue #79 shape: the app is killed, so the end marker never lands.
    func testMissingEndMarkerMeansExternalTermination() {
        let text = logText(
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "2026-09-04T00:00:01.000Z EVENT Refresh      refreshing usage"
        )
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: text), .terminatedUnexpectedly)
    }

    /// Only the most recent session counts: an earlier clean exit must not mask
    /// a later kill.
    func testEarlierCleanSessionDoesNotMaskALaterKill() {
        let text = logText(
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "\(LogFormatting.sessionEndMarker) reason=clean uptime=10s",
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "2026-09-04T00:00:01.000Z EVENT Refresh      refreshing usage"
        )
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: text), .terminatedUnexpectedly)
    }

    func testEarlierKillDoesNotMaskALaterCleanExit() {
        let text = logText(
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "\(LogFormatting.sessionStartMarker) app=3.4.0",
            "\(LogFormatting.sessionEndMarker) reason=clean uptime=10s"
        )
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: text), .clean)
    }

    func testEmptyLogHasNoSessionOnRecord() {
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: ""), .unknown)
    }

    /// A log that rotated away its session markers must report `.unknown`, never
    /// a false "terminated" that would send a maintainer chasing a phantom crash.
    func testLogWithoutAnyMarkerIsUnknownNotTerminated() {
        let text = "2026-09-04T00:00:01.000Z EVENT API          just a line"
        XCTAssertEqual(SessionLogScanner.previousSessionOutcome(in: text), .unknown)
    }

    // MARK: - LogRetentionPolicy

    /// The whole point of the redesign: a provable ceiling on the user's disk.
    func testTotalDiskCeilingIsBounded() {
        XCTAssertEqual(LogRetentionPolicy.maxTotalBytes, 512 * 1024)
    }

    func testRotationTriggersOnlyWhenTheWriteWouldExceedTheCap() {
        let cap = LogRetentionPolicy.maxFileBytes
        XCTAssertFalse(LogRetentionPolicy.shouldRotate(currentSize: cap - 100, pendingBytes: 99))
        XCTAssertTrue(LogRetentionPolicy.shouldRotate(currentSize: cap - 100, pendingBytes: 101))
    }

    func testFreshArchiveIsKeptAndStaleArchiveIsExpired() {
        let now = Date()
        let fresh = now.addingTimeInterval(-3 * 24 * 3600)
        let stale = now.addingTimeInterval(-30 * 24 * 3600)

        XCTAssertFalse(LogRetentionPolicy.isArchiveExpired(modifiedAt: fresh, now: now))
        XCTAssertTrue(LogRetentionPolicy.isArchiveExpired(modifiedAt: stale, now: now))
    }

    /// trace exists for development. Shipping it to disk would spend the user's
    /// space on lines nobody reads.
    func testTraceNeverReachesDiskInReleaseButEverythingElseDoes() {
        XCTAssertFalse(LogRetentionPolicy.shouldWriteToFile(.trace, isDebugBuild: false))
        XCTAssertTrue(LogRetentionPolicy.shouldWriteToFile(.event, isDebugBuild: false))
        XCTAssertTrue(LogRetentionPolicy.shouldWriteToFile(.warning, isDebugBuild: false))
        XCTAssertTrue(LogRetentionPolicy.shouldWriteToFile(.error, isDebugBuild: false))
    }

    func testDebugBuildsWriteEveryLevelIncludingTrace() {
        for level in LogLevel.allCases {
            XCTAssertTrue(LogRetentionPolicy.shouldWriteToFile(level, isDebugBuild: true))
        }
    }
}
