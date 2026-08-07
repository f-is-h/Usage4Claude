//
//  AccountUsageSnapshot.swift
//  Usage4Claude
//
//  Account-scoped usage state shared by refresh and menu-bar rendering.
//

import Foundation

enum AccountUsagePayload: Sendable {
    case claude(UsageData)
    case codex(CodexUsageData)
}

struct AccountUsageSnapshot: Identifiable, Sendable {
    let id: UUID
    let provider: ProviderType
    let displayName: String
    let accountIdentity: String
    let label: String
    let payload: AccountUsagePayload?
    let errorDescription: String?

    init(
        account: Account,
        label: String? = nil,
        payload: AccountUsagePayload? = nil,
        errorDescription: String? = nil
    ) {
        id = account.id
        provider = account.provider
        displayName = account.displayName
        accountIdentity = account.accountIdentity
        self.label = label ?? account.displayName
        self.payload = payload
        self.errorDescription = errorDescription
    }

    init(
        id: UUID,
        provider: ProviderType,
        displayName: String,
        accountIdentity: String,
        label: String,
        payload: AccountUsagePayload?,
        errorDescription: String?
    ) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.accountIdentity = accountIdentity
        self.label = label
        self.payload = payload
        self.errorDescription = errorDescription
    }
}

enum AccountMenuBarPlan {
    static func make(
        claudeAccounts: [Account],
        codexAccounts: [Account],
        maxLabelLength: Int = 10
    ) -> [AccountUsageSnapshot] {
        let accounts = claudeAccounts + codexAccounts
        let labelLength = max(1, maxLabelLength)
        let baseLabels = accounts.map { account -> String in
            let compact = String(account.displayName.prefix(labelLength))
            return compact.isEmpty ? account.provider.displayName : compact
        }
        let counts = Dictionary(baseLabels.map { ($0, 1) }, uniquingKeysWith: +)
        var occurrences: [String: Int] = [:]

        return zip(accounts, baseLabels).map { account, baseLabel in
            occurrences[baseLabel, default: 0] += 1
            let label = counts[baseLabel, default: 0] > 1
                ? "\(baseLabel) \(occurrences[baseLabel, default: 1])"
                : baseLabel
            return AccountUsageSnapshot(account: account, label: label)
        }
    }
}

enum AccountCredentialUpdate {
    static func replacingCredential(
        in accounts: [Account],
        accountId: UUID,
        expectedToken: String? = nil,
        token: String
    ) -> [Account] {
        accounts.map { account in
            guard account.id == accountId,
                  expectedToken == nil || account.sessionKey == expectedToken else { return account }
            return Account(
                id: account.id,
                sessionKey: token,
                organizationId: account.organizationId,
                organizationName: account.organizationName,
                email: account.email,
                alias: account.alias,
                createdAt: account.createdAt,
                provider: account.provider
            )
        }
    }
}

enum AccountUsageResult: Sendable {
    case success(AccountUsagePayload)
    case failure(String)
}

enum AccountUsageReducer {
    static func applying(
        _ results: [UUID: Result<AccountUsagePayload, Error>],
        to previous: [AccountUsageSnapshot],
        plan: [AccountUsageSnapshot]
    ) -> [AccountUsageSnapshot] {
        let normalized = results.mapValues { result in
            switch result {
            case .success(let payload):
                return AccountUsageResult.success(payload)
            case .failure(let error):
                return AccountUsageResult.failure(error.localizedDescription)
            }
        }
        return merge(plan: plan, previous: previous, results: normalized)
    }

    static func merge(
        plan: [AccountUsageSnapshot],
        previous: [AccountUsageSnapshot],
        results: [UUID: AccountUsageResult]
    ) -> [AccountUsageSnapshot] {
        let previousById = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })

        return plan.map { planned in
            let old = previousById[planned.id]
            let payload: AccountUsagePayload?
            let errorDescription: String?

            switch results[planned.id] {
            case .success(let freshPayload):
                payload = freshPayload
                errorDescription = nil
            case .failure(let error):
                payload = old?.payload
                errorDescription = error
            case .none:
                payload = old?.payload
                errorDescription = old?.errorDescription
            }

            return AccountUsageSnapshot(
                id: planned.id,
                provider: planned.provider,
                displayName: planned.displayName,
                accountIdentity: planned.accountIdentity,
                label: planned.label,
                payload: payload,
                errorDescription: errorDescription
            )
        }
    }
}

enum AccountMenuBarSignature {
    static func make(snapshots: [AccountUsageSnapshot], hasUpdate: Bool) -> String {
        let accountParts = snapshots.map { snapshot in
            [
                snapshot.id.uuidString,
                snapshot.provider.rawValue,
                snapshot.label,
                payloadSignature(snapshot.payload),
                snapshot.errorDescription ?? ""
            ].map { value in
                "\(value.utf8.count)#\(value)"
            }.joined(separator: ":")
        }
        return ([hasUpdate ? "badge" : "plain"] + accountParts).joined(separator: "|")
    }

    private static func payloadSignature(_ payload: AccountUsagePayload?) -> String {
        guard let payload else { return "none" }
        switch payload {
        case .claude(let usage):
            let weekly = usage.weeklyModels.map {
                "\($0.modelName ?? "")=\($0.limit.percentage)"
            }.joined(separator: ",")
            let parts: [String] = [
                "claude",
                usage.fiveHour.map { String($0.percentage) } ?? "nil",
                usage.sevenDay.map { String($0.percentage) } ?? "nil",
                weekly,
                usage.extraUsage?.enabled == true ? "1" : "0",
                usage.extraUsage?.percentage.map { String($0) } ?? "nil"
            ]
            return parts.joined(separator: ";")
        case .codex(let usage):
            let parts: [String] = [
                "codex",
                usage.primary.map { String($0.percentage) } ?? "nil",
                usage.secondary.map { String($0.percentage) } ?? "nil",
                usage.extraUsage?.enabled == true ? "1" : "0",
                usage.extraUsage?.percentage.map { String($0) } ?? "nil"
            ]
            return parts.joined(separator: ";")
        }
    }
}

extension Array where Element == AccountUsageSnapshot {
    func selectedClaude(accountId: UUID?) -> UsageData? {
        guard let accountId,
              let snapshot = first(where: { $0.id == accountId }),
              case .claude(let usage) = snapshot.payload else {
            return nil
        }
        return usage
    }

    func selectedCodex(accountId: UUID?) -> CodexUsageData? {
        guard let accountId,
              let snapshot = first(where: { $0.id == accountId }),
              case .codex(let usage) = snapshot.payload else {
            return nil
        }
        return usage
    }
}
