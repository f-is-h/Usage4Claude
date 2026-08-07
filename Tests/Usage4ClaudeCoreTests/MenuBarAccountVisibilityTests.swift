import XCTest
@testable import Usage4ClaudeCore

final class MenuBarAccountVisibilityTests: XCTestCase {
    func testAccountsAreVisibleWhenNoPreferenceHasBeenSaved() {
        let accountId = UUID()
        let visibility = MenuBarAccountVisibility(persistedAccountIdStrings: nil)

        XCTAssertTrue(visibility.isVisible(accountId: accountId))
        XCTAssertTrue(visibility.hiddenAccountIds.isEmpty)
    }

    func testHidingAndShowingAnAccountUpdatesPersistedIDs() {
        let accountId = UUID()
        var visibility = MenuBarAccountVisibility(persistedAccountIdStrings: nil)

        visibility.setVisibility(accountId: accountId, isVisible: false)
        XCTAssertFalse(visibility.isVisible(accountId: accountId))
        XCTAssertEqual(visibility.persistedAccountIdStrings, [accountId.uuidString])

        visibility.setVisibility(accountId: accountId, isVisible: true)
        XCTAssertTrue(visibility.isVisible(accountId: accountId))
        XCTAssertTrue(visibility.persistedAccountIdStrings.isEmpty)
    }

    func testInvalidPersistedIDsAreIgnored() {
        let accountId = UUID()
        let visibility = MenuBarAccountVisibility(
            persistedAccountIdStrings: ["not-a-uuid", accountId.uuidString]
        )

        XCTAssertEqual(visibility.hiddenAccountIds, [accountId])
    }

    func testRemovingAccountPrunesItsHiddenPreference() {
        let hiddenId = UUID()
        var visibility = MenuBarAccountVisibility(
            persistedAccountIdStrings: [hiddenId.uuidString]
        )

        visibility.removeAccount(hiddenId)

        XCTAssertTrue(visibility.hiddenAccountIds.isEmpty)
    }
}
