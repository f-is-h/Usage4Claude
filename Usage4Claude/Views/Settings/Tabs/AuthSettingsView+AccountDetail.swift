//
//  AuthSettingsView+AccountDetail.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  当前 Claude / Codex 账户详情卡片，从 AuthSettingsView.swift 拆出

import SwiftUI

extension AuthSettingsView {

    // MARK: - Current Account Detail View

    func currentAccountDetailView(account: Account) -> some View {
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

    // MARK: - Current Codex Account Detail View

    func currentCodexAccountDetailView(account: Account) -> some View {
        SettingCard(
            icon: "person.circle.fill",
            iconColor: Color(red: 13/255.0, green: 148/255.0, blue: 136/255.0),
            title: L.Account.codexCurrentAccount,
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
                                settings.updateCodexAccount(account, alias: newValue.isEmpty ? nil : newValue)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if account.alias != nil && !account.alias!.isEmpty {
                            Button(action: {
                                settings.updateCodexAccount(account, alias: nil)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L.Account.clearAlias)
                        }
                    }
                }

                // Session Token 显示
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
                        Text(String(repeating: "•", count: min(account.sessionKey.count, 30)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }

                // 删除按钮
                Divider()

                Button(action: {
                    codexAccountToDelete = account
                    showDeleteCodexConfirmation = true
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
