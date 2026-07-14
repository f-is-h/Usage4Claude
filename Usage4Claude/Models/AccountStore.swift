//
//  AccountStore.swift
//  Usage4Claude
//
//  Extracted from UserSettings.swift (审计报告 4.1)：账户 CRUD、Keychain 持久化、
//  当前账户 ID、silentlyUpdate*Token 等多账户逻辑独立成一个可组合的 ObservableObject。
//  UserSettings 通过 accountStore 属性持有并转发，对外 API 保持不变。
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Combine
import OSLog

/// 多账户（Claude + Codex）存储、持久化与切换逻辑
final class AccountStore: ObservableObject {

    private let defaults = UserDefaults.standard
    private let keychain = KeychainManager.shared

    // MARK: - Claude 账户

    /// 账户列表（存储在 Keychain 中）
    @Published var accounts: [Account] {
        didSet {
            saveAccounts()
        }
    }

    /// 当前激活账户的 ID（存储在 UserDefaults 中）
    @Published var currentAccountId: UUID? {
        didSet {
            #if DEBUG
            let key = "DEBUG_currentAccountId"
            #else
            let key = "currentAccountId"
            #endif
            if let id = currentAccountId {
                defaults.set(id.uuidString, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// 当前激活的账户
    var currentAccount: Account? {
        guard let id = currentAccountId else { return accounts.first }
        return accounts.first { $0.id == id } ?? accounts.first
    }

    /// Claude Session Key（计算属性，指向当前账户）
    var sessionKey: String {
        get { currentAccount?.sessionKey ?? "" }
        set {
            guard let id = currentAccountId,
                  let index = accounts.firstIndex(where: { $0.id == id }) else { return }
            accounts[index].sessionKey = newValue
        }
    }

    /// Claude Organization ID（计算属性，指向当前账户）
    var organizationId: String {
        get { currentAccount?.organizationId ?? "" }
        set {
            guard let id = currentAccountId,
                  let index = accounts.firstIndex(where: { $0.id == id }) else { return }
            accounts[index].organizationId = newValue
        }
    }

    /// Claude 账户列表的语义别名（等同于 accounts，用于 provider-aware 代码中保持对称）
    var claudeAccounts: [Account] { accounts }

    /// 用于显示的账户列表
    var displayAccounts: [Account] { accounts }

    /// 当前账户的显示名称
    var currentAccountName: String? { currentAccount?.displayName }

    // MARK: - Codex 账户

    /// Codex 账户列表（存储在独立 Keychain key "accounts_codex" 中，不干扰 Claude 数据）
    @Published var codexAccounts: [Account] {
        didSet {
            saveCodexAccounts()
        }
    }

    /// 当前激活的 Codex 账户 ID（存储在 UserDefaults 中）
    @Published var currentCodexAccountId: UUID? {
        didSet {
            #if DEBUG
            let key = "DEBUG_currentCodexAccountId"
            #else
            let key = "currentCodexAccountId"
            #endif
            if let id = currentCodexAccountId {
                defaults.set(id.uuidString, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// 当前激活的 Codex 账户
    var currentCodexAccount: Account? {
        guard let id = currentCodexAccountId else { return codexAccounts.first }
        return codexAccounts.first { $0.id == id } ?? codexAccounts.first
    }

    /// Codex Session Token（计算属性，指向当前 Codex 账户的 sessionKey 字段）
    var codexSessionToken: String {
        currentCodexAccount?.sessionKey ?? ""
    }

    /// Codex 认证信息是否已配置
    var hasValidCodexCredentials: Bool {
        !codexSessionToken.isEmpty
    }

    // MARK: - Initialization

    init() {
        // MARK: - 加载多账户数据（v2.1.0）

        // 从 Keychain 加载账户列表（使用局部变量避免初始化顺序问题）
        var loadedAccounts = keychain.loadAccounts() ?? []
        var loadedCurrentAccountId: UUID? = nil

        // 加载当前账户 ID
        #if DEBUG
        let currentAccountIdKey = "DEBUG_currentAccountId"
        #else
        let currentAccountIdKey = "currentAccountId"
        #endif
        if let idString = defaults.string(forKey: currentAccountIdKey),
           let id = UUID(uuidString: idString) {
            loadedCurrentAccountId = id
        } else if let firstAccount = loadedAccounts.first {
            // 如果没有保存当前账户 ID，默认使用第一个账户
            loadedCurrentAccountId = firstAccount.id
        }

        // MARK: - 数据迁移（v2.0.x → v2.1.0 多账户）

        // 检查是否需要从单账户迁移到多账户
        if loadedAccounts.isEmpty && !defaults.bool(forKey: "multiAccountMigrated") {
            // 尝试从旧的单账户数据迁移
            let oldSessionKey = keychain.loadSessionKey() ?? ""
            let oldOrgId = defaults.string(forKey: "organizationId") ?? ""

            if !oldSessionKey.isEmpty && !oldOrgId.isEmpty {
                Logger.settings.notice("[Migration] Migrating single account to multi-account system")

                // 获取组织名称（如果有缓存）
                let cachedOrgs = Self.loadOrganizations(from: defaults)
                let orgName = cachedOrgs.first { $0.uuid == oldOrgId }?.name ?? "Account 1"

                // 创建第一个账户
                let migratedAccount = Account(
                    sessionKey: oldSessionKey,
                    organizationId: oldOrgId,
                    organizationName: orgName
                )
                loadedAccounts = [migratedAccount]
                loadedCurrentAccountId = migratedAccount.id

                // 清理旧的单账户数据
                keychain.deleteSessionKey()
                defaults.removeObject(forKey: "organizationId")

                Logger.settings.notice("[Migration] Multi-account migration completed")
            }

            defaults.set(true, forKey: "multiAccountMigrated")
        }

        // 设置 accounts 和 currentAccountId
        self.accounts = loadedAccounts
        self.currentAccountId = loadedCurrentAccountId

        // MARK: - 加载 Codex 账户数据

        let loadedCodexAccounts = keychain.loadCodexAccounts() ?? []
        self.codexAccounts = loadedCodexAccounts

        #if DEBUG
        let codexCurrentAccountIdKey = "DEBUG_currentCodexAccountId"
        #else
        let codexCurrentAccountIdKey = "currentCodexAccountId"
        #endif
        if let idString = defaults.string(forKey: codexCurrentAccountIdKey),
           let id = UUID(uuidString: idString) {
            self.currentCodexAccountId = id
        } else {
            self.currentCodexAccountId = loadedCodexAccounts.first?.id
        }

        // MARK: - 旧版迁移（v1.x → v2.0.0，保留向后兼容）

        // 迁移 Organization ID 从 Keychain 到 UserDefaults（旧版迁移，现已包含在上面的多账户迁移中）
        if !defaults.bool(forKey: "organizationIdMigrated") {
            if let oldOrgId = keychain.loadOrganizationId(), !oldOrgId.isEmpty {
                Logger.settings.notice("[Migration] Found Organization ID in old Keychain location")
                keychain.deleteOrganizationId()
            }
            defaults.set(true, forKey: "organizationIdMigrated")
        }
    }

    // MARK: - Claude Account Management

    /// 保存账户列表到 Keychain
    private func saveAccounts() {
        // 在调用线程（主线程）快照，避免后台队列直接读取主线程持有的可变数组造成数据竞争
        let snapshot = accounts
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.keychain.saveAccounts(snapshot)
        }
    }

    /// 添加新账户
    /// - Parameter account: 要添加的账户
    /// - Returns: 是否是第一个 Claude 账户（调用方可据此触发额外的一次性初始化逻辑）
    @discardableResult
    func addAccount(_ account: Account) -> Bool {
        // 检查是否已存在相同 organizationId 的账户
        if accounts.contains(where: { $0.organizationId == account.organizationId }) {
            Logger.settings.notice("账户已存在，跳过: \(account.displayName)")
            return false
        }
        let wasFirstClaudeAccount = accounts.isEmpty
        accounts.append(account)
        // 如果是第一个账户，自动设为当前账户
        if accounts.count == 1 {
            currentAccountId = account.id
        }
        Logger.settings.notice("添加账户: \(account.displayName)")

        if wasFirstClaudeAccount {
            postAccountChanged(provider: .claude)
        }
        return wasFirstClaudeAccount
    }

    /// 删除账户
    /// - Parameter account: 要删除的账户
    func removeAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

        let wasCurrentAccount = (currentAccountId == account.id)
        accounts.remove(at: index)
        NotificationManager.shared.resetNotificationStates(for: .claude, accountId: account.id)

        // 如果删除的是当前账户，切换到第一个账户
        if wasCurrentAccount {
            currentAccountId = accounts.first?.id
            // 发送账户变更通知
            postAccountChanged(provider: .claude)
        }

        Logger.settings.notice("删除账户: \(account.displayName)")
    }

    /// 切换到指定账户
    /// - Parameter account: 要切换到的账户
    func switchToAccount(_ account: Account) {
        guard account.id != currentAccountId else { return }
        guard accounts.contains(where: { $0.id == account.id }) else { return }

        currentAccountId = account.id
        Logger.settings.notice("切换到账户: \(account.displayName)")

        // 发送账户变更通知
        postAccountChanged(provider: .claude)
    }

    /// 更新账户信息
    /// - Parameters:
    ///   - account: 要更新的账户
    ///   - alias: 新的别名（可选）
    func updateAccount(_ account: Account, alias: String?) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].alias = alias
        let displayName = accounts[index].displayName
        Logger.settings.notice("更新账户别名: \(displayName)")
    }

    /// 静默更新当前 Claude 账户的 session-token（不触发 accountChanged 通知）
    /// 用于 OAuth refresh_token 轮换场景——只更新持久化数据，不触发重新拉取循环
    func silentlyUpdateCurrentClaudeSessionToken(_ token: String) {
        guard let id = currentAccountId,
              let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        guard accounts[index].sessionKey != token else { return }
        // Account 是 struct，下标赋值触发 accounts.didSet → saveAccounts()，自动持久化
        accounts[index].sessionKey = token
        Logger.settings.notice("Claude session-token 已静默更新（自动续期）")
    }

    // MARK: - Codex Account Management

    private func saveCodexAccounts() {
        // 在调用线程（主线程）快照，避免后台队列直接读取主线程持有的可变数组造成数据竞争
        let snapshot = codexAccounts
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.keychain.saveCodexAccounts(snapshot)
        }
    }

    /// 添加/更新 Codex 账户
    /// - Returns: (存储后的账户, 是否是新增的第一个 Codex 账户)
    ///   第二个返回值供调用方判断是否需要执行"首次接入 Codex"的一次性初始化逻辑
    @discardableResult
    func addCodexAccount(_ account: Account) -> (account: Account, wasFirstCodexAccount: Bool) {
        let stableId = account.organizationId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let existingIndex = codexAccounts.firstIndex { existing in
            if !stableId.isEmpty {
                let existingStableId = existing.organizationId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return existingStableId == stableId || existing.sessionKey == account.sessionKey
            }
            return existing.sessionKey == account.sessionKey
        }

        if let index = existingIndex {
            codexAccounts[index].sessionKey = account.sessionKey
            codexAccounts[index].organizationId = account.organizationId
            codexAccounts[index].organizationName = account.organizationName
            codexAccounts[index].provider = .codex
            if currentCodexAccountId == nil {
                currentCodexAccountId = codexAccounts[index].id
            }
            Logger.settings.notice("更新已存在的 Codex 账户: \(self.codexAccounts[index].displayName)")
            postAccountChanged(provider: .codex)
            return (codexAccounts[index], false)
        }

        let wasFirstCodexAccount = codexAccounts.isEmpty
        var storedAccount = account
        storedAccount.provider = .codex
        codexAccounts.append(storedAccount)
        if codexAccounts.count == 1 {
            currentCodexAccountId = storedAccount.id
        }
        Logger.settings.notice("添加 Codex 账户: \(storedAccount.displayName)")
        postAccountChanged(provider: .codex)
        return (storedAccount, wasFirstCodexAccount)
    }

    func removeCodexAccount(_ account: Account) {
        guard let index = codexAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        let wasCurrent = (currentCodexAccountId == account.id)
        codexAccounts.remove(at: index)
        NotificationManager.shared.resetNotificationStates(for: .codex, accountId: account.id)
        if wasCurrent {
            currentCodexAccountId = codexAccounts.first?.id
            postAccountChanged(provider: .codex)
        }
        Logger.settings.notice("删除 Codex 账户: \(account.displayName)")
    }

    func switchToCodexAccount(_ account: Account) {
        guard account.id != currentCodexAccountId else { return }
        guard codexAccounts.contains(where: { $0.id == account.id }) else { return }
        currentCodexAccountId = account.id
        Logger.settings.notice("切换到 Codex 账户: \(account.displayName)")
        postAccountChanged(provider: .codex)
    }

    func updateCodexAccount(_ account: Account, alias: String?) {
        guard let index = codexAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        codexAccounts[index].alias = alias
        Logger.settings.notice("更新 Codex 账户别名: \(self.codexAccounts[index].displayName)")
    }

    /// 静默更新当前 Codex 账户的 session-token（不触发 accountChanged 通知）
    /// 用于自动续期场景——只更新持久化数据，不触发重新拉取循环
    func silentlyUpdateCurrentCodexSessionToken(_ token: String) {
        guard let id = currentCodexAccountId,
              let index = codexAccounts.firstIndex(where: { $0.id == id }) else { return }
        guard codexAccounts[index].sessionKey != token else { return }
        // Account 是 struct，下标赋值触发 codexAccounts.didSet → saveCodexAccounts()，自动持久化
        codexAccounts[index].sessionKey = token
        Logger.settings.notice("Codex session-token 已静默更新（自动续期）")
    }

    // MARK: - Shared Helpers

    private func postAccountChanged(provider: ProviderType) {
        NotificationCenter.default.post(
            name: .accountChanged,
            object: nil,
            userInfo: [Notification.UserInfoKey.provider: provider.rawValue]
        )
    }

    /// 从 UserDefaults 加载组织列表（供 v2.0.x → v2.1.0 迁移时查找组织名称使用）
    /// - Parameter defaults: UserDefaults 实例
    /// - Returns: 组织列表，如果加载失败则返回空数组
    private static func loadOrganizations(from defaults: UserDefaults) -> [Organization] {
        guard let data = defaults.data(forKey: "cachedOrganizations") else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([Organization].self, from: data)) ?? []
    }
}
