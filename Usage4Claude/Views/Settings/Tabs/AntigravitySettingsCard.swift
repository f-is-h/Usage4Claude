//
//  AntigravitySettingsCard.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//

import SwiftUI

/// Account details share the Claude/Codex layout for local and independent OAuth accounts.
struct AntigravitySettingsCard: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var store = AntigravityUsageStore.shared
    @State private var showDeleteConfirmation = false
    /// 输入中的别名草稿：停顿后/回车/离开时才写一次 Keychain，而不是每个按键都写
    @State private var aliasDraft = ""
    @State private var aliasCommit: Task<Void, Never>?

    private var account: AntigravityAccount? { settings.currentAntigravityAccount }
    private var hasCLI: Bool { AntigravityAPIService.locateCLI() != nil }

    var body: some View {
        SettingCard(
            icon: "person.circle.fill",
            iconColor: .indigo,
            title: L.Antigravity.currentAccount,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(L.Account.alias, icon: "tag.fill", color: .orange)

                    HStack {
                        TextField(account?.email ?? "", text: $aliasDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { commitAlias() }
                            .onChange(of: aliasDraft) { _ in scheduleAliasCommit() }

                        if !aliasDraft.isEmpty {
                            Button(action: { aliasDraft = ""; commitAlias() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .help(L.Account.clearAlias)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(L.Antigravity.authentication, icon: "key.fill", color: .red)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if account?.isLocal == true && !hasCLI {
                        Text(L.Antigravity.installHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if store.data == nil || store.errorMessage != nil {
                        Button(action: recheck) {
                            Label(L.Antigravity.recheck, systemImage: "arrow.clockwise")
                        }
                        .focusable(false)
                    }
                }

                Divider()

                Button(action: { showDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text(L.Account.deleteAccount)
                    }
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .onAppear { aliasDraft = account?.alias ?? "" }
        .onChange(of: account?.id) { _ in aliasDraft = account?.alias ?? "" }
        .onDisappear { commitAlias() }
        .alert(L.Account.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(L.Account.cancel, role: .cancel) {}
            Button(L.Account.delete, role: .destructive) {
                if let account { AntigravityAccountStore.shared.remove(account) }
            }
        } message: {
            Text(L.Antigravity.deleteConfirmMessage)
        }
    }

    private var statusText: String {
        if account?.isLocal == true && !hasCLI { return L.Antigravity.cliNotFoundShort }
        if let error = store.errorMessage { return error }
        if store.data != nil { return account?.isLocal == true ? L.Antigravity.managedSignIn : L.Antigravity.googleSignIn }
        return L.Usage.loading
    }

    /// 先记下目标账户和值：停顿期间切换账户时，草稿仍写回原来的账户
    private func scheduleAliasCommit() {
        aliasCommit?.cancel()
        let target = account, value = aliasDraft
        aliasCommit = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            Self.commit(value, to: target)
        }
    }

    private func commitAlias() {
        aliasCommit?.cancel()
        Self.commit(aliasDraft, to: account)
    }

    private static func commit(_ alias: String, to account: AntigravityAccount?) {
        guard let account,
              let stored = AntigravityAccountStore.shared.accounts.first(where: { $0.id == account.id }),
              stored.alias != alias else { return }
        AntigravityAccountStore.shared.rename(stored, alias: alias)
    }

    private func fieldLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    /// 重新检测：走账户切换通知，DataRefreshManager 会清掉旧状态和退避后立即拉取一次
    private func recheck() {
        _ = AntigravityAPIService.locateCLI(refresh: true)
        NotificationCenter.default.post(
            name: .accountChanged,
            object: nil,
            userInfo: [Notification.UserInfoKey.provider: ProviderType.antigravity.rawValue]
        )
    }
}
