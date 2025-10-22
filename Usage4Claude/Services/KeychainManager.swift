//
//  KeychainManager.swift
//  Usage4Claude
//
//  Created by f-is-h on 2025-10-19.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation
import Security

/// 管理 Keychain 存储的类
/// 用于安全存储敏感信息（如 Organization ID 和 Session Key）
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {
        // 动态获取 Bundle ID，如果获取失败则使用默认值
        if let bundleID = Bundle.main.bundleIdentifier {
            service = bundleID
        }
    }
    
    // MARK: - Keychain 配置
    
    /// Keychain 服务标识符（自动从 Bundle 获取）
    private var service: String = "xyz.fi5h.Usage4Claude"  // 默认值，会在 init 中更新
    
    // MARK: - 保存方法
    
    /// 保存 Organization ID 到 Keychain
    /// - Parameter value: Organization ID 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveOrganizationId(_ value: String) -> Bool {
        return save(key: "organizationId", value: value)
    }
    
    /// 保存 Session Key 到 Keychain
    /// - Parameter value: Session Key 值
    /// - Returns: 是否保存成功
    @discardableResult
    func saveSessionKey(_ value: String) -> Bool {
        return save(key: "sessionKey", value: value)
    }
    
    // MARK: - 读取方法
    
    /// 从 Keychain 读取 Organization ID
    /// - Returns: Organization ID 值，如果不存在返回 nil
    func loadOrganizationId() -> String? {
        return load(key: "organizationId")
    }
    
    /// 从 Keychain 读取 Session Key
    /// - Returns: Session Key 值，如果不存在返回 nil
    func loadSessionKey() -> String? {
        return load(key: "sessionKey")
    }
    
    // MARK: - 删除方法
    
    /// 从 Keychain 删除 Organization ID
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteOrganizationId() -> Bool {
        return delete(key: "organizationId")
    }
    
    /// 从 Keychain 删除 Session Key
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteSessionKey() -> Bool {
        return delete(key: "sessionKey")
    }
    
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
    
    // MARK: - 通用 Keychain 操作
    
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
            print("❌ Keychain 保存失败: \(key), 状态码: \(status)")
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
            print("❌ Keychain 读取失败: \(key), 状态码: \(status)")
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
            print("❌ Keychain 删除失败: \(key), 状态码: \(status)")
            return false
        }
    }
}
