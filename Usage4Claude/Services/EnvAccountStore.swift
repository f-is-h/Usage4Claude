//
//  EnvAccountStore.swift
//  Usage4Claude
//
//  Loads Claude accounts (session key + OAuth warm-up token) from the
//  WARMUP_ACCOUNTS variable in ~/.config/usage4claude/.env — the same JSON
//  format UsageResetter uses. Synced into UserSettings at every launch so the
//  .env file is the single source of truth for Claude credentials.
//

import Foundation
import CryptoKit
import OSLog

/// 一条 WARMUP_ACCOUNTS 里的账户记录（与 usageresetter 的 .env 格式一致）
struct EnvWarmupAccount: Decodable {
    let id: String
    let label: String?
    let provider: String?
    /// Claude OAuth setup-token（sk-ant-oat01-…），用于推理 warm-up
    let token: String?
    /// Claude 会话 Cookie（sk-ant-sid…），用于用量查询
    let sessionKey: String?
    let refreshToken: String?
}

enum EnvAccountStore {
    struct SyncResult {
        var accounts: [Account]
        var managedIds: Set<UUID>
        /// .env 是否成功读取并解析（否则保持原状，不删除任何账户）
        var envWasLoaded: Bool
    }

    /// 沙盒内 homeDirectoryForCurrentUser 指向容器，这里取真实的用户主目录
    static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// 凭证文件位置：~/.config/usage4claude/.env
    /// （读取权限来自 entitlements 的 home-relative-path.read-only 例外）
    static var envFileURL: URL {
        realHomeDirectory
            .appendingPathComponent(".config/usage4claude", isDirectory: true)
            .appendingPathComponent(".env")
    }

    /// 解析 .env 内容中的 WARMUP_ACCOUNTS，缺失或解析失败返回 nil
    static func parseWarmupAccounts(from content: String) -> [EnvWarmupAccount]? {
        guard let json = extractValue(named: "WARMUP_ACCOUNTS", from: content) else {
            Logger.settings.notice("EnvAccountStore: WARMUP_ACCOUNTS not found in .env")
            return nil
        }
        do {
            return try JSONDecoder().decode([EnvWarmupAccount].self, from: Data(json.utf8))
        } catch {
            Logger.settings.error("EnvAccountStore: WARMUP_ACCOUNTS JSON decode failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 提取 KEY='value' / KEY="value" / KEY=value；引号内的值可跨多行
    static func extractValue(named key: String, from content: String) -> String? {
        var searchRange = content.startIndex..<content.endIndex
        while let range = content.range(of: "\(key)=", range: searchRange) {
            // 只接受位于行首的赋值（允许前导空白或 `export `），跳过注释/子串命中
            let lineStart = content[..<range.lowerBound].lastIndex(of: "\n")
                .map { content.index(after: $0) } ?? content.startIndex
            let prefix = content[lineStart..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            if prefix.isEmpty || prefix == "export" {
                var rest = content[range.upperBound...]
                if let quote = rest.first, quote == "'" || quote == "\"" {
                    rest = rest.dropFirst()
                    guard let end = rest.firstIndex(of: quote) else { return nil }
                    return String(rest[..<end])
                }
                return String(rest.prefix(while: { $0 != "\n" })).trimmingCharacters(in: .whitespaces)
            }
            searchRange = range.upperBound..<content.endIndex
        }
        return nil
    }

    /// 由 .env 里的账户 id 派生稳定 UUID，保证每次启动同一账户拿到同一标识
    /// （menuBarAccountIds、profiles、通知状态等都按 UUID 引用账户）
    static func stableUUID(for envID: String) -> UUID {
        let digest = SHA256.hash(data: Data("usage4claude.env.\(envID)".utf8))
        var bytes = [UInt8](digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5 风格
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Kimi for Coding：KIMI_KEY 变量（或 WARMUP_ACCOUNTS 里 provider=kimi 的条目）
    /// 合成为一个 Claude 形态的账户 —— sessionKey/oauthToken 都是 sk-kimi- key，
    /// 用量由 KimiAPIService 拉取，organizationId 固定为 "kimi"（无需解析组织）。
    private static func kimiEnvAccounts(from content: String, envAccounts: [EnvWarmupAccount]) -> [EnvWarmupAccount] {
        var result = envAccounts.filter { ($0.provider ?? "") == "kimi" }
        if let key = extractValue(named: "KIMI_KEY", from: content),
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !result.contains(where: { $0.token == key || $0.sessionKey == key }) {
            result.append(EnvWarmupAccount(
                id: "kimi",
                label: "Kimi",
                provider: "kimi",
                token: key,
                sessionKey: key,
                refreshToken: nil
            ))
        }
        return result
    }

    /// 将 .env 中 provider=anthropic 的账户合并进现有账户列表：
    /// - 已存在（同派生 UUID）→ 更新 sessionKey / oauthToken / 别名
    /// - 不存在 → 新建（organizationId 留空，启动后由 resolveMissingOrganizationIds 补齐）
    /// - 之前由 .env 管理但已从 .env 移除 → 删除
    /// 手动添加的账户不受影响。
    static func syncClaudeAccounts(into existing: [Account], previouslyManaged: Set<UUID>) -> SyncResult {
        guard let content = try? String(contentsOf: envFileURL, encoding: .utf8) else {
            Logger.settings.notice("EnvAccountStore: no .env at \(envFileURL.path, privacy: .public)")
            return SyncResult(accounts: existing, managedIds: previouslyManaged, envWasLoaded: false)
        }
        let envAccounts = parseWarmupAccounts(from: content) ?? []
        let claudeEntries = envAccounts.filter { ($0.provider ?? "anthropic") == "anthropic" }
        let kimiEntries = kimiEnvAccounts(from: content, envAccounts: envAccounts)
        guard !claudeEntries.isEmpty || !kimiEntries.isEmpty else {
            return SyncResult(accounts: existing, managedIds: previouslyManaged, envWasLoaded: false)
        }

        var accounts = existing
        var managed = Set<UUID>()

        func upsert(_ env: EnvWarmupAccount, organizationId: String) {
            let uuid = stableUUID(for: env.id)
            managed.insert(uuid)
            let sessionKey = env.sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let token = env.token?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = env.label?.isEmpty == false ? env.label : env.id

            if let index = accounts.firstIndex(where: { $0.id == uuid }) {
                accounts[index].sessionKey = sessionKey
                accounts[index].oauthToken = token
                accounts[index].alias = label
                if !organizationId.isEmpty {
                    accounts[index].organizationId = organizationId
                }
            } else {
                accounts.append(Account(
                    id: uuid,
                    sessionKey: sessionKey,
                    organizationId: organizationId,
                    organizationName: label ?? env.id,
                    alias: label,
                    oauthToken: token,
                    lastWarmedAt: nil,
                    createdAt: Date(),
                    provider: .claude
                ))
            }
        }

        for env in claudeEntries {
            upsert(env, organizationId: "")  // 启动后自动解析
        }
        for env in kimiEntries {
            upsert(env, organizationId: "kimi")  // Kimi 无组织概念，固定占位
        }

        let removed = previouslyManaged.subtracting(managed)
        if !removed.isEmpty {
            accounts.removeAll { removed.contains($0.id) }
        }

        Logger.settings.notice("EnvAccountStore: synced \(managed.count) account(s) from .env (\(kimiEntries.count) Kimi)")
        return SyncResult(accounts: accounts, managedIds: managed, envWasLoaded: true)
    }
}
