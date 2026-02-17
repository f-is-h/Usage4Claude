//
//  WebLoginView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-02-06.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI
import WebKit

/// WebView 登录界面
/// 包含状态栏、WKWebView 和加载进度条
struct WebLoginView: View {
    @StateObject private var coordinator = WebLoginCoordinator()
    var onAccountCreated: ((Account) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            statusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // WKWebView 区域
            WebViewRepresentable(coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部加载进度条
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
                // 登录成功后延迟 1.5s 自动关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    WebLoginWindowManager.shared.closeLoginWindow()
                }
            }
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        switch coordinator.loginState {
        case .loading:
            statusRow(
                icon: "globe",
                iconColor: .blue,
                text: L.WebLogin.loading,
                showSpinner: true
            )

        case .waitingForLogin:
            VStack(alignment: .leading, spacing: 6) {
                statusRow(
                    icon: "person.crop.circle.badge.checkmark",
                    iconColor: .orange,
                    text: L.WebLogin.waitingForLogin,
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
            statusRow(
                icon: "checkmark.shield.fill",
                iconColor: .blue,
                text: L.WebLogin.validating,
                showSpinner: true
            )

        case .success(let accountName):
            statusRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                text: L.WebLogin.success(accountName),
                showSpinner: false
            )

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                statusRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    text: message,
                    showSpinner: false
                )
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

/// 将 WKWebView 包装为 SwiftUI 视图
struct WebViewRepresentable: NSViewRepresentable {
    let coordinator: WebLoginCoordinator

    func makeNSView(context: Context) -> WKWebView {
        return coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
