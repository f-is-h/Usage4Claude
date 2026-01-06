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

        // 先保存到 Keychain（同步）
        _ = KeychainManager.shared.saveSessionKey(trimmedKey)

        // 更新 UserSettings
        settings.sessionKey = trimmedKey

        // 获取 Organization ID
        fetchOrganizationId { success in
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

    /// 获取 Organization ID
    /// - Parameter completion: 完成回调，返回是否成功
    private func fetchOrganizationId(completion: @escaping (Bool) -> Void) {
        let apiService = ClaudeAPIService()
        apiService.fetchOrganizations { result in
            switch result {
            case .success(let organizations):
                if let firstOrg = organizations.first {
                    DispatchQueue.main.async {
                        settings.organizationId = firstOrg.uuid
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

// MARK: - Setup Step (Combined Authentication + Display Options)

struct SetupStepView: View {
    @Binding var sessionKey: String
    @Binding var isShowingPassword: Bool
    @ObservedObject private var settings = UserSettings.shared

    // MARK: - Checkbox Helper Methods

    /// 判断是否应该禁用某个checkbox
    private func shouldDisableCheckbox(for limitType: LimitType) -> Bool {
        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay]

        // 如果这是最后一个选中的圆形图标，则禁用
        if circularTypes.contains(limitType) {
            let selectedCircular = settings.customDisplayTypes.intersection(circularTypes)
            return selectedCircular.count == 1 && selectedCircular.contains(limitType)
        }

        return false
    }

    /// 切换限制类型的选中状态
    private func toggleLimitType(_ limitType: LimitType) {
        if settings.customDisplayTypes.contains(limitType) {
            // 检查是否可以取消选择
            if !shouldDisableCheckbox(for: limitType) {
                settings.customDisplayTypes.remove(limitType)
            }
        } else {
            settings.customDisplayTypes.insert(limitType)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 紧凑的欢迎信息
                VStack(spacing: 8) {
                    if let icon = ImageHelper.createAppIcon(size: 48) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .cornerRadius(10)
                    }

                    Text(L.Welcome.title)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .padding(.vertical, 20)

                // 主设置区域
                VStack(alignment: .leading, spacing: 20) {
                    // SessionKey 设置 - 横向布局
                    VStack(alignment: .leading, spacing: 12) {
                        // 标题
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text(L.Welcome.authenticationSetup)
                                .font(.headline)

                            Spacer()

                            // 帮助按钮
                            Button(action: {
                                if let url = URL(string: getGitHubReadmeURL(section: .initialSetup)) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "questionmark.circle")
                                    Text(L.Welcome.howToGetSessionKey)
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        // Session Key输入 - 横向
                        HStack(alignment: .top, spacing: 12) {
                            Text(L.Welcome.sessionKey)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if isShowingPassword {
                                        TextField(L.Welcome.sessionKeyPlaceholder, text: $sessionKey)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    } else {
                                        SecureField(L.Welcome.sessionKeyPlaceholder, text: $sessionKey)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    }

                                    Button(action: {
                                        isShowingPassword.toggle()
                                    }) {
                                        Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // 验证状态
                                if !sessionKey.isEmpty {
                                    if settings.isValidSessionKey(sessionKey) {
                                        Label(L.Welcome.validFormat, systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Label(L.Welcome.invalidFormat, systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                Text(L.Welcome.sessionKeyHint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // 主题设置
                    VStack(alignment: .leading, spacing: 12) {
                        // 标题和预览
                        HStack(alignment: .top, spacing: 8) {
                            // 左侧标题
                            HStack(spacing: 8) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                Text(L.Welcome.displayTitle)
                                    .font(.headline)
                            }

                            Spacer()

                            // 右侧预览
                            VStack(alignment: .trailing, spacing: 6) {
                                MenuBarIconPreview()

                                // 菜单栏图标提示链接
                                Button(action: {
                                    if let url = URL(string: getGitHubReadmeURL(section: .faq)) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "questionmark.circle")
                                        Text(L.Welcome.menubarIconNotVisible)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 第一行：菜单栏主题
                        HStack(alignment: .top, spacing: 12) {
                            Text(L.SettingsGeneral.menubarTheme)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)

                            HorizontalRadioGroup(
                                selection: $settings.iconStyleMode,
                                options: [
                                    (.colorTranslucent, L.IconStyle.colorTranslucent),
                                    (.monochrome, L.IconStyle.monochrome)
                                ]
                            )
                        }

                        // 第二行：显示内容 - 使用 checkbox
                        HStack(alignment: .top, spacing: 12) {
                            Text(L.SettingsGeneral.displayContent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 16) {
                                    Toggle(isOn: Binding(
                                        get: { settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both },
                                        set: { showIcon in
                                            let showPercentage = settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both
                                            if showIcon && showPercentage {
                                                settings.iconDisplayMode = .both
                                            } else if showIcon {
                                                settings.iconDisplayMode = .iconOnly
                                            } else if showPercentage {
                                                settings.iconDisplayMode = .percentageOnly
                                            } else {
                                                // 至少保留一个
                                                settings.iconDisplayMode = .percentageOnly
                                            }
                                        }
                                    )) {
                                        Text(L.Display.showIcon)
                                    }
                                    .toggleStyle(.checkbox)

                                    Toggle(isOn: Binding(
                                        get: { settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both },
                                        set: { showPercentage in
                                            let showIcon = settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both
                                            if showIcon && showPercentage {
                                                settings.iconDisplayMode = .both
                                            } else if showPercentage {
                                                settings.iconDisplayMode = .percentageOnly
                                            } else if showIcon {
                                                settings.iconDisplayMode = .iconOnly
                                            } else {
                                                // 至少保留一个
                                                settings.iconDisplayMode = .iconOnly
                                            }
                                        }
                                    )) {
                                        Text(L.Display.showPercentage)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }

                        // 第三行：显示模式（智能/自定义）
                        HStack(alignment: .top, spacing: 12) {
                            Text(L.DisplayOptions.displayModeLabel)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                HorizontalRadioGroup(
                                    selection: $settings.displayMode,
                                    options: [
                                        (.smart, L.Welcome.smartModeRecommended),
                                        (.custom, L.Welcome.customSelection)
                                    ]
                                )

                                // 模式说明
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(settings.displayMode == .smart ?
                                         L.DisplayOptions.smartDisplayDescription :
                                         L.DisplayOptions.customDisplayDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                // 自定义选择的checkbox - 3+2两行布局
                                if settings.displayMode == .custom {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(L.Welcome.selectLimits)
                                            .font(.caption)
                                            .fontWeight(.medium)

                                        VStack(alignment: .leading, spacing: 10) {
                                            // 第一行：5小时、7天、Extra Usage
                                            HStack(spacing: 16) {
                                                LimitTypeCheckbox(
                                                    limitType: .fiveHour,
                                                    isSelected: settings.customDisplayTypes.contains(.fiveHour),
                                                    isDisabled: shouldDisableCheckbox(for: .fiveHour)
                                                ) {
                                                    toggleLimitType(.fiveHour)
                                                }

                                                LimitTypeCheckbox(
                                                    limitType: .sevenDay,
                                                    isSelected: settings.customDisplayTypes.contains(.sevenDay),
                                                    isDisabled: shouldDisableCheckbox(for: .sevenDay)
                                                ) {
                                                    toggleLimitType(.sevenDay)
                                                }

                                                LimitTypeCheckbox(
                                                    limitType: .extraUsage,
                                                    isSelected: settings.customDisplayTypes.contains(.extraUsage),
                                                    isDisabled: shouldDisableCheckbox(for: .extraUsage)
                                                ) {
                                                    toggleLimitType(.extraUsage)
                                                }

                                                Spacer()
                                            }

                                            // 第二行：Opus Weekly、Sonnet Weekly
                                            HStack(spacing: 16) {
                                                LimitTypeCheckbox(
                                                    limitType: .opusWeekly,
                                                    isSelected: settings.customDisplayTypes.contains(.opusWeekly),
                                                    isDisabled: shouldDisableCheckbox(for: .opusWeekly)
                                                ) {
                                                    toggleLimitType(.opusWeekly)
                                                }

                                                LimitTypeCheckbox(
                                                    limitType: .sonnetWeekly,
                                                    isSelected: settings.customDisplayTypes.contains(.sonnetWeekly),
                                                    isDisabled: shouldDisableCheckbox(for: .sonnetWeekly)
                                                ) {
                                                    toggleLimitType(.sonnetWeekly)
                                                }

                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - GitHub README URL Helper

    /// README 章节枚举
    private enum ReadmeSection {
        case initialSetup
        case faq
    }

    /// 根据当前语言生成 GitHub README URL
    /// - Parameter section: README 章节
    /// - Returns: 对应语言和章节的 GitHub README URL
    private func getGitHubReadmeURL(section: ReadmeSection) -> String {
        let baseURL = "https://github.com/f-is-h/Usage4Claude/blob/main"
        let language = settings.language

        switch language {
        case .english:
            let anchor = section == .initialSetup ? "#initial-setup" : "#-faq"
            return "\(baseURL)/README.md\(anchor)"

        case .chinese:
            let anchor = section == .initialSetup ? "#首次配置" : "#-常见问题"
            return "\(baseURL)/docs/README.zh-CN.md\(anchor)"

        case .chineseTraditional:
            let anchor = section == .initialSetup ? "#首次設定" : "#-常見問題"
            return "\(baseURL)/docs/README.zh-TW.md\(anchor)"

        case .japanese:
            let anchor = section == .initialSetup ? "#初期設定" : "#-よくある質問"
            return "\(baseURL)/docs/README.ja.md\(anchor)"

        case .korean:
            let anchor = section == .initialSetup ? "#초기-설정" : "#-자주-묻는-질문"
            return "\(baseURL)/docs/README.ko.md\(anchor)"
        }
    }
}

// MARK: - Horizontal Radio Group Component

/// 横向单选按钮组
struct HorizontalRadioGroup<T: Hashable>: View {
    let selection: Binding<T>
    let options: [(value: T, label: String)]
    let spacing: CGFloat

    init(selection: Binding<T>, options: [(value: T, label: String)], spacing: CGFloat = 16) {
        self.selection = selection
        self.options = options
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button(action: {
                    selection.wrappedValue = option.value
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: selection.wrappedValue == option.value ? "largecircle.fill.circle" : "circle")
                            .font(.body)
                            .foregroundColor(selection.wrappedValue == option.value ? .accentColor : .secondary)
                        Text(option.label)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)  // 禁用键盘焦点
            }
        }
    }
}

// MARK: - Menu Bar Icon Preview

/// 菜单栏图标预览组件
/// 使用假数据模拟真实的菜单栏图标显示效果
struct MenuBarIconPreview: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        // 模拟菜单栏背景
        HStack(spacing: 3) {
            Image(nsImage: getPreviewIcon())
                .resizable()
                .scaledToFit()
                .frame(height: 18)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(previewBackgroundColor)
        .cornerRadius(4)
    }

    /// 获取预览图标（使用createIcon方法）
    private func getPreviewIcon() -> NSImage {
        let renderer = MenuBarIconRenderer(settings: settings)
        let mockData = createMockUsageData()

        // 使用 createIcon 方法，这样会正确响应 iconDisplayMode
        return renderer.createIcon(usageData: mockData, hasUpdate: false, button: nil)
    }

    /// 创建模拟用量数据（66% 使用率）
    private func createMockUsageData() -> UsageData {
        let mockPercentage = 66.0

        return UsageData(
            fiveHour: UsageData.LimitData(
                percentage: mockPercentage,
                resetsAt: Date().addingTimeInterval(3600)
            ),
            sevenDay: UsageData.LimitData(
                percentage: mockPercentage,
                resetsAt: Date().addingTimeInterval(86400 * 3)
            ),
            opus: UsageData.LimitData(
                percentage: mockPercentage,
                resetsAt: Date().addingTimeInterval(86400 * 5)
            ),
            sonnet: UsageData.LimitData(
                percentage: mockPercentage,
                resetsAt: Date().addingTimeInterval(86400 * 5)
            ),
            extraUsage: ExtraUsageData(
                enabled: true,
                used: mockPercentage,
                limit: 100.0,
                currency: "USD"
            )
        )
    }

    /// 预览背景色（模拟菜单栏）
    private var previewBackgroundColor: Color {
        // 根据系统外观返回菜单栏颜色
        if UsageColorScheme.isDarkMode {
            return Color(white: 0.2)  // 深色模式菜单栏
        } else {
            return Color(white: 0.95)  // 浅色模式菜单栏
        }
    }
}

// MARK: - Navigation Buttons

struct NavigationButtons: View {
    let currentStep: WelcomeView.WelcomeStep
    let canProceed: Bool
    let isFetchingOrgId: Bool
    let fetchError: String?
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 错误提示
            if let error = fetchError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // 按钮行
            HStack(spacing: 12) {
                // 返回按钮
                if currentStep != .welcome {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(L.Welcome.back)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isFetchingOrgId)
                }

                Spacer()

                // 跳过按钮
                if currentStep != .setup {
                    Button(L.Welcome.skip, action: onSkip)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .disabled(isFetchingOrgId)
                }

                // 继续/完成按钮
                Button(action: currentStep == .setup ? onComplete : onNext) {
                    HStack(spacing: 8) {
                        if isFetchingOrgId && currentStep == .setup {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 12, height: 12)
                            Text(L.Welcome.configuring)
                        } else {
                            Text(currentStep == .setup ? L.Welcome.finish : L.Welcome.continue_)
                            if currentStep != .setup {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .frame(maxWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed || isFetchingOrgId)
            }
        }
    }
}
