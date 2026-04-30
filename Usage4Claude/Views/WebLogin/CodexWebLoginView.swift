//
//  CodexWebLoginView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-27.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI
import WebKit

/// Codex WebView 登录界面
struct CodexWebLoginView: View {
    @StateObject private var coordinator = CodexWebLoginCoordinator()
    var onAccountCreated: ((Account) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            CodexWebViewRepresentable(coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if coordinator.loadProgress < 1.0 && coordinator.loadProgress > 0 {
                ProgressView(value: coordinator.loadProgress)
                    .progressViewStyle(.linear)
            }
        }
        .onAppear {
            if let callback = onAccountCreated {
                coordinator.setOnAccountCreated(callback)
            }
            coordinator.loadLoginPage()
        }
        .onDisappear {
            coordinator.cleanup()
        }
        .onChange(of: coordinator.loginState) { newState in
            if case .success = newState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    WebLoginWindowManager.shared.closeCodexLoginWindow()
                }
            }
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        let teal = Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0)

        switch coordinator.loginState {
        case .loading:
            statusRow(icon: "globe", iconColor: teal, text: L.WebLogin.loading, showSpinner: true)

        case .waitingForLogin:
            VStack(alignment: .leading, spacing: 6) {
                statusRow(
                    icon: "person.crop.circle.badge.checkmark",
                    iconColor: .orange,
                    text: L.WebLogin.codexWaitingForLogin,
                    showSpinner: false
                )
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(L.WebLogin.privacyNotice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        case .validating:
            statusRow(icon: "checkmark.shield.fill", iconColor: teal, text: L.WebLogin.validating, showSpinner: true)

        case .success(let accountName):
            statusRow(icon: "checkmark.circle.fill", iconColor: .green, text: L.WebLogin.success(accountName), showSpinner: false)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                statusRow(icon: "exclamationmark.triangle.fill", iconColor: .red, text: message, showSpinner: false)
                Text(L.WebLogin.cloudflareBlocked)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func statusRow(icon: String, iconColor: Color, text: String, showSpinner: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            if showSpinner {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
    }
}

// MARK: - NSViewRepresentable

struct CodexWebViewRepresentable: NSViewRepresentable {
    let coordinator: CodexWebLoginCoordinator

    func makeNSView(context: Context) -> WKWebView {
        return coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
