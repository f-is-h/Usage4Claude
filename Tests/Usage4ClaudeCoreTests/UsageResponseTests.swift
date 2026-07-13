import XCTest
@testable import Usage4ClaudeCore

/// Tests for `UsageResponse.toUsageData()` — the JSON → in-memory transform
/// that backs the main /api/organizations/<id>/usage fetch.
///
/// Specs the production code intends to honor:
/// - 5-hour data is always parsed (utilization + resets_at).
/// - 7-day always emits a placeholder. Every Claude account has a 7-day limit
///   even before usage starts; when `seven_day` is missing OR returns
///   (utilization=0, resets_at=null), the transform yields a 0% placeholder
///   so the UI can still display the row from day one.
/// - Opus and Sonnet are nil when the field is missing OR when
///   utilization=0 AND resets_at=nil (the API's "no data" sentinel).
/// - resets_at strings are rounded to the nearest whole second so the UI
///   countdown doesn't jitter across `.645` / `.159` fractional boundaries.
final class UsageResponseTests: XCTestCase {

    // MARK: - Decode helper

    private func decode(_ json: String) throws -> UsageResponse {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    // MARK: - 5-hour limit (always parsed)

    func testFiveHourParsesWithIntegerUtilization() throws {
        let json = """
        {
            "five_hour": { "utilization": 42, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()

        XCTAssertNotNil(usage.fiveHour)
        XCTAssertEqual(usage.fiveHour?.percentage, 42)
        XCTAssertNotNil(usage.fiveHour?.resetsAt)
    }

    func testFiveHourParsesFloatingPointUtilization() throws {
        let json = """
        {
            "five_hour": { "utilization": 73.5, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.fiveHour?.percentage, 73.5)
    }

    func testFiveHourMissingResetsAtParsesPercentage() throws {
        // resets_at can be nil when usage hasn't started — percentage still parses.
        let json = """
        {
            "five_hour": { "utilization": 0, "resets_at": null },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.fiveHour?.percentage, 0)
        XCTAssertNil(usage.fiveHour?.resetsAt)
    }

    // MARK: - 7-day limit (always emits a placeholder)

    func testSevenDayMissingFieldReturnsZeroPlaceholder() throws {
        // Every Claude account has a 7-day limit; when the API doesn't include
        // a `seven_day` field at all (e.g. brand-new accounts), production
        // code emits a 0% placeholder so the UI can still display the row.
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNotNil(usage.sevenDay)
        XCTAssertEqual(usage.sevenDay?.percentage, 0)
        XCTAssertNil(usage.sevenDay?.resetsAt)
    }

    func testSevenDayWithZeroUtilizationAndNoResetReturnsZeroPlaceholder() throws {
        // Same intent as the missing-field case: when the API returns
        // (utilization=0, resets_at=null) the row is shown with 0%, not hidden.
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": { "utilization": 0, "resets_at": null },
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNotNil(usage.sevenDay)
        XCTAssertEqual(usage.sevenDay?.percentage, 0)
        XCTAssertNil(usage.sevenDay?.resetsAt)
    }

    func testSevenDayWithRealDataIsParsed() throws {
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": { "utilization": 55, "resets_at": "2026-05-08T15:00:00.000Z" },
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.sevenDay?.percentage, 55)
        XCTAssertNotNil(usage.sevenDay?.resetsAt)
    }

    // MARK: - Opus / Sonnet — "no data" sentinel still hides the row

    func testOpusAndSonnetMissingFieldsAreNil() throws {
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.opus)
        XCTAssertNil(usage.sonnet)
    }

    func testOpusZeroSentinelIsNil() throws {
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": { "utilization": 0, "resets_at": null },
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.opus)
    }

    func testSonnetZeroSentinelIsNil() throws {
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": { "utilization": 0, "resets_at": null }
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.sonnet)
    }

    func testOpusAndSonnetWithRealDataAreParsed() throws {
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus":   { "utilization": 25, "resets_at": "2026-05-08T15:00:00.000Z" },
            "seven_day_sonnet": { "utilization": 67, "resets_at": "2026-05-08T15:00:00.000Z" }
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.opus?.percentage, 25)
        XCTAssertEqual(usage.sonnet?.percentage, 67)
    }

    // MARK: - resets_at fractional-second rounding

    func testResetTimeRoundsFractionalSecondsUp() throws {
        // .645 → next whole second
        let json = """
        {
            "five_hour": { "utilization": 50, "resets_at": "2026-05-01T05:59:59.645Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        guard let resetsAt = usage.fiveHour?.resetsAt else {
            XCTFail("expected resetsAt")
            return
        }
        // Rounded interval should land exactly on a whole-second boundary.
        let interval = resetsAt.timeIntervalSinceReferenceDate
        XCTAssertEqual(interval, interval.rounded(), accuracy: 0.0001,
                       "resets_at should be rounded to the nearest whole second")
    }

    func testResetTimeRoundsFractionalSecondsDown() throws {
        // .159 → previous whole second
        let json = """
        {
            "five_hour": { "utilization": 50, "resets_at": "2026-05-01T06:00:00.159Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        guard let resetsAt = usage.fiveHour?.resetsAt else {
            XCTFail("expected resetsAt")
            return
        }
        let interval = resetsAt.timeIntervalSinceReferenceDate
        XCTAssertEqual(interval, interval.rounded(), accuracy: 0.0001)
    }

    // MARK: - Extra Usage is always nil from this transform

    func testToUsageDataLeavesExtraUsageNil() throws {
        // Extra Usage flows through a separate fetcher; UsageResponse must
        // never invent it.
        let json = """
        {
            "five_hour": { "utilization": 10, "resets_at": "2026-05-01T15:00:00.000Z" },
            "seven_day": null,
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.extraUsage)
    }

    // MARK: - Scoped model weekly limits (Claude 5 `limits[]`)
    //
    // In the Claude 5 era the API stopped populating `seven_day_opus` /
    // `seven_day_sonnet` and moved per-model weekly limits into a `limits`
    // array. Each model-scoped entry carries `scope.model.display_name`
    // (e.g. "Fable") + `percent`. These flow into the opus/sonnet display
    // slots so the existing weekly-limit UI lights up, with the real model
    // name surfaced via `opusModelName` / `sonnetModelName`.

    func testScopedModelWeeklyLimitPopulatesOpusSlotWithName() throws {
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": { "utilization": 13, "resets_at": "2026-07-08T16:59:59.000Z" },
            "seven_day_opus": null,
            "seven_day_sonnet": null,
            "limits": [
                { "kind": "session",     "group": "session", "percent": 20, "scope": null },
                { "kind": "weekly_all",  "group": "weekly",  "percent": 13, "scope": null },
                { "kind": "weekly_scoped", "group": "weekly", "percent": 21,
                  "resets_at": "2026-07-08T16:59:59.000Z",
                  "scope": { "model": { "id": null, "display_name": "Fable" } },
                  "is_active": true }
            ]
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.opus?.percentage, 21)
        XCTAssertEqual(usage.opusModelName, "Fable")
        XCTAssertNotNil(usage.opus?.resetsAt)
        XCTAssertNil(usage.sonnet)
    }

    func testLegacyOpusFieldTakesPrecedenceOverScopedModel() throws {
        // If the API ever returns both the legacy field and a limits entry,
        // the dedicated field wins and no model-name override is applied.
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": null,
            "seven_day_opus": { "utilization": 40, "resets_at": "2026-07-08T16:59:59.000Z" },
            "seven_day_sonnet": null,
            "limits": [
                { "kind": "weekly_scoped", "group": "weekly", "percent": 21,
                  "scope": { "model": { "display_name": "Fable" } } }
            ]
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.opus?.percentage, 40)
        XCTAssertNil(usage.opusModelName)
    }

    func testTwoScopedModelsFillOpusThenSonnet() throws {
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null,
            "limits": [
                { "kind": "weekly_scoped", "group": "weekly", "percent": 21,
                  "scope": { "model": { "display_name": "Fable" } } },
                { "kind": "weekly_scoped", "group": "weekly", "percent": 8,
                  "scope": { "model": { "display_name": "Opus" } } }
            ]
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.opus?.percentage, 21)
        XCTAssertEqual(usage.opusModelName, "Fable")
        XCTAssertEqual(usage.sonnet?.percentage, 8)
        XCTAssertEqual(usage.sonnetModelName, "Opus")
    }

    func testThreeScopedModelsAllPreservedInWeeklyModels() throws {
        // Regression guard for the array refactor: a third (and beyond)
        // model-scoped weekly limit is no longer dropped. All entries flow into
        // `weeklyModels` in API order; the first two still derive the legacy
        // opus/sonnet slots for the menu-bar and older read paths.
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null,
            "limits": [
                { "kind": "weekly_scoped", "group": "weekly", "percent": 21,
                  "scope": { "model": { "display_name": "Fable" } } },
                { "kind": "weekly_scoped", "group": "weekly", "percent": 8,
                  "scope": { "model": { "display_name": "Opus" } } },
                { "kind": "weekly_scoped", "group": "weekly", "percent": 3,
                  "scope": { "model": { "display_name": "Sonnet" } } }
            ]
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertEqual(usage.weeklyModels.count, 3)
        XCTAssertEqual(usage.weeklyModels.map(\.modelName), ["Fable", "Opus", "Sonnet"])
        XCTAssertEqual(usage.weeklyModels.map { $0.limit.percentage }, [21, 8, 3])
        // 前两个仍派生到 opus / sonnet 槽位
        XCTAssertEqual(usage.opus?.percentage, 21)
        XCTAssertEqual(usage.opusModelName, "Fable")
        XCTAssertEqual(usage.sonnet?.percentage, 8)
        XCTAssertEqual(usage.sonnetModelName, "Opus")
    }

    func testNonModelScopedLimitsAreIgnored() throws {
        // session / weekly_all entries carry no scope.model — they must not
        // create phantom model rows.
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null,
            "limits": [
                { "kind": "session",    "group": "session", "percent": 20, "scope": null },
                { "kind": "weekly_all", "group": "weekly",  "percent": 13, "scope": null }
            ]
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.opus)
        XCTAssertNil(usage.sonnet)
        XCTAssertNil(usage.opusModelName)
    }

    func testMissingLimitsArrayLeavesScopedSlotsNil() throws {
        // Backward compatibility: responses without a `limits` array behave
        // exactly as before.
        let json = """
        {
            "five_hour": { "utilization": 20, "resets_at": "2026-07-03T18:19:59.000Z" },
            "seven_day": null,
            "seven_day_opus": null,
            "seven_day_sonnet": null
        }
        """
        let usage = try decode(json).toUsageData()
        XCTAssertNil(usage.opus)
        XCTAssertNil(usage.opusModelName)
    }
}
