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

/// 管理 Keychain 存储的类
/// 用于安全存储敏感信息（如 Organization ID 和 Session Key）
/// Debug 模式：使用 UserDefaults（便于开发测试，不弹窗）
/// Release 模式：使用 Keychain（安全存储）
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {
        #if !DEBUG
        // 动态获取 Bundle ID，如果获取失败则使用默认值
        if let bundleID = Bundle.main.bundleIdentifier {
            service = bundleID
        }
        #endif
    }
    
    // MARK: - Keychain 配置
    
    #if DEBUG
    /// Debug 模式：UserDefaults key 前缀
    private let debugKeyPrefix = "DEBUG_"
    #else
    /// Keychain 服务标识符（自动从 Bundle 获取）
    private var service: String = "xyz.fi5h.Usage4Claude"  // 默认值，会在 init 中更新
    #endif
    
    // MARK: - 保存方法
    
    #if DEBUG
    /// 保存 Organization ID 到 UserDefaults（Debug 模式）
    /// - Parameter value: Organization ID 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveOrganizationId(_ value: String) -> Bool {
        UserDefaults.standard.set(value, forKey: debugKeyPrefix + "organizationId")
        Logger.keychain.debug("[Debug] 保存 Organization ID 到 UserDefaults")
        return true
    }

    /// 保存 Session Key 到 UserDefaults（Debug 模式）
    /// - Parameter value: Session Key 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveSessionKey(_ value: String) -> Bool {
        UserDefaults.standard.set(value, forKey: debugKeyPrefix + "sessionKey")
        Logger.keychain.debug("[Debug] 保存 Session Key 到 UserDefaults")
        return true
    }
    #else
    /// 保存 Organization ID 到 Keychain（Release 模式）
    /// - Parameter value: Organization ID 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveOrganizationId(_ value: String) -> Bool {
        return save(key: "organizationId", value: value)
    }
    
    /// 保存 Session Key 到 Keychain（Release 模式）
    /// - Parameter value: Session Key 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveSessionKey(_ value: String) -> Bool {
        return save(key: "sessionKey", value: value)
    }
    #endif
    
    // MARK: - 读取方法
    
    #if DEBUG
    /// 从 UserDefaults 读取 Organization ID（Debug 模式）
    /// - Returns: Organization ID 值，如果不存在返回 nil
    func loadOrganizationId() -> String? {
        let value = UserDefaults.standard.string(forKey: debugKeyPrefix + "organizationId")
        Logger.keychain.debug("[Debug] 读取 Organization ID: \(value ?? "nil")")
        return value
    }

    /// 从 UserDefaults 读取 Session Key（Debug 模式）
    /// - Returns: Session Key 值，如果不存在返回 nil
    func loadSessionKey() -> String? {
        let value = UserDefaults.standard.string(forKey: debugKeyPrefix + "sessionKey")
        Logger.keychain.debug("[Debug] 读取 Session Key: \(value != nil ? "存在" : "nil")")
        return value
    }
    #else
    /// 从 Keychain 读取 Organization ID（Release 模式）
    /// - Returns: Organization ID 值，如果不存在返回 nil
    func loadOrganizationId() -> String? {
        return load(key: "organizationId")
    }
    
    /// 从 Keychain 读取 Session Key（Release 模式）
    /// - Returns: Session Key 值，如果不存在返回 nil
    func loadSessionKey() -> String? {
        return load(key: "sessionKey")
    }
    #endif
    
    // MARK: - 删除方法
    
    #if DEBUG
    /// 从 UserDefaults 删除 Organization ID（Debug 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteOrganizationId() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "organizationId")
        Logger.keychain.debug("[Debug] 删除 Organization ID")
        return true
    }

    /// 从 UserDefaults 删除 Session Key（Debug 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteSessionKey() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "sessionKey")
        Logger.keychain.debug("[Debug] 删除 Session Key")
        return true
    }
    #else
    /// 从 Keychain 删除 Organization ID（Release 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteOrganizationId() -> Bool {
        return delete(key: "organizationId")
    }
    
    /// 从 Keychain 删除 Session Key（Release 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteSessionKey() -> Bool {
        return delete(key: "sessionKey")
    }
    #endif
    
    /// 删除所有认证信息
    /// - Returns: 是否全部删除成功
    @discardableResult
    func deleteAll() -> Bool {
        let result1 = deleteOrganizationId()
        let result2 = deleteSessionKey()
        return result1 && result2
    }
    
    /// 删除所有凭证信息（deleteAll的别名，更符合业务语义）
    /// - Returns: 是否全部删除成功
    @discardableResult
    func deleteCredentials() -> Bool {
        return deleteAll()
    }

    // MARK: - 账户列表存储（v2.1.0 多账户支持）

    #if DEBUG
    /// 保存账户列表到 UserDefaults（Debug 模式）
    /// - Parameter accounts: 账户列表
    /// - Returns: 是否保存成功
    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accounts) else {
            Logger.keychain.error("[Debug] 账户列表编码失败")
            return false
        }
        UserDefaults.standard.set(data, forKey: debugKeyPrefix + "accounts")
        Logger.keychain.debug("[Debug] 保存 \(accounts.count) 个账户到 UserDefaults")
        return true
    }

    /// 从 UserDefaults 读取账户列表（Debug 模式）
    /// - Returns: 账户列表，如果不存在返回 nil
    func loadAccounts() -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: debugKeyPrefix + "accounts") else {
            Logger.keychain.debug("[Debug] 账户列表不存在")
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: data) else {
            Logger.keychain.error("[Debug] 账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("[Debug] 读取 \(accounts.count) 个账户")
        return accounts
    }

    /// 从 UserDefaults 删除账户列表（Debug 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccounts() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "accounts")
        Logger.keychain.debug("[Debug] 删除账户列表")
        return true
    }
    #else
    /// 保存账户列表到本地文件（Release 模式）
    /// 不再使用 Keychain：重新签名的本地构建每次读 Keychain 都会弹出
    /// “输入登录钥匙串密码”对话框。凭证本身已在 ~/.config/usage4claude/.env 中
    /// 以明文管理，文件存储与其安全级别一致。
    /// - Parameter accounts: 账户列表
    /// - Returns: 是否保存成功
    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        return saveAccountsFile(accounts, filename: Self.accountsFilename, label: "账户")
    }

    /// 从本地文件读取账户列表（Release 模式），首次运行时自动从旧 Keychain 迁移
    /// - Returns: 账户列表，如果不存在返回 nil
    func loadAccounts() -> [Account]? {
        return loadAccountsFile(
            filename: Self.accountsFilename,
            legacyKeychainKey: "accounts",
            migrationFlag: "accountsFileStoreMigrated",
            label: "账户"
        )
    }

    /// 删除账户列表（Release 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccounts() -> Bool {
        _ = delete(key: "accounts")  // 清理旧 Keychain 残留（删除不会弹窗）
        return deleteAccountsFile(filename: Self.accountsFilename)
    }
    #endif

    // MARK: - Codex 账户列表存储

    #if DEBUG
    @discardableResult
    func saveCodexAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accounts) else {
            Logger.keychain.error("[Debug] Codex 账户列表编码失败")
            return false
        }
        UserDefaults.standard.set(data, forKey: debugKeyPrefix + "accounts_codex")
        Logger.keychain.debug("[Debug] 保存 \(accounts.count) 个 Codex 账户到 UserDefaults")
        return true
    }

    func loadCodexAccounts() -> [Account]? {
        guard let data = UserDefaults.standard.data(forKey: debugKeyPrefix + "accounts_codex") else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: data) else {
            Logger.keychain.error("[Debug] Codex 账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("[Debug] 读取 \(accounts.count) 个 Codex 账户")
        return accounts
    }

    @discardableResult
    func deleteCodexAccounts() -> Bool {
        UserDefaults.standard.removeObject(forKey: debugKeyPrefix + "accounts_codex")
        Logger.keychain.debug("[Debug] 删除 Codex 账户列表")
        return true
    }
    #else
    @discardableResult
    func saveCodexAccounts(_ accounts: [Account]) -> Bool {
        return saveAccountsFile(accounts, filename: Self.codexAccountsFilename, label: "Codex 账户")
    }

    func loadCodexAccounts() -> [Account]? {
        return loadAccountsFile(
            filename: Self.codexAccountsFilename,
            legacyKeychainKey: "accounts_codex",
            migrationFlag: "codexAccountsFileStoreMigrated",
            label: "Codex 账户"
        )
    }

    @discardableResult
    func deleteCodexAccounts() -> Bool {
        _ = delete(key: "accounts_codex")
        return deleteAccountsFile(filename: Self.codexAccountsFilename)
    }
    #endif

    #if !DEBUG
    // MARK: - 文件账户存储（仅 Release 模式）

    private static let accountsFilename = "accounts.json"
    private static let codexAccountsFilename = "accounts_codex.json"

    /// 账户存储目录：Application Support/Usage4Claude（沙盒下位于应用容器内）
    private var accountsStoreDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("Usage4Claude", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func accountsFileURL(_ filename: String) -> URL? {
        accountsStoreDirectory?.appendingPathComponent(filename)
    }

    private func saveAccountsFile(_ accounts: [Account], filename: String, label: String) -> Bool {
        guard let url = accountsFileURL(filename),
              let data = try? JSONEncoder().encode(accounts) else {
            Logger.keychain.error("\(label)列表编码失败")
            return false
        }
        do {
            try data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            Logger.keychain.debug("保存 \(accounts.count) 个\(label)到文件")
            return true
        } catch {
            Logger.keychain.error("\(label)列表写入失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 读取账户文件；文件缺失时一次性尝试从旧 Keychain 迁移（仅第一次，之后不再触碰 Keychain）
    private func loadAccountsFile(
        filename: String,
        legacyKeychainKey: String,
        migrationFlag: String,
        label: String
    ) -> [Account]? {
        if let url = accountsFileURL(filename),
           let data = try? Data(contentsOf: url) {
            guard let accounts = try? JSONDecoder().decode([Account].self, from: data) else {
                Logger.keychain.error("\(label)列表解码失败")
                return nil
            }
            Logger.keychain.debug("读取 \(accounts.count) 个\(label)")
            return accounts
        }

        // 一次性 Keychain → 文件迁移（这次读取可能弹一次钥匙串密码框，之后永远不会）
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationFlag) else { return nil }
        defaults.set(true, forKey: migrationFlag)

        guard let jsonString = load(key: legacyKeychainKey),
              let jsonData = jsonString.data(using: .utf8),
              let accounts = try? JSONDecoder().decode([Account].self, from: jsonData) else {
            return nil
        }
        Logger.keychain.notice("从 Keychain 迁移 \(accounts.count) 个\(label)到文件存储")
        _ = saveAccountsFile(accounts, filename: filename, label: label)
        return accounts
    }

    private func deleteAccountsFile(filename: String) -> Bool {
        guard let url = accountsFileURL(filename) else { return false }
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            Logger.keychain.error("账户文件删除失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 通用 Keychain 操作（仅 Release 模式）

    /// 保存数据到 Keychain
    /// - Parameters:
    ///   - key: 键名
    ///   - value: 要保存的值
    /// - Returns: 是否保存成功
    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // 构建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 先尝试删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            Logger.keychain.error("Keychain 保存失败: \(key), 状态码: \(status)")
            return false
        }
    }
    
    /// 从 Keychain 读取数据
    /// - Parameter key: 键名
    /// - Returns: 读取的值，如果不存在返回 nil
    private func load(key: String) -> String? {
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
    
    /// 从 Keychain 删除数据
    /// - Parameter key: 键名
    /// - Returns: 是否删除成功
    private func delete(key: String) -> Bool {
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
    #endif
}
