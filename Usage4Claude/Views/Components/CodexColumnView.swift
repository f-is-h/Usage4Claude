//
//  CodexColumnView.swift
//  Usage4Claude
//
//  Created by f-is-h on 2026-04-27.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// Codex 用量列视图（双 Provider 模式右列）
struct CodexColumnView: View {
    let codexUsageData: CodexUsageData
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    /// Codex 官方重置预告（Beta，第三方数据源）；nil 表示没有预告（绝大多数时间）或功能已关闭
    var codexResetAnnouncement: CodexResetAnnouncement? = nil
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private var activeCodexTypes: [LimitType] {
        UserSettings.shared.getActiveDisplayTypes(usageData: nil, codexUsageData: codexUsageData)
            .filter { $0.provider == .codex }
    }

    private var primaryRingType: LimitType? {
        if activeCodexTypes.contains(.codexPrimary) {
            return .codexPrimary
        }
        if activeCodexTypes.contains(.codexSecondary) {
            return .codexSecondary
        }
        return nil
    }

    private var primaryRingData: CodexUsageData.LimitData? {
        let placeholder = CodexUsageData.LimitData(percentage: 0, resetsAt: nil)
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover

        switch primaryRingType {
        case .codexPrimary:
            return codexUsageData.primary ?? (showPlaceholder ? placeholder : nil)
        case .codexSecondary:
            return codexUsageData.secondary ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var secondaryData: CodexUsageData.LimitData? { codexUsageData.secondary }

    private var showSecondaryRing: Bool {
        primaryRingType == .codexPrimary && activeCodexTypes.contains(.codexSecondary) && secondaryData != nil
    }

    private var isCodexRefreshing: Bool {
        refreshState.isRefreshingProvider(.codex)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 15) {
            // 圆环区域
            ZStack {
                if let primary = primaryRingData {
                    let primaryColor = primaryRingColor(for: primary.percentage)
                    let primaryRange = UsageRingDisplay.displayedTrimRange(
                        usedPercentage: primary.percentage,
                        showRemainingMode: showRemainingMode
                    )

                    // 背景圆环
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    // 主进度条（刷新中显示加载动画）
                    if isCodexRefreshing {
                        codexLoadingAnimation()
                    } else {
                        Circle()
                            .trim(from: primaryRange.from, to: primaryRange.to)
                            .stroke(
                                primaryColor,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05),
                                value: primaryRange
                            )
                    }

                    // 外层细圆环（Secondary / 7天）
                    if showSecondaryRing, let secondary = secondaryData {
                        let secondaryRange = UsageRingDisplay.displayedTrimRange(
                            usedPercentage: secondary.percentage,
                            showRemainingMode: showRemainingMode
                        )

                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                            .frame(width: 114, height: 114)

                        if isCodexRefreshing {
                            codexOuterLoadingAnimation()
                        } else {
                            Circle()
                                .trim(from: secondaryRange.from, to: secondaryRange.to)
                                .stroke(
                                    UsageColorScheme.codexSecondaryColorSwiftUI(secondary.percentage),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 114, height: 114)
                                .rotationEffect(.degrees(-90))
                                .animation(
                                    .spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.05),
                                    value: secondaryRange
                                )
                        }
                    }

                    if !isCodexRefreshing {
                        DetailUsageRingSweep(
                            trigger: remainingModeAnimationTrigger,
                            diameter: 122,
                            lineWidth: 3,
                            color: primaryColor
                        )
                    }

                    // 中心百分比
                    DetailUsageRingCenterText(
                        usedPercentage: primary.percentage,
                        showRemainingMode: showRemainingMode
                    )
                }
            }
            .frame(height: 114)
            .contentShape(Circle())
            .onTapGesture {
                if refreshState.canRefresh && !refreshState.isRefreshing {
                    onRefresh?()
                }
            }
            .onLongPressGesture(minimumDuration: 3.0) {
                let allTypes = UsageDetailView.LoadingAnimationType.allCases
                let currentIndex = allTypes.firstIndex(of: animationType) ?? 0
                animationType = allTypes[(currentIndex + 1) % allTypes.count]

                onAnimationHint?(animationType.name)
            }
            // 先撑满列宽，overlay 才能以整列为参照系定位到右上角（ZStack 自身只会
            // hug 住圆环的 ~122pt）。高度仍是 114，与上面一致——这里只改宽度，不影响
            // 圆环的垂直位置。必须放在 contentShape/手势之后，否则 Circle() 会被拉伸成
            // 贴合整列的椭圆，点按/长按热区跟着撑满整列，误触发刷新/切换动画。
            .frame(maxWidth: .infinity)
            .frame(height: 114)
            // 角标落在圆环右上方本就空白的区域：圆环含扫光直径 122pt 居中，但在角标所在
            // 高度（顶部下方约 9pt）圆环横向只占到 x≈183，右侧到列边缘还有约 90pt 空白，
            // 足够放下约 72pt 宽的角标。因此这里不需要任何 offset——不挤压圆环、不超出
            // popover 手算的 contentHeight 边界（否则会被窗口裁切、且裁切区收不到鼠标事件）。
            .overlay(alignment: .topTrailing) {
                if let announcement = codexResetAnnouncement {
                    CodexResetAnnouncementBadge(announcement: announcement)
                        .padding(.trailing, 8)
                        .padding(.top, 2)
                }
            }

            // 限制行
            VStack(spacing: 5) {
                ForEach(activeCodexTypes, id: \.self) { type in
                    UnifiedLimitRow(
                        type: type,
                        codexData: codexUsageData,
                        showRemainingMode: showRemainingMode
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleRemainingMode?()
            }
            .padding(.horizontal, 14)
        }
    }

    private func primaryRingColor(for percentage: Double) -> Color {
        if primaryRingType == .codexSecondary {
            return UsageColorScheme.codexSecondaryColorSwiftUI(percentage)
        }
        return UsageColorScheme.codexPrimaryColorSwiftUI(percentage)
    }

    // MARK: - Loading Animations

    private let codexPrimaryColor = Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0)
    private let codexPrimaryDark = Color(red: 13/255.0, green: 148/255.0, blue: 136/255.0)
    private let codexSecondaryColor = Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0)
    private let codexSecondaryDark = Color(red: 37/255.0, green: 99/255.0, blue: 235/255.0)
    private let codexSecondaryDeep = Color(red: 30/255.0, green: 58/255.0, blue: 138/255.0)

    @ViewBuilder
    private func codexLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [codexPrimaryColor, codexPrimaryDark, .cyan, codexPrimaryColor]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(codexPrimaryColor, style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8]))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .pulse:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(codexPrimaryColor.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(rotationAngle))
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(codexPrimaryColor.opacity(0.4), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-rotationAngle * 0.7))
            }
        }
    }

    @ViewBuilder
    private func codexOuterLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [codexSecondaryColor, codexSecondaryDark, codexSecondaryDeep, codexSecondaryColor]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(codexSecondaryDark, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .pulse:
            Circle()
                .trim(from: 0, to: 0.4)
                .stroke(codexSecondaryDark.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
        }
    }
}
