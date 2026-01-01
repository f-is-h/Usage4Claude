//
//  UsageRowComponents.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

// MARK: - Mini Progress Icon Component

/// 迷你进度环图标（与菜单栏图标样式一致）
struct MiniProgressIcon: View {
    let type: LimitType
    let color: Color
    let size: CGFloat = 14

    var body: some View {
        Canvas { context, canvasSize in
            let lineWidth: CGFloat = 1.8

            // 绘制背景边框
            context.stroke(
                shapePath(in: CGRect(origin: .zero, size: canvasSize)),
                with: .color(Color.gray.opacity(0.3)),
                lineWidth: lineWidth
            )

            // 绘制满进度环（100%）
            context.stroke(
                shapePath(in: CGRect(origin: .zero, size: canvasSize)),
                with: .color(color),
                lineWidth: lineWidth
            )
        }
        .frame(width: size, height: size)
    }

    private func shapePath(in rect: CGRect) -> Path {
        return IconShapePaths.pathForLimitType(type, in: rect)
    }
}

// MARK: - Unified Limit Row Component

/// 统一的限制行组件（支持所有5种限制类型）
struct UnifiedLimitRow: View {
    let type: LimitType
    let data: UsageData
    let showRemainingMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 图标
            MiniProgressIcon(type: type, color: iconColor)

            // 限制类型名称
            Text(limitName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            // 右侧：重置时间或剩余额度
            Text(displayValue)
                .font(.system(size: 12))
                .fontWeight(.medium)
                .id(showRemainingMode ? "remaining" : "reset")  // 强制识别为不同视图
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var limitName: String {
        switch type {
        case .fiveHour:
            return L.Limit.fiveHour
        case .sevenDay:
            return L.Limit.sevenDay
        case .opusWeekly:
            return L.Limit.opusWeekly
        case .sonnetWeekly:
            return L.Limit.sonnetWeekly
        case .extraUsage:
            return L.Limit.extraUsage
        }
    }

    private var iconColor: Color {
        switch type {
        case .fiveHour:
            return .green  // 5小时用绿色
        case .sevenDay:
            return .purple
        case .opusWeekly:
            return .orange
        case .sonnetWeekly:
            return .blue  // 7天Sonnet用蓝色
        case .extraUsage:
            return .pink
        }
    }

    private var displayValue: String {
        switch type {
        case .fiveHour:
            guard let fiveHour = data.fiveHour else { return "-" }
            return showRemainingMode ? fiveHour.formattedCompactRemaining : fiveHour.formattedCompactResetTime

        case .sevenDay:
            guard let sevenDay = data.sevenDay else { return "-" }
            return showRemainingMode ? sevenDay.formattedCompactRemaining : sevenDay.formattedCompactResetDate

        case .opusWeekly:
            guard let opus = data.opus else { return "-" }
            return showRemainingMode ? opus.formattedCompactRemaining : opus.formattedCompactResetDate

        case .sonnetWeekly:
            guard let sonnet = data.sonnet else { return "-" }
            return showRemainingMode ? sonnet.formattedCompactRemaining : sonnet.formattedCompactResetDate

        case .extraUsage:
            guard let extra = data.extraUsage else { return "-" }
            return showRemainingMode ? extra.formattedRemainingAmount : extra.formattedCompactAmount
        }
    }
}
