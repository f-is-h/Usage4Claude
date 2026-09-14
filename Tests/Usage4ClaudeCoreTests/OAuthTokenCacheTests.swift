import XCTest
@testable import Usage4ClaudeCore

/// Tests for `OAuthTokenCache` — the actor-based OAuth access_token cache +
/// single-flight refresh that replaced the hand-written NSLock + waiters array.
///
/// Specs the production code intends to honor:
/// - A cached, non-expired token (for the same refresh_token) is returned
///   without invoking the refresh closure again.
/// - Concurrent callers for the SAME refresh_token share exactly one network
///   call (single-flight): the refresh closure runs once, not once per caller.
/// - Concurrent callers for DIFFERENT refresh_tokens are NOT merged — each
///   gets its own refresh.
/// - A failed refresh does not poison the cache: the next call retries fresh.
/// - `clear()` forces the next call to refresh even if the cached token
///   hasn't technically expired yet.
/// - Refresh_token rotation: the token returned by `refresh` becomes the new
///   cache key, so a later call with the ORIGINAL refresh_token misses cache.
final class OAuthTokenCacheTests: XCTestCase {

    /// Actor-based call counter — a plain class with a lock would work too,
    /// but an actor keeps the test itself free of manual synchronization.
    actor CallCounter {
        private(set) var count = 0
        func increment() -> Int {
            count += 1
            return count
        }
    }

    private func makeTokens(access: String, refresh: String = "", expiresIn: TimeInterval = 3600) -> OAuthTokenCache.Tokens {
        OAuthTokenCache.Tokens(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expiresIn))
    }

    func testReturnsFreshTokenOnFirstCall() async throws {
        let cache = OAuthTokenCache()
        let token = try await cache.accessToken(refreshToken: "rt-1") { rt in
            self.makeTokens(access: "access-for-\(rt)", refresh: rt)
        }
        XCTAssertEqual(token, "access-for-rt-1")
    }

    func testSecondCallUsesCacheWithoutRefreshing() async throws {
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        func fetch() async throws -> String {
            try await cache.accessToken(refreshToken: "rt-1") { rt in
                _ = await counter.increment()
                return self.makeTokens(access: "access-1", refresh: rt)
            }
        }

        let first = try await fetch()
        let second = try await fetch()

        XCTAssertEqual(first, "access-1")
        XCTAssertEqual(second, "access-1")
        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 1, "second call should hit cache, not refresh again")
    }

    func testConcurrentCallsWithSameRefreshTokenShareOneRefresh() async throws {
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await cache.accessToken(refreshToken: "rt-shared") { rt in
                        _ = await counter.increment()
                        // Simulate network latency so all 20 callers actually overlap
                        try await Task.sleep(nanoseconds: 50_000_000)
                        return self.makeTokens(access: "access-shared", refresh: rt)
                    }
                }
            }
            var collected: [String] = []
            for try await value in group { collected.append(value) }
            return collected
        }

        XCTAssertEqual(results.count, 20)
        XCTAssertTrue(results.allSatisfy { $0 == "access-shared" })
        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 1, "20 concurrent callers for the same refresh_token must share a single network call")
    }

    func testConcurrentCallsWithDifferentRefreshTokensAreNotMerged() async throws {
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try await cache.accessToken(refreshToken: "rt-\(i)") { rt in
                        _ = await counter.increment()
                        try await Task.sleep(nanoseconds: 20_000_000)
                        return self.makeTokens(access: "access-\(rt)", refresh: rt)
                    }
                }
            }
            var collected: [String] = []
            for try await value in group { collected.append(value) }
            return collected
        }

        XCTAssertEqual(Set(results).count, 5, "each distinct refresh_token should get its own access token")
        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 5, "different refresh_tokens must not be merged into one flight")
    }

    func testFailedRefreshDoesNotPoisonCacheForNextCall() async {
        struct DummyError: Error {}
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        do {
            _ = try await cache.accessToken(refreshToken: "rt-1") { _ in
                _ = await counter.increment()
                throw DummyError()
            }
            XCTFail("expected the first call to throw")
        } catch {
            // expected
        }

        // A second call after the failure must attempt a fresh refresh, not
        // reuse/hang on the failed task.
        let token = try? await cache.accessToken(refreshToken: "rt-1") { rt in
            _ = await counter.increment()
            return self.makeTokens(access: "access-recovered", refresh: rt)
        }

        XCTAssertEqual(token, "access-recovered")
        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 2, "retry after failure should invoke refresh again, not reuse the failed task")
    }

    func testClearForcesRefreshEvenBeforeExpiry() async throws {
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        func fetch() async throws -> String {
            try await cache.accessToken(refreshToken: "rt-1") { rt in
                let n = await counter.increment()
                return self.makeTokens(access: "access-\(n)", refresh: rt)
            }
        }

        let first = try await fetch()
        await cache.clear()
        let second = try await fetch()

        XCTAssertEqual(first, "access-1")
        XCTAssertEqual(second, "access-2", "after clear(), a fresh token must be fetched even though the old one hadn't expired")
        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 2)
    }

    func testRefreshTokenRotationChangesTheCacheKey() async throws {
        let cache = OAuthTokenCache()

        // First call rotates rt-old -> rt-new.
        let first = try await cache.accessToken(refreshToken: "rt-old") { _ in
            self.makeTokens(access: "access-1", refresh: "rt-new")
        }
        XCTAssertEqual(first, "access-1")

        // A later call with the ORIGINAL (now-stale) refresh_token must miss
        // cache (cachedForRefreshToken is "rt-new") and refresh again.
        var refreshedWithStaleToken = false
        let second = try await cache.accessToken(refreshToken: "rt-old") { _ in
            refreshedWithStaleToken = true
            return self.makeTokens(access: "access-2", refresh: "rt-new")
        }

        XCTAssertTrue(refreshedWithStaleToken, "stale refresh_token must not hit the cache written under the rotated token")
        XCTAssertEqual(second, "access-2")

        // But a call with the NEW refresh_token should now hit cache.
        let third = try await cache.accessToken(refreshToken: "rt-new") { _ in
            XCTFail("should have hit cache for the rotated refresh_token")
            return self.makeTokens(access: "unexpected", refresh: "rt-new")
        }
        XCTAssertEqual(third, "access-2")
    }

    // MARK: - validCachedToken（刷新失败时的回退查询）

    func testValidCachedTokenReturnsUnexpiredTokenEvenInsideRefreshMargin() async throws {
        let cache = OAuthTokenCache()

        // Cache a token that expires in 60s — inside a 20-minute refresh margin,
        // but not actually expired yet.
        _ = try await cache.accessToken(refreshToken: "rt-1") { rt in
            OAuthTokenCache.Tokens(accessToken: "access-1", refreshToken: rt, expiresAt: Date().addingTimeInterval(60))
        }

        // With margin 0 (the fallback query), the token still counts as usable.
        let fallback = await cache.validCachedToken(refreshToken: "rt-1")
        XCTAssertEqual(fallback, "access-1", "a not-yet-expired token must be available as fallback even inside the refresh margin")

        // With a 20-minute margin it does NOT count (that's what forces the refresh attempt).
        let strict = await cache.validCachedToken(refreshToken: "rt-1", margin: 20 * 60)
        XCTAssertNil(strict)
    }

    func testValidCachedTokenReturnsNilForExpiredOrForeignToken() async throws {
        let cache = OAuthTokenCache()

        // Nothing cached yet.
        let empty = await cache.validCachedToken(refreshToken: "rt-1")
        XCTAssertNil(empty)

        // Cache a token that is already expired.
        _ = try await cache.accessToken(refreshToken: "rt-1") { rt in
            OAuthTokenCache.Tokens(accessToken: "access-expired", refreshToken: rt, expiresAt: Date().addingTimeInterval(-1))
        }
        let expired = await cache.validCachedToken(refreshToken: "rt-1")
        XCTAssertNil(expired, "an expired token must never be offered as fallback")

        // Cache a valid token for rt-1; querying with a different refresh_token must miss.
        await cache.clear()
        _ = try await cache.accessToken(refreshToken: "rt-1") { rt in
            OAuthTokenCache.Tokens(accessToken: "access-1", refreshToken: rt, expiresAt: Date().addingTimeInterval(3600))
        }
        let foreign = await cache.validCachedToken(refreshToken: "rt-other")
        XCTAssertNil(foreign, "fallback must be keyed to the same credential")
    }

    func testExpiredCacheTriggersRefresh() async throws {
        let cache = OAuthTokenCache()
        let counter = CallCounter()

        // First fetch caches a token expiring in 60s (real time).
        _ = try await cache.accessToken(refreshToken: "rt-1", margin: 5 * 60) { rt in
            _ = await counter.increment()
            return OAuthTokenCache.Tokens(accessToken: "access-1", refreshToken: rt, expiresAt: Date().addingTimeInterval(60))
        }

        // With a 5-minute margin, a token expiring in 60s no longer counts as
        // valid, so the next call must refresh again.
        _ = try await cache.accessToken(refreshToken: "rt-1", margin: 5 * 60) { rt in
            _ = await counter.increment()
            return OAuthTokenCache.Tokens(accessToken: "access-2", refreshToken: rt, expiresAt: Date().addingTimeInterval(3600))
        }

        let refreshCount = await counter.count
        XCTAssertEqual(refreshCount, 2, "token within the refresh margin should be treated as needing renewal")
    }
}
