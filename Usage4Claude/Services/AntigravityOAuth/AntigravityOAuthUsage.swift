import Foundation

/// 每个账户一个 OAuthTokenCache：access_token 缓存 + 同一 refresh_token 的单飞刷新（CLAUDE.md 约定），
/// 不同账户互不阻塞；同一账户的并发拉取共享一次结果。
actor AntigravityOAuthUsage {
    static let shared = AntigravityOAuthUsage()
    /// TOS 不支持、账户身份不符等永久性失败：刷新 token 也无法恢复，不再花一次刷新重试
    private struct PermanentFailure: Error {}
    private var tokenCaches: [UUID: OAuthTokenCache] = [:]
    private var tasks: [UUID: Task<AntigravityUsageData, Error>] = [:]

    func fetch(_ account: AntigravityAccount) async throws -> AntigravityUsageData {
        if let task = tasks[account.id] { return try await task.value }
        let cache = tokenCache(for: account.id)
        let task = Task {
            do {
                do { return try await Self.load(account, cache: cache) }
                catch AntigravityError.notLoggedIn {
                    // 401/403：缓存的 access_token 可能已被吊销，清掉后强制刷新并重新发现项目一次
                    await cache.clear()
                    let current = await MainActor.run { AntigravityAccountStore.shared.accounts.first { $0.id == account.id } }
                    guard let current else { throw AntigravityError.notLoggedIn }
                    return try await Self.load(current, cache: cache, forceRefresh: true)
                }
            } catch is PermanentFailure { throw AntigravityError.notLoggedIn }
        }
        tasks[account.id] = task
        defer { tasks[account.id] = nil }
        return try await task.value
    }

    private func tokenCache(for id: UUID) -> OAuthTokenCache {
        if let cache = tokenCaches[id] { return cache }
        let cache = OAuthTokenCache()
        tokenCaches[id] = cache
        return cache
    }

    private static func load(_ account: AntigravityAccount, cache: OAuthTokenCache, forceRefresh: Bool = false) async throws -> AntigravityUsageData {
        guard var credentials = account.credentials else { throw AntigravityError.notLoggedIn }
        // 已保存的 access_token 仍有效时直接放进缓存，重启后不必为此花掉一次刷新
        if !forceRefresh, credentials.expiresAt > Date().addingTimeInterval(60),
           await cache.validCachedToken(refreshToken: credentials.refreshToken) == nil {
            await cache.store(OAuthTokenCache.Tokens(accessToken: credentials.accessToken,
                refreshToken: credentials.refreshToken, expiresAt: credentials.expiresAt))
        }
        let client = credentials
        let access = try await cache.accessToken(refreshToken: credentials.refreshToken, margin: 60) { token in
            let refreshed = try await AntigravityOAuthService.token(["grant_type": "refresh_token",
                "refresh_token": token, "client_id": client.clientID,
                "client_secret": client.clientSecret], previous: client)
            try await MainActor.run {
                try AntigravityAccountStore.shared.updateCredentials(refreshed, accountID: account.id, replacing: token)
            }
            return OAuthTokenCache.Tokens(accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken, expiresAt: refreshed.expiresAt)
        }
        if access != credentials.accessToken {
            let stored = await MainActor.run { AntigravityAccountStore.shared.accounts.first { $0.id == account.id }?.credentials }
            if let stored, stored.accessToken == access { credentials = stored } else { credentials.accessToken = access }
        }

        // 项目 ID 发现一次后保存，之后每轮只发一次配额请求；强制刷新时重新发现
        var project = forceRefresh ? nil : credentials.projectID
        if project == nil {
            let setup = try await post("https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
                body: ["metadata": ["ideType": "ANTIGRAVITY", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"]],
                access: credentials.accessToken)
            project = setup["cloudaicompanionProject"] as? String ??
                (setup["cloudaicompanionProject"] as? [String: Any])?["id"] as? String ?? credentials.projectID
            if project == nil, setup["currentTier"] == nil,
               let tiers = setup["ineligibleTiers"] as? [[String: Any]],
               tiers.contains(where: { $0["reasonCode"] as? String == "GOOGLE_TOS_NOT_SUPPORTED_BY_CLIENT" }) {
                throw PermanentFailure()
            }
            if let project, project != credentials.projectID {
                credentials.projectID = project
                let updated = credentials
                try? await MainActor.run {
                    try AntigravityAccountStore.shared.updateCredentials(updated, accountID: account.id, replacing: updated.refreshToken)
                }
            }
        }
        do {
            let summary = try await post("https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
                body: project.map { ["project": $0] } ?? [:], access: credentials.accessToken)
            return try AntigravityRemoteQuotaParser.parse(summary)
        } catch {
            if let failure = error as? AntigravityError {
                switch failure {
                case .malformedOutput: break
                case .commandFailed(let message) where ["HTTP 404", "HTTP 501"].contains(message): break
                default: throw error
                }
            } else if !(error is AntigravityParseError) { throw error }
            // A valid account with an unsupported quota shape may use the official report.
            // 传入的 access_token 刚从缓存取出且至少还有 60 秒，agy 通常不需要自行刷新
            let (result, effective) = try await AntigravityAPIService.shared.fetchScoped(credentials)
            if effective.accessToken != credentials.accessToken || effective.refreshToken != credentials.refreshToken {
                let verified = try await AntigravityOAuthService.identity(effective.accessToken)
                guard verified.subject == account.subject else { throw PermanentFailure() }
                try await MainActor.run {
                    try AntigravityAccountStore.shared.updateCredentials(effective, accountID: account.id, replacing: credentials.refreshToken)
                }
                await cache.store(OAuthTokenCache.Tokens(accessToken: effective.accessToken,
                    refreshToken: effective.refreshToken, expiresAt: effective.expiresAt))
            }
            return result
        }
    }

    private static func post(_ endpoint: String, body: [String: Any], access: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/hub/2.9.1 darwin/arm64", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await AntigravityOAuthService.json(request)
    }
}
