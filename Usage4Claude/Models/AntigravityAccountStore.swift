import Foundation
import Combine

final class AntigravityAccountStore: ObservableObject {
    static let shared = AntigravityAccountStore()
    @Published private(set) var accounts: [AntigravityAccount] = []
    @Published private(set) var selectedID: UUID?
    private(set) var selectionRevision = 0
    @Published var storageError: String?
    private var canWrite = false
    private let storage = AntigravitySecureStorage()
    private let defaults = UserDefaults.standard
    var current: AntigravityAccount? { accounts.first { $0.id == selectedID } ?? accounts.first }

    private init() {
        selectedID = defaults.string(forKey: "antigravitySelectedAccount").flatMap(UUID.init(uuidString:))
        do {
            accounts = try storage.load(); canWrite = true
        } catch AntigravitySecureStorage.Failure.corrupt {
            // 读不出来的数据无从恢复：允许覆盖，否则之后任何连接/改名都无法保存
            canWrite = true
            storageError = NSLocalizedString("antigravity.storage_failed", comment: "")
        } catch {
            // Keychain 拒绝访问时本地 agy 账户不含密钥，仍在内存里保留它，监控不因此中断
            storageError = NSLocalizedString("antigravity.storage_failed", comment: "")
            if shouldOfferLocalAccount { accounts = [localAccount] }
            return
        }
        if !defaults.bool(forKey: "antigravityAccountsMigrated") {
            if shouldOfferLocalAccount {
                let local = localAccount
                do {
                    try storage.save(accounts + [local]); accounts.append(local)
                    defaults.set(true, forKey: "antigravityAccountsMigrated")
                } catch { storageError = NSLocalizedString("antigravity.storage_failed", comment: "") }
            } else { defaults.set(true, forKey: "antigravityAccountsMigrated") }
        }
    }

    /// 只有装了 agy 且用户没有关掉过 Antigravity 时才自动加入本地账户，新装用户不会多出一个空账户
    private var shouldOfferLocalAccount: Bool {
        defaults.object(forKey: "antigravityEnabled") as? Bool != false && AntigravityAPIService.locateCLI() != nil
    }

    private var localAccount: AntigravityAccount {
        AntigravityAccount(email: "Antigravity", subject: "local", alias: defaults.string(forKey: "antigravityAlias") ?? "")
    }

    func upsert(_ account: AntigravityAccount, select: Bool = true) throws {
        guard canWrite else { throw AntigravityError.commandFailed(L.Antigravity.storageFailed) }
        var next = accounts
        var saved = account
        if let index = next.firstIndex(where: { $0.subject == account.subject }) {
            saved.id = next[index].id; saved.alias = next[index].alias
            next[index] = saved
        } else { next.append(saved) }
        try storage.save(next)
        accounts = next
        if select { switchTo(saved.id) }
    }

    func rename(_ account: AntigravityAccount, alias: String) {
        guard canWrite else { storageError = L.Antigravity.storageFailed; return }
        var next = accounts
        guard let i = next.firstIndex(where: { $0.id == account.id }) else { return }
        next[i].alias = alias
        do { try storage.save(next); accounts = next } catch { storageError = NSLocalizedString("antigravity.storage_failed", comment: "") }
    }

    /// 本地 agy 账户的邮箱来自 agy 日志，agy 换了登录账户时跟着更新
    func updateLocalEmail(_ email: String) {
        guard canWrite, let i = accounts.firstIndex(where: { $0.isLocal }), accounts[i].email != email else { return }
        var next = accounts
        next[i].email = email
        do { try storage.save(next); accounts = next } catch { storageError = NSLocalizedString("antigravity.storage_failed", comment: "") }
    }

    func remove(_ account: AntigravityAccount) {
        guard canWrite else { storageError = L.Antigravity.storageFailed; return }
        let next = accounts.filter { $0.id != account.id }
        do {
            try storage.save(next); accounts = next
            NotificationManager.shared.resetNotificationStates(for: .antigravity, accountId: account.id)
            switchTo(current?.id)
        } catch { storageError = NSLocalizedString("antigravity.storage_failed", comment: "") }
    }

    func switchTo(_ id: UUID?) {
        selectionRevision += 1
        selectedID = id
        defaults.set(id?.uuidString, forKey: "antigravitySelectedAccount")
        defaults.set(!accounts.isEmpty, forKey: "antigravityEnabled")
        AntigravityUsageStore.shared.data = nil
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        NotificationCenter.default.post(name: .accountChanged, object: nil,
            userInfo: [Notification.UserInfoKey.provider: ProviderType.antigravity.rawValue])
    }

    /// 按发起请求时的 refresh_token 反查写回（同 Claude 的 silentlyUpdateClaudeSessionToken）：
    /// 期间账户已删除或已被另一路更新成新 token 时，保留已存的较新值
    func updateCredentials(_ credentials: AntigravityCredentials, accountID: UUID, replacing refreshToken: String) throws {
        guard let i = accounts.firstIndex(where: { $0.id == accountID }),
              accounts[i].credentials?.refreshToken == refreshToken,
              accounts[i].credentials != credentials else { return }
        guard canWrite else { throw AntigravityError.commandFailed(L.Antigravity.storageFailed) }
        var next = accounts
        next[i].credentials = credentials
        try storage.save(next); accounts = next
    }
}
