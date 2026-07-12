//
//  WelcomeSupportingViews.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//
//  小型可复用组件，从 WelcomeView.swift 拆出以保持单文件体量可控：
//  HorizontalRadioGroup / MenuBarIconPreview / NavigationButtons

import SwiftUI

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
