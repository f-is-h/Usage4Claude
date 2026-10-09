//
//  CommandCodeColumnView.swift
//  Usage4Claude
//
//  Command Code 用量列视图（multi-provider 模式的一列，或独立列）
//  与 CodexColumnView 同构：圆环显示第一个可用窗口（5小时优先），限制行列出全部指标。
//

import SwiftUI

/// Command Code 用量列视图
struct CommandCodeColumnView: View {
    let commandCodeUsageData: CommandCodeUsageData
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private var activeCommandCodeTypes: [LimitType] {
        UserSettings.shared.getActiveDisplayTypes(usageData: nil, commandCodeUsageData: commandCodeUsageData)
            .filter { $0.provider == .commandCode }
    }

    /// 主圆环显示的类型：5小时优先，其次每周
    private var primaryRingType: LimitType? {
        if activeCommandCodeTypes.contains(.commandCodeFiveHour) {
            return .commandCodeFiveHour
        }
        if activeCommandCodeTypes.contains(.commandCodeWeekly) {
            return .commandCodeWeekly
        }
        return nil
    }

    private var primaryRingData: CommandCodeUsageData.Window? {
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover
        let placeholder = CommandCodeUsageData.Window(percentage: 0, resetsAt: nil)
        switch primaryRingType {
        case .commandCodeFiveHour:
            return commandCodeUsageData.fiveHour ?? (showPlaceholder ? placeholder : nil)
        case .commandCodeWeekly:
            return commandCodeUsageData.weekly ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.commandCode)
    }

    /// 每周窗口数据（作为外层细圆环）
    private var secondaryData: CommandCodeUsageData.Window? { commandCodeUsageData.weekly }

    /// 主圆环显示 5 小时且周窗口存在时，才画外层细圆环（与 Codex 同构）
    private var showSecondaryRing: Bool {
        primaryRingType == .commandCodeFiveHour
            && activeCommandCodeTypes.contains(.commandCodeWeekly)
            && secondaryData != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 15) {
            Group {
                switch UserSettings.shared.graphDisplayType {
                case .ring:
                    ZStack {
                        if let primary = primaryRingData {
                            let primaryColor = primaryRingColor(for: primary.percentage)
                            let primaryRange = UsageRingDisplay.displayedTrimRange(
                                usedPercentage: primary.percentage,
                                showRemainingMode: showRemainingMode
                            )

                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)

                            if isRefreshing {
                                loadingAnimation()
                            } else {
                                UsageRingArc(primaryRange)
                                    .stroke(
                                        primaryColor,
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                    .animation(UsageRingDisplay.toggleAnimation, value: primaryRange)
                            }

                            // 外层细圆环（每周窗口）
                            if showSecondaryRing, let secondary = secondaryData {
                                let secondaryRange = UsageRingDisplay.displayedTrimRange(
                                    usedPercentage: secondary.percentage,
                                    showRemainingMode: showRemainingMode
                                )

                                Circle()
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                    .frame(width: 114, height: 114)

                                if isRefreshing {
                                    outerLoadingAnimation()
                                } else {
                                    UsageRingArc(secondaryRange)
                                        .stroke(
                                            UsageColorScheme.commandCodeWeeklyColorSwiftUI(secondary.percentage),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 114, height: 114)
                                        .rotationEffect(.degrees(-90))
                                        .animation(UsageRingDisplay.toggleAnimation, value: secondaryRange)
                                }
                            }

                            DetailUsageRingCenterText(
                                usedPercentage: primary.percentage,
                                showRemainingMode: showRemainingMode
                            )
                        }
                    }
                    .frame(height: 114)
                    .contentShape(Circle())
                case .pace:
                    PaceGraphView(
                        commandCodeUsageData: commandCodeUsageData,
                        activeDisplayTypes: activeCommandCodeTypes,
                        isRefreshing: isRefreshing,
                        showRemainingMode: showRemainingMode
                    )
                    .frame(height: 114)
                    .contentShape(Rectangle())
                }
            }
            .onTapGesture {
                if refreshState.canRefresh && !refreshState.isRefreshing {
                    onRefresh?()
                }
            }
            .onLongPressGesture(minimumDuration: 3.0) {
                guard UserSettings.shared.graphDisplayType == .ring else { return }
                let allTypes = UsageDetailView.LoadingAnimationType.allCases
                let currentIndex = allTypes.firstIndex(of: animationType) ?? 0
                animationType = allTypes[(currentIndex + 1) % allTypes.count]
                onAnimationHint?(animationType.name)
            }

            VStack(spacing: 5) {
                ForEach(activeCommandCodeTypes, id: \.self) { type in
                    UnifiedLimitRow(
                        type: type,
                        commandCodeData: commandCodeUsageData,
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
        if primaryRingType == .commandCodeWeekly {
            return UsageColorScheme.commandCodeWeeklyColorSwiftUI(percentage)
        }
        return UsageColorScheme.commandCodeFiveHourColorSwiftUI(percentage)
    }

    // MARK: - Loading Animation

    private let fiveHourColor = Color(red: 34/255.0, green: 211/255.0, blue: 238/255.0)
    private let fiveHourDark = Color(red: 8/255.0, green: 145/255.0, blue: 178/255.0)
    private let weeklyColor = Color(red: 163/255.0, green: 230/255.0, blue: 53/255.0)
    private let weeklyDark = Color(red: 101/255.0, green: 163/255.0, blue: 13/255.0)

    @ViewBuilder
    private func loadingAnimation() -> some View {
        let primary = primaryRingType == .commandCodeWeekly ? weeklyColor : fiveHourColor
        let secondary = primaryRingType == .commandCodeWeekly ? weeklyDark : fiveHourDark
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [primary, secondary, .cyan, primary]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(primary, style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8]))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .pulse:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(primary.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(rotationAngle))
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(primary.opacity(0.4), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-rotationAngle * 0.7))
            }
        }
    }

    /// 外层细圆环（每周窗口）的刷新动画，与 Codex 同构
    @ViewBuilder
    private func outerLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [weeklyColor, weeklyDark, weeklyColor]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(weeklyDark, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .pulse:
            Circle()
                .trim(from: 0, to: 0.4)
                .stroke(weeklyDark.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
        }
    }
}
