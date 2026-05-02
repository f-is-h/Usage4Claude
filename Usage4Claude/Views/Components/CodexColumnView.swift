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
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?

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
        let showPlaceholder = UserSettings.shared.displayMode == .custom

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
                    // 背景圆环
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    // 主进度条（刷新中显示加载动画）
                    if isCodexRefreshing {
                        codexLoadingAnimation()
                    } else {
                        Circle()
                            .trim(from: 0, to: CGFloat(primary.percentage) / 100.0)
                            .stroke(
                                primaryRingColor(for: primary.percentage),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: primary.percentage)
                    }

                    // 外层细圆环（Secondary / 7天）
                    if showSecondaryRing, let secondary = secondaryData {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                            .frame(width: 114, height: 114)

                        if isCodexRefreshing {
                            codexOuterLoadingAnimation()
                        } else {
                            Circle()
                                .trim(from: 0, to: CGFloat(secondary.percentage) / 100.0)
                                .stroke(
                                    UsageColorScheme.codexSecondaryColorSwiftUI(secondary.percentage),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 2])
                                )
                                .frame(width: 114, height: 114)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut, value: secondary.percentage)
                        }
                    }

                    // 中心百分比
                    VStack(spacing: 2) {
                        Text("\(Int(primary.percentage))%")
                            .font(.system(size: 28, weight: .bold))
                        Text(L.Usage.used)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRemainingMode.toggle()
                }
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
