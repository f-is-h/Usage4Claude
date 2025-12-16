//
//  CompactInfoRow.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 极简信息行组件（用于双模式两行显示）
/// 使用图标代替文字标签，所有信息在一行内紧凑显示
struct CompactInfoRow: View {
    let limitIcon: String      // 限制类型图标（⏱ 或 📅）
    let limitLabel: String     // 限制标签（5h 或 7d）
    let remainingIcon: String  // 剩余时间图标（⏳）
    let remaining: String      // 剩余时间（1h48m 或 3d12h）
    let resetIcon: String      // 重置图标（↻）
    let resetTime: String      // 重置时间（15:07 或 11/29-12h）
    var tintColor: Color = .blue

    var body: some View {
        HStack(spacing: 6) {
            // 限制类型
            HStack(spacing: 3) {
                Text(limitIcon)
                    .font(.system(size: 14))
                Text(limitLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tintColor)
            }

            // 剩余时间
            HStack(spacing: 3) {
                Text(remainingIcon)
                    .font(.system(size: 12))
                Text(remaining)
                    .font(.system(size: 13, weight: .medium))
            }

            // 重置时间
            HStack(spacing: 3) {
                Text(resetIcon)
                    .font(.system(size: 12))
                Text(resetTime)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tintColor.opacity(0.08))
        .cornerRadius(6)
    }
}

