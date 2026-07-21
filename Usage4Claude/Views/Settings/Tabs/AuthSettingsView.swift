//
//  AuthSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  账户详情卡片、添加账户流程、说明/诊断卡片分别拆到
//  AuthSettingsView+AccountDetail.swift / +AddAccount.swift / +Help.swift，
//  保持本文件体量可控。跨文件共享的 @State 因此不能标 private（extension 无法跨文件访问）。

import SwiftUI

/// 认证设置页面
/// 使用卡片式布局，用于管理多账户
struct AuthSettingsView: View {
    @ObservedObject var settings = UserSettings.shared
    @State var isAddingAccount = false
    @State var newSessionKey = ""
    @State var newAlias = ""
    @State var isValidating = false
    @State var validationError: String?
    @State var isShowingPassword = false
    @State var showDeleteConfirmation = false
    @State var accountToDelete: Account?
    @State var successMessage: String?
    @State var showDeleteCodexConfirmation = false
    @State var codexAccountToDelete: Account?
    @State var showDeleteGrokConfirmation = false
    @State var grokAccountToDelete: Account?
    @State var isImportingGrokAuth = false
    @State var isGrokDeviceLogin = false
    @State var grokDeviceUserCode: String?
    @State var grokDeviceVerificationURL: URL?
    @State private var grokDeviceCancel = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isAddingAccount {
                    // 添加账户视图
                    addAccountView
                } else {
                    // 多组织添加成功提示
                    if let message = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { successMessage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // 账户列表视图
                    accountListView

                    // 当前 Claude 账户详情
                    if let currentAccount = settings.currentAccount {
                        currentAccountDetailView(account: currentAccount)
                    }

                    // 当前 Codex 账户详情
                    if let currentCodexAccount = settings.currentCodexAccount {
                        currentCodexAccountDetailView(account: currentCodexAccount)
                    }

                    // Current Grok account detail
                    if let currentGrokAccount = settings.currentGrokAccount {
                        currentGrokAccountDetailView(account: currentGrokAccount)
                    }

                    if isGrokDeviceLogin {
                        grokDeviceLoginCard
                    }

                    // 说明卡片
                    howToCard

                    // 诊断卡片
                    diagnosticsCard
                }
            }
            .padding()
        }
        .alert(L.Account.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(L.Account.cancel, role: .cancel) {}
            Button(L.Account.delete, role: .destructive) {
                if let account = accountToDelete {
                    settings.removeAccount(account)
                }
            }
        } message: {
            Text(L.Account.deleteConfirmMessage)
        }
        .alert(L.Account.deleteConfirmTitle, isPresented: $showDeleteCodexConfirmation) {
            Button(L.Account.cancel, role: .cancel) {}
            Button(L.Account.delete, role: .destructive) {
                if let account = codexAccountToDelete {
                    settings.removeCodexAccount(account)
                }
            }
        } message: {
            Text(L.Account.deleteConfirmMessage)
        }
        .alert(L.Account.deleteConfirmTitle, isPresented: $showDeleteGrokConfirmation) {
            Button(L.Account.cancel, role: .cancel) {}
            Button(L.Account.delete, role: .destructive) {
                if let account = grokAccountToDelete {
                    settings.removeGrokAccount(account)
                }
            }
        } message: {
            Text(L.Account.deleteConfirmMessage)
        }
    }

    // MARK: - Account List View

    var accountListView: some View {
        let hasCodex = !settings.codexAccounts.isEmpty
        let hasGrok = !settings.grokAccounts.isEmpty
        let providerCount = [!settings.accounts.isEmpty, hasCodex, hasGrok].filter { $0 }.count
        let hasMultipleProviders = providerCount >= 2

        return SettingCard(
            icon: "person.2.fill",
            iconColor: .blue,
            title: L.Account.listTitle,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if settings.accounts.isEmpty && settings.codexAccounts.isEmpty && settings.grokAccounts.isEmpty {
                    // 无账户时的提示
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(L.Account.noAccounts)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Claude 账户组
                    if !settings.accounts.isEmpty {
                        if hasMultipleProviders {
                            providerSectionHeader(provider: .claude, label: L.Account.claudeAccounts)
                        }
                        ForEach(settings.accounts) { account in
                            accountRow(account: account, provider: .claude)
                        }
                    }

                    // Codex 账户组
                    if hasCodex {
                        if hasMultipleProviders {
                            providerSectionHeader(provider: .codex, label: L.Account.codexAccounts)
                                .padding(.top, 4)
                        }
                        ForEach(settings.codexAccounts) { account in
                            accountRow(account: account, provider: .codex)
                        }
                    }

                    // Grok accounts
                    if hasGrok {
                        if hasMultipleProviders {
                            providerSectionHeader(provider: .grok, label: L.Account.grokAccounts)
                                .padding(.top, 4)
                        }
                        ForEach(settings.grokAccounts) { account in
                            accountRow(account: account, provider: .grok)
                        }
                    }
                }

                // 添加账户入口
                addAccountActionsView
            }
        }
    }

    var addAccountActionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.Account.addAccount)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                addAccountActionButton(
                    provider: .claude,
                    title: L.WebLogin.browserLogin,
                    help: "\(ProviderType.claude.displayName) \(L.WebLogin.browserLogin)"
                ) {
                    WebLoginWindowManager.shared.showLoginWindow()
                }

                addAccountActionButton(
                    provider: .claude,
                    title: L.WebLogin.manualInput,
                    help: L.SettingsAuth.manualInputClaudeOnlyHelp
                ) {
                    withAnimation {
                        isAddingAccount = true
                        newSessionKey = ""
                        newAlias = ""
                        validationError = nil
                    }
                }

                addAccountActionButton(
                    provider: .codex,
                    title: L.WebLogin.browserLogin,
                    help: "\(ProviderType.codex.displayName) \(L.WebLogin.browserLogin)"
                ) {
                    WebLoginWindowManager.shared.showCodexLoginWindow()
                }

                addAccountActionButton(
                    provider: .grok,
                    title: L.Account.importGrokAuth,
                    help: L.Account.importGrokAuthHelp
                ) {
                    importGrokAuthJSON()
                }

                addAccountActionButton(
                    provider: .grok,
                    title: L.Account.grokDeviceLogin,
                    help: L.Account.grokDeviceLoginHelp
                ) {
                    startGrokDeviceLogin()
                }
            }
        }
        .padding(.top, 8)
    }

    func addAccountActionButton(
        provider: ProviderType,
        title: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                providerIcon(provider: provider, size: 16)

                Text(title)
                    .font(.subheadline)
            }
        }
        .buttonStyle(.bordered)
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder
    func providerIcon(provider: ProviderType, size: CGFloat) -> some View {
        switch provider {
        case .claude:
            if let icon = ImageHelper.createAppIcon(size: size) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "sparkles")
                    .frame(width: size, height: size)
            }
        case .codex:
            if let icon = ImageHelper.createCodexIcon(size: size) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "sparkles")
                    .frame(width: size, height: size)
            }
        case .grok:
            Image(systemName: "sparkles")
                .foregroundColor(Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0))
                .frame(width: size, height: size)
        }
    }

    func providerSectionHeader(provider: ProviderType, label: String) -> some View {
        HStack(spacing: 4) {
            if provider == .codex, let icon = ImageHelper.createCodexIcon(size: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 12, height: 12)
            } else if provider == .claude, let icon = ImageHelper.createAppIcon(size: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 12, height: 12)
            } else if provider == .grok {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0))
            }
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Divider()
                .frame(height: 10)
        }
    }

    // MARK: - Account Row

    func accountRow(account: Account, provider: ProviderType) -> some View {
        let isSelected: Bool = {
            switch provider {
            case .claude: return account.id == settings.currentAccountId
            case .codex: return account.id == settings.currentCodexAccountId
            case .grok: return account.id == settings.currentGrokAccountId
            }
        }()
        let accentColor: Color = {
            switch provider {
            case .claude: return .blue
            case .codex: return Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0)
            case .grok: return Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0)
            }
        }()

        return Button(action: {
            switch provider {
            case .claude: settings.switchToAccount(account)
            case .codex: settings.switchToCodexAccount(account)
            case .grok: settings.switchToGrokAccount(account)
            }
        }) {
            HStack(spacing: 12) {
                // 选中状态指示器
                Circle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    )

                // 账户信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(account.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(accentColor)
                        }
                    }

                    if account.alias != nil && !account.alias!.isEmpty {
                        Text(account.organizationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
