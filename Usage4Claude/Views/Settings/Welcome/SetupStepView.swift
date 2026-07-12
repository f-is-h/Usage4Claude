//
//  SetupStepView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

// MARK: - Setup Step (Combined Authentication + Display Options)
// 从 WelcomeView.swift 拆出，便于保持单文件体量可控

struct SetupStepView: View {
    @Binding var sessionKey: String
    @Binding var isShowingPassword: Bool
    @ObservedObject private var settings = UserSettings.shared

    // MARK: - Checkbox Helper Methods

    /// 判断是否应该禁用某个checkbox
    private func shouldDisableCheckbox(for limitType: LimitType) -> Bool {
        let circularTypes: Set<LimitType> = [.fiveHour, .sevenDay, .codexPrimary, .codexSecondary]

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
                    // SessionKey 设置
                    VStack(alignment: .leading, spacing: 12) {
                        // 标题
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text(L.Welcome.authenticationSetup)
                                .font(.headline)

                            Spacer()

                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(L.Welcome.multiAccountHint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 浏览器登录按钮（推荐）
                        Button(action: {
                            WebLoginWindowManager.shared.showLoginWindow { account in
                                // 登录成功后自动填充 sessionKey
                                sessionKey = account.sessionKey
                            }
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                Text(L.WebLogin.browserLoginRecommended)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        // 分隔线
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text(L.WebLogin.orManualInput)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .layoutPriority(1)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
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
                                            } else {
                                                settings.iconDisplayMode = .percentageOnly
                                            }
                                        }
                                    )) {
                                        Text(L.Display.showIcon)
                                    }
                                    .toggleStyle(.checkbox)
                                    .disabled(settings.iconDisplayMode == .iconOnly)

                                    Toggle(isOn: Binding(
                                        get: { settings.iconDisplayMode == .percentageOnly || settings.iconDisplayMode == .both },
                                        set: { showPercentage in
                                            let showIcon = settings.iconDisplayMode == .iconOnly || settings.iconDisplayMode == .both
                                            if showIcon && showPercentage {
                                                settings.iconDisplayMode = .both
                                            } else if showPercentage {
                                                settings.iconDisplayMode = .percentageOnly
                                            } else {
                                                settings.iconDisplayMode = .iconOnly
                                            }
                                        }
                                    )) {
                                        Text(L.Display.showPercentage)
                                    }
                                    .toggleStyle(.checkbox)
                                    .disabled(settings.iconDisplayMode == .percentageOnly)
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

        case .french:
            let anchor = section == .initialSetup ? "#configuration-initiale" : "#-faq"
            return "\(baseURL)/docs/README.fr.md\(anchor)"
        }
    }
}
