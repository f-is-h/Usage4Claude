//
//  AccountTokenRotationTests.swift
//  Usage4ClaudeCoreTests
//
//  覆盖 token 轮换的落点判定。核心回归场景是「刷新期间切换账号」：
//  以前写回走「当前选中账号」，切一次就会把 A 的新 token 写进 B 的条目，
//  而 refresh_token 一经轮换旧值即作废，两个账号会同时永久登出。
//
//  Copyright © 2026 f-is-h. All rights reserved.
//

import XCTest
@testable import Usage4ClaudeCore

final class AccountTokenRotationTests: XCTestCase {

    private func makeAccount(sessionKey: String, name: String, provider: ProviderType = .claude) -> Account {
        Account(
            sessionKey: sessionKey,
            organizationId: "org-\(name)",
            organizationName: name,
            provider: provider
        )
    }

    // MARK: - 正常轮换

    func testRotationTargetsTheAccountHoldingTheOldToken() {
        let accounts = [
            makeAccount(sessionKey: "token-A", name: "Personal"),
            makeAccount(sessionKey: "token-B", name: "Work")
        ]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "token-A-new")

        XCTAssertEqual(outcome, .apply(index: 0))
    }

    func testRotationFindsAccountRegardlessOfPosition() {
        let accounts = [
            makeAccount(sessionKey: "token-A", name: "Personal"),
            makeAccount(sessionKey: "token-B", name: "Work"),
            makeAccount(sessionKey: "token-C", name: "Side")
        ]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-C", with: "token-C-new")

        XCTAssertEqual(outcome, .apply(index: 2))
    }

    // MARK: - 回归：刷新期间切换账号

    /// 这是修复的核心场景。账号 A 发起刷新，回调到达前用户切到了 B。
    /// 判定必须仍然落在 A 身上（index 0），而不是「当前选中」的 B。
    func testSwitchingAccountsMidRefreshStillTargetsTheOriginator() {
        let accounts = [
            makeAccount(sessionKey: "token-A", name: "Personal"),
            makeAccount(sessionKey: "token-B", name: "Work")
        ]

        // 用户此刻已切到 Work，但轮换的是 Personal 发起的那一次
        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "token-A-rotated")

        XCTAssertEqual(outcome, .apply(index: 0), "轮换必须落在发起刷新的账号上，与当前选中账号无关")
    }

    /// 账号在刷新期间被删除：宁可丢掉这次轮换，也不能回退成写「当前账号」
    func testRotationIsDroppedWhenOriginatingAccountWasRemoved() {
        let accounts = [makeAccount(sessionKey: "token-B", name: "Work")]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "token-A-rotated")

        XCTAssertEqual(outcome, .skip(.accountGone))
    }

    /// 账号列表为空（全部删除）时同样必须放弃，不能崩也不能误写
    func testRotationIsDroppedWhenNoAccountsRemain() {
        let outcome = AccountTokenRotation.resolve(accounts: [], replacing: "token-A", with: "token-A-rotated")

        XCTAssertEqual(outcome, .skip(.accountGone))
    }

    /// 旧 token 已被另一次刷新写成了新值，此时按旧值查不到账号，应放弃而不是覆盖
    func testRotationIsDroppedWhenTokenAlreadyRotatedByAnotherRefresh() {
        let accounts = [makeAccount(sessionKey: "token-A-rotated-once", name: "Personal")]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "token-A-rotated-twice")

        XCTAssertEqual(outcome, .skip(.accountGone))
    }

    // MARK: - 无需写入的情形

    func testUnchangedTokenIsNotWritten() {
        let accounts = [makeAccount(sessionKey: "token-A", name: "Personal")]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "token-A")

        XCTAssertEqual(outcome, .skip(.unchanged))
    }

    /// 空的新 token 绝不能覆盖仍然有效的凭据
    func testEmptyNewTokenNeverOverwritesCredentials() {
        let accounts = [makeAccount(sessionKey: "token-A", name: "Personal")]

        let outcome = AccountTokenRotation.resolve(accounts: accounts, replacing: "token-A", with: "")

        XCTAssertEqual(outcome, .skip(.emptyToken))
    }

    /// 空 token 的判定优先于账号查找，即使账号本身已不存在
    func testEmptyNewTokenIsRejectedBeforeLookup() {
        let outcome = AccountTokenRotation.resolve(accounts: [], replacing: "token-A", with: "")

        XCTAssertEqual(outcome, .skip(.emptyToken))
    }

    // MARK: - Provider 隔离

    /// Claude 与 Codex 各自维护账号列表，调用方传入哪份列表就只在哪份里查找
    func testLookupIsScopedToTheProvidedList() {
        let codexAccounts = [makeAccount(sessionKey: "codex-token", name: "Codex", provider: .codex)]

        let outcome = AccountTokenRotation.resolve(accounts: codexAccounts, replacing: "claude-token", with: "claude-new")

        XCTAssertEqual(outcome, .skip(.accountGone))
    }
}
