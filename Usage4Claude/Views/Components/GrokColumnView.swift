//
//  GrokColumnView.swift
//  Usage4Claude
//
//  Grok usage column (weekly + monthly rings, credits row).
//

import SwiftUI

/// Grok usage column view
struct GrokColumnView: View {
    let grokUsageData: GrokUsageData
    @Binding var showRemainingMode: Bool
    let refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    let remainingModeAnimationTrigger: Int
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?
    var onToggleRemainingMode: (() -> Void)?

    private var activeGrokTypes: [LimitType] {
        UserSettings.shared.getActiveDisplayTypes(usageData: nil, grokUsageData: grokUsageData)
            .filter { $0.provider == .grok }
    }

    private var primaryRingType: LimitType? {
        if activeGrokTypes.contains(.grokWeekly) { return .grokWeekly }
        if activeGrokTypes.contains(.grokMonthly) { return .grokMonthly }
        return nil
    }

    private var primaryRingData: GrokUsageData.LimitData? {
        let placeholder = GrokUsageData.LimitData(percentage: 0, resetsAt: nil, used: nil, limit: nil)
        let showPlaceholder = UserSettings.shared.shouldShowCustomPlaceholderInPopover

        switch primaryRingType {
        case .grokWeekly:
            return grokUsageData.weekly ?? (showPlaceholder ? placeholder : nil)
        case .grokMonthly:
            return grokUsageData.monthly ?? (showPlaceholder ? placeholder : nil)
        default:
            return nil
        }
    }

    private var secondaryData: GrokUsageData.LimitData? { grokUsageData.monthly }

    private var showSecondaryRing: Bool {
        primaryRingType == .grokWeekly && activeGrokTypes.contains(.grokMonthly) && secondaryData != nil
    }

    private var isGrokRefreshing: Bool {
        refreshState.isRefreshingProvider(.grok)
    }

    var body: some View {
        VStack(spacing: 15) {
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

                    if isGrokRefreshing {
                        grokLoadingAnimation()
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

                    if showSecondaryRing, let secondary = secondaryData {
                        let secondaryRange = UsageRingDisplay.displayedTrimRange(
                            usedPercentage: secondary.percentage,
                            showRemainingMode: showRemainingMode
                        )

                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                            .frame(width: 114, height: 114)

                        if isGrokRefreshing {
                            grokOuterLoadingAnimation()
                        } else {
                            Circle()
                                .trim(from: secondaryRange.from, to: secondaryRange.to)
                                .stroke(
                                    UsageColorScheme.grokMonthlyColorSwiftUI(secondary.percentage),
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

                    if !isGrokRefreshing {
                        DetailUsageRingSweep(
                            trigger: remainingModeAnimationTrigger,
                            diameter: 122,
                            lineWidth: 3,
                            color: primaryColor
                        )
                    }

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

            VStack(spacing: 5) {
                ForEach(activeGrokTypes, id: \.self) { type in
                    UnifiedLimitRow(
                        type: type,
                        grokData: grokUsageData,
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
        if primaryRingType == .grokMonthly {
            return UsageColorScheme.grokMonthlyColorSwiftUI(percentage)
        }
        return UsageColorScheme.grokWeeklyColorSwiftUI(percentage)
    }

    private let grokPrimary = Color(red: 100/255.0, green: 116/255.0, blue: 139/255.0)
    private let grokPrimaryDark = Color(red: 71/255.0, green: 85/255.0, blue: 105/255.0)
    private let grokSecondary = Color(red: 244/255.0, green: 114/255.0, blue: 182/255.0)
    private let grokSecondaryDark = Color(red: 219/255.0, green: 39/255.0, blue: 119/255.0)

    @ViewBuilder
    private func grokLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [grokPrimary, grokPrimaryDark, .gray, grokPrimary]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(grokPrimary, style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [10, 8]))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
        case .pulse:
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(grokPrimary.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(rotationAngle))
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(grokPrimary.opacity(0.4), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-rotationAngle * 0.7))
            }
        }
    }

    @ViewBuilder
    private func grokOuterLoadingAnimation() -> some View {
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [grokSecondary, grokSecondaryDark, .pink, grokSecondary]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(grokSecondaryDark, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle))
        case .pulse:
            Circle()
                .trim(from: 0, to: 0.4)
                .stroke(grokSecondaryDark.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 114, height: 114)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
        }
    }
}
