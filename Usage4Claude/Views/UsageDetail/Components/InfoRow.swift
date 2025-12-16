//
//  InfoRow.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-02.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import SwiftUI

/// 信息行组件
/// 显示一行信息，包含图标、标题和值
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var tintColor: Color = .blue  // 新增：可自定义图标颜色

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(tintColor)  // 使用自定义颜色
                .frame(width: 8)
                .font(.system(size: 12))  // 图标大小

            Text(title)
                .font(.system(size: 12))  // 第一列文字大小
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 12))  // 第二列文字大小
                .fontWeight(.medium)
        }
        .padding(.vertical, 6)  // 行高
        .padding(.horizontal, 12) // 行宽
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
