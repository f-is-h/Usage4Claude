import XCTest
@testable import Usage4ClaudeCore

/// Tests for `URLSessionConfiguration.uncached`, the starting point for every session the
/// app creates: no URL cache, but the shared cookie storage must survive, since Codex
/// session-token rotation arrives through `HTTPCookieStorage.shared`.
final class NetworkCachePolicyTests: XCTestCase {

    func testUncachedHasNoURLCache() {
        XCTAssertNil(URLSessionConfiguration.uncached.urlCache)
    }

    func testUncachedKeepsSharedCookieStorage() {
        let configuration = URLSessionConfiguration.uncached
        XCTAssertTrue(configuration.httpCookieStorage === HTTPCookieStorage.shared)
        XCTAssertTrue(configuration.httpShouldSetCookies)
    }

    func testEachAccessReturnsAFreshConfiguration() {
        // 调用方会在拿到的实例上改超时；若返回共享实例，各服务的设置会互相覆盖
        let first = URLSessionConfiguration.uncached
        first.timeoutIntervalForRequest = 1
        XCTAssertNotEqual(URLSessionConfiguration.uncached.timeoutIntervalForRequest, 1)
    }
}
