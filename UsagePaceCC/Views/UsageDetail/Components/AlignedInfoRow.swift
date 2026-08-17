//
//  AlignedInfoRow.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 对齐的信息行组件（用于双限制场景的垂直对齐）
/// 使用固定宽度布局确保两行的时间数据垂直对齐
struct AlignedInfoRow: View {
    let icon: String
    let title: String
    let remainingIcon: String
    let remaining: String
    let resetIcon: String
    let resetTime: String
    var tintColor: Color = .blue

    var body: some View {
        HStack(spacing: 6) {  // 整行宽度
            // 左侧：图标+标题（固定区域）
            HStack(spacing: 4) {  // 图标和标题间距
                Image(systemName: icon)
                    .foregroundColor(tintColor)
                    .frame(width: 18)  // 宽度

                Text(title)
                    .font(.system(size: 12))  // 字体
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)  // 左侧整体宽度

            Spacer()

            // 右侧：使用固定宽度布局对齐时间数据
            HStack(spacing: 8) {
                // 剩余时间
                HStack(spacing: 3) {  // 图标和文字间距
                    Image(systemName: remainingIcon)
                        .font(.system(size: 12))  // 图标大小
                        .foregroundColor(.secondary)
                    Text(remaining)
                        .font(.system(size: 12))  // 字号
                        .fontWeight(.medium)
                }
                .frame(width: 75, alignment: .leading)  // 显示宽度

                // 重置时间
                HStack(spacing: 3) {  // 图标和文字间距
                    Image(systemName: resetIcon)
                        .font(.system(size: 12))  // 图标大小
                        .foregroundColor(.secondary)
                    Text(resetTime)
                        .font(.system(size: 12))  // 显示宽度
                        .fontWeight(.medium)
                }
                .frame(width: 90, alignment: .leading)  // 显示宽度
            }
        }
        .padding(.vertical, 6) // 行高
        .padding(.horizontal, 12)  // 行宽
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
