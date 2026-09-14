import XCTest
@testable import Usage4ClaudeCore

/// Integration tests for the real file-writing path in `LogStore` — rotation,
/// the disk ceiling, repeat collapsing, session markers, and redaction at the
/// entry point. These drive the shipping code against a temp directory rather
/// than a parallel reimplementation, because the properties that matter here
/// (does it actually stay under the cap, does the marker actually survive) are
/// exactly the ones a stand-in would not prove.
///
/// Specs the production code intends to honor:
/// - Total disk usage stays under `LogRetentionPolicy.maxTotalBytes`, always.
/// - A message is redacted before it reaches disk, never after.
/// - A session that ends without `endSession()` is detectable on next launch.
final class AppLogStoreTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("applog-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> LogStore { LogStore(directory: directory) }

    /// 日志文件名在 DEBUG 下带前缀，避免与 Release 实例写同一个文件
    private var currentLogName: String {
        #if DEBUG
        return "debug-current.log"
        #else
        return "current.log"
        #endif
    }

    private var archiveLogName: String {
        #if DEBUG
        return "debug-previous.log"
        #else
        return "previous.log"
        #endif
    }

    private func readCurrentLog() -> String {
        let url = directory.appendingPathComponent(currentLogName)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    // MARK: - Writing

    func testEventIsWrittenToDisk() {
        let store = makeStore()
        store.appendToFile(level: .event, category: .api, message: "usage refresh finished")
        store.waitForPendingWrites()

        let log = readCurrentLog()
        XCTAssertTrue(log.contains("usage refresh finished"), log)
        XCTAssertTrue(log.contains("EVENT"))
        XCTAssertTrue(log.contains("API"))
    }

    #if !DEBUG
    /// trace must not spend the user's disk in a shipping build.
    func testTraceIsNotWrittenInReleaseBuilds() {
        let store = makeStore()
        store.appendToFile(level: .trace, category: .api, message: "chatty detail")
        store.waitForPendingWrites()

        XCTAssertFalse(readCurrentLog().contains("chatty detail"))
    }
    #endif

    // MARK: - Repeat collapsing

    func testRepeatedMessageCollapsesInsteadOfRepeating() {
        let store = makeStore()
        for _ in 0..<50 {
            store.appendToFile(level: .error, category: .api, message: "network unreachable")
        }
        store.appendToFile(level: .event, category: .api, message: "back online")
        store.waitForPendingWrites()

        let log = readCurrentLog()
        let occurrences = log.components(separatedBy: "network unreachable").count - 1
        XCTAssertEqual(occurrences, 1, "50 identical errors must collapse to one line:\n\(log)")
        XCTAssertTrue(log.contains("repeated 49 more times"), log)
    }

    // MARK: - Disk ceiling

    /// The headline guarantee of the redesign. The previous design wrote a 5 MB
    /// file per day and pruned only `.old` archives, so daily files grew forever.
    func testDiskUsageStaysUnderTheCapUnderSustainedWriting() {
        let store = makeStore()
        // Distinct messages so the collapser cannot mask the growth
        for index in 0..<8000 {
            store.appendToFile(level: .event, category: .api, message: "sustained write number \(index)")
        }
        store.waitForPendingWrites()

        let usage = store.diskUsageBytes()
        XCTAssertGreaterThan(usage, 0, "The test must actually have written something")
        XCTAssertLessThanOrEqual(
            usage, LogRetentionPolicy.maxTotalBytes,
            "Log usage \(usage) exceeded the \(LogRetentionPolicy.maxTotalBytes) byte ceiling"
        )
    }

    func testRotationPreservesRecentHistoryInTheArchive() {
        let store = makeStore()
        for index in 0..<8000 {
            store.appendToFile(level: .event, category: .api, message: "sustained write number \(index)")
        }
        store.waitForPendingWrites()

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent(archiveLogName).path),
            "Rotation must keep one archive rather than discarding history outright"
        )
        let recent = store.recentLines(maxLines: 50)
        XCTAssertNotNil(recent)
        XCTAssertTrue(recent!.contains("sustained write number 7999"), "The newest line must survive")
    }

    // MARK: - Redaction at the entry point

    /// Redaction happens before the bytes land, so a leaked token is never
    /// recoverable from the file afterwards.
    func testSecretsAreRedactedBeforeReachingDisk() {
        let store = makeStore()
        let message = SensitiveDataRedactor.redactLogMessage(
            #"session response {"accessToken":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.sigsigsig"}"#
        )
        store.appendToFile(level: .error, category: .auth, message: message)
        store.waitForPendingWrites()

        let log = readCurrentLog()
        XCTAssertFalse(log.contains("eyJhbGciOiJIUzI1NiJ9"), "JWT reached disk:\n\(log)")
        XCTAssertTrue(log.contains("***REDACTED***"))
    }

    // MARK: - Session markers (Issue #79)

    func testCleanExitIsRecognisedOnTheNextLaunch() {
        let first = makeStore()   // init writes the session-start marker
        first.appendToFile(level: .event, category: .api, message: "did some work")
        first.endSession()

        let second = makeStore()
        XCTAssertEqual(second.previousSessionOutcome, .clean)
    }

    /// The Issue #79 scenario: the process is killed, so `endSession()` never runs.
    func testMissingEndMarkerIsReportedAsExternalTermination() {
        let first = makeStore()
        first.appendToFile(level: .event, category: .api, message: "did some work")
        // No endSession() — this is what a SIGKILL looks like on disk
        first.waitForPendingWrites()

        let second = makeStore()
        XCTAssertEqual(second.previousSessionOutcome, .terminatedUnexpectedly)
    }

    /// The warning about the previous kill must land in this store's own file,
    /// not in whatever the static default instance points at.
    func testTerminationWarningIsWrittenToTheSameStore() {
        let first = makeStore()
        first.waitForPendingWrites()

        let second = makeStore()
        second.waitForPendingWrites()

        XCTAssertTrue(
            readCurrentLog().contains("terminated externally"),
            "The kill notice belongs in this store's log:\n\(readCurrentLog())"
        )
    }

    func testFirstEverLaunchReportsNoPriorSession() {
        XCTAssertEqual(makeStore().previousSessionOutcome, .unknown)
    }

    /// The marker must be the first line of the process. It previously lived in
    /// `applicationDidFinishLaunching`, but SwiftUI builds `UserSettings` and
    /// `AccountStore` while constructing the App, so their lines landed above it
    /// and read as belonging to the previous session.
    func testSessionMarkerPrecedesEveryOtherLine() {
        let store = makeStore()
        store.appendToFile(level: .event, category: .api, message: "first real line")
        store.waitForPendingWrites()

        let lines = readCurrentLog().split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertTrue(
            lines.first?.contains(LogFormatting.sessionStartMarker) == true,
            "Session marker must lead the file, got:\n\(readCurrentLog())"
        )
    }

}
