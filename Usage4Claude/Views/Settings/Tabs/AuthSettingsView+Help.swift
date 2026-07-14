//
//  AuthSettingsView+Help.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  说明卡片与诊断卡片，从 AuthSettingsView.swift 拆出

import SwiftUI

extension AuthSettingsView {

    // MARK: - How To Card

    var howToCard: some View {
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

    var diagnosticsCard: some View {
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
}
