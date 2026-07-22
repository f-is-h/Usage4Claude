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
    var alias: String?
    /// Claude setup-token used only for inference warm-ups (stored with the account in Keychain).
    var oauthToken: String?
    /// Local record of a successful warm-up, used when this account has no cached usage response.
    var lastWarmedAt: Date?
    let createdAt: Date
    var provider: ProviderType

    var displayName: String {
        if let alias = alias, !alias.isEmpty {
            return alias
        }
        return organizationName
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id, sessionKey, organizationId, organizationName, alias, oauthToken, lastWarmedAt, createdAt, provider
    }

    // MARK: - Codable

    // 自定义解码：旧版 JSON 不含 provider 字段时默认为 .claude，确保旧账号数据零迁移
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionKey = try container.decode(String.self, forKey: .sessionKey)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        oauthToken = try container.decodeIfPresent(String.self, forKey: .oauthToken)
        lastWarmedAt = try container.decodeIfPresent(Date.self, forKey: .lastWarmedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        provider = try container.decodeIfPresent(ProviderType.self, forKey: .provider) ?? .claude
    }

    // MARK: - Initialization

    init(
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String? = nil,
        oauthToken: String? = nil,
        lastWarmedAt: Date? = nil,
        provider: ProviderType = .claude
    ) {
        self.id = UUID()
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.oauthToken = oauthToken
        self.lastWarmedAt = lastWarmedAt
        self.createdAt = Date()
        self.provider = provider
    }

    init(
        id: UUID,
        sessionKey: String,
        organizationId: String,
        organizationName: String,
        alias: String?,
        oauthToken: String? = nil,
        lastWarmedAt: Date? = nil,
        createdAt: Date,
        provider: ProviderType = .claude
    ) {
        self.id = id
        self.sessionKey = sessionKey
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.alias = alias
        self.oauthToken = oauthToken
        self.lastWarmedAt = lastWarmedAt
        self.createdAt = createdAt
        self.provider = provider
    }

    // MARK: - Equatable

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }

    /// A warm-up anchors a five-hour window. This fallback covers accounts whose usage is not cached.
    var hasLocallyActiveWarmupWindow: Bool {
        guard let lastWarmedAt else { return false }
        return lastWarmedAt.addingTimeInterval(5 * 60 * 60) > Date()
    }
}
