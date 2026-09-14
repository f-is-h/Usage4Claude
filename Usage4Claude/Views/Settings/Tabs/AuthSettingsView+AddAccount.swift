//
//  AuthSettingsView+AddAccount.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  手动添加账户（Session Key 输入 + 校验）流程，从 AuthSettingsView.swift 拆出

import SwiftUI

extension AuthSettingsView {

    // MARK: - Add Account View

    var addAccountView: some View {
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

    // MARK: - Private Methods

    /// 验证并添加账户
    func validateAndAddAccount() {
        isValidating = true
        validationError = nil

        let apiService = ClaudeAPIService.shared
        apiService.fetchOrganizations(sessionKey: newSessionKey) { result in
            DispatchQueue.main.async {
                isValidating = false

                switch result {
                case .success(let organizations):
                    if !organizations.isEmpty {
                        let useAlias = organizations.count == 1
                        for (index, org) in organizations.enumerated() {
                            let newAccount = Account(
                                sessionKey: newSessionKey,
                                organizationId: org.uuid,
                                organizationName: org.name,
                                alias: (useAlias && !newAlias.isEmpty) ? newAlias : nil
                            )
                            settings.addAccount(newAccount)
                            // 切换到第一个新添加的账户
                            if index == 0 {
                                settings.switchToAccount(newAccount)
                            }
                        }
                        // 多组织时显示提示
                        if organizations.count > 1 {
                            successMessage = String(format: L.Account.multiOrgAdded, organizations.count)
                        }
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
