//
//  AuthSettingsView+AccountDetail.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  当前 Claude / Codex 账户详情卡片，从 AuthSettingsView.swift 拆出

import SwiftUI
import AppKit

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

    func currentGrokAccountDetailView(account: Account) -> some View {
        SettingCard(
            icon: "sparkles",
            iconColor: Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0),
            title: L.Account.grokCurrentAccount,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 16) {
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
                                settings.updateGrokAccount(account, alias: newValue.isEmpty ? nil : newValue)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if account.alias != nil && !account.alias!.isEmpty {
                            Button(action: {
                                settings.updateGrokAccount(account, alias: nil)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(L.Account.clearAlias)
                        }
                    }
                }

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

                    Text(account.organizationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                Button(action: {
                    grokAccountToDelete = account
                    showDeleteGrokConfirmation = true
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

    // MARK: - Grok import / device login

    var grokDeviceLoginCard: some View {
        SettingCard(
            icon: "sparkles",
            iconColor: Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0),
            title: L.Account.grokDeviceLogin,
            hint: ""
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let code = grokDeviceUserCode {
                    Text(L.Account.grokDeviceCodeHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(code)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                    if let url = grokDeviceVerificationURL {
                        Button(L.Account.grokOpenBrowser) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    ProgressView()
                        .scaleEffect(0.8)
                    Button(L.Account.cancel) {
                        grokDeviceCancel = true
                        isGrokDeviceLogin = false
                        grokDeviceUserCode = nil
                        grokDeviceVerificationURL = nil
                    }
                    .buttonStyle(.bordered)
                } else {
                    ProgressView(L.Account.grokDevicePreparing)
                }
            }
        }
    }

    func importGrokAuthJSON() {
        isImportingGrokAuth = true
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["json"]
        panel.directoryURL = GrokOAuthConfig.defaultAuthJSONPath.deletingLastPathComponent()
        panel.nameFieldStringValue = "auth.json"
        panel.message = L.Account.importGrokAuthHelp

        panel.begin { response in
            defer { isImportingGrokAuth = false }
            guard response == .OK, let url = panel.url else { return }
            do {
                let tokens = try GrokOAuthService.importFromAuthJSON(at: url)
                guard let refresh = tokens.refreshToken, !refresh.isEmpty else {
                    validationError = UsageError.noCredentials.localizedDescription
                    return
                }
                let account = Account(
                    sessionKey: refresh,
                    organizationId: tokens.teamId ?? tokens.userId ?? UUID().uuidString,
                    organizationName: tokens.email ?? "Grok",
                    provider: .grok
                )
                _ = settings.addGrokAccount(account)
                successMessage = L.Account.grokImportSuccess
            } catch {
                validationError = error.localizedDescription
            }
        }
    }

    func startGrokDeviceLogin() {
        grokDeviceCancel = false
        isGrokDeviceLogin = true
        grokDeviceUserCode = nil
        grokDeviceVerificationURL = nil

        GrokOAuthService.requestDeviceCode { result in
            switch result {
            case .failure(let error):
                isGrokDeviceLogin = false
                validationError = error.localizedDescription
            case .success(let device):
                grokDeviceUserCode = device.userCode
                grokDeviceVerificationURL = device.verificationURIComplete ?? device.verificationURI
                if let url = grokDeviceVerificationURL {
                    NSWorkspace.shared.open(url)
                }
                GrokOAuthService.pollDeviceToken(
                    deviceCode: device.deviceCode,
                    interval: device.interval,
                    expiresIn: device.expiresIn,
                    shouldCancel: { grokDeviceCancel }
                ) { pollResult in
                    isGrokDeviceLogin = false
                    grokDeviceUserCode = nil
                    grokDeviceVerificationURL = nil
                    switch pollResult {
                    case .failure(let error):
                        if !grokDeviceCancel {
                            validationError = error.localizedDescription
                        }
                    case .success(let tokens):
                        guard let refresh = tokens.refreshToken, !refresh.isEmpty else {
                            validationError = UsageError.noCredentials.localizedDescription
                            return
                        }
                        let account = Account(
                            sessionKey: refresh,
                            organizationId: tokens.teamId ?? tokens.userId ?? UUID().uuidString,
                            organizationName: tokens.email ?? "Grok",
                            provider: .grok
                        )
                        _ = settings.addGrokAccount(account)
                        successMessage = L.Account.grokImportSuccess
                    }
                }
            }
        }
    }
}
