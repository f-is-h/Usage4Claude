//
//  AuthSettingsView+CommandCode.swift
//  Usage4Claude
//
//  Command Code 账户的添加（粘贴会话 Cookie）与当前账户详情卡片。
//  与 Claude 的「手动输入 Session Key」流程同构：粘贴 → 探测 /internal/billing/credits → 入库。
//

import SwiftUI

extension AuthSettingsView {

    // MARK: - Add Command Code Account View

    var commandCodeAddAccountView: some View {
        SettingCard(
            icon: "person.badge.plus",
            iconColor: Color(red: 139/255.0, green: 92/255.0, blue: 246/255.0),
            title: L.Account.commandCodeAccounts,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // 会话 Cookie 输入
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(L.CommandCode.sessionCookieLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    TextField(L.CommandCode.sessionCookieLabel, text: $newCommandCodeCookie)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(L.CommandCode.sessionCookieHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

                    TextField(L.Account.aliasPlaceholder, text: $newCommandCodeAlias)
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
                        withAnimation { isAddingCommandCodeAccount = false }
                    }) {
                        Text(L.Account.cancel)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        validateAndAddCommandCodeAccount()
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
                    .disabled(newCommandCodeCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                }
            }
        }
    }

    /// 验证并添加 Command Code 账户
    func validateAndAddCommandCodeAccount() {
        let cookie = newCommandCodeCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidating = true
        validationError = nil

        CommandCodeAPIService.shared.validate(cookie: cookie) { result in
            DispatchQueue.main.async {
                isValidating = false

                switch result {
                case .success:
                    let alias = newCommandCodeAlias.trimmingCharacters(in: .whitespacesAndNewlines)
                    let account = Account(
                        sessionKey: cookie,
                        organizationId: "",
                        organizationName: L.Account.commandCodeAccounts,
                        alias: alias.isEmpty ? nil : alias,
                        provider: .commandCode
                    )
                    _ = settings.addCommandCodeAccount(account)
                    settings.switchToCommandCodeAccount(account)
                    withAnimation { isAddingCommandCodeAccount = false }

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

    // MARK: - Current Command Code Account Detail View

    func currentCommandCodeAccountDetailView(account: Account) -> some View {
        SettingCard(
            icon: "person.circle.fill",
            iconColor: Color(red: 139/255.0, green: 92/255.0, blue: 246/255.0),
            title: L.Account.commandCodeCurrentAccount,
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
                                settings.updateCommandCodeAccount(account, alias: newValue.isEmpty ? nil : newValue)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if account.alias != nil && !account.alias!.isEmpty {
                            Button(action: {
                                settings.updateCommandCodeAccount(account, alias: nil)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .help(L.Account.clearAlias)
                        }
                    }
                }

                // 会话 Cookie 显示（始终打码）
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                        Text(L.CommandCode.sessionCookieLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(String(repeating: "•", count: min(account.sessionKey.count, 30)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                // 删除按钮
                Divider()

                Button(action: {
                    commandCodeAccountToDelete = account
                    showDeleteCommandCodeConfirmation = true
                }) {
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
    }
}
