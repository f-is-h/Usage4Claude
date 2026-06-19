//
//  CodexOAuthLoginView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-06-18.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// Codex OAuth 登录进度窗口
///
/// 实际认证在系统默认浏览器中完成，本窗口仅展示进度与结果。
/// 这样可彻底绕开 WKWebView 对 Google 嵌入式登录的封锁，以及 passkey/WebAuthn 在
/// 内嵌 WebView 中不可用的问题。
struct CodexOAuthLoginView: View {
    @StateObject private var coordinator = CodexOAuthCoordinator()
    var onAccountCreated: ((Account) -> Void)?

    private let teal = Color(red: 45 / 255.0, green: 212 / 255.0, blue: 191 / 255.0)

    var body: some View {
        VStack(spacing: 18) {
            content
        }
        .padding(32)
        .frame(width: 440, height: 300)
        .onAppear { coordinator.start(onAccountCreated: onAccountCreated) }
        .onDisappear { coordinator.cancel() }
        .onChange(of: coordinator.loginState) { state in
            if case .success = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    WebLoginWindowManager.shared.closeCodexLoginWindow()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.loginState {
        case .starting:
            spinner(L.WebLogin.codexOAuthPreparing)

        case .waitingForBrowser:
            VStack(spacing: 14) {
                Image(systemName: "safari")
                    .font(.system(size: 44))
                    .foregroundColor(teal)
                Text(L.WebLogin.codexOAuthWaitingBrowser)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(L.WebLogin.codexOAuthWaitingHint)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.WebLogin.codexOAuthReopenBrowser) { coordinator.reopenBrowser() }
                    .buttonStyle(.link)
            }

        case .exchanging:
            spinner(L.WebLogin.codexOAuthExchanging)

        case .success(let name):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                Text(L.WebLogin.success(name))
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(L.WebLogin.codexOAuthRetry) {
                    coordinator.start(onAccountCreated: onAccountCreated)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func spinner(_ text: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
