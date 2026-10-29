import Foundation
import Security

/// Always Keychain, including Debug; never UserDefaults or a token-bearing log.
struct AntigravitySecureStorage {
    /// 区分「数据坏了」（可以覆盖）和「Keychain 拒绝访问」（不能覆盖）
    enum Failure: Error { case corrupt }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "xyz.fi5h.Usage4Claude") + ".antigravity",
         kSecAttrAccount as String: "accounts"]
    }
    func load() throws -> [AntigravityAccount] {
        var q = query; q[kSecReturnData as String] = true
        var value: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &value)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = value as? Data else { throw AntigravityError.commandFailed(NSLocalizedString("antigravity.storage_failed", comment: "")) }
        guard let accounts = try? JSONDecoder().decode([AntigravityAccount].self, from: data) else { throw Failure.corrupt }
        return accounts
    }
    func save(_ accounts: [AntigravityAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        let attributes = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AntigravityError.commandFailed(NSLocalizedString("antigravity.storage_failed", comment: "")) }
    }
}
