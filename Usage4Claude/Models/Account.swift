//
//  Account.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-02-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

/// 账户数据模型
/// 存储用户的 Claude 账户信息，包括认证凭据和显示名称
/// 一个账户对应一组 Session Key 和 Organization ID
struct Account: Codable, Identifiable, Equatable {
    /// 唯一标识符
    let id: UUID
    /// Claude Session Key
    var sessionKey: String
    /// Organization ID（从 API 获取）
    var organizationId: String
    /// API 返回的组织名称（如 "xxx's Organization"）
    var organizationName: String
    /// 用户自定义别名（可选）
    var alias: String?
    /// 创建时间
    let createdAt: Date

    /// 显示名称：优先使用别名，否则使用 API 返回的名称
    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return alias
        }
        return organizationName
    }

    // MARK: - Initialization

    /// 创建新账户
    /// - Parameters:
    ///   - sessionKey: Claude Session Key
    ///   - organizationId: Organization ID
    ///   - organizationName: 组织名称
    ///   - alias: 用户自定义别名（可选）
    init(
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String? = nil
    ) {
        self.id = UUID()
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.createdAt = Date()
    }

    /// 用于从存储中解码的完整初始化方法
    init(
        id: UUID,
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String?,
        createdAt: Date
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.createdAt = createdAt
    }

    // MARK: - Equatable

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
}
