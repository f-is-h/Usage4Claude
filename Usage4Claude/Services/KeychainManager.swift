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
    /// 保存账户列表到 Keychain（Release 模式）
    /// - Parameter accounts: 账户列表
    /// - Returns: 是否保存成功
    @discardableResult
    func saveAccounts(_ accounts: [Account]) -> Bool {
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(accounts),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.keychain.error("账户列表编码失败")
            return false
        }
        let result = save(key: "accounts", value: jsonString)
        if result {
            Logger.keychain.debug("保存 \(accounts.count) 个账户到 Keychain")
        }
        return result
    }

    /// 从 Keychain 读取账户列表（Release 模式）
    /// - Returns: 账户列表，如果不存在返回 nil
    func loadAccounts() -> [Account]? {
        guard let jsonString = load(key: "accounts"),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let accounts = try? decoder.decode([Account].self, from: jsonData) else {
            Logger.keychain.error("账户列表解码失败")
            return nil
        }
        Logger.keychain.debug("读取 \(accounts.count) 个账户")
        return accounts
    }

    /// 从 Keychain 删除账户列表（Release 模式）
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteAccounts() -> Bool {
        return delete(key: "accounts")
    }
    #endif

    #if !DEBUG
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
