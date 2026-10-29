//
//  AntigravityColumnView.swift
//  Usage4Claude
//
//  Antigravity (Google) quota support.
//  结构照搬 CodexColumnView：圆环/节奏图 + 限制行，另外自带错误和加载状态。
//

import SwiftUI

/// Antigravity 用量列视图
struct AntigravityColumnView: View {
    @ObservedObject var store: AntigravityUsageStore = .shared
    @Binding var showRemainingMode: Bool
    @ObservedObject var refreshState: RefreshState
    @Binding var animationType: UsageDetailView.LoadingAnimationType
    @Binding var rotationAngle: Double
    var onRefresh: (() -> Void)?
    var onAnimationHint: ((String) -> Void)?
    var onToggleRemainingMode: (() -> Void)?
    var onOpenAccounts: (() -> Void)?

    /// 列中限制行的数量，供父视图计算高度
    static func rowCount(for data: AntigravityUsageData?) -> Int {
        let count = UserSettings.shared.antigravityDisplayTypes(data: data).count
        return count == 1 ? 2 : max(count, 1)
    }

    var body: some View {
        if let data = store.data {
            content(data: data)
        } else if let error = store.errorMessage {
            errorView(error)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(L.Usage.loading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
        }
    }

    // MARK: - Content

    private func activeTypes(_ data: AntigravityUsageData) -> [LimitType] {
        UserSettings.shared.antigravityDisplayTypes(data: data)
    }

    private var isRefreshing: Bool {
        refreshState.isRefreshingProvider(.antigravity)
    }

    private var placeholder: UsageData.LimitData? {
        UserSettings.shared.shouldShowCustomPlaceholderInPopover
            ? UsageData.LimitData(percentage: 0, resetsAt: nil)
            : nil
    }

    /// 主环：已选类型中使用率最高的窗口
    private func primaryRingType(_ data: AntigravityUsageData) -> LimitType? {
        let types = activeTypes(data)
        return types.max { lhs, rhs in
            (data.limit(for: lhs)?.percentage ?? 0) < (data.limit(for: rhs)?.percentage ?? 0)
        } ?? types.first
    }

    /// 外环：与主环同组的另一个窗口（也必须在已选类型中）
    private func secondaryRingType(_ data: AntigravityUsageData, primary: LimitType?) -> LimitType? {
        let partner: LimitType?
        switch primary {
        case .antigravityGeminiFiveHour: partner = .antigravityGeminiWeekly
        case .antigravityGeminiWeekly: partner = .antigravityGeminiFiveHour
        case .antigravityThirdPartyFiveHour: partner = .antigravityThirdPartyWeekly
        case .antigravityThirdPartyWeekly: partner = .antigravityThirdPartyFiveHour
        default: partner = nil
        }
        guard let partner, activeTypes(data).contains(partner), data.limit(for: partner) != nil else { return nil }
        return partner
    }

    @ViewBuilder
    private func content(data: AntigravityUsageData) -> some View {
        let types = activeTypes(data)
        VStack(spacing: 15) {
            Group {
                switch UserSettings.shared.graphDisplayType {
                case .ring:
                    ring(data: data)
                case .pace:
                    PaceGraphView(
                        antigravityUsageData: data,
                        activeDisplayTypes: types,
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
                ForEach(types, id: \.self) { type in
                    UnifiedLimitRow(
                        type: type,
                        antigravityData: data,
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

    @ViewBuilder
    private func ring(data: AntigravityUsageData) -> some View {
        let primaryType = primaryRingType(data)
        let secondaryType = secondaryRingType(data, primary: primaryType)
        ZStack {
            if let primaryType, let primary = data.limit(for: primaryType) ?? placeholder {
                let primaryRange = displayRange(primary.percentage)

                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    .frame(width: 100, height: 100)

                if isRefreshing {
                    loadingAnimation(colorType: primaryType, lineWidth: 10, diameter: 100, reversed: false)
                } else {
                    UsageRingArc(primaryRange)
                        .stroke(
                            UsageColorScheme.antigravityColorSwiftUI(primaryType, primary.percentage),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(UsageRingDisplay.toggleAnimation, value: primaryRange)
                }

                if let secondaryType, let secondary = data.limit(for: secondaryType) {
                    let secondaryRange = displayRange(secondary.percentage)

                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                        .frame(width: 114, height: 114)

                    if isRefreshing {
                        loadingAnimation(colorType: secondaryType, lineWidth: 3, diameter: 114, reversed: true)
                    } else {
                        UsageRingArc(secondaryRange)
                            .stroke(
                                UsageColorScheme.antigravityColorSwiftUI(secondaryType, secondary.percentage),
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
    }

    private func displayRange(_ percentage: Double) -> UsageRingTrimRange {
        UsageRingDisplay.displayedTrimRange(usedPercentage: percentage, showRemainingMode: showRemainingMode)
    }

    // MARK: - Loading Animation

    @ViewBuilder
    private func loadingAnimation(colorType: LimitType, lineWidth: CGFloat, diameter: CGFloat, reversed: Bool) -> some View {
        let light = UsageColorScheme.antigravityColorSwiftUI(colorType, 0, opacity: 1)
        let dark = UsageColorScheme.antigravityColorSwiftUI(colorType, 80, opacity: 1)
        let angle = reversed ? -rotationAngle : rotationAngle
        switch animationType {
        case .rainbow:
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [light, dark, light]), center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        case .dashed:
            Circle()
                .trim(from: 0, to: 1)
                .stroke(light, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [10, 8]))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        case .pulse:
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(light.opacity(0.8), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
        }
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if store.errorRequiresAuthAction {
                Button(action: { onOpenAccounts?() }) {
                    Label(L.Usage.goToSettings, systemImage: "key.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}
