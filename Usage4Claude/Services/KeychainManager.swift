//
//  KeychainManager.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-19.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Security
import OSLog

/// 凭据存储后端协议：Debug 用 UserDefaults（便于开发测试、不触发系统弹窗），
/// Release 用 Keychain（安全存储）。两种实现各自独立，`KeychainManager` 只在
/// 选择实现时区分 `#if DEBUG`，业务方法本身不再重复。
protocol CredentialStorage {
    func save(key: String, value: String) -> Bool
    func load(key: String) -> String?
    func delete(key: String) -> Bool
}

/// Debug 模式存储：明文写入 UserDefaults
/// - Warning: 未加密，勿在共享机器上用真实账号跑 Debug 构建
private struct UserDefaultsCredentialStorage: CredentialStorage {
    private let keyPrefix = "DEBUG_"
    private let defaults = UserDefaults.standard

    func save(key: String, value: String) -> Bool {
        defaults.set(value, forKey: keyPrefix + key)
        return true
    }

    func load(key: String) -> String? {
        defaults.string(forKey: keyPrefix + key)
    }

    func delete(key: String) -> Bool {
        defaults.removeObject(forKey: keyPrefix + key)
        return true
    }
}

/// Release 模式存储：写入系统 Keychain
private struct KeychainCredentialStorage: CredentialStorage {
    let service: String

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // 先尝试删除已存在的项，再添加新项
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            return true
        } else {
            Logger.keychain.error("Keychain 保存失败: \(key), 状态码: \(status)")
            return false
        }
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        } else if status != errSecItemNotFound {
            Logger.keychain.error("Keychain 读取失败: \(key), 状态码: \(status)")
        }
        return nil
    }

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            Logger.keychain.error("Keychain 删除失败: \(key), 状态码: \(status)")
            return false
        }
    }
}

/// 管理认证凭据存储的类
/// 用于安全存储敏感信息（如 Organization ID 和 Session Key）
/// Debug 模式：使用 UserDefaults（便于开发测试，不弹窗）
/// Release 模式：使用 Keychain（安全存储）
class KeychainManager {
    static let shared = KeychainManager()

    private let storage: CredentialStorage

    private init() {
        #if DEBUG
        storage = UserDefaultsCredentialStorage()
        #else
        // 动态获取 Bundle ID，如果获取失败则使用默认值
        storage = KeychainCredentialStorage(service: Bundle.main.bundleIdentifier ?? "xyz.fi5h.Usage4Claude")
        #endif
    }

    // MARK: - Organization ID / Session Key

    @discardableResult
    func saveOrganizationId(_ value: String) -> Bool {
        storage.save(key: "organizationId", value: value)
    }

    func loadOrganizationId() -> String? {
        storage.load(key: "organizationId")
    }

    @discardableResult
    func deleteOrganizationId() -> Bool {
        storage.delete(key: "organizationId")
    }

    @discardableResult
    func saveSessionKey(_ value: String) -> Bool {
        storage.save(key: "sessionKey", value: value)
    }

    func loadSessionKey() -> String? {
        storage.load(key: "sessionKey")
    }

    @discardableResult
    func deleteSessionKey() -> Bool {
        storage.delete(key: "sessionKey")
    }

    /// 删除所有认证信息
    /// - Returns: 是否全部删除成功
    @discardableResult
    func deleteAll() -> Bool {
        let result1 = deleteOrganizationId()
        let result2 = deleteSessionKey()
        return result1 && result2
    }

    /// 删除所有凭证信息（deleteAll 的别名，更符合业务语义）
    /// - Returns: 是否全部删除成功
    @discardableResult
    func deleteCredentials() -> Bool {
        deleteAll()
    }

    // MARK: - 账户列表存储（v2.1.0 多账户支持）

    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        saveAccountsList(accounts, key: "accounts")
    }

    func loadAccounts() -> [Account]? {
        loadAccountsList(key: "accounts")
    }

    @discardableResult
    func deleteAccounts() -> Bool {
        storage.delete(key: "accounts")
    }

    // MARK: - Codex 账户列表存储

    @discardableResult
    func saveCodexAccounts(_ accounts: [Account]) -> Bool {
        saveAccountsList(accounts, key: "accounts_codex")
    }

    func loadCodexAccounts() -> [Account]? {
        loadAccountsList(key: "accounts_codex")
    }

    @discardableResult
    func deleteCodexAccounts() -> Bool {
        storage.delete(key: "accounts_codex")
    }

    // MARK: - Grok 账户列表存储

    @discardableResult
    func saveGrokAccounts(_ accounts: [Account]) -> Bool {
        saveAccountsList(accounts, key: "accounts_grok")
    }

    func loadGrokAccounts() -> [Account]? {
        loadAccountsList(key: "accounts_grok")
    }

    @discardableResult
    func deleteGrokAccounts() -> Bool {
        storage.delete(key: "accounts_grok")
    }

    // MARK: - 账户列表的 JSON 编解码封装

    @discardableResult
    private func saveAccountsList(_ accounts: [Account], key: String) -> Bool {
        guard let jsonData = try? JSONEncoder().encode(accounts),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.keychain.error("账户列表编码失败 (\(key))")
            return false
        }
        let result = storage.save(key: key, value: jsonString)
        if result {
            Logger.keychain.debug("保存 \(accounts.count) 个账户 (\(key))")
        }
        return result
    }

    private func loadAccountsList(key: String) -> [Account]? {
        guard let jsonString = storage.load(key: key),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        guard let accounts = try? JSONDecoder().decode([Account].self, from: jsonData) else {
            Logger.keychain.error("账户列表解码失败 (\(key))")
            return nil
        }
        Logger.keychain.debug("读取 \(accounts.count) 个账户 (\(key))")
        return accounts
    }
}
