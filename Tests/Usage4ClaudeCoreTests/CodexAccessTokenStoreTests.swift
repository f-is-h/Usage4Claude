import XCTest
@testable import Usage4ClaudeCore

final class CodexAccessTokenStoreTests: XCTestCase {
    private final class MemoryStorage: CredentialStorage {
        var values: [String: String] = [:]
        var acceptsWrites = true
        func save(key: String, value: String) -> Bool {
            guard acceptsWrites else { return false }
            values[key] = value
            return true
        }
        func load(key: String) -> String? { values[key] }
        func delete(key: String) -> Bool { values.removeValue(forKey: key); return true }
    }

    func testRestoresAcrossStoreInstancesWithoutRefreshing() async throws {
        let storage = MemoryStorage()
        let beforeRestart = CodexAccessTokenStore(storage: storage)
        let expiry = Date().addingTimeInterval(3600)
        XCTAssertTrue(beforeRestart.save(.init(accessToken: "access", refreshToken: "rt.login", expiresAt: expiry)))
        XCTAssertFalse(storage.values.keys.contains("rt.login"))
        let afterRestart = CodexAccessTokenStore(storage: storage)
        let cache = OAuthTokenCache()
        let token = try await cache.accessToken(refreshToken: "rt.login", margin: 0) { credential in
            try XCTUnwrap(afterRestart.load(credential: credential))
        }
        XCTAssertEqual(token, "access")
        XCTAssertEqual(afterRestart.load(credential: "rt.login")?.expiresAt, expiry)
        XCTAssertNil(afterRestart.load(credential: "rt.other"))
    }

    func testDeletesExpiredAndMalformedEntries() {
        let storage = MemoryStorage()
        let store = CodexAccessTokenStore(storage: storage)
        XCTAssertTrue(store.save(.init(accessToken: "access", refreshToken: "rt.login", expiresAt: Date().addingTimeInterval(3600))))
        let key = storage.values.keys.first!
        storage.values[key] = #"{"accessToken":"access","expiresAt":0}"#
        XCTAssertNil(store.load(credential: "rt.login"))
        XCTAssertTrue(storage.values.isEmpty)
        storage.values[key] = "invalid json"
        XCTAssertNil(store.load(credential: "rt.login"))
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testRejectsExpiredJWTDespiteFutureCacheDeadline() {
        let storage = MemoryStorage()
        let store = CodexAccessTokenStore(storage: storage)
        let payload = Data(#"{"exp":1700000000}"#.utf8).base64EncodedString()
        XCTAssertTrue(store.save(.init(accessToken: "header.\(payload).signature", refreshToken: "rt.login", expiresAt: Date().addingTimeInterval(3600))))
        XCTAssertNil(store.load(credential: "rt.login"))
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testReplacementDeletionAndWriteFailure() {
        let storage = MemoryStorage()
        let store = CodexAccessTokenStore(storage: storage)
        let expiry = Date().addingTimeInterval(3600)
        XCTAssertTrue(store.save(.init(accessToken: "first", refreshToken: "rt.login", expiresAt: expiry)))
        XCTAssertTrue(store.save(.init(accessToken: "second", refreshToken: "rt.login", expiresAt: expiry)))
        XCTAssertEqual(store.load(credential: "rt.login")?.accessToken, "second")
        storage.acceptsWrites = false
        XCTAssertFalse(store.save(.init(accessToken: "third", refreshToken: "rt.login", expiresAt: expiry)))
        XCTAssertEqual(store.load(credential: "rt.login")?.accessToken, "second")
        store.delete(credential: "rt.login")
        XCTAssertNil(store.load(credential: "rt.login"))
    }
}
