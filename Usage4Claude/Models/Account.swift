//
//  Account.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-02-05.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import Foundation

struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var sessionKey: String
    var organizationId: String
    var organizationName: String
    /// Stable account identity shown outside the menu bar when it is available.
    var email: String?
    var alias: String?
    let createdAt: Date
    var provider: ProviderType

    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return alias
        }
        return organizationName
    }

    /// A duplicate-safe identity for settings and detail views.
    var presentationLabel: String {
        let identity = accountIdentity
        guard identity != displayName else { return displayName }
        return "\(displayName) — \(identity)"
    }

    /// Uses the verified email when available, then preserves legacy organization labels.
    var accountIdentity: String {
        if let email, !email.isEmpty {
            return email
        }
        return organizationName
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id, sessionKey, organizationId, organizationName, email, alias, createdAt, provider
    }

    // MARK: - Codable

    // 自定义解码：旧版 JSON 不含 provider 字段时默认为 .claude，确保旧账号数据零迁移
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionKey = try container.decode(String.self, forKey: .sessionKey)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        provider = try container.decodeIfPresent(ProviderType.self, forKey: .provider) ?? .claude
    }

    // MARK: - Initialization

    init(
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        email: String? = nil,
        alias: String? = nil,
        provider: ProviderType = .claude
    ) {
        self.id = UUID()
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.email = email
        self.alias = alias
        self.createdAt = Date()
        self.provider = provider
    }

    init(
        id: UUID,
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        email: String? = nil,
        alias: String?,
        createdAt: Date,
        provider: ProviderType = .claude
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.email = email
        self.alias = alias
        self.createdAt = createdAt
        self.provider = provider
    }

    // MARK: - Equatable

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }
}
