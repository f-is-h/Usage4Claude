//
//  AuthSettingsView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 认证设置页面
/// 使用卡片式布局，用于管理多账户
struct AuthSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var isAddingAccount = false
    @State private var newSessionKey = ""
    @State private var newAlias = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var isShowingPassword = false
    @State private var showDeleteConfirmation = false
    @State private var accountToDelete: Account?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isAddingAccount {
                    // 添加账户视图
                    addAccountView
                } else {
                    // 账户列表视图
                    accountListView

                    // 当前账户详情
                    if let currentAccount = settings.currentAccount {
                        currentAccountDetailView(account: currentAccount)
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
    }

    // MARK: - Account List View

    private var accountListView: some View {
        SettingCard(
            icon: "person.2.fill",
            iconColor: .blue,
            title: L.Account.listTitle,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if settings.accounts.isEmpty {
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
                    // 账户列表
                    ForEach(settings.accounts) { account in
                        accountRow(account: account)
                    }
                }

                // 添加账户按钮
                Button(action: {
                    withAnimation {
                        isAddingAccount = true
                        newSessionKey = ""
                        newAlias = ""
                        validationError = nil
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(L.Account.addAccount)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Account Row

    private func accountRow(account: Account) -> some View {
        Button(action: {
            settings.switchToAccount(account)
        }) {
            HStack(spacing: 12) {
                // 选中状态指示器
                Circle()
                    .fill(account.id == settings.currentAccountId ? Color.blue : Color.clear)
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

                        if account.id == settings.currentAccountId {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    // 如果有别名，显示原始名称作为副标题
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
                    .fill(account.id == settings.currentAccountId ? Color.blue.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Account Detail View

    private func currentAccountDetailView(account: Account) -> some View {
        SettingCard(
            icon: "person.circle.fill",
            iconColor: .green,
            title: L.Account.currentAccount,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // 别名编辑
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        Text(L.Account.alias)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        TextField(account.organizationName, text: Binding(
                            get: { account.alias ?? "" },
                            set: { newValue in
                                settings.updateAccount(account, alias: newValue.isEmpty ? nil : newValue)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if account.alias != nil && !account.alias!.isEmpty {
                            Button(action: {
                                settings.updateAccount(account, alias: nil)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L.Account.clearAlias)
                        }
                    }
                }

                // Session Key 显示
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(L.SettingsAuth.sessionKeyLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        if isShowingPassword {
                            Text(account.sessionKey)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text(String(repeating: "•", count: min(account.sessionKey.count, 30)))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            isShowingPassword.toggle()
                        }) {
                            Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(isShowingPassword ? L.SettingsAuth.hidePassword : L.SettingsAuth.showPassword)
                    }
                }

                // Organization ID 显示
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.purple)
                            .font(.subheadline)
                        Text(L.Account.organizationId)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text(account.organizationId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(account.organizationId, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L.Account.copyOrgId)
                    }
                }

                // 删除按钮
                if settings.accounts.count > 0 {
                    Divider()

                    Button(action: {
                        accountToDelete = account
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(L.Account.deleteAccount)
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Add Account View

    private var addAccountView: some View {
        SettingCard(
            icon: "person.badge.plus",
            iconColor: .blue,
            title: L.Account.addNewAccount,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Session Key 输入
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(L.SettingsAuth.sessionKeyLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    SecureField(L.SettingsAuth.sessionKeyPlaceholder, text: $newSessionKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    // 验证状态提示
                    if !newSessionKey.isEmpty {
                        if settings.isValidSessionKey(newSessionKey) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(L.Welcome.validFormat)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(L.Welcome.invalidFormat)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(L.SettingsAuth.sessionKeyHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 别名输入（可选）
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        Text(L.Account.aliasOptional)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    TextField(L.Account.aliasPlaceholder, text: $newAlias)
                        .textFieldStyle(.roundedBorder)
                }

                // 错误提示
                if let error = validationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // 操作按钮
                HStack {
                    Button(action: {
                        withAnimation {
                            isAddingAccount = false
                        }
                    }) {
                        Text(L.Account.cancel)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        validateAndAddAccount()
                    }) {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text(L.Account.validateAndAdd)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settings.isValidSessionKey(newSessionKey) || isValidating)
                }
            }
        }
    }

    // MARK: - How To Card

    private var howToCard: some View {
        SettingCard(
            icon: "book.fill",
            iconColor: .blue,
            title: L.SettingsAuth.howToTitle,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.SettingsAuth.step1)
                    .font(.subheadline)
                Text(L.SettingsAuth.step2)
                    .font(.subheadline)
                Text(L.SettingsAuth.step3)
                    .font(.subheadline)
                Text(L.SettingsAuth.step4)
                    .font(.subheadline)
                Text(L.SettingsAuth.step5)
                    .font(.subheadline)
                Text(L.SettingsAuth.step6)
                    .font(.subheadline)

                Button(action: {
                    if let url = URL(string: "https://claude.ai/settings/usage") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text(L.SettingsAuth.openBrowser)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Diagnostics Card

    private var diagnosticsCard: some View {
        SettingCard(
            icon: "stethoscope",
            iconColor: .blue,
            title: L.Diagnostic.sectionTitle,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.Diagnostic.sectionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // 诊断组件
                DiagnosticsView()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Private Methods

    /// 验证并添加账户
    private func validateAndAddAccount() {
        isValidating = true
        validationError = nil

        let apiService = ClaudeAPIService()
        apiService.fetchOrganizations(sessionKey: newSessionKey) { result in
            DispatchQueue.main.async {
                isValidating = false

                switch result {
                case .success(let organizations):
                    if let firstOrg = organizations.first {
                        // 创建新账户
                        let newAccount = Account(
                            sessionKey: newSessionKey,
                            organizationId: firstOrg.uuid,
                            organizationName: firstOrg.name,
                            alias: newAlias.isEmpty ? nil : newAlias
                        )
                        settings.addAccount(newAccount)

                        // 自动切换到新账户
                        settings.switchToAccount(newAccount)

                        // 关闭添加界面
                        withAnimation {
                            isAddingAccount = false
                        }
                    } else {
                        validationError = L.Error.noOrganizationsFound
                    }
                case .failure(let error):
                    if let usageError = error as? UsageError {
                        validationError = usageError.localizedDescription
                    } else {
                        validationError = error.localizedDescription
                    }
                }
            }
        }
    }
}

/// 关于页面
/// 显示应用信息、版本号和相关链接
