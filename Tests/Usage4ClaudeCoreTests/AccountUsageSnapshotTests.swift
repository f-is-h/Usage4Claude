import XCTest
@testable import Usage4ClaudeCore

final class AccountUsageSnapshotTests: XCTestCase {
    func testPlanKeepsEveryClaudeThenEveryCodexAccount() {
        let claude = (0..<12).map { account("Claude \($0)", provider: .claude) }
        let codex = (0..<9).map { account("Codex \($0)", provider: .codex) }

        let plan = AccountMenuBarPlan.make(
            claudeAccounts: claude,
            codexAccounts: codex
        )

        XCTAssertEqual(plan.count, 21)
        XCTAssertEqual(
            plan.map(\.provider),
            Array(repeating: ProviderType.claude, count: 12)
                + Array(repeating: ProviderType.codex, count: 9)
        )
    }

    func testDuplicateCompactLabelsReceiveStableOrdinals() {
        let accounts = [
            account("Personal", provider: .claude),
            account("Personal", provider: .claude)
        ]

        let labels = AccountMenuBarPlan.make(
            claudeAccounts: accounts,
            codexAccounts: []
        ).map(\.label)

        XCTAssertEqual(labels, ["Personal 1", "Personal 2"])
    }

    func testLabelsAreTruncatedByCharacters() {
        let plan = AccountMenuBarPlan.make(
            claudeAccounts: [account("Personal Account", provider: .claude)],
            codexAccounts: [],
            maxLabelLength: 8
        )

        XCTAssertEqual(plan.map(\.label), ["Personal"])
    }

    func testSnapshotKeepsAliasAndEmailAsSeparateIdentityFields() {
        let account = Account(
            sessionKey: "credential",
            organizationId: "organization",
            organizationName: "Personal workspace",
            email: "owner@example.com",
            alias: "Work",
            provider: .claude
        )

        let snapshot = AccountUsageSnapshot(account: account)

        XCTAssertEqual(snapshot.displayName, "Work")
        XCTAssertEqual(snapshot.accountIdentity, "owner@example.com")
        XCTAssertEqual(account.presentationLabel, "Work — owner@example.com")
    }

    func testSelectedProjectionUsesMatchingUUID() {
        let first = account("One", provider: .claude)
        let second = account("Two", provider: .claude)
        let usage = UsageData(
            fiveHour: .init(percentage: 42, resetsAt: nil),
            sevenDay: nil,
            weeklyModels: [],
            extraUsage: nil
        )
        let snapshots = [
            AccountUsageSnapshot(account: second, payload: .claude(usage))
        ]

        XCTAssertNil(snapshots.selectedClaude(accountId: first.id))
        XCTAssertEqual(snapshots.selectedClaude(accountId: second.id)?.percentage, 42)
    }

    func testCredentialUpdateChangesOnlyMatchingAccount() {
        let first = account("One", provider: .claude)
        let second = account("Two", provider: .claude)

        let updated = AccountCredentialUpdate.replacingCredential(
            in: [first, second],
            accountId: second.id,
            token: "rotated-token"
        )

        XCTAssertEqual(updated[0].sessionKey, first.sessionKey)
        XCTAssertEqual(updated[1].sessionKey, "rotated-token")
        XCTAssertEqual(updated.map(\.id), [first.id, second.id])
    }

    func testCredentialUpdateDoesNotOverwriteNewerCredential() {
        let account = account("One", provider: .claude)

        let staleUpdate = AccountCredentialUpdate.replacingCredential(
            in: [account],
            accountId: account.id,
            expectedToken: "already-replaced",
            token: "late-refresh"
        )
        let validUpdate = AccountCredentialUpdate.replacingCredential(
            in: [account],
            accountId: account.id,
            expectedToken: account.sessionKey,
            token: "fresh-refresh"
        )

        XCTAssertEqual(staleUpdate[0].sessionKey, account.sessionKey)
        XCTAssertEqual(validUpdate[0].sessionKey, "fresh-refresh")
    }

    func testReducerKeepsPreviousPayloadWhenOneAccountFails() {
        let first = account("One", provider: .claude)
        let second = account("Two", provider: .claude)
        let previousUsage = claudeUsage(percentage: 20)
        let freshUsage = claudeUsage(percentage: 70)
        let plan = AccountMenuBarPlan.make(claudeAccounts: [first, second], codexAccounts: [])
        let previous = [
            AccountUsageSnapshot(account: first, payload: .claude(previousUsage)),
            AccountUsageSnapshot(account: second, payload: .claude(previousUsage))
        ]

        let merged = AccountUsageReducer.merge(
            plan: plan,
            previous: previous,
            results: [
                first.id: .success(.claude(freshUsage)),
                second.id: .failure("offline")
            ]
        )

        XCTAssertEqual(merged.selectedClaude(accountId: first.id)?.percentage, 70)
        XCTAssertEqual(merged.selectedClaude(accountId: second.id)?.percentage, 20)
        XCTAssertEqual(merged.first(where: { $0.id == second.id })?.errorDescription, "offline")
    }

    func testReducerDropsAccountsNoLongerInPlan() {
        let kept = account("Kept", provider: .claude)
        let removed = account("Removed", provider: .claude)
        let previous = [
            AccountUsageSnapshot(account: kept, payload: .claude(claudeUsage(percentage: 10))),
            AccountUsageSnapshot(account: removed, payload: .claude(claudeUsage(percentage: 20)))
        ]

        let merged = AccountUsageReducer.merge(
            plan: AccountMenuBarPlan.make(claudeAccounts: [kept], codexAccounts: []),
            previous: previous,
            results: [:]
        )

        XCTAssertEqual(merged.map(\.id), [kept.id])
    }

    func testReducerPublishesPlanBeforeResultsWhileKeepingPreviousPayloads() {
        let first = account("One", provider: .claude)
        let second = account("Two", provider: .codex)
        let previous = [
            AccountUsageSnapshot(account: first, payload: .claude(claudeUsage(percentage: 10)))
        ]
        let plan = AccountMenuBarPlan.make(
            claudeAccounts: [first],
            codexAccounts: [second]
        )

        let merged = AccountUsageReducer.merge(plan: plan, previous: previous, results: [:])

        XCTAssertEqual(merged.map(\.id), [first.id, second.id])
        XCTAssertEqual(merged.selectedClaude(accountId: first.id)?.percentage, 10)
        XCTAssertNil(merged.first(where: { $0.id == second.id })?.payload)
    }

    func testRenderSignatureIncludesEveryAccountAndChangesWithUsage() {
        let first = account("One", provider: .claude)
        let second = account("Two", provider: .claude)
        let initial = [
            AccountUsageSnapshot(account: first, payload: .claude(claudeUsage(percentage: 10))),
            AccountUsageSnapshot(account: second, payload: .claude(claudeUsage(percentage: 20)))
        ]
        let changed = [
            initial[0],
            AccountUsageSnapshot(account: second, payload: .claude(claudeUsage(percentage: 21)))
        ]

        let initialSignature = AccountMenuBarSignature.make(snapshots: initial, hasUpdate: false)
        let changedSignature = AccountMenuBarSignature.make(snapshots: changed, hasUpdate: false)

        XCTAssertTrue(initialSignature.contains(first.id.uuidString))
        XCTAssertTrue(initialSignature.contains(second.id.uuidString))
        XCTAssertNotEqual(initialSignature, changedSignature)
    }

    private func claudeUsage(percentage: Double) -> UsageData {
        UsageData(
            fiveHour: .init(percentage: percentage, resetsAt: nil),
            sevenDay: nil,
            weeklyModels: [],
            extraUsage: nil
        )
    }

    private func account(_ name: String, provider: ProviderType) -> Account {
        Account(
            sessionKey: "credential-\(name)",
            organizationId: "organization-\(name)",
            organizationName: name,
            provider: provider
        )
    }
}
