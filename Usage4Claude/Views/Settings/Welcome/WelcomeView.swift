//
//  WelcomeView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 首次启动欢迎界面
/// 单页流程：欢迎 → 所有设置（认证 + 主题 + 预览）
/// 具体步骤内容拆到 SetupStepView.swift / WelcomeSupportingViews.swift，保持本文件体量可控
struct WelcomeView: View {
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared
    @State private var currentStep: WelcomeStep = .welcome
    @State private var sessionKey: String = ""
    @State private var isShowingPassword: Bool = false
    @State private var isFetchingOrgId: Bool = false
    @State private var fetchError: String?

    enum WelcomeStep {
        case welcome
        case setup
    }

    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView()
                case .setup:
                    SetupStepView(
                        sessionKey: $sessionKey,
                        isShowingPassword: $isShowingPassword
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部导航按钮
            NavigationButtons(
                currentStep: currentStep,
                canProceed: canProceed,
                isFetchingOrgId: isFetchingOrgId,
                fetchError: fetchError,
                onBack: goToPreviousStep,
                onNext: goToNextStep,
                onSkip: skipSetup,
                onComplete: completeSetup
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 550, height: 600)
        .id(localization.updateTrigger)
    }

    // MARK: - Computed Properties

    private var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .setup:
            return !sessionKey.isEmpty && settings.isValidSessionKey(sessionKey)
        }
    }

    // MARK: - Navigation Methods

    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .setup:
                currentStep = .welcome
            case .welcome:
                break
            }
        }
    }

    private func goToNextStep() {
        withAnimation {
            switch currentStep {
            case .welcome:
                currentStep = .setup
            case .setup:
                completeSetup()
            }
        }
    }

    private func skipSetup() {
        settings.isFirstLaunch = false
        dismiss()
    }

    private func completeSetup() {
        let trimmedKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 显示加载状态
        isFetchingOrgId = true
        fetchError = nil

        // 获取 Organization ID 并创建账户
        fetchOrganizationAndCreateAccount(sessionKey: trimmedKey) { success in
            DispatchQueue.main.async {
                isFetchingOrgId = false

                if success {
                    // 获取成功，标记首次启动完成
                    settings.isFirstLaunch = false

                    // 发送通知以启动数据刷新
                    NotificationCenter.default.post(name: .openSettings, object: nil)

                    // 关闭窗口
                    dismiss()
                } else {
                    // 获取失败，显示错误但不阻止用户继续
                    // 用户可以稍后在设置中重新配置
                    fetchError = L.Welcome.fetchOrgIdFailed

                    // 3秒后自动关闭错误提示并继续
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        settings.isFirstLaunch = false
                        dismiss()
                    }
                }
            }
        }
    }

    /// 获取 Organization 并创建账户
    /// - Parameters:
    ///   - sessionKey: Session Key
    ///   - completion: 完成回调，返回是否成功
    private func fetchOrganizationAndCreateAccount(sessionKey: String, completion: @escaping (Bool) -> Void) {
        let apiService = ClaudeAPIService.shared
        apiService.fetchOrganizations(sessionKey: sessionKey) { result in
            switch result {
            case .success(let organizations):
                if !organizations.isEmpty {
                    DispatchQueue.main.async {
                        for org in organizations {
                            let newAccount = Account(
                                sessionKey: sessionKey,
                                organizationId: org.uuid,
                                organizationName: org.name,
                                alias: nil
                            )
                            settings.addAccount(newAccount)
                        }
                    }
                    completion(true)
                } else {
                    completion(false)
                }
            case .failure:
                completion(false)
            }
        }
    }

}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App图标
            if let icon = ImageHelper.createAppIcon(size: 120) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                    .shadow(radius: 10)
            }

            // 欢迎文字
            VStack(spacing: 12) {
                Text(L.Welcome.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L.Welcome.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}
